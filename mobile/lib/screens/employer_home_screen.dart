import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../core/constants.dart';
import '../models/equipment.dart';
import '../models/site.dart';
import '../models/user_location.dart';
import '../models/work_order.dart';
import 'assign_work_order_screen.dart';
import 'notifications_screen.dart';
import 'saha_durumu_screen.dart';
import 'work_order_detail_screen.dart';

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABB Kontrol — İşveren'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Denetim Kuyruğu'),
            Tab(text: 'Canlı Harita'),
            Tab(text: 'Saha Durumu'),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Çıkış yap', onPressed: () => auth.logout()),
        ],
      ),
      body: TabBarView(controller: _tabController, children: const [_DenetimKuyruguTab(), _CanliHaritaTab(), SahaDurumuBody()]),
      floatingActionButton: auth.currentUser?.rol == 'yonetici'
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.assignment_add),
              label: const Text('İş Ata'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssignWorkOrderScreen())),
            )
          : null,
    );
  }
}

class _DenetimKuyruguTab extends StatefulWidget {
  const _DenetimKuyruguTab();

  @override
  State<_DenetimKuyruguTab> createState() => _DenetimKuyruguTabState();
}

class _DenetimKuyruguTabState extends State<_DenetimKuyruguTab> with WidgetsBindingObserver {
  List<WorkOrder> _items = [];
  Map<int, Equipment> _equipmentById = {};
  Map<int, Site> _siteById = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final results = await Future.wait([
        dio.get('/api/work-orders', queryParameters: {'durum': 'onay_bekliyor'}),
        dio.get('/api/equipment'),
        dio.get('/api/sites'),
      ]);
      final items = (results[0].data as List<dynamic>).map((e) => WorkOrder.fromJson(e as Map<String, dynamic>)).toList();
      final equipmentList = (results[1].data as List<dynamic>).map((e) => Equipment.fromJson(e as Map<String, dynamic>)).toList();
      final siteList = (results[2].data as List<dynamic>).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _items = items;
        _equipmentById = {for (final e in equipmentList) e.id: e};
        _siteById = {for (final s in siteList) s.id: s};
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Veriler yüklenemedi';
        _loading = false;
      });
    }
  }

  String _equipmentLabel(int equipmentId) {
    final eq = _equipmentById[equipmentId];
    if (eq == null) return 'Ekipman #$equipmentId';
    final site = _siteById[eq.siteId];
    final siteName = site?.ad ?? 'Saha #${eq.siteId}';
    return '$siteName — ${eq.label.isEmpty ? eq.tipLabel : eq.label}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Onay bekleyen iş emri yok', style: TextStyle(color: Colors.grey))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final wo = _items[index];
                final fmt = DateFormat('dd.MM.yyyy HH:mm');
                return Card(
                  child: ListTile(
                    title: Text(_equipmentLabel(wo.equipmentId)),
                    subtitle: Text(
                      '${wo.tipLabel} · Çözen: ${wo.resolvedByLabel} · ${wo.resolvedAt != null ? fmt.format(wo.resolvedAt!.toLocal()) : '—'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: wo.id)));
                      _load();
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _CanliHaritaTab extends StatefulWidget {
  const _CanliHaritaTab();

  @override
  State<_CanliHaritaTab> createState() => _CanliHaritaTabState();
}

class _CanliHaritaTabState extends State<_CanliHaritaTab> {
  List<UserLocation> _locations = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(ApiConfig.locationInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('/api/locations');
      if (!mounted) return;
      setState(() {
        _locations = (res.data as List<dynamic>).map((e) => UserLocation.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final center = _locations.isNotEmpty ? ll.LatLng(_locations.first.lat, _locations.first.lng) : const ll.LatLng(41.05, 28.8);

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 12),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sefirox.abbkontrol',
        ),
        MarkerLayer(
          markers: _locations
              .map(
                (loc) => Marker(
                  point: ll.LatLng(loc.lat, loc.lng),
                  width: 160,
                  height: 60,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3),
                        ]),
                        child: Text(loc.ad, style: const TextStyle(fontSize: 11)),
                      ),
                      const Icon(Icons.location_on, color: Colors.red, size: 28),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
