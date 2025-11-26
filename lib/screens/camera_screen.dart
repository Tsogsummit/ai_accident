import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/auth_service.dart';

import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../providers/accident_provider.dart';

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
  String? _error;
  bool _permissionDenied = false;

  String? _imagePath;
  Position? _currentPosition;

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

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
  }

  void _cleanupResources() {
    print(' Cleaning up camera resources...');

    if (_cameraController != null) {
      _cameraController?.dispose();
      _cameraController = null;
    }

    print(' Cleanup complete');
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print(' Байршлын үйлчилгээ идэвхгүй байна');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print(' Байршлын зөвшөөрөл олгогдоогүй');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      print(
        ' Байршил авагдлаа: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
      );
    } catch (e) {
      print(' Байршил авахад алдаа: $e');
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
    var cameraStatus = await Permission.camera.request();

    if (cameraStatus.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _error =
              'Камерын зөвшөөрөл татгалзсан. Тохиргооноос зөвшөөрөл өгнө үү.';
        });
        _showPermissionDialog('Камер', 'камерын');
      }
      return;
    }

    if (!cameraStatus.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _error = 'Камерын зөвшөөрөл олгогдоогүй';
        });
      }
      return;
    }

    var microphoneStatus = await Permission.microphone.request();

    if (microphoneStatus.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _error =
              'Микрофоны зөвшөөрөл татгалзсан. Тохиргооноос зөвшөөрөл өгнө үү.';
        });
        _showPermissionDialog('Микрофон', 'микрофоны');
      }
      return;
    }

    if (!microphoneStatus.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _error = 'Микрофоны зөвшөөрөл олгогдоогүй';
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
      ResolutionPreset.medium,
      enableAudio: true,
    );

    await _cameraController!.initialize();

    _minZoom = await _cameraController!.getMinZoomLevel();
    _maxZoom = await _cameraController!.getMaxZoomLevel();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _error = null;
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _cameraController == null) return;

    try {
      final image = await _cameraController!.takePicture();

      if (mounted) {
        setState(() {
          _imagePath = image.path;
        });
        print(' Зураг дарагдлаа: $_imagePath');
        _showImagePreview();
      }
    } catch (e) {
      print(' Take picture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Зураг дарахад алдаа: $e')));
      }
    }
  }

  void _showImagePreview() {
    if (!mounted || _imagePath == null) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, size: 48, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Зураг бэлэн',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(File(_imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _deleteImage();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.delete, color: Colors.red),
                      label: Text(
                        'Устгах',
                        style: TextStyle(color: Colors.red),
                      ),
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
                        _uploadImage();
                      },
                      icon: Icon(Icons.send),
                      label: Text('Илгээх (AI)'),
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

  void _deleteImage() {
    if (_imagePath != null) {
      try {
        File(_imagePath!).deleteSync();
        setState(() => _imagePath = null);
      } catch (e) {
        print(' Файл устгахад алдаа: $e');
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imagePath == null) return;

    final imageFile = File(_imagePath!);
    if (!await imageFile.exists()) return;

    if (_currentPosition == null) {
      await _getCurrentLocation();
      _currentPosition ??= Position(
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

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI шинжилж байна...'),
          ],
        ),
      ),
    );

    try {
      final provider = Provider.of<AccidentProvider>(context, listen: false);

      File? compressedFile = await _compressImage(imageFile);
      if (compressedFile == null) {
        throw Exception('Зураг шахахад алдаа гарлаа');
      }

      final result = await provider.reportImageAccident(
        imageFile: compressedFile,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        description: 'AI Image Report',
      );

      try {
        if (compressedFile.path != imageFile.path) {
          compressedFile.deleteSync();
        }
      } catch (e) {
        print(' Failed to delete compressed file: $e');
      }

      _deleteImage();
      if (!mounted) return;
      Navigator.pop(context);

      if (result != null && result['success'] == true) {
        final data = result['data'];

        if (data != null && data['isAccident'] == false) {
          final analysis = data['analysis'];
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Осол илрээгүй'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result['message'] ?? 'Зураг шалгагдлаа'),
                  if (analysis != null) ...[
                    SizedBox(height: 12),
                    Text(
                      'AI: ${analysis['description'] ?? ''}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ОК'),
                ),
              ],
            ),
          );
        } else {
          String description = '';
          if (data is Map && data['description'] != null) {
            description = data['description'];
          } else if (result['data'] != null &&
              result['data'].description != null) {
            description = result['data'].description;
          }

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Осол бүртгэгдлээ'),
                ],
              ),
              content: Text(
                description.isNotEmpty
                    ? 'AI Хариу: $description'
                    : 'Осол амжилттай бүртгэгдлээ',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ОК'),
                ),
              ],
            ),
          );
        }
      } else {
        String errorMsg = result?['error'] ?? 'Алдаа гарлаа';

        if (result?['rateLimited'] == true) {
          final remainingMinutes = result?['remainingMinutes'] ?? 15;
          _showErrorDialog(
            ' Та хэт олон мэдээлэл илгээж байна.\n\n'
            '$remainingMinutes минутын дараа дахин оролдоно уу.',
          );
        } else if (errorMsg.contains('токен') ||
            errorMsg.contains('401') ||
            errorMsg.contains('403')) {
          _showErrorDialog(
            'Нэвтрэлтийн хугацаа дууссан байна. Дахин нэвтрэнэ үү.',
          );
        } else {
          _showErrorDialog(errorMsg);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      String errorStr = e.toString();
      String userMessage;

      if (errorStr.contains('токен') ||
          errorStr.contains('Хүчингүй') ||
          errorStr.contains('403') ||
          errorStr.contains('401')) {
        userMessage = 'Нэвтрэлтийн хугацаа дууссан. Дахин нэвтрэнэ үү.';
      } else if (errorStr.contains('Connection') ||
          errorStr.contains('timeout') ||
          errorStr.contains('сүлжээ')) {
        userMessage = 'Сүлжээний алдаа. Интернет холболтоо шалгана уу.';
      } else if (errorStr.contains('500') || errorStr.contains('сервер')) {
        userMessage = 'Серверийн алдаа. Түр хүлээгээд дахин оролдоно уу.';
      } else {
        userMessage = 'Зураг илгээхэд алдаа гарлаа. Дахин оролдоно уу.';
      }

      _showErrorDialog(userMessage);
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
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          if (message.contains('эрх') || message.contains('403'))
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                await authService.logout();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: Text('Гарах', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Хаах'),
          ),
        ],
      ),
    );
  }

  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) return file;
      return File(result.path);
    } catch (e) {
      print(' Image compression error: $e');
      return file;
    }
  }

  Future<void> _showPermissionDialog(
    String permissionName,
    String permissionNameGenitive,
  ) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName зөвшөөрөл шаардлагатай'),
        content: Text(
          '$permissionNameGenitive зөвшөөрөл татгалзсан байна. '
          'Энэхүү зөвшөөрөлгүйгээр бичлэг хийх боломжгүй. '
          'Тохиргооноос зөвшөөрөл өгөх үү?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Цуцлах'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: Text('Тохиргоо нээх'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Осол Илрүүлэлт'),
        backgroundColor: Colors.blue,
      ),
      body: _buildBody(),
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

        Positioned(
          bottom: 140,
          left: 40,
          right: 40,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.zoom_out, color: Colors.white),
                  Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.zoom_in, color: Colors.white),
                ],
              ),
              Slider(
                value: _currentZoom,
                min: _minZoom,
                max: _maxZoom,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged: (value) async {
                  setState(() => _currentZoom = value);
                  await _cameraController?.setZoomLevel(value);
                },
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.blue, width: 4),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue, size: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
