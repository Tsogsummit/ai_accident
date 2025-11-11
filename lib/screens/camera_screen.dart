// lib/screens/camera_screen.dart - IMPROVED WITH BETTER ERROR HANDLING
// 🇲🇳 КАМЕР ХУУДАС - Алдаа засварласан хувилбар

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initializeCameraWithTimeout();
  }

  // ✅ Timeout-тэй камер эхлүүлэх (5 секунд)
  Future<void> _initializeCameraWithTimeout() async {
    try {
      await _initializeCamera().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          if (mounted) {
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
    }
  }

  Future<void> _initializeCamera() async {
    print('📷 Камер эхлүүлж байна...');

    // 1. Зөвшөөрөл шалгах
    final permission = await Permission.camera.request();
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

    if (_isMonitoring) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI хяналт эхэллээ - Ослыг хайж байна'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI хяналт зогслоо'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

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
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Осол Илрүүлэлт'),
        backgroundColor: Colors.blue,
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
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ✅ Permission denied state
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
                icon: Icon(Icons.refresh),
                label: Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      );
    }

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
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isMonitoring ? Icons.visibility : Icons.visibility_off,
                      color: _isMonitoring ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMonitoring
                          ? 'AI хяналт идэвхтэй'
                          : 'AI хяналт идэвхгүй',
                      style: TextStyle(
                        color: _isMonitoring ? Colors.green : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isMonitoring)
                      const Text(
                        'Ослыг хайж байна...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),

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
              ),
            ],
          ),
        ),
      ],
    );
  }
}