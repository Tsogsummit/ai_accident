// lib/widgets/false_report_dialog.dart
import 'package:flutter/material.dart';
import '../services/false_report_service.dart';
import '../services/auth_service.dart';

class FalseReportDialog extends StatefulWidget {
  final int accidentId;

  const FalseReportDialog({
    super.key,
    required this.accidentId,
  });

  @override
  State<FalseReportDialog> createState() => _FalseReportDialogState();
}

class _FalseReportDialogState extends State<FalseReportDialog> {
  final FalseReportService _falseReportService = FalseReportService();
  final AuthService _authService = AuthService();
  final TextEditingController _commentController = TextEditingController();
  
  List<Map<String, dynamic>> _reasons = [];
  int? _selectedReasonId;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    setState(() => _isLoading = true);
    try {
      final reasons = await _falseReportService.getReportReasons();
      setState(() {
        _reasons = reasons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Шалтгаан авахад алдаа гарлаа: $e')),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReasonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Шалтгаан сонгоно уу')),
      );
      return;
    }

    final user = await _authService.getUser();
    if (user == null || user['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хэрэглэгчийн мэдээлэл олдсонгүй')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _falseReportService.reportFalseAlarm(
        accidentId: widget.accidentId,
        userId: user['id'] as int,
        reasonId: _selectedReasonId!,
        comment: _commentController.text.trim().isEmpty 
            ? null 
            : _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, success);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Буруу мэдээлэл илгээгдлээ' 
                : 'Илгээхэд алдаа гарлаа'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_problem, color: Colors.orange),
          SizedBox(width: 8),
          Text('Буруу мэдээлэл мэдэгдэх'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Энэ осол буруу мэдээлэл гэж үзэж байна уу?',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_reasons.isEmpty)
              Text('Шалтгаан олдсонгүй', style: TextStyle(color: Colors.red))
            else
              ..._reasons.map((reason) => RadioListTile<int>(
                title: Text(reason['name'] ?? ''),
                subtitle: reason['description'] != null
                    ? Text(
                        reason['description'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    : null,
                value: reason['id'] as int,
                groupValue: _selectedReasonId,
                onChanged: (value) {
                  setState(() => _selectedReasonId = value);
                },
              )),
            
            SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Нэмэлт тайлбар (сонголттой)',
                border: OutlineInputBorder(),
                hintText: 'Буруу мэдээлэл гэж үзэх шалтгаанаа бичнэ үү...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('Цуцлах'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Илгээх'),
        ),
      ],
    );
  }
}

