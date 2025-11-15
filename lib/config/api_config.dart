// lib/config/api_config.dart - VIDEO SERVICE НЭМСЭН
import 'package:flutter/foundation.dart';

class ApiConfig {
  // ============================================
  // ҮНДСЭН ТОХИРГОО
  // ============================================
  
  static const bool useGateway = false;
  
  // ⚠️ Өөрийн компьютерийн IP хаяг
  static const String localIP = 'localhost'; // ЭНИЙГ ӨӨРЧИЛ!
  
  // Android Emulator: '10.0.2.2'
  // iOS Simulator: 'localhost'
  // Physical device: '192.168.x.x' (WiFi IP)
  
  // ============================================
  // SERVICE PORTS
  // ============================================
  static const int authPort = 3001;
  static const int accidentPort = 3002;
  static const int videoPort = 3003;        // ✅ VIDEO PORT
  static const int aiPort = 3004;
  static const int notificationPort = 3005;
  
  // ============================================
  // SERVICE BASE URLS
  // ============================================
  static String get authServiceUrl => 'http://$localIP:$authPort';
  static String get accidentServiceUrl => 'http://$localIP:$accidentPort';
  static String get videoServiceUrl => 'http://$localIP:$videoPort';  // ✅ VIDEO URL
  static String get aiServiceUrl => 'http://$localIP:$aiPort';
  static String get notificationServiceUrl => 'http://$localIP:$notificationPort';
  
  // Gateway URL (одоогоор ашиглахгүй)
  static String get gatewayUrl => 'http://$localIP:3000/api';
  
  // Default base URL
  static String get baseUrl => useGateway ? gatewayUrl : accidentServiceUrl;
  
  // ============================================
  // ENDPOINTS - Auth Service
  // ============================================
  static String get loginEndpoint => '$authServiceUrl/auth/login';
  static String get registerEndpoint => '$authServiceUrl/auth/register';
  static String get logoutEndpoint => '$authServiceUrl/auth/logout';
  static String get refreshTokenEndpoint => '$authServiceUrl/auth/refresh';
  static String get userProfileEndpoint => '$authServiceUrl/auth/profile';
  
  // ============================================
  // ENDPOINTS - Accident Service
  // ============================================
  static String get accidentsEndpoint => '$accidentServiceUrl/accidents';
  static String get nearbyAccidentsEndpoint => '$accidentServiceUrl/accidents/nearby';
  static String get userAccidentsEndpoint => '$accidentServiceUrl/accidents/user';
  static String get accidentStatisticsEndpoint => '$accidentServiceUrl/accidents/statistics';
  
  // ============================================
  // ENDPOINTS - Video Service ✅ ШИНЭ
  // ============================================
  static String get videoUploadEndpoint => '$videoServiceUrl/upload';
  static String get videoListEndpoint => '$videoServiceUrl/videos';
  static String get videoStatusEndpoint => '$videoServiceUrl/videos'; // /videos/:id/status
  
  // ============================================
  // ENDPOINTS - AI Service
  // ============================================
  static String get aiAnalyzeEndpoint => '$aiServiceUrl/ai/analyze';
  static String get aiDetectEndpoint => '$aiServiceUrl/ai/detect';
  static String get aiModelsEndpoint => '$aiServiceUrl/ai/models';
  
  // ============================================
  // ENDPOINTS - Notification Service
  // ============================================
  static String get notificationsEndpoint => '$notificationServiceUrl/notifications';
  static String get markReadEndpoint => '$notificationServiceUrl/notifications/read';
  
  // ============================================
  // TIMEOUT SETTINGS
  // ============================================
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Video upload timeout (дольше)
  static const Duration videoUploadTimeout = Duration(minutes: 5);
  
  // ============================================
  // RETRY SETTINGS
  // ============================================
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // ============================================
  // CACHE SETTINGS
  // ============================================
  static const bool enableCaching = true;
  static const Duration cacheValidDuration = Duration(minutes: 5);
  
  // ============================================
  // LOGGING
  // ============================================
  static const bool enableLogging = kDebugMode;
  static const bool isDevelopment = kDebugMode;
  
  // ============================================
  // HEADERS
  // ============================================
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // ============================================
  // FILE UPLOAD SETTINGS
  // ============================================
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 100;
  static const List<String> allowedImageFormats = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedVideoFormats = ['mp4', 'mov', 'avi', 'webm'];
  
  static int get maxImageSizeBytes => maxImageSizeMB * 1024 * 1024;
  static int get maxVideoSizeBytes => maxVideoSizeMB * 1024 * 1024;
  
  // ============================================
  // FILE VALIDATION
  // ============================================
  
  static bool isValidImageSize(int sizeInBytes) {
    return sizeInBytes <= maxImageSizeBytes;
  }
  
  static bool isValidVideoSize(int sizeInBytes) {
    return sizeInBytes <= maxVideoSizeBytes;
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  static bool isValidImageExtension(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedImageFormats.contains(extension);
  }
  
  static bool isValidVideoExtension(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedVideoFormats.contains(extension);
  }
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  static void printServiceUrls() {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📡 SERVICE URLS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔐 Auth:         $authServiceUrl');
    print('🚗 Accident:     $accidentServiceUrl');
    print('📹 Video:        $videoServiceUrl');
    print('🤖 AI:           $aiServiceUrl');
    print('🔔 Notification: $notificationServiceUrl');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
  
  static String get connectionMode => useGateway ? 'Gateway' : 'Direct';
  
  static String getServiceUrl(String serviceName) {
    switch (serviceName.toLowerCase()) {
      case 'auth':
        return authServiceUrl;
      case 'accident':
        return accidentServiceUrl;
      case 'video':
        return videoServiceUrl;
      case 'ai':
        return aiServiceUrl;
      case 'notification':
        return notificationServiceUrl;
      default:
        throw Exception('Unknown service: $serviceName');
    }
  }
}