import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import 'equipment_history_screen.dart';

class _SiteStatusEquipment {
  final int id;
  final String tip;
  final String? marka;
  final String? model;
  final String? seriNo;
  final String durum;

  _SiteStatusEquipment.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      tip = json['tip'] as String,
      marka = json['marka'] as String?,
      model = json['model'] as String?,
      seriNo = json['seriNo'] as String?,
      durum = json['durum'] as String;

  String get tipLabel => tip == 'asansor' ? 'Asansör' : 'Yürüyen Merdiven';
  String get label => [marka, model].where((v) => v != null && v.isNotEmpty).join(' ');
}

class _SiteStatus {
  final int id;
  final String ad;
  final double? lat;
  final double? lng;
  final String durum;
  final DateTime? sonKontrol;
  final List<_SiteStatusEquipment> equipment;

  _SiteStatus.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      ad = json['ad'] as String,
      lat = json['lat'] != null ? double.tryParse(json['lat'] as String) : null,
      lng = json['lng'] != null ? double.tryParse(json['lng'] as String) : null,
      durum = json['durum'] as String,
      sonKontrol = json['sonKontrol'] != null ? DateTime.parse(json['sonKontrol'] as String) : null,
      equipment = (json['equipment'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_SiteStatusEquipment.fromJson)
          .toList();

  String get _relativeTime {
    final diff = DateTime.now().difference(sonKontrol!);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  String get sonKontrolLabel => sonKontrol == null
      ? 'Kontrol edilmedi'
      : '$_relativeTime (${DateFormat('dd.MM.yyyy HH:mm').format(sonKontrol!.toLocal())})';
}

const Map<String, Color> _renkColor = {'kirmizi': Colors.red, 'sari': Colors.orange, 'yesil': Colors.green};
const Map<String, String> _renkLabel = {'kirmizi': 'Sorun var', 'sari': 'Bakımda', 'yesil': 'Sorun yok'};

/// Saha Durumu — grid (açılır saha kartları) ve harita (renkli nokta) görünümü.
/// İşveren'de sekme, Yüklenici (sorumlu)'de ayrı bir ekran olarak gömülür.
class SahaDurumuBody extends StatefulWidget {
  const SahaDurumuBody({super.key});

  @override
  State<SahaDurumuBody> createState() => _SahaDurumuBodyState();
}

class _SahaDurumuBodyState extends State<SahaDurumuBody> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<_SiteStatus> _sites = [];
  bool _loading = true;
  String? _error;
  int? _acikSiteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('/api/sites/status');
      final sites = (res.data as List<dynamic>).cast<Map<String, dynamic>>().map(_SiteStatus.fromJson).toList();
      setState(() {
        _sites = sites;
        _loading = false;
      });
    } on DioException catch (_) {
      setState(() {
        _error = 'Veriler yüklenemedi';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(controller: _tabController, tabs: const [Tab(text: 'Grid'), Tab(text: 'Harita')]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(onRefresh: _load, child: _buildGrid()),
                    _buildMap(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    if (_sites.isEmpty) {
      return ListView(children: const [SizedBox(height: 120), Center(child: Text('Saha yok', style: TextStyle(color: Colors.grey)))]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sites.length,
      itemBuilder: (context, index) {
        final site = _sites[index];
        final acik = _acikSiteId == site.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(radius: 6, backgroundColor: _renkColor[site.durum]),
                title: Text(site.ad),
                subtitle: Text('${_renkLabel[site.durum]} · ${site.equipment.length} ünite · Son kontrol: ${site.sonKontrolLabel}'),
                trailing: Icon(acik ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _acikSiteId = acik ? null : site.id),
              ),
              if (acik)
                for (final eq in site.equipment)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    leading: CircleAvatar(radius: 5, backgroundColor: _renkColor[eq.durum]),
                    title: Text('${eq.tipLabel} — ${eq.label.isEmpty ? '—' : eq.label}'),
                    subtitle: Text(eq.seriNo ?? '—'),
                    trailing: Text(_renkLabel[eq.durum] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EquipmentHistoryScreen(equipmentId: eq.id))),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    final withCoords = _sites.where((s) => s.lat != null && s.lng != null).toList();
    final center = withCoords.isNotEmpty ? ll.LatLng(withCoords.first.lat!, withCoords.first.lng!) : const ll.LatLng(41.05, 28.8);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 12),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.sefirox.abbkontrol'),
        MarkerLayer(
          markers: withCoords
              .map(
                (site) => Marker(
                  point: ll.LatLng(site.lat!, site.lng!),
                  width: 160,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _tabController.index = 0;
                      _acikSiteId = site.id;
                    }),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 3),
                          ]),
                          child: Text(site.ad, style: const TextStyle(fontSize: 11)),
                        ),
                        Icon(Icons.location_on, color: _renkColor[site.durum], size: 30),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
