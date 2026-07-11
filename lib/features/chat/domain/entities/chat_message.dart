enum MessageSender {
  user,
  assistant,
  system,
}

enum AttachmentType {
  none,
  image,
  audio,
}

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final String? attachmentPath;
  final AttachmentType attachmentType;
  final bool isPending;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.attachmentPath,
    this.attachmentType = AttachmentType.none,
    this.isPending = false,
  });

  bool get hasAttachment => attachmentPath != null && attachmentType != AttachmentType.none;

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    String? attachmentPath,
    AttachmentType? attachmentType,
    bool? isPending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentType: attachmentType ?? this.attachmentType,
      isPending: isPending ?? this.isPending,
    );
  }

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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
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
}
