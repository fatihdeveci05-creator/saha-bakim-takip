import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Cihazda çekilmiş ama henüz sunucuya yüklenmemiş fotoğraf. Seri çekim
/// yapılabilsin diye GPS+zaman damgası çekim anında alınır (kanıt doğru
/// olsun), ama ağ yüklemesi (upload) bilerek ERTELENİR — kullanıcı arka
/// arkaya fotoğraf çekerken her birinin yüklenmesini beklemesin.
class PendingPhoto {
  final Uint8List bytes;
  final double gpsLat;
  final double gpsLng;
  final DateTime capturedAt;

  PendingPhoto({required this.bytes, required this.gpsLat, required this.gpsLng, required this.capturedAt});
}

/// Kamerayı açar, fotoğrafı ve o anki GPS/zaman damgasını alıp yerelde tutar.
/// Ağ isteği YAPMAZ — bu yüzden art arda hızlıca çağrılabilir.
Future<PendingPhoto?> capturePendingPhoto() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw StateError('Fotoğraf için konum izni gerekli');
  }

  final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1920);
  if (photo == null) return null;

  final bytes = await photo.readAsBytes();
  final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  return PendingPhoto(bytes: bytes, gpsLat: position.latitude, gpsLng: position.longitude, capturedAt: DateTime.now());
}

/// Bekleyen fotoğrafları sırayla sunucuya yükler (ölçekleme/sıkıştırma zaten
/// çekim anında `imageQuality`/`maxWidth` ile yapıldı). `onProgress` her
/// fotoğraf bitince çağrılır — "3/5 yüklendi" gibi bir gösterge için.
Future<void> uploadPendingPhotos(
  Dio dio,
  int workOrderId,
  List<PendingPhoto> photos, {
  void Function(int done, int total)? onProgress,
}) async {
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    final uploadRes = await dio.post(
      '/api/uploads',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(p.bytes, filename: 'photo.jpg')}),
    );
    final url = uploadRes.data['url'] as String;
    await dio.post(
      '/api/work-orders/$workOrderId/photos',
      data: {
        'url': url,
        'gpsLat': p.gpsLat,
        'gpsLng': p.gpsLng,
        'cekimZamani': p.capturedAt.toUtc().toIso8601String(),
        'boyutKb': p.bytes.length ~/ 1024,
      },
    );
    onProgress?.call(i + 1, photos.length);
  }
}

/// Henüz yüklenmemiş fotoğrafları küçük resim (thumbnail) olarak, sağ üstte
/// silme çarpısıyla gösteren grid. Sunucudaki gerçek fotoğraflarla aynı grid
/// hücre boyutunda kullanılmak üzere tasarlandı.
class PendingPhotoTile extends StatelessWidget {
  const PendingPhotoTile({super.key, required this.photo, required this.onRemove});

  final PendingPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(photo.bytes, fit: BoxFit.cover),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
            child: const Text('Bekliyor', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
