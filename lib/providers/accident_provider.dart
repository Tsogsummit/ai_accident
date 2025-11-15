// lib/providers/accident_provider.dart - ЗАСВАРЛАСАН (Mock data устгасан)
import 'package:flutter/material.dart';
import '../models/accident.dart';
import '../services/accident_service.dart';

class AccidentProvider extends ChangeNotifier {
  List<Accident> _accidents = [];
  List<Accident> _filteredAccidents = [];

  // Loading states
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;

  // Error handling
  String _error = '';
  DateTime? _lastFetchTime;

  // Upload progress
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  // Filters
  Set<AccidentSource> _sourceFilters = {
    AccidentSource.user,
    AccidentSource.camera
  };
  Set<AccidentSeverity> _severityFilters = {
    AccidentSeverity.minor,
    AccidentSeverity.moderate,
    AccidentSeverity.severe,
  };
  Set<AccidentStatus> _statusFilters = {
    AccidentStatus.reported,
    AccidentStatus.confirmed,
  };

  // Getters
  List<Accident> get accidents => _filteredAccidents;
  List<Accident> get allAccidents => _accidents;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;
  Set<AccidentSource> get sourceFilters => _sourceFilters;
  Set<AccidentSeverity> get severityFilters => _severityFilters;
  Set<AccidentStatus> get statusFilters => _statusFilters;

  final AccidentService _accidentService = AccidentService();

  // Statistics
  int get totalAccidents => _accidents.length;
  int get visibleAccidents => _filteredAccidents.length;
  int get userAccidents =>
      _accidents.where((a) => a.source == AccidentSource.user).length;
  int get cameraAccidents =>
      _accidents.where((a) => a.source == AccidentSource.camera).length;
  int get severeAccidents =>
      _accidents.where((a) => a.severity == AccidentSeverity.severe).length;
  int get moderateAccidents =>
      _accidents.where((a) => a.severity == AccidentSeverity.moderate).length;
  int get minorAccidents =>
      _accidents.where((a) => a.severity == AccidentSeverity.minor).length;
  int get reportedAccidents =>
      _accidents.where((a) => a.status == AccidentStatus.reported).length;
  int get confirmedAccidents =>
      _accidents.where((a) => a.status == AccidentStatus.confirmed).length;
  int get resolvedAccidents =>
      _accidents.where((a) => a.status == AccidentStatus.resolved).length;

  // ✅ Load accidents from API - NO MOCK DATA
  Future<void> loadAccidents({bool forceRefresh = false}) async {
    if (_isLoading || _isRefreshing) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('📡 Ослын мэдээлэл татаж байна...');
      
      _accidents = await _accidentService.getAllAccidents(
        forceRefresh: forceRefresh,
      );
      
      print('✅ ${_accidents.length} осол ачаалагдлаа');
      
      _applyFilters();
      _lastFetchTime = DateTime.now();
      _error = '';
    } catch (e) {
      _error = e.toString();
      print('❌ Ослын мэдээлэл ачаалахад алдаа: $_error');
      
      // ⚠️ АНХААР: Mock data ашиглахгүй! 
      // Хэрвээ API ажиллахгүй бол хоосон array буцаана
      _accidents = [];
      _applyFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Refresh accidents (pull-to-refresh)
  Future<void> refreshAccidents() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _error = '';
    notifyListeners();

    try {
      print('🔄 Мэдээлэл шинэчилж байна...');
      
      _accidents = await _accidentService.getAllAccidents(
        forceRefresh: true,
      );
      
      print('✅ ${_accidents.length} осол шинэчлэгдлээ');
      
      _applyFilters();
      _lastFetchTime = DateTime.now();
      _error = '';
    } catch (e) {
      _error = e.toString();
      print('❌ Мэдээлэл шинэчлэхэд алдаа: $_error');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  // ✅ Load nearby accidents
  Future<void> loadNearbyAccidents(
      double latitude,
      double longitude, {
        double radiusKm = 5.0,
      }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('📍 Ойролцоох ослын мэдээлэл татаж байна...');
      
      _accidents = await _accidentService.getNearbyAccidents(
        latitude,
        longitude,
        radiusKm: radiusKm,
      );
      
      print('✅ ${_accidents.length} осол олдлоо');
      
      _applyFilters();
      _lastFetchTime = DateTime.now();
    } catch (e) {
      _error = e.toString();
      print('❌ Ойр дахь ослын мэдээлэл ачаалахад алдаа: $_error');
      _accidents = [];
      _applyFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Report new accident with progress tracking
  Future<Accident?> reportAccident({
    required double latitude,
    required double longitude,
    required String description,
    AccidentSeverity? severity,
    var imageFile,
    var videoFile,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = '';
      notifyListeners();

      print('📤 Осол мэдээлж байна...');

      final accident = await _accidentService.reportAccident(
        latitude: latitude,
        longitude: longitude,
        description: description,
        severity: severity,
        imageFile: imageFile,
        videoFile: videoFile,
        onProgress: (sent, total) {
          _uploadProgress = sent / total;
          notifyListeners();
        },
      );

      print('✅ Осол амжилттай мэдээлэгдлээ');

      _accidents.insert(0, accident); // Add to beginning
      _applyFilters();
      _lastFetchTime = DateTime.now();

      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();

      return accident;
    } catch (e) {
      _error = e.toString();
      print('❌ Осол мэдээлэхэд алдаа: $_error');
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  // ✅ Update accident
  Future<bool> updateAccident(
      String accidentId, {
        String? description,
        AccidentSeverity? severity,
        AccidentStatus? status,
      }) async {
    try {
      _error = '';

      final updated = await _accidentService.updateAccident(
        accidentId,
        description: description,
        severity: severity,
        status: status,
      );

      final index = _accidents.indexWhere((a) => a.id == accidentId);
      if (index != -1) {
        _accidents[index] = updated;
        _applyFilters();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ Verify accident
  Future<bool> verifyAccident(String accidentId) async {
    try {
      _error = '';

      final success = await _accidentService.verifyAccident(accidentId);
      if (success) {
        // Update local accident
        final index = _accidents.indexWhere((a) => a.id == accidentId);
        if (index != -1) {
          _accidents[index] = _accidents[index].copyWith(
            verificationCount: _accidents[index].verificationCount + 1,
          );
          _applyFilters();
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ Report false accident
  Future<bool> reportFalseAccident(
      String accidentId, {
        required String reason,
        String? comment,
      }) async {
    try {
      _error = '';

      final success = await _accidentService.reportFalseAccident(
        accidentId,
        reason: reason,
        comment: comment,
      );
      if (success) {
        await loadAccidents(forceRefresh: true);
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ Delete accident
  Future<bool> deleteAccident(String accidentId) async {
    try {
      _error = '';

      final success = await _accidentService.deleteAccident(accidentId);
      if (success) {
        _accidents.removeWhere((a) => a.id == accidentId);
        _applyFilters();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Filter methods
  void toggleSourceFilter(AccidentSource source) {
    if (_sourceFilters.contains(source)) {
      _sourceFilters.remove(source);
    } else {
      _sourceFilters.add(source);
    }
    _applyFilters();
    notifyListeners();
  }

  void toggleSeverityFilter(AccidentSeverity severity) {
    if (_severityFilters.contains(severity)) {
      _severityFilters.remove(severity);
    } else {
      _severityFilters.add(severity);
    }
    _applyFilters();
    notifyListeners();
  }

  void toggleStatusFilter(AccidentStatus status) {
    if (_statusFilters.contains(status)) {
      _statusFilters.remove(status);
    } else {
      _statusFilters.add(status);
    }
    _applyFilters();
    notifyListeners();
  }

  void setSourceFilters(Set<AccidentSource> sources) {
    _sourceFilters = sources;
    _applyFilters();
    notifyListeners();
  }

  void setSeverityFilters(Set<AccidentSeverity> severities) {
    _severityFilters = severities;
    _applyFilters();
    notifyListeners();
  }

  void setStatusFilters(Set<AccidentStatus> statuses) {
    _statusFilters = statuses;
    _applyFilters();
    notifyListeners();
  }

  void resetFilters() {
    _sourceFilters = {AccidentSource.user, AccidentSource.camera};
    _severityFilters = {
      AccidentSeverity.minor,
      AccidentSeverity.moderate,
      AccidentSeverity.severe,
    };
    _statusFilters = {
      AccidentStatus.reported,
      AccidentStatus.confirmed,
    };
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredAccidents = _accidents.where((accident) {
      final sourceMatch = _sourceFilters.contains(accident.source);
      final severityMatch = _severityFilters.contains(accident.severity);
      final statusMatch = _statusFilters.contains(accident.status);

      return sourceMatch && severityMatch && statusMatch;
    }).toList();

    // Sort by timestamp (newest first)
    _filteredAccidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  // ✅ Clear cache
  void clearCache() {
    _accidentService.clearCache();
  }

  @override
  void dispose() {
    _accidentService.dispose();
    super.dispose();
  }
}