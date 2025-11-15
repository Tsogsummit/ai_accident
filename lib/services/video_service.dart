// lib/services/video_service.dart - ЗАСВАРЛАСАН FLUTTER VIDEO SERVICE
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class VideoService {
  late final Dio _dio;
  final AuthService _authService = AuthService();
  
  VideoService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.videoServiceUrl,
        connectTimeout: Duration(minutes: 2),
        receiveTimeout: Duration(minutes: 5),
        sendTimeout: Duration(minutes: 5),
        headers: ApiConfig.defaultHeaders,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );
    
    // Retry interceptor
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: 2,
        retryDelays: [
          Duration(seconds: 3),
          Duration(seconds: 5),
        ],
      ),
    );
    
    // Auth token interceptor
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
    
    // Logging
    if (ApiConfig.enableLogging && ApiConfig.isDevelopment) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestBody: false,
          responseBody: true,
          error: true,
        ),
      );
    }
  }
  
  // ==========================================
  // VIDEO UPLOAD - SIMPLIFIED
  // ==========================================
  
  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    required double latitude,
    required double longitude,
    required String description,
    String severity = 'moderate',
    File? thumbnailFile,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      // Validate file size
      final fileSize = await videoFile.length();
      if (!ApiConfig.isValidVideoSize(fileSize)) {
        throw Exception(
          'Видео хэт том байна. Максимум: ${ApiConfig.maxVideoSizeMB}MB\n'
          'Танай файл: ${ApiConfig.formatFileSize(fileSize)}'
        );
      }
      
      // Validate extension
      if (!ApiConfig.isValidVideoExtension(videoFile.path)) {
        throw Exception(
          'Видеоны формат буруу. Зөвшөөрөгдсөн: ${ApiConfig.allowedVideoFormats.join(", ")}'
        );
      }
      
      print('📹 Video upload эхэллээ: ${ApiConfig.formatFileSize(fileSize)}');
      
      // Get user ID
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('Нэвтрэх шаардлагатай');
      }
      
      // Prepare form data
      FormData formData = FormData.fromMap({
        'userId': userId.toString(),
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'description': description,
        'severity': severity,
        'video': await MultipartFile.fromFile(
          videoFile.path,
          filename: 'accident_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      });
      
      print('📤 Sending to: ${ApiConfig.videoServiceUrl}/upload');
      print('📦 Form data: userId=$userId, lat=$latitude, lng=$longitude');
      
      // Upload video
      final response = await _dio.post(
        '/upload',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          print('📊 Upload: ${(progress * 100).toStringAsFixed(1)}% ($sent / $total bytes)');
          if (onProgress != null) {
            onProgress(sent, total);
          }
        },
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['success'] == true) {
          print('✅ Видео амжилттай илгээгдлээ');
          
          return {
            'success': true,
            'message': response.data['message'] ?? 'Видео амжилттай илгээгдлээ',
            'videoId': response.data['videoId'],
            'accidentId': response.data['accidentId'],
            'status': response.data['status'] ?? 'processed',
          };
        } else {
          throw Exception(response.data['error'] ?? 'Видео илгээхэд алдаа гарлаа');
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode}\n'
          '${response.data['error'] ?? response.data['message'] ?? 'Unknown error'}'
        );
      }
    } on DioException catch (e) {
      print('❌ DioException: ${e.type}');
      print('❌ Message: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw Exception('Видео илгээхэд алдаа гарлаа: $e');
    }
  }
  
  // ==========================================
  // VIDEO STATUS
  // ==========================================
  
  Future<Map<String, dynamic>> getVideoStatus(String videoId) async {
    try {
      final response = await _dio.get('/$videoId/status');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'videoId': response.data['videoId'],
          'status': response.data['status'],
          'accidentId': response.data['accidentId'],
        };
      }
      
      return {'success': false, 'error': 'Статус авахад алдаа гарлаа'};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // ==========================================
  // GET VIDEOS
  // ==========================================
  
  Future<List<Map<String, dynamic>>> getVideos({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (status != null) queryParams['status'] = status;
      
      final response = await _dio.get(
        '/videos',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.cast<Map<String, dynamic>>();
      }
      
      return [];
    } on DioException catch (e) {
      print('❌ Get videos error: ${e.message}');
      return [];
    }
  }
  
  // ==========================================
  // DELETE VIDEO
  // ==========================================
  
  Future<bool> deleteVideo(String videoId) async {
    try {
      final userId = await _authService.getUserId();
      
      final response = await _dio.delete(
        '/$videoId',
        data: {'userId': userId},
      );
      
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      print('❌ Delete video error: ${e.message}');
      return false;
    }
  }
  
  // ==========================================
  // ERROR HANDLING
  // ==========================================
  
  String _handleError(DioException e) {
    print('🔍 Error details:');
    print('   Type: ${e.type}');
    print('   Message: ${e.message}');
    print('   Response: ${e.response?.data}');
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Файл илгээх хугацаа дууслаа. Интернет холболтоо шалгана уу.';
        
      case DioExceptionType.receiveTimeout:
        return 'Серверээс хариу хүлээх хугацаа дууслаа. Дахин оролдоно уу.';
        
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        
        String message = 'Серверийн алдаа';
        
        if (data is Map) {
          message = data['error']?.toString() ?? 
                   data['message']?.toString() ?? 
                   'Тодорхойгүй алдаа';
        }
        
        if (statusCode == 401) {
          return 'Нэвтрэх эрх дууссан. Дахин нэвтэрнэ үү.';
        } else if (statusCode == 413) {
          return 'Файл хэт том байна. Багасгаад дахин оролдоно уу.';
        } else if (statusCode == 415) {
          return 'Файлын формат буруу байна.';
        }
        
        return '$message (Код: $statusCode)';
        
      case DioExceptionType.connectionError:
        return 'Интернет холболт тасарсан. WiFi эсвэл мобайл датаа шалгана уу.';
        
      case DioExceptionType.cancel:
        return 'Upload цуцлагдсан';
        
      default:
        return 'Файл илгээхэд алдаа гарлаа: ${e.message ?? "Unknown error"}';
    }
  }
  
  void dispose() {
    _dio.close();
  }
}