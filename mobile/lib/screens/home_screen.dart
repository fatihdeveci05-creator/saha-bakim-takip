import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../models/equipment.dart';
import '../models/site.dart';
import '../models/work_order.dart';
import '../widgets/status_badge.dart';
import 'notifications_screen.dart';
import 'report_ariza_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  List<WorkOrder> _all = [];
  Map<int, Equipment> _equipmentById = {};
  Map<int, Site> _siteById = {};
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([dio.get('/api/work-orders'), dio.get('/api/equipment'), dio.get('/api/sites')]);

      final workOrders = (results[0].data as List<dynamic>)
          .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      final equipmentList = (results[1].data as List<dynamic>)
          .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
          .toList();
      final siteList = (results[2].data as List<dynamic>).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _all = workOrders;
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
        title: const Text('İş Listem'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _Tab.values.map((tab) => Tab(text: _tabLabel(tab))).toList(),
        ),
        actions: [
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
                children: _Tab.values.map((tab) => _WorkOrderList(items: _filter(tab), equipmentLabel: _equipmentLabel)).toList(),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Arıza Bildir'),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ReportArizaScreen()));
          if (created == true) _load();
        },
      ),
    );
  }
}

class _WorkOrderList extends StatelessWidget {
  const _WorkOrderList({required this.items, required this.equipmentLabel});

  final List<WorkOrder> items;
  final String Function(int equipmentId) equipmentLabel;

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
            title: Text(equipmentLabel(wo.equipmentId)),
            subtitle: Text('${wo.tipLabel} · ${wo.reportedAt != null ? fmt.format(wo.reportedAt!.toLocal()) : '—'}'),
            trailing: StatusBadge(durum: wo.durum),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(workOrderId: wo.id))),
          ),
        );
      },
    );
  }
}
