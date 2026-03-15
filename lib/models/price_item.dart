class PriceItem {
  final int? id;
  final String category; // ✅
  final String name;
  final String unit;
  final double price;

  PriceItem({
    this.id,
    required this.category,
    required this.name,
    required this.unit,
    required this.price,
  });

  factory PriceItem.fromMap(Map<String, Object?> m) => PriceItem(
        id: (m['id'] as num?)?.toInt(),
        category: (m['category'] as String),
        name: (m['name'] as String),
        unit: (m['unit'] as String),
        price: (m['price'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'name': name,
        'unit': unit,
        'price': price,
      };
}
