import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../models/work_order.dart';
import '../services/location_service.dart';
import '../widgets/confirm_logout.dart';
import '../widgets/status_badge.dart';
import '../widgets/tip_badge.dart';
import 'notifications_screen.dart';
import 'report_ariza_screen.dart';
import 'work_order_detail_screen.dart';

/// Kontrol Ekibi'nin ana ekranı — konum-tabanlı denetim akışı (PLAN.md böl. 2).
/// Checklist/foto yok: GPS 100m yarıçapa girince aktif ekipman gösterilir,
/// "Sorun Yok" tek tıkla kapanır; sorun varsa mevcut arıza bildirme ekranına gidilir.
class KontrolHomeScreen extends StatefulWidget {
  const KontrolHomeScreen({super.key});

  @override
  State<KontrolHomeScreen> createState() => _KontrolHomeScreenState();
}

class _KontrolHomeScreenState extends State<KontrolHomeScreen> {
  StreamSubscription<Position>? _sub;
  Position? _lastPosition;
  Map<String, dynamic>? _nearby;
  List<WorkOrder> _assignedTasks = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Konum akışları (tek seferlik GPS + sürekli positionStream, ki bu ikincisi
    // arka planda flutter_foreground_task'ın kendi Flutter engine'ini başlatır)
    // ve ekstra bir HTTP isteği aynı anda tetiklenirse ANR riskine yol açtığı
    // gözlemlendi (native platform-channel çakışması). Bu yüzden hepsi ilk
    // frame'den SONRA ve birbirini BEKLEYEREK (paralel değil, sıralı) başlatılır.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    await _refreshOnce();
    if (!mounted) return;
    _sub = context.read<LocationService>().positionStream.listen(_onPosition);
    await _loadAssignedTasks();
  }

  // Yönetici/Sorumlu tarafından doğrudan atanmış "kontrol" (veya başka tip)
  // işleri — Kontrol Ekibi'nin GPS-tetiklemeli "Sorun Yok" akışından ayrı,
  // normal Müdahale Başlat/Devam Edecek/Tamamlandı akışıyla yürütülür.
  Future<void> _loadAssignedTasks() async {
    try {
      final dio = context.read<ApiClient>().dio;
      final myId = context.read<AuthService>().currentUser?.id;
      final res = await dio.get('/api/work-orders');
      final all = (res.data as List<dynamic>).map((e) => WorkOrder.fromJson(e as Map<String, dynamic>)).toList();
      final mine = all
          .where((w) => w.atananUserId == myId && (w.durum == 'bekliyor' || w.durum == 'devam_edecek'))
          .toList();
      if (!mounted) return;
      setState(() => _assignedTasks = mine);
    } catch (_) {
      // Sessizce yut — bu ikincil bir bilgi kartı, GPS-yakınlık akışını etkilememeli.
    }
  }

  Future<void> _openAssignedTask(WorkOrder task) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: task.id)));
    if (mounted) await _loadAssignedTasks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onPosition(Position p) {
    _lastPosition = p;
    _load(p);
  }

  Future<void> _refreshOnce() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastPosition = p;
      await _load(p);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Konum alınamadı — konum izni verildiğinden emin olun';
        });
      }
    }
  }

  Future<void> _load(Position p) async {
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get(
        '/api/kontrol/nearby',
        queryParameters: {'lat': p.latitude, 'lng': p.longitude},
      );
      if (!mounted) return;
      setState(() {
        _nearby = res.data as Map<String, dynamic>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Veri alınamadı';
        });
      }
    }
  }

  Future<void> _sorunYok(int equipmentId) async {
    if (_lastPosition == null) return;
    setState(() => _submitting = true);
    try {
      final dio = context.read<ApiClient>().dio;
      await dio.post(
        '/api/kontrol/check',
        data: {'equipmentId': equipmentId, 'lat': _lastPosition!.latitude, 'lng': _lastPosition!.longitude},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi — sorun yok')));
      await _load(_lastPosition!);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['statusMessage'] as String? ?? 'Kaydedilemedi';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sorunVar(int equipmentId) async {
    final site = _nearby?['site'] as Map<String, dynamic>?;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportArizaScreen(initialSiteId: site?['id'] as int?, initialEquipmentId: equipmentId),
      ),
    );
    if (_lastPosition != null) await _load(_lastPosition!);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SahaCheck — Kontrol Ekibi'),
        actions: [
          const NotificationBellButton(),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Çıkış yap', onPressed: () => confirmAndLogout(context, auth)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _refreshAll() async {
    await _refreshOnce();
    await _loadAssignedTasks();
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refreshAll, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }

    final nearby = _nearby;
    final site = nearby?['site'] as Map<String, dynamic>?;
    final distance = nearby?['distanceMeters'] as int?;
    final icinde = nearby?['icinde'] as bool? ?? false;
    final equipmentList = site != null ? (nearby?['equipment'] as List<dynamic>).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];

    if (site == null && _assignedTasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Aktif ekipman bulunamadı', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_assignedTasks.isNotEmpty) ...[
            Text('Size Atanan Görevler', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final task in _assignedTasks) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text('İş Emri #${task.id}'),
                  subtitle: Wrap(
                    spacing: 6,
                    children: [TipBadge(tip: task.tip), StatusBadge(durum: task.durum)],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAssignedTask(task),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
          ],
          if (site != null) ...[
            Card(
              color: icinde ? Colors.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site['ad'] as String, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      icinde
                          ? 'Bu sahadasınız (${distance ?? 0}m)'
                          : 'En yakın aktif saha — ${distance ?? '?'}m uzakta, yaklaşınca aktifleşir',
                      style: TextStyle(color: icinde ? Colors.green[800] : Colors.orange[900]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final eq in equipmentList) ...[
            Card(
              child: ListTile(
                title: Text('${_tipLabel(eq['tip'] as String)} — ${eq['marka'] ?? ''} ${eq['model'] ?? ''}'.trim()),
                subtitle: eq['seriNo'] != null ? Text('Seri No: ${eq['seriNo']}') : null,
                enabled: icinde && !_submitting,
              ),
            ),
            if (icinde)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Sorun Yok'),
                        onPressed: _submitting ? null : () => _sorunYok(eq['id'] as int),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Sorun Var'),
                        onPressed: _submitting ? null : () => _sorunVar(eq['id'] as int),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _tipLabel(String tip) => tip == 'asansor' ? 'Asansör' : 'Yürüyen Merdiven';
}
