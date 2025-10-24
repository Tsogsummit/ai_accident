// lib/screens/history_screen.dart - FIXED VERSION
// 🇲🇳 ТҮҮХ ХУУДАС (Reports -> History)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accident_provider.dart';
import '../models/accident.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  String _selectedFilter = 'all'; // all, user, camera

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

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
            onPressed: () {
              context.read<AccidentProvider>().loadAccidents();
            },
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Алдаа гарлаа', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(provider.error, textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.loadAccidents(),
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
            onRefresh: () => provider.loadAccidents(),
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

                  // Severity badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(accident.severity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      accident.severityMongolian,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
                  _buildDetailRow('Хүнд байдал', accident.severityMongolian, Icons.warning, _getSeverityColor(accident.severity)),
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
                            // Navigate to map
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

  Color _getSeverityColor(AccidentSeverity severity) {
    switch (severity) {
      case AccidentSeverity.severe:
        return Colors.red;
      case AccidentSeverity.moderate:
        return Colors.orange;
      case AccidentSeverity.minor:
        return Colors.yellow[700]!;
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