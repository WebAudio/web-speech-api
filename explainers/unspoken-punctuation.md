# Explainer: Unspoken Punctuation for the Web Speech API

## Introduction

The Web Speech API provides powerful speech recognition capabilities to web applications. However, continuous speech often lacks explicit spoken punctuation commands. When building casual voice typing tools, automated transcription services, and conversational assistants, developers frequently need to post-process the raw text to insert punctuation, making it readable and natural.

To address this, we introduce **unspoken punctuation** to the Web Speech API. This feature allows developers to configure the speech recognition engine to automatically infer and insert punctuation marks (such as periods, commas, and question marks) based on natural pauses, grammatical structure, and prosody, without requiring the user to explicitly speak the punctuation commands (e.g. saying "period" or "comma").

## Why Use Unspoken Punctuation?

### 1. **Customization for Different Use Cases**
Different speech recognition contexts require distinct handling of text flow. Casual voice typing, automated transcription, and conversational assistants greatly benefit from automatic punctuation to produce readable, polished text out of the box. Conversely, precise dictation tools, coding via voice, or raw acoustic logging applications may require verbatim, unpunctuated streams where punctuation is strictly controlled by explicit user commands.

### 2. **Enhanced User Experience**
Natural, continuous speech often lacks explicit spoken punctuation commands. Allowing developers to enable automatic punctuation lowers the cognitive load for end-users, making voice input feel more intuitive and conversational while saving developers from implementing complex downstream NLP models to handle basic text formatting.

## New API Components

The unspoken punctuation feature is implemented through a new `unspokenPunctuation` boolean attribute on the `SpeechRecognition` interface.

### `SpeechRecognition.unspokenPunctuation` attribute
This boolean attribute controls whether the speech recognition engine automatically infers and inserts punctuation marks.

- When set to `true`, the user agent should automatically insert punctuation based on natural pauses and grammatical structure.
- When set to `false`, the user agent must not insert unspoken punctuation, requiring the user to explicitly dictate punctuation commands.
- The default value is `false` to maintain backward compatibility with existing applications and ensure deterministic, unformatted text outputs unless explicitly opted into by the developer.

## Example Usage

```javascript
const recognition = new SpeechRecognition();

// Enable unspoken punctuation
recognition.unspokenPunctuation = true;

// Configure other settings
recognition.continuous = true;
recognition.interimResults = true;
recognition.lang = 'en-US';

recognition.onresult = (event) => {
  for (let i = event.resultIndex; i < event.results.length; ++i) {
    if (event.results[i].isFinal) {
      console.log('Final Result with Punctuation: ', event.results[i][0].transcript);
      // Example output: "Hello there, how are you today?"
      // Instead of: "hello there how are you today"
    } else {
      console.log('Interim Result: ', event.results[i][0].transcript);
    }
  }
};

recognition.start();
```

### Note on Automatic Capitalization
In many modern speech-to-text engines, automatic punctuation is tightly coupled with automatic capitalization. When `unspokenPunctuation` is set to `true`, developers should expect that the underlying recognition engine may also automatically capitalize the first word following an inferred sentence-ending punctuation mark (e.g., a period or question mark). Because this behavior depends on the specific platform and OS implementation, developers should not assume the resulting text will remain strictly lowercase when this flag is enabled.

### Internationalization
Punctuation and spacing rules vary by language (e.g., `¿` in Spanish). When `unspokenPunctuation` is enabled, the specific formatting is implementation-dependent. The underlying engine is expected to apply the correct localized rules based on the `SpeechRecognition.lang` attribute.
