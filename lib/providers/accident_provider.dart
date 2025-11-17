// lib/providers/accident_provider.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/accident.dart';
import '../services/accident_service.dart';
import '../services/video_service.dart';
import '../services/false_report_service.dart';

class AccidentProvider extends ChangeNotifier {
  List<Accident> _accidents = [];
  List<Accident> _filteredAccidents = [];

  bool _isLoading = false;
  bool _isRefreshing = false;
  String _error = '';
  DateTime? _lastFetchTime;

  double _uploadProgress = 0.0;
  bool _isUploading = false;

  Set<AccidentSource> _sourceFilters = {
    AccidentSource.user,
    AccidentSource.camera
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
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;
  Set<AccidentSource> get sourceFilters => _sourceFilters;
  Set<AccidentStatus> get statusFilters => _statusFilters;

  final AccidentService _accidentService = AccidentService();
  final VideoService _videoService = VideoService();

  // Statistics
  int get totalAccidents => _accidents.length;
  int get visibleAccidents => _filteredAccidents.length;
  int get userAccidents =>
      _accidents.where((a) => a.source == AccidentSource.user).length;
  int get cameraAccidents =>
      _accidents.where((a) => a.source == AccidentSource.camera).length;
  int get reportedAccidents =>
      _accidents.where((a) => a.status == AccidentStatus.reported).length;
  int get confirmedAccidents =>
      _accidents.where((a) => a.status == AccidentStatus.confirmed).length;
  int get resolvedAccidents =>
      _accidents.where((a) => a.status == AccidentStatus.resolved).length;

  // Load accidents
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
      _accidents = [];
      _applyFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh accidents
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

  // Load nearby accidents
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

  // ✅✅✅ FIXED: VIDEO UPLOAD with proper response handling
  Future<Map<String, dynamic>?> uploadVideoAccident({
    required File videoFile,
    required double latitude,
    required double longitude,
    required String description,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = '';
      notifyListeners();

      print('📹 Видео upload эхэллээ...');

      // Call VideoService
      final result = await _videoService.uploadVideo(
        videoFile: videoFile,
        latitude: latitude,
        longitude: longitude,
        description: description,
        onProgress: (sent, total) {
          _uploadProgress = sent / total;
          if (onProgress != null) {
            onProgress(sent, total);
          }
          notifyListeners();
        },
      );

      print('✅ Response received: $result');

      if (result['success'] == true) {
        print('✅ Video амжилттай илгээгдлээ');
        print('   VideoId: ${result['videoId']}');
        print('   AccidentId: ${result['accidentId']}');

        // ✅ Clear cache to ensure fresh data from backend
        _accidentService.clearCache();
        
        // ✅ Always reload from backend after successful upload
        // This ensures we get the complete accident data with proper timestamps
        // and any additional fields that might have been set by the backend
        await Future.delayed(Duration(milliseconds: 500)); // Small delay to ensure backend has processed
        await loadAccidents(forceRefresh: true);

        _isUploading = false;
        _uploadProgress = 0.0;
        notifyListeners();

        return result;
      } else {
        throw Exception(result['error'] ?? 'Видео илгээлт амжилтгүй');
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Видео илгээхэд алдаа: $_error');
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      rethrow;
    }
  }

  // Update accident
  Future<bool> updateAccident(
      String accidentId, {
        String? description,
        AccidentStatus? status,
      }) async {
    try {
      _error = '';

      final updated = await _accidentService.updateAccident(
        accidentId,
        description: description,
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

  // Verify accident
  Future<bool> verifyAccident(String accidentId) async {
    try {
      _error = '';

      final success = await _accidentService.verifyAccident(accidentId);
      if (success) {
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

  // Report false accident (using new FalseReportService)
  Future<bool> reportFalseAccident({
    required int accidentId,
    required int userId,
    required int reasonId,
    String? comment,
  }) async {
    try {
      _error = '';

      // Import FalseReportService at the top of the file
      final falseReportService = FalseReportService();

      final result = await falseReportService.reportFalseAlarm(
        accidentId: accidentId,
        userId: userId,
        reasonId: reasonId,
        comment: comment,
      );

      final success = result['success'] == true;

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

  // Delete accident
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

  void setStatusFilters(Set<AccidentStatus> statuses) {
    _statusFilters = statuses;
    _applyFilters();
    notifyListeners();
  }

  void resetFilters() {
    _sourceFilters = {AccidentSource.user, AccidentSource.camera};
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
      final statusMatch = _statusFilters.contains(accident.status);

      return sourceMatch && statusMatch;
    }).toList();

    _filteredAccidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void clearCache() {
    _accidentService.clearCache();
  }

  @override
  void dispose() {
    _accidentService.dispose();
    _videoService.dispose();
    super.dispose();
  }
}