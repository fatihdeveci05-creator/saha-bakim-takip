class AuthUser {
  final int id;
  final String ad;
  final String email;
  final String taraf; // 'isveren' | 'alt_yuklenici'
  final String rol;

  AuthUser({required this.id, required this.ad, required this.email, required this.taraf, required this.rol});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    ad: json['ad'] as String,
    email: json['email'] as String,
    taraf: json['taraf'] as String,
    rol: json['rol'] as String,
  );

  bool get isAltYuklenici => taraf == 'alt_yuklenici';
  bool get isKontrolEkibi => rol == 'kontrol_ekibi';
}
