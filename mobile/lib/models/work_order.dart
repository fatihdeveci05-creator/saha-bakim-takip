/// Durum akışı: bekliyor -> devam_edecek -> tamamlandi (min 3 foto) -> otomatik
/// onay_bekliyor -> onaylandi | reddedildi (reddedilirse yeni bir bekliyor kaydı açılır).
class WorkOrder {
  final int id;
  final int equipmentId;
  final String tip; // 'bakim' | 'ariza' | 'kontrol'
  final int? atananUserId;
  final String durum;
  final String? aciklama;
  final int? parentWorkOrderId;
  final DateTime? reportedAt;
  final DateTime? responseStartedAt;
  final DateTime? resolvedAt;
  final int? resolvedByUserId;
  final String? atananAd;
  final String? resolvedByAd;
  final DateTime createdAt;

  WorkOrder({
    required this.id,
    required this.equipmentId,
    required this.tip,
    required this.atananUserId,
    required this.durum,
    required this.aciklama,
    required this.parentWorkOrderId,
    required this.reportedAt,
    required this.responseStartedAt,
    required this.resolvedAt,
    required this.resolvedByUserId,
    required this.atananAd,
    required this.resolvedByAd,
    required this.createdAt,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
    id: json['id'] as int,
    equipmentId: json['equipmentId'] as int,
    tip: json['tip'] as String,
    atananUserId: json['atananUserId'] as int?,
    durum: json['durum'] as String,
    aciklama: json['aciklama'] as String?,
    parentWorkOrderId: json['parentWorkOrderId'] as int?,
    reportedAt: _parseDate(json['reportedAt']),
    responseStartedAt: _parseDate(json['responseStartedAt']),
    resolvedAt: _parseDate(json['resolvedAt']),
    resolvedByUserId: json['resolvedByUserId'] as int?,
    atananAd: json['atananAd'] as String?,
    resolvedByAd: json['resolvedByAd'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String get atananLabel => atananAd ?? (atananUserId != null ? '#$atananUserId' : '—');
  String get resolvedByLabel => resolvedByAd ?? (resolvedByUserId != null ? '#$resolvedByUserId' : '—');

  static DateTime? _parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String);

  static const durumLabels = {
    'bekliyor': 'Bekliyor',
    'devam_edecek': 'Müdahale Başladı',
    'tamamlandi': 'Tamamlandı',
    'onay_bekliyor': 'Onay Bekliyor',
    'onaylandi': 'Onaylandı',
    'reddedildi': 'Reddedildi',
    'na': 'N/A',
  };

  static const tipLabels = {'bakim': 'Bakım', 'ariza': 'Arıza', 'kontrol': 'Kontrol'};

  String get durumLabel => durumLabels[durum] ?? durum;
  String get tipLabel => tipLabels[tip] ?? tip;

  bool get canChangeStatus => durum == 'bekliyor' || durum == 'devam_edecek';
}

class WorkOrderPhoto {
  final int id;
  final String url;
  final String gpsLat;
  final String gpsLng;
  final DateTime cekimZamani;

  WorkOrderPhoto({required this.id, required this.url, required this.gpsLat, required this.gpsLng, required this.cekimZamani});

  factory WorkOrderPhoto.fromJson(Map<String, dynamic> json) => WorkOrderPhoto(
    id: json['id'] as int,
    url: json['url'] as String,
    gpsLat: json['gpsLat'] as String,
    gpsLng: json['gpsLng'] as String,
    cekimZamani: DateTime.parse(json['cekimZamani'] as String),
  );
}

class WorkOrderReview {
  final int id;
  final String sonuc; // 'onay' | 'red'
  final String? gerekce;
  final DateTime incelenenZaman;

  WorkOrderReview({required this.id, required this.sonuc, this.gerekce, required this.incelenenZaman});

  factory WorkOrderReview.fromJson(Map<String, dynamic> json) => WorkOrderReview(
    id: json['id'] as int,
    sonuc: json['sonuc'] as String,
    gerekce: json['gerekce'] as String?,
    incelenenZaman: DateTime.parse(json['incelenenZaman'] as String),
  );
}

class WorkOrderMaterialUsage {
  final int materialId;
  final String miktar;
  final String ad;
  final String? birim;

  WorkOrderMaterialUsage({required this.materialId, required this.miktar, required this.ad, this.birim});

  factory WorkOrderMaterialUsage.fromJson(Map<String, dynamic> json) => WorkOrderMaterialUsage(
    materialId: json['materialId'] as int,
    miktar: json['miktar'] as String,
    ad: json['ad'] as String,
    birim: json['birim'] as String?,
  );
}

class WorkOrderTimelineEntry {
  final int id;
  final String durum;
  final String? not;
  final DateTime createdAt;

  WorkOrderTimelineEntry({required this.id, required this.durum, this.not, required this.createdAt});

  factory WorkOrderTimelineEntry.fromJson(Map<String, dynamic> json) => WorkOrderTimelineEntry(
    id: json['id'] as int,
    durum: json['durum'] as String,
    not: json['not'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class WorkOrderDetail extends WorkOrder {
  final List<WorkOrderPhoto> photos;
  final List<WorkOrderReview> reviews;
  final List<WorkOrderMaterialUsage> materials;
  final List<WorkOrderTimelineEntry> timeline;

  WorkOrderDetail({
    required super.id,
    required super.equipmentId,
    required super.tip,
    required super.atananUserId,
    required super.durum,
    required super.aciklama,
    required super.parentWorkOrderId,
    required super.reportedAt,
    required super.responseStartedAt,
    required super.resolvedAt,
    required super.resolvedByUserId,
    required super.atananAd,
    required super.resolvedByAd,
    required super.createdAt,
    required this.photos,
    required this.reviews,
    required this.materials,
    required this.timeline,
  });

  factory WorkOrderDetail.fromJson(Map<String, dynamic> json) {
    final base = WorkOrder.fromJson(json);
    return WorkOrderDetail(
      id: base.id,
      equipmentId: base.equipmentId,
      tip: base.tip,
      atananUserId: base.atananUserId,
      durum: base.durum,
      aciklama: base.aciklama,
      parentWorkOrderId: base.parentWorkOrderId,
      reportedAt: base.reportedAt,
      responseStartedAt: base.responseStartedAt,
      resolvedAt: base.resolvedAt,
      resolvedByUserId: base.resolvedByUserId,
      atananAd: base.atananAd,
      resolvedByAd: base.resolvedByAd,
      createdAt: base.createdAt,
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => WorkOrderPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviews: (json['reviews'] as List<dynamic>? ?? [])
          .map((e) => WorkOrderReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      materials: (json['materials'] as List<dynamic>? ?? [])
          .map((e) => WorkOrderMaterialUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map((e) => WorkOrderTimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
