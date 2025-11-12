import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _videoPath;
  VideoPlayerController? _videoPlayerController;
  bool _isUploading = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        _showError('Камер олдсонгүй');
        return;
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Камер эхлүүлэхэд алдаа гарлаа: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Түр хавтас үүсгэх
      final Directory tempDir = await getTemporaryDirectory();
      final String videoPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';

      await _cameraController!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _videoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бичлэг эхэллээ'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      _showError('Бичлэг эхлүүлэхэд алдаа гарлаа: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();

      setState(() {
        _isRecording = false;
        _videoPath = videoFile.path;
      });

      // Video preview эхлүүлэх
      _videoPlayerController = VideoPlayerController.file(File(_videoPath!));
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setLooping(true);
      await _videoPlayerController!.play();

      setState(() {});

    } catch (e) {
      _showError('Бичлэг зогсоохоо алдаа гарлаа: $e');
    }
  }

  Future<void> _sendVideo() async {
    if (_videoPath == null) return;

    setState(() => _isUploading = true);

    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        _showError('Нэвтэрсэн байх шаардлагатай');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}/videos/upload'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('video', _videoPath!));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Бичлэг амжилттай илгээгдсэн - устгах
        await _deleteVideoFile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бичлэг амжилттай илгээгдлээ'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        _showError('Бичлэг илгээхэд алдаа гарлаа');
      }
    } catch (e) {
      _showError('Серверт холбогдож чадсангүй: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteVideo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бичлэг устгах'),
        content: const Text('Та бичлэгээ устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Үгүй'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Тийм'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteVideoFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бичлэг устгагдлаа')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _deleteVideoFile() async {
    if (_videoPath != null) {
      try {
        final file = File(_videoPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
        setState(() => _videoPath = null);
      } catch (e) {
        print('Файл устгахад алдаа: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera эсвэл Video preview
            if (_videoPath == null)
              _buildCameraPreview()
            else
              _buildVideoPreview(),

            // Устгах товч (баруун дээд булан)
            if (_videoPath != null)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: _deleteVideo,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

            // Доод хэсгийн удирдлага
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _videoPath == null
                  ? _buildRecordingControls()
                  : _buildVideoControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _cameraController!.value.aspectRatio,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: VideoPlayer(_videoPlayerController!),
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Буцах
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
          ),

          // Бичих/Зогсоох товч
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.white,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
              child: _isRecording
                  ? const Icon(Icons.stop, color: Colors.white, size: 40)
                  : null,
            ),
          ),

          const SizedBox(width: 48), // Placeholder
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Дахин бичих
          ElevatedButton.icon(
            onPressed: () async {
              await _deleteVideoFile();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Дахин бичих'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),

          // Илгээх товч
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _sendVideo,
            icon: _isUploading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.send),
            label: Text(_isUploading ? 'Илгээж байна...' : 'Илгээх'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}