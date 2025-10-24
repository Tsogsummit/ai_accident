import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/accident_provider.dart';
import '../models/accident.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  Completer<GoogleMapController> _controller = Completer();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  Set<Marker> _markers = {};
  bool _isMapReady = false;
  double _currentZoom = 12.0;

  static const LatLng _defaultLocation = LatLng(47.9077, 106.8832); // Ulaanbaatar

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccidents();
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        setState(() => _currentPosition = position);
        if (_isMapReady) {
          _moveToLocation(LatLng(position.latitude, position.longitude));
        }
      }
    } catch (e) {
      print('Location error: $e');
    }
  }

  void _loadAccidents() {
    final provider = Provider.of<AccidentProvider>(context, listen: false);
    provider.loadAccidents().then((_) {
      if (mounted && _isMapReady) {
        _updateMarkers(provider.accidents);
      }
    });
  }

  void _updateMarkers(List<Accident> accidents) {
    if (!_isMapReady) return;

    Set<Marker> newMarkers = {};

    for (final accident in accidents) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('accident_${accident.id}'),
          position: LatLng(accident.latitude, accident.longitude),
          icon: _getMarkerIcon(accident.severity),
          infoWindow: InfoWindow(
            title: _severityToMongolian(accident.severity),
            snippet: _formatTime(accident.timestamp),
            onTap: () => _showAccidentDetails(accident),
          ),
        ),
      );
    }

    setState(() => _markers = newMarkers);
  }

  BitmapDescriptor _getMarkerIcon(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case AccidentSeverity.moderate:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case AccidentSeverity.minor:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    _mapController = controller;
    _isMapReady = true;

    if (_currentPosition != null) {
      _moveToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }

    Timer(Duration(milliseconds: 300), () {
      if (mounted) _loadAccidents();
    });
  }

  void _moveToLocation(LatLng location) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 15.0),
        ),
      );
    }
  }

  void _moveToCurrentLocation() {
    if (_currentPosition != null) {
      _moveToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    } else {
      _initializeLocation().then((_) {
        if (_currentPosition != null) {
          _moveToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
        }
      });
    }
  }

  void _showAccidentDetails(Accident accident) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getSeverityColor(accident.severity),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Осол #${accident.id}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Хүнд байдал', _severityToMongolian(accident.severity)),
                      _buildInfoRow('Төлөв', _statusToMongolian(accident.status)),
                      _buildInfoRow('Огноо', _formatDate(accident.timestamp)),
                      _buildInfoRow('Цаг', _formatTime(accident.timestamp)),
                      _buildInfoRow('Байршил', '${accident.latitude.toStringAsFixed(6)}, ${accident.longitude.toStringAsFixed(6)}'),
                      _buildInfoRow('Мэдээлсэн', accident.reportedBy),
                      if (accident.description.isNotEmpty)
                        _buildInfoRow('Тайлбар', accident.description),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _moveToLocation(LatLng(accident.latitude, accident.longitude));
                    },
                    icon: Icon(Icons.location_on),
                    label: Text('Газрын зураг дээр харах'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe: return Colors.red;
      case AccidentSeverity.moderate: return Colors.orange;
      case AccidentSeverity.minor: return Colors.yellow[700]!;
    }
  }

  String _severityToMongolian(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe: return 'Ноцтой';
      case AccidentSeverity.moderate: return 'Дунд зэрэг';
      case AccidentSeverity.minor: return 'Хөнгөн';
    }
  }

  String _statusToMongolian(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported: return 'Мэдээлсэн';
      case AccidentStatus.confirmed: return 'Баталгаажсан';
      case AccidentStatus.resolved: return 'Шийдэгдсэн';
      case AccidentStatus.falseAlarm: return 'Худал';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Замын осол'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
            tooltip: 'Миний байршил',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAccidents,
            tooltip: 'Шинэчлэх',
          ),
        ],
      ),
      body: Consumer<AccidentProvider>(
        builder: (context, provider, child) {
          if (!provider.isLoading &&
              provider.accidents.isNotEmpty &&
              _isMapReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMarkers(provider.accidents);
            });
          }

          return Stack(
            children: [
              // Google Map
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : _defaultLocation,
                  zoom: 12.0,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                onCameraMove: (position) => _currentZoom = position.zoom,
              ),

              // ✅ COMPACT STATISTICS - Single Row
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactStat(
                          '${provider.accidents.length}',
                          'Нийт',
                          Colors.grey[700]!,
                        ),
                        _buildCompactStat(
                          '${_markers.length}',
                          'Харагдаж буй',
                          Colors.blue,
                        ),
                        _buildCompactStat(
                          '${provider.accidents.where((a) => a.severity == AccidentSeverity.severe).length}',
                          'Ноцтой',
                          Colors.red,
                        ),
                        _buildCompactStat(
                          '${provider.accidents.where((a) => a.severity == AccidentSeverity.moderate).length}',
                          'Дунд',
                          Colors.orange,
                        ),
                        _buildCompactStat(
                          '${provider.accidents.where((a) => a.severity == AccidentSeverity.minor).length}',
                          'Хөнгөн',
                          Colors.yellow[700]!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Loading overlay
              if (provider.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black12,
                    child: Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(strokeWidth: 3),
                              SizedBox(height: 16),
                              Text(
                                'Осол ачааллаж байна...',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "location",
            onPressed: _moveToCurrentLocation,
            child: Icon(Icons.my_location),
            mini: true,
            backgroundColor: Colors.blue,
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _loadAccidents,
            child: Icon(Icons.refresh),
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }

  // ✅ COMPACT STAT WIDGET - Smaller and cleaner
  Widget _buildCompactStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}