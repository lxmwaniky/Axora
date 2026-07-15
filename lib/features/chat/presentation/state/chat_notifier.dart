import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatNotifier extends ChangeNotifier {
  final ChatRepository _repository;
  
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isLoading = false;
  bool _isWriting = false;

  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;
  bool get isLoading => _isLoading;
  bool get isWriting => _isWriting;

  ChatSession? get currentSession {
    if (_currentSessionId == null || _sessions.isEmpty) return null;
    return _sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () => _sessions.first);
  }

  List<ChatMessage> get messages => currentSession?.messages ?? [];

  ChatNotifier(this._repository) {
    _init();
  }

  void _init() {
    loadHistory();
    _repository.getMessageStream().listen((message) {
      _handleIncomingMessage(message);
    });
  }

  Future<File> _getStorageFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/chat_sessions.json');
  }

  Future<void> _saveSessionsToDisk() async {
    try {
      final file = await _getStorageFile();
      final jsonList = _sessions.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      debugPrint("[ChatNotifier] Saved ${_sessions.length} sessions to local storage.");
    } catch (e) {
      debugPrint("[ChatNotifier] Error saving sessions to disk: $e");
    }
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        _sessions = jsonList.map((s) => ChatSession.fromJson(s as Map<String, dynamic>)).toList();
        _sortSessions();
        _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
        debugPrint("[ChatNotifier] Loaded ${_sessions.length} sessions from disk.");
      } else {
        _sessions = [];
        _currentSessionId = null;
        debugPrint("[ChatNotifier] No stored sessions found. Starting fresh.");
      }
    } catch (e) {
      debugPrint("Failed to load chat history: $e");
      _sessions = [];
      _currentSessionId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortSessions() {
    _sessions.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      
      final aTime = a.messages.isNotEmpty ? a.messages.last.timestamp : a.createdAt;
      final bTime = b.messages.isNotEmpty ? b.messages.last.timestamp : b.createdAt;
      return bTime.compareTo(aTime);
    });
  }

  void selectSession(String sessionId) {
    _currentSessionId = sessionId;
    _isWriting = false;
    _repository.startNewSession();
    notifyListeners();
  }

  String createNewSession({String title = 'New Chat'}) {
    final newId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final newSession = ChatSession(
      id: newId,
      title: title,
      createdAt: DateTime.now(),
      messages: [],
    );
    _sessions.insert(0, newSession);
    _currentSessionId = newId;
    _isWriting = false;
    _repository.startNewSession();
    _sortSessions();
    _saveSessionsToDisk();
    notifyListeners();
    return newId;
  }

  void renameSession(String sessionId, String newTitle) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions[index].title = newTitle;
      _saveSessionsToDisk();
      notifyListeners();
    }
  }

  bool togglePinSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return false;

    final session = _sessions[index];
    if (!session.isPinned) {
      final pinnedCount = _sessions.where((s) => s.isPinned).length;
      if (pinnedCount >= 4) {
        return false; // Limit reached
      }
      session.isPinned = true;
    } else {
      session.isPinned = false;
    }

    _sortSessions();
    _saveSessionsToDisk();
    notifyListeners();
    return true;
  }

  void deleteSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final session = _sessions[index];
      for (final msg in session.messages) {
        if (msg.attachmentPath != null &&
            !msg.attachmentPath!.startsWith('mock_path')) {
          try {
            final file = File(msg.attachmentPath!);
            if (file.existsSync()) {
              file.deleteSync();
              debugPrint("[Storage] Deleted local attachment file on session delete: ${msg.attachmentPath}");
            }
          } catch (e) {
            debugPrint("[Storage] Error deleting local attachment file: $e");
          }
        }
      }
      _sessions.removeAt(index);
    }
    if (_currentSessionId == sessionId) {
      _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
    }
    _saveSessionsToDisk();
    notifyListeners();
  }

  Future<void> sendUserMessage(
    String text, {
    String? attachmentPath,
    AttachmentType attachmentType = AttachmentType.none,
  }) async {
    if (text.trim().isEmpty && attachmentPath == null) return;
    if (_currentSessionId == null) {
      createNewSession();
    }

    final activeSession = currentSession!;
    final isFirstMessage = activeSession.messages.isEmpty;

    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      attachmentPath: attachmentPath,
      attachmentType: attachmentType,
      isPending: false,
    );

    // Optimistically add user message and set writing to true
    activeSession.messages.add(userMessage);
    if (isFirstMessage) {
      activeSession.title = text;
    }
    _isWriting = true;
    _sortSessions();
    _saveSessionsToDisk();
    notifyListeners();

    try {
      await _repository.sendMessage(userMessage);
    } catch (e) {
      debugPrint("Failed to send message: $e");
      _isWriting = false;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    if (_currentSessionId != null) {
      final session = currentSession!;
      for (final msg in session.messages) {
        if (msg.attachmentPath != null &&
            !msg.attachmentPath!.startsWith('mock_path')) {
          try {
            final file = File(msg.attachmentPath!);
            if (file.existsSync()) {
              file.deleteSync();
              debugPrint("[Storage] Deleted local attachment file during clearAll: ${msg.attachmentPath}");
            }
          } catch (e) {
            debugPrint("[Storage] Error deleting local attachment file: $e");
          }
        }
      }
      session.messages.clear();
      _isWriting = false;
      _saveSessionsToDisk();
      notifyListeners();
    }
  }

  void _handleIncomingMessage(ChatMessage message) {
    final activeSession = currentSession;
    if (activeSession == null) return;

    final index = activeSession.messages.indexWhere((m) => m.id == message.id);

    if (index != -1) {
      activeSession.messages[index] = message;
    } else {
      activeSession.messages.add(message);
    }

    if (message.sender == MessageSender.assistant) {
      // Stop the typing bubble as soon as the first token arrives
      if (_isWriting && message.text.isNotEmpty) {
        _isWriting = false;
      }

      // Only persist to disk when the full response is done (not on every token)
      if (!message.isPending) {
        _sortSessions();
        _saveSessionsToDisk();
      }
    }

    notifyListeners();
  }
}
