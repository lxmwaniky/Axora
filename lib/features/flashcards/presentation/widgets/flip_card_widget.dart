import 'dart:math';
import 'package:flutter/material.dart';

class FlipCardWidget extends StatefulWidget {
  final String frontText;
  final String backText;

  const FlipCardWidget({
    super.key,
    required this.frontText,
    required this.backText,
  });

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  // Ensure card resets to front when content changes
  @override
  void didUpdateWidget(covariant FlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frontText != widget.frontText || oldWidget.backText != widget.backText) {
      _controller.value = 0;
      _isFront = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value;
          final showFront = angle < pi / 2;
          
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // Perspective depth
              ..rotateY(angle),
            alignment: Alignment.center,
            child: showFront
                ? _buildCardSide(
                    text: widget.frontText,
                    isFront: true,
                  )
                : Transform(
                    transform: Matrix4.identity()..rotateY(pi), // Prevent mirrored text
                    alignment: Alignment.center,
                    child: _buildCardSide(
                      text: widget.backText,
                      isFront: false,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardSide({required String text, required bool isFront}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isFront
            ? const LinearGradient(
                colors: [Color(0xFF1E1E2F), Color(0xFF12121A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isFront ? Colors.white.withAlpha(25) : Colors.white.withAlpha(50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFront 
                ? Colors.black.withAlpha(127)
                : const Color(0xFF6D28D9).withAlpha(100),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isFront ? Colors.white10 : Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isFront ? 'QUESTION' : 'ANSWER',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Icon(
                isFront ? Icons.flip_camera_android_rounded : Icons.check_circle_outline_rounded,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),
          
          // Main Text Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: isFront ? FontWeight.w600 : FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          
          // Action hint at bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                color: isFront ? Colors.white38 : Colors.white60,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                isFront ? 'Tap to reveal answer' : 'Tap to see question',
                style: TextStyle(
                  color: isFront ? Colors.white38 : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
