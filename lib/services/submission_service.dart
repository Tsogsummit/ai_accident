import 'package:dio/dio.dart';
import '../models/submission.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class SubmissionService {
  final Dio _dio;
  final AuthService _authService = AuthService();

  SubmissionService() : _dio = Dio() {
    _dio.options.baseUrl = ApiConfig.reportServiceUrl;
    _dio.options.connectTimeout = ApiConfig.connectTimeout;
    _dio.options.receiveTimeout = ApiConfig.receiveTimeout;
    _dio.options.sendTimeout = ApiConfig.sendTimeout;
    _dio.options.headers = ApiConfig.defaultHeaders;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<List<Submission>> getUserSubmissions({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '/reports/submissions',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
        options: Options(headers: headers),
      );

      print('📦 Submissions response: ${response.data}');

      if (response.data is Map && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Submission.fromJson(json)).toList();
      }

      return [];
    } on DioException catch (e) {
      print('❌ Get submissions error: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      throw _handleError(e);
    }
  }
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Холболтын хугацаа дууслаа';
      case DioExceptionType.receiveTimeout:
        return 'Хариу хүлээх хугацаа дууслаа';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'Нэвтрэх эрх дууссан';
        } else if (statusCode == 403) {
          return 'Эрх хүрэхгүй байна';
        }
        return e.response?.data?['error'] ?? 'Серверийн алдаа';
      case DioExceptionType.connectionError:
        return 'Интернет холболт алдаатай';
      default:
        return 'Алдаа гарлаа';
    }
  }

  void dispose() {
    _dio.close();
  }
}
