import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import 'create_user_screen.dart';

/// Saha personeli listesi + "günlük görev ataması" (rol/ekip değiştirme) —
/// web'deki `users/index.vue`'nun mobil karşılığı. Yönetici herkesin
/// rolünü değiştirebilir; Sorumlu (Yüklenici) sadece halihazırda saha
/// personeli olan hesapları 3 saha rolü arasında geçirebilir — backend
/// (`PATCH /api/users/:id`) aynı kısıtı zaten uyguluyor, burada sadece
/// gösterilen seçenekler daraltılıyor.
class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({super.key});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

const _rolLabels = {
  'yonetici': 'Yönetici',
  'denetci': 'Denetçi',
  'sorumlu': 'Sorumlu',
  'ariza_ekibi': 'Arıza Ekibi',
  'bakim_ekibi': 'Bakım Ekibi',
  'kontrol_ekibi': 'Kontrol Ekibi',
};
const _sahaRolleri = {'ariza_ekibi', 'bakim_ekibi', 'kontrol_ekibi'};

class _Personel {
  final int id;
  final String ad;
  final String email;
  final String taraf;
  final String rol;
  final bool aktif;
  final int? takimId;

  _Personel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      ad = json['ad'] as String,
      email = json['email'] as String,
      taraf = json['taraf'] as String,
      rol = json['rol'] as String,
      aktif = json['aktif'] as bool,
      takimId = json['takimId'] as int?;
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  List<_Personel> _personel = [];
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;
  String? _error;

  bool get _isYonetici => context.read<AuthService>().currentUser?.rol == 'yonetici';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Dio get _dio => context.read<ApiClient>().dio;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_dio.get('/api/users'), _dio.get('/api/teams')]);
      final personel = (results[0].data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_Personel.fromJson)
          .where((p) => p.taraf == 'alt_yuklenici')
          .toList();
      setState(() {
        _personel = personel;
        _teams = (results[1].data as List<dynamic>).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Veriler yüklenemedi';
        _loading = false;
      });
    }
  }

  String? _takimAdi(int? takimId) {
    if (takimId == null) return null;
    final t = _teams.firstWhere((t) => t['id'] == takimId, orElse: () => const {});
    return t['ad'] as String?;
  }

  bool _rolDegistirilebilirMi(_Personel p) {
    if (_isYonetici) return true;
    return _sahaRolleri.contains(p.rol); // Sorumlu — sadece saha personeli
  }

  List<MapEntry<String, String>> _rolSecenekleri() =>
      _isYonetici ? rolOptionsAltYuklenici : rolOptionsSahaPersoneli;

  Future<void> _duzenle(_Personel p) async {
    var secilenRol = p.rol;
    int? secilenTakim = p.takimId;
    final rolDegistirilebilir = _rolDegistirilebilirMi(p);

    final kaydet = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(p.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              if (rolDegistirilebilir)
                DropdownButtonFormField<String>(
                  initialValue: secilenRol,
                  decoration: const InputDecoration(labelText: 'Rol (günlük görev)', border: OutlineInputBorder()),
                  items: _rolSecenekleri().map((r) => DropdownMenuItem(value: r.key, child: Text(r.value))).toList(),
                  onChanged: (v) => setSheetState(() => secilenRol = v ?? secilenRol),
                )
              else
                Text('Rol: ${_rolLabels[p.rol] ?? p.rol} (bu rolü değiştiremezsiniz)', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: secilenTakim,
                decoration: const InputDecoration(labelText: 'Takım', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— Takım yok —')),
                  ..._teams.map((t) => DropdownMenuItem<int?>(value: t['id'] as int, child: Text(t['ad'] as String))),
                ],
                onChanged: (v) => setSheetState(() => secilenTakim = v),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (kaydet != true) return;
    try {
      await _dio.patch(
        '/api/users/${p.id}',
        data: {if (rolDegistirilebilir && secilenRol != p.rol) 'rol': secilenRol, 'takimId': secilenTakim},
      );
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.response?.data?['statusMessage'] as String? ?? 'Güncellenemedi')));
      }
    }
  }

  Future<void> _toggleAktif(_Personel p) async {
    await _dio.patch('/api/users/${p.id}', data: {'aktif': !p.aktif});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saha Personeli')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: _personel.isEmpty
                  ? ListView(
                      children: const [SizedBox(height: 120), Center(child: Text('Kayıt yok', style: TextStyle(color: Colors.grey)))],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _personel.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = _personel[index];
                        final takimAdi = _takimAdi(p.takimId);
                        return Card(
                          child: ListTile(
                            title: Text(p.ad),
                            subtitle: Text(
                              '${_rolLabels[p.rol] ?? p.rol}${takimAdi != null ? ' · $takimAdi' : ''} · ${p.aktif ? 'Aktif' : 'Pasif'}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Düzenle', onPressed: () => _duzenle(p)),
                                IconButton(
                                  icon: Icon(p.aktif ? Icons.toggle_on : Icons.toggle_off, color: p.aktif ? Colors.green : Colors.grey),
                                  tooltip: p.aktif ? 'Pasife al' : 'Aktifleştir',
                                  onPressed: () => _toggleAktif(p),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Yeni Kullanıcı'),
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreateUserScreen()));
          if (created == true) _load();
        },
      ),
    );
  }
}
