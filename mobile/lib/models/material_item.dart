class MaterialItem {
  final int id;
  final String ad;
  final String? birim;

  MaterialItem({required this.id, required this.ad, this.birim});

  factory MaterialItem.fromJson(Map<String, dynamic> json) =>
      MaterialItem(id: json['id'] as int, ad: json['ad'] as String, birim: json['birim'] as String?);
}
