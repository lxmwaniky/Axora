import 'dart:async';
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
            "Hey! I'm inkq, your offline Gemma 4 study assistant. Ask me any question directly in Airplane Mode! 📝🎧",
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

      // 1024 gives the system prompt (~60 tok) + user message + response enough room.
      // 512 caused DYNAMIC_UPDATE_SLICE KV-cache overflow on this device.
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.cpu,
      );
      _engineReady = true;
    }

    if (!_chatReady) {
      _chat = await _model!.createChat(
        systemInstruction: AppConfig.defaultSystemInstruction,
        modelType: ModelType.gemma4,
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

      await _chat!.addQueryChunk(
        Message.text(text: userMessage.text, isUser: true),
      );

      final stream = _chat!.generateChatResponseAsync();

      await for (final response in stream) {
        if (response is TextResponse) {
          accumulatedText += response.token;
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

      final finalMessage = ChatMessage(
        id: responseId,
        text: accumulatedText,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        isPending: false,
      );
      _history.add(finalMessage);
      _messageController.add(finalMessage);
      debugPrint("[ChatRepository] Gemma inference complete.");
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
}