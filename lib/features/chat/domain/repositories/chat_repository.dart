import '../entities/chat_message.dart';

abstract class ChatRepository {
  Stream<ChatMessage> getMessageStream();
  Future<List<ChatMessage>> getMessageHistory();
  Future<void> sendMessage(ChatMessage message);
  Future<void> clearHistory();
  Future<void> startNewSession();
}
