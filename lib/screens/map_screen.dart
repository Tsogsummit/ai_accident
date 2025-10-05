import 'dart:async';
import 'dart:math' as math;
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

class _MapScreenState extends State<MapScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  // Controllers and state
  GoogleMapController? _mapController;
  Completer<GoogleMapController> _controller = Completer();

  // Location state
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLocationServiceEnabled = false;

  // Map state
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Map<String, BitmapDescriptor> _customIcons = {};

  // Performance optimization
  List<Accident> _cachedAccidents = [];
  Timer? _debounceTimer;
  bool _isMapReady = false;
  bool _initialLocationSet = false;
  double _currentZoom = 12.0;
  LatLngBounds? _visibleRegion;

  // Constants
  static const LatLng _defaultLocation = LatLng(47.9077, 106.8832); // Ulaanbaatar
  static const double _defaultZoom = 12.0;
  static const double _closeZoom = 15.0;
  static const double _maxMarkersToShow = 100;
  static const Duration _locationTimeout = Duration(seconds: 10);
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSubscription?.cancel();
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isMapReady) {
      _refreshLocation();
    }
  }

  // Initialize map with optimizations
  Future<void> _initializeMap() async {
    await _preloadCustomIcons();
    await _initializeLocation();

    // Load accidents after a delay to prevent blocking UI
    Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        _loadAccidents();
      }
    });
  }

  // Preload custom marker icons for better performance
  Future<void> _preloadCustomIcons() async {
    try {
      _customIcons = {
        'severe': await BitmapDescriptor.fromAssetImage(
          ImageConfiguration(devicePixelRatio: 2.5),
          'assets/markers/severe_marker.png',
        ),
        'moderate': await BitmapDescriptor.fromAssetImage(
          ImageConfiguration(devicePixelRatio: 2.5),
          'assets/markers/moderate_marker.png',
        ),
        'minor': await BitmapDescriptor.fromAssetImage(
          ImageConfiguration(devicePixelRatio: 2.5),
          'assets/markers/minor_marker.png',
        ),
      };
    } catch (e) {
      // Fallback to default markers if custom icons fail
      print('Failed to load custom icons: $e');
      _customIcons = {
        'severe': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        'moderate': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        'minor': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      };
    }
  }

  // Optimized location initialization
  Future<void> _initializeLocation() async {
    try {
      _isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!_isLocationServiceEnabled) {
        _showLocationMessage('Location services disabled. Using default location.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationMessage('Location permission required for better experience.');
        return;
      }

      await _getCurrentLocationOptimized();
      _startLocationStream();

    } catch (e) {
      print('Location initialization error: $e');
      _showLocationMessage('Location error. Using default location.');
    }
  }

  // Optimized location fetching with timeout and accuracy settings
  Future<void> _getCurrentLocationOptimized() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Good balance of accuracy and performance
        timeLimit: _locationTimeout,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });

        if (_isMapReady && !_initialLocationSet) {
          _moveToLocation(LatLng(position.latitude, position.longitude));
          _initialLocationSet = true;
        }
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  // Location stream for real-time updates (optimized)
  void _startLocationStream() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium, // Good balance of accuracy and battery
        distanceFilter: 50, // Update only if moved 50+ meters
      ),
    ).listen(
          (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
      onError: (e) => print('Location stream error: $e'),
    );
  }

  // Optimized accident loading with clustering
  void _loadAccidents() {
    final provider = Provider.of<AccidentProvider>(context, listen: false);
    provider.loadAccidents().then((_) {
      if (mounted && _isMapReady) {
        _updateMarkersOptimized(provider.accidents);
      }
    });
  }

  // Optimized marker creation with clustering and viewport filtering
  void _updateMarkersOptimized(List<Accident> accidents) {
    if (!_isMapReady || accidents.isEmpty) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      _createOptimizedMarkers(accidents);
    });
  }

  void _createOptimizedMarkers(List<Accident> accidents) {
    if (!mounted) return;

    // Filter accidents by viewport if available
    List<Accident> visibleAccidents = accidents;
    if (_visibleRegion != null) {
      visibleAccidents = accidents.where((accident) {
        final lat = accident.latitude;
        final lng = accident.longitude;
        return lat >= _visibleRegion!.southwest.latitude &&
            lat <= _visibleRegion!.northeast.latitude &&
            lng >= _visibleRegion!.southwest.longitude &&
            lng <= _visibleRegion!.northeast.longitude;
      }).toList();
    }

    // Limit markers for performance
    if (visibleAccidents.length > _maxMarkersToShow) {
      visibleAccidents = _prioritizeAccidents(visibleAccidents);
    }

    // Cluster markers if zoomed out
    if (_currentZoom < 13.0) {
      _createClusteredMarkers(visibleAccidents);
    } else {
      _createIndividualMarkers(visibleAccidents);
    }

    _cachedAccidents = List.from(accidents);
  }

  // Prioritize accidents by severity and recency
  List<Accident> _prioritizeAccidents(List<Accident> accidents) {
    accidents.sort((a, b) {
      // Sort by severity first, then by timestamp
      final severityComparison = _getSeverityPriority(b.severity) - _getSeverityPriority(a.severity);
      if (severityComparison != 0) return severityComparison;
      return b.timestamp.compareTo(a.timestamp);
    });

    return accidents.take(_maxMarkersToShow.toInt()).toList();
  }

  int _getSeverityPriority(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe: return 3;
      case AccidentSeverity.moderate: return 2;
      case AccidentSeverity.minor: return 1;
    }
  }

  // Create clustered markers for better performance at low zoom levels
  void _createClusteredMarkers(List<Accident> accidents) {
    Map<String, List<Accident>> clusters = {};

    // Group accidents by approximate location (clustering)
    for (final accident in accidents) {
      final clusterKey = '${(accident.latitude * 100).round()}_${(accident.longitude * 100).round()}';
      clusters[clusterKey] = (clusters[clusterKey] ?? [])..add(accident);
    }

    Set<Marker> newMarkers = {};
    Set<Circle> newCircles = {};

    clusters.forEach((key, clusterAccidents) {
      if (clusterAccidents.length == 1) {
        // Single accident
        newMarkers.add(_createMarker(clusterAccidents.first));
      } else {
        // Multiple accidents - create cluster marker
        final centerLat = clusterAccidents.map((a) => a.latitude).reduce((a, b) => a + b) / clusterAccidents.length;
        final centerLng = clusterAccidents.map((a) => a.longitude).reduce((a, b) => a + b) / clusterAccidents.length;

        newMarkers.add(
          Marker(
            markerId: MarkerId('cluster_$key'),
            position: LatLng(centerLat, centerLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: 'Accident Cluster',
              snippet: '${clusterAccidents.length} accidents',
              onTap: () => _showClusterDetails(clusterAccidents),
            ),
          ),
        );

        // Add circle to show cluster area
        newCircles.add(
          Circle(
            circleId: CircleId('cluster_circle_$key'),
            center: LatLng(centerLat, centerLng),
            radius: 200,
            fillColor: Colors.blue.withOpacity(0.1),
            strokeColor: Colors.blue.withOpacity(0.3),
            strokeWidth: 1,
          ),
        );
      }
    });

    setState(() {
      _markers = newMarkers;
      _circles = newCircles;
    });
  }

  // Create individual markers for high zoom levels
  void _createIndividualMarkers(List<Accident> accidents) {
    Set<Marker> newMarkers = {};

    for (final accident in accidents) {
      newMarkers.add(_createMarker(accident));
    }

    setState(() {
      _markers = newMarkers;
      _circles = {};
    });
  }

  // Optimized marker creation
  Marker _createMarker(Accident accident) {
    return Marker(
      markerId: MarkerId('accident_${accident.id}'),
      position: LatLng(accident.latitude, accident.longitude),
      icon: _getOptimizedMarkerIcon(accident.severity),
      infoWindow: InfoWindow(
        title: 'Accident ${accident.id}',
        snippet: '${_severityToString(accident.severity)} - ${_formatTime(accident.timestamp)}',
        onTap: () => _showAccidentDetails(accident),
      ),
      onTap: () => _onMarkerTapped(accident),
    );
  }

  BitmapDescriptor _getOptimizedMarkerIcon(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe:
        return _customIcons['severe'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case AccidentSeverity.moderate:
        return _customIcons['moderate'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case AccidentSeverity.minor:
        return _customIcons['minor'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
  }

  // Optimized map creation callback
  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
    _mapController = controller;
    _isMapReady = true;

    // Apply initial camera position if we have location
    if (_currentPosition != null && !_initialLocationSet) {
      _moveToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      _initialLocationSet = true;
    }

    // Load accidents after map is ready
    Timer(Duration(milliseconds: 300), () {
      if (mounted) {
        _loadAccidents();
      }
    });
  }

  // Optimized camera move handling
  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
  }

  void _onCameraIdle() async {
    if (_mapController != null) {
      _visibleRegion = await _mapController!.getVisibleRegion();
      // Refresh markers if zoom level changed significantly
      _refreshMarkersIfNeeded();
    }
  }

  void _refreshMarkersIfNeeded() {
    final provider = Provider.of<AccidentProvider>(context, listen: false);
    if (provider.accidents.isNotEmpty &&
        !provider.isLoading &&
        _cachedAccidents.isNotEmpty) {
      _updateMarkersOptimized(provider.accidents);
    }
  }

  // Optimized location movement
  void _moveToLocation(LatLng location, {double? zoom}) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: zoom ?? _closeZoom,
          ),
        ),
      );
    }
  }

  // Refresh current location
  void _refreshLocation() {
    _getCurrentLocationOptimized();
  }

  // Move to user's current location
  void _moveToCurrentLocation() {
    if (_currentPosition != null) {
      _moveToLocation(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
    } else {
      _getCurrentLocationOptimized().then((_) {
        if (_currentPosition != null) {
          _moveToLocation(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          );
        }
      });
    }
  }

  // Event handlers
  void _onMarkerTapped(Accident accident) {
    // Optional: Add haptic feedback or sound
    // HapticFeedback.lightImpact();
  }

  void _showLocationMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showClusterDetails(List<Accident> accidents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '${accidents.length} Accidents in This Area',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: accidents.length,
                    itemBuilder: (context, index) {
                      final accident = accidents[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getSeverityColor(accident.severity),
                          child: Icon(Icons.warning, color: Colors.white, size: 16),
                          radius: 16,
                        ),
                        title: Text('Accident ${accident.id}'),
                        subtitle: Text('${_severityToString(accident.severity)} - ${_formatTime(accident.timestamp)}'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _showAccidentDetails(accident);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAccidentDetails(Accident accident) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                        'Accident ${accident.id}',
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
                      _buildDetailCard('Severity', _severityToString(accident.severity)),
                      _buildDetailCard('Status', _statusToString(accident.status)),
                      _buildDetailCard('Date', _formatDate(accident.timestamp)),
                      _buildDetailCard('Time', _formatTime(accident.timestamp)),
                      _buildDetailCard('Location', '${accident.latitude.toStringAsFixed(6)}, ${accident.longitude.toStringAsFixed(6)}'),
                      _buildDetailCard('Reported By', accident.reportedBy),
                      if (accident.description.isNotEmpty)
                        _buildDetailCard('Description', accident.description),

                      // Image
                      if (accident.imageUrl.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text('Evidence Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            accident.imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _moveToLocation(LatLng(accident.latitude, accident.longitude));
                        },
                        icon: Icon(Icons.location_on),
                        label: Text('Show on Map'),
                      ),
                    ),
                    if (accident.status != AccidentStatus.resolved) ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateAccidentStatus(accident);
                          },
                          icon: Icon(Icons.edit),
                          label: Text('Update'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _updateAccidentStatus(Accident accident) {
    showDialog(
      context: context,
      builder: (context) {
        AccidentStatus selectedStatus = accident.status;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Update Accident Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: AccidentStatus.values.map((status) {
                  return RadioListTile<AccidentStatus>(
                    title: Text(_statusToString(status)),
                    value: status,
                    groupValue: selectedStatus,
                    onChanged: (AccidentStatus? value) {
                      setDialogState(() {
                        selectedStatus = value!;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update accident status through provider
                    final provider = Provider.of<AccidentProvider>(context, listen: false);
                    // provider.updateAccidentStatus(accident.id, selectedStatus);
                    Navigator.pop(context);
                    _showLocationMessage('Status updated to ${_statusToString(selectedStatus)}');
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Utility methods
  Color _getSeverityColor(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe: return Colors.red;
      case AccidentSeverity.moderate: return Colors.orange;
      case AccidentSeverity.minor: return Colors.yellow[700]!;
    }
  }

  String _severityToString(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe: return 'Severe';
      case AccidentSeverity.moderate: return 'Moderate';
      case AccidentSeverity.minor: return 'Minor';
    }
  }

  String _statusToString(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported: return 'Reported';
      case AccidentStatus.confirmed: return 'Confirmed';
      case AccidentStatus.resolved: return 'Resolved';
      case AccidentStatus.falseAlarm: return 'False Alarm';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: Text('Accident Map'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
            tooltip: 'My Location',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAccidents,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'traffic':
                // Toggle traffic layer
                  break;
                case 'satellite':
                // Toggle map type
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'traffic', child: Text('Toggle Traffic')),
              PopupMenuItem(value: 'satellite', child: Text('Satellite View')),
            ],
          ),
        ],
      ),
      body: Consumer<AccidentProvider>(
        builder: (context, provider, child) {
          // Auto-update markers when accidents change
          if (!provider.isLoading &&
              provider.accidents.isNotEmpty &&
              _isMapReady &&
              !_listEquals(_cachedAccidents, provider.accidents)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMarkersOptimized(provider.accidents);
            });
          }

          return Stack(
            children: [
              // Main map
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : _defaultLocation,
                  zoom: _defaultZoom,
                ),
                markers: _markers,
                circles: _circles,
                myLocationEnabled: _isLocationServiceEnabled,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: true,
                trafficEnabled: false,
                buildingsEnabled: false,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                mapType: MapType.normal,
              ),

              // Loading overlay
              if (provider.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black12,
                    child: Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(strokeWidth: 3),
                              SizedBox(height: 16),
                              Text('Loading accidents...', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Statistics panel
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          '${provider.accidents.length}',
                          'Total',
                          Icons.warning,
                          Colors.grey[600]!,
                        ),
                        _buildStatColumn(
                          '${_markers.length}',
                          'Visible',
                          Icons.visibility,
                          Colors.blue,
                        ),
                        _buildStatColumn(
                          '${provider.accidents.where((a) => a.severity == AccidentSeverity.severe).length}',
                          'Severe',
                          Icons.circle,
                          Colors.red,
                        ),
                        _buildStatColumn(
                          '${provider.accidents.where((a) => a.severity == AccidentSeverity.moderate).length}',
                          'Moderate',
                          Icons.circle,
                          Colors.orange,
                        ),
                        _buildStatColumn(
                          '${provider.accidents.where((a) => a.severity == AccidentSeverity.minor).length}',
                          'Minor',
                          Icons.circle,
                          Colors.yellow[700]!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Zoom info (debug mode)
              if (false) // Set to true for debugging
                Positioned(
                  bottom: 100,
                  left: 16,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Zoom: ${_currentZoom.toStringAsFixed(1)}'),
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
          // My location button
          FloatingActionButton(
            heroTag: "location",
            onPressed: _moveToCurrentLocation,
            child: Icon(Icons.my_location),
            mini: true,
            backgroundColor: Colors.blue,
            tooltip: 'Go to my location',
          ),
          SizedBox(height: 12),

          // Refresh button
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _loadAccidents,
            child: Icon(Icons.refresh),
            backgroundColor: Colors.green,
            tooltip: 'Refresh accidents',
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Helper function to compare lists
  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}