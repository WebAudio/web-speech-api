# Explainer: Speech Recognition Context for the Web Speech API


## Introduction


The Web Speech API provides speech recognition with generalized language models, but currently lacks explicit mechanisms to support contextual biasing. This means it is difficult to prioritize certain words or phrases, or adapt to user-specific or domain-specific vocabularies.


Therefore we introduce a new feature to add **recognition context** to be part of the Web Speech API, along with an update method to keep updating it during an active speech recognition session.


## Why Add Speech Recognition Context?


### 1. **Improve Accuracy**
Recognition context allows the speech recognition models to recognize words and phrases that are relevant to a specific domain, user, or situation, even if those terms are rare or absent from the general training data. This can significantly decrease the number of errors in transcriptions, especially in scenarios where ambiguity exists.


### 2. **Enhanced Relevance**
By incorporating contextual information, the speech recognition models can produce transcriptions that are more meaningful and better aligned with the user's expectations of the output. This leads to improved understanding of the spoken content and more reliable execution of voice commands.


### 3. **Increased Efficiency**
By focusing on relevant vocabulary, the speech recognition models can streamline the recognition process, leading to faster and more efficient transcriptions.


## New Interfaces


### 1. **SpeechRecognitionPhrase**
This interface holds fundamental information about a biasing phrase, such as a text string for phrase content and a boost value indicating how likely the phrase will appear. The phrase string should be non-empty and a valid boost value should be inside the range of [0, 10] with a default value of 1.0.


#### Definition
```javascript
[Exposed=Window]
interface SpeechRecognitionPhrase {
    constructor(DOMString phrase, optional float boost = 1.0);
    attribute DOMString phrase;
    attribute float boost;
};
```


### 2. **SpeechRecognitionPhraseList**
This interface holds a list of `SpeechRecognitionPhrase` and supports adding more `SpeechRecognitionPhrase` to the list.


#### Definition
```javascript
[Exposed=Window]
interface SpeechRecognitionPhraseList {
    readonly attribute unsigned long length;
    getter SpeechRecognitionPhrase item(unsigned long index);
    void addItem(SpeechRecognitionPhrase item);
};
```


### 3. **SpeechRecognitionContext**
This interface holds a `SpeechRecognitionPhraseList` attribute providing contextual information to the speech recognition models. It can hold more types of contextual data if needed in the future. 


#### Definition
```javascript
[Exposed=Window]
interface SpeechRecognitionContext {
    attribute SpeechRecognitionPhraseList phrases;
};
```


## New Attribute


### 1. `context` attribute in the `SpeechRecognition` interface
The `context` attribute of the type `SpeechRecognitionContext` in the `SpeechRecognition` interface provides initial contextual information to start the speech recognition session with.


#### Example Usage
```javascript
var list = new SpeechRecognitionPhraseList();
list.addItem(new SpeechRecognitionPhrase("text", 1.0));
var context = new SpeechRecognitionContext(list);

const recognition = new SpeechRecognition();
recognition.context = context;
recognition.start();
```


## New Method


### 1. `void updateContext(SpeechRecognitionContext context)`
This method in the `SpeechRecognition` interface updates the speech recognition context after the speech recognition session has started.


#### Example Usage
```javascript
const recognition = new SpeechRecognition();
recognition.start();

var list = new SpeechRecognitionPhraseList();
list.addItem(new SpeechRecognitionPhrase("updated text", 2.0));
var context = new SpeechRecognitionContext(list);
recognition.updateContext(context);
```


## New Error Code


### 1. `recognition-context-not-supported` in the `SpeechRecognitionErrorCode` enum
This error code is returned when the speech recognition models do not support biasing, but speech recognition context is set during SpeechRecognition initialization, or the update context method is called. For example, Chrome requires on-device speech recognition to be used in order to support recognition context.


#### Example Scenario 1
```javascript
const recognition = new SpeechRecognition();
recognition.mode = "cloud-only";

var list = new SpeechRecognitionPhraseList();
list.addItem(new SpeechRecognitionPhrase("text", 1.0));
var context = new SpeechRecognitionContext(list);
recognition.context = context;

// If the speech recognition model in the cloud does not support biasing,
// an error event will occur when the recognition starts.
recognition.onerror = function(event) {
  if (event.error == "recognition-context-not-supported") {
    console.log("Recognition context is not supported: ", event);
  }
};

recognition.start();
```


#### Example Scenario 2
```javascript
const recognition = new SpeechRecognition();
recognition.mode = "cloud-only";
recognition.start();

var list = new SpeechRecognitionPhraseList();
list.addItem(new SpeechRecognitionPhrase("text", 1.0));
var context = new SpeechRecognitionContext(list);

// If the speech recognition model in the cloud does not support biasing,
// an error event will occur when calling updateContext().
recognition.onerror = function(event) {
  if (event.error == "recognition-context-not-supported") {
    console.log("Recognition context is not supported: ", event);
  }
};

recognition.updateContext(context);
```

## Conclusion


In conclusion, adding SpeechRecognitionContext to the Web Speech API represents a critical step towards supporting contextual biasing for speech recognition. This enables the developers to improve accuracy and relevance for domain-specific and personalized speech recognition, and allows for dynamic adaptation during active speech recognition sessions.

