import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static String get baseUrl => ApiConfig.authServiceUrl;

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    print('✅ Токен хадгалагдлаа');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
    print('✅ Хэрэглэгчийн мэдээлэл хадгалагдлаа: ${user['name']}');
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  Future<int?> getUserId() async {
    final user = await getUser();
    return user?['id'] as int?;
  }

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
        final responseData = data['data'];
        await saveTokens(responseData['accessToken'], responseData['refreshToken']);
        await saveUser(responseData['user']);
        print('✅ Амжилттай нэвтэрлээ: ${responseData['user']['name']}');
        return {'success': true, 'user': responseData['user']};
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
        final responseData = data['data'];
        await saveTokens(responseData['accessToken'], responseData['refreshToken']);
        await saveUser(responseData['user']);
        print('✅ Амжилттай бүртгэгдлээ');
        return {'success': true, 'user': responseData['user']};
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
      }
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    print('✅ Локал мэдээлэл устгагдлаа');
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final user = await getUser();
    final isLoggedIn = token != null && user != null;
    print('🔍 Нэвтэрсэн эсэх: $isLoggedIn');
    return isLoggedIn;
  }
  Future<bool> refreshAccessToken() async {
    print('🔄 Токен шинэчилж байна...');
    
    try {
      final refreshToken = await getRefreshToken();

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
        final responseData = data['data'];
        await saveTokens(responseData['accessToken'], responseData['refreshToken']);
        print('✅ Токен шинэчлэгдлээ');
        return true;
      } else {
        print('❌ Токен шинэчлэх алдаа: ${data['error']}');
        await logout();
        return false;
      }
    } catch (e) {
      print('❌ Токен шинэчлэх алдаа: $e');
      return false;
    }
  }

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

      print('📥 Profile response: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('⚠️ Токен хүчингүй, шинэчилж байна...');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          return await getProfile();
        }
        return null;
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final userData = data['data']['user'];
        await saveUser(userData);
        print('✅ Профайл авагдлаа: ${userData['name']}');
        return userData;
      } else {
        print('❌ Профайл авах алдаа: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('❌ Профайл авах алдаа: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    required String currentPassword,
  }) async {
    print('✏️ Профайл шинэчилж байна...');

    try {
      final token = await getAccessToken();
      if (token == null) {
        print('❌ Токен олдсонгүй');
        return {
          'success': false,
          'error': 'Нэвтрэх шаардлагатай'
        };
      }

      final response = await http.put(
        Uri.parse('${baseUrl}/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'currentPassword': currentPassword,
        }),
      ).timeout(Duration(seconds: 10));

      print('📥 Update profile response: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('⚠️ Токен хүчингүй, шинэчилж байна...');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          return await updateProfile(
            name: name,
            email: email,
            phone: phone,
            currentPassword: currentPassword,
          );
        }
        return {
          'success': false,
          'error': 'Токен хүчингүй. Дахин нэвтэрнэ үү.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final userData = data['data']['user'];
        await saveUser(userData);
        print('✅ Профайл шинэчлэгдлээ: ${userData['name']}');
        return {
          'success': true,
          'message': data['message'],
          'user': userData
        };
      } else {
        print('❌ Профайл шинэчлэх алдаа: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Профайл шинэчлэхэд алдаа гарлаа'
        };
      }
    } catch (e) {
      print('❌ Профайл шинэчлэх алдаа: $e');
      return {
        'success': false,
        'error': 'Сервертэй холбогдож чадсангүй. IP хаягаа шалгана уу.\n\nАлдаа: $e'
      };
    }
  }

}