// lib/screens/profile_screen.dart - ЗАСВАРЛАСАН ХУВИЛБАР
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accident_provider.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'api_test_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ✅ Хэрэглэгчийн мэдээлэл ачаалах
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Эхлээд локал хадгалсан мэдээллийг авах
      final localUser = await _authService.getUser();
      
      if (localUser != null) {
        setState(() {
          _userData = localUser;
          _isLoading = false;
        });
      }

      // Дараа нь серверээс шинэ мэдээлэл татах
      final serverUser = await _authService.getProfile();
      
      if (serverUser != null) {
        setState(() {
          _userData = serverUser;
          _error = null;
        });
      } else if (localUser == null) {
        setState(() {
          _error = 'Хэрэглэгчийн мэдээлэл ачаалагдсангүй';
        });
      }
    } catch (e) {
      print('❌ Profile load error: $e');
      setState(() {
        _error = 'Алдаа гарлаа: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ ГАРАХ функц
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Гарах'),
        content: Text('Та гарахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Үгүй'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Тийм'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Гарч байна...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        // Logout хийх
        await _authService.logout();
        
        if (!mounted) return;
        
        // Loading dialog хаах
        Navigator.pop(context);
        
        // Login screen руу шилжих
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Амжилттай гарлаа'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        // Loading dialog хаах
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Гарахад алдаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профайл'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ApiTestScreen()),
              );
            },
            tooltip: 'API Тестлэх',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Шинэчлэх',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ачааллаж байна...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Алдаа гарлаа',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadUserData,
                          icon: Icon(Icons.refresh),
                          label: Text('Дахин оролдох'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return Consumer<AccidentProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Profile Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Text(
                  _userData?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                _userData?['name'] ?? 'Хэрэглэгч',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Phone
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    _userData?['phone'] ?? 'Утас тодорхойгүй',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
              
              // Email
              if (_userData?['email'] != null) ...[
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      _userData!['email'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 30),

              // API Connection Status Card
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud, color: Colors.blue, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'API Холболт',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 16),
                      _buildApiInfoRow('Горим', ApiConfig.connectionMode),
                      _buildApiInfoRow('IP хаяг', ApiConfig.localIP),
                      _buildApiInfoRow('Auth', ApiConfig.authServiceUrl),
                      _buildApiInfoRow('Accident', ApiConfig.accidentServiceUrl),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ApiTestScreen()),
                            );
                          },
                          icon: Icon(Icons.bug_report),
                          label: Text('API Тестлэх'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Statistics Card
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.blue, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Миний статистик',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24),
                      _buildStatRow(
                        'Нийт мэдээлсэн',
                        '${provider.userAccidents}',
                        Icons.report,
                        Colors.blue,
                      ),
                      SizedBox(height: 12),
                      _buildStatRow(
                        'Баталгаажсан',
                        '${provider.confirmedAccidents}',
                        Icons.verified,
                        Colors.green,
                      ),
                      SizedBox(height: 12),
                      _buildStatRow(
                        'Шийдвэрлэгдсэн',
                        '${provider.resolvedAccidents}',
                        Icons.check_circle,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: Icon(Icons.logout),
                  label: Text('Гарах'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApiInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}