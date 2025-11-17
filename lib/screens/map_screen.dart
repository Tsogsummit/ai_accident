import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/accident_provider.dart';
import '../models/accident.dart';
import '../widgets/false_report_dialog.dart';

class MapScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  
  const MapScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  Set<Marker> _markers = {};
  bool _isMapReady = false;
  double _currentZoom = 12.0;
  CameraPosition? _currentCameraPosition;
  bool _isAnimating = false;

  // Track last updated accidents to prevent unnecessary marker updates
  List<Accident>? _lastAccidents;

  static const LatLng _defaultLocation = LatLng(47.9077, 106.8832); // Ulaanbaatar
  static const double _minZoom = 5.0;
  static const double _maxZoom = 20.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccidents();
      // If initial location is provided, move to it
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        Future.delayed(Duration(milliseconds: 500), () {
          _moveToLocation(
            LatLng(widget.initialLatitude!, widget.initialLongitude!),
            zoom: 15.0,
          );
        });
      }
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

  bool _shouldUpdateMarkers(List<Accident> accidents) {
    // Check if accidents list has changed
    if (_lastAccidents == null) return true;
    if (_lastAccidents!.length != accidents.length) return true;

    // Check if any accident IDs are different
    return !_lastAccidents!.every((a) => accidents.any((b) => a.id == b.id));
  }

  void _updateMarkers(List<Accident> accidents) {
    if (!_isMapReady) return;

    Set<Marker> newMarkers = {};

    for (final accident in accidents) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('accident_${accident.id}'),
          position: LatLng(accident.latitude, accident.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: accident.statusMongolian,
            snippet: _formatTime(accident.timestamp),
            onTap: () => _showAccidentDetails(accident),
          ),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      _lastAccidents = accidents;
    });
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

  void _moveToLocation(LatLng location, {double? zoom}) async {
    if (_mapController == null || _isAnimating) return;
    
    _isAnimating = true;
    try {
      final targetZoom = zoom ?? _currentZoom.clamp(_minZoom, _maxZoom);
      
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: targetZoom,
            tilt: _currentCameraPosition?.tilt ?? 0.0,
            bearing: _currentCameraPosition?.bearing ?? 0.0,
          ),
        ),
      );
    } finally {
      _isAnimating = false;
    }
  }

  void _moveToCurrentLocation() {
    if (_currentPosition != null) {
      _moveToLocation(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15.0,
      );
    } else {
      _initializeLocation().then((_) {
        if (_currentPosition != null) {
          _moveToLocation(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15.0,
          );
        }
      });
    }
  }
  
  void _zoomIn() {
    if (_mapController == null || _isAnimating) return;
    _mapController!.animateCamera(CameraUpdate.zoomIn());
  }
  
  void _zoomOut() {
    if (_mapController == null || _isAnimating) return;
    _mapController!.animateCamera(CameraUpdate.zoomOut());
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
                  color: Colors.red,
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
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _moveToLocation(
                            LatLng(accident.latitude, accident.longitude),
                            zoom: 15.0,
                          );
                        },
                        icon: Icon(Icons.location_on),
                        label: Text('Газрын зураг дээр харах'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final provider = Provider.of<AccidentProvider>(context, listen: false);

                          navigator.pop();
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => FalseReportDialog(
                              accidentId: int.parse(accident.id),
                              userHasReported: accident.userHasReported,
                            ),
                          );
                          if (result == true) {
                            // Force reload accidents from backend to reflect status change
                            await provider.loadAccidents(forceRefresh: true);
                            if (mounted && _isMapReady) {
                              _updateMarkers(provider.accidents);
                            }
                          }
                        },
                        icon: Icon(
                          accident.userHasReported ? Icons.check_circle : Icons.report_problem,
                          color: accident.userHasReported ? Colors.grey : Colors.orange,
                        ),
                        label: Text(
                          accident.userHasReported ? 'Мэдэгдсэн' : 'Буруу мэдээлэл мэдэгдэх',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: accident.userHasReported ? Colors.grey : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ],
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
        automaticallyImplyLeading: false,
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
          // Schedule marker update after build completes, only if data changed
          if (!provider.isLoading &&
              provider.accidents.isNotEmpty &&
              _isMapReady &&
              _shouldUpdateMarkers(provider.accidents)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMarkers(provider.accidents);
              }
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
                minMaxZoomPreference: MinMaxZoomPreference(_minZoom, _maxZoom),
                // Enable smooth gestures
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                // Optimize gesture recognizers for smooth interaction
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                  Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                  Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                  Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
                },
                onCameraMove: (position) {
                  _currentZoom = position.zoom;
                  _currentCameraPosition = position;
                },
                onCameraMoveStarted: () {
                  _isAnimating = true;
                },
                onCameraIdle: () {
                  _isAnimating = false;
                },
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
                          '${provider.accidents.where((a) => a.status == AccidentStatus.confirmed).length}',
                          'Баталгаажсан',
                          Colors.green,
                        ),
                        _buildCompactStat(
                          '${provider.accidents.where((a) => a.status == AccidentStatus.reported).length}',
                          'Мэдээлсэн',
                          Colors.orange,
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
            heroTag: "zoom_in",
            onPressed: _zoomIn,
            mini: true,
            backgroundColor: Colors.blue[700],
            child: Icon(Icons.add),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "zoom_out",
            onPressed: _zoomOut,
            mini: true,
            backgroundColor: Colors.blue[700],
            child: Icon(Icons.remove),
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "location",
            onPressed: _moveToCurrentLocation,
            mini: true,
            backgroundColor: Colors.blue,
            child: Icon(Icons.my_location),
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _loadAccidents,
            backgroundColor: Colors.green,
            child: Icon(Icons.refresh),
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
