import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/equipment.dart';
import '../models/site.dart';

class ReportArizaScreen extends StatefulWidget {
  const ReportArizaScreen({super.key, this.initialSiteId, this.initialEquipmentId});

  /// Kontrol Ekibi "Sorun Var" derken, zaten yanında durduğu ekipmanı/sahayı
  /// önceden seçili getirmek için — kullanıcı dropdown'dan tekrar seçmek
  /// zorunda kalmasın.
  final int? initialSiteId;
  final int? initialEquipmentId;

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

  // Fotoğraf isteğe bağlı — sarkan parça, açıkta kalan bir kısım gibi
  // arıza/işverenin özellikle görmesi gereken bir şey varsa eklenebilir.
  XFile? _photo;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.initialSiteId;
    _selectedEquipmentId = widget.initialEquipmentId;
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

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1920);
      if (photo != null) setState(() => _photo = photo);
    } catch (_) {
      // Kullanıcı kamerayı iptal etmiş olabilir — sessizce yut, foto opsiyonel.
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _attachPhoto(Dio dio, int workOrderId, XFile photo) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    // XFile.readAsBytes/MultipartFile.fromBytes kullanılır (File/fromFile web'de çalışmaz).
    final bytes = await photo.readAsBytes();
    final uploadRes = await dio.post(
      '/api/uploads',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg')}),
    );
    final url = uploadRes.data['url'] as String;
    await dio.post(
      '/api/work-orders/$workOrderId/photos',
      data: {
        'url': url,
        'gpsLat': position.latitude,
        'gpsLng': position.longitude,
        'cekimZamani': DateTime.now().toUtc().toIso8601String(),
        'boyutKb': bytes.length ~/ 1024,
      },
    );
  }

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
      final aciklama = _aciklamaController.text.trim();
      final res = await dio.post(
        '/api/work-orders',
        data: {
          'equipmentId': _selectedEquipmentId,
          'tip': 'ariza',
          if (aciklama.isNotEmpty) 'aciklama': aciklama,
        },
      );

      if (_photo != null) {
        final workOrderId = res.data['id'] as int;
        try {
          await _attachPhoto(dio, workOrderId, _photo!);
        } catch (_) {
          // Arıza zaten bildirildi — foto eklenemese de bildirimi kaybetme,
          // sadece kullanıcıyı bilgilendir.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Arıza bildirildi ama fotoğraf eklenemedi')),
            );
          }
        }
      }

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
                  const SizedBox(height: 12),
                  Text('Fotoğraf (opsiyonel)', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Sarkan/açıkta kalan bir parça gibi özellikle görülmesi gereken bir şey varsa ekleyin.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (_photo == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(_pickingPhoto ? 'Açılıyor…' : 'Fotoğraf Çek'),
                      onPressed: _pickingPhoto ? null : _pickPhoto,
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Fotoğraf eklendi')),
                        TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Kaldır')),
                      ],
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
