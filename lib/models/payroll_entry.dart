import 'dart:convert';

class PayrollEntry {
  final int? id;
  final int workerId;
  final String month; // YYYY-MM
  final double grossSalary;
  final double employeePct;
  final double employerPct;
  final String? note;

  // REJA
  final double dailyRate;
  final String? workedDaysJson; // ["2026-03-01","2026-03-02"]

  PayrollEntry({
    this.id,
    required this.workerId,
    required this.month,
    required this.grossSalary,
    required this.employeePct,
    required this.employerPct,
    this.note,
    this.dailyRate = 0,
    this.workedDaysJson,
  });

  factory PayrollEntry.fromMap(Map<String, Object?> m) => PayrollEntry(
        id: (m['id'] as num?)?.toInt(),
        workerId: (m['workerId'] as num).toInt(),
        month: m['month'] as String,
        grossSalary: (m['grossSalary'] as num).toDouble(),
        employeePct: (m['employeePct'] as num).toDouble(),
        employerPct: (m['employerPct'] as num).toDouble(),
        note: m['note'] as String?,
        dailyRate: ((m['dailyRate'] as num?) ?? 0).toDouble(),
        workedDaysJson: m['workedDaysJson'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'workerId': workerId,
        'month': month,
        'grossSalary': grossSalary,
        'employeePct': employeePct,
        'employerPct': employerPct,
        'note': note,
        'dailyRate': dailyRate,
        'workedDaysJson': workedDaysJson,
      };

  double get netSalary => grossSalary * (1.0 - employeePct / 100.0);
  double get employerCost => grossSalary * (1.0 + employerPct / 100.0);

  List<String> get workedDays {
    if (workedDaysJson == null || workedDaysJson!.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(workedDaysJson!);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList()..sort();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  int get workedDaysCount => workedDays.length;

  bool get isDailyPayroll => dailyRate > 0 || workedDays.isNotEmpty;

  PayrollEntry copyWith({
    int? id,
    int? workerId,
    String? month,
    double? grossSalary,
    double? employeePct,
    double? employerPct,
    String? note,
    double? dailyRate,
    String? workedDaysJson,
  }) {
    return PayrollEntry(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      month: month ?? this.month,
      grossSalary: grossSalary ?? this.grossSalary,
      employeePct: employeePct ?? this.employeePct,
      employerPct: employerPct ?? this.employerPct,
      note: note ?? this.note,
      dailyRate: dailyRate ?? this.dailyRate,
      workedDaysJson: workedDaysJson ?? this.workedDaysJson,
    );
  }

  static String encodeWorkedDays(Set<DateTime> dates) {
    final list = dates
        .map(
          (d) =>
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        )
        .toList()
      ..sort();
    return jsonEncode(list);
  }
}
