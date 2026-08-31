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
import '../widgets/confirm_logout.dart';
import '../widgets/floating_icon_menu.dart';
import '../widgets/status_badge.dart';
import '../widgets/tip_badge.dart';
import 'assign_work_order_screen.dart';
import 'notifications_screen.dart';
import 'personnel_screen.dart';
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
    _tabController = TabController(length: 5, vsync: this);
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
        title: const Text('SahaCheck — İşveren'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Denetim Kuyruğu'),
            Tab(text: 'Tüm İşler'),
            Tab(text: 'Canlı Harita'),
            Tab(text: 'Saha Durumu'),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Çıkış yap', onPressed: () => confirmAndLogout(context, auth)),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: const [_DashboardTab(), _DenetimKuyruguTab(), _TumIslerTab(), _CanliHaritaTab(), SahaDurumuBody()],
          ),
          FloatingIconMenu(
            items: [
              if (auth.currentUser?.rol == 'yonetici')
                FloatingIconMenuItem(
                  icon: Icons.people_alt_outlined,
                  label: 'Saha Personeli',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonnelScreen())),
                ),
            ],
          ),
        ],
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

// Web'deki Dashboard'ın mobil karşılığı — özet istatistikler + bugünün
// ekip dağılımı (kim hangi rolde/takımda, günlük görev ataması sonucu).
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<WorkOrder> _items = [];
  List<Map<String, dynamic>> _personel = [];
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([dio.get('/api/work-orders'), dio.get('/api/users'), dio.get('/api/teams')]);
      setState(() {
        _items = (results[0].data as List<dynamic>).map((e) => WorkOrder.fromJson(e as Map<String, dynamic>)).toList();
        _personel = (results[1].data as List<dynamic>).cast<Map<String, dynamic>>();
        _teams = (results[2].data as List<dynamic>).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Veriler yüklenemedi';
        _loading = false;
      });
    }
  }

  int get _acikIsSayisi => _items.where((w) => ['bekliyor', 'devam_edecek', 'onay_bekliyor'].contains(w.durum)).length;
  int get _onayBekleyenSayisi => _items.where((w) => w.durum == 'onay_bekliyor').length;

  double? _avgHours(DateTime? Function(WorkOrder) start, DateTime? Function(WorkOrder) end) {
    final diffs = <double>[];
    for (final w in _items) {
      final s = start(w);
      final e = end(w);
      if (s == null || e == null) continue;
      final h = e.difference(s).inMinutes / 60.0;
      if (h >= 0) diffs.add(h);
    }
    if (diffs.isEmpty) return null;
    return diffs.reduce((a, b) => a + b) / diffs.length;
  }

  int get _gecikenIsler {
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    return _items.where((w) => ['bekliyor', 'devam_edecek'].contains(w.durum) && w.createdAt.isBefore(cutoff)).length;
  }

  String _fmtHours(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} sa';

  static const _rolLabels = {'sorumlu': 'Sorumlu', 'ariza_ekibi': 'Arıza Ekibi', 'bakim_ekibi': 'Bakım Ekibi', 'kontrol_ekibi': 'Kontrol Ekibi'};
  static const _rolSirasi = ['sorumlu', 'ariza_ekibi', 'bakim_ekibi', 'kontrol_ekibi'];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final aktifSahaPersoneli = _personel.where((u) => u['taraf'] == 'alt_yuklenici' && u['aktif'] == true).toList();
    final teamNameById = {for (final t in _teams) t['id'] as int: t['ad'] as String};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.7,
            children: [
              _StatCard(value: '$_acikIsSayisi', label: 'Açık iş sayısı'),
              _StatCard(value: '$_onayBekleyenSayisi', label: 'Onay bekleyen'),
              _StatCard(value: _fmtHours(_avgHours((w) => w.reportedAt, (w) => w.responseStartedAt)), label: 'Ort. müdahale süresi'),
              _StatCard(value: _fmtHours(_avgHours((w) => w.reportedAt, (w) => w.resolvedAt)), label: 'Ort. çözüm süresi'),
              _StatCard(value: '$_gecikenIsler', label: 'Geciken işler (>3 gün)'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bugünün Ekip Dağılımı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (aktifSahaPersoneli.isEmpty)
                    const Text('Aktif saha personeli yok', style: TextStyle(color: Colors.grey))
                  else
                    for (final rol in _rolSirasi)
                      if (aktifSahaPersoneli.where((u) => u['rol'] == rol).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_rolLabels[rol]} (${aktifSahaPersoneli.where((u) => u['rol'] == rol).length})',
                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: aktifSahaPersoneli
                                    .where((u) => u['rol'] == rol)
                                    .map((u) {
                                      final takimId = u['takimId'] as int?;
                                      final takimAdi = takimId != null ? teamNameById[takimId] : null;
                                      return Chip(label: Text('${u['ad']}${takimAdi != null ? ' ($takimAdi)' : ''}'));
                                    })
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
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

// "Bekliyor"/"Müdahale Başladı" hâlâ açık/aktif işlerdir — tarihe göre
// filtrelenmez, aksi halde unutulmuş eski bir arıza görünmez olurdu.
// Sadece kapanmış kayıtlar (Tamamlanan/Reddedilen) tarih filtresine
// tabidir — aynı home_screen.dart'taki mantık (kullanıcı talebiyle
// İşveren'in de Bekleyen/Bugün'de HERŞEYİ görmesi, sadece
// Tamamlanan/Reddedilen'in bugüne kısıtlanması gerekiyor).
const _tumIslerAktifDurumlar = {'bekliyor', 'devam_edecek'};
const _tumIslerGecmisDurumlar = {'onay_bekliyor', 'onaylandi', 'reddedildi', 'na'};

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
        dio.get('/api/work-orders'),
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
      final active = (results[0].data as List<dynamic>)
          .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
          .where((w) => _tumIslerAktifDurumlar.contains(w.durum));
      final historical = (results[1].data as List<dynamic>)
          .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
          .where((w) => _tumIslerGecmisDurumlar.contains(w.durum));
      final equipmentList = (results[2].data as List<dynamic>).map((e) => Equipment.fromJson(e as Map<String, dynamic>)).toList();
      final siteList = (results[3].data as List<dynamic>).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _items = [...active, ...historical];
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
              'Tamamlanan/Reddedilen: ${periodDisplayLabel(_period, customFrom: _customFrom, customTo: _customTo)}',
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

  static const _tipOrder = ['ariza', 'bakim', 'kontrol'];

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(children: const [SizedBox(height: 120), Center(child: Text('Kayıt yok', style: TextStyle(color: Colors.grey)))]);
    }
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    // Tipleri (Arıza/Bakım/Kontrol) karışık tek liste yerine ayrı gridler
    // halinde göster — birbirine karışmasınlar diye.
    final byTip = <String, List<WorkOrder>>{for (final t in _tipOrder) t: []};
    for (final wo in items) {
      byTip[wo.tip]?.add(wo);
    }

    Widget buildCard(WorkOrder wo) => Card(
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final tip in _tipOrder) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              '${WorkOrder.tipLabels[tip] ?? tip} (${byTip[tip]!.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (byTip[tip]!.isEmpty)
            const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Kayıt yok', style: TextStyle(color: Colors.grey)))
          else
            for (final wo in byTip[tip]!) Padding(padding: const EdgeInsets.only(bottom: 8), child: buildCard(wo)),
          const SizedBox(height: 12),
        ],
      ],
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

    final points = _locations.map((l) => ll.LatLng(l.lat, l.lng)).toList();
    final center = points.isNotEmpty ? points.first : const ll.LatLng(41.05, 28.8);

    return FlutterMap(
      // Sabit İstanbul merkez/zoom yerine tüm personel konumlarını kapsayacak
      // şekilde otomatik yakınlaştır. `initialCameraFit` sadece ilk mount'ta
      // uygulanır — periyodik yenilemede (setState) kullanıcının haritada
      // gezindiği görünümü sıfırlamaz.
      options: MapOptions(
        initialCenter: center,
        initialZoom: points.length > 1 ? 12 : 15,
        initialCameraFit: points.length > 1
            ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(40), maxZoom: 15)
            : null,
      ),
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
