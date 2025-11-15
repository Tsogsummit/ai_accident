// lib/screens/api_test_screen.dart
// 🧪 API ТЕСТЛЭХ ХУУДАС - Service тус бүрийг шалгах

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'dart:convert';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({Key? key}) : super(key: key);

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final Map<String, TestResult> _testResults = {};
  bool _isTestingAll = false;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    ApiConfig.printServiceUrls();
  }

  // ============================================
  // ТЕСТ АЖИЛЛУУЛАХ
  // ============================================

  Future<void> _testAllServices() async {
    setState(() {
      _isTestingAll = true;
      _testResults.clear();
    });

    // Test each service
    await _testAuthService();
    await _testAccidentService();
    await _testVideoService();
    await _testAiService();
    await _testNotificationService();

    setState(() => _isTestingAll = false);
  }

  // ============================================
  // AUTH SERVICE TESTS
  // ============================================

  Future<void> _testAuthService() async {
    final tests = [
      ApiTest(
        name: 'Auth Health Check',
        url: '${ApiConfig.authServiceUrl}/health',
        method: 'GET',
      ),
      ApiTest(
        name: 'Auth Service Info',
        url: '${ApiConfig.authServiceUrl}/',
        method: 'GET',
      ),
    ];

    await _runTests('Auth Service', tests);
  }

  // ============================================
  // ACCIDENT SERVICE TESTS
  // ============================================

  Future<void> _testAccidentService() async {
    final tests = [
      ApiTest(
        name: 'Accident Health Check',
        url: '${ApiConfig.accidentServiceUrl}/health',
        method: 'GET',
      ),
      ApiTest(
        name: 'Get All Accidents',
        url: ApiConfig.accidentsEndpoint,
        method: 'GET',
      ),
      ApiTest(
        name: 'Get Statistics',
        url: ApiConfig.accidentStatisticsEndpoint,
        method: 'GET',
      ),
    ];

    await _runTests('Accident Service', tests);
  }

  // ============================================
  // VIDEO SERVICE TESTS
  // ============================================

  Future<void> _testVideoService() async {
    final tests = [
      ApiTest(
        name: 'Video Health Check',
        url: '${ApiConfig.videoServiceUrl}/health',
        method: 'GET',
      ),
      ApiTest(
        name: 'Get Videos',
        url: ApiConfig.videoListEndpoint,
        method: 'GET',
      ),
    ];

    await _runTests('Video Service', tests);
  }

  // ============================================
  // AI SERVICE TESTS
  // ============================================

  Future<void> _testAiService() async {
    final tests = [
      ApiTest(
        name: 'AI Health Check',
        url: '${ApiConfig.aiServiceUrl}/health',
        method: 'GET',
      ),
      ApiTest(
        name: 'Get AI Models',
        url: ApiConfig.aiModelsEndpoint,
        method: 'GET',
      ),
    ];

    await _runTests('AI Service', tests);
  }

  // ============================================
  // NOTIFICATION SERVICE TESTS
  // ============================================

  Future<void> _testNotificationService() async {
    final tests = [
      ApiTest(
        name: 'Notification Health Check',
        url: '${ApiConfig.notificationServiceUrl}/health',
        method: 'GET',
      ),
    ];

    await _runTests('Notification Service', tests);
  }

  // ============================================
  // RUN TESTS
  // ============================================

  Future<void> _runTests(String serviceName, List<ApiTest> tests) async {
    final results = <SingleTestResult>[];

    for (final test in tests) {
      final result = await _runSingleTest(test);
      results.add(result);
      await Future.delayed(Duration(milliseconds: 300)); // Delay between tests
    }

    setState(() {
      _testResults[serviceName] = TestResult(
        serviceName: serviceName,
        tests: results,
        timestamp: DateTime.now(),
      );
    });
  }

  Future<SingleTestResult> _runSingleTest(ApiTest test) async {
    final startTime = DateTime.now();

    try {
      final response = await _dio.request(
        test.url,
        options: Options(
          method: test.method,
          validateStatus: (status) => true, // Accept any status
        ),
      ).timeout(Duration(seconds: 5));

      final duration = DateTime.now().difference(startTime);

      return SingleTestResult(
        test: test,
        success: response.statusCode != null && response.statusCode! < 500,
        statusCode: response.statusCode ?? 0,
        responseTime: duration,
        responseData: response.data,
        error: null,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      return SingleTestResult(
        test: test,
        success: false,
        statusCode: 0,
        responseTime: duration,
        responseData: null,
        error: e.toString(),
      );
    }
  }

  // ============================================
  // UI BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🧪 API Тестлэх'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showConfigInfo,
            tooltip: 'Тохиргоо харах',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_ethernet, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Холболтын горим: ${ApiConfig.connectionMode}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'IP: ${ApiConfig.localIP}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          // Test All Button
          Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTestingAll ? null : _testAllServices,
                icon: _isTestingAll
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.play_arrow),
                label: Text(_isTestingAll ? 'Тестлэж байна...' : 'Бүх Service Тестлэх'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _testResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.science, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Тест ажиллуулаагүй байна',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _testResults.length,
                    itemBuilder: (context, index) {
                      final entry = _testResults.entries.elementAt(index);
                      return _buildServiceCard(entry.key, entry.value);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'individual',
            onPressed: _showIndividualTestDialog,
            child: Icon(Icons.filter_1),
            mini: true,
            backgroundColor: Colors.orange,
            tooltip: 'Тусад нь тестлэх',
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'clear',
            onPressed: () {
              setState(() => _testResults.clear());
            },
            child: Icon(Icons.clear_all),
            backgroundColor: Colors.red,
            tooltip: 'Цэвэрлэх',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String serviceName, TestResult result) {
    final successCount = result.tests.where((t) => t.success).length;
    final totalCount = result.tests.length;
    final isAllSuccess = successCount == totalCount;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          isAllSuccess ? Icons.check_circle : Icons.error,
          color: isAllSuccess ? Colors.green : Colors.red,
          size: 32,
        ),
        title: Text(
          serviceName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('$successCount/$totalCount амжилттай'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...result.tests.map((test) => _buildTestItem(test)),
                SizedBox(height: 8),
                Text(
                  'Тестлэсэн: ${_formatTime(result.timestamp)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItem(SingleTestResult result) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle_outline : Icons.error_outline,
                color: result.success ? Colors.green : Colors.red,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.test.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(result.statusCode),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.statusCode.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${result.test.method} ${result.test.url}',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            'Хугацаа: ${result.responseTime.inMilliseconds}ms',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          if (result.error != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Алдаа: ${result.error}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (result.responseData != null && result.success) ...[
            SizedBox(height: 8),
            InkWell(
              onTap: () => _showResponseDialog(result),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.data_object, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Response харах',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 300 && statusCode < 400) return Colors.orange;
    if (statusCode >= 400 && statusCode < 500) return Colors.red;
    if (statusCode >= 500) return Colors.purple;
    return Colors.grey;
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  void _showResponseDialog(SingleTestResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Response'),
        content: SingleChildScrollView(
          child: Text(
            JsonEncoder.withIndent('  ').convert(result.responseData),
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Хаах'),
          ),
        ],
      ),
    );
  }

  void _showConfigInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Тохиргооны мэдээлэл'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('IP хаяг', ApiConfig.localIP),
              _buildInfoRow('Горим', ApiConfig.connectionMode),
              Divider(),
              Text('Service URLs:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildInfoRow('Auth', ApiConfig.authServiceUrl),
              _buildInfoRow('Accident', ApiConfig.accidentServiceUrl),
              _buildInfoRow('Video', ApiConfig.videoServiceUrl),
              _buildInfoRow('AI', ApiConfig.aiServiceUrl),
              _buildInfoRow('Notification', ApiConfig.notificationServiceUrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Хаах'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showIndividualTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Тусад нь тестлэх'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.lock, color: Colors.blue),
              title: Text('Auth Service'),
              onTap: () {
                Navigator.pop(context);
                _testAuthService();
              },
            ),
            ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text('Accident Service'),
              onTap: () {
                Navigator.pop(context);
                _testAccidentService();
              },
            ),
            ListTile(
              leading: Icon(Icons.video_library, color: Colors.purple),
              title: Text('Video Service'),
              onTap: () {
                Navigator.pop(context);
                _testVideoService();
              },
            ),
            ListTile(
              leading: Icon(Icons.psychology, color: Colors.green),
              title: Text('AI Service'),
              onTap: () {
                Navigator.pop(context);
                _testAiService();
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: Colors.red),
              title: Text('Notification Service'),
              onTap: () {
                Navigator.pop(context);
                _testNotificationService();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

// ============================================
// DATA MODELS
// ============================================

class ApiTest {
  final String name;
  final String url;
  final String method;
  final Map<String, dynamic>? body;

  ApiTest({
    required this.name,
    required this.url,
    required this.method,
    this.body,
  });
}

class SingleTestResult {
  final ApiTest test;
  final bool success;
  final int statusCode;
  final Duration responseTime;
  final dynamic responseData;
  final String? error;

  SingleTestResult({
    required this.test,
    required this.success,
    required this.statusCode,
    required this.responseTime,
    this.responseData,
    this.error,
  });
}

class TestResult {
  final String serviceName;
  final List<SingleTestResult> tests;
  final DateTime timestamp;

  TestResult({
    required this.serviceName,
    required this.tests,
    required this.timestamp,
  });
}