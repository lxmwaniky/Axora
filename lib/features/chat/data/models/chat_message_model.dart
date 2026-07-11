import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.text,
    required super.sender,
    required super.timestamp,
    super.attachmentPath,
    super.attachmentType = AttachmentType.none,
    super.isPending = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      sender: MessageSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => MessageSender.user,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      attachmentPath: json['attachmentPath'] as String?,
      attachmentType: AttachmentType.values.firstWhere(
        (e) => e.name == json['attachmentType'],
        orElse: () => AttachmentType.none,
      ),
      isPending: json['isPending'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'attachmentPath': attachmentPath,
      'attachmentType': attachmentType.name,
      'isPending': isPending,
    };
  }

  factory ChatMessageModel.fromEntity(ChatMessage entity) {
    return ChatMessageModel(
      id: entity.id,
      text: entity.text,
      sender: entity.sender,
      timestamp: entity.timestamp,
      attachmentPath: entity.attachmentPath,
      attachmentType: entity.attachmentType,
      isPending: entity.isPending,
    );
  }
}
