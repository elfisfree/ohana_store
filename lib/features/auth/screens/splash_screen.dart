// lib/features/auth/screens/splash_screen.dart - ЭТОТ КОД ПРАВИЛЬНЫЙ

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final session = supabase.auth.currentSession;

    if (session == null) {
      context.go('/login');
      return;
    }

    try {
      final userId = session.user.id;
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = response['role'] as String;

      switch (role) {
        case 'admin':
          context.go('/admin');
          break;
        case 'collector':
          context.go('/warehouse'); // Отправляем на склад
          break;
        case 'courier':
          context.go('/delivery'); // Отправляем в доставку
          break;
        default:
          context.go('/home'); // Покупатели идут в каталог
      }
    } catch (e) {
      print('Ошибка при загрузке профиля на SplashScreen: $e');
      await supabase.auth.signOut();
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
