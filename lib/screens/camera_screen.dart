<<<<<<< HEAD
// lib/screens/camera_screen.dart - ВИДЕО БИЧЛЭГТЭЙ
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import '../providers/accident_provider.dart';
import '../models/accident.dart';
=======
// lib/screens/camera_screen.dart - IMPROVED WITH BETTER ERROR HANDLING
// 🇲🇳 КАМЕР ХУУДАС - Алдаа засварласан хувилбар

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
<<<<<<< HEAD
  bool _isRecording = false;
  String? _error;
  bool _permissionDenied = false;

  // Video recording
  String? _videoPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
=======
  bool _isMonitoring = false;
  String? _error;
  bool _permissionDenied = false;
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7

  @override
  void initState() {
    super.initState();
    _initializeCameraWithTimeout();
  }

<<<<<<< HEAD
=======
  // ✅ Timeout-тэй камер эхлүүлэх (5 секунд)
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
  Future<void> _initializeCameraWithTimeout() async {
    try {
      await _initializeCamera().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          if (mounted) {
<<<<<<< HEAD
            setState(() => _error = 'Камер эхлүүлэх хугацаа дууслаа');
          }
          throw TimeoutException('Camera timeout');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Камер эхлүүлэхэд алдаа: $e');
=======
            setState(() {
              _error = 'Камер эхлүүлэх хугацаа дууслаа. Дахин оролдоно уу.';
            });
          }
          throw TimeoutException('Camera initialization timeout');
        },
      );
    } on TimeoutException catch (e) {
      print('⏱️ Камер эхлүүлэх timeout: $e');
      if (mounted) {
        setState(() {
          _error = 'Камер эхлүүлэх хугацаа дууслаа';
        });
      }
    } catch (e) {
      print('❌ Камер эхлүүлэхэд алдаа: $e');
      if (mounted) {
        setState(() {
          _error = 'Камер эхлүүлэхэд алдаа гарлаа: $e';
        });
      }
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
    }
  }

  Future<void> _initializeCamera() async {
    print('📷 Камер эхлүүлж байна...');

    // 1. Зөвшөөрөл шалгах
    final permission = await Permission.camera.request();
<<<<<<< HEAD
    if (permission != PermissionStatus.granted) {
      if (mounted) setState(() {
        _permissionDenied = true;
        _error = 'Камерын зөвшөөрөл олгогдоогүй';
      });
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
    if (mounted) setState(() {
      _isInitialized = true;
      _error = null;
    });
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized || _cameraController == null) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _recordingSeconds++);
      });
=======
    print('📷 Камерын зөвшөөрөл: $permission');

    if (permission != PermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _error = 'Камерын зөвшөөрөл олгогдоогүй';
        });
      }
      return;
    }

    // 2. Камернуудыг олох
    try {
      print('📷 Камернуудыг хайж байна...');
      _cameras = await availableCameras();
      print('📷 Олдсон камернууд: ${_cameras?.length ?? 0}');

      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'Камер олдсонгүй';
          });
        }
        return;
      }

      // 3. Камер controller үүсгэх
      print('📷 Камер controller үүсгэж байна...');
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      // 4. Камер эхлүүлэх
      print('📷 Камер эхлүүлж байна...');
      await _cameraController!.initialize();
      print('✅ Камер амжилттай эхэллээ');

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e) {
      print('❌ Камер эхлүүлэхэд алдаа: $e');
      if (mounted) {
        setState(() {
          _error = 'Камер эхлүүлэхэд алдаа гарлаа: $e';
        });
      }
    }
  }

  // ✅ Камер дахин эхлүүлэх
  Future<void> _retryInitialization() async {
    if (mounted) {
      setState(() {
        _error = null;
        _isInitialized = false;
        _permissionDenied = false;
      });
    }
    await _initializeCameraWithTimeout();
  }

  void _toggleMonitoring() {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Камер эхлэхийг хүлээнэ үү'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isMonitoring = !_isMonitoring;
    });
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бичлэг эхэллээ'), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бичлэг эхлэхэд алдаа: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final video = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = video.path;
      });

      _showVideoPreview();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бичлэг зогсоохд алдаа: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showVideoPreview() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    );
  }

  void _deleteVideo() {
    if (_videoPath != null) {
      try {
        File(_videoPath!).deleteSync();
        setState(() => _videoPath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Бичлэг устгагдлаа'), backgroundColor: Colors.orange),
        );
      } catch (e) {
        print('Delete error: $e');
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoPath == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Бичлэг илгээж байна...'),
          ],
        ),
      ),
    );

    try {
      final provider = Provider.of<AccidentProvider>(context, listen: false);

      // Get current location (you need to implement this)
      // For now using dummy coordinates
      final accident = await provider.reportAccident(
        latitude: 47.9184,
        longitude: 106.9177,
        description: 'Камераас бичигдсэн осол',
        severity: AccidentSeverity.moderate,
        videoFile: File(_videoPath!),
      );

      _deleteVideo(); // Delete after successful upload

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ослын мэдээлэл амжилттай илгээгдлээ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Илгээхэд алдаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

<<<<<<< HEAD
  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
=======
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Камерын зөвшөөрөл шаардлагатай'),
        content: const Text(
          'Энэ апп нь осол илрүүлэхийн тулд камерын зөвшөөрөл хэрэгтэй. '
              'Тохиргооноос зөвшөөрөл өгнө үү.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Тохиргоо нээх'),
          ),
        ],
      ),
    );
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    if (_videoPath != null) _deleteVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Осол Илрүүлэлт'),
        backgroundColor: Colors.blue,
<<<<<<< HEAD
=======
        actions: [
          if (_isMonitoring)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'АЖИЛЛАЖ БАЙНА',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          // Debug info button
          if (_error != null)
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Алдааны мэдээлэл'),
                    content: Text(_error ?? 'Тодорхойгүй алдаа'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Хаах'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
<<<<<<< HEAD
=======
    // ✅ Permission denied state
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 80, color: Colors.red),
              SizedBox(height: 24),
<<<<<<< HEAD
              Text('Камерын зөвшөөрөл хэрэгтэй', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                icon: Icon(Icons.settings),
                label: Text('Тохиргоо нээх'),
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
              Text('Алдаа гарлаа', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeCameraWithTimeout,
=======
              Text(
                'Камерын зөвшөөрөл хэрэгтэй',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'AI осол илрүүлэхийн тулд камер ашиглах зөвшөөрөл өгнө үү.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showPermissionDialog,
                icon: Icon(Icons.settings),
                label: Text('Тохиргоо нээх'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 12),
              TextButton.icon(
                onPressed: _retryInitialization,
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
                icon: Icon(Icons.refresh),
                label: Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      );
    }

<<<<<<< HEAD
=======
    // ✅ Error state
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
              Text(
                _error!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                icon: Icon(Icons.refresh),
                label: Text('Дахин оролдох'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              if (_permissionDenied) ...[
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    openAppSettings();
                  },
                  icon: Icon(Icons.settings),
                  label: Text('Тохиргоо нээх'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // ✅ Loading state
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Камер эхлүүлж байна...'),
            SizedBox(height: 24),
            Text(
              'Хэтэрхий удаж байвал "Дахин оролдох" дарна уу',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            TextButton.icon(
              onPressed: _retryInitialization,
              icon: Icon(Icons.refresh),
              label: Text('Дахин оролдох'),
            ),
          ],
        ),
      );
    }

    // ✅ Camera preview (success state)
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_cameraController!)),

        // Recording indicator
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

<<<<<<< HEAD
        // Close button (X)
        if (_videoPath != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
=======
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _toggleMonitoring,
                icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                label: Text(_isMonitoring ? 'Зогсоох' : 'Эхлүүлэх'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
>>>>>>> 8a7fc3c07c949b63f557bdca610ef8b8c44abfd7
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  _deleteVideo();
                },
              ),
            ),
          ),

        // Record button
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