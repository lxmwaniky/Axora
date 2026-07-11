import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0E0E10);
  static const Color surface = Color(0xFF18181B);
  static const Color surfaceLight = Color(0xFF27272A);

  // Brand / Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color secondary = Color(0xFFEC4899); // Pink
  static const Color accent = Color(0xFF8B5CF6); // Violet

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient instagramGradient = LinearGradient(
    colors: [
      Color(0xFF833AB4), // Purple
      Color(0xFFFD1D1D), // Red
      Color(0xFFF77737), // Orange
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text colors
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Message Bubbles
  static const Color receiverBubble = Color(0xFF27272A);
  static const Color senderBubbleText = Colors.white;
  static const Color receiverBubbleText = Color(0xFFF4F4F5);

  // Curated premium gradients for unique session DPs
  static final List<LinearGradient> avatarGradients = [
    const LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    const LinearGradient(
      colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    const LinearGradient(
      colors: [Color(0xFF14B8A6), Color(0xFF10B981)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    const LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    const LinearGradient(
      colors: [Color(0xFFF97316), Color(0xFFEF4444)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    const LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];
}
