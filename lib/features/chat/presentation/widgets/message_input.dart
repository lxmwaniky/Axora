import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
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
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingMs = 0;

  // Audio Player State for Previewing
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showAudioPreview = false;
  bool _isPlaying = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _previewPosition = p);
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _previewDuration = d);
    });
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
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
        _recordingMs = 20000; // Countdown starts at 20 seconds
        _recordingPath = path;
        _isMenuExpanded = false;
      });

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingMs -= 100;
          if (_recordingMs <= 0) {
            _stopRecordingAndShowPreview();
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

  Future<void> _stopRecordingAndShowPreview() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) {
          _recordingPath = path;
          _showAudioPreview = true;
          _previewPosition = Duration.zero;
          _previewDuration = Duration.zero;
          _isPlaying = false;
        }
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _stopAndSendVoiceNote() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (!_isRecording) return;
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        widget.onSendMessage('', attachmentPath: path, attachmentType: AttachmentType.audio);
      }
    } catch (e) {
      debugPrint('Error stop and send voice note: $e');
    } finally {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
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

  String _formatRecordingTime(int ms) {
    if (ms < 0) ms = 0;
    final int minutes = (ms ~/ 60000);
    final int seconds = (ms % 60000) ~/ 1000;
    final int tenths = (ms % 1000) ~/ 100;
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr.$tenths';
  }

  Future<void> _playPausePreview() async {
    if (_recordingPath == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
      }
    } catch (e) {
      debugPrint('Error playing/pausing preview: $e');
    }
  }

  Future<void> _deletePreview() async {
    try {
      await _audioPlayer.stop();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting preview: $e');
    } finally {
      setState(() {
        _showAudioPreview = false;
        _recordingPath = null;
        _isPlaying = false;
        _previewPosition = Duration.zero;
        _previewDuration = Duration.zero;
      });
    }
  }

  void _sendVoiceNote() {
    _audioPlayer.stop();
    if (_recordingPath != null) {
      widget.onSendMessage('', attachmentPath: _recordingPath, attachmentType: AttachmentType.audio);
    }
    setState(() {
      _showAudioPreview = false;
      _recordingPath = null;
      _isPlaying = false;
      _previewPosition = Duration.zero;
      _previewDuration = Duration.zero;
    });
  }

  String _formatDurationMs(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _selectMockAttachment(AttachmentType type) {
    setState(() {
      _selectedAttachmentType = type;
      _selectedAttachmentPath = 'mock_path_for_${type.name}';
    });
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                            : Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedAttachmentType == AttachmentType.image
                              ? 'Attached image'
                              : 'Attached file',
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: _isRecording
                                ? [
                                    const SizedBox(width: 8),
                                    const _BlinkingDot(),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatRecordingTime(_recordingMs),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const _AudioWaveforms(),
                                    const Expanded(child: SizedBox()),
                                    TextButton(
                                      onPressed: _cancelRecording,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Color(0xFF2E87FF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.stop_rounded, color: Colors.white70, size: 20),
                                      onPressed: _stopRecordingAndShowPreview,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _stopAndSendVoiceNote,
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
                                        width: 34,
                                        height: 34,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2E87FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                : _showAudioPreview
                                    ? [
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                          onPressed: _deletePreview,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: _playPausePreview,
                                          child: Icon(
                                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(2),
                                                child: LinearProgressIndicator(
                                                  value: _previewDuration.inMilliseconds > 0
                                                      ? _previewPosition.inMilliseconds / _previewDuration.inMilliseconds
                                                      : 0.0,
                                                  backgroundColor: Colors.white12,
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E87FF)),
                                                  minHeight: 4,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_formatDurationMs(_previewPosition)} / ${_formatDurationMs(_previewDuration)}',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: _sendVoiceNote,
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
                                            width: 34,
                                            height: 34,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2E87FF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.send_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]
                                    : [
                                        IconButton(
                                          icon: const Icon(Icons.attach_file_rounded, color: Colors.white54, size: 22),
                                          onPressed: () {
                                            setState(() {
                                              _isMenuExpanded = !_isMenuExpanded;
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _textController,
                                            focusNode: _focusNode,
                                            textCapitalization: TextCapitalization.sentences,
                                            style: const TextStyle(color: Colors.white, fontSize: 15),
                                            maxLines: null,
                                            decoration: const InputDecoration(
                                              hintText: 'Write a message...',
                                              hintStyle: TextStyle(color: AppColors.textMuted),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (_showSendButton || _selectedAttachmentType != AttachmentType.none)
                                          GestureDetector(
                                            onTap: _handleSend,
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
                                              width: 34,
                                              height: 34,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF2E87FF),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.send_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          IconButton(
                                            icon: const Icon(Icons.mic_none_rounded, color: Colors.white54, size: 22),
                                            onPressed: _startRecording,
                                          ),
                                      ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isMenuExpanded)
                    Positioned(
                      left: 12,
                      bottom: 52,
                      child: Container(
                        width: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2732),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMenuItem(
                              icon: Icons.image_outlined,
                              label: 'Photo or video',
                              onTap: () {
                                _selectMockAttachment(AttachmentType.image);
                                setState(() => _isMenuExpanded = false);
                              },
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            _buildMenuItem(
                              icon: Icons.description_outlined,
                              label: 'Document',
                              onTap: () {
                                _selectMockAttachment(AttachmentType.file);
                                setState(() => _isMenuExpanded = false);
                              },
                            ),
                          ],
                        ),
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
