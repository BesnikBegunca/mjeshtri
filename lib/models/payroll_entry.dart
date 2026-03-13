class PayrollEntry {
  final int? id;
  final int workerId;
  final String month; // YYYY-MM
  final double grossSalary;
  final double employeePct;
  final double employerPct;
  final String? note;

  PayrollEntry({
    this.id,
    required this.workerId,
    required this.month,
    required this.grossSalary,
    required this.employeePct,
    required this.employerPct,
    this.note,
  });

  factory PayrollEntry.fromMap(Map<String, Object?> m) => PayrollEntry(
    id: (m['id'] as num?)?.toInt(),
    workerId: (m['workerId'] as num).toInt(),
    month: m['month'] as String,
    grossSalary: (m['grossSalary'] as num).toDouble(),
    employeePct: (m['employeePct'] as num).toDouble(),
    employerPct: (m['employerPct'] as num).toDouble(),
    note: m['note'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'workerId': workerId,
    'month': month,
    'grossSalary': grossSalary,
    'employeePct': employeePct,
    'employerPct': employerPct,
    'note': note,
  };

  double get netSalary => grossSalary * (1.0 - employeePct / 100.0);
  double get employerCost => grossSalary * (1.0 + employerPct / 100.0);
}
