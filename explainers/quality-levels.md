# Web Speech API Proposal: On-Device Speech Recognition Quality Levels

**Author:** evliu@google.com

### Problem

The recent updates to the Web Speech API enabling on-device speech recognition (via `processLocally: true`) are a significant step forward for privacy and latency. However, the current API treats all on-device models as functionally equivalent.

In reality, on-device models vary drastically in capability. A lightweight model optimized for voice commands (e.g., "turn on the lights") is insufficient for high-stakes use cases like video conferencing transcription or accessibility captioning, which require handling continuous speech, multiple speakers, and background noise.

Currently, developers have no way to query if the local device is capable of handling these complex tasks. Because they cannot verify the *quality* of the on-device model, applications like Google Meet must often default to Cloud-based recognition to guarantee a minimum user experience. This effectively negates the privacy and bandwidth benefits of the on-device API for high-end use cases.

### Proposed Solution

I propose extending the `SpeechRecognitionOptions` dictionary (used in `SpeechRecognition.available()` and `SpeechRecognition.install()`) to include a `quality` field.

This field uses a "Levels" approach—similar to video codec profiles—to describe the task complexity the model can handle, rather than raw accuracy numbers.

#### WebIDL Definition

```webidl
enum SpeechRecognitionQuality {
   "command",      // Level 1: Short phrases, single speaker, limited vocab (e.g. Smart Home)
   "dictation",    // Level 2: Continuous speech, moderate noise, single primary speaker (e.g. SMS/Email)
   "conversation"  // Level 3: Multi-speaker, complex vocab, high noise tolerance (e.g. Meetings/Captions)
};

dictionary SpeechRecognitionOptions {
   required sequence<DOMString> langs;
   boolean processLocally = false;
   
   // New optional field. Defaults to "command" (lowest bar) if omitted.
   SpeechRecognitionQuality quality = "command";  
};
```

### Proposed Behavior

The `quality` field acts as a hard constraint, similar to `langs`.

1. **SpeechRecognition.available(options):** Returns `true` only if the device has an installed model that meets or exceeds the requested quality level for the specified language.
2. **SpeechRecognition.install(options):** Attempts to download/install a model that meets the requested `quality`. If the device hardware is incapable of running a model of that complexity (e.g., lack of NPU or RAM), the promise should reject.

### Usage Example

This allows developers to write "progressive enhancement" logic that prefers on-device processing but falls back gracefully if the device isn't powerful enough.

```javascript
const meetConfig = {
  langs: ['en-US'],
  processLocally: true,
  // We specifically need a model capable of handling a meeting environment
  quality: 'conversation' 
};

async function setupSpeech() {
  // 1. Check if a high-quality model is already available
  const availability = await SpeechRecognition.available(meetConfig);
  
  if (availability == 'available') {
    startOnDeviceSpeech();
    return;
  }

  // 2. If not, try to install one
  try {
    await SpeechRecognition.install(meetConfig);
    startOnDeviceSpeech();
  } catch (e) {
    // 3. Fallback: Device hardware is too weak for "conversation" quality,
    // or user denied the download. Fallback to Cloud to ensure transcript usability.
    console.log("High-quality on-device model unavailable. Using Cloud.");
    startCloudSpeech();
  }
}
```

### Alternatives Considered

**1. Exposing Word Error Rate (WER) or Accuracy scores**
* *Proposal:* Allow developers to request `minAccuracy: 0.95`.
* *Why rejected:*
    * **Fingerprinting:** Precise accuracy metrics (e.g., 95.4%) are a high-entropy fingerprinting vector that can identify specific hardware/model versions.
    * **Future Proofing:** Accuracy metrics drift over time. A "95%" score on a 2025 test set might be considered poor performance in 2030.

**2. Relative Enums (Low, Medium, High)**
* *Proposal:* Allow developers to request `quality: 'high'`.
* *Why rejected:* "High" is relative to the device. "High" quality on a low-end smartwatch might still be insufficient for a meeting transcript. The API needs to guarantee an *absolute* floor of utility (Semantic Capability) rather than a relative hardware setting.

### Benefits

* **Privacy:** Applications can confidently use on-device models for complex tasks, keeping audio data off the cloud.
* **Predictability:** Developers know exactly what class of tasks the model can handle (e.g., `conversation` implies a higher level of accuracy).
* **Safety:** By grouping devices into coarse buckets (`command`, `dictation`, `conversation`), we minimize fingerprinting risks compared to exposing model versions or raw metrics.