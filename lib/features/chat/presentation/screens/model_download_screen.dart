import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/model_download_service.dart';

class ModelDownloadScreen extends StatefulWidget {
  final ModelDownloadService downloadService;
  final VoidCallback onDownloadComplete;

  const ModelDownloadScreen({
    super.key,
    required this.downloadService,
    required this.onDownloadComplete,
  });

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  @override
  void initState() {
    super.initState();
    widget.downloadService.stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.downloadService.stateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (widget.downloadService.stateNotifier.value == DownloadState.completed) {
      widget.onDownloadComplete();
    }
  }

  Future<void> _checkAndDownload(BuildContext context) async {
    // Show checking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final int freeSpace = await widget.downloadService.getFreeDiskSpace();
    
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (freeSpace != -1) {
      // 3.0 GB = 3,221,225,472 bytes
      const int requiredSpace = 3221225472;
      if (freeSpace < requiredSpace) {
        final double availableGb = freeSpace / (1024 * 1024 * 1024);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Storage Space Warning', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Text(
                'Gemma 4 requires at least 3.0 GB of free space to download. You currently only have ${availableGb.toStringAsFixed(2)} GB free on your device.\n\nPlease clear some space before proceeding.',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // Show cellular warning dialog
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.network_check, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('Network Warning', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'You are about to download a 2.59 GB file. We highly recommend connecting to Wi-Fi to avoid potential mobile data charges.\n\nDo you want to continue?',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.downloadService.startDownload();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Download Anyway'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Top AI Icon / Branding (with dancing animations)
              Center(
                child: ValueListenableBuilder<DownloadState>(
                  valueListenable: widget.downloadService.stateNotifier,
                  builder: (context, state, child) {
                    final isDownloading = state == DownloadState.downloading;
                    return DancingAIWidget(isDownloading: isDownloading);
                  },
                ),
              ),
              const SizedBox(height: 32),
              // Title & Subtitle
              const Text(
                'Setup Gemma 4 E2B',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Download the 2.59 GB on-device study engine. All reasoning runs 100% locally in Airplane Mode.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              
              // Progress Bar Section
              ValueListenableBuilder<DownloadState>(
                valueListenable: widget.downloadService.stateNotifier,
                builder: (context, state, child) {
                  return ValueListenableBuilder<int>(
                    valueListenable: widget.downloadService.progressNotifier,
                    builder: (context, progress, child) {
                      if (state == DownloadState.notStarted) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                state == DownloadState.completed
                                    ? 'Completed'
                                    : 'Downloading...',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$progress%',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Wavy progress indicator
                          WavyProgressIndicator(
                            value: progress / 100,
                            isDownloading: state == DownloadState.downloading,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You can close the app. Progress is shown in the notification bar.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  );
                },
              ),

              // Action Buttons
              ValueListenableBuilder<DownloadState>(
                valueListenable: widget.downloadService.stateNotifier,
                builder: (context, state, child) {
                  final isDownloading = state == DownloadState.downloading;
                  final isFailed = state == DownloadState.failed;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state == DownloadState.notStarted || isFailed)
                        ElevatedButton(
                          onPressed: () => _checkAndDownload(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Download Model (2.59 GB)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (isDownloading)
                        ElevatedButton.icon(
                          onPressed: widget.downloadService.cancelDownload,
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text('Cancel Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withAlpha(204),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class DancingAIWidget extends StatelessWidget {
  final bool isDownloading;
  const DancingAIWidget({super.key, required this.isDownloading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(76),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_outlined,
            color: Colors.white,
            size: 64,
          ),
        ),
      ),
    );
  }
}

class WavyProgressIndicator extends StatefulWidget {
  final double value;
  final bool isDownloading;

  const WavyProgressIndicator({
    super.key,
    required this.value,
    required this.isDownloading,
  });

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isDownloading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WavyProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDownloading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isDownloading && _controller.isAnimating) {
      _controller.stop();
    }
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
        return CustomPaint(
          size: const Size(double.infinity, 24),
          painter: _WavyProgressPainter(
            value: widget.value,
            animationValue: _controller.value,
            isDownloading: widget.isDownloading,
          ),
        );
      },
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double value;
  final double animationValue;
  final bool isDownloading;

  _WavyProgressPainter({
    required this.value,
    required this.animationValue,
    required this.isDownloading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    final double width = size.width;
    final double progressWidth = width * value;
    final double phase = isDownloading ? animationValue * 2 * pi : 0.0;

    // 1. Active wave segment (0 to progressWidth) - colored in AppColors.primary
    if (progressWidth > 0) {
      final Paint progressPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      final Path progressPath = Path();
      progressPath.moveTo(0, midY + 6.0 * sin(-phase));

      for (double x = 0; x <= progressWidth; x += 2) {
        final double y = midY + 6.0 * sin(x * 0.08 - phase);
        progressPath.lineTo(x, y);
      }
      canvas.drawPath(progressPath, progressPaint);
    }

    // 2. Remaining track wave segment (progressWidth to width) - colored in AppColors.surfaceLight
    if (progressWidth < width) {
      final Paint trackPaint = Paint()
        ..color = AppColors.surfaceLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final Path trackPath = Path();
      // Start exactly at progressWidth
      final double startY = midY + 6.0 * sin(progressWidth * 0.08 - phase);
      trackPath.moveTo(progressWidth, startY);

      for (double x = progressWidth; x <= width; x += 2) {
        final double y = midY + 6.0 * sin(x * 0.08 - phase);
        trackPath.lineTo(x, y);
      }
      canvas.drawPath(trackPath, trackPaint);
    }

    // 3. Glowing indicator dot at the boundary
    if (progressWidth > 0 && progressWidth < width) {
      final double endX = progressWidth;
      final double endY = midY + 6.0 * sin(endX * 0.08 - phase);
      
      final Paint dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
        
      final Paint dotGlowPaint = Paint()
        ..color = AppColors.primary.withAlpha(150)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(endX, endY), 6.0, dotGlowPaint);
      canvas.drawCircle(Offset(endX, endY), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isDownloading != isDownloading;
  }
}
