import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../models/equipment.dart';
import '../models/site.dart';
import '../models/work_order.dart';
import '../utils/date_range.dart';
import '../widgets/status_badge.dart';
import '../widgets/tip_badge.dart';
import 'assign_work_order_screen.dart';
import 'notifications_screen.dart';
import 'personnel_screen.dart';
import 'report_ariza_screen.dart';
import 'saha_durumu_screen.dart';
import 'work_order_detail_screen.dart';

/// Sekme grupları PLAN.md'deki "bugün/bekleyen/tamamlanan/reddedilen" isimlerine
/// karşılık gelir; veri modelinde ayrı bir "planlanan tarih" alanı olmadığından
/// "Bugün" sekmesi hâlihazırda aktif (bekliyor+devam_edecek) işleri gösterir.
enum _Tab { bugun, bekleyen, tamamlanan, reddedilen }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// "Bugün"/"Bekleyen" hâlâ açık/aktif işleri gösterir — tarihe göre filtrelenmez,
// aksi halde unutulmuş eski bir arıza görünmez olurdu. Sadece kapanmış kayıtlar
// (Tamamlanan/Reddedilen) tarih filtresine tabidir; aksi halde liste sınırsız
// büyür (kullanıcı talebi).
const _activeDurumlar = {'bekliyor', 'devam_edecek'};
const _historicalDurumlar = {'onay_bekliyor', 'onaylandi', 'reddedildi', 'na'};

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  List<WorkOrder> _all = [];
  Map<int, Equipment> _equipmentById = {};
  Map<int, Site> _siteById = {};
  bool _loading = true;
  String? _error;
  Period _period = Period.bugun;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _Tab.values.length, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
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
          .where((w) => _activeDurumlar.contains(w.durum));
      final historical = (results[1].data as List<dynamic>)
          .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
          .where((w) => _historicalDurumlar.contains(w.durum));
      final equipmentList = (results[2].data as List<dynamic>)
          .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
          .toList();
      final siteList = (results[3].data as List<dynamic>).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _all = [...active, ...historical];
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

  Future<void> _pickPeriod() async {
    final selected = await showModalBottomSheet<Period>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Tamamlanan/Reddedilen için tarih filtresi', style: TextStyle(color: Colors.grey, fontSize: 12))),
            ),
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

  List<WorkOrder> _filter(_Tab tab) {
    switch (tab) {
      case _Tab.bugun:
        return _all.where((w) => w.durum == 'bekliyor' || w.durum == 'devam_edecek').toList();
      case _Tab.bekleyen:
        return _all.where((w) => w.durum == 'bekliyor').toList();
      case _Tab.tamamlanan:
        return _all.where((w) => w.durum == 'onay_bekliyor' || w.durum == 'onaylandi').toList();
      case _Tab.reddedilen:
        return _all.where((w) => w.durum == 'reddedildi').toList();
    }
  }

  static const _tabLabels = {
    _Tab.bugun: 'Bugün',
    _Tab.bekleyen: 'Bekleyen',
    _Tab.tamamlanan: 'Tamamlanan',
    _Tab.reddedilen: 'Reddedilen',
  };

  String _tabLabel(_Tab tab) => '${_tabLabels[tab]} (${_filter(tab).length})';

  String _equipmentLabel(int equipmentId) {
    final eq = _equipmentById[equipmentId];
    if (eq == null) return 'Ekipman #$equipmentId';
    final site = _siteById[eq.siteId];
    final siteName = site?.ad ?? 'Saha #${eq.siteId}';
    return '$siteName — ${eq.label.isEmpty ? eq.tipLabel : eq.label}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('İş Listem'),
            Text(
              'Tamamlanan/Reddedilen: ${periodDisplayLabel(_period, customFrom: _customFrom, customTo: _customTo)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _Tab.values.map((tab) => Tab(text: _tabLabel(tab))).toList(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.event_outlined), tooltip: 'Tarih filtresi', onPressed: _pickPeriod),
          if (auth.currentUser?.rol == 'sorumlu') ...[
            IconButton(
              icon: const Icon(Icons.grid_view_outlined),
              tooltip: 'Saha Durumu',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Saha Durumu')), body: const SahaDurumuBody())),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'Saha Personeli',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonnelScreen())),
            ),
          ],
          const NotificationBellButton(),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Çıkış yap', onPressed: () => auth.logout()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : TabBarView(
                controller: _tabController,
                children: _Tab.values
                    .map((tab) => _WorkOrderList(items: _filter(tab), equipmentLabel: _equipmentLabel, onReturn: _load))
                    .toList(),
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sadece "sorumlu" ekibindeki birine planlı bakım/kontrol işi atayabilir.
          if (auth.currentUser?.rol == 'sorumlu') ...[
            FloatingActionButton.extended(
              heroTag: 'assign',
              icon: const Icon(Icons.assignment_add),
              label: const Text('İş Ata'),
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AssignWorkOrderScreen()));
                if (created == true) _load();
              },
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'ariza',
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Arıza Bildir'),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ReportArizaScreen()));
              if (created == true) _load();
            },
          ),
        ],
      ),
    );
  }
}

class _WorkOrderList extends StatelessWidget {
  const _WorkOrderList({required this.items, required this.equipmentLabel, required this.onReturn});

  final List<WorkOrder> items;
  final String Function(int equipmentId) equipmentLabel;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Kayıt yok', style: TextStyle(color: Colors.grey)));
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
            title: Text(equipmentLabel(wo.equipmentId)),
            subtitle: Text(wo.reportedAt != null ? fmt.format(wo.reportedAt!.toLocal()) : '—'),
            trailing: StatusBadge(durum: wo.durum),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: wo.id)));
              onReturn();
            },
          ),
        );
      },
    );
  }
}
