// lib/core/utils/app_notifications.dart
import 'package:flutter/material.dart';

class AppNotifications {
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      Colors.green.shade600,
      Icons.check_circle_outline,
    );
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red.shade700, Icons.error_outline);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.blue.shade600, Icons.info_outline);
  }

  static void _showSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(); // Убираем предыдущее, если есть

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // Делаем "парящим"
        margin: const EdgeInsets.all(20), // Отступы от краев экрана
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }
}
