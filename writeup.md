# Axora — A Private AI Study Companion Powered by Gemma 4

A fully offline, on-device tutoring and study application that turns any Android phone into a personalized study system — no cloud, no subscriptions, and zero data leaving the device.

---

## 💡 Motivation
Across the Global South and low-income communities worldwide, hundreds of millions of students grow up without access to qualified tutors, supplementary study materials, or personalized learning support. While urban students enrich their studies with private tutoring and expensive cloud-based AI tools, children in remote or underserved regions face three compounding barriers:

1. **Cost** — A \$20/month cloud AI subscription exceeds what many rural families spend on food and housing in a week.
2. **Connectivity** — Mountain villages, ethnic-minority townships, and migrant-worker communities are offline by default. School WiFi is unreliable, and home internet is often nonexistent.
3. **Hardware** — High-end laptops and flagship phones are out of reach. The only computing device in a household is frequently a single budget Android phone shared between multiple siblings.

Educational AI today is built for the students who need it least. The children who would benefit most from a patient, always-available tutor — those without access to good schools, qualified teachers, or after-class help — are exactly the ones priced and disconnected out of every cloud-based product on the market.

Google's **Gemma 4 E2B** changes the equation. A frontier-class model that runs on a budget Android phone, fully offline, with no recurring fees and no account required. **Axora** is built on this foundation: a personal tutor that fits in any child's pocket, works without WiFi, costs nothing to use, and never expires. Every child deserves a teacher who will answer the same question ten times without judgment, explain a concept at 2 AM, and travel with them no matter how remote the village. Axora is a step toward making that universal.

---

## 🏗️ Architecture

Axora is a Flutter application designed to interact directly with the local **LiteRT-LM** engine. 

```
+--------------------------------------------------------+
|                      Axora App                         |
|     Chat Interface       |       Flashcard Lounge      |
+--------------------------------------------------------+
                            |
                            v
+--------------------------------------------------------+
|                Local Inference Bridge                  |
|                 (flutter_gemma FFI)                    |
+--------------------------------------------------------+
                            |
                            v
+--------------------------------------------------------+
|                On-Device Gemma 4 E2B                   |
|                   (LiteRT Engine)                      |
+--------------------------------------------------------+
```

Students never need an internet connection. The app launches immediately into the chat or flashcard workspace, running model calculations directly on the phone's native hardware.

---

## 🤖 How Gemma 4 Is Used — Specifically

Gemma 4 powers every intelligent action in the app:

| Feature | Gemma 4 Path | How |
| :--- | :--- | :--- |
| **Multimodal Chat** | On-device (`gemma-4-E2B-it`) | `generateChatResponseAsync()` with context-aware prompts supporting text, downscaled images, and voice notes. |
| **Flashcard Generation** | On-device (`gemma-4-E2B-it`) | Prompts the model to brainstorm exactly 20 Q&A cards based on a topic and return raw JSON data. |

---

## 🚀 Key Features

* **📚 AI Flashcard Lounge** — Brainstorm and generate exactly 20 flashcards on any specific topic offline. Review cards in a deck using an interactive learning progress dashboard.
* **✨ Premium 3D Flip Cards** — Built using native Flutter Matrix4 transformations to create a stunning, perspective-warped card flipping rotation without external package overhead.
* **🎙️ Voice Note Processing** — Records WAV (PCM 16-bit, 16kHz mono) audio notes up to 15 seconds, allowing students to speak queries directly to the on-device model.
* **🖼️ Multimodal Chat** — Attach photos, study materials, or textbook figures to chat sessions for instant explanations.

---

## 💻 Engineering Challenges

### 1 — Image Preprocessing & CPU Patch Explosion (63s down to 2s Prefill)
When sending high-resolution camera images to the model, Gemma's vision preprocessor resized them to custom boundaries resulting in **2,376 patches**. Running that many patches through a 2.5B parameter model on a budget CPU without hardware acceleration (since mobile devices often lack native `liblitert_dispatch.so` drivers) caused a prefill latency of **63.2 seconds**, triggering silent timeouts and task cancellations.
* **Fix**: We built a hardware-accelerated image scaling utility inside the Flutter framework using native canvas operations. All images are downscaled to a max dimension of **384 pixels** before being passed to Gemma, reducing the number of patches to less than 100 and bringing prefill latency down to under 2 seconds.

### 2 — JSON Sanitizer Bug & Parse Failures
To generate flashcards, the model is instructed to output JSON matching a strict question-and-answer schema. However, models occasionally append markdown fences (like ` ```json `) or introductory/concluding chat conversational text. Traditional regex cleanup often deleted curly braces or quotes required for parsing.
* **Fix**: Implemented a robust sanitization process that checks for markdown backticks and extracts only the text between the brackets before decoding, ensuring valid JSON arrays are parsed safely without crashing the UI.

### 3 — flutter_gemma API Drift & Shared Singletons
During integration, calling `.close()` on model sessions corrupted subsequent requests with native errors (`INTERNAL: Failed to invoke compiled model`). 
* **Fix**: Understood that the `InferenceModel` is a shared native singleton. We modified the model lifecycle management to close only the individual `InferenceChat` session instances rather than the underlying model container.

### 4 — PDF Feature Limitations & Time Constraints
* **Challenge**: While we initially laid out plans to support full client-side PDF document parsing using `syncfusion_flutter_pdf` to extract and process text, we encountered severe memory overhead limits and context window constraints when trying to feed entire books into a mobile model.
* **Pivoted Fix**: Due to time constraints and the need to guarantee model stability, we chose to prioritize a direct, topic-based 20 Q&A generator. This keeps the prompt sizes small, predictable, and highly efficient on mobile hardware while guaranteeing the output schema is never corrupted.

---

## 🌍 Impact
Axora targets students who are priced out of cloud-based AI, reside in areas with sparse or zero internet connectivity, or require strict privacy where no data or images are ever transmitted to corporate servers. It transforms a mobile phone into a self-contained tutor that works anywhere in the world.

---

## 🙏 Acknowledgments
* **Google & the Gemma Team** — For the Apache 2.0 licensing that makes offline, on-device frontier model usage a reality.
* **Sasha Denisov & the flutter_gemma community** — For building the Flutter bridge to the native LiteRT-LM C API.
