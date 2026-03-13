class ProductCalcItem {
  final int? id;
  final String kodi;
  final String emertimi;
  final String pako;
  final double sasiaPer100m2;
  final double vleraPer100m2;
  final double tvshPer100m2;

  const ProductCalcItem({
    this.id,
    required this.kodi,
    required this.emertimi,
    required this.pako,
    required this.sasiaPer100m2,
    required this.vleraPer100m2,
    required this.tvshPer100m2,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kodi': kodi,
      'emertimi': emertimi,
      'pako': pako,
      'sasiaPer100m2': sasiaPer100m2,
      'vleraPer100m2': vleraPer100m2,
      'tvshPer100m2': tvshPer100m2,
    };
  }

  factory ProductCalcItem.fromMap(Map<String, Object?> map) {
    return ProductCalcItem(
      id: map['id'] as int?,
      kodi: (map['kodi'] ?? '').toString(),
      emertimi: (map['emertimi'] ?? '').toString(),
      pako: (map['pako'] ?? '').toString(),
      sasiaPer100m2: ((map['sasiaPer100m2'] ?? 0) as num).toDouble(),
      vleraPer100m2: ((map['vleraPer100m2'] ?? 0) as num).toDouble(),
      tvshPer100m2: ((map['tvshPer100m2'] ?? 0) as num).toDouble(),
    );
  }

  double qtyForM2(double m2) => sasiaPer100m2 * (m2 / 100.0);

  double vleraPaTvsh(double m2) => vleraPer100m2 * (m2 / 100.0);

  double vleraTvsh(double m2) => tvshPer100m2 * (m2 / 100.0);

  double vleraMeTvsh(double m2) => vleraPaTvsh(m2) + vleraTvsh(m2);

  ProductCalcItem copyWith({
    int? id,
    String? kodi,
    String? emertimi,
    String? pako,
    double? sasiaPer100m2,
    double? vleraPer100m2,
    double? tvshPer100m2,
  }) {
    return ProductCalcItem(
      id: id ?? this.id,
      kodi: kodi ?? this.kodi,
      emertimi: emertimi ?? this.emertimi,
      pako: pako ?? this.pako,
      sasiaPer100m2: sasiaPer100m2 ?? this.sasiaPer100m2,
      vleraPer100m2: vleraPer100m2 ?? this.vleraPer100m2,
      tvshPer100m2: tvshPer100m2 ?? this.tvshPer100m2,
    );
  }
}