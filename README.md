# Axora 📝🧠🎙️

Axora is a privacy-first, offline-capable, on-device AI study assistant built with Flutter. It leverages Google's **Gemma 4** model via the **LiteRT-LM** engine to digest notes, transcribe and analyze voice recordings, and help students study efficiently with flashcards—all without an internet connection (completely functional in Airplane Mode).

<img width="2752" height="1536" alt="gemma" src="https://github.com/user-attachments/assets/e3e3beaf-0f8f-42cb-a0f6-aa132a9fd6cd" />

---

## 🚀 Key Features

* **Offline Multimodal Intelligence**: Powered by `gemma-4-E2B-it` running locally on your device via the LiteRT C API.
* **📚 AI Flashcard Lounge**: Brainstorm and generate exactly 20 flashcards on any custom topic. Tap to flip cards in a premium interactive 3D study interface.
* **🎙️ Voice Note Digestion**: Speak study queries directly inside the app, and feed them into Gemma for automatic summarization and study guides.
* **🖼️ Multimodal Chat**: Snap a picture of a textbook diagram or upload study materials to get step-by-step guidance offline.
* **⚡ Optimized Image Resizing**: Built-in canvas-level hardware-accelerated image preprocessing scales attachments to a max dimension of 384px, bringing image prefill latency down from 63s to under 2s on CPU.
* **Real-time Logging**: Asynchronous token streaming outputs printed directly to `stdout` for developer inspection.
* **Continuous Integration**: Automated GitHub Actions CI/CD to generate split APKs and App Bundles on push.

---

## 🛠️ Tech Stack & Dependencies

* **Core Framework**: Flutter (Dart)
* **Local Inference**: `flutter_gemma` (using `flutter_gemma_litertlm` for FFI bindings)
* **Audio Capture**: `record` (configured for raw 16kHz mono WAV recording)
* **Playback & UI**: `audioplayers` integrated with a custom vertical-bar gesture-based waveform seeker.
* **CI/CD**: GitHub Actions building split-per-abi release binaries.

---

## 🎙️ On-Device Audio Constraints

To operate within the 2048-token context window of Gemma 4 without KV-cache prefill overflow:
* **Format**: WAV (PCM 16-bit)
* **Sample Rate**: 16 kHz
* **Channels**: Mono (1 channel)
* **Cap**: 15 seconds (automatically enforced during recording in the input widget)

---

## 💻 Technical & Engineering Challenges Resolved

Read our detailed project documentation in [Kaggle Writeup](https://www.kaggle.com/competitions/build-with-gemma-gdg-embu/writeups/axora) to learn how we addressed:
1. **Image Preprocessing Latency**: Resizing high-resolution images to fit the Gemma 4 vision encoder grid without CPU bottlenecks.
2. **JSON Sanitization**: Dealing with Markdown brackets and prose wrapped around JSON outputs from the LLM.
3. **Session State Corruption**: Managing shared singletons in the native LiteRT FFI bridge.
4. **PDF Memory Limits**: Pivoting to direct topic-based prompt generation due to resource boundaries on mobile devices.

---

## 📦 Building & Releases

The project includes a pre-configured GitHub Actions CI/CD workflow (`.github/workflows/release.yml`) that triggers on:
1. **Pushes to `main`**: Automatically compiles and updates a rolling `latest` prerelease on GitHub.
2. **Pushes to tags (`v*`)**: Automatically compiles and publishes a production release on GitHub.

To build the optimized, smallest format installers locally:
```bash
# Generate split APKs for each architecture
flutter build apk --release --split-per-abi

# Generate the Android App Bundle for Google Play
flutter build appbundle --release
```

---

*Gemma is a trademark of Google LLC.*
