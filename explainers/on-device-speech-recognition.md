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

## New Methods

### 1. `Promise<boolean> availableOnDevice(DOMString lang)`
This method checks if on-device speech recognition is available for a specific language. Developers can use this to determine whether to enable features that require on-device speech recognition.

#### Example Usage
```javascript
const lang = 'en-US';
SpeechRecognition.availableOnDevice(lang).then((available) => {
    if (available) {
        console.log(`On-device speech recognition is available for ${lang}.`);
    } else {
        console.log(`On-device speech recognition is not available for ${lang}.`);
    }
});
```

### 2. `Promise<boolean> installOnDevice(DOMString[] lang)`
This method install the resources required for on-device speech recognition for the given BCP-47 language codes. The installation process may download and configure necessary language models.

#### Example Usage
```javascript
const lang = 'en-US';
SpeechRecognition.installOnDevice([lang]).then((success) => {
    if (success) {
        console.log('On-device speech recognition resources installed successfully.');
    } else {
        console.error('Unable to install on-device speech recognition.');
    }
});
```

## New Attribute

### 1. `mode` attribute in the `SpeechRecognition` interface
The `mode` attribute in the `SpeechRecognition` interface defines how speech recognition should behave when starting a session.

#### `SpeechRecognitionMode` Enum

- **"on-device-preferred"**: Use on-device speech recognition if available. If not, fall back to cloud-based speech recognition.
- **"on-device-only"**: Only use on-device speech recognition. If it's unavailable, throw an error.

#### Example Usage
```javascript
const recognition = new SpeechRecognition();
recognition.mode = "ondevice-only"; // Only use on-device speech recognition.
recognition.start();
```

## Privacy considerations
To reduce the risk of fingerprinting, user agents must implementing privacy-preserving countermeasures. The Web Speech API will employ the same masking techniques used by the [Web Translation API](https://github.com/webmachinelearning/writing-assistance-apis/pull/47).

## Conclusion
The addition of on-device speech recognition capabilities to the Web Speech API marks a significant step forward in creating more private, performant, and accessible web applications. By leveraging these new methods, developers can enhance user experiences while addressing key concerns around privacy and connectivity.