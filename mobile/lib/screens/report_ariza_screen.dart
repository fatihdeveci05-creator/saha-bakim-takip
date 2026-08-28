import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/equipment.dart';
import '../models/site.dart';

class ReportArizaScreen extends StatefulWidget {
  const ReportArizaScreen({super.key});

  @override
  State<ReportArizaScreen> createState() => _ReportArizaScreenState();
}

class _ReportArizaScreenState extends State<ReportArizaScreen> {
  List<Site> _sites = [];
  List<Equipment> _equipment = [];
  int? _selectedSiteId;
  int? _selectedEquipmentId;
  final _aciklamaController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _aciklamaController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = context.read<ApiClient>().dio;
      final results = await Future.wait([dio.get('/api/sites'), dio.get('/api/equipment')]);
      setState(() {
        _sites = (results[0].data as List<dynamic>).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
        _equipment = (results[1].data as List<dynamic>).map((e) => Equipment.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Veriler yüklenemedi';
        _loading = false;
      });
    }
  }

  List<Equipment> get _filteredEquipment =>
      _selectedSiteId == null ? [] : _equipment.where((e) => e.siteId == _selectedSiteId).toList();

  Future<void> _submit() async {
    if (_selectedEquipmentId == null) {
      setState(() => _error = 'Ekipman seçin');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      await dio.post(
        '/api/work-orders',
        data: {
          'equipmentId': _selectedEquipmentId,
          'tip': 'ariza',
          'aciklama': _aciklamaController.text.trim().isEmpty ? null : _aciklamaController.text.trim(),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['statusMessage'] as String? ?? 'Bildirim başarısız');
    } catch (_) {
      setState(() => _error = 'Bildirim başarısız');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arıza Bildir')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSiteId,
                    decoration: const InputDecoration(labelText: 'Saha', border: OutlineInputBorder()),
                    items: _sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.ad))).toList(),
                    onChanged: (v) => setState(() {
                      _selectedSiteId = v;
                      _selectedEquipmentId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedEquipmentId,
                    decoration: const InputDecoration(labelText: 'Ekipman', border: OutlineInputBorder()),
                    items: _filteredEquipment
                        .map((e) => DropdownMenuItem(value: e.id, child: Text('${e.tipLabel} — ${e.label}')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedEquipmentId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aciklamaController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder(), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Bildir'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
