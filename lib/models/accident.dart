// lib/models/accident.dart - FIXED VERSION
enum AccidentSeverity { minor, moderate, severe }
enum AccidentStatus { reported, confirmed, resolved, falseAlarm }
enum AccidentSource { user, camera }

class Accident {
  final String id;
  final double latitude;
  final double longitude;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final AccidentSeverity severity;
  final AccidentStatus status;
  final AccidentSource source;
  final String reportedBy;
  final int? userId;
  final int? cameraId;
  final int verificationCount;

  Accident({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.imageUrl = '',
    required this.timestamp,
    this.severity = AccidentSeverity.minor,
    this.status = AccidentStatus.reported,
    this.source = AccidentSource.user,
    this.reportedBy = 'Тодорхойгүй',
    this.userId,
    this.cameraId,
    this.verificationCount = 0,
  });

  factory Accident.fromJson(Map<String, dynamic> json) {
    return Accident(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      timestamp: json['accident_time'] != null
          ? DateTime.parse(json['accident_time'])
          : (json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now()),
      severity: _parseSeverity(json['severity']),
      status: _parseStatus(json['status']),
      source: _parseSource(json['source']),
      reportedBy: json['reported_by'] ?? json['reportedBy'] ?? 'Тодорхойгүй',
      userId: json['user_id'],
      cameraId: json['camera_id'],
      verificationCount: json['verification_count'] ?? 0,
    );
  }

  static AccidentSeverity _parseSeverity(dynamic severity) {
    if (severity is int) {
      if (severity >= 0 && severity < AccidentSeverity.values.length) {
        return AccidentSeverity.values[severity];
      }
      return AccidentSeverity.minor;
    }

    if (severity is String) {
      switch (severity.toLowerCase()) {
        case 'severe':
          return AccidentSeverity.severe;
        case 'moderate':
          return AccidentSeverity.moderate;
        case 'minor':
        default:
          return AccidentSeverity.minor;
      }
    }

    return AccidentSeverity.minor;
  }

  static AccidentStatus _parseStatus(dynamic status) {
    if (status is int) {
      if (status >= 0 && status < AccidentStatus.values.length) {
        return AccidentStatus.values[status];
      }
      return AccidentStatus.reported;
    }

    if (status is String) {
      switch (status.toLowerCase()) {
        case 'confirmed':
          return AccidentStatus.confirmed;
        case 'resolved':
          return AccidentStatus.resolved;
        case 'false_alarm':
        case 'falsealarm':
          return AccidentStatus.falseAlarm;
        case 'reported':
        default:
          return AccidentStatus.reported;
      }
    }

    return AccidentStatus.reported;
  }

  static AccidentSource _parseSource(dynamic source) {
    if (source is String) {
      switch (source.toLowerCase()) {
        case 'camera':
          return AccidentSource.camera;
        case 'user':
        default:
          return AccidentSource.user;
      }
    }
    return AccidentSource.user;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'image_url': imageUrl,
      'accident_time': timestamp.toIso8601String(),
      'severity': _severityToString(severity),
      'status': _statusToString(status),
      'source': _sourceToString(source),
      'reported_by': reportedBy,
      'user_id': userId,
      'camera_id': cameraId,
      'verification_count': verificationCount,
    };
  }

  static String _severityToString(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe:
        return 'severe';
      case AccidentSeverity.moderate:
        return 'moderate';
      case AccidentSeverity.minor:
        return 'minor';
    }
  }

  static String _statusToString(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported:
        return 'reported';
      case AccidentStatus.confirmed:
        return 'confirmed';
      case AccidentStatus.resolved:
        return 'resolved';
      case AccidentStatus.falseAlarm:
        return 'false_alarm';
    }
  }

  static String _sourceToString(AccidentSource source) {
    switch (source) {
      case AccidentSource.user:
        return 'user';
      case AccidentSource.camera:
        return 'camera';
    }
  }

  // Mongolian display names
  String get severityMongolian {
    switch (severity) {
      case AccidentSeverity.severe:
        return 'Ноцтой';
      case AccidentSeverity.moderate:
        return 'Дунд зэрэг';
      case AccidentSeverity.minor:
        return 'Хөнгөн';
    }
  }

  String get statusMongolian {
    switch (status) {
      case AccidentStatus.reported:
        return 'Мэдээлсэн';
      case AccidentStatus.confirmed:
        return 'Баталгаажсан';
      case AccidentStatus.resolved:
        return 'Шийдвэрлэсэн';
      case AccidentStatus.falseAlarm:
        return 'Худал дуудлага';
    }
  }

  String get sourceMongolian {
    switch (source) {
      case AccidentSource.user:
        return 'Хэрэглэгч';
      case AccidentSource.camera:
        return 'Камер';
    }
  }

  // Copy method for updating accidents
  Accident copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? description,
    String? imageUrl,
    DateTime? timestamp,
    AccidentSeverity? severity,
    AccidentStatus? status,
    AccidentSource? source,
    String? reportedBy,
    int? userId,
    int? cameraId,
    int? verificationCount,
  }) {
    return Accident(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      source: source ?? this.source,
      reportedBy: reportedBy ?? this.reportedBy,
      userId: userId ?? this.userId,
      cameraId: cameraId ?? this.cameraId,
      verificationCount: verificationCount ?? this.verificationCount,
    );
  }
}