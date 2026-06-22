import 'package:flutter/material.dart';

class AdminColors {
  static const background = Color(0xFFF8F9FD);
  static const sidebar = Colors.white;
  static const card = Colors.white; //цвет заливки фона
  static const accentPurple = Color(0xFF673AB7);
  static const textPrimary = Color.fromARGB(255, 0, 0, 0);
  static const textSecondary = Color.fromARGB(255, 95, 95, 95);

  static List<BoxShadow> shadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
