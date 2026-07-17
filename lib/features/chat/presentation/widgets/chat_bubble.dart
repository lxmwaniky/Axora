import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;

    // Check if the message content contains JSON for study cards
    final isJson = !isUser && message.text.trim().startsWith('[') && message.text.trim().endsWith(']');

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isJson)
              _buildInteractiveStudyCards(context, message.text)
            else if (message.attachmentType == AttachmentType.audio && isUser)
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: AudioBubblePlayer(
                  attachmentPath: message.attachmentPath,
                  isUser: isUser,
                ),
              )
            else
              GestureDetector(
                onLongPress: isUser ? null : () => _copyToClipboard(context, message.text),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? null : AppColors.receiverBubble,
                    gradient: isUser ? AppColors.instagramGradient : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.hasAttachment) ...[
                        _buildAttachmentWidget(context, isUser),
                        const SizedBox(height: 8),
                      ],
                      if (isUser)
                        Text(
                          message.text,
                          style: TextStyle(
                            color: AppColors.senderBubbleText,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        )
                      else
                        MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: AppColors.receiverBubbleText,
                              fontSize: 15,
                              height: 1.4,
                            ),
                            strong: TextStyle(
                              color: AppColors.receiverBubbleText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: TextStyle(
                              color: AppColors.receiverBubbleText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.6,
                            ),
                            listBullet: TextStyle(
                              color: AppColors.receiverBubbleText,
                              fontSize: 15,
                            ),
                            code: TextStyle(
                              color: AppColors.receiverBubbleText,
                              backgroundColor: Colors.black26,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Timestamp or pending state
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
              child: Text(
                message.isPending ? 'Typing...' : _formatTime(message.timestamp),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentWidget(BuildContext context, bool isUser) {
    if (message.attachmentType == AttachmentType.image) {
      final bool hasRealFile = message.attachmentPath != null &&
          !message.attachmentPath!.startsWith('mock_path') &&
          File(message.attachmentPath!).existsSync();

      return GestureDetector(
        onTap: () {
          if (hasRealFile) {
            _showFullScreenImage(context, message.attachmentPath!);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black26,
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasRealFile)
                  Hero(
                    tag: message.attachmentPath!,
                    child: Image.file(
                      File(message.attachmentPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF434343), Color(0xFF000000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white60,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF434343), Color(0xFF000000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white60,
                        size: 40,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          hasRealFile ? 'Photo' : 'Captured Image',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    } else if (message.attachmentType == AttachmentType.audio) {
      return AudioBubblePlayer(
        attachmentPath: message.attachmentPath,
        isUser: isUser,
      );
    } else if (message.attachmentType == AttachmentType.file) {
      return Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.greenAccent,
              child: Icon(Icons.description, color: Colors.black87, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Study Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.attachmentPath != null
                        ? message.attachmentPath!.split('_').last
                        : 'textbook_chapter.pdf',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInteractiveStudyCards(BuildContext context, String jsonText) {
    try {
      final List<dynamic> cards = jsonDecode(jsonText);
      return Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 200,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: PageView.builder(
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            if (card['type'] == 'flashcard') {
              return _FlashcardWidget(
                question: card['question'] ?? '',
                answer: card['answer'] ?? '',
              );
            } else if (card['type'] == 'quiz_question') {
              return _QuizWidget(
                question: card['question'] ?? '',
                options: List<String>.from(card['options'] ?? []),
                correctIndex: card['correct_index'] ?? 0,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    } catch (e) {
      // Fallback in case of JSON parse failure
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Malformed study card payload:\n$jsonText",
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2732),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            content: const Row(
              children: [
                Icon(Icons.copy_all, color: Colors.greenAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Response copied to clipboard!',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  void _showFullScreenImage(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: path,
                      child: Image.file(
                        File(path),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------
// Flip Flashcard Sub-Widget
// ----------------------------------------------------
class _FlashcardWidget extends StatefulWidget {
  final String question;
  final String answer;

  const _FlashcardWidget({
    required this.question,
    required this.answer,
  });

  @override
  State<_FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<_FlashcardWidget> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAnswer = !_showAnswer;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _showAnswer
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                )
              : const LinearGradient(
                  colors: [AppColors.surface, AppColors.surfaceLight],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(76),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FLASHCARD',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.flip_camera_android, color: Colors.white60, size: 18),
              ],
            ),
            const Spacer(),
            Text(
              _showAnswer ? widget.answer : widget.question,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: _showAnswer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            const Text(
              'Tap to Flip',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Multiple Choice Quiz Sub-Widget
// ----------------------------------------------------
class _QuizWidget extends StatefulWidget {
  final String question;
  final List<String> options;
  final int correctIndex;

  const _QuizWidget({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  @override
  State<_QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<_QuizWidget> {
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'QUIZ',
              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 2.8,
              ),
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final isSelected = _selectedIdx == index;
                final isCorrect = index == widget.correctIndex;
                
                Color optionColor = AppColors.surfaceLight;
                if (_selectedIdx != null) {
                  if (isCorrect) {
                    optionColor = Colors.green.shade800;
                  } else if (isSelected) {
                    optionColor = Colors.red.shade800;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (_selectedIdx == null) {
                      setState(() {
                        _selectedIdx = index;
                      });
                    }
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: optionColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.white10,
                      ),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AudioBubblePlayer extends StatefulWidget {
  final String? attachmentPath;
  final bool isUser;

  const AudioBubblePlayer({
    super.key,
    required this.attachmentPath,
    required this.isUser,
  });

  @override
  State<AudioBubblePlayer> createState() => _AudioBubblePlayerState();
}

class _AudioBubblePlayerState extends State<AudioBubblePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    _checkFile();
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _completeSub = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _checkFile() async {
    if (widget.attachmentPath != null) {
      final file = File(widget.attachmentPath!);
      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _fileExists = exists;
        });
      }
      if (exists) {
        try {
          // Preload source to retrieve duration
          await _audioPlayer.setSource(DeviceFileSource(widget.attachmentPath!));
        } catch (e) {
          debugPrint('Error setting source: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (!_fileExists || widget.attachmentPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.attachmentPath!));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString();
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_fileExists) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade300, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Audio file unavailable',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final totalSeconds = _duration.inSeconds;
    final currentSeconds = _position.inSeconds;
    final progress = totalSeconds > 0 ? currentSeconds / totalSeconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isUser ? const Color(0xFF1E2732) : Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isUser ? Colors.white.withValues(alpha: 0.08) : Colors.white10,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _playPause,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (_duration.inMilliseconds > 0) {
                final pct = (details.localPosition.dx / 140.0).clamp(0.0, 1.0);
                final seekToMs = (pct * _duration.inMilliseconds).round();
                _audioPlayer.seek(Duration(milliseconds: seekToMs));
              }
            },
            onHorizontalDragUpdate: (details) {
              if (_duration.inMilliseconds > 0) {
                final pct = (details.localPosition.dx / 140.0).clamp(0.0, 1.0);
                final seekToMs = (pct * _duration.inMilliseconds).round();
                _audioPlayer.seek(Duration(milliseconds: seekToMs));
              }
            },
            child: _AudioWaveformProgress(
              progress: progress,
              isUser: widget.isUser,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_position.inSeconds > 0 ? _position : _duration),
            style: TextStyle(
              color: widget.isUser ? Colors.white70 : Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioWaveformProgress extends StatelessWidget {
  final double progress;
  final bool isUser;

  const _AudioWaveformProgress({
    required this.progress,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    // Predefined heights for the vertical bars to render a neat waveform
    final List<double> heights = [
      4, 6, 8, 10, 6, 8, 12, 16, 14, 10, 8, 12, 18, 14, 10, 6, 8, 14, 16, 12, 8, 6, 8, 12, 16, 14, 10, 8, 6, 10, 12, 10, 8, 6, 4
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(heights.length, (index) {
        final barProgress = index / heights.length;
        final isActive = progress >= barProgress;
        final Color color = isActive
            ? const Color(0xFF2E87FF)
            : (isUser ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.12));

        return Container(
          width: 2,
          height: heights[index],
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
