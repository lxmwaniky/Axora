# Axora 📝🎧

Axora is a privacy-first, offline-capable, on-device AI study assistant built with Flutter. It leverages Google's **Gemma 4** model via the **LiteRT-LM** engine to digest notes, transcribe and analyze voice recordings, and help students study efficiently—all without an internet connection (completely functional in Airplane Mode).

---

## 🚀 Key Features

* **Offline Multimodal Intelligence**: Powered by `gemma-4-E2B-it` running locally on your device via the LiteRT C API.
* **Lecture & Voice Note Digestion**: Record audio notes directly inside the app, and feed them into Gemma for automatic summarization and study guides.
* **Interactive Waveforms**: Customized vertical-bar audio player widgets with drag-to-seek support.
* **Real-time Logging**: Asynchronous token streaming outputs printed directly to `stdout` for developer inspection.
* **Continuous Integration**: Automated GitHub Actions CI/CD to generate split APKs (for the smallest file sizes) and App Bundles on push.

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

## 📦 Building & Releases

The project includes a pre-configured GitHub Actions CI/CD workflow (`.github/workflows/release.yml`) that triggers on:
1. **Pushes to `main`**: Automatically compiles and updates a rolling `latest` prerelease on GitHub, alongside standard Action run artifacts.
2. **Pushes to tags (`v*`)**: Automatically compiles and publishes a production release on GitHub.

To build the optimized, smallest format installers locally:
```bash
# Generate split APKs for each architecture
flutter build apk --release --split-per-abi

# Generate the Android App Bundle for Google Play
flutter build appbundle --release
```
