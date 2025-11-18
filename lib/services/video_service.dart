
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:path/path.dart' as path;
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
        headers: {
          'Content-Type': 'multipart/form-data', 
          'Accept': 'application/json',
        },
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );
    
    
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
          requestBody: false, 
          responseBody: true,
          error: true,
        ),
      );
    }
  }
  
  
  
  
  
  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    required double latitude,
    required double longitude,
    required String description,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      
      if (!await videoFile.exists()) {
        throw Exception('Видео файл олдсонгүй');
      }

      
      final fileSize = await videoFile.length();
      if (!ApiConfig.isValidVideoSize(fileSize)) {
        throw Exception(
          'Видео хэт том байна. Максимум: ${ApiConfig.maxVideoSizeMB}MB\n'
          'Танай файл: ${ApiConfig.formatFileSize(fileSize)}'
        );
      }
      
      
      final fileName = path.basename(videoFile.path);
      if (!ApiConfig.isValidVideoExtension(fileName)) {
        throw Exception(
          'Видеоны формат буруу. Зөвшөөрөгдсөн: ${ApiConfig.allowedVideoFormats.join(", ")}'
        );
      }
      
      print('📹 Video upload эхэллээ');
      print('   File: $fileName');
      print('   Size: ${ApiConfig.formatFileSize(fileSize)}');
      print('   Location: $latitude, $longitude');
      
      
      final userId = await _authService.getUserId();
      if (userId == null) {
        throw Exception('Нэвтрэх шаардлагатай');
      }
      
      print('👤 User ID: $userId');
      
      
      
      final multipartFile = await MultipartFile.fromFile(
        videoFile.path,
        filename: fileName,
      );
      
      
      final formData = FormData.fromMap({
        'userId': userId.toString(),
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'description': description,
        'video': multipartFile, 
      });
      
      print('📤 Uploading to: ${ApiConfig.videoServiceUrl}/upload');
      
      
      final response = await _dio.post(
        '/upload',
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          print('📊 Upload: ${(progress * 100).toStringAsFixed(1)}%');
          if (onProgress != null) {
            onProgress(sent, total);
          }
        },
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response: ${response.data}');
      
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        if (data is Map && data['success'] == true) {
          print('✅ Видео амжилттай илгээгдлээ');
          print('   VideoId: ${data['videoId']}');
          print('   AccidentId: ${data['accidentId']}');
          
          return {
            'success': true,
            'message': data['message'] ?? 'Видео амжилттай илгээгдлээ',
            'videoId': data['videoId'],
            'accidentId': data['accidentId'],
            'status': data['status'] ?? 'uploaded',
            'accident': data['accident'],
          };
        } else {
          final errorMsg = data is Map 
              ? (data['error'] ?? 'Тодорхойгүй алдаа') 
              : 'Хариу буруу байна';
          throw Exception(errorMsg);
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode}\n'
          '${response.data}'
        );
      }
      
    } on DioException catch (e) {
      print('❌ DioException type: ${e.type}');
      print('❌ Message: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      print('❌ Error: ${e.error}');
      
      throw Exception(_handleError(e));
      
    } catch (e, stackTrace) {
      print('❌ Unexpected error: $e');
      print('❌ Stack trace: $stackTrace');
      
      throw Exception('Видео илгээхэд алдаа: $e');
    }
  }
  
  
  
  
  
  Future<Map<String, dynamic>> getVideoStatus(String videoId) async {
    try {
      final response = await _dio.get('/videos/$videoId/status');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['success'] == true) {
          return {
            'success': true,
            'videoId': data['videoId'],
            'accidentId': data['accidentId'],
            'status': data['status'],
            'accident': data['accident'],
          };
        }
      }
      
      return {
        'success': false, 
        'error': 'Статус авахад алдаа гарлаа'
      };
      
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }
  
  
  
  
  
  Future<List<Map<String, dynamic>>> getVideos({
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (status != null) queryParams['status'] = status;
      
      final response = await _dio.get(
        '/videos',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is Map && data['success'] == true) {
          final list = data['data'] as List?;
          if (list != null) {
            return list.cast<Map<String, dynamic>>();
          }
        }
      }
      
      return [];
      
    } on DioException catch (e) {
      print('❌ Get videos error: ${e.message}');
      return [];
    }
  }
  
  
  
  
  
  Future<bool> deleteVideo(String videoId) async {
    try {
      final userId = await _authService.getUserId();
      
      final response = await _dio.delete(
        '/videos/$videoId',
        data: {'userId': userId},
      );
      
      return response.statusCode == 200 && 
             response.data is Map && 
             response.data['success'] == true;
             
    } on DioException catch (e) {
      print('❌ Delete video error: ${e.message}');
      return false;
    }
  }
  
  
  
  
  
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Холболтын хугацаа дууслаа. Интернет холболтоо шалгана уу.';
        
      case DioExceptionType.receiveTimeout:
        return 'Хариу хүлээх хугацаа дууслаа. Дахин оролдоно уу.';
        
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        
        String message = 'Серверийн алдаа';
        
        if (data is Map) {
          message = data['error']?.toString() ?? 
                   data['message']?.toString() ?? 
                   'Тодорхойгүй алдаа';
        } else if (data is String) {
          message = data;
        }
        
        switch (statusCode) {
          case 400:
            return 'Буруу хүсэлт: $message';
          case 401:
            return 'Нэвтрэх эрх дууссан. Дахин нэвтэрнэ үү.';
          case 403:
            return 'Хандах эрх байхгүй.';
          case 404:
            return 'Олдсонгүй: $message';
          case 413:
            return 'Файл хэт том байна.';
          case 415:
            return 'Файлын формат буруу байна.';
          case 500:
            return 'Серверийн алдаа: $message';
          case 503:
            return 'Үйлчилгээ түр зогссон байна.';
          default:
            return '$message (Код: $statusCode)';
        }
        
      case DioExceptionType.connectionError:
        return 'Интернет холболт алдаатай. WiFi эсвэл мобайл датаа шалгана уу.';
        
      case DioExceptionType.cancel:
        return 'Upload цуцлагдсан';
        
      case DioExceptionType.badCertificate:
        return 'Аюулгүй холболтын алдаа';
        
      case DioExceptionType.unknown:
      default:
        final errorMsg = e.error?.toString() ?? e.message ?? 'Тодорхойгүй алдаа';
        return 'Алдаа гарлаа: $errorMsg';
    }
  }
  
  void dispose() {
    _dio.close();
  }
}