import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
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

  // Audio Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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

  Future<void> _startRecording() async {
    try {
      final hasPermission = await Permission.microphone.request().isGranted;
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.surfaceLight,
              content: Text('Microphone permission is required to record voice notes.'),
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _audioRecorder.start(config, path: path);

      _recordingTimer?.cancel();
      setState(() {
        _isRecording = true;
        _isLocked = false;
        _recordingSeconds = 0;
        _recordingPath = path;
        _isMenuExpanded = false;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingSeconds++;
          // Auto-stop recording if it reaches 20 seconds (Gemma limit)
          if (_recordingSeconds >= 20) {
            _stopRecording();
          }
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceLight,
            content: Text('Failed to start recording: $e'),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isLocked = false;
        if (path != null) {
          _selectedAttachmentType = AttachmentType.audio;
          _selectedAttachmentPath = path;
        }
      });
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceLight,
            content: Row(
              children: [
                Icon(Icons.mic, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Recorded voice note (Max 20s)'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (!_isRecording) return;
    try {
      await _audioRecorder.stop();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
    } catch (e) {
      debugPrint('Error canceling recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _handleLongPressStart() {
    _startRecording();
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_isRecording && !_isLocked) {
      if (details.localOffsetFromOrigin.dy < -50) {
        setState(() {
          _isLocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1500),
            backgroundColor: AppColors.surfaceLight,
            content: Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Recording locked. Tap stop when done.'),
              ],
            ),
          ),
        );
      }
    }
  }

  void _handleLongPressEnd() {
    if (_isRecording && !_isLocked) {
      _stopRecording();
    }
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
    final showPlusButton = !_showSendButton && _selectedAttachmentType == AttachmentType.none && !_isRecording;

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
                            children: _isRecording
                                ? [
                                    const _BlinkingDot(),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(_recordingSeconds),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const _AudioWaveforms(),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isLocked
                                            ? ''
                                            : '  Swipe up to lock 🔒',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (_isLocked) ...[
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                                        onPressed: _cancelRecording,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: _stopRecording,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.stop_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4.0),
                                        child: Icon(
                                          Icons.keyboard_double_arrow_up_rounded,
                                          color: Colors.white38,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ]
                                : [
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
                                      // Placeholder space inside text field for the floating plus and mic buttons
                                      const SizedBox(
                                        width: 72,
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
                          // 2. Document Option
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _isMenuExpanded ? 1.0 : 0.0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 180),
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
                            duration: const Duration(milliseconds: 180),
                            height: _isMenuExpanded ? 12 : 0,
                          ),
                          // Plus/Close trigger and Mic button side-by-side
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                              const SizedBox(width: 12),
                              GestureDetector(
                                onLongPressStart: (_) => _handleLongPressStart(),
                                onLongPressMoveUpdate: (details) => _handleLongPressMoveUpdate(details),
                                onLongPressEnd: (_) => _handleLongPressEnd(),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mic_none_rounded,
                                    color: Colors.white70,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
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

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AudioWaveforms extends StatefulWidget {
  const _AudioWaveforms();

  @override
  State<_AudioWaveforms> createState() => _AudioWaveformsState();
}

class _AudioWaveformsState extends State<_AudioWaveforms> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, (index) {
            final double animatedValue = index % 2 == 0 
                ? _controller.value 
                : 1.0 - _controller.value;
            final double height = 4.0 + (animatedValue * 14.0);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
