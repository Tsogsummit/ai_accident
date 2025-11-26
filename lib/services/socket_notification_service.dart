import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'local_notification_service.dart';
import '../config/api_config.dart';

class SocketNotificationService {
  static final SocketNotificationService _instance = SocketNotificationService._internal();
  factory SocketNotificationService() => _instance;
  SocketNotificationService._internal();

  IO.Socket? _socket;
  final _localNotificationService = LocalNotificationService();
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void connect(int userId) {
    if (_socket != null && _isConnected) {
      print('Socket already connected');
      return;
    }

    try {
      _socket = IO.io(
        ApiConfig.notificationServiceUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket!.onConnect((_) {
        print('Socket connected successfully');
        _isConnected = true;
        _socket!.emit('register', userId);
        print('User registered: $userId');
      });

      _socket!.onDisconnect((_) {
        print('Socket disconnected');
        _isConnected = false;
      });

      _socket!.onConnectError((error) {
        print('Connection error: $error');
        _isConnected = false;
      });

      _socket!.onError((error) {
        print('Socket error: $error');
      });

      _socket!.on('notification', (data) {
        print('Notification received: $data');
        _handleNotification(data);
      });

      _socket!.connect();
    } catch (e) {
      print('Socket initialization error: $e');
    }
  }

  void _handleNotification(dynamic data) {
    try {
      final notificationData = data as Map<String, dynamic>;
      final id = notificationData['id'] ?? 0;
      final title = notificationData['title'] ?? 'New Notification';
      final message = notificationData['message'] ?? '';
      final type = notificationData['type'] ?? 'general';
      final accidentId = notificationData['accident_id'];

      if (accidentId != null) {
        _localNotificationService.showAccidentNotification(
          accidentId: accidentId is int ? accidentId : int.tryParse(accidentId.toString()) ?? 0,
          title: title,
          message: message,
          type: type,
        );
      } else {
        _localNotificationService.showNotification(
          id: id is int ? id : int.tryParse(id.toString()) ?? 0,
          title: title,
          body: message,
          payload: type,
        );
      }
    } catch (e) {
      print('Error handling notification: $e');
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      print('Socket disconnected and disposed');
    }
  }

  void reconnect(int userId) {
    disconnect();
    connect(userId);
  }
}
