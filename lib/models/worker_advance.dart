class WorkerAdvance {
  final int? id;
  final int workerId;
  final String month;
  final double amount;
  final String? note;
  final DateTime createdAt;

  WorkerAdvance({
    this.id,
    required this.workerId,
    required this.month,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'month': month,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WorkerAdvance.fromMap(Map<String, Object?> map) {
    return WorkerAdvance(
      id: map['id'] as int?,
      workerId: (map['workerId'] as num).toInt(),
      month: map['month'] as String,
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  WorkerAdvance copyWith({
    int? id,
    int? workerId,
    String? month,
    double? amount,
    String? note,
    DateTime? createdAt,
  }) {
    return WorkerAdvance(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
