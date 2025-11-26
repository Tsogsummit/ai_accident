import 'package:flutter/material.dart';
import 'dart:io';
import '../models/accident.dart';
import '../services/accident_service.dart';
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
    AccidentSource.camera,
  };
  Set<AccidentStatus> _statusFilters = {
    AccidentStatus.reported,
    AccidentStatus.confirmed,
  };

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

  Future<void> loadAccidents({
    bool forceRefresh = false,
    bool userOnly = false,
  }) async {
    if (_isLoading || _isRefreshing) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('📡 Ослын мэдээлэл татаж байна...');

      _accidents = await _accidentService.getAllAccidents(
        forceRefresh: forceRefresh,
        userOnly: userOnly,
      );

      print('✅ ${_accidents.length} осол ачаалагдлаа');

      _applyFilters();
      _lastFetchTime = DateTime.now();
      _error = '';
    } catch (e) {
      _error = 'Ослын мэдээлэл татахад алдаа гарлаа: ${e.toString()}';
      print('❌ Ослын мэдээлэл ачаалахад алдаа: $_error');
      _accidents = [];
      _applyFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAccidents() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _error = '';
    notifyListeners();

    try {
      print('🔄 Мэдээлэл шинэчилж байна...');

      _accidents = await _accidentService.getAllAccidents(forceRefresh: true);

      print('✅ ${_accidents.length} осол шинэчлэгдлээ');

      _applyFilters();
      _lastFetchTime = DateTime.now();
      _error = '';
    } catch (e) {
      _error = 'Мэдээлэл шинэчлэхэд алдаа гарлаа: ${e.toString()}';
      print('❌ Мэдээлэл шинэчлэхэд алдаа: $_error');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

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
      _error = 'Ойролцоох ослын мэдээлэл авахад алдаа гарлаа: ${e.toString()}';
      print('❌ Ойр дахь ослын мэдээлэл ачаалахад алдаа: $_error');
      _accidents = [];
      _applyFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> reportImageAccident({
    required File imageFile,
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

      print('📸 Зураг илгээж байна...');

      final result = await _accidentService.reportImageAccidentRaw(
        latitude: latitude,
        longitude: longitude,
        description: description,
        imageFile: imageFile,
        onProgress: (sent, total) {
          _uploadProgress = sent / total;
          if (onProgress != null) {
            onProgress(sent, total);
          }
          notifyListeners();
        },
      );

      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();

      if (result['success'] == true) {
        final data = result['data'];

        if (data != null && data is Map && data['id'] != null) {
          print('✅ Осол бүртгэгдлээ. ID: ${data['id']}');
          await loadAccidents(forceRefresh: true);
          return result;
        } else if (data != null && data['isAccident'] == false) {
          print('ℹ️ Осол илрээгүй');
          return result;
        }
      }

      return result;
    } catch (e) {
      _error = e.toString();
      print('❌ Зураг илгээхэд алдаа: $_error');
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();

      return {
        'success': false,
        'error': _error,
      };
    }
  }

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
      _error = 'Ослын мэдээлэл шинэчлэхэд алдаа гарлаа: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

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
      _error = 'Ослыг баталгаажуулахад алдаа гарлаа: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportFalseAccident({
    required int accidentId,
    required int userId,
    required int reasonId,
    String? comment,
  }) async {
    try {
      _error = '';

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
      _error = 'Худал дуудлага мэдээлэхэд алдаа гарлаа: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
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
      _error = 'Осол устгахад алдаа гарлаа: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

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
    _statusFilters = {AccidentStatus.reported, AccidentStatus.confirmed};
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
    super.dispose();
  }
}
