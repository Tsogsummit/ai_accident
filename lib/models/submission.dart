class Submission {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final String description;
  final String imageUrl;
  final String status; 
  final bool aiAnalyzed;
  final bool isAccident;
  final double? aiConfidence;
  final String? aiAnalysis;
  final String? accidentId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? analyzedAt;

  final String? accidentStatus;
  final String? accidentDescription;

  Submission({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.imageUrl,
    required this.status,
    required this.aiAnalyzed,
    required this.isAccident,
    this.aiConfidence,
    this.aiAnalysis,
    this.accidentId,
    this.errorMessage,
    required this.createdAt,
    this.analyzedAt,
    this.accidentStatus,
    this.accidentDescription,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      status: json['status']?.toString() ?? 'analyzing',
      aiAnalyzed: json['ai_analyzed'] == true || json['ai_analyzed'] == 1,
      isAccident: json['is_accident'] == true || json['is_accident'] == 1,
      aiConfidence: json['ai_confidence'] != null
          ? double.tryParse(json['ai_confidence'].toString())
          : null,
      aiAnalysis: json['ai_analysis']?.toString(),
      accidentId: json['accident_id']?.toString(),
      errorMessage: json['error_message']?.toString(),
      createdAt: DateTime.parse(json['created_at']),
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'])
          : null,
      accidentStatus: json['accident_status']?.toString(),
      accidentDescription: json['accident_description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'image_url': imageUrl,
      'status': status,
      'ai_analyzed': aiAnalyzed,
      'is_accident': isAccident,
      'ai_confidence': aiConfidence,
      'ai_analysis': aiAnalysis,
      'accident_id': accidentId,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'analyzed_at': analyzedAt?.toIso8601String(),
      'accident_status': accidentStatus,
      'accident_description': accidentDescription,
    };
  }

  String get statusMongolian {
    switch (status) {
      case 'analyzing':
        return 'Шинжилж байна';
      case 'accident_created':
        return 'Осол үүссэн';
      case 'not_accident':
        return 'Осол биш';
      case 'error':
        return 'Алдаа гарсан';
      default:
        return status;
    }
  }

  bool get isConfirmedAccident => status == 'accident_created' && accidentId != null;
  bool get isRejected => status == 'not_accident' || (status == 'error' && !isAccident);
}
