class AppNotification {
  final int id;
  final String tip;
  final String mesaj;
  final int? relatedWorkOrderId;
  final bool okundu;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.tip,
    required this.mesaj,
    required this.relatedWorkOrderId,
    required this.okundu,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as int,
    tip: json['tip'] as String,
    mesaj: json['mesaj'] as String,
    relatedWorkOrderId: json['relatedWorkOrderId'] as int?,
    okundu: json['okundu'] == true || json['okundu'] == 1,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
