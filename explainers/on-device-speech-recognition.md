# Explainer: On-Device Speech Recognition for the Web Speech API

## Introduction

The Web Speech API is a powerful browser feature that enables applications to perform speech recognition. Traditionally, this functionality relies on sending audio data to cloud-based services for recognition. While this approach is effective, it has certain drawbacks:

- **Privacy concerns:** Raw and transcribed audio is transmitted over the network.
- **Latency issues:** Users may experience delays due to network communication.
- **Offline limitations:** Speech recognition does not work without an internet connection.

To address these issues, we introduce **on-device speech recognition capabilities** as part of the Web Speech API. This enhancement allows speech recognition to run locally on user devices, providing a faster, more private, and offline-compatible experience.

## Why Use On-Device Speech Recognition?
 
### 1. **Privacy**
On-device processing ensures that neither raw audio nor transcriptions leave the user's device, enhancing data security and user trust.

### 2. **Performance**
Local processing reduces latency, providing a smoother and faster user experience.

### 3. **Offline Functionality**
Applications can offer speech recognition capabilities even without an active internet connection, increasing their utility in remote or low-connectivity environments.
## New API Members

This enhancement introduces new members to the Web Speech API to support on-device recognition:

*   An instance attribute `processLocally` on the `SpeechRecognition` object to control processing for individual recognition sessions.
*   A `SpeechRecognitionOptions` dictionary used for querying and installing on-device capabilities.
*   Static methods `SpeechRecognition.available()` and `SpeechRecognition.install()` for managing these capabilities.

### Controlling On-Device Processing for a Session

To instruct a specific speech recognition session to be performed on-device, the `processLocally` attribute on the `SpeechRecognition` instance is used.

- `SpeechRecognition.processLocally` (`boolean`): When set to `true`, it mandates that the recognition for this particular session occurs on the user's device. If `false` (the default), the user agent can select any available recognition method (local or cloud-based).

#### Example: Requesting On-Device for a Single Session
```javascript
const recognition = new SpeechRecognition();
recognition.processLocally = true; // Instruct this session to run on-device
recognition.start();
```

### `SpeechRecognitionOptions` Dictionary

This dictionary is used to configure speech recognition preferences, both for individual sessions and for querying or installing capabilities.

It includes the following members:

- `processLocally`: A boolean that, if `true`, instructs the recognition to be performed on-device. If `false` (the default), any available recognition method (cloud-based or on-device) may be used.

```idl
dictionary SpeechRecognitionOptions {
  boolean processLocally = false;  // Instructs the recognition to be performed on-device. If `false` (default), any available recognition method may be used.
};
```

## Example use cases
### 1. Company with data residency requirements
Websites with strict data residency requirements (i.e., regulatory, legal, or company policy) can ensure that audio data remains on the user's device and is not sent over the network for processing. This is particularly crucial for compliance with regulations like GDPR, which considers voice as personally identifiable information (PII) as voice recordings can reveal information about an individual's gender, ethnic origin, or even potential health conditions. On-device processing significantly enhances user privacy by minimizing the exposure of sensitive voice data.

### 2. Video conferencing service with strict performance requirements (e.g. meet.google.com)
Some websites would only adopt the Web Speech API if it meets strict performance requirements. On-device speech recognition may provide better accuracy and latency as well as provide additional features (e.g. contextual biasing) that may not be available by the cloud-based service used by the user agent. In the event on-device speech recognition is not available, these websites may elect to use an alternative cloud-based speech recognition provider that meet these requirements instead of the default one provided by the user agent.

### 3. Educational website (e.g. khanacademy.org)
Applications that need to function in unreliable or offline network conditions—such as voice-based productivity tools, educational software, or accessibility features—benefit from on-device speech recognition. This enables uninterrupted functionality during flights, remote travel, or in areas with limited connectivity. When on-device recognition is unavailable, a website can choose to hide the UI or gracefully degrade functionality to maintain a coherent user experience.

## New Methods

### 1. `static Promise<AvailabilityStatus> SpeechRecognition.available(SpeechRecognitionOptions options)`
This static method checks the availability of speech recognition capabilities matching the provided `SpeechRecognitionOptions`.

The method returns a `Promise` that resolves to an `AvailabilityStatus` enum string:
- `"available"`: Ready to use according to the specified options.
- `"downloadable"`: Not currently available, but resources (e.g., language packs for on-device) can be downloaded.
- `"downloading"`: Resources are currently being downloaded.
- `"unavailable"`: Not available and not downloadable.

#### Example Usage
```javascript
// Check availability for on-device English (US)
const options = { langs: ['en-US'], processLocally: true };

SpeechRecognition.available(options).then((status) => {
    console.log(`Speech recognition status for ${options.langs.join(', ')} (on-device): ${status}.`);
    if (status === 'available') {
        console.log('Ready to use on-device speech recognition.');
    } else if (status === 'downloadable') {
        console.log('Resources are downloadable. Call install() if needed.');
    } else if (status === 'downloading') {
        console.log('Resources are currently downloading.');
    } else {
        console.log('Not available for on-device speech recognition.');
    }
});
```

### 2. `Promise<boolean> install(SpeechRecognitionOptions options)`
This method installs the resources required for speech recognition matching the provided `SpeechRecognitionOptions`. The installation process may download and configure necessary language models.

#### Example Usage
```javascript
// Install on-device resources for English (US)
const options = { langs: ['en-US'], processLocally: true };
SpeechRecognition.install(options).then((success) => {
    if (success) {
        console.log(`On-device speech recognition resources for ${options.langs.join(', ')} installed successfully.`);
    } else {
        console.error(`Unable to install on-device speech recognition resources for ${options.langs.join(', ')}. This could be due to unsupported languages or download issues.`);
    }
});
```

## Privacy considerations
To reduce the risk of fingerprinting, user agents must implement privacy-preserving countermeasures. The Web Speech API will employ the same masking techniques used by the [Web Translation API](https://github.com/webmachinelearning/writing-assistance-apis/pull/47).

## Conclusion
The addition of on-device speech recognition capabilities to the Web Speech API marks a significant step forward in creating more private, performant, and accessible web applications. By leveraging these new methods, developers can enhance user experiences while addressing key concerns around privacy and connectivity.
