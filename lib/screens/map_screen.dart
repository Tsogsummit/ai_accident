import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/accident.dart';
import '../providers/accident_provider.dart';
import '../widgets/false_report_dialog.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccidents());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadAccidents({bool forceRefresh = false}) async {
    final provider = Provider.of<AccidentProvider>(context, listen: false);
    await provider.loadAccidents(forceRefresh: forceRefresh);
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _initializeLocation(),
      _loadAccidents(forceRefresh: true),
    ]);
  }

  void _showAccidentDetails(Accident accident) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Осол #${accident.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Төлөв', _statusToMongolian(accident.status)),
                      _buildInfoRow('Огноо', _formatDate(accident.timestamp)),
                      _buildInfoRow('Цаг', _formatTime(accident.timestamp)),
                      _buildInfoRow('Байршил', '${accident.latitude.toStringAsFixed(6)}, ${accident.longitude.toStringAsFixed(6)}'),
                      _buildInfoRow('Мэдээлсэн', accident.reportedBy),
                      if (accident.description.isNotEmpty)
                        _buildInfoRow('Тайлбар', accident.description),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final provider = Provider.of<AccidentProvider>(context, listen: false);
                          navigator.pop();
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => FalseReportDialog(
                              accidentId: int.parse(accident.id),
                              userHasReported: accident.userHasReported,
                            ),
                          );
                          if (result == true) {
                            await provider.loadAccidents(forceRefresh: true);
                          }
                        },
                        icon: Icon(
                          accident.userHasReported ? Icons.check_circle : Icons.report_problem,
                          color: accident.userHasReported ? Colors.grey : Colors.orange,
                        ),
                        label: Text(accident.userHasReported ? 'Мэдэгдсэн' : 'Буруу мэдээлэл мэдэгдэх'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Хаах'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _statusToMongolian(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported:
        return 'Мэдээлсэн';
      case AccidentStatus.confirmed:
        return 'Баталгаажсан';
      case AccidentStatus.resolved:
        return 'Шийдэгдсэн';
      case AccidentStatus.falseAlarm:
        return 'Худал';
    }
  }

  String _formatDate(DateTime dateTime) =>
      '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

  Widget _buildNoticeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.map_outlined, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Google Maps Integration-ыг системээс бүрэн салгасан тул газрын зураг харагдахгүй. '
                'Доорх жагсаалтаас ослын байршил, мэдээллийг үзнэ үү.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(AccidentProvider provider) {
    final total = provider.accidents.length;
    final confirmed = provider.accidents.where((a) => a.status == AccidentStatus.confirmed).length;
    final reported = provider.accidents.where((a) => a.status == AccidentStatus.reported).length;
    final resolved = provider.accidents.where((a) => a.status == AccidentStatus.resolved).length;

    Widget stat(String label, String value, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            stat('Нийт', '$total', Colors.black87),
            stat('Баталгаажсан', '$confirmed', Colors.green),
            stat('Мэдээлсэн', '$reported', Colors.orange),
            stat('Шийдэгдсэн', '$resolved', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildAccidentCard(Accident accident) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _statusColor(accident.status)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Осол #${accident.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  _statusToMongolian(accident.status),
                  style: TextStyle(color: _statusColor(accident.status), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Огноо', '${_formatDate(accident.timestamp)} ${_formatTime(accident.timestamp)}'),
            _buildInfoRow('Байршил', '${accident.latitude.toStringAsFixed(6)}, ${accident.longitude.toStringAsFixed(6)}'),
            _buildInfoRow('Мэдээлсэн', accident.reportedBy),
            if (accident.description.isNotEmpty)
              _buildInfoRow('Тайлбар', accident.description),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showAccidentDetails(accident),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Дэлгэрэнгүй'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AccidentStatus status) {
    switch (status) {
      case AccidentStatus.reported:
        return Colors.orange;
      case AccidentStatus.confirmed:
        return Colors.red;
      case AccidentStatus.resolved:
        return Colors.green;
      case AccidentStatus.falseAlarm:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Одоогоор ослын мэдээлэл алга',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Шинэ мэдээлэл ирэхэд жагсаалт автоматаар шинэчлэгдэнэ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Осол, байршлын түүх'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializeLocation,
            tooltip: 'Байршлыг шинэчлэх',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAccidents(forceRefresh: true),
            tooltip: 'Шинэчлэх',
          ),
        ],
      ),
      body: Consumer<AccidentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.accidents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = <Widget>[
            _buildNoticeCard(),
            const SizedBox(height: 12),
            _buildStatsCard(provider),
            const SizedBox(height: 12),
          ];

          if (_isLoadingLocation && _currentPosition == null) {
            children.add(const Card(
              elevation: 1,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Байршлын мэдээлэл шинэчилж байна...')),
                  ],
                ),
              ),
            ));
            children.add(const SizedBox(height: 12));
          } else if (_currentPosition != null) {
            children.add(Card(
              elevation: 1,
              child: ListTile(
                leading: const Icon(Icons.near_me, color: Colors.blue),
                title: const Text('Таны байршил'),
                subtitle: Text(
                  '${_currentPosition!.latitude.toStringAsFixed(6)}, '
                  '${_currentPosition!.longitude.toStringAsFixed(6)}',
                ),
              ),
            ));
            children.add(const SizedBox(height: 12));
          }

          if (provider.accidents.isEmpty) {
            children.add(_buildEmptyState());
          } else {
            for (final accident in provider.accidents) {
              children
                ..add(_buildAccidentCard(accident))
                ..add(const SizedBox(height: 12));
            }
          }

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: children,
            ),
          );
        },
      ),
    );
  }
}
