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
import '../utils/date_range.dart';
import '../widgets/status_badge.dart';
import '../widgets/tip_badge.dart';
import 'assign_work_order_screen.dart';
import 'create_user_screen.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'Denetim Kuyruğu'),
            Tab(text: 'Tüm İşler'),
            Tab(text: 'Canlı Harita'),
            Tab(text: 'Saha Durumu'),
          ],
        ),
        actions: [
          if (auth.currentUser?.rol == 'yonetici')
            IconButton(
              icon: const Icon(Icons.person_add_alt_outlined),
              tooltip: 'Yeni Kullanıcı',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateUserScreen())),
            ),
          const NotificationBellButton(),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Çıkış yap', onPressed: () => auth.logout()),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_DenetimKuyruguTab(), _TumIslerTab(), _CanliHaritaTab(), SahaDurumuBody()],
      ),
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
                    leading: TipBadge(tip: wo.tip),
                    title: Text(_equipmentLabel(wo.equipmentId)),
                    subtitle: Text('Çözen: ${wo.resolvedByLabel} · ${wo.resolvedAt != null ? fmt.format(wo.resolvedAt!.toLocal()) : '—'}'),
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

// İşveren'in de Yüklenici/Arıza/Bakım/Kontrol ekiplerinin gördüğü tüm iş
// emirlerini (sadece denetim kuyruğundakileri değil) görüp, gerekirse
// kendisi de müdahale edebilmesi için (backend zaten yönetici'ye tam yetki
// veriyor — bkz. workOrderAccess.canViewAllWorkOrders).
enum _DurumFilter { hepsi, bekliyor, devamEdiyor, tamamlanan, reddedilen }

class _TumIslerTab extends StatefulWidget {
  const _TumIslerTab();

  @override
  State<_TumIslerTab> createState() => _TumIslerTabState();
}

class _TumIslerTabState extends State<_TumIslerTab> {
  List<WorkOrder> _items = [];
  Map<int, Equipment> _equipmentById = {};
  Map<int, Site> _siteById = {};
  bool _loading = true;
  String? _error;
  Period _period = Period.bugun;
  DateTime? _customFrom;
  DateTime? _customTo;
  _DurumFilter _durumFilter = _DurumFilter.hepsi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final range = periodRange(_period, customFrom: _customFrom, customTo: _customTo);
      final results = await Future.wait([
        dio.get(
          '/api/work-orders',
          queryParameters: {
            if (range.from != null) 'from': range.from!.toUtc().toIso8601String(),
            if (range.to != null) 'to': range.to!.toUtc().toIso8601String(),
          },
        ),
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

  List<WorkOrder> get _filtered {
    switch (_durumFilter) {
      case _DurumFilter.hepsi:
        return _items;
      case _DurumFilter.bekliyor:
        return _items.where((w) => w.durum == 'bekliyor').toList();
      case _DurumFilter.devamEdiyor:
        return _items.where((w) => w.durum == 'devam_edecek').toList();
      case _DurumFilter.tamamlanan:
        return _items.where((w) => w.durum == 'onay_bekliyor' || w.durum == 'onaylandi').toList();
      case _DurumFilter.reddedilen:
        return _items.where((w) => w.durum == 'reddedildi').toList();
    }
  }

  String _equipmentLabel(int equipmentId) {
    final eq = _equipmentById[equipmentId];
    if (eq == null) return 'Ekipman #$equipmentId';
    final site = _siteById[eq.siteId];
    final siteName = site?.ad ?? 'Saha #${eq.siteId}';
    return '$siteName — ${eq.label.isEmpty ? eq.tipLabel : eq.label}';
  }

  Future<void> _pickPeriod() async {
    final selected = await showModalBottomSheet<Period>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in Period.values)
              ListTile(
                title: Text(periodLabels[p]!),
                trailing: p == _period ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    if (selected == Period.ozel) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(today.year - 2),
        lastDate: today,
        initialDateRange: _customFrom != null && _customTo != null
            ? DateTimeRange(start: _customFrom!, end: _customTo!)
            : DateTimeRange(start: today.subtract(const Duration(days: 7)), end: today),
      );
      if (range == null || !mounted) return;
      setState(() {
        _period = Period.ozel;
        _customFrom = range.start;
        _customTo = range.end;
      });
    } else {
      setState(() => _period = selected);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_DurumFilter>(
                  initialValue: _durumFilter,
                  decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: _DurumFilter.hepsi, child: Text('Tümü')),
                    DropdownMenuItem(value: _DurumFilter.bekliyor, child: Text('Bekliyor')),
                    DropdownMenuItem(value: _DurumFilter.devamEdiyor, child: Text('Müdahale Başladı')),
                    DropdownMenuItem(value: _DurumFilter.tamamlanan, child: Text('Tamamlanan')),
                    DropdownMenuItem(value: _DurumFilter.reddedilen, child: Text('Reddedilen')),
                  ],
                  onChanged: (v) => setState(() => _durumFilter = v ?? _DurumFilter.hepsi),
                ),
              ),
              IconButton(icon: const Icon(Icons.event_outlined), tooltip: 'Tarih filtresi', onPressed: _pickPeriod),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              periodDisplayLabel(_period, customFrom: _customFrom, customTo: _customTo),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(onRefresh: _load, child: _buildList()),
        ),
      ],
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(children: const [SizedBox(height: 120), Center(child: Text('Kayıt yok', style: TextStyle(color: Colors.grey)))]);
    }
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final wo = items[index];
        return Card(
          child: ListTile(
            leading: TipBadge(tip: wo.tip),
            title: Text(_equipmentLabel(wo.equipmentId)),
            subtitle: Text(wo.reportedAt != null ? fmt.format(wo.reportedAt!.toLocal()) : '—'),
            trailing: StatusBadge(durum: wo.durum),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: wo.id)));
              _load();
            },
          ),
        );
      },
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
