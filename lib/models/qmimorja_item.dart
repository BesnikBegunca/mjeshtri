class QmimorjaItem {
  final int? id;
  final String category;
  final String name;
  final String unit;
  final double price;

  const QmimorjaItem({
    this.id,
    required this.category,
    required this.name,
    required this.unit,
    required this.price,
  });

  factory QmimorjaItem.fromMap(Map<String, Object?> m) {
    return QmimorjaItem(
      id: (m['id'] as num?)?.toInt(),
      category: (m['category'] as String? ?? '').trim(),
      name: (m['name'] as String? ?? '').trim(),
      unit: (m['unit'] as String? ?? '').trim(),
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'unit': unit,
      'price': price,
    };
  }

  QmimorjaItem copyWith({
    int? id,
    String? category,
    String? name,
    String? unit,
    double? price,
  }) {
    return QmimorjaItem(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      price: price ?? this.price,
    );
  }
}
