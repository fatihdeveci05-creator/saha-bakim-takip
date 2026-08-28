class Site {
  final int id;
  final String ad;
  final String? adres;

  Site({required this.id, required this.ad, this.adres});

  factory Site.fromJson(Map<String, dynamic> json) =>
      Site(id: json['id'] as int, ad: json['ad'] as String, adres: json['adres'] as String?);
}
