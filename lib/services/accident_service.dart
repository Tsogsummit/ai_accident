import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/accident.dart';

class AccidentService {
  static const String baseUrl = 'https://your-api-endpoint.com/api';
  late final Dio _dio;

  AccidentService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ));
  }

  Future<List<Accident>> getAllAccidents() async {
    try {
      final response = await _dio.get('/accidents');
      final List<dynamic> data = response.data;
      return data.map((json) => Accident.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ослын мэдээлэл татахад алдаа гарлаа: $e');
    }
  }

  Future<Accident> reportAccident(Accident accident) async {
    try {
      final response = await _dio.post('/accidents', data: accident.toJson());
      return Accident.fromJson(response.data);
    } catch (e) {
      throw Exception('Осол мэдээлэхэд алдаа гарлаа: $e');
    }
  }

  Future<void> updateAccidentStatus(String accidentId, AccidentStatus status) async {
    try {
      await _dio.put('/accidents/$accidentId/status', data: {'status': status.index});
    } catch (e) {
      throw Exception('Ослын төлөв шинэчлэхэд алдаа гарлаа: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imageFile.path),
      });
      
      final response = await _dio.post('/ai/analyze', data: formData);
      return response.data;
    } catch (e) {
      throw Exception('Зураг шинжлэхэд алдаа гарлаа: $e');
    }
  }
}
