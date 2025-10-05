import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.report, color: Colors.white),
              ),
              title: Text('Accident Report #${index + 1}'),
              subtitle: Text('Date: ${DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0]}'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to report details
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Report #${index + 1} tapped')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}