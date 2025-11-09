// lib/services/connectivity_service.dart
// Интернет холболт шалгах үйлчилгээ

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final StreamController<ConnectivityResult> _statusController =
  StreamController<ConnectivityResult>.broadcast();

  // Getters
  bool get isConnected => _connectionStatus != ConnectivityResult.none;
  bool get isWifi => _connectionStatus == ConnectivityResult.wifi;
  bool get isMobile => _connectionStatus == ConnectivityResult.mobile;
  Stream<ConnectivityResult> get onConnectivityChanged => _statusController.stream;
  ConnectivityResult get currentStatus => _connectionStatus;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Get initial status
      _connectionStatus = await _connectivity.checkConnectivity();
      _statusController.add(_connectionStatus);

      // Listen for changes
      _subscription = _connectivity.onConnectivityChanged.listen(
            (ConnectivityResult result) {
          _connectionStatus = result;
          _statusController.add(result);
          print('🌐 Холболтын төлөв солигдлоо: ${_getStatusText(result)}');
        },
        onError: (error) {
          print('❌ Холболтын төлөв шалгахад алдаа: $error');
        },
      );
    } catch (e) {
      print('❌ ConnectivityService эхлүүлэхэд алдаа: $e');
    }
  }

  // Check if internet is available
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _connectionStatus = result;
      return result != ConnectivityResult.none;
    } catch (e) {
      print('❌ Холболт шалгахад алдаа: $e');
      return false;
    }
  }

  // Get connection status text in Mongolian
  String getStatusText() {
    return _getStatusText(_connectionStatus);
  }

  String _getStatusText(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi холбогдсон';
      case ConnectivityResult.mobile:
        return 'Мобайл дата холбогдсон';
      case ConnectivityResult.ethernet:
        return 'Ethernet холбогдсон';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth холбогдсон';
      case ConnectivityResult.vpn:
        return 'VPN холбогдсон';
      case ConnectivityResult.none:
        return 'Интернет холболт байхгүй';
      case ConnectivityResult.other:
        return 'Тодорхойгүй холболт';
    }
  }

  // Show connectivity snackbar
  void showConnectivitySnackBar(BuildContext context, ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _getStatusText(result),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isConnected ? Colors.green : Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Dispose
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

// Connectivity Provider for easy state management
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service = ConnectivityService();
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityResult _status = ConnectivityResult.none;

  bool get isConnected => _status != ConnectivityResult.none;
  bool get isWifi => _status == ConnectivityResult.wifi;
  bool get isMobile => _status == ConnectivityResult.mobile;
  String get statusText => _service.getStatusText();
  ConnectivityResult get status => _status;

  ConnectivityProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    _status = _service.currentStatus;

    _subscription = _service.onConnectivityChanged.listen((result) {
      _status = result;
      notifyListeners();
    });
  }

  Future<bool> checkConnection() async {
    final isConnected = await _service.checkConnection();
    _status = _service.currentStatus;
    notifyListeners();
    return isConnected;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}