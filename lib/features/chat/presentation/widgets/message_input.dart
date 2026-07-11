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
  final FocusNode _focusNode = FocusNode();
  bool _showSendButton = false;
  bool _isMenuExpanded = false;

  // Selected mock attachment state
  String? _selectedAttachmentPath;
  AttachmentType _selectedAttachmentType = AttachmentType.none;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _isMenuExpanded) {
      _isMenuExpanded = false;
    }
    setState(() {});
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
      _isMenuExpanded = false;
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
              type == AttachmentType.image
                  ? Icons.image
                  : type == AttachmentType.audio
                      ? Icons.mic
                      : Icons.description,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              type == AttachmentType.image
                  ? 'Selected local textbook photo'
                  : type == AttachmentType.audio
                      ? 'Recorded local lecture voice note'
                      : 'Selected textbook chapter PDF',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingOption({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(89),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPlusButton = !_showSendButton && _selectedAttachmentType == AttachmentType.none;

    return TapRegion(
      onTapOutside: (event) {
        if (_isMenuExpanded) {
          setState(() {
            _isMenuExpanded = false;
          });
        }
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      child: SafeArea(
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
                            : _selectedAttachmentType == AttachmentType.audio
                                ? Icons.mic_none_outlined
                                : Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedAttachmentType == AttachmentType.image
                              ? 'Ready to upload textbook_notes.jpg'
                              : _selectedAttachmentType == AttachmentType.audio
                                  ? 'Ready to transcribe audio_lecture.wav'
                                  : 'Ready to parse textbook_chapter.pdf',
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
              // Use a Stack to absolute-position the floating vertical menu on the right
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Input Pill
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
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
                              const SizedBox(width: 8),
                              // Send button with send icon inside circular container
                              if (_showSendButton || _selectedAttachmentType != AttachmentType.none)
                                GestureDetector(
                                  onTap: _handleSend,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 3.0),
                                      child: Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                )
                              else if (showPlusButton)
                                // Placeholder space inside text field for the floating plus button
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Floating Overlay (Plus button and vertical menu) on the right side
                  if (showPlusButton)
                    Positioned(
                      right: 12,
                      bottom: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Camera Option
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 150),
                              scale: _isMenuExpanded ? 1.0 : 0.0,
                              child: SizedBox(
                                height: _isMenuExpanded ? 40 : 0,
                                child: _buildFloatingOption(
                                  icon: Icons.camera_alt_outlined,
                                  color: Colors.blueAccent,
                                  tooltip: 'Camera',
                                  onTap: () {
                                    _selectMockAttachment(AttachmentType.image);
                                    setState(() => _isMenuExpanded = false);
                                  },
                                ),
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: _isMenuExpanded ? 10 : 0,
                          ),
                          // 2. Audio Option
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              scale: _isMenuExpanded ? 1.0 : 0.0,
                              child: SizedBox(
                                height: _isMenuExpanded ? 40 : 0,
                                child: _buildFloatingOption(
                                  icon: Icons.mic_none_outlined,
                                  color: Colors.redAccent,
                                  tooltip: 'Audio',
                                  onTap: () {
                                    _selectMockAttachment(AttachmentType.audio);
                                    setState(() => _isMenuExpanded = false);
                                  },
                                ),
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: _isMenuExpanded ? 10 : 0,
                          ),
                          // 3. Document Option
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 210),
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 210),
                              scale: _isMenuExpanded ? 1.0 : 0.0,
                              child: SizedBox(
                                height: _isMenuExpanded ? 40 : 0,
                                child: _buildFloatingOption(
                                  icon: Icons.description_outlined,
                                  color: Colors.greenAccent,
                                  tooltip: 'Document',
                                  onTap: () {
                                    _selectMockAttachment(AttachmentType.file);
                                    setState(() => _isMenuExpanded = false);
                                  },
                                ),
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 210),
                            height: _isMenuExpanded ? 12 : 0,
                          ),
                          // Plus / Close rotating trigger button inside the text box right side
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: _isMenuExpanded ? 0.125 : 0.0,
                              child: Icon(
                                _isMenuExpanded ? Icons.add_circle : Icons.add_circle_outline_rounded,
                                color: _isMenuExpanded ? AppColors.primary : Colors.white70,
                                size: 28,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isMenuExpanded = !_isMenuExpanded;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
