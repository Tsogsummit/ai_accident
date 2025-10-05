import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 8,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: index < 3 ? Colors.red : Colors.grey[300],
              child: Icon(
                Icons.warning,
                color: index < 3 ? Colors.white : Colors.grey[600],
              ),
            ),
            title: Text(
              index < 3 ? 'New Accident Detected!' : 'Accident Report Update',
              style: TextStyle(
                fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              '${index + 1} ${index == 0 ? 'minute' : 'minutes'} ago',
            ),
            trailing: index < 3 
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
                SnackBar(content: Text('Notification ${index + 1} tapped')),
              );
            },
          );
        },
      ),
    );
  }
}