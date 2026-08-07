# Web Speech API Proposal: SpeechRecognitionResult Timestamps

**Author:** alanding@google.com, evliu@google.com

### Problem

The Web Speech API currently does not expose the start and end timestamps of the source audio corresponding to a given transcription result (`SpeechRecognitionResult`). This limitation creates two major challenges for API clients and end users:

- **Timeline Association:** Developers cannot readily associate transcribed text with specific segments of the audio source, making it difficult to map generated captions to media timelines or audio tracks.
- **Latency Tracking & Backend Failover:** With the adoption of on-device Automatic Speech Recognition (ASR) to improve privacy and reduce server costs, processing performance becomes heavily dependent on local client hardware resources. The Web Speech API acts as a "black box" regarding local processing delays. Developers cannot programmatically calculate transcription latency or detect when on-device models fall behind real-time. This leads to poor user experiences (e.g. caption lag during live video conferencing) and deprives applications of the signal needed to seamlessly fail over to high-performance cloud backends.

### Proposed Solution

We propose extending the `SpeechRecognitionResult` interface to include optional (nullable) `audioStartTime` and `audioEndTime` attributes.

#### Web IDL Definition

```webidl
partial interface SpeechRecognitionResult {
    // Start timestamp of the audio segment in milliseconds (relative to time origin)
    readonly attribute DOMHighResTimeStamp? audioStartTime;

    // End timestamp of the audio segment in milliseconds (relative to time origin)
    readonly attribute DOMHighResTimeStamp? audioEndTime;
};
```

### Proposed Behavior & Example Usage

The `audioStartTime` and `audioEndTime` properties represent the audio duration bounds (in milliseconds) corresponding to the transcribed segment. If the underlying recognition engine backend does not support segment timestamps, these attributes return `null`.

Developers can programmatically compute processing latency by comparing `audioEndTime` against the standard DOM event generation timestamp (`Event.timeStamp`):

```javascript
const recognition = new SpeechRecognition();
recognition.continuous = true;
recognition.interimResults = true;

recognition.onresult = (event) => {
  const result = event.results[event.resultIndex];

  if (result.audioEndTime !== null) {
    // Calculate on-device processing latency
    const processingLatencyMs = event.timeStamp - result.audioEndTime;

    // Trigger seamless failover to cloud backend if latency breaches acceptable threshold
    if (processingLatencyMs > 1500) {
      console.warn(`ASR processing lag detected (${processingLatencyMs}ms). Transitioning to cloud provider.`);
      switchToCloudBackend();
    }
  }
};

recognition.start();
```

### Security and Privacy Considerations

#### Fingerprinting Risk
Exposing sub-millisecond or precise micro-architectural timing information enables hardware profiling (measuring CPU execution speed, thermal throttling, and system load), creating a tracking vector for cross-origin user fingerprinting.

#### Mitigation Strategy
To mitigate fingerprinting vectors, browser implementations MUST apply timestamp fuzzing and precision reduction before exposing timing attributes to web scripts. We propose mirroring the precision capping strategy used in [`HTMLMediaElement.currentTime`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/currentTime), rounding exposed timestamps to **2ms** precision (or matching the site-wide timer resolution policy).

### Alternatives Considered

- **Browser-Generated Warning Events (`onprocessinglag`):** Simple for web applications to catch, but fails to accommodate varying latency thresholds across different use cases (e.g. real-time meeting captioning requires <200ms latency, while dictation tools tolerate multi-second delays).
- **Internal Processing Queue Metric (`queueDepth`):** Directly exposes engine backlogs, but is difficult to standardize across fragmented engine architectures, model types, and buffering strategies.
- **Binary Status Flag (`isRealTime`):** Simple boolean check, but lacks numerical precision for applications seeking to track progressive latency degradation trendlines.
