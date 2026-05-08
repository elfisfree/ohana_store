// lib/features/auth/auth_notifier.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ohana_store/main.dart';

class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  AuthNotifier() {
    _subscription = supabase.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
