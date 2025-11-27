import 'package:flutter/material.dart';
import '../models/submission.dart';
import '../services/auth_service.dart';
import '../services/submission_service.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  final SubmissionService _submissionService = SubmissionService();
  bool _isInitialized = false;
  List<Submission> _submissions = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    final token = await _authService.getAccessToken();
    final user = await _authService.getUser();

    if (token == null || user == null) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📝 Нэвтрэх шаардлагатай'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });

      await _loadSubmissions();
    }
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final submissions = await _submissionService.getUserSubmissions();
      if (mounted) {
        setState(() {
          _submissions = submissions;
          _isLoading = false;
        });
      }
      print('✅ Loaded ${submissions.length} submissions');
    } catch (e) {
      print('❌ Load submissions error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Түүх'),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Эхлүүлж байна...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Түүх'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Шинэчлэх',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ачааллаж байна...'),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Алдаа гарлаа',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: Icon(Icons.refresh),
                label: Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      );
    }

    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Түүх хоосон байна', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Та илгээсэн мэдээлэл одоогоор байхгүй байна',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _submissions.length,
        itemBuilder: (context, index) {
          final submission = _submissions[index];
          return _buildSubmissionCard(context, submission);
        },
      ),
    );
  }

  Widget _buildSubmissionCard(BuildContext context, Submission submission) {
    final statusColor = _getSubmissionStatusColor(submission.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSubmissionDetails(context, submission),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, color: statusColor, size: 20),
                  ),
                  SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Илгээсэн зураг',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          submission.statusMongolian,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (submission.isRejected)
                    Icon(Icons.cancel, color: Colors.red, size: 24),
                ],
              ),

              SizedBox(height: 12),

              if (submission.description.isNotEmpty) ...[
                Text(
                  submission.description,
                  style: TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
              ],

              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    _formatDateTime(submission.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  submission.statusMongolian,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmissionDetails(BuildContext context, Submission submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(
                        Icons.image,
                        color: _getSubmissionStatusColor(submission.status),
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Илгээсэн зураг',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${submission.id}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  if (submission.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        submission.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Зураг ачаалагдсангүй',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  _buildDetailRow(
                    'Төлөв',
                    submission.statusMongolian,
                    Icons.info,
                    _getSubmissionStatusColor(submission.status),
                  ),
                  _buildDetailRow(
                    'Огноо цаг',
                    _formatDateTime(submission.createdAt),
                    Icons.access_time,
                    Colors.grey[700]!,
                  ),
                  _buildDetailRow(
                    'Байршил',
                    '${submission.latitude.toStringAsFixed(6)}, ${submission.longitude.toStringAsFixed(6)}',
                    Icons.location_on,
                    Colors.red,
                  ),

                  if (submission.description.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Тайлбар:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      submission.description,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],

                  if (submission.errorMessage != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              submission.errorMessage!,
                              style: TextStyle(color: Colors.red[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Хаах'),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    // Backend-ээс Монголын цагаар (UTC+8) ирсэн байна
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getSubmissionStatusColor(String status) {
    switch (status) {
      case 'analyzing':
        return Colors.orange;
      case 'accident_created':
        return Colors.green;
      case 'not_accident':
        return Colors.grey;
      case 'error':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
