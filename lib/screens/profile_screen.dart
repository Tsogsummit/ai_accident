// lib/screens/profile_screen.dart - FIXED VERSION
// 🇲🇳 ПРОФАЙЛ ХЭСЭГ - Монгол хэлтэй, Verified устгасан

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accident_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профайл'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettings(context);
            },
            tooltip: 'Тохиргоо',
          ),
        ],
      ),
      body: Consumer<AccidentProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Profile Avatar
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),

                // Name
                const Text(
                  'Хэрэглэгч',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Email/Phone
                Text(
                  'user@example.com',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

                const SizedBox(height: 30),

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
                        SizedBox(height: 12),
                        _buildStatRow(
                          'Баталгаажуулалт',
                          '0', // This would come from API
                          Icons.thumb_up,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Profile Items
                _buildProfileItem(
                  context,
                  Icons.location_on,
                  'Байршил',
                  'Улаанбаатар, Монгол',
                      () {},
                ),
                _buildProfileItem(
                  context,
                  Icons.phone,
                  'Утас',
                  '+976 XXXX XXXX',
                      () {},
                ),
                _buildProfileItem(
                  context,
                  Icons.notifications,
                  'Мэдэгдэл',
                  'Идэвхтэй',
                      () {},
                ),
                _buildProfileItem(
                  context,
                  Icons.language,
                  'Хэл',
                  'Монгол',
                      () {},
                ),
                _buildProfileItem(
                  context,
                  Icons.info,
                  'Апп-ийн тухай',
                  'Хувилбар 1.0.0',
                      () {
                    _showAboutDialog(context);
                  },
                ),

                const SizedBox(height: 30),

                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showLogoutDialog(context);
                    },
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

  Widget _buildProfileItem(
      BuildContext context,
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Тохиргоо'),
        content: Text('Тохиргооны цонх удахгүй нэмэгдэнэ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Хаах'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Апп-ийн тухай'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Замын Ослын Апп', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Хувилбар: 1.0.0'),
            Text('Үүсгэсэн: 2025'),
            SizedBox(height: 16),
            Text('Хиймэл оюун ухаан ашиглан замын осол илрүүлэх, мэдээлэх систем.'),
          ],
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Гарах'),
        content: Text('Та гарахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Үгүй'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Системээс гарлаа')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Тийм'),
          ),
        ],
      ),
    );
  }
}