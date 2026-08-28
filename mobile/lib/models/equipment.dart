class Equipment {
  final int id;
  final int siteId;
  final String tip; // 'asansor' | 'yuruyen_merdiven'
  final String? marka;
  final String? model;
  final String? seriNo;

  Equipment({required this.id, required this.siteId, required this.tip, this.marka, this.model, this.seriNo});

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
    id: json['id'] as int,
    siteId: json['siteId'] as int,
    tip: json['tip'] as String,
    marka: json['marka'] as String?,
    model: json['model'] as String?,
    seriNo: json['seriNo'] as String?,
  );

  String get tipLabel => tip == 'asansor' ? 'Asansör' : 'Yürüyen Merdiven';

  String get label => [marka, model].where((v) => v != null && v.isNotEmpty).join(' ');
}
