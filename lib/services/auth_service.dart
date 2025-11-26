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
    print('Token saved successfully');
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
    print('User information saved: ${user['name']}');
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
    print('Attempting login...');
    print('URL: ${ApiConfig.loginEndpoint}');

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
          throw Exception('Request timeout - Could not connect to server');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final responseData = data['data'];
        await saveTokens(responseData['accessToken'], responseData['refreshToken']);
        await saveUser(responseData['user']);
        print('Login successful: ${responseData['user']['name']}');
        return {'success': true, 'user': responseData['user']};
      } else {
        print('Login failed: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Login failed. Please try again.'};
      }
    } catch (e) {
      print('Error occurred: $e');
      return {
        'success': false,
        'error': 'Unable to connect to the server. Please check your internet connection and try again.'
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    required String password,
    String? email,
  }) async {
    print('Registering account...');
    print('URL: ${ApiConfig.registerEndpoint}');

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
          throw Exception('Request timeout - Could not connect to server');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        final responseData = data['data'];
        await saveTokens(responseData['accessToken'], responseData['refreshToken']);
        await saveUser(responseData['user']);
        print('Registration successful');
        return {'success': true, 'user': responseData['user']};
      } else {
        print('Registration failed: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Registration failed. Please try again.'};
      }
    } catch (e) {
      print('Error occurred: $e');
      return {
        'success': false,
        'error': 'Unable to connect to the server. Please check your internet connection and try again.'
      };
    }
  }

  Future<void> logout() async {
    print('Logging out...');

    final prefs = await SharedPreferences.getInstance();
    final user = await getUser();

    if (user != null) {
      try {
        await http.post(
          Uri.parse(ApiConfig.logoutEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': user['id']}),
        ).timeout(Duration(seconds: 5));
        print('Logged out from server');
      } catch (e) {
        print('Warning: Server logout failed: $e');
      }
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    print('Local data cleared');
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final user = await getUser();
    final isLoggedIn = token != null && user != null;
    print('Checking login status: $isLoggedIn');
    return isLoggedIn;
  }
  Future<bool> refreshAccessToken() async {
    print('Refreshing access token...');

    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken == null) {
        print('Refresh token not found');
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
        print('Token refreshed successfully');
        return true;
      } else {
        print('Token refresh failed: ${data['error']}');
        await logout();
        return false;
      }
    } catch (e) {
      print('Token refresh error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    print('Fetching user profile...');

    try {
      final token = await getAccessToken();
      if (token == null) {
        print('Access token not found');
        return null;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));

      print('Profile response: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('Token expired, refreshing...');
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
        print('Profile loaded: ${userData['name']}');
        return userData;
      } else {
        print('Profile fetch failed: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Profile fetch error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    required String currentPassword,
  }) async {
    print('Updating profile...');

    try {
      final token = await getAccessToken();
      if (token == null) {
        print('Access token not found');
        return {
          'success': false,
          'error': 'Please login to continue'
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

      print('Update profile response: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('Token expired, refreshing...');
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
          'error': 'Your session has expired. Please login again.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final userData = data['data']['user'];
        await saveUser(userData);
        print('Profile updated: ${userData['name']}');
        return {
          'success': true,
          'message': data['message'],
          'user': userData
        };
      } else {
        print('Profile update failed: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update profile. Please try again.'
        };
      }
    } catch (e) {
      print('Profile update error: $e');
      return {
        'success': false,
        'error': 'Unable to connect to the server. Please check your internet connection and try again.'
      };
    }
  }

}