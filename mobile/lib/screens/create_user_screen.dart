import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';

/// Yeni kullanıcı oluşturma — web'deki `users/index.vue` formunun mobil
/// karşılığı. Yönetici (İşveren) herkesi oluşturabilir; Sorumlu (Yüklenici)
/// sadece saha personeli (arıza/bakım/kontrol ekibi) oluşturabilir — izin
/// zaten backend'de (`POST /api/users`) uygulanıyor, burada sadece o
/// kullanıcıya gösterilen seçenekler daraltılıyor.
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

const _rolOptionsIsveren = [MapEntry('yonetici', 'Yönetici'), MapEntry('denetci', 'Denetçi')];
const _rolOptionsAltYuklenici = [
  MapEntry('sorumlu', 'Sorumlu (Yüklenici)'),
  MapEntry('ariza_ekibi', 'Arıza Ekibi'),
  MapEntry('bakim_ekibi', 'Bakım Ekibi'),
  MapEntry('kontrol_ekibi', 'Kontrol Ekibi'),
];
const _rolOptionsSahaPersoneli = [
  MapEntry('ariza_ekibi', 'Arıza Ekibi'),
  MapEntry('bakim_ekibi', 'Bakım Ekibi'),
  MapEntry('kontrol_ekibi', 'Kontrol Ekibi'),
];

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _adController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isYonetici;
  String _taraf = 'alt_yuklenici';
  late String _rol;
  int? _takimId;

  List<Map<String, dynamic>> _teams = [];
  bool _loadingTeams = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isYonetici = context.read<AuthService>().currentUser?.rol == 'yonetici';
    _rol = _isYonetici ? _rolOptionsAltYuklenici.first.key : _rolOptionsSahaPersoneli.first.key;
    _loadTeams();
  }

  @override
  void dispose() {
    _adController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _rolOptions {
    if (!_isYonetici) return _rolOptionsSahaPersoneli;
    return _taraf == 'isveren' ? _rolOptionsIsveren : _rolOptionsAltYuklenici;
  }

  Future<void> _loadTeams() async {
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('/api/teams');
      setState(() {
        _teams = (res.data as List<dynamic>).cast<Map<String, dynamic>>();
        _loadingTeams = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  Future<void> _submit() async {
    if (_adController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.length < 8) {
      setState(() => _error = 'Ad, e-posta zorunlu; şifre en az 8 karakter olmalı');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final telefon = _telefonController.text.trim();
      await dio.post(
        '/api/users',
        data: {
          'ad': _adController.text.trim(),
          'email': _emailController.text.trim(),
          if (telefon.isNotEmpty) 'telefon': telefon,
          'password': _passwordController.text,
          'taraf': _isYonetici ? _taraf : 'alt_yuklenici',
          'rol': _rol,
          if ((_isYonetici ? _taraf : 'alt_yuklenici') == 'alt_yuklenici' && _takimId != null) 'takimId': _takimId,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['statusMessage'] as String? ?? 'Kaydedilemedi');
    } catch (_) {
      setState(() => _error = 'Kaydedilemedi');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTaraf = _isYonetici ? _taraf : 'alt_yuklenici';
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Kullanıcı')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: _adController, decoration: const InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon (isteğe bağlı)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre (en az 8 karakter)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (_isYonetici) ...[
              DropdownButtonFormField<String>(
                initialValue: _taraf,
                decoration: const InputDecoration(labelText: 'Taraf', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'alt_yuklenici', child: Text('Alt Yüklenici')),
                  DropdownMenuItem(value: 'isveren', child: Text('İşveren')),
                ],
                onChanged: (v) => setState(() {
                  _taraf = v ?? 'alt_yuklenici';
                  _rol = _rolOptions.first.key;
                  if (_taraf == 'isveren') _takimId = null;
                }),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
              items: _rolOptions.map((r) => DropdownMenuItem(value: r.key, child: Text(r.value))).toList(),
              onChanged: (v) => setState(() => _rol = v ?? _rol),
            ),
            if (effectiveTaraf == 'alt_yuklenici') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _takimId,
                decoration: const InputDecoration(labelText: 'Takım (isteğe bağlı)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— Takım yok —')),
                  if (!_loadingTeams)
                    ..._teams.map((t) => DropdownMenuItem<int?>(value: t['id'] as int, child: Text(t['ad'] as String))),
                ],
                onChanged: (v) => setState(() => _takimId = v),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
