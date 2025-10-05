import 'package:flutter/material.dart';
import '../models/accident.dart';
import '../services/accident_service.dart';

class AccidentProvider extends ChangeNotifier {
  List<Accident> _accidents = [];
  bool _isLoading = false;
  String _error = '';

  List<Accident> get accidents => _accidents;
  bool get isLoading => _isLoading;
  String get error => _error;

  final AccidentService _accidentService = AccidentService();

  Future<void> loadAccidents() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // For testing purposes, use mock data since API might not be available
      _accidents = await _getMockAccidents();
      // Uncomment below line when you have a working API
      // _accidents = await _accidentService.getAllAccidents();
    } catch (e) {
      _error = e.toString();
      print('Error loading accidents: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mock data for testing
  Future<List<Accident>> _getMockAccidents() async {
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay
    
    return [
      Accident(
        id: '1',
        latitude: 47.9184,
        longitude: 106.9177,
        description: 'Хөнгөн машин мөргөлдөөн, замын голд',
        imageUrl: 'https://example.com/accident1.jpg',
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
        severity: AccidentSeverity.minor,
        status: AccidentStatus.reported,
        reportedBy: 'Батбаяр',
      ),
      Accident(
        id: '2',
        latitude: 47.9200,
        longitude: 106.9190,
        description: 'Ачааны машин эвдэрсэн, зам хааж байна',
        imageUrl: 'https://example.com/accident2.jpg',
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        severity: AccidentSeverity.moderate,
        status: AccidentStatus.confirmed,
        reportedBy: 'Цэцэгмаа',
      ),
      Accident(
        id: '3',
        latitude: 47.9150,
        longitude: 106.9160,
        description: 'Ноцтой осол, түргэн тусламж хэрэгтэй',
        imageUrl: 'https://example.com/accident3.jpg',
        timestamp: DateTime.now().subtract(Duration(hours: 3)),
        severity: AccidentSeverity.severe,
        status: AccidentStatus.confirmed,
        reportedBy: 'Өнөрбаяр',
      ),
    ];
  }

  Future<void> reportAccident(Accident accident) async {
    try {
      // For testing, just add to local list
      _accidents.add(accident);
      notifyListeners();
      
      // Uncomment below when API is ready
      // final newAccident = await _accidentService.reportAccident(accident);
      // _accidents.add(newAccident);
      // notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateAccidentStatus(String accidentId, AccidentStatus status) async {
    try {
      final index = _accidents.indexWhere((a) => a.id == accidentId);
      if (index != -1) {
        _accidents[index] = _accidents[index].copyWith(status: status);
        notifyListeners();
      }
      
      // Uncomment below when API is ready
      // await _accidentService.updateAccidentStatus(accidentId, status);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void addAccident(Accident accident) {
    _accidents.add(accident);
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}