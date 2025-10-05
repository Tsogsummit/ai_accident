enum AccidentSeverity { minor, moderate, severe }
enum AccidentStatus { reported, confirmed, resolved, falseAlarm }

class Accident {
  final String id;
  final double latitude;
  final double longitude;
  final String description;
  final String imageUrl;
  final DateTime timestamp;
  final AccidentSeverity severity;
  final AccidentStatus status;
  final String reportedBy;

  Accident({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.imageUrl = '',
    required this.timestamp,
    this.severity = AccidentSeverity.minor,
    this.status = AccidentStatus.reported,
    this.reportedBy = 'Unknown',
  });

  factory Accident.fromJson(Map<String, dynamic> json) {
    return Accident(
      id: json['id'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      severity: json['severity'] != null 
          ? AccidentSeverity.values[json['severity']] 
          : AccidentSeverity.minor,
      status: json['status'] != null 
          ? AccidentStatus.values[json['status']] 
          : AccidentStatus.reported,
      reportedBy: json['reportedBy'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.index,
      'status': status.index,
      'reportedBy': reportedBy,
    };
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
    String? reportedBy,
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
      reportedBy: reportedBy ?? this.reportedBy,
    );
  }
}