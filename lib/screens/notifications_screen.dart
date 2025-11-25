// lib/screens/notifications_screen.dart - BACKEND ХОЛБОСОН
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/accident_service.dart';
import '../models/accident.dart';
import 'map_screen.dart';
import '../widgets/false_report_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final AccidentService _accidentService = AccidentService();
  
  List<Map<String, dynamic>> _notifications = [];
  List<Accident> _confirmedAccidents = [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await _authService.getUserId();
      
      if (userId == null) {
        setState(() {
          _error = 'Хэрэглэгч олдсонгүй. Дахин нэвтэрнэ үү.';
          _isLoading = false;
        });
        return;
      }

      print('📬 Loading notifications for userId: $userId');

      // Load notifications
      final result = await _notificationService.getNotifications(userId);
      
      print('📥 Notification Result: ${result['success']}');
      
      // Load ALL confirmed accidents (nearby from any user)
      print('📬 Loading all confirmed accidents...');
      List<Accident> confirmedAccidents = [];
      try {
        confirmedAccidents = await _accidentService.getAllAccidents(
          status: AccidentStatus.confirmed,
          limit: 100,
          forceRefresh: true,
          userOnly: false, // Show accidents from ALL users
        );
        print('✅ All confirmed accidents loaded: ${confirmedAccidents.length}');
      } catch (e) {
        print('⚠️ Failed to load confirmed accidents: $e');
        // Don't fail the whole load if this fails
      }
      
      if (result['success']) {
        setState(() {
          _notifications = result['notifications'];
          _unreadCount = result['unreadCount'];
          _confirmedAccidents = confirmedAccidents;
          _error = null;
          _isLoading = false;
        });
        print('✅ Notifications loaded: ${_notifications.length}, Confirmed accidents: ${_confirmedAccidents.length}');
      } else {
        // Even if notifications fail, show confirmed accidents
        setState(() {
          _notifications = [];
          _unreadCount = 0;
          _confirmedAccidents = confirmedAccidents;
          _error = confirmedAccidents.isEmpty 
              ? (result['error'] ?? 'Мэдэгдэл ачаалагдсангүй')
              : null; // Don't show error if we have confirmed accidents
          _isLoading = false;
        });
        print('❌ Load failed: ${result['error']}, but showing ${confirmedAccidents.length} confirmed accidents');
      }
    } catch (e) {
      print('❌ Load notifications exception: $e');
      // Try to load ALL confirmed accidents even if notifications fail
      List<Accident> confirmedAccidents = [];
      try {
        confirmedAccidents = await _accidentService.getAllAccidents(
          status: AccidentStatus.confirmed,
          limit: 100,
          forceRefresh: true,
          userOnly: false, // Show accidents from ALL users
        );
        print('✅ Loaded ${confirmedAccidents.length} confirmed accidents as fallback');
      } catch (accidentError) {
        print('⚠️ Failed to load confirmed accidents: $accidentError');
      }
      
      setState(() {
        _error = confirmedAccidents.isEmpty ? 'Алдаа гарлаа: $e' : null;
        _notifications = [];
        _unreadCount = 0;
        _confirmedAccidents = confirmedAccidents;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      await _loadNotifications(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      await _notificationService.markAllAsRead(userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бүх мэдэгдлийг уншсан гэж тэмдэглэлээ'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadNotifications(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      await _notificationService.deleteNotification(notificationId, userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Мэдэгдэл устгагдлаа'),
          backgroundColor: Colors.orange,
        ),
      );
      
      await _loadNotifications(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showApiTestDialog() async {
    final userId = await _authService.getUserId();
    String testResult = 'Туршиж байна...';
    bool isLoading = true;

    // Test API connection
    if (userId != null) {
      try {
        final result = await _notificationService.getNotifications(userId);
        if (result['success']) {
          testResult = '✅ API холболт амжилттай\n'
              'Мэдэгдлийн тоо: ${result['notifications']?.length ?? 0}\n'
              'Уншаагүй: ${result['unreadCount'] ?? 0}';
        } else {
          testResult = '❌ API алдаа:\n${result['error'] ?? 'Тодорхойгүй алдаа'}';
        }
      } catch (e) {
        testResult = '❌ Алдаа гарлаа:\n$e';
      }
    } else {
      testResult = '❌ Хэрэглэгч олдсонгүй';
    }
    isLoading = false;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange),
              SizedBox(width: 8),
              Text('API Тест'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Хэрэглэгчийн ID: ${userId ?? "Олдсонгүй"}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                if (isLoading)
                  Center(child: CircularProgressIndicator())
                else
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      testResult,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                if (_error != null) ...[
                  SizedBox(height: 16),
                  Text(
                    'Одоогийн алдаа:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red[900],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Хаах'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadNotifications();
              },
              child: Text('Дахин турших'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: Text('Мэдэгдэл ${_unreadCount > 0 ? '($_unreadCount)' : ''}'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Бүгдийг уншсан',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
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

    if (_error != null) {
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
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  print('🔄 Retry button pressed');
                  _loadNotifications();
                },
                icon: Icon(Icons.refresh),
                label: Text('Дахин оролдох'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  // Show API test dialog
                  _showApiTestDialog();
                },
                icon: Icon(Icons.bug_report, size: 18),
                label: Text('API Тест'),
              ),
            ],
          ),
        ),
      );
    }

    // Show confirmed accidents if no notifications
    final totalItems = _notifications.length + _confirmedAccidents.length;
    
    if (totalItems == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Мэдэгдэл байхгүй',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              'Баталгаажсан осол байхгүй байна',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // Show notifications first, then confirmed accidents
          if (index < _notifications.length) {
            final notification = _notifications[index];
            return _buildNotificationCard(notification);
          } else {
            final accidentIndex = index - _notifications.length;
            final accident = _confirmedAccidents[accidentIndex];
            return _buildConfirmedAccidentCard(accident);
          }
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final title = notification['title'] ?? 'Мэдэгдэл';
    final message = notification['message'] ?? '';
    final sentAt = notification['sent_at'];
    final type = notification['type'] ?? 'general';
    
    // Time formatting
    String timeAgo = 'Цаг тодорхойгүй';
    if (sentAt != null) {
      try {
        final dateTime = DateTime.parse(sentAt);
        final difference = DateTime.now().difference(dateTime);
        
        if (difference.inMinutes < 1) {
          timeAgo = 'Дөнгөж сая';
        } else if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes} минутын өмнө';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours} цагийн өмнө';
        } else {
          timeAgo = '${difference.inDays} өдрийн өмнө';
        }
      } catch (e) {
        print('Date parse error: $e');
      }
    }

    // Icon based on type
    IconData icon;
    Color iconColor;
    
    switch (type) {
      case 'accident':
        icon = Icons.warning;
        iconColor = Colors.red;
        break;
      case 'alert':
        icon = Icons.error;
        iconColor = Colors.orange;
        break;
      case 'info':
        icon = Icons.info;
        iconColor = Colors.blue;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Устгах'),
            content: Text('Энэ мэдэгдлийг устгах уу?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Үгүй'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Устгах'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteNotification(notification['id'].toString());
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4),
        color: isRead ? null : Colors.blue.shade50,
        child: InkWell(
          onTap: () {
            if (!isRead) {
              _markAsRead(notification['id'].toString());
            }
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isRead ? Colors.grey[300] : iconColor.withOpacity(0.2),
                  child: Icon(
                    icon,
                    color: isRead ? Colors.grey[600] : iconColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmedAccidentCard(Accident accident) {
    String timeAgo = 'Цаг тодорхойгүй';
    try {
      final difference = DateTime.now().difference(accident.timestamp);
      if (difference.inMinutes < 1) {
        timeAgo = 'Дөнгөж сая';
      } else if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} минутын өмнө';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} цагийн өмнө';
      } else {
        timeAgo = '${difference.inDays} өдрийн өмнө';
      }
    } catch (e) {
      print('Date parse error: $e');
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      color: Colors.green.shade50,
      child: InkWell(
        onTap: () {
          // Navigate to map screen and show accident location
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapScreen(
                initialLatitude: accident.latitude,
                initialLongitude: accident.longitude,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 Баталгаажсан осол',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    if (accident.description.isNotEmpty)
                      Text(
                        accident.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '${accident.latitude.toStringAsFixed(4)}, ${accident.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => FalseReportDialog(
                              accidentId: int.parse(accident.id),
                              userHasReported: accident.userHasReported,
                            ),
                          );
                          if (result == true) {
                            // Reload notifications to reflect status change
                            if (mounted) {
                              _loadNotifications();
                            }
                          }
                        },
                        icon: Icon(
                          accident.userHasReported ? Icons.check_circle : Icons.report_problem,
                          size: 16,
                          color: accident.userHasReported ? Colors.grey : Colors.orange,
                        ),
                        label: Text(
                          accident.userHasReported ? 'Мэдэгдсэн' : 'Буруу мэдээлэл мэдэгдэх',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          side: BorderSide(
                            color: accident.userHasReported ? Colors.grey : Colors.orange,
                          ),
                          minimumSize: Size(0, 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}