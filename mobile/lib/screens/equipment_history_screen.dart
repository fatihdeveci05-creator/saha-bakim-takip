import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/equipment.dart';
import '../models/site.dart';
import '../models/work_order.dart';
import '../widgets/status_badge.dart';
import 'work_order_detail_screen.dart';

/// Ünite künyesi — bir ekipmanın tüm geçmişi (arıza/bakım/kontrol karışık).
/// Saha Durumu grid/haritasından ünite seçilince buraya gelinir.
class EquipmentHistoryScreen extends StatefulWidget {
  const EquipmentHistoryScreen({super.key, required this.equipmentId});

  final int equipmentId;

  @override
  State<EquipmentHistoryScreen> createState() => _EquipmentHistoryScreenState();
}

class _EquipmentHistoryScreenState extends State<EquipmentHistoryScreen> {
  Equipment? _equipment;
  Site? _site;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Dio get _dio => context.read<ApiClient>().dio;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/api/equipment/${widget.equipmentId}'),
        _dio.get('/api/equipment/${widget.equipmentId}/history'),
      ]);
      final equipment = Equipment.fromJson(results[0].data as Map<String, dynamic>);
      final history = (results[1].data as List<dynamic>).cast<Map<String, dynamic>>();
      final siteRes = await _dio.get('/api/sites/${equipment.siteId}');
      setState(() {
        _equipment = equipment;
        _site = Site.fromJson(siteRes.data as Map<String, dynamic>);
        _history = history;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Kayıt yüklenemedi';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ünite Geçmişi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _equipment == null
          ? Center(child: Text(_error ?? 'Kayıt bulunamadı'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_site?.ad ?? 'Saha #${_equipment!.siteId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '${_equipment!.tipLabel} — ${_equipment!.label.isEmpty ? '—' : _equipment!.label} — Seri No: ${_equipment!.seriNo ?? '—'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 32),
                  if (_history.isEmpty) const Text('Bu ekipmanla ilgili henüz kayıt yok', style: TextStyle(color: Colors.grey)),
                  for (final h in _history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: h['id'] as int)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(durum: h['durum'] as String),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${WorkOrder.tipLabels[h['tip']] ?? h['tip']} · ${h['resolvedByAd'] ?? '—'}'
                                    '${h['resolvedAt'] != null ? ' · ${DateFormat('dd.MM.yyyy').format(DateTime.parse(h['resolvedAt'] as String).toLocal())}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (h['aciklama'] != null) Text(h['aciklama'] as String, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
