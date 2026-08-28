class UserLocation {
  final int userId;
  final double lat;
  final double lng;
  final DateTime updatedAt;
  final String ad;
  final String rol;

  UserLocation({required this.userId, required this.lat, required this.lng, required this.updatedAt, required this.ad, required this.rol});

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    userId: json['userId'] as int,
    lat: double.parse(json['lat'] as String),
    lng: double.parse(json['lng'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    ad: json['ad'] as String,
    rol: json['rol'] as String,
  );
}
