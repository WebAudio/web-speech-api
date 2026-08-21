# Web Speech API Proposal: SpeechRecognitionResult Timestamps

**Author:** alanding@google.com, evliu@google.com

### Problem

The Web Speech API currently does not expose the start and end timestamps of the source audio corresponding to a given transcription result (`SpeechRecognitionResult`). This limitation creates two major challenges for API clients and end users:

- **Timeline Association:** Developers cannot readily associate transcribed text with specific segments of the audio source, making it difficult to map generated captions to media timelines, audio tracks, or video frames.
- **Latency Tracking & Backend Failover:** With the adoption of on-device Automatic Speech Recognition (ASR) to improve privacy and reduce server costs, processing performance becomes heavily dependent on local client hardware resources. The Web Speech API acts as a "black box" regarding local processing delays. Developers cannot programmatically calculate transcription latency or detect when on-device models fall behind real-time. This leads to poor user experiences (e.g. caption lag during live video conferencing) and deprives applications of the signal needed to seamlessly fail over to high-performance cloud backends.

### Proposed Solution

We propose extending the `SpeechRecognitionResult` interface to include `audioStartTime` and `audioEndTime` attributes.

#### Web IDL Definition

```webidl
partial interface SpeechRecognitionResult {
    // Start timestamp of the audio segment in seconds relative to the start of the audio stream (0.0s).
    readonly attribute double audioStartTime;

    // End timestamp of the audio segment in seconds relative to the start of the audio stream.
    readonly attribute double audioEndTime;
};
```

### Choice of Time Representation: Seconds as `double`

The timestamps `audioStartTime` and `audioEndTime` are defined as `double` representing **seconds**, rather than `DOMHighResTimeStamp` (milliseconds). This design choice is based on the following considerations:

1. **Consistency with Adjacent Web Audio & Media APIs:**
   * In adjacent W3C media specifications, media-local stream timelines are universally represented in **seconds** as a `double`:
     * **Web Audio API:** [`BaseAudioContext.currentTime`](https://webaudio.github.io/web-audio-api/#dom-baseaudiocontext-currenttime) (seconds)
     * **HTML Media Elements:** [`HTMLMediaElement.currentTime`](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime) (seconds)
     * **AudioParam Scheduling:** [`AudioParam.setValueAtTime()`](https://webaudio.github.io/web-audio-api/#dom-audioparam-setvalueattime) (seconds)
   * Using seconds ensures seamless interoperability when developers route audio between `<audio>`/`<video>` elements, Web Audio graphs, and `SpeechRecognition`, avoiding repetitive and error-prone unit conversions ($1000\times / \div 1000$).

2. **Semantic Inaccuracy of `DOMHighResTimeStamp` for Media Streams:**
   * Under the [W3C High Resolution Time Level 3](https://www.w3.org/TR/hr-time-3/#sec-domhighrestimestamp) specification, `DOMHighResTimeStamp` is strictly defined as a time coordinate in **milliseconds** measured relative to the global execution context's time origin (`performance.timeOrigin`).
   * Because `audioStartTime` and `audioEndTime` represent a **media-local timeline** (elapsed time starting at $0.0\text{s}$ at the beginning of the audio stream) rather than document uptime, using `DOMHighResTimeStamp` would be semantically incorrect.

3. **Numerical Precision:**
   * A standard 64-bit IEEE 754 floating-point number (`double`) in seconds provides sub-nanosecond resolution across hours of continuous audio streaming, ensuring sample-accurate precision at any audio sample rate (e.g. 16 kHz to 96 kHz).

4. **W3C TAG Design Principles Alignment:**
   * This design adheres to the [W3C TAG Design Principles on Times and Dates](https://w3ctag.github.io/design-principles/#times-and-dates), ensuring consistency across media stream APIs on the web platform.

---

### Proposed Behavior & Example Usage

The `audioStartTime` and `audioEndTime` properties represent the audio duration bounds (in seconds) corresponding to the transcribed segment.

Developers can programmatically compute processing latency by converting the stream timestamp to the document timeline and comparing against `Event.timeStamp`:

```javascript
const recognition = new SpeechRecognition();
recognition.continuous = true;
recognition.interimResults = true;

let audioOriginMs = 0;

// 1. Capture the audio stream's start timestamp on the document timeline
recognition.onaudiostart = (event) => {
  audioOriginMs = event.timeStamp;
};

recognition.onresult = (event) => {
  const result = event.results[event.resultIndex];

  // 2. Convert stream-relative seconds to document timeline milliseconds
  const absoluteAudioEndMs = audioOriginMs + (result.audioEndTime * 1000);

  // 3. Calculate on-device processing latency
  const processingLatencyMs = event.timeStamp - absoluteAudioEndMs;

  // 4. Trigger seamless failover to cloud backend if latency breaches acceptable threshold
  if (processingLatencyMs > 1500) {
    console.warn(`ASR processing lag detected (${processingLatencyMs.toFixed(0)}ms). Transitioning to cloud provider.`);
    switchToCloudBackend();
  }
};

recognition.start();
```

---

### Converting Stream Timestamps to Document Time Origin

`audioStartTime` and `audioEndTime` are defined as media-local offsets in seconds relative to the start of the audio stream ($t = 0.0\text{s}$).

For real-time applications such as **live translation**, **subtitling overlays**, and **audio-visual sync**, developers often need to map these stream offsets to the document's global timeline (`performance.timeOrigin` / `performance.now()`).

#### Pattern: Capturing the Audio Timeline Origin

To convert stream-relative timestamps to document time coordinates:
1. Record the baseline timestamp when the `audiostart` event fires (`event.timeStamp` is in milliseconds relative to `timeOrigin`).
2. Add the result's `audioStartTime` and `audioEndTime` offsets (converted to milliseconds) to that baseline:

$$\text{absoluteStartTimeMs} = \text{audioOriginMs} + (\text{result.audioStartTime} \times 1000)$$
$$\text{absoluteEndTimeMs} = \text{audioOriginMs} + (\text{result.audioEndTime} \times 1000)$$

#### Measuring Live Translation Latency Example

In live speech translation workflows, measuring both **Speech-to-Text (STT) latency** and **Machine Translation (MT) end-to-end latency** is essential:

```javascript
const recognition = new SpeechRecognition();
recognition.continuous = true;
recognition.interimResults = true;

let audioOriginTimeMs = 0;

// 1. Capture the audio stream's time origin on the document timeline
recognition.onaudiostart = (event) => {
  audioOriginTimeMs = event.timeStamp;
};

recognition.onresult = async (event) => {
  const result = event.results[event.resultIndex];

  // 2. Convert stream offsets (seconds) to document timeline (milliseconds)
  const absoluteAudioStartMs = audioOriginTimeMs + (result.audioStartTime * 1000);
  const absoluteAudioEndMs = audioOriginTimeMs + (result.audioEndTime * 1000);

  // 3. Compute ASR recognition latency
  const asrLatencyMs = event.timeStamp - absoluteAudioEndMs;

  // 4. Perform live translation
  const text = result[0].transcript;
  const translationStartTime = performance.now();
  const translatedText = await translateService.translate(text, 'es');
  const translationEndTime = performance.now();

  // 5. Total end-to-end latency from speaker utterance to translated subtitle
  const totalE2ELatencyMs = translationEndTime - absoluteAudioEndMs;

  console.log(`ASR Processing Time: ${asrLatencyMs.toFixed(1)}ms`);
  console.log(`Total Live Translation Delay: ${totalE2ELatencyMs.toFixed(1)}ms`);
};

recognition.start();
```

---

### Security and Privacy Considerations

#### Fingerprinting Risk
Exposing sub-millisecond or precise micro-architectural timing information enables hardware profiling (measuring CPU execution speed, thermal throttling, and system load), creating a potential tracking vector for cross-origin user fingerprinting.

#### Mitigation Strategy
To mitigate potential side-channel and fingerprinting vectors:
* **Precedent:** Implementations (such as Chromium) follow the security posture established by [`HTMLMediaElement.currentTime`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/currentTime), coarsening raw engine timestamps to discrete resolution buckets (e.g. 2ms resolution) in non-isolated execution contexts.
* **Specification Precedent:** In accordance with [W3C High Resolution Time Level 3](https://www.w3.org/TR/hr-time-3/#privacy-security), the specification does not mandate a hardcoded quantization value, allowing user agents to adjust timer resolution or introduce jitter according to their security and cross-origin isolation policies.

---

### Alternatives Considered

- **Browser-Generated Warning Events (`onprocessinglag`):** Simple for web applications to catch, but fails to accommodate varying latency thresholds across different use cases (e.g. real-time meeting captioning requires <200ms latency, while dictation tools tolerate multi-second delays).
- **Internal Processing Queue Metric (`queueDepth`):** Directly exposes engine backlogs, but is difficult to standardize across fragmented engine architectures, model types, and buffering strategies.
- **Binary Status Flag (`isRealTime`):** Simple boolean check, but lacks numerical precision for applications seeking to track progressive latency degradation trendlines.
- **Existing API Surfaces (Events):** Existing events were deemed insufficient because:
  1. **`speechstart` and `speechend` Events:**
     The Web Speech API specification defines `speechstart` and `speechend` events on the `SpeechRecognition` interface. However, these events cannot solve the continuous latency tracking problem:
     * **Session-level vs. Result-level Granularity:** In continuous recognition mode, `speechstart` and `soundstart` fire once when voice activity is first detected at the beginning of the session. They do not fire for every individual phrase or sentence returned in subsequent `SpeechRecognitionResult` events.
     * **Inequality with Result Audio Boundaries:** Because `speechstart` only marks initial voice activity, `speechstart.timeStamp` is not equal to `result.audioStartTime` for any subsequent utterance emitted throughout a session.
     * **Fragile Event Correlation:** Even if engines fired `speechstart`/`speechend` around each phrase, associating separate asynchronous DOM events with streaming interim and final `SpeechRecognitionResult` objects requires complex, error-prone client-side state tracking (poor ergonomics).
  2. **Overloading `event.timeStamp` on Result Events:**
     Another alternative considered was modifying `event.timeStamp` on the `result` event to match the speech timing:
     * **Eliminates Latency Calculation:** `event.timeStamp` indicates when the browser dispatched the DOM event on the document timeline. Keeping `event.timeStamp` intact while providing `result.audioEndTime` allows web applications to measure processing delay:
       $$\text{latencyMs} = \text{event.timeStamp} - (\text{audioOriginMs} + \text{result.audioEndTime} \times 1000)$$
     * Overwriting `event.timeStamp` would conflate acoustic timing with main-thread dispatch time, eliminating the ability to detect processing lag.

Attaching `audioStartTime` and `audioEndTime` directly to `SpeechRecognitionResult` provides a 1:1 association between the recognized transcript text and its corresponding acoustic timeline.
