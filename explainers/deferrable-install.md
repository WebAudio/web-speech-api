# Explainer: Deferrable Web Speech API Model Installation

## Introduction

On-device speech recognition via the Web Speech API requires machine learning speech models to be downloaded and installed locally before processing audio. These models typically range from tens to hundreds of megabytes in size.

Currently, developers can use `SpeechRecognition.install()` to trigger an immediate download, similar to a file download or `fetch()` request. When invoked during active user sessions—such as an ongoing WebRTC video conference—a high-bandwidth download can compete with real-time network traffic, leading to audio/video stuttering and reduced media quality. Immediate downloads also risk impacting end-user networks if they can be triggered in a coordinated manner, such as an application everyone launches when they get to work at 9 o’clock.

This explainer proposes adding a new `downloadPriority` hint to `SpeechRecognitionOptions` to allow sites to express whether they instead need the model to be available as soon as possible (`"immediate"`) because model availability blocks a critical user journey or whether it is okay for the feature to be available later (`"deferrable"`). Deferrable installation allows the browser to complete the download more slowly or during idle time, leveraging the same mechanisms used for browser updates to reduce its impact. 

## User Needs & Goals

### User Need

Users expect real-time web applications (e.g., video calling, live streaming) to remain smooth and responsive. Unintended high-bandwidth network activity during an active session degrades media quality, particularly on constrained or low-bandwidth connections.

### Developer Need

Developers want to offer fast, private, on-device features, but need a safe way to prepare on-device assets opportunistically. When a fallback capability (such as cloud-based speech recognition) is available, developers can request background downloads to avoid network contention. Conversely, developers need to be able to express when on-device processing blocks a critical user journey and it is therefore worth elevating the priority of the download to that of a typical user-initiated file download.

### Goals

*   Enable developers to express that the deferrable download model is compatible with their desired user experience.
*   Provide an explicit `"immediate"` hint for when model availability blocks a critical user journey.

### Non-Goals

*   Guaranteeing exact completion times or strict scheduling guarantees for downloads.

## Proposed API Design

We propose adding a `downloadPriority` hint to the options dictionary passed to `install()` (extending `SpeechRecognitionOptions`), defaulting to `"immediate"` to maintain the current default behavior:

```
enum SpeechRecognitionDownloadPriority {
  "immediate",
  "deferrable",
};

dictionary SpeechRecognitionInstallOptions : SpeechRecognitionOptions {
  SpeechRecognitionDownloadPriority downloadPriority = "immediate";
};

partial interface SpeechRecognition {
  static Promise<undefined> install(SpeechRecognitionInstallOptions options);
};
```

## Example

This example illustrates initiating a deferrable model installation in the background while immediately falling back to cloud-based speech recognition:

```javascript
// Trigger deferrable model download in background.
SpeechRecognition.install({ downloadPriority: "deferrable" }).catch(err => {
  console.warn("Background model download failed:", err);
});

// Continue with speech recognition immediately without waiting.
const recognition = new SpeechRecognition();
recognition.start();
```

## Detailed Design Considerations

### Browser Download Scheduling

Browsers already possess infrastructure to handle deferred, low-priority downloads (such as component updates and system updates) in order to avoid the scenarios listed above.

When `downloadPriority` is set to `"deferrable"`:

*   The download state for the origin is unmasked upfront. Therefore if the model is already available, `install({ downloadPriority: "deferrable" })` will resolve immediately.
*   Downloading may automatically pause while the browser is in use and resume when idle.
*   The browser may delegate downloads to the underlying system’s networking service to pick a time when the system as a whole is idle.
*   Promise resolution continues to operate normally, though no progress may be made until conditions permit downloading.
*   A later call to `install({ downloadPriority: "immediate" })` overrides this request and begins an immediate download.

Since deferrable downloads may be significantly delayed in starting and finishing they should survive tab closure. In future sessions the developer will either observe `SpeechRecognition.availability()` return `"downloading"` or `"available"` depending on whether the install is complete.

### Immediate Downloads

When `downloadPriority` is set to `"immediate"` (the default) the browser treats the download request as a typical resource load or file download. This preserves expected behavior for interactive flows where the user is actively waiting for a local model to complete installation before continuing. If the page is closed before the download completes the download priority could be reduced so that the model is available in a future user session but is no longer a priority.   

## Alternate Designs

### Alternative 1: Deferrable downloads by default

**Description:** Change the default behavior and require developers to explicitly choose immediate downloads.

**Why Rejected:** While this option makes mitigating the concerns of immediate downloads the default behavior, it is a breaking change to existing developer expectations as `install()` with no priority option would now rarely resolve during the current session. By default, a Web API should not return a Promise that may never resolve during the user's session without giving the developer progress or scheduling visibility. When a site calls `install()` without specifying a priority, the browser should fulfill that request immediately like any standard network fetch, rather than silently deferring it to an unknown future idle window.

### Alternative 2: Triggering installs on page unload

**Description:** Having applications wait until they are idle or the user is about to navigate away before calling `install()`.

**Why Rejected:** Unreliable. Users frequently close browser tabs or windows directly, which doesn’t give the page time to call `install()`. An explicit API parameter allows the browser to manage the download lifetime across tab closure or background states cleanly.

## Security Considerations

The background scheduling and priority do not alter the origin sandbox model or grant new access to system resources. Origin-based capability masking remains enforced to prevent untrusted cross-origin access to installed models.

## Privacy Considerations

The download masking technique is unmodified, so a site still needs to call `install()` with user activation to unmask the model download state. There is a potential minor benefit in the transition between `"downloading"` and `"available"` states now likely occurring when there isn't a page context around to observe it.
