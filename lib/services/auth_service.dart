import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  // ✅ Use ApiConfig for URLs
  static String get baseUrl => ApiConfig.authServiceUrl;

  // Токен хадгалах
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    print('✅ Токен хадгалагдлаа');
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
    print('✅ Хэрэглэгчийн мэдээлэл хадгалагдлаа');
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

  // ✅ Хэрэглэгчийн ID авах
  Future<int?> getUserId() async {
    final user = await getUser();
    return user?['id'] as int?;
  }

  // ✅ НЭВТРЭХ - ApiConfig ашиглах
  Future<Map<String, dynamic>> login(String phone, String password) async {
    print('🔐 Нэвтэрч байна...');
    print('📡 URL: ${ApiConfig.loginEndpoint}');
    
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Хугацаа дууссан - Серверт холбогдож чадсангүй');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await saveTokens(data['accessToken'], data['refreshToken']);
        await saveUser(data['user']);
        print('✅ Амжилттай нэвтэрлээ');
        return {'success': true, 'user': data['user']};
      } else {
        print('❌ Нэвтрэлт амжилтгүй: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Нэвтрэхэд алдаа гарлаа'};
      }
    } catch (e) {
      print('❌ Алдаа гарлаа: $e');
      return {
        'success': false,
        'error': 'Сервертэй холбогдож чадсангүй. IP хаягаа шалгана уу.\n\nURL: ${ApiConfig.loginEndpoint}\n\nАлдаа: $e'
      };
    }
  }

  // ✅ БҮРТГҮҮЛЭХ - ApiConfig ашиглах
  Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    required String password,
    String? email,
  }) async {
    print('📝 Бүртгүүлж байна...');
    print('📡 URL: ${ApiConfig.registerEndpoint}');
    
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'name': name,
          'password': password,
          'email': email,
        }),
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Хугацаа дууссан - Серверт холбогдож чадсангүй');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        await saveTokens(data['accessToken'], data['refreshToken']);
        await saveUser(data['user']);
        print('✅ Амжилттай бүртгэгдлээ');
        return {'success': true, 'user': data['user']};
      } else {
        print('❌ Бүртгэл амжилтгүй: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Бүртгэлд алдаа гарлаа'};
      }
    } catch (e) {
      print('❌ Алдаа гарлаа: $e');
      return {
        'success': false,
        'error': 'Сервертэй холбогдож чадсангүй. IP хаягаа шалгана уу.\n\nURL: ${ApiConfig.registerEndpoint}\n\nАлдаа: $e'
      };
    }
  }

  // ✅ ГАРАХ - ApiConfig ашиглах
  Future<void> logout() async {
    print('🚪 Гарч байна...');
    
    final prefs = await SharedPreferences.getInstance();
    final user = await getUser();

    if (user != null) {
      try {
        await http.post(
          Uri.parse(ApiConfig.logoutEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': user['id']}),
        ).timeout(Duration(seconds: 5));
        print('✅ Серверээс гарлаа');
      } catch (e) {
        print('⚠️ Серверээс гарах алдаа: $e');
        // Ignore error - logout locally anyway
      }
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    print('✅ Локал токен устгагдлаа');
  }

  // Нэвтэрсэн эсэхийг шалгах
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final isLoggedIn = token != null;
    print('🔍 Нэвтэрсэн эсэх: $isLoggedIn');
    return isLoggedIn;
  }

  // ✅ ТОКЕН ШИНЭЧЛЭХ
  Future<bool> refreshAccessToken() async {
    print('🔄 Токен шинэчилж байна...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        print('❌ Refresh token олдсонгүй');
        return false;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.refreshTokenEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await saveTokens(data['accessToken'], data['refreshToken']);
        print('✅ Токен шинэчлэгдлээ');
        return true;
      } else {
        print('❌ Токен шинэчлэх алдаа: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('❌ Токен шинэчлэх алдаа: $e');
      return false;
    }
  }

  // Backward compatibility
  @Deprecated('Use refreshAccessToken instead')
  Future<bool> refreshToken() => refreshAccessToken();

  // ✅ ПРОФАЙЛ АВАХ
  Future<Map<String, dynamic>?> getProfile() async {
    print('👤 Профайл авч байна...');
    
    try {
      final token = await getAccessToken();
      if (token == null) {
        print('❌ Токен олдсонгүй');
        return null;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await saveUser(data['user']);
        print('✅ Профайл авагдлаа');
        return data['user'];
      } else {
        print('❌ Профайл авах алдаа: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('❌ Профайл авах алдаа: $e');
      return null;
    }
  }
}