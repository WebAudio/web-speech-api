# Explainer: Contextual Biasing for the Web Speech API

## Introduction

The Web Speech API provides powerful speech recognition capabilities to web applications. However, general-purpose speech recognition models can sometimes struggle with domain-specific terminology, proper nouns, or other words that are unlikely to appear in general conversation. This can lead to a frustrating user experience where the user's intent is frequently misrecognized.

To address this, we introduce **contextual biasing** to the Web Speech API. This feature allows developers to provide "hints" to the speech recognition engine in the form of a list of phrases and boost values. By biasing the recognizer towards these phrases, applications can significantly improve the accuracy for vocabulary that is important in their specific context.

## Why Use Contextual Biasing?

### 1. **Improved Accuracy**
By providing a list of likely phrases, developers can dramatically increase the probability of those phrases being recognized correctly. This is especially useful for words that are acoustically similar to more common words.

### 2. **Enhanced User Experience**
When speech recognition "just works" for the user's context, it leads to a smoother, faster, and less frustrating interaction. Users don't have to repeat themselves or manually correct transcription errors.

### 3. **Enabling Specialized Applications**
Contextual biasing makes the Web Speech API a more viable option for specialized applications in fields like medicine, law, science, or gaming, where precise and often uncommon terminology is essential.

## Example Use Cases

### 1. Voice-controlled Video Game
A video game might have characters with unique names like "Zoltan," "Xylia," or "Grog." Without contextual biasing, a command like "Attack Zoltan" might be misheard as "Attack Sultan." By providing a list of character and location names, the game can ensure commands are understood reliably.

### 2. E-commerce Product Search
An online store can bias the speech recognizer towards its product catalog. When a user says "Show me Fujifilm cameras," the recognizer is more likely to correctly identify "Fujifilm" instead of a more common but similar-sounding word.

### 3. Medical Dictation
A web-based application for doctors could be biased towards recognizing complex medical terms, drug names, and procedures. This allows for accurate and efficient voice-based note-taking.

## New API Components

Contextual biasing is implemented through a new `phrases` attribute on the `SpeechRecognition` interface, which uses the new `SpeechRecognitionPhrase` interface.

### 1. `SpeechRecognition.phrases` attribute
This attribute is an `ObservableArray<SpeechRecognitionPhrase>` that allows developers to provide contextual hints for the recognition session. It can be modified like a JavaScript `Array`.

### 2. `SpeechRecognitionPhrase` interface
Represents a single phrase and its associated boost value.

- `constructor(DOMString phrase, optional float boost = 1.0)`: Creates a new phrase object.
- `phrase`: The text string to be boosted.
- `boost`: A float between 0.0 and 10.0. Higher values make the phrase more likely to be recognized.


### Example Usage

```javascript
// A list of phrases relevant to our application's context.
const phraseData = [
  { phrase: 'Zoltan', boost: 3.0 },
  { phrase: 'Grog', boost: 2.0 },
];

// Create SpeechRecognitionPhrase objects.
const phraseObjects = phraseData.map(p => new SpeechRecognitionPhrase(p.phrase, p.boost));

const recognition = new SpeechRecognition();

// Assign the phrase objects to the recognition instance.
// The attribute is an ObservableArray, so we can assign an array to it.
recognition.phrases = phraseObjects;

// We can also dynamically add/remove phrases.
recognition.phrases.push(new SpeechRecognitionPhrase('Xylia', 2.5));

// Some user agents (e.g. Chrome) might only support on-device contextual biasing.
recognition.processLocally = true;

recognition.onresult = (event) => {
  const transcript = event.results[0][0].transcript;
  console.log(`Result: ${transcript}`);
};

recognition.onerror = (event) => {
  if (event.error === 'phrases-not-supported') {
    console.warn('Contextual biasing is not supported by this browser/service.');
  }
};

// Start recognition when the user clicks a button.
document.getElementById('speak-button').onclick = () => {
  recognition.start();
};
```

## Conclusion

Contextual biasing is a powerful enhancement to the Web Speech API that gives developers finer control over the speech recognition process. By allowing applications to provide context-specific hints, this feature improves accuracy, creates a better user experience, and makes voice-enabled web applications more practical for a wider range of specialized use cases.