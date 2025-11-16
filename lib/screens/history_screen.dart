// lib/screens/history_screen.dart - ЗАСВАРЛАСАН (TOKEN FIX)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accident_provider.dart';
import '../models/accident.dart';
import '../services/auth_service.dart';
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
  String _selectedFilter = 'all'; // all, user, camera
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  // ✅ Эхлээд token шалгаад, дараа нь өгөгдөл ачаалах
  Future<void> _initializeAndLoadData() async {
    // Check if logged in
    final token = await _authService.getAccessToken();
    final user = await _authService.getUser();
    
    if (token == null || user == null) {
      // ✅ Нэвтрээгүй бол Login screen руу шилжүүлэх
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

    // ✅ Logged in - load data
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      
      final provider = Provider.of<AccidentProvider>(context, listen: false);
      
      try {
        await provider.loadAccidents();
      } catch (e) {
        print('❌ Load accidents error: $e');
        // Don't navigate away on error, just show error in UI
      }
    }
  }

  Future<void> _refreshData() async {
    // Don't check token here - let the API call handle it
    if (mounted) {
      final provider = Provider.of<AccidentProvider>(context, listen: false);
      
      try {
        await provider.loadAccidents(forceRefresh: true);
        
        // Clear any previous errors
        provider.clearError();
      } catch (e) {
        print('❌ Refresh error: $e');
        // Error will be shown in UI through provider
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

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
          // Filter dropdown
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
                value: 'user',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Хэрэглэгчээс'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'camera',
                child: Row(
                  children: [
                    Icon(Icons.videocam, size: 20),
                    SizedBox(width: 8),
                    Text('Камераас'),
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

          // ✅ Check for authentication error
          if (provider.error.isNotEmpty) {
            final errorLower = provider.error.toLowerCase();
            
            if (errorLower.contains('нэвтрэх') || 
                errorLower.contains('эрх дууссан') ||
                errorLower.contains('unauthorized') ||
                errorLower.contains('401')) {
              // Token expired - show button to re-login
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

            // Other errors
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

          // Filter accidents
          List<Accident> accidents = provider.allAccidents;
          if (_selectedFilter == 'user') {
            accidents = accidents.where((a) => a.source == AccidentSource.user).toList();
          } else if (_selectedFilter == 'camera') {
            accidents = accidents.where((a) => a.source == AccidentSource.camera).toList();
          }

          // Sort by timestamp (newest first)
          accidents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (accidents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Түүх хоосон байна', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Ослын мэдээлэл одоогоор байхгүй байна', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accidents.length,
              itemBuilder: (context, index) {
                final accident = accidents[index];
                return _buildAccidentCard(context, accident);
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
              // Header row
              Row(
                children: [
                  // Source icon
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

                  // Info
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

              // Description
              if (accident.description.isNotEmpty) ...[
                Text(
                  accident.description,
                  style: TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
              ],

              // Footer row
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

              // Status
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
                  // Handle
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

                  // Title
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

                  // Details
                  _buildDetailRow('Төлөв', accident.statusMongolian, Icons.info, _getStatusColor(accident.status)),
                  _buildDetailRow('Мэдээлсэн', accident.reportedBy, Icons.person, Colors.blue),
                  _buildDetailRow('Огноо цаг', _formatDateTime(accident.timestamp), Icons.access_time, Colors.grey[700]!),
                  _buildDetailRow('Байршил', '${accident.latitude.toStringAsFixed(6)}, ${accident.longitude.toStringAsFixed(6)}', Icons.location_on, Colors.red),
                  if (accident.verificationCount > 0)
                    _buildDetailRow('Баталгаажуулалт', '${accident.verificationCount} хүн', Icons.verified, Colors.green),

                  if (accident.description.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Тайлбар:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(accident.description, style: TextStyle(fontSize: 14)),
                  ],

                  SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.map),
                          label: Text('Газрын зураг'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _verifyAccident(context, accident);
                          },
                          icon: Icon(Icons.verified),
                          label: Text('Баталгаажуулах'),
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

  void _verifyAccident(BuildContext context, Accident accident) {
    final provider = context.read<AccidentProvider>();
    provider.verifyAccident(accident.id).then((success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Амжилттай баталгаажууллаа' : 'Алдаа гарлаа'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
}