import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class NotificationService {
  late final Dio _dio;
  final AuthService _authService = AuthService();

  NotificationService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.notificationServiceUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: ApiConfig.defaultHeaders,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: ApiConfig.maxRetryAttempts,
        retryDelays: [
          ApiConfig.retryDelay,
          ApiConfig.retryDelay * 2,
          ApiConfig.retryDelay * 3,
        ],
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _authService.refreshAccessToken();
            if (refreshed) {
              final token = await _authService.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';

              try {
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    if (ApiConfig.enableLogging && ApiConfig.isDevelopment) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> getNotifications(
    int userId, {
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/notifications',
        queryParameters: {
          'userId': userId,
          'page': page,
          'limit': limit,
          'unreadOnly': unreadOnly,
        },
      );

      if (response.statusCode == 200 && response.data['success']) {
        final notifications = (response.data['notifications'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();

        print('${notifications.length} notifications loaded');

        return {
          'success': true,
          'notifications': notifications,
          'unreadCount': response.data['unreadCount'] ?? 0,
          'total': response.data['total'] ?? 0,
        };
      }

      return {
        'success': false,
        'error': response.data['error'] ?? 'An error occurred',
        'notifications': [],
        'unreadCount': 0,
      };
    } on DioException catch (e) {
      print('Notification error: ${e.message}');
      return {
        'success': false,
        'error': _handleError(e),
        'notifications': [],
        'unreadCount': 0,
      };
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      print('Marking notification as read: id=$notificationId');

      final response = await _dio.put('/notifications/$notificationId/read');

      if (response.statusCode == 200 && response.data['success']) {
        print('Notification marked as read');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('Mark as read error: ${e.message}');
      return false;
    }
  }

  Future<bool> markAllAsRead(int userId) async {
    try {
      print('Marking all notifications as read: userId=$userId');

      final response = await _dio.put(
        '/notifications/read-all',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('All notifications marked as read');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('Mark all as read error: ${e.message}');
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId, int userId) async {
    try {
      print('Deleting notification: id=$notificationId');

      final response = await _dio.delete(
        '/notifications/$notificationId',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('Notification deleted');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('Delete notification error: ${e.message}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSettings(int userId) async {
    try {
      final response = await _dio.get('/notifications/settings/$userId');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }

      return null;
    } on DioException catch (e) {
      print('Get settings error: ${e.message}');
      return null;
    }
  }

  Future<bool> updateSettings({
    required int userId,
    bool? pushEnabled,
    int? radius,
    List<String>? accidentTypes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (pushEnabled != null) data['pushEnabled'] = pushEnabled;
      if (radius != null) data['radius'] = radius;
      if (accidentTypes != null) data['accidentTypes'] = accidentTypes;

      final response = await _dio.put(
        '/notifications/settings/$userId',
        data: data,
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('Settings updated successfully');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('Update settings error: ${e.message}');
      return false;
    }
  }

  Future<bool> registerFcmToken(int userId, String fcmToken) async {
    try {
      final response = await _dio.post(
        '/notifications/register-token',
        data: {'userId': userId, 'fcmToken': fcmToken},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('FCM token registered');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('Register FCM token error: ${e.message}');
      return false;
    }
  }

  Future<bool> unregisterFcmToken(int userId) async {
    try {
      final response = await _dio.delete(
        '/notifications/unregister-token',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('FCM token unregistered');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('Unregister FCM token error: ${e.message}');
      return false;
    }
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection and try again.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message =
            e.response?.data?['error'] ?? e.response?.data?['message'];

        if (statusCode == 401) {
          return 'Your session has expired. Please login again.';
        } else if (statusCode == 403) {
          return 'You do not have permission to access this.';
        } else if (statusCode == 404) {
          return 'Notification not found.';
        } else if (message != null) {
          return message.toString();
        }
        return 'Server error occurred. Please try again later.';

      case DioExceptionType.connectionError:
        return 'Connection failed. Please check your internet connection.';

      default:
        return 'An error occurred. Please try again.';
    }
  }

  void dispose() {
    _dio.close();
  }
}
