import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class FalseReportService {
  final Dio _dio;
  final AuthService _authService = AuthService();

  FalseReportService() : _dio = Dio() {
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

  Future<List<Map<String, dynamic>>> getReportReasons() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.reportReasonsEndpoint,
        options: Options(headers: headers),
      );

      if (response.data is Map && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
      }

      return [];
    } on DioException catch (e) {
      print('Get report reasons error: ${e.message}');
      return [];
    }
  }

  Future<Map<String, dynamic>> reportFalseAlarm({
    required int accidentId,
    required int userId,
    required int reasonId,
    String? comment,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        ApiConfig.falseReportsEndpoint,
        data: {
          'accidentId': accidentId,
          'userId': userId,
          'reasonId': reasonId,
          'comment': comment,
        },
        options: Options(headers: headers),
      );

      if (response.data is Map && response.data['success'] == true) {
        final falseReportCount = response.data['falseReportCount'] ?? 0;
        print(' False report submitted. Total reports: $falseReportCount');
        return {
          'success': true,
          'falseReportCount': falseReportCount,
          'alreadyReported': false,
        };
      }

      if (response.data is Map && response.data['alreadyReported'] == true) {
        print(' User has already reported this accident');
        return {
          'success': false,
          'alreadyReported': true,
          'message': response.data['message'] ?? 'Already reported',
        };
      }

      return {
        'success': false,
        'alreadyReported': false,
        'message': response.data?['message'] ?? 'Unknown error',
      };
    } on DioException catch (e) {
      print('Report false alarm error: ${e.message}');
      if (e.response != null) {
        print('Response: ${e.response?.data}');

        if (e.response?.data is Map &&
            e.response?.data['alreadyReported'] == true) {
          return {
            'success': false,
            'alreadyReported': true,
            'message': e.response?.data['message'] ?? 'Already reported',
          };
        }
      }
      return {
        'success': false,
        'alreadyReported': false,
        'message': e.message ?? 'Network error',
      };
    }
  }
}
