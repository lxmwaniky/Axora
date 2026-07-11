import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/chat_notifier.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_input.dart';
import '../../domain/entities/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final ChatNotifier notifier;

  const ChatScreen({
    super.key,
    required this.notifier,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_scrollToBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ChatHeader(
        onClearPressed: widget.notifier.clearAll,
      ),
      body: Column(
        children: [
          // Divider
          Container(
            height: 1,
            color: Colors.white10,
          ),
          // Chat List
          Expanded(
            child: AnimatedBuilder(
              animation: widget.notifier,
              builder: (context, _) {
                if (widget.notifier.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (widget.notifier.messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hi!',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                final showTyping = widget.notifier.isWriting;
                final itemCount = widget.notifier.messages.length + (showTyping ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: itemCount,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    if (showTyping && index == 0) {
                      return _buildTypingIndicator();
                    }

                    final messageIndex = widget.notifier.messages.length - 1 - (index - (showTyping ? 1 : 0));
                    final message = widget.notifier.messages[messageIndex];
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          // Input Field
          MessageInput(
            onSendMessage: (text, {attachmentPath, attachmentType = AttachmentType.none}) {
              widget.notifier.sendUserMessage(
                text,
                attachmentPath: attachmentPath,
                attachmentType: attachmentType,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.receiverBubble,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypingDot(0),
              const SizedBox(width: 4),
              _buildTypingDot(1),
              const SizedBox(width: 4),
              _buildTypingDot(2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int delayIndex) {
    return _AnimatedDot(delayIndex: delayIndex);
  }
}

// Sub-widget for animating a typing dot
class _AnimatedDot extends StatefulWidget {
  final int delayIndex;

  const _AnimatedDot({required this.delayIndex});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Apply offset delay for sequencing
    Future.delayed(Duration(milliseconds: widget.delayIndex * 150), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
