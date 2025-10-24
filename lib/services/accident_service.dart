// lib/services/accident_service.dart - FIXED VERSION
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/accident.dart';

class AccidentService {
  // ⚠️ ЧУХАЛ: Энэ URL-ийг өөрийн backend URL-ээр солино уу
  static const String baseUrl = 'http://localhost:3000/api';
  // Production дээр:
  // static const String baseUrl = 'https://your-domain.com/api';

  late final Dio _dio;

  AccidentService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 15),
      receiveTimeout: Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptor for logging (development only)
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  // Set JWT token for authentication
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Get all accidents with optional filters
  Future<List<Accident>> getAllAccidents({
    AccidentSource? source,
    AccidentSeverity? severity,
    AccidentStatus? status,
    double? latitude,
    double? longitude,
    double? radius, // in meters
    int? limit,
    int? offset,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};

      if (source != null) {
        queryParams['source'] = source == AccidentSource.user ? 'user' : 'camera';
      }
      if (severity != null) {
        queryParams['severity'] = _severityToString(severity);
      }
      if (status != null) {
        queryParams['status'] = _statusToString(status);
      }
      if (latitude != null) queryParams['latitude'] = latitude;
      if (longitude != null) queryParams['longitude'] = longitude;
      if (radius != null) queryParams['radius'] = radius;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;

      final response = await _dio.get(
        '/accidents',
        queryParameters: queryParams,
      );

      if (response.data is Map && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Accident.fromJson(json)).toList();
      } else if (response.data is List) {
        return (response.data as List).map((json) => Accident.fromJson(json)).toList();
      }

      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get nearby accidents
  Future<List<Accident>> getNearbyAccidents(
      double latitude,
      double longitude, {
        double radiusKm = 5.0,
      }) async {
    try {
      final response = await _dio.get(
        '/accidents/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radiusKm * 1000, // Convert to meters
        },
      );

      if (response.data is Map && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Accident.fromJson(json)).toList();
      }

      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get accident by ID
  Future<Accident?> getAccidentById(String accidentId) async {
    try {
      final response = await _dio.get('/accidents/$accidentId');

      if (response.data is Map && response.data['success'] == true) {
        return Accident.fromJson(response.data['data']);
      } else if (response.data is Map) {
        return Accident.fromJson(response.data);
      }

      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Report new accident
  Future<Accident> reportAccident({
    required double latitude,
    required double longitude,
    required String description,
    AccidentSeverity? severity,
    File? imageFile,
    File? videoFile,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        if (severity != null) 'severity': _severityToString(severity),
      });

      // Add image if provided
      if (imageFile != null) {
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(
              imageFile.path,
              filename: 'accident_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
      }

      // Add video if provided
      if (videoFile != null) {
        formData.files.add(
          MapEntry(
            'video',
            await MultipartFile.fromFile(
              videoFile.path,
              filename: 'accident_${DateTime.now().millisecondsSinceEpoch}.mp4',
            ),
          ),
        );
      }

      final response = await _dio.post('/accidents', data: formData);

      if (response.data is Map && response.data['success'] == true) {
        return Accident.fromJson(response.data['data']);
      } else if (response.data is Map) {
        return Accident.fromJson(response.data);
      }

      throw Exception('Осол мэдээлэхэд алдаа гарлаа');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Update accident
  Future<Accident> updateAccident(
      String accidentId, {
        String? description,
        AccidentSeverity? severity,
        AccidentStatus? status,
      }) async {
    try {
      Map<String, dynamic> data = {};

      if (description != null) data['description'] = description;
      if (severity != null) data['severity'] = _severityToString(severity);
      if (status != null) data['status'] = _statusToString(status);

      final response = await _dio.put('/accidents/$accidentId', data: data);

      if (response.data is Map && response.data['success'] == true) {
        return Accident.fromJson(response.data['data']);
      } else if (response.data is Map) {
        return Accident.fromJson(response.data);
      }

      throw Exception('Ослын мэдээлэл шинэчлэхэд алдаа гарлаа');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Delete accident
  Future<bool> deleteAccident(String accidentId) async {
    try {
      final response = await _dio.delete('/accidents/$accidentId');
      return response.data?['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Verify accident (increase verification count)
  Future<bool> verifyAccident(String accidentId) async {
    try {
      final response = await _dio.post('/accidents/$accidentId/verify');
      return response.data?['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Report false accident
  Future<bool> reportFalseAccident(
      String accidentId, {
        required String reason,
        String? comment,
      }) async {
    try {
      final response = await _dio.post(
        '/accidents/$accidentId/false-report',
        data: {
          'reason': reason,
          'comment': comment,
        },
      );
      return response.data?['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get accident statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _dio.get('/accidents/statistics');

      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }

      return {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // AI Image Analysis
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await _dio.post('/ai/analyze', data: formData);

      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Helper methods
  String _severityToString(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe:
        return 'severe';
      case AccidentSeverity.moderate:
        return 'moderate';
      case AccidentSeverity.minor:
        return 'minor';
    }
  }

  String _statusToString(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported:
        return 'reported';
      case AccidentStatus.confirmed:
        return 'confirmed';
      case AccidentStatus.resolved:
        return 'resolved';
      case AccidentStatus.falseAlarm:
        return 'false_alarm';
    }
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Холболт хэтэрсэн. Дахин оролдоно уу.';
      case DioExceptionType.sendTimeout:
        return 'Илгээх хугацаа дууслаа. Дахин оролдоно уу.';
      case DioExceptionType.receiveTimeout:
        return 'Хүлээх хугацаа дууслаа. Дахин оролдоно уу.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error'] ?? e.response?.data?['message'];

        if (statusCode == 401) {
          return 'Нэвтрэх шаардлагатай. Дахин нэвтэрнэ үү.';
        } else if (statusCode == 403) {
          return 'Энэ үйлдэл хийх эрхгүй байна.';
        } else if (statusCode == 404) {
          return 'Мэдээлэл олдсонгүй.';
        } else if (message != null) {
          return message.toString();
        }
        return 'Сервер алдаа гарлаа. (${statusCode ?? 'Unknown'})';
      case DioExceptionType.cancel:
        return 'Хүсэлт цуцлагдлаа.';
      case DioExceptionType.connectionError:
        return 'Интернет холболт алдаатай байна.';
      case DioExceptionType.badCertificate:
        return 'Аюулгүй байдлын гэрчилгээ буруу байна.';
      case DioExceptionType.unknown:
      default:
        return 'Тодорхойгүй алдаа гарлаа: ${e.message}';
    }
  }
}