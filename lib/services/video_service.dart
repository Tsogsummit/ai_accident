// lib/services/video_service.dart - ЗАСВАРЛАСАН VIDEO UPLOAD SERVICE
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
        baseUrl: ApiConfig.videoServiceUrl,  // ✅ Video service URL ашиглах
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: Duration(minutes: 5), // Video upload-д урт хугацаа
        sendTimeout: Duration(minutes: 5),
        headers: ApiConfig.defaultHeaders,
      ),
    );
    
    // Add retry interceptor
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: 2, // Video upload-д бага retry
        retryDelays: [
          Duration(seconds: 3),
          Duration(seconds: 5),
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
          // Handle 401 - try to refresh token
          if (error.response?.statusCode == 401) {
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
          requestBody: false, // Video болон зураг биш харуулах
          responseBody: true,
          error: true,
        ),
      );
    }
  }
  
  // ==========================================
  // VIDEO UPLOAD
  // ==========================================
  
  /// Upload video with accident report
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
          'Видео хэт том байна. Максимум хэмжээ: ${ApiConfig.maxVideoSizeMB}MB\n'
          'Танай файл: ${ApiConfig.formatFileSize(fileSize)}'
        );
      }
      
      // Validate file extension
      if (!ApiConfig.isValidVideoExtension(videoFile.path)) {
        throw Exception(
          'Видеоны формат буруу байна. Зөвшөөрөгдсөн форматууд: ${ApiConfig.allowedVideoFormats.join(", ")}'
        );
      }
      
      print('📹 Видео upload эхэллээ: ${ApiConfig.formatFileSize(fileSize)}');
      
      // Get user ID
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('Нэвтрэх шаардлагатай');
      }
      
      // Prepare form data
      FormData formData = FormData.fromMap({
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'severity': severity,
        'video': await MultipartFile.fromFile(
          videoFile.path,
          filename: 'accident_${DateTime.now().millisecondsSinceEpoch}.mp4',
        ),
      });
      
      // Add thumbnail if provided
      if (thumbnailFile != null) {
        formData.files.add(
          MapEntry(
            'thumbnail',
            await MultipartFile.fromFile(
              thumbnailFile.path,
              filename: 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
      }
      
      // Upload video
      final response = await _dio.post(
        '/upload',  // ✅ Relative path (baseUrl нь video service)
        data: formData,
        onSendProgress: onProgress,
      );
      
      if (response.statusCode == 200 || response.statusCode == 202) {
        print('✅ Видео амжилттай илгээгдлээ');
        
        return {
          'success': true,
          'message': response.data['message'] ?? 'Видео амжилттай илгээгдлээ',
          'videoId': response.data['videoId'],
          'status': response.data['status'] ?? 'processing',
          'estimatedTime': response.data['estimatedTime'],
        };
      } else {
        throw Exception(response.data['error'] ?? 'Видео илгээхэд алдаа гарлаа');
      }
    } on DioException catch (e) {
      print('❌ Video upload error: ${e.message}');
      throw _handleError(e);
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw Exception('Видео илгээхэд алдаа гарлаа: $e');
    }
  }
  
  // ==========================================
  // VIDEO STATUS CHECK
  // ==========================================
  
  /// Check video processing status
  Future<Map<String, dynamic>> getVideoStatus(String videoId) async {
    try {
      final response = await _dio.get('/$videoId/status');
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'videoId': response.data['videoId'],
          'status': response.data['status'],
          'aiStatus': response.data['aiStatus'],
          'confidence': response.data['confidence'],
          'detectedObjects': response.data['detectedObjects'],
          'uploadedAt': response.data['uploadedAt'],
          'processedAt': response.data['processedAt'],
        };
      }
      
      return {'success': false, 'error': 'Статус авахад алдаа гарлаа'};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // ==========================================
  // GET ALL VIDEOS
  // ==========================================
  
  /// Get list of uploaded videos
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
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.cast<Map<String, dynamic>>();
      }
      
      return [];
    } on DioException catch (e) {
      print('❌ Get videos error: ${e.message}');
      return [];
    }
  }
  
  // ==========================================
  // IMAGE UPLOAD (for accidents without video)
  // ==========================================
  
  /// Upload image with accident report
  Future<Map<String, dynamic>> uploadImage({
    required File imageFile,
    required double latitude,
    required double longitude,
    required String description,
    String severity = 'moderate',
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      // Validate file size
      final fileSize = await imageFile.length();
      if (!ApiConfig.isValidImageSize(fileSize)) {
        throw Exception(
          'Зураг хэт том байна. Максимум хэмжээ: ${ApiConfig.maxImageSizeMB}MB\n'
          'Танай файл: ${ApiConfig.formatFileSize(fileSize)}'
        );
      }
      
      // Validate file extension
      if (!ApiConfig.isValidImageExtension(imageFile.path)) {
        throw Exception(
          'Зургийн формат буруу байна. Зөвшөөрөгдсөн форматууд: ${ApiConfig.allowedImageFormats.join(", ")}'
        );
      }
      
      print('📷 Зураг upload эхэллээ: ${ApiConfig.formatFileSize(fileSize)}');
      
      // Get user ID
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('Нэвтрэх шаардлагатай');
      }
      
      // Prepare form data
      FormData formData = FormData.fromMap({
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'severity': severity,
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'accident_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
      
      // ✅ Upload to accidents endpoint (images go directly to accident report)
      // Use full URL since we're posting to accident service, not video service
      final accidentDio = Dio(BaseOptions(baseUrl: ApiConfig.accidentServiceUrl));
      
      // Add auth interceptor
      final token = await _authService.getAccessToken();
      if (token != null) {
        accidentDio.options.headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await accidentDio.post(
        '/accidents',
        data: formData,
        onSendProgress: onProgress,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Зураг амжилттай илгээгдлээ');
        
        return {
          'success': true,
          'message': response.data['message'] ?? 'Зураг амжилттай илгээгдлээ',
          'accidentId': response.data['data']?['id'],
          'accident': response.data['data'],
        };
      } else {
        throw Exception(response.data['error'] ?? 'Зураг илгээхэд алдаа гарлаа');
      }
    } on DioException catch (e) {
      print('❌ Image upload error: ${e.message}');
      throw _handleError(e);
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw Exception('Зураг илгээхэд алдаа гарлаа: $e');
    }
  }
  
  // ==========================================
  // DOWNLOAD VIDEO
  // ==========================================
  
  /// Get download URL for video
  Future<String> getDownloadUrl(String videoId) async {
    try {
      final response = await _dio.get('/$videoId/download');
      
      if (response.statusCode == 200 && response.data['downloadUrl'] != null) {
        return response.data['downloadUrl'];
      }
      
      throw Exception('Download URL авахад алдаа гарлаа');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // ==========================================
  // DELETE VIDEO
  // ==========================================
  
  /// Delete uploaded video
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
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Файл илгээх хугацаа дууслаа. Интернет холболтоо шалгана уу.';
        
      case DioExceptionType.receiveTimeout:
        return 'Серверээс хариу хүлээх хугацаа дууслаа. Дахин оролдоно уу.';
        
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error'] ?? e.response?.data?['message'];
        
        if (statusCode == 401) {
          return 'Нэвтрэх эрх дууссан. Дахин нэвтэрнэ үү.';
        } else if (statusCode == 413) {
          return 'Файл хэт том байна. Багасгаад дахин оролдоно уу.';
        } else if (statusCode == 415) {
          return 'Файлын формат буруу байна.';
        } else if (message != null) {
          return message.toString();
        }
        return 'Серверээс алдаа буцаж ирлээ.';
        
      case DioExceptionType.connectionError:
        return 'Интернет холболт тасарсан. WiFi эсвэл мобайл датаа шалгана уу.';
        
      default:
        return 'Файл илгээхэд алдаа гарлаа. Дахин оролдоно уу.';
    }
  }
  
  // ==========================================
  // HELPERS
  // ==========================================
  
  void dispose() {
    _dio.close();
  }
}