# Web Speech API Proposal: Speaker Diarization

**Author:** alanding@google.com

### Problem

With on-device speech recognition (`processLocally: true`), `MediaStreamTrack` input, and result timestamps (`speechStartTime` and `speechEndTime`), web applications can transcribe audio locally with timeline precision. However, `SpeechRecognition` still treats every audio source as a single homogeneous speaker stream and provides no way to distinguish **who spoke when** when multiple people share a microphone or appear in a single media track:

- **Shared-Mic Video Conferencing:** When multiple participants share a conference room microphone or laptop (e.g. Google Meet), live captions and meeting transcripts collapse into an unattributed wall of text, degrading readability and meeting notes.
- **Automated Multi-Speaker Subtitling (`WebVTT` `<v>` Voice Spans):** Accessibility guidelines for deaf and hard-of-hearing (DHH) users require captions to signal speaker changes and distinguish speakers (`<v Speaker 1>`). Web applications transcribing a media track currently cannot generate speaker-attributed `VTTCue`s.
- **Privacy-Sensitive In-Person Note-Taking:** Clinicians, educators, attorneys, and journalists transcribing multi-party conversations locally (`processLocally: true`) must currently either send sensitive audio to cloud APIs or run a duplicate audio-capture and speaker-embedding pipeline in WebAssembly.
- **Downstream Analytics & On-Device AI Pipelines:** Applications cannot compute per-speaker talk-time balance from result timestamps or pass speaker-attributed transcripts to on-device language models (such as the Prompt API) to summarize action items and infer conversational roles without exposing voice data.

---

### Proposed Solution

We propose adding opt-in speaker diarization to `SpeechRecognition` and `SpeechRecognitionOptions`, and annotating each `SpeechRecognitionResult` with `speakerChanged` and `speaker` attributes.

#### Web IDL Definition

```webidl
enum SpeechRecognitionDiarization {
    "none",            // Default: no speaker turn detection or labeling.
    "speaker-turns",   // Splits results on speaker changes and sets speakerChanged.
    "speaker-labels"   // Splits results on speaker changes and assigns session-scoped speaker labels.
};

partial interface SpeechRecognition {
    // Requested diarization mode, read when start() is called. Defaults to "none".
    attribute SpeechRecognitionDiarization diarization;

    // Optional speaker-count hints for "speaker-labels" mode. 0 (default) means no hint.
    attribute unsigned long minSpeakers;
    attribute unsigned long maxSpeakers;
};

partial dictionary SpeechRecognitionOptions {
    // Allows available() and install() to check and provision diarization resources.
    SpeechRecognitionDiarization diarization = "none";
};

partial interface SpeechRecognitionResult {
    // True if this result starts a new speaker turn. Always false for the first result
    // of a session and when diarization is "none".
    readonly attribute boolean speakerChanged;

    // Canonical 1-indexed session label ("1", "2", ...) in "speaker-labels" mode;
    // null in other modes, or when the speaker could not yet be determined.
    readonly attribute DOMString? speaker;
};

// Added to SpeechRecognitionErrorCode:
//   "diarization-not-supported"
```

### Choice of Naming & Representation

1. **Per-Result Turn Metadata (`speaker` and `speakerChanged`):**
   * Attaching `speaker` and `speakerChanged` directly to `SpeechRecognitionResult` matches `speechStartTime` and `speechEndTime` ([PR #192](https://github.com/WebAudio/web-speech-api/pull/192)) and proposed per-result `lang` ([Issue #208](https://github.com/WebAudio/web-speech-api/issues/208)), keeping speaker attribution inside the cumulative `SpeechRecognitionResultList` rather than transient events.
   * When diarization is active, each detected speaker change ends the current result and starts a new result, so `[speechStartTime, speechEndTime]` automatically bounds when that speaker spoke on the session audio timeline ([Issue #213](https://github.com/WebAudio/web-speech-api/issues/213)).
   * Keeping `speakerChanged` distinct from `speaker` lets code group consecutive pause-split or code-switched results from the same speaker into a single turn (`speakerChanged === false`), and serves as the sole output in `"speaker-turns"` mode.
2. **Two Capability Tiers (`"speaker-turns"` vs. `"speaker-labels"`):**
   * `"speaker-turns"` detects acoustic turn transitions (`speakerChanged`) without requiring per-speaker voice embeddings or clustering—offering a lower-compute, lower-sensitivity tier ideal for live caption line breaks (`>>`).
   * `"speaker-labels"` clusters turns within the session and assigns canonical 1-indexed decimal strings (`"1"`, `"2"`, ...) in order of first appearance, mapping directly to WebVTT voice spans (`<v Speaker 1>`).
3. **Attributes on `SpeechRecognition` + Option in `SpeechRecognitionOptions`:**
   * Placing `diarization`, `minSpeakers`, and `maxSpeakers` on `SpeechRecognition` matches `processLocally`, `unspokenPunctuation`, and `maxAlternatives`, and enables reliable feature detection (`'diarization' in SpeechRecognition.prototype`)—avoiding the WebIDL dictionary pitfall where older user agents silently ignore unknown members in `SpeechRecognitionOptions`.
   * If a user agent cannot satisfy the requested diarization mode, `start()` queues an `error` event with `"diarization-not-supported"` (mirroring `"phrases-not-supported"`) rather than silently downgrading.

---

### Proposed Behavior & Examples

When `diarization` is `"speaker-turns"` or `"speaker-labels"`, the recognizer ends the active `SpeechRecognitionResult` whenever a speaker turn change is detected (in addition to normal pause endpointing or detected language changes; if `continuous` is `false`, the session's single result ends at the first detected speaker turn). `speakerChanged` is `false` for the first result of a session and for subsequent results from the *same* speaker, and `true` only when the speaker differs from the preceding result:

| Result | `speechStartTime` | `speechEndTime` | `speakerChanged` | `speaker` | `result[0].transcript` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 0 | `0.42` | `2.10` | `false` | `"1"` | `"Good morning. What brings you in today?"` |
| 1 | `2.65` | `6.80` | `true` | `"2"` | `"I've had a headache for about three days."` |
| 2 | `7.30` | `9.05` | `false` | `"2"` | `"It gets worse in the afternoon."` |
| 3 | `9.60` | `11.20` | `true` | `"1"` | `"Any nausea or sensitivity to light?"` |

*(Here, Result 2 starts after a pause by Speaker 2, so `speakerChanged` remains `false`.)*

While `result.isFinal` is `false` (`interimResults = true`), `speaker` and `speakerChanged` are provisional (`speaker` may initially be `null` on a newly heard voice or remain `null` on brief unattributable backchannels such as `"mm-hmm"`). Once `result.isFinal` is `true`, speaker metadata is immutable, just like the transcript—live streams balance finalization latency against attribution stability, while faster-than-realtime `AudioData` sessions ([PR #216](https://github.com/WebAudio/web-speech-api/pull/216)) can leverage buffered lookahead so finalized labels are consistent across an entire recording.

In `"speaker-labels"` mode, `minSpeakers` and `maxSpeakers` (`0` = no hint; ignored in other modes) guide speaker clustering: `minSpeakers` is an advisory hint, a non-zero `maxSpeakers` caps the number of distinct labels emitted (`"1"` … `maxSpeakers`), and `start()` throws a `RangeError` if both are non-zero and `minSpeakers > maxSpeakers`.

#### Example 1: Live Meeting Transcription with Feature Detection & On-Device Install

```javascript
async function chooseLocalDiarization(lang) {
  if (!('diarization' in SpeechRecognition.prototype)) return 'none';

  for (const mode of ['speaker-labels', 'speaker-turns']) {
    const options = { langs: [lang], processLocally: true, diarization: mode };
    const status = await SpeechRecognition.available(options);
    if (status === 'available') return mode;
    if (status !== 'unavailable') {
      try {
        if (await SpeechRecognition.install(options)) return mode;
      } catch {
        // install() rejects with NotAllowedError if transient activation was consumed.
      }
    }
  }
  return 'none';
}

const recognition = new SpeechRecognition();
recognition.lang = 'en-US';
recognition.continuous = true;
recognition.interimResults = true;
recognition.processLocally = true;
recognition.maxSpeakers = 6;

recognition.onresult = (event) => {
  // Group consecutive pause-split results from the same speaker into one turn.
  const turns = [];
  for (const result of event.results) {
    const text = result[0].transcript.trim();
    if (turns.length === 0 || result.speakerChanged) {
      turns.push({
        speaker: result.speaker,
        startTime: result.speechStartTime,
        endTime: result.speechEndTime,
        text,
      });
    } else {
      const current = turns.at(-1);
      current.text += ' ' + text;
      current.endTime = result.speechEndTime;
      current.speaker ??= result.speaker;
    }
  }
  renderTranscriptTurns(turns);
};

let fallbackWithoutDiarization = false;
recognition.onerror = (event) => {
  if (event.error === 'diarization-not-supported' && recognition.diarization !== 'none') {
    fallbackWithoutDiarization = true;
  }
};
recognition.onend = () => {
  if (!fallbackWithoutDiarization) return;
  fallbackWithoutDiarization = false;
  recognition.diarization = 'none';
  recognition.start();
};

startButton.onclick = async () => {
  if ('diarization' in recognition) {
    recognition.diarization = await chooseLocalDiarization('en-US');
  }
  recognition.start();
};
```

#### Example 2: Automated Multi-Speaker Subtitling (`WebVTT` `<v>` Voice Spans)

```javascript
const mediaElement = document.querySelector('video');
const track = mediaElement.addTextTrack('captions', 'English', 'en');
track.mode = 'showing';

const recognition = new SpeechRecognition();
recognition.lang = 'en-US';
recognition.continuous = true;
recognition.interimResults = false;
recognition.processLocally = true;
recognition.diarization = 'speaker-labels';
recognition.maxSpeakers = 4;

// Result timestamps are offsets from when recognition began consuming the track (#213).
// Pausing or seeking mediaElement requires starting a new recognition session
// (a paused track continues emitting silence), which also resets labels to "1".
const mediaOffset = mediaElement.currentTime;
const [audioTrack] = mediaElement.captureStream().getAudioTracks();
recognition.start(audioTrack);

recognition.onresult = (event) => {
  for (let i = event.resultIndex; i < event.results.length; ++i) {
    const result = event.results[i];
    if (!result.isFinal) continue;

    const text = result[0].transcript.trim();
    const vttText = result.speaker ? `<v Speaker ${result.speaker}>${text}` : text;

    track.addCue(new VTTCue(
      mediaOffset + result.speechStartTime,
      mediaOffset + result.speechEndTime,
      vttText
    ));
  }
};
```

---

### Security and Privacy Considerations

#### Non-Biometric, Ephemeral Session Scope
* This API performs **intra-session relative turn clustering**, not biometric speaker identification, verification, or voiceprint enrollment.
* Voice representations exist solely in memory for a single `SpeechRecognition` session (restarting at `"1"` on every `start()` call) and are purged immediately when the session ends, is aborted, or the document unloads. Raw speaker embeddings are never exposed to JavaScript and are never matched against OS, browser, or cloud user profiles.

#### Data Minimization Compared with Status-Quo Workarounds
* Today, web applications that want local speaker diarization must capture raw microphone PCM via `getUserMedia()` and compute speaker embeddings directly in page script/WebAssembly—where voice representations can be retained or exfiltrated—or send raw audio to third-party servers. Keeping voice representations isolated inside the user agent and surfacing only ephemeral, session-scoped labels (`"1"`, `"2"`) is a net privacy improvement.

#### Fingerprinting Risk & Mitigation
* **Canonical Label Format:** User agents normalize `speaker` to canonical 1-indexed decimal strings (`"1"`, `"2"`, `"3"`, ...) ordered by first appearance, preventing engine-specific label prefixes (e.g. `"spk_0"` vs. `"SPEAKER_01"`) from acting as a backend fingerprinting vector.
* **Storage-Key Download Masking & Audio Timeline Offsets:** `SpeechRecognition.available()` exposes only standard `SpeechRecognitionAvailabilityStatus` values subject to storage-key download masking ([PR #165](https://github.com/WebAudio/web-speech-api/pull/165)), and turn boundaries reuse `speechStartTime` and `speechEndTime` on the session audio timeline without adding any new timing side channel beyond [PR #192](https://github.com/WebAudio/web-speech-api/pull/192).

#### Permissions Policy & Multi-Party Privacy
* **Bystander & Multi-Party Impact:** Because diarization characterizes voices of secondary speakers or nearby bystanders who may not have interacted directly with the page, ephemeral session scoping prevents cross-session voiceprint tracking of non-consenting parties, while applications remain responsible for multi-party transcription indicators where appropriate.
* **Permissions Policy Gating:** Diarization inherits `SpeechRecognition`'s existing permissions and policy controls—including `"microphone"` for live capture and `"on-device-speech-recognition"` (default allowlist `'self'`, [PR #165](https://github.com/WebAudio/web-speech-api/pull/165)) when `processLocally` is `true`—failing with `"service-not-allowed"` (or `"not-allowed"`) in disallowed cross-origin iframes.

---

### Alternatives Considered

- **Placing `speaker` on `SpeechRecognitionAlternative`:** Rejected because acoustic speaker attribution describes the audio segment rather than individual lexical N-best hypotheses (`result[0]`, `result[1]`). Attaching `speaker` to `SpeechRecognitionResult` matches `speechStartTime` / `speechEndTime` ([PR #192](https://github.com/WebAudio/web-speech-api/pull/192)) and `lang` ([Issue #208](https://github.com/WebAudio/web-speech-api/issues/208)).
- **A boolean `diarization` flag without a `"speaker-turns"` tier:** Rejected because turn segmentation alone serves live captioning (`>>`), costs less compute and memory, and requires no per-speaker voice embeddings—allowing user agents and applications to use `"speaker-turns"` even where full clustering is unavailable.
- **Folding diarization into `SpeechRecognitionQuality` (`quality: "conversation"`):** `"conversation"` ([PR #186](https://github.com/WebAudio/web-speech-api/pull/186)) describes acoustic robustness to multi-speaker and noisy audio; diarization changes result segmentation, carries distinct privacy properties, and requires separate model resources that should be explicitly requested and feature-detectable.
- **Emitting transient DOM events (`onspeakerchange`) without `SpeechRecognitionResult` attributes:** Decouples speaker attribution from the cumulative `event.results` list, forcing applications to maintain fragile external state across streaming interim updates (mirroring why `speech-recognition-result-timestamps.md` rejected `resultstart` / `resultend` events).
- **Exposing speaker embeddings or cross-session label continuity:** Rejected. Retaining voice representations across sessions or exposing raw embeddings to script would create cross-session voiceprint tracking risks.
