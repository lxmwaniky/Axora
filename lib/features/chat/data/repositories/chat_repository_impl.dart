import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final _messageController = StreamController<ChatMessage>.broadcast();
  final List<ChatMessage> _history = [];

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _engineReady = false;   // true once the model weights are loaded
  bool _chatReady  = false;    // true once _chat is open and usable

  ChatRepositoryImpl() {
    _history.add(
      ChatMessage(
        id: 'welcome_msg',
        text:
            "Hey! I'm Axora, your offline Gemma 4 study assistant. Ask me any question directly in Airplane Mode! 📝🎧",
        sender: MessageSender.assistant,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
  }

  @override
  Stream<ChatMessage> getMessageStream() => _messageController.stream;

  @override
  Future<List<ChatMessage>> getMessageHistory() async {
    return List.from(_history);
  }

  Future<String> _getModelPath() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/${AppConfig.modelFilename}';
  }

  /// Loads the model weights exactly once, then opens the main chat session.
  Future<void> _ensureEngineInitialized(String modelPath) async {
    if (!_engineReady) {
      await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);

      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(modelPath).install();

      // 2048 gives the system prompt, user message, response, and multimodal audio/vision embeddings enough room.
      // Smaller sizes (512 or 1024) cause DYNAMIC_UPDATE_SLICE KV-cache overflow on multimodal input.
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
        supportImage: true,
        supportAudio: true,
      );
      _engineReady = true;
    }

    if (!_chatReady) {
      _chat = await _model!.createChat(
        systemInstruction: AppConfig.defaultSystemInstruction,
        modelType: ModelType.gemma4,
        supportImage: true,
        supportAudio: true,
      );
      _chatReady = true;
    }
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    debugPrint(
      "[ChatRepository] User sent message (ID: ${message.id}): '${message.text}'",
    );
    _history.add(message);
    _messageController.add(message);

    final modelFile = File(await _getModelPath());
    final modelExists =
        await modelFile.exists() && (await modelFile.length() >= 2500000000);

    if (!modelExists) {
      final errorMessage = ChatMessage(
        id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
        text:
            "Error: Gemma model file not found or incomplete. Please complete the download.",
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        isPending: false,
      );
      _history.add(errorMessage);
      _messageController.add(errorMessage);
      return;
    }

    await _runGemmaInference(message, modelFile.path);
  }

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }

  @override
  Future<void> startNewSession() async {
    try {
      if (_engineReady && _model != null) {
        debugPrint("[ChatRepository] Starting new Gemma session...");
        if (_chatReady && _chat != null) {
          await _chat!.close();
        }
        _chat = await _model!.createChat(
          systemInstruction: AppConfig.defaultSystemInstruction,
          modelType: ModelType.gemma4,
          supportImage: true,
          supportAudio: true,
        );
        _chatReady = true;
      }
    } catch (e) {
      debugPrint("[ChatRepository] Failed to start new session: $e");
      _chatReady = false;
    }
  }

  Future<void> _runGemmaInference(
    ChatMessage userMessage,
    String modelPath,
  ) async {
    final responseId = 'assistant_${DateTime.now().millisecondsSinceEpoch}';
    String accumulatedText = "";

    try {
      debugPrint("[ChatRepository] Ensuring Gemma engine is initialized...");
      await _ensureEngineInitialized(modelPath);

      final gemmaMessage = await _toGemmaMessage(userMessage);
      await _chat!.addQueryChunk(gemmaMessage);

      final stream = _chat!.generateChatResponseAsync();

      debugPrint("[ChatRepository] Starting Gemma response stream:");
      await for (final response in stream) {
        if (response is TextResponse) {
          accumulatedText += response.token;
          if (kDebugMode) {
            stdout.write(response.token);
          }
          _messageController.add(
            ChatMessage(
              id: responseId,
              text: accumulatedText,
              sender: MessageSender.assistant,
              timestamp: DateTime.now(),
              isPending: true,
            ),
          );
        }
      }
      if (kDebugMode) {
        stdout.writeln();
      }

      final finalMessage = ChatMessage(
        id: responseId,
        text: accumulatedText,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        isPending: false,
      );
      _history.add(finalMessage);
      _messageController.add(finalMessage);
      debugPrint("[ChatRepository] Gemma inference complete. Final response: '$accumulatedText'");
    } catch (e) {
      debugPrint("[ChatRepository] Error running Gemma inference: $e");
      final errorMessage = ChatMessage(
        id: responseId,
        text: "Failed to run Gemma engine: $e",
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        isPending: false,
      );
      _history.add(errorMessage);
      _messageController.add(errorMessage);
    }
  }

  Future<Message> _toGemmaMessage(ChatMessage userMessage) async {
    debugPrint("[AudioDebug] Processing message ID: ${userMessage.id}");
    debugPrint("[AudioDebug] Attachment Type: ${userMessage.attachmentType}");
    debugPrint("[AudioDebug] Attachment Path: ${userMessage.attachmentPath}");
    debugPrint("[AudioDebug] Text Content: '${userMessage.text}'");

    if (userMessage.attachmentType == AttachmentType.image) {
      Uint8List bytes;
      if (userMessage.attachmentPath != null &&
          !userMessage.attachmentPath!.startsWith('mock_path')) {
        final file = File(userMessage.attachmentPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          debugPrint("[AudioDebug] Loaded image bytes from file: ${bytes.length} bytes");
        } else {
          debugPrint("[AudioDebug] Image file does not exist, using fallback bytes");
          bytes = _getFallbackImageBytes();
        }
      } else {
        debugPrint("[AudioDebug] Image path is null or mock, using fallback bytes");
        bytes = _getFallbackImageBytes();
      }
      
      // Scale down image to a max dimension of 384 pixels to ensure fast, offline 1-2s prefill latency
      bytes = await _resizeImageBytes(bytes, 384);
      debugPrint("[AudioDebug] Resized image bytes: ${bytes.length} bytes");

      final String basePrompt = userMessage.text.trim().isEmpty
          ? "Please explain and analyze this image."
          : "Please analyze the attached image to answer this query: ${userMessage.text.trim()}";
      final promptText = "<|image><image|>\n$basePrompt";
      debugPrint("[AudioDebug] Final image prompt sent to Gemma: '$promptText'");
      return Message.withImage(
        text: promptText,
        imageBytes: bytes,
        isUser: true,
      );
    } else if (userMessage.attachmentType == AttachmentType.audio) {
      Uint8List bytes;
      bool usedFallback = false;
      if (userMessage.attachmentPath != null &&
          !userMessage.attachmentPath!.startsWith('mock_path')) {
        final file = File(userMessage.attachmentPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          debugPrint("[AudioDebug] Loaded audio bytes from file: ${bytes.length} bytes");
        } else {
          debugPrint("[AudioDebug] Audio file does not exist at '${userMessage.attachmentPath}', using fallback bytes");
          bytes = _getFallbackAudioBytes();
          usedFallback = true;
        }
      } else {
        debugPrint("[AudioDebug] Audio path is null or mock, using fallback bytes");
        bytes = _getFallbackAudioBytes();
        usedFallback = true;
      }
      final String basePrompt = userMessage.text.trim().isEmpty
          ? "Listen to the voice note and respond directly to the query or instruction spoken in it."
          : "Please analyze the attached audio to answer this query: ${userMessage.text.trim()}";
      final promptText = "<|audio><audio|>\n$basePrompt";
      debugPrint("[AudioDebug] Final audio prompt sent to Gemma: '$promptText' (using fallback: $usedFallback)");
      return Message.withAudio(
        text: promptText,
        audioBytes: bytes,
        isUser: true,
      );
    } else {
      debugPrint("[AudioDebug] Plain text message sent to Gemma: '${userMessage.text}'");
      return Message.text(
        text: userMessage.text,
        isUser: true,
      );
    }
  }

  Uint8List _getFallbackImageBytes() {
    const base64Png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    return base64Decode(base64Png);
  }

  Uint8List _getFallbackAudioBytes() {
    const base64Wav = 'UklGRiQAAABXQVZFZm10IBAAAAABAAEAgD4AAIA+AAABAAgAZGF0YQAAAAA=';
    return base64Decode(base64Wav);
  }

  Future<Uint8List> _resizeImageBytes(Uint8List originalBytes, int maxDimension) async {
    try {
      final Completer<ui.Image> completer = Completer();
      ui.decodeImageFromList(originalBytes, (ui.Image img) {
        completer.complete(img);
      });
      final ui.Image image = await completer.future;

      int width = image.width;
      int height = image.height;

      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension / width).round();
          width = maxDimension;
        } else {
          width = (width * maxDimension / height).round();
          height = maxDimension;
        }
      } else {
        image.dispose();
        return originalBytes;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        paint,
      );

      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(width, height);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      image.dispose();
      resizedImage.dispose();
      picture.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[ImageResize] Error resizing image: $e');
    }
    return originalBytes;
  }
}