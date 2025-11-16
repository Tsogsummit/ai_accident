// lib/screens/camera_screen.dart - FIXED WITH BETTER ERROR HANDLING
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';
import '../providers/accident_provider.dart';
import '../models/accident.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _error;
  bool _permissionDenied = false;

  String? _videoPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  Position? _currentPosition;
  bool _isScreenActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraWithTimeout();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _isScreenActive = false;
      if (_isRecording) {
        print('⚠️ App inactive - stopping recording');
        _stopRecording();
      }
    } else if (state == AppLifecycleState.resumed) {
      _isScreenActive = true;
    }
  }

  void _cleanupResources() {
    print('🧹 Cleaning up camera resources...');
    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    if (_cameraController != null) {
      if (_isRecording) {
        try {
          _cameraController!.stopVideoRecording();
        } catch (e) {
          print('⚠️ Error stopping recording during cleanup: $e');
        }
      }
      _cameraController?.dispose();
      _cameraController = null;
    }
    
    if (_videoPath != null) {
      _deleteVideo();
    }
    
    print('✅ Cleanup complete');
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Байршлын үйлчилгээ идэвхгүй байна');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⚠️ Байршлын зөвшөөрөл олгогдоогүй');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      print('✅ Байршил авагдлаа: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    } catch (e) {
      print('❌ Байршил авахад алдаа: $e');
    }
  }

  Future<void> _initializeCameraWithTimeout() async {
    try {
      await _initializeCamera().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          if (mounted) {
            setState(() => _error = 'Камер эхлүүлэх хугацаа дууслаа');
          }
          throw TimeoutException('Camera timeout');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Камер эхлүүлэхэд алдаа: $e');
    }
  }

  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.request();
    if (permission != PermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _error = 'Камерын зөвшөөрөл олгогдоогүй';
        });
      }
      return;
    }

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      if (mounted) setState(() => _error = 'Камер олдсонгүй');
      return;
    }

    _cameraController = CameraController(
      _cameras![0],
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _error = null;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized || _cameraController == null) return;
    if (!_isScreenActive) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!_isScreenActive) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          setState(() => _recordingSeconds++);
        } else {
          timer.cancel();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔴 Бичлэг эхэллээ'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Start recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Бичлэг эхлэхэд алдаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _cameraController == null) return;

    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      final video = await _cameraController!.stopVideoRecording();
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _videoPath = video.path;
        });

        print('✅ Бичлэг хадгалагдлаа: $_videoPath');
        _showVideoPreview();
      }
    } catch (e) {
      print('❌ Stop recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Бичлэг зогсоохд алдаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVideoPreview() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, size: 48, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Бичлэг бэлэн',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Хугацаа: ${_formatDuration(_recordingSeconds)}'),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _deleteVideo();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.delete, color: Colors.red),
                      label: Text('Устгах', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadVideo();
                      },
                      icon: Icon(Icons.upload),
                      label: Text('Илгээх'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteVideo() {
    if (_videoPath != null) {
      try {
        File(_videoPath!).deleteSync();
        setState(() => _videoPath = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Бичлэг устгагдлаа'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print('❌ Файл устгахад алдаа: $e');
      }
    }
  }

  // ✅✅✅ FIXED: Better error handling and logging
  Future<void> _uploadVideo() async {
    if (_videoPath == null) {
      print('❌ Video path null байна');
      _showErrorDialog('Видео файл олдсонгүй');
      return;
    }

    // Check if file exists
    final videoFile = File(_videoPath!);
    if (!await videoFile.exists()) {
      print('❌ Video файл байхгүй: $_videoPath');
      _showErrorDialog('Видео файл олдсонгүй');
      return;
    }

    print('✅ Video файл олдлоо: $_videoPath');
    print('   Size: ${await videoFile.length()} bytes');

    // Get location
    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) {
        print('⚠️ Using default location');
        _currentPosition = Position(
          latitude: 47.9184,
          longitude: 106.9177,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    }

    print('📍 Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Consumer<AccidentProvider>(
          builder: (context, provider, child) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: provider.isUploading ? provider.uploadProgress : null,
                  ),
                  SizedBox(height: 16),
                  Text(
                    provider.isUploading
                        ? 'Илгээж байна... ${(provider.uploadProgress * 100).toStringAsFixed(0)}%'
                        : 'Бэлтгэж байна...',
                  ),
                  if (provider.isUploading) ...[
                    SizedBox(height: 8),
                    Text(
                      '${(provider.uploadProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    try {
      print('📤 Starting upload...');
      
      final provider = Provider.of<AccidentProvider>(context, listen: false);

      final result = await provider.uploadVideoAccident(
        videoFile: videoFile,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        description: 'Камераас бичигдсэн осол (${_formatDuration(_recordingSeconds)})',
      );

      print('✅ Upload result: $result');

      _deleteVideo(); // Delete after successful upload

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✅ Видео амжилттай илгээгдлээ'),
                      Text(
                        'AccidentId: ${result['accidentId']}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        throw Exception('Видео илгээлт амжилтгүй');
      }
    } catch (e, stackTrace) {
      print('❌ Video upload error: $e');
      print('❌ Stack trace: $stackTrace');
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      _showErrorDialog('Видео илгээхэд алдаа гарлаа:\n\n$e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text('Алдаа'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Хаах'),
          ),
          if (_videoPath != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _uploadVideo(); // Retry
              },
              child: Text('Дахин оролдох'),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRecording) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Бичлэг зогсоох уу?'),
              content: Text('Бичлэг хийгдэж байна. Буцах бол бичлэг зогсоно.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Үгүй'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _stopRecording();
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('Зогсоох'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('AI Осол Илрүүлэлт'),
          backgroundColor: Colors.blue,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 80, color: Colors.red),
              SizedBox(height: 24),
              Text(
                'Камерын зөвшөөрөл хэрэгтэй',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Осол бичлэг хийхийн тулд камерын зөвшөөрөл өгнө үү',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                icon: Icon(Icons.settings),
                label: Text('Тохиргоо нээх'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && !_isInitialized) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 24),
              Text(
                'Алдаа гарлаа',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeCameraWithTimeout,
                icon: Icon(Icons.refresh),
                label: Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Камер эхлүүлж байна...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_cameraController!)),

        if (_isRecording)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingSeconds),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.white,
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: _isRecording
                    ? Icon(Icons.stop, color: Colors.white, size: 40)
                    : Icon(Icons.videocam, color: Colors.red, size: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}