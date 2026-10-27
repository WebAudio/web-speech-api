# Speech recognition on `AudioData`

**Author:** Paul Adenot (padenot@mozilla.com)

## Problem

`SpeechRecognition` takes audio from the microphone or a `MediaStreamTrack`. Both are real time. Transcribing a 1h recording takes 1h, and requires playing it back (e.g. `captureStream()` or a `MediaStreamAudioDestinationNode`).

Authors often already have the audio: a file, a WebCodecs `AudioDecoder` output, samples generated or processed in script. It should be possible to feed it to a recognizer as fast as the recognizer can go.

## Proposal

1. `start()` takes an options object that says where the audio comes from.
2. A new source, `"audio-data"`, where the author pushes `AudioData` objects.
3. Backpressure mirrors WebCodecs: a queue size and a `dequeue` event.

Getting results is unchanged: `result`, `error`, `end`, etc.

```webidl
dictionary SpeechRecognitionStartOptions {
  (SpeechRecognitionSource or MediaStreamTrack) source = "microphone";
};

enum SpeechRecognitionSource { "microphone", "audio-data" };

partial interface SpeechRecognition {
  undefined start(optional SpeechRecognitionStartOptions options = {});
  undefined start(MediaStreamTrack audioTrack); // existing, same as start({ source: audioTrack })

  undefined processAudio(AudioData data);
  readonly attribute unsigned long audioQueueSize;
  attribute EventHandler ondequeue;
};
```

Behavior:

- `processAudio()` throws `InvalidStateError` if the session is not started with `"audio-data"`. Like `AudioEncoder.encode()`, it clones `data`; the author can `close()` it right after.
- Any sample rate, channel count and format is accepted. The UA resamples and downmixes as needed. These can change between calls.
- Audio is processed as fast as possible, not paced in real time. There are no wall-clock based timeouts (`no-speech` is determined from the audio, not elapsed time).
- `stop()` signals the end of the input. Queued audio is processed, final results are delivered, then `end` fires. `abort()` drops the queue.
- No microphone permission is requested, same as for `MediaStreamTrack`. The existing non-personalization requirement applies.
- [Result timestamps](speech-recognition-result-timestamps.md) are in the `AudioData` timeline: `speechStartTime` and `speechEndTime` are `timestamp / 1e6` of the corresponding audio, not an offset from the first chunk. Results map directly back to the media, regardless of where ingestion started (e.g. after a seek).

## Examples

Transcribe a file, with backpressure:

```js
const recognition = new SpeechRecognition();
recognition.lang = "en-US";
recognition.continuous = true;
recognition.processLocally = true;
recognition.onresult = (e) => {
  for (let i = e.resultIndex; i < e.results.length; i++) {
    if (e.results[i].isFinal) console.log(e.results[i][0].transcript);
  }
};
recognition.onend = () => console.log("done");

recognition.start({ source: "audio-data" });

const file = await (await fetch("talk.opus")).arrayBuffer();
const buffer = await new OfflineAudioContext(1, 1, 16000).decodeAudioData(file);
const samples = buffer.getChannelData(0);

for (let i = 0; i < samples.length; i += buffer.sampleRate) {
  const data = samples.subarray(i, i + buffer.sampleRate);
  const audio = new AudioData({
    format: "f32-planar",
    sampleRate: buffer.sampleRate,
    numberOfChannels: 1,
    numberOfFrames: data.length,
    timestamp: (i / buffer.sampleRate) * 1e6,
    data,
  });
  while (recognition.audioQueueSize > 8) {
    await new Promise((r) => recognition.addEventListener("dequeue", r, { once: true }));
  }
  recognition.processAudio(audio);
  audio.close();
}
recognition.stop();
```

Straight out of an `AudioDecoder` (demuxing elided):

```js
recognition.start({ source: "audio-data" });

const decoder = new AudioDecoder({
  output(audio) {
    recognition.processAudio(audio);
    audio.close();
  },
  error(e) { console.error(e); },
});
decoder.configure(config);
for (const chunk of chunks) decoder.decode(chunk);
await decoder.flush();
recognition.stop();
```

## Open questions

- Gaps and overlaps in `AudioData` timestamps: treat gaps as silence? Reject overlaps?
- Exposing `SpeechRecognition` in workers, where decoding usually happens.
- Naming: `processAudio()` is close to `processLocally`. `appendAudio()`, `recognize()`?

## Alternatives considered

- **A third `start()` overload** (e.g. `start(ReadableStream<AudioData>)`). Keeps overloading `start()` for configuration, which doesn't scale. A stream can be layered on top of `processAudio()` in a few lines.
- **`MediaStreamTrackGenerator`** to turn `AudioData` into a track, then `start(track)`. Still real time, and there is no standard audio track generator.
- **`AudioBuffer` input.** `AudioData` is what WebCodecs produces and carries a timestamp. `AudioBuffer` converts to `AudioData` trivially.
