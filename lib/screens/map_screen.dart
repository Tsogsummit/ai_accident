import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
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
  google_maps.GoogleMapController? _googleMapController;
  final Completer<google_maps.GoogleMapController> _googleController = Completer();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  Set<google_maps.Marker> _googleMarkers = {};

  bool _isMapReady = false;
  double _currentZoom = 12.0;
  google_maps.CameraPosition? _currentGoogleCameraPosition;
  bool _isAnimating = false;

  List<Accident>? _lastAccidents;

  static const double _defaultLat = 47.9077;
  static const double _defaultLng = 106.8832;
  static const double _minZoom = 5.0;
  static const double _maxZoom = 20.0;

  bool _showTraffic = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccidents();
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        Future.delayed(Duration(milliseconds: 500), () {
          _moveToLocation(
            widget.initialLatitude!,
            widget.initialLongitude!,
            zoom: 15.0,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _googleMapController?.dispose();
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
          _moveToLocation(position.latitude, position.longitude);
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
    if (_lastAccidents == null) return true;
    if (_lastAccidents!.length != accidents.length) return true;

    return !_lastAccidents!.every((a) => accidents.any((b) => a.id == b.id));
  }

  void _updateMarkers(List<Accident> accidents) {
    if (!_isMapReady) return;

    Set<google_maps.Marker> newMarkers = {};
    for (final accident in accidents) {
      newMarkers.add(
        google_maps.Marker(
          markerId: google_maps.MarkerId('accident_${accident.id}'),
          position: google_maps.LatLng(accident.latitude, accident.longitude),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
              google_maps.BitmapDescriptor.hueRed),
          infoWindow: google_maps.InfoWindow(
            title: accident.statusMongolian,
            snippet: _formatTime(accident.timestamp),
            onTap: () => _showAccidentDetails(accident),
          ),
        ),
      );
    }
    setState(() {
      _googleMarkers = newMarkers;
      _lastAccidents = accidents;
    });
  }

  void _onGoogleMapCreated(google_maps.GoogleMapController controller) {
    _googleController.complete(controller);
    _googleMapController = controller;
    _isMapReady = true;

    if (_currentPosition != null) {
      _moveToLocation(_currentPosition!.latitude, _currentPosition!.longitude);
    }

    Timer(Duration(milliseconds: 300), () {
      if (mounted) _loadAccidents();
    });
  }

  void _moveToLocation(double lat, double lng, {double? zoom}) async {
    if (_isAnimating) return;

    _isAnimating = true;
    try {
      final targetZoom = zoom ?? _currentZoom.clamp(_minZoom, _maxZoom);

      if (_googleMapController != null) {
        await _googleMapController!.animateCamera(
          google_maps.CameraUpdate.newCameraPosition(
            google_maps.CameraPosition(
              target: google_maps.LatLng(lat, lng),
              zoom: targetZoom,
              tilt: _currentGoogleCameraPosition?.tilt ?? 0.0,
              bearing: _currentGoogleCameraPosition?.bearing ?? 0.0,
            ),
          ),
        );
      }
    } finally {
      _isAnimating = false;
    }
  }

  void _moveToCurrentLocation() {
    if (_currentPosition != null) {
      _moveToLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        zoom: 15.0,
      );
    } else {
      _initializeLocation().then((_) {
        if (_currentPosition != null) {
          _moveToLocation(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            zoom: 15.0,
          );
        }
      });
    }
  }

  void _zoomIn() {
    if (_isAnimating) return;
    if (_googleMapController != null) {
      _googleMapController!.animateCamera(google_maps.CameraUpdate.zoomIn());
    }
  }

  void _zoomOut() {
    if (_isAnimating) return;
    if (_googleMapController != null) {
      _googleMapController!.animateCamera(google_maps.CameraUpdate.zoomOut());
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
                            accident.latitude,
                            accident.longitude,
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

  Widget _buildGoogleMap() {
    return google_maps.GoogleMap(
      onMapCreated: _onGoogleMapCreated,
      initialCameraPosition: google_maps.CameraPosition(
        target: _currentPosition != null
            ? google_maps.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : google_maps.LatLng(_defaultLat, _defaultLng),
        zoom: 12.0,
      ),
      markers: _googleMarkers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      trafficEnabled: _showTraffic, 
      minMaxZoomPreference: google_maps.MinMaxZoomPreference(_minZoom, _maxZoom),
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
        Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
      },
      onCameraMove: (position) {
        _currentZoom = position.zoom;
        _currentGoogleCameraPosition = position;
      },
      onCameraMoveStarted: () {
        _isAnimating = true;
      },
      onCameraIdle: () {
        _isAnimating = false;
      },
    );
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
              _buildGoogleMap(),

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
                          '${_googleMarkers.length}',
                          'Харагдаж буй',
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

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
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "traffic",
            onPressed: () {
              setState(() {
                _showTraffic = !_showTraffic;
              });
            },
            mini: true,
            backgroundColor: _showTraffic ? Colors.orange : Colors.grey[700],
            tooltip: _showTraffic ? 'Замын хөдөлгөөн нуух' : 'Замын хөдөлгөөн харуулах',
            child: Icon(
              Icons.traffic,
              color: _showTraffic ? Colors.white : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

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
