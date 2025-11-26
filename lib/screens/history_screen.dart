import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accident_provider.dart';
import '../models/accident.dart';
import '../models/submission.dart';
import '../services/auth_service.dart';
import '../services/submission_service.dart';
import '../widgets/false_report_dialog.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  final SubmissionService _submissionService = SubmissionService();
  String _selectedFilter = 'all';
  bool _isInitialized = false;
  List<Submission> _submissions = [];

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
            content: Text('⚠️ Нэвтрэх шаардлагатай'),
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

      final provider = Provider.of<AccidentProvider>(context, listen: false);

      try {
        await Future.wait([
          provider.loadAccidents(userOnly: true),
          _loadSubmissions(),
        ]);
      } catch (e) {
        print('❌ Load data error: $e');
      }
    }
  }

  Future<void> _loadSubmissions() async {
    try {
      final submissions = await _submissionService.getUserSubmissions();
      if (mounted) {
        setState(() {
          _submissions = submissions;
        });
      }
      print('✅ Loaded ${submissions.length} submissions');
    } catch (e) {
      print('❌ Load submissions error: $e');
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      final provider = Provider.of<AccidentProvider>(context, listen: false);

      try {
        await Future.wait([
          provider.loadAccidents(forceRefresh: true, userOnly: true),
          _loadSubmissions(),
        ]);

        provider.clearError();
      } catch (e) {
        print('❌ Refresh error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 

    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ослын түүх'),
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
        title: const Text('Ослын түүх'),
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedFilter,
            icon: Icon(Icons.filter_list),
            tooltip: 'Шүүх',
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20),
                    SizedBox(width: 8),
                    Text('Бүгд'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'accidents',
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 20),
                    SizedBox(width: 8),
                    Text('Баталгаажсан ослууд'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'submissions',
                child: Row(
                  children: [
                    Icon(Icons.image, size: 20),
                    SizedBox(width: 8),
                    Text('Миний илгээсэн'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Шинэчлэх',
          ),
        ],
      ),
      body: Consumer<AccidentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ачаалж байна...'),
                ],
              ),
            );
          }

          if (provider.error.isNotEmpty) {
            final errorLower = provider.error.toLowerCase();
            
            if (errorLower.contains('нэвтрэх') || 
                errorLower.contains('эрх дууссан') ||
                errorLower.contains('unauthorized') ||
                errorLower.contains('401')) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 64, color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'Нэвтрэх эрх дууссан',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Та дахин нэвтрэх шаардлагатай',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _authService.logout();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: Icon(Icons.login),
                        label: Text('Дахин нэвтрэх'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Алдаа гарлаа', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      provider.error,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshData,
                    icon: Icon(Icons.refresh),
                    label: Text('Дахин оролдох'),
                  ),
                ],
              ),
            );
          }

          List<dynamic> items = [];

          if (_selectedFilter == 'all' || _selectedFilter == 'accidents') {
            items.addAll(provider.allAccidents);
          }

          if (_selectedFilter == 'all' || _selectedFilter == 'submissions') {
            items.addAll(_submissions);
          }

          items.sort((a, b) {
            DateTime aTime = a is Accident ? a.timestamp : (a as Submission).createdAt;
            DateTime bTime = b is Accident ? b.timestamp : (b as Submission).createdAt;
            return bTime.compareTo(aTime);
          });

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Түүх хоосон байна', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Мэдээлэл одоогоор байхгүй байна', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is Accident) {
                  return _buildAccidentCard(context, item);
                } else if (item is Submission) {
                  return _buildSubmissionCard(context, item);
                }
                return SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccidentCard(BuildContext context, Accident accident) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAccidentDetails(context, accident),
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
                      color: _getSourceColor(accident.source).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      accident.source == AccidentSource.user ? Icons.person : Icons.videocam,
                      color: _getSourceColor(accident.source),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accident.sourceMongolian,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getSourceColor(accident.source),
                          ),
                        ),
                        Text(
                          accident.reportedBy,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),

                ],
              ),

              SizedBox(height: 12),

              if (accident.description.isNotEmpty) ...[
                Text(
                  _stripDuration(accident.description),
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
                    _formatDateTime(accident.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${accident.latitude.toStringAsFixed(4)}, ${accident.longitude.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (accident.verificationCount > 0) ...[
                    Icon(Icons.verified, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      '${accident.verificationCount}',
                      style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(accident.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  accident.statusMongolian,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(accident.status),
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image,
                      color: statusColor,
                      size: 20,
                    ),
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  color: statusColor.withOpacity(0.1),
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

  void _showAccidentDetails(BuildContext context, Accident accident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
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
                        accident.source == AccidentSource.user ? Icons.person : Icons.videocam,
                        color: _getSourceColor(accident.source),
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              accident.sourceMongolian,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _getSourceColor(accident.source),
                              ),
                            ),
                            Text(
                              'Осол #${accident.id}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  _buildDetailRow('Төлөв', accident.statusMongolian, Icons.info, _getStatusColor(accident.status)),
                  _buildDetailRow('Огноо цаг', _formatDateTime(accident.timestamp), Icons.access_time, Colors.grey[700]!),
                  _buildDetailRow('Байршил', '${accident.latitude.toStringAsFixed(6)}, ${accident.longitude.toStringAsFixed(6)}', Icons.location_on, Colors.red),

                  if (accident.description.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Хэрэглэгчээс бичигдсэн осол:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(_stripDuration(accident.description), style: TextStyle(fontSize: 14)),
                  ],

                  SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.map),
                          label: Text('Газрын зураг'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: accident.userHasReported
                              ? null
                              : () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => FalseReportDialog(
                                      accidentId: int.parse(accident.id),
                                      userHasReported: accident.userHasReported,
                                    ),
                                  );

                                  if (result == true && mounted) {
                                    _refreshData();
                                    Navigator.pop(context);
                                  }
                                },
                          icon: Icon(
                            accident.userHasReported ? Icons.check_circle : Icons.report_problem,
                            size: 18,
                          ),
                          label: Text(
                            accident.userHasReported ? 'Мэдэгдсэн' : 'Буруу мэдээлэл',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accident.userHasReported ? Colors.grey : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
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

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _stripDuration(String description) {
    return description.replaceAll(RegExp(r'\s*\(\d+:\d+\)\s*$'), '');
  }

  Color _getSourceColor(AccidentSource source) {
    switch (source) {
      case AccidentSource.user:
        return Colors.blue;
      case AccidentSource.camera:
        return Colors.purple;
    }
  }

  Color _getStatusColor(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported:
        return Colors.blue;
      case AccidentStatus.confirmed:
        return Colors.green;
      case AccidentStatus.resolved:
        return Colors.grey;
      case AccidentStatus.falseAlarm:
        return Colors.red;
    }
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
                      Icon(Icons.image, color: _getSubmissionStatusColor(submission.status), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Илгээсэн зураг',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'ID: ${submission.id}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Зураг ачаалагдсангүй', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  _buildDetailRow('Төлөв', submission.statusMongolian, Icons.info, _getSubmissionStatusColor(submission.status)),
                  _buildDetailRow('Огноо цаг', _formatDateTime(submission.createdAt), Icons.access_time, Colors.grey[700]!),
                  _buildDetailRow('Байршил', '${submission.latitude.toStringAsFixed(6)}, ${submission.longitude.toStringAsFixed(6)}', Icons.location_on, Colors.red),

                  if (submission.description.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text('Тайлбар:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text(submission.description, style: TextStyle(fontSize: 14)),
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
                      child: Text('Хаах'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
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
}