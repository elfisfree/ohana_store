// lib/core/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  ConnectivityService() {
    _checkInitial();
    // Слушаем изменения сети в реальном времени
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // Если в списке есть хоть какой-то результат кроме .none — интернет есть
    final bool connected = !results.contains(ConnectivityResult.none);
    if (_isConnected != connected) {
      _isConnected = connected;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
