import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:3001'; // Өөрийн IP хаягаа оруулна уу

  // Токен хадгалах
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Токен авах
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Хэрэглэгчийн мэдээлэл хадгалах
  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  // Хэрэглэгчийн мэдээлэл авах
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // Нэвтрэх
  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await saveTokens(data['accessToken'], data['refreshToken']);
        await saveUser(data['user']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Нэвтрэхэд алдаа гарлаа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Сервертэй холбогдож чадсангүй'};
    }
  }

  // Бүртгүүлэх
  Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    required String password,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'name': name,
          'password': password,
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        await saveTokens(data['accessToken'], data['refreshToken']);
        await saveUser(data['user']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Бүртгэлд алдаа гарлаа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Сервертэй холбогдож чадсангүй'};
    }
  }

  // Гарах
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await getUser();

    if (user != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': user['id']}),
        );
      } catch (e) {
        // Ignore error
      }
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
  }

  // Нэвтэрсэн эсэхийг шалгах
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }
}
