// lib/widgets/internet_wrapper.dart
import 'package:flutter/material.dart';
import 'package:ohana_store/core/services/connectivity_service.dart';
import 'package:provider/provider.dart';

class InternetWrapper extends StatelessWidget {
  final Widget child;
  const InternetWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ConnectivityService>().isConnected;

    return Column(
      children: [
        // Анимированная плашка "Нет интернета"
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isConnected ? 0 : 30 + MediaQuery.of(context).padding.top,
          color: Colors.redAccent,
          width: double.infinity,
          child: isConnected
              ? const SizedBox.shrink()
              : SafeArea(
                  bottom: false,
                  child: const Center(
                    child: Text(
                      'ОЖИДАНИЕ СЕТИ...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
        ),
        // Основное приложение
        Expanded(child: child),
      ],
    );
  }
}
