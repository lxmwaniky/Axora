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
  dynamic _chat; // the created chat/session object
  bool _engineInitialized = false;

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

  /// Sets up the LiteRT-LM engine and loads the model exactly once.
  Future<void> _ensureEngineInitialized(String modelPath) async {
    if (_engineInitialized) return;

    await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);

    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(modelPath).install();

    // CPU backend — proven working on this hardware; GPU crashed during testing.
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
    );

    _chat = await _model!.createChat();
    _engineInitialized = true;
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
      if (_engineInitialized && _model != null) {
        debugPrint("[ChatRepository] Starting new Gemma session...");
        _chat = await _model!.createChat();
      }
    } catch (e) {
      debugPrint("[ChatRepository] Failed to start new session: $e");
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

      await _chat.addQueryChunk(
        Message.text(text: userMessage.text, isUser: true),
      );

      final stream = _chat.generateChatResponseAsync();

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

  @override
  Future<String> generateTitle(String firstMessage) async {
    final normalized = firstMessage.toLowerCase().trim();

    if (normalized.contains("hello") ||
        normalized.contains("hi ") ||
        normalized == "hi") {
      return "Casual Greeting";
    }
    if (normalized.contains("dsa") ||
        normalized.contains("data structure") ||
        normalized.contains("algorithm")) {
      return "DSA Study";
    }
    if (normalized.contains("math") ||
        normalized.contains("calculus") ||
        normalized.contains("algebra")) {
      return "Math Solver";
    }
    if (normalized.contains("physics") ||
        normalized.contains("force") ||
        normalized.contains("gravity")) {
      return "Physics Study";
    }

    final words = firstMessage.split(RegExp(r'\s+')).take(3).join(" ");
    String title = words;
    if (words.length > 20) {
      title = "${words.substring(0, 17)}...";
    }
    title = title
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
    return "$title";
  }
}