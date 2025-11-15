// lib/services/accident_service.dart - IMPROVED VERSION
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import '../models/accident.dart';
import '../config/api_config.dart';

class AccidentService {
  late final Dio _dio;
  String? _authToken;

  // Cache for accidents
  List<Accident>? _cachedAccidents;
  DateTime? _cacheTimestamp;

  AccidentService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      headers: ApiConfig.defaultHeaders,
    ));

    // ✅ Add retry interceptor
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        retries: ApiConfig.maxRetryAttempts,
        retryDelays: [
          ApiConfig.retryDelay,
          ApiConfig.retryDelay * 2,
          ApiConfig.retryDelay * 3,
        ],
        retryableExtraStatuses: {408, 429, 500, 502, 503, 504},
      ),
    );

    // ✅ Add logging interceptor (development only)
    if (ApiConfig.enableLogging && ApiConfig.isDevelopment) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestBody: true,
          responseBody: true,
          error: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }

    // ✅ Add auth token interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors (unauthorized)
          if (error.response?.statusCode == 401) {
            // Token expired or invalid - clear it
            _authToken = null;
            // You can add auto-refresh logic here
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Set JWT token for authentication
  void setAuthToken(String token) {
    _authToken = token;
  }

  // Clear auth token
  void clearAuthToken() {
    _authToken = null;
  }

  // Check if cache is valid
  bool _isCacheValid() {
    if (!ApiConfig.enableCaching) return false;
    if (_cachedAccidents == null || _cacheTimestamp == null) return false;

    final now = DateTime.now();
    final cacheAge = now.difference(_cacheTimestamp!);
    return cacheAge < ApiConfig.cacheValidDuration;
  }

  // Clear cache
  void clearCache() {
    _cachedAccidents = null;
    _cacheTimestamp = null;
  }

  // ✅ Get all accidents with caching
  Future<List<Accident>> getAllAccidents({
    AccidentSource? source,
    AccidentSeverity? severity,
    AccidentStatus? status,
    double? latitude,
    double? longitude,
    double? radius,
    int? limit,
    int? offset,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid
    if (!forceRefresh && _isCacheValid()) {
      return _cachedAccidents!;
    }

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
        ApiConfig.accidentsEndpoint,
        queryParameters: queryParams,
      );

      List<Accident> accidents = [];

      if (response.data is Map && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        accidents = data.map((json) => Accident.fromJson(json)).toList();
      } else if (response.data is List) {
        accidents = (response.data as List)
            .map((json) => Accident.fromJson(json))
            .toList();
      }

      // Update cache
      _cachedAccidents = accidents;
      _cacheTimestamp = DateTime.now();

      return accidents;
    } on DioException catch (e) {
      // If there's cached data and network error, return cached data
      if (_cachedAccidents != null && _isNetworkError(e)) {
        print('⚠️ Сүлжээний алдаа - кэш өгөгдөл ашиглаж байна');
        return _cachedAccidents!;
      }
      throw _handleError(e);
    } catch (e) {
      throw 'Тодорхойгүй алдаа гарлаа: $e';
    }
  }

  // ✅ Get nearby accidents
  Future<List<Accident>> getNearbyAccidents(
      double latitude,
      double longitude, {
        double radiusKm = 5.0,
      }) async {
    try {
      final response = await _dio.get(
        ApiConfig.nearbyAccidentsEndpoint,
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

  // ✅ Get accident by ID
  Future<Accident?> getAccidentById(String accidentId) async {
    try {
      final response = await _dio.get('${ApiConfig.accidentsEndpoint}/$accidentId');

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

  // ✅ Report new accident with progress callback
  Future<Accident> reportAccident({
    required double latitude,
    required double longitude,
    required String description,
    AccidentSeverity? severity,
    File? imageFile,
    File? videoFile,
    Function(int sent, int total)? onProgress,
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

      final response = await _dio.post(
        ApiConfig.accidentsEndpoint,
        data: formData,
        onSendProgress: onProgress,
      );

      // Clear cache after successful report
      clearCache();

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

  // ✅ Update accident
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

      final response = await _dio.put(
        '${ApiConfig.accidentsEndpoint}/$accidentId',
        data: data,
      );

      // Clear cache after update
      clearCache();

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

  // ✅ Delete accident
  Future<bool> deleteAccident(String accidentId) async {
    try {
      final response = await _dio.delete('${ApiConfig.accidentsEndpoint}/$accidentId');

      // Clear cache after delete
      clearCache();

      return response.data?['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ Verify accident
  Future<bool> verifyAccident(String accidentId) async {
    try {
      final response = await _dio.post('${ApiConfig.accidentsEndpoint}/$accidentId/verify');

      // Clear cache after verification
      clearCache();

      return response.data?['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ Report false accident
  Future<bool> reportFalseAccident(
      String accidentId, {
        required String reason,
        String? comment,
      }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.accidentsEndpoint}/$accidentId/false-report',
        data: {
          'reason': reason,
          'comment': comment,
        },
      );

      // Clear cache after reporting false
      clearCache();

      return response.data?['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ Get accident statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _dio.get('${ApiConfig.accidentsEndpoint}/statistics');

      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }

      return {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ AI Image Analysis
  Future<Map<String, dynamic>> analyzeImage(
      File imageFile, {
        Function(int sent, int total)? onProgress,
      }) async {
    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await _dio.post(
        '${ApiConfig.aiAnalyzeEndpoint}',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Helper: Check if error is network-related
  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  // Helper: Convert severity to string
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

  // Helper: Convert status to string
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

  // ✅ Enhanced error handler with better Mongolian messages
  String _handleError(DioException e) {
    print('❌ API Алдаа: ${e.type} - ${e.message}');

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Холболтын хугацаа дууслаа. Интернет холболтоо шалгаад дахин оролдоно уу.';

      case DioExceptionType.sendTimeout:
        return 'Өгөгдөл илгээх хугацаа дууслаа. Интернет холболтоо шалгаад дахин оролдоно уу.';

      case DioExceptionType.receiveTimeout:
        return 'Хариу хүлээх хугацаа дууслаа. Интернет холболтоо шалгаад дахин оролдоно уу.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error'] ??
            e.response?.data?['message'];

        if (statusCode == 401) {
          return 'Нэвтрэх эрх дууссан. Дахин нэвтэрнэ үү.';
        } else if (statusCode == 403) {
          return 'Энэ үйлдэл хийх эрх танд байхгүй байна.';
        } else if (statusCode == 404) {
          return 'Хүссэн мэдээлэл олдсонгүй.';
        } else if (statusCode == 429) {
          return 'Хэт олон хүсэлт илгээлээ. Түр хүлээгээд дахин оролдоно уу.';
        } else if (statusCode == 500) {
          return 'Серверийн алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу.';
        } else if (statusCode == 503) {
          return 'Үйлчилгээ түр зогссон байна. Түр хүлээгээд дахин оролдоно уу.';
        } else if (message != null) {
          return message.toString();
        }
        return 'Серверээс алдаа буцаж ирлээ. (Код: ${statusCode ?? "??"})';

      case DioExceptionType.cancel:
        return 'Хүсэлт цуцлагдлаа.';

      case DioExceptionType.connectionError:
        return 'Интернет холболт тасарсан байна. Холболтоо шалгаад дахин оролдоно уу.';

      case DioExceptionType.badCertificate:
        return 'Аюулгүй байдлын гэрчилгээ буруу байна. Апп шинэчлэлт хэрэгтэй байж магадгүй.';

      case DioExceptionType.unknown:
      default:
        if (e.error is SocketException) {
          return 'Интернет холболт алдаатай байна. WiFi эсвэл мобайл датаа шалгана уу.';
        }
        return 'Тодорхойгүй алдаа гарлаа. Дахин оролдоно уу.';
    }
  }

  // Dispose method
  void dispose() {
    _dio.close();
  }
}
