import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../services/location_service.dart';
import '../widgets/confirm_logout.dart';
import 'notifications_screen.dart';
import 'report_ariza_screen.dart';

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
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = context.read<LocationService>().positionStream.listen(_onPosition);
    unawaited(_refreshOnce());
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refreshOnce, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }

    final nearby = _nearby;
    if (nearby == null || nearby['site'] == null) {
      return const Center(child: Text('Aktif ekipman bulunamadı', style: TextStyle(color: Colors.grey)));
    }

    final site = nearby['site'] as Map<String, dynamic>;
    final distance = nearby['distanceMeters'] as int?;
    final icinde = nearby['icinde'] as bool? ?? false;
    final equipmentList = (nearby['equipment'] as List<dynamic>).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _refreshOnce,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
