
import 'package:flutter/foundation.dart';

class ApiConfig {
  
  
  

  static const bool useGateway = false;

  
  static const String localIP = '192.168.0.108'; 

  
  
  

  
  
  
  static const int authPort = 3001;
  static const int accidentPort = 3002;
  static const int videoPort = 3003; 
  static const int aiPort = 3004;
  static const int notificationPort = 3005;
  static const int reportPort = 3007; 

  
  
  
  static String get authServiceUrl => 'http://$localIP:$authPort';
  static String get accidentServiceUrl => 'http://$localIP:$accidentPort';
  static String get videoServiceUrl => 'http://$localIP:$videoPort';
  static String get aiServiceUrl => 'http://$localIP:$aiPort';
  static String get notificationServiceUrl => 'http://$localIP:$notificationPort';
  static String get reportServiceUrl => 'http://$localIP:$reportPort';


  static String get gatewayUrl => 'http://$localIP:3000';

  
  static String get baseUrl => useGateway ? gatewayUrl : accidentServiceUrl;

  
  
  
  static String get loginEndpoint => '$authServiceUrl/auth/login';
  static String get registerEndpoint => '$authServiceUrl/auth/register';
  static String get logoutEndpoint => '$authServiceUrl/auth/logout';
  static String get refreshTokenEndpoint => '$authServiceUrl/auth/refresh';
  static String get userProfileEndpoint => '$authServiceUrl/auth/profile';

  
  
  
  static String get accidentsEndpoint => '$accidentServiceUrl/accidents';
  static String get nearbyAccidentsEndpoint =>
      '$accidentServiceUrl/accidents/nearby';
  static String get userAccidentsEndpoint =>
      '$accidentServiceUrl/accidents/user';
  static String get accidentStatisticsEndpoint =>
      '$accidentServiceUrl/accidents/statistics';

  
  
  
  static String get videoUploadEndpoint => '$videoServiceUrl/upload';
  static String get videoListEndpoint => '$videoServiceUrl/videos';
  static String get videoStatusEndpoint =>
      '$videoServiceUrl/videos'; 

  
  
  
  static String get aiAnalyzeEndpoint => '$aiServiceUrl/ai/analyze';
  static String get aiDetectEndpoint => '$aiServiceUrl/ai/detect';
  static String get aiModelsEndpoint => '$aiServiceUrl/ai/models';

  
  
  
  static String get notificationsEndpoint =>
      '$notificationServiceUrl/notifications';
  static String get markReadEndpoint =>
      '$notificationServiceUrl/notifications/read';

  
  
  
  static String get falseReportsEndpoint => '$reportServiceUrl/false-reports';
  static String get reportReasonsEndpoint =>
      '$reportServiceUrl/false-reports/reasons';

  
  
  
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 30);

  
  static const Duration videoUploadTimeout = Duration(minutes: 5);

  
  
  
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  
  
  
  static const bool enableCaching = true;
  static const Duration cacheValidDuration = Duration(minutes: 5);

  
  
  
  static const bool enableLogging = kDebugMode;
  static const bool isDevelopment = kDebugMode;

  
  
  
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  
  
  
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 100;
  static const List<String> allowedImageFormats = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedVideoFormats = ['mp4', 'mov', 'avi', 'webm'];

  static int get maxImageSizeBytes => maxImageSizeMB * 1024 * 1024;
  static int get maxVideoSizeBytes => maxVideoSizeMB * 1024 * 1024;

  
  
  

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
