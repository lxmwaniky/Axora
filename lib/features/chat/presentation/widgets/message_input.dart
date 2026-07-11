import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';

class MessageInput extends StatefulWidget {
  final Function(String text, {String? attachmentPath, AttachmentType attachmentType}) onSendMessage;

  const MessageInput({
    super.key,
    required this.onSendMessage,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  bool _showSendButton = false;

  // Selected mock attachment state
  String? _selectedAttachmentPath;
  AttachmentType _selectedAttachmentType = AttachmentType.none;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _showSendButton) {
      setState(() {
        _showSendButton = hasText;
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedAttachmentType == AttachmentType.none) return;

    widget.onSendMessage(
      text,
      attachmentPath: _selectedAttachmentPath,
      attachmentType: _selectedAttachmentType,
    );

    // Reset state
    _textController.clear();
    setState(() {
      _selectedAttachmentPath = null;
      _selectedAttachmentType = AttachmentType.none;
    });
  }

  void _selectMockAttachment(AttachmentType type) {
    setState(() {
      _selectedAttachmentType = type;
      _selectedAttachmentPath = 'mock_path_for_${type.name}';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceLight,
        content: Row(
          children: [
            Icon(
              type == AttachmentType.image ? Icons.image : Icons.mic,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              type == AttachmentType.image
                  ? 'Selected local textbook photo'
                  : 'Recorded local lecture voice note',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview attachment if selected
            if (_selectedAttachmentType != AttachmentType.none)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(76)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedAttachmentType == AttachmentType.image
                          ? Icons.image_outlined
                          : Icons.mic_none_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAttachmentType == AttachmentType.image
                            ? 'Ready to upload textbook_notes.jpg'
                            : 'Ready to transcribe audio_lecture.wav',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 16),
                      onPressed: () {
                        setState(() {
                          _selectedAttachmentPath = null;
                          _selectedAttachmentType = AttachmentType.none;
                        });
                      },
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                // Camera action (Vision)
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                  onPressed: () => _selectMockAttachment(AttachmentType.image),
                ),
                // Audio recorder action (ASR)
                IconButton(
                  icon: const Icon(Icons.mic_none_outlined, color: Colors.white),
                  onPressed: () => _selectMockAttachment(AttachmentType.audio),
                ),
                const SizedBox(width: 4),
                // Input Pill
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(color: Colors.white),
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: 'Talk to inkq...',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        // Send text button like Instagram
                        if (_showSendButton || _selectedAttachmentType != AttachmentType.none)
                          GestureDetector(
                            onTap: _handleSend,
                            child: const Text(
                              'Send',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.sentiment_satisfied_alt_outlined,
                                color: Colors.white70, size: 20),
                            onPressed: () {},
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
