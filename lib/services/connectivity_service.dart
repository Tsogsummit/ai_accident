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

  bool get isConnected => _connectionStatus != ConnectivityResult.none;
  bool get isWifi => _connectionStatus == ConnectivityResult.wifi;
  bool get isMobile => _connectionStatus == ConnectivityResult.mobile;
  Stream<ConnectivityResult> get onConnectivityChanged => _statusController.stream;
  ConnectivityResult get currentStatus => _connectionStatus;

  Future<void> initialize() async {
    if (_subscription != null) {
      return;
    }

    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _statusController.add(_connectionStatus);

      _subscription = _connectivity.onConnectivityChanged.listen(
            (ConnectivityResult result) {
          _connectionStatus = result;
          _statusController.add(result);
          print('Connectivity status changed: ${_getStatusText(result)}');
        },
        onError: (error) {
          print('Error checking connectivity status: $error');
        },
      );
    } catch (e) {
      print('Error initializing ConnectivityService: $e');
    }
  }

  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _connectionStatus = result;
      return result != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connection: $e');
      return false;
    }
  }

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

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

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