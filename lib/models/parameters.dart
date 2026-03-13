class Parameters {
  final double litersPer100;
  final double wastePct;
  final int coats;

  final double bucketPrice;      // ✅ çmimi i kovës 25L
  final String laborCategory;    // ✅ p.sh. "Punë dore"

  Parameters({
    required this.litersPer100,
    required this.wastePct,
    required this.coats,
    required this.bucketPrice,
    required this.laborCategory,
  });

  factory Parameters.fromMap(Map<String, Object?> m) => Parameters(
    litersPer100: (m['litersPer100'] as num).toDouble(),
    wastePct: (m['wastePct'] as num).toDouble(),
    coats: (m['coats'] as num).toInt(),
    bucketPrice: (m['bucketPrice'] as num).toDouble(),
    laborCategory: (m['laborCategory'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': 1,
    'litersPer100': litersPer100,
    'wastePct': wastePct,
    'coats': coats,
    'bucketPrice': bucketPrice,
    'laborCategory': laborCategory,
  };
}
