// lib/config/api_config.dart - API ТОХИРГОО (Service тус бүрээр)
import 'package:flutter/foundation.dart';

class ApiConfig {
  // ============================================
  // ҮНДСЭН ТОХИРГОО
  // ============================================
  
  // Gateway-гүй тохиргоо - Service тус бүрээр шууд холбогдоно
  static const bool useGateway = false;
  
  // Өөрийн компьютерийн IP хаяг (WiFi-ээр холбогдсон бол)
  // CMD/Terminal дээр: ipconfig (Windows) эсвэл ifconfig (Mac/Linux)
  static const String localIP = 'localhost'; // ⚠️ Энийг өөрчилнө үү!
  
  // Альтернатив: Android Emulator дээр ажиллуулах бол
  // static const String localIP = '10.0.2.2';
  
  // ============================================
  // SERVICE PORTS
  // ============================================
  static const int authPort = 3001;        // Auth Service
  static const int accidentPort = 3002;    // Accident Service  
  static const int videoPort = 3003;       // Video Service
  static const int aiPort = 3004;          // AI Detection Service
  static const int notificationPort = 3005; // Notification Service
  
  // ============================================
  // SERVICE BASE URLS
  // ============================================
  static String get authServiceUrl => 'http://$localIP:$authPort';
  static String get accidentServiceUrl => 'http://$localIP:$accidentPort';
  static String get videoServiceUrl => 'http://$localIP:$videoPort';
  static String get aiServiceUrl => 'http://$localIP:$aiPort';
  static String get notificationServiceUrl => 'http://$localIP:$notificationPort';
  
  // Gateway URL (хэрвээ дараа нь ашиглах бол)
  static String get gatewayUrl => 'http://$localIP:3000/api';
  
  // Одоогоор хэрэглэж буй үндсэн URL (accident service)
  static String get baseUrl => useGateway ? gatewayUrl : accidentServiceUrl;
  
  // ============================================
  // ENDPOINTS - Auth Service
  // ============================================
  static String get loginEndpoint => '$gatewayUrl/auth/login';
  static String get registerEndpoint => '$gatewayUrl/auth/register';
  static String get logoutEndpoint => '$gatewayUrl/auth/logout';
  static String get refreshTokenEndpoint => '$gatewayUrl/auth/refresh';
  static String get userProfileEndpoint => '$gatewayUrl/auth/profile';
  
  // ============================================
  // ENDPOINTS - Accident Service
  // ============================================
  static String get accidentsEndpoint => '$gatewayUrl/accidents';
  static String get nearbyAccidentsEndpoint => '$gatewayUrl/accidents/nearby';
  static String get userAccidentsEndpoint => '$gatewayUrl/accidents/user';
  static String get accidentStatisticsEndpoint => '$gatewayUrl/accidents/statistics';
  
  // ============================================
  // ENDPOINTS - Video Service
  // ============================================
  static String get videoUploadEndpoint => '$gatewayUrl/videos/upload';
  static String get videoListEndpoint => '$gatewayUrl/videos';
  static String get videoProcessEndpoint => '$gatewayUrl/videos/process';
  
  // ============================================
  // ENDPOINTS - AI Service
  // ============================================
  static String get aiAnalyzeEndpoint => '$gatewayUrl/ai/analyze';
  static String get aiDetectEndpoint => '$gatewayUrl/ai/detect';
  static String get aiModelsEndpoint => '$gatewayUrl/ai/models';
  
  // ============================================
  // ENDPOINTS - Notification Service
  // ============================================
  static String get notificationsEndpoint => '$gatewayUrl/notifications';
  static String get markReadEndpoint => '$gatewayUrl/notifications/read';
  
  // ============================================
  // TIMEOUT SETTINGS
  // ============================================
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 30);
  
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
  static const List<String> allowedVideoFormats = ['mp4', 'mov', 'avi'];
  
  // File size in bytes
  static int get maxImageSizeBytes => maxImageSizeMB * 1024 * 1024;
  static int get maxVideoSizeBytes => maxVideoSizeMB * 1024 * 1024;
  
  // ============================================
  // FILE VALIDATION METHODS
  // ============================================
  
  /// Check if image size is valid
  static bool isValidImageSize(int sizeInBytes) {
    return sizeInBytes <= maxImageSizeBytes;
  }
  
  /// Check if video size is valid
  static bool isValidVideoSize(int sizeInBytes) {
    return sizeInBytes <= maxVideoSizeBytes;
  }
  
  /// Format file size to human readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  /// Check if file extension is allowed for images
  static bool isValidImageExtension(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedImageFormats.contains(extension);
  }
  
  /// Check if file extension is allowed for videos
  static bool isValidVideoExtension(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedVideoFormats.contains(extension);
  }
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Print all service URLs (Debugging)
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
  
  /// Check if using gateway
  static String get connectionMode => useGateway ? 'Gateway' : 'Direct';
  
  /// Get service URL by name
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