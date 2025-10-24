// lib/screens/notifications_screen.dart - FIXED VERSION
// 🇲🇳 МЭДЭГДЭЛ ХУУДАС

import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мэдэгдэл'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Бүх мэдэгдлийг уншсан гэж тэмдэглэлээ')),
              );
            },
            tooltip: 'Бүгдийг уншсан',
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: 8,
        itemBuilder: (context, index) {
          final bool isNew = index < 3;
          return Card(
            margin: EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isNew ? Colors.red : Colors.grey[300],
                child: Icon(
                  Icons.warning,
                  color: isNew ? Colors.white : Colors.grey[600],
                ),
              ),
              title: Text(
                isNew ? 'Шинэ осол илэрлээ!' : 'Ослын мэдээ шинэчлэгдлээ',
                style: TextStyle(
                  fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${index + 1} минутын өмнө',
              ),
              trailing: isNew
                  ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
                  : null,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Мэдэгдэл ${index + 1} дарагдлаа')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

