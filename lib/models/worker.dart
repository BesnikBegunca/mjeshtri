class Worker {
  final int? id;
  final String fullName;
  final String position;
  final double baseSalary;

  Worker({this.id, required this.fullName, required this.position, required this.baseSalary});

  factory Worker.fromMap(Map<String, Object?> m) => Worker(
    id: (m['id'] as num?)?.toInt(),
    fullName: m['fullName'] as String,
    position: m['position'] as String,
    baseSalary: (m['baseSalary'] as num).toDouble(),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'fullName': fullName,
    'position': position,
    'baseSalary': baseSalary,
  };
}
