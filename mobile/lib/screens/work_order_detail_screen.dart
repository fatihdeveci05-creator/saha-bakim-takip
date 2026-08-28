import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../core/constants.dart';
import '../models/auth_user.dart';
import '../models/equipment.dart';
import '../models/material_item.dart';
import '../models/site.dart';
import '../models/work_order.dart';
import '../widgets/status_badge.dart';
import 'photo_viewer_screen.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  final int workOrderId;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  WorkOrderDetail? _detail;
  Equipment? _equipment;
  Site? _site;
  List<MaterialItem> _materials = [];
  List<AuthUser> _workers = [];
  int? _assignUserId;
  bool _assigning = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _gerekceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gerekceController.dispose();
    super.dispose();
  }

  Dio get _dio => context.read<ApiClient>().dio;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detailRes = await _dio.get('/api/work-orders/${widget.workOrderId}');
      final detail = WorkOrderDetail.fromJson(detailRes.data as Map<String, dynamic>);

      final canAssign = mounted && ['yonetici', 'sorumlu'].contains(context.read<AuthService>().currentUser?.rol);
      final results = await Future.wait([
        _dio.get('/api/equipment/${detail.equipmentId}'),
        _dio.get('/api/materials'),
        if (canAssign) _dio.get('/api/users'),
      ]);
      final equipment = Equipment.fromJson(results[0].data as Map<String, dynamic>);
      final materials = (results[1].data as List<dynamic>).map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)).toList();
      final workers = canAssign
          ? (results[2].data as List<dynamic>)
                .map((e) => AuthUser.fromJson(e as Map<String, dynamic>))
                .where((u) => u.isAltYuklenici)
                .toList()
          : <AuthUser>[];
      final siteRes = await _dio.get('/api/sites/${equipment.siteId}');

      setState(() {
        _detail = detail;
        _equipment = equipment;
        _site = Site.fromJson(siteRes.data as Map<String, dynamic>);
        _materials = materials;
        _workers = workers;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Kayıt yüklenemedi';
        _loading = false;
      });
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _addPhoto() async {
    setState(() => _busy = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await _showError('Fotoğraf için konum izni gerekli');
        return;
      }

      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1920);
      if (photo == null) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // XFile.readAsBytes/MultipartFile.fromBytes kullanılır (File/fromFile web'de çalışmaz).
      final bytes = await photo.readAsBytes();
      final sizeKb = bytes.length ~/ 1024;

      final uploadRes = await _dio.post(
        '/api/uploads',
        data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg')}),
      );
      final url = uploadRes.data['url'] as String;

      await _dio.post(
        '/api/work-orders/${widget.workOrderId}/photos',
        data: {
          'url': url,
          'gpsLat': position.latitude,
          'gpsLng': position.longitude,
          'cekimZamani': DateTime.now().toUtc().toIso8601String(),
          'boyutKb': sizeKb,
        },
      );

      await _load();
    } on DioException catch (e) {
      await _showError(e.response?.data?['statusMessage'] as String? ?? 'Fotoğraf eklenemedi');
    } catch (e) {
      await _showError('Fotoğraf eklenemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String durum, {String? not}) async {
    setState(() => _busy = true);
    try {
      await _dio.patch('/api/work-orders/${widget.workOrderId}/status', data: {'durum': durum, if (not != null) 'not': not});
      await _load();
    } on DioException catch (e) {
      await _showError(e.response?.data?['statusMessage'] as String? ?? 'Durum güncellenemedi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitAssign() async {
    if (_assignUserId == null) return;
    setState(() => _assigning = true);
    try {
      await _dio.patch('/api/work-orders/${widget.workOrderId}/assign', data: {'atananUserId': _assignUserId});
      _assignUserId = null;
      await _load();
    } on DioException catch (e) {
      await _showError(e.response?.data?['statusMessage'] as String? ?? 'Atama başarısız');
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _confirmNa() async {
    final notController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('N/A olarak işaretle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu iş emri kapanacak, onaya gitmeyecek. İsteğe bağlı bir açıklama ekleyebilirsiniz (ör. "arıza yoktu", "mükerrer bildirim").'),
            const SizedBox(height: 12),
            TextField(controller: notController, decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
        ],
      ),
    );
    if (confirmed != true) return;
    final not = notController.text.trim();
    await _changeStatus('na', not: not.isEmpty ? null : not);
  }

  Future<void> _addMaterial() async {
    if (_materials.isEmpty) {
      await _showError('Tanımlı malzeme yok');
      return;
    }
    int selectedId = _materials.first.id;
    final miktarController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Malzeme Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(
              builder: (context, setDialogState) => DropdownButtonFormField<int>(
                initialValue: selectedId,
                items: _materials.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.ad}${m.birim != null ? ' (${m.birim})' : ''}'))).toList(),
                onChanged: (v) => setDialogState(() => selectedId = v ?? selectedId),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: miktarController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Miktar'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
        ],
      ),
    );

    if (result != true) return;
    final miktar = double.tryParse(miktarController.text.replaceAll(',', '.'));
    if (miktar == null || miktar <= 0) {
      await _showError('Geçerli bir miktar girin');
      return;
    }

    setState(() => _busy = true);
    try {
      await _dio.post('/api/work-orders/${widget.workOrderId}/materials', data: {'materialId': selectedId, 'miktar': miktar});
      await _load();
    } on DioException catch (e) {
      await _showError(e.response?.data?['statusMessage'] as String? ?? 'Malzeme eklenemedi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReview(String sonuc) async {
    if (sonuc == 'red' && _gerekceController.text.trim().isEmpty) {
      await _showError('Red için gerekçe zorunludur');
      return;
    }
    setState(() => _busy = true);
    try {
      await _dio.post(
        '/api/work-orders/${widget.workOrderId}/review',
        data: {'sonuc': sonuc, if (_gerekceController.text.trim().isNotEmpty) 'gerekce': _gerekceController.text.trim()},
      );
      _gerekceController.clear();
      await _load();
    } on DioException catch (e) {
      await _showError(e.response?.data?['statusMessage'] as String? ?? 'İşlem başarısız');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final auth = context.watch<AuthService>();
    final canReview = detail != null && detail.durum == 'onay_bekliyor' && auth.currentUser?.rol == 'yonetici';
    final photoUrls = detail?.photos.map((p) => '${ApiConfig.baseUrl}${p.url}').toList() ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text('İş Emri #${widget.workOrderId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || detail == null
          ? Center(child: Text(_error ?? 'Kayıt bulunamadı'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_site?.ad ?? 'Saha #${_equipment?.siteId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${_equipment?.tipLabel ?? ''} ${_equipment?.label ?? ''}', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      StatusBadge(durum: detail.durum),
                    ],
                  ),
                  if (detail.aciklama != null) ...[const SizedBox(height: 12), Text(detail.aciklama!)],

                  if (detail.atananUserId == null && detail.durum == 'bekliyor' && _workers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Bu iş emri henüz kimseye atanmadı', style: TextStyle(color: Colors.orange, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _assignUserId,
                            decoration: const InputDecoration(labelText: 'Personel seçin', border: OutlineInputBorder(), isDense: true),
                            items: _workers.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.ad} (${u.rol})'))).toList(),
                            onChanged: (v) => setState(() => _assignUserId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _assignUserId == null || _assigning ? null : _submitAssign,
                          child: const Text('Ata'),
                        ),
                      ],
                    ),
                  ],

                  const Divider(height: 32),

                  Text('Fotoğraflar (${detail.photos.length}/3 min)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: detail.photos.length,
                    itemBuilder: (context, i) {
                      final p = detail.photos[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PhotoViewerScreen(imageUrls: photoUrls, initialIndex: i)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network('${ApiConfig.baseUrl}${p.url}', fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[300])),
                        ),
                      );
                    },
                  ),
                  if (detail.canChangeStatus) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _addPhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Fotoğraf Çek'),
                    ),
                  ],

                  const Divider(height: 32),
                  Text('Kullanılan Malzemeler', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (detail.materials.isEmpty) const Text('Henüz malzeme eklenmemiş', style: TextStyle(color: Colors.grey)),
                  for (final m in detail.materials) Text('• ${m.ad}: ${m.miktar} ${m.birim ?? ''}'),
                  if (detail.canChangeStatus) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _busy ? null : _addMaterial, icon: const Icon(Icons.add), label: const Text('Malzeme Ekle')),
                  ],

                  if (detail.canChangeStatus) ...[
                    const Divider(height: 32),
                    Text('Durum Güncelle', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (detail.durum == 'bekliyor')
                          FilledButton(onPressed: _busy ? null : () => _changeStatus('devam_edecek'), child: const Text('Müdahale Başlat')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: _busy || detail.photos.length < 3 ? null : () => _changeStatus('tamamlandi'),
                          child: const Text('Tamamlandı'),
                        ),
                        OutlinedButton(onPressed: _busy ? null : _confirmNa, child: const Text('N/A')),
                      ],
                    ),
                    if (detail.photos.length < 3)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Tamamlandı için en az 3 fotoğraf gerekli', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      ),
                  ],

                  if (canReview) ...[
                    const Divider(height: 32),
                    Text('Denetim Kararı', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _gerekceController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Gerekçe (red için zorunlu)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: _busy ? null : () => _submitReview('onay'),
                          icon: const Icon(Icons.check),
                          label: const Text('Onayla'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: _busy ? null : () => _submitReview('red'),
                          icon: const Icon(Icons.close),
                          label: const Text('Reddet'),
                        ),
                      ],
                    ),
                  ],

                  if (detail.reviews.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text('Denetim Geçmişi', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final r in detail.reviews)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(r.sonuc == 'onay' ? Icons.check_circle : Icons.cancel, color: r.sonuc == 'onay' ? Colors.green : Colors.red, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('dd.MM.yyyy HH:mm').format(r.incelenenZaman.toLocal())),
                                  if (r.gerekce != null) Text(r.gerekce!, style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  if (detail.timeline.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text('Zaman Çizelgesi', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final t in detail.timeline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(durum: t.durum),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('dd.MM.yyyy HH:mm').format(t.createdAt.toLocal()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  if (t.not != null) Text(t.not!, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
