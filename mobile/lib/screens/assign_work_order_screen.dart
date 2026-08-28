import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/auth_user.dart';
import '../models/equipment.dart';
import '../models/site.dart';

/// Sorumlu rolündeki alt yüklenici personeli, ekibindeki birine planlı bir
/// bakım/kontrol işi (veya gerekirse arıza) atayabilir. Arıza bildirimindeki
/// self-servis akışın aksine burada atanan kişi serbestçe seçilir.
class AssignWorkOrderScreen extends StatefulWidget {
  const AssignWorkOrderScreen({super.key});

  @override
  State<AssignWorkOrderScreen> createState() => _AssignWorkOrderScreenState();
}

class _AssignWorkOrderScreenState extends State<AssignWorkOrderScreen> {
  List<Site> _sites = [];
  List<Equipment> _equipment = [];
  List<AuthUser> _workers = [];
  int? _selectedSiteId;
  int? _selectedEquipmentId;
  int? _selectedUserId;
  String _tip = 'bakim';
  String _oncelik = '';
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
      final results = await Future.wait([dio.get('/api/sites'), dio.get('/api/equipment'), dio.get('/api/users')]);
      setState(() {
        _sites = (results[0].data as List<dynamic>).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
        _equipment = (results[1].data as List<dynamic>).map((e) => Equipment.fromJson(e as Map<String, dynamic>)).toList();
        _workers = (results[2].data as List<dynamic>)
            .map((e) => AuthUser.fromJson(e as Map<String, dynamic>))
            .where((u) => u.isAltYuklenici)
            .toList();
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
    if (_selectedEquipmentId == null || _selectedUserId == null) {
      setState(() => _error = 'Ekipman ve personel seçin');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final aciklama = _aciklamaController.text.trim();
      await dio.post(
        '/api/work-orders',
        data: {
          'equipmentId': _selectedEquipmentId,
          'tip': _tip,
          'atananUserId': _selectedUserId,
          if (_oncelik.isNotEmpty) 'oncelik': _oncelik,
          if (aciklama.isNotEmpty) 'aciklama': aciklama,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['statusMessage'] as String? ?? 'İş emri oluşturulamadı');
    } catch (_) {
      setState(() => _error = 'İş emri oluşturulamadı');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static const _tipLabels = {'bakim': 'Bakım', 'kontrol': 'Kontrol', 'ariza': 'Arıza'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İş Ata')),
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
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
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
                  DropdownButtonFormField<String>(
                    initialValue: _tip,
                    decoration: const InputDecoration(labelText: 'Tip', border: OutlineInputBorder()),
                    items: _tipLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _tip = v ?? _tip),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedUserId,
                    decoration: const InputDecoration(labelText: 'Atanacak Personel', border: OutlineInputBorder()),
                    items: _workers.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.ad} (${u.rol})'))).toList(),
                    onChanged: (v) => setState(() => _selectedUserId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _oncelik,
                    decoration: const InputDecoration(labelText: 'Öncelik', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('—')),
                      DropdownMenuItem(value: 'dusuk', child: Text('Düşük')),
                      DropdownMenuItem(value: 'orta', child: Text('Orta')),
                      DropdownMenuItem(value: 'yuksek', child: Text('Yüksek')),
                    ],
                    onChanged: (v) => setState(() => _oncelik = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aciklamaController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder(), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
