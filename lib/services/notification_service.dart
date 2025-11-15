// lib/services/notification_service.dart - ШИНЭ
import 'dart:convert';
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
      ),
    );

    // Add retry interceptor
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

    // Add auth token interceptor
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
            // Try to refresh token
            final refreshed = await _authService.refreshAccessToken();
            if (refreshed) {
              // Retry request with new token
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

    // Add logging (development only)
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

  // ==========================================
  // GET NOTIFICATIONS
  // ==========================================

  Future<Map<String, dynamic>> getNotifications(
    int userId, {
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      print('📬 Мэдэгдэл ачааллаж байна: userId=$userId');

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

        print('✅ ${notifications.length} мэдэгдэл ачаалагдлаа');

        return {
          'success': true,
          'notifications': notifications,
          'unreadCount': response.data['unreadCount'] ?? 0,
          'total': response.data['total'] ?? 0,
        };
      }

      return {
        'success': false,
        'error': response.data['error'] ?? 'Алдаа гарлаа',
        'notifications': [],
        'unreadCount': 0,
      };
    } on DioException catch (e) {
      print('❌ Notification error: ${e.message}');
      return {
        'success': false,
        'error': _handleError(e),
        'notifications': [],
        'unreadCount': 0,
      };
    }
  }

  // ==========================================
  // MARK AS READ
  // ==========================================

  Future<bool> markAsRead(String notificationId) async {
    try {
      print('✅ Мэдэгдэл уншиж байна: id=$notificationId');

      final response = await _dio.put(
        '/notifications/$notificationId/read',
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('✅ Мэдэгдэл уншигдлаа');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Mark as read error: ${e.message}');
      return false;
    }
  }

  // ==========================================
  // MARK ALL AS READ
  // ==========================================

  Future<bool> markAllAsRead(int userId) async {
    try {
      print('✅ Бүх мэдэгдэл уншиж байна: userId=$userId');

      final response = await _dio.put(
        '/notifications/read-all',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('✅ Бүх мэдэгдэл уншигдлаа');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Mark all as read error: ${e.message}');
      return false;
    }
  }

  // ==========================================
  // DELETE NOTIFICATION
  // ==========================================

  Future<bool> deleteNotification(String notificationId, int userId) async {
    try {
      print('🗑️ Мэдэгдэл устгаж байна: id=$notificationId');

      final response = await _dio.delete(
        '/notifications/$notificationId',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('✅ Мэдэгдэл устгагдлаа');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Delete notification error: ${e.message}');
      return false;
    }
  }

  // ==========================================
  // GET NOTIFICATION SETTINGS
  // ==========================================

  Future<Map<String, dynamic>?> getSettings(int userId) async {
    try {
      final response = await _dio.get('/notifications/settings/$userId');

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data'];
      }

      return null;
    } on DioException catch (e) {
      print('❌ Get settings error: ${e.message}');
      return null;
    }
  }

  // ==========================================
  // UPDATE NOTIFICATION SETTINGS
  // ==========================================

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
        print('✅ Тохиргоо шинэчлэгдлээ');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Update settings error: ${e.message}');
      return false;
    }
  }

  // ==========================================
  // REGISTER FCM TOKEN
  // ==========================================

  Future<bool> registerFcmToken(int userId, String fcmToken) async {
    try {
      final response = await _dio.post(
        '/notifications/register-token',
        data: {
          'userId': userId,
          'fcmToken': fcmToken,
        },
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('✅ FCM токен бүртгэгдлээ');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Register FCM token error: ${e.message}');
      return false;
    }
  }

  // ==========================================
  // UNREGISTER FCM TOKEN
  // ==========================================

  Future<bool> unregisterFcmToken(int userId) async {
    try {
      final response = await _dio.delete(
        '/notifications/unregister-token',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success']) {
        print('✅ FCM токен устгагдлаа');
        return true;
      }

      return false;
    } on DioException catch (e) {
      print('❌ Unregister FCM token error: ${e.message}');
      return false;
    }
  }

  // ==========================================
  // ERROR HANDLING
  // ==========================================

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Холболтын хугацаа дууслаа. Интернет холболтоо шалгана уу.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error'] ?? e.response?.data?['message'];

        if (statusCode == 401) {
          return 'Нэвтрэх эрх дууссан. Дахин нэвтэрнэ үү.';
        } else if (statusCode == 403) {
          return 'Хандах эрх байхгүй.';
        } else if (statusCode == 404) {
          return 'Мэдэгдэл олдсонгүй.';
        } else if (message != null) {
          return message.toString();
        }
        return 'Серверийн алдаа гарлаа.';

      case DioExceptionType.connectionError:
        return 'Интернет холболт тасарсан.';

      default:
        return 'Алдаа гарлаа. Дахин оролдоно уу.';
    }
  }

  void dispose() {
    _dio.close();
  }
}