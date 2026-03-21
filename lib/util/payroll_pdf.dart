import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll_entry.dart';
import '../models/worker.dart';
import '../models/worker_advance.dart';

class PayrollPdf {
  static const List<String> _monthNames = [
    'JANAR',
    'SHKURT',
    'MARS',
    'PRILL',
    'MAJ',
    'QERSHOR',
    'KORRIK',
    'GUSHT',
    'SHTATOR',
    'TETOR',
    'NËNTOR',
    'DHJETOR',
  ];

  static const List<String> _weekdays = [
    'HËN',
    'MAR',
    'MËR',
    'ENJ',
    'PRE',
    'SHT',
    'DIE',
  ];

  static Future<Uint8List> build({
    required String title,
    required List<PayrollPdfRow> rows,
    List<WorkerAdvance> advances = const [],
  }) async {
    final doc = pw.Document();

    final double totalGross = rows.fold<double>(
      0,
      (sum, r) => sum + r.entry.grossSalary,
    );

    final double totalNet = rows.fold<double>(
      0,
      (sum, r) => sum + r.entry.netSalary,
    );

    final double totalEmployerCost = rows.fold<double>(
      0,
      (sum, r) => sum + r.entry.employerCost,
    );

    final int totalWorkedDays = rows.fold<int>(
      0,
      (sum, r) => sum + r.entry.workedDaysCount,
    );

    final double totalAdvances = advances.fold<double>(
      0,
      (sum, a) => sum + a.amount,
    );

    final double totalRemaining = rows.fold<double>(
      0,
      (sum, r) => sum + _remainingForRow(r, advances),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text(
            _safe(title),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          _summaryTop(
            totalGross: totalGross,
            totalNet: totalNet,
            totalEmployerCost: totalEmployerCost,
            totalWorkedDays: totalWorkedDays,
            totalAdvances: totalAdvances,
            totalRemaining: totalRemaining,
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            headers: const [
              'Punëtori',
              'Muaji',
              'Ditë',
              '€/ditë',
              'Bruto (EUR)',
              'Avans (EUR)',
              'Mbeten (EUR)',
              'Net (punëtori)',
              'Kosto (firma)',
              'Shënim',
            ],
            data: [
              ...rows.map((r) {
                final w = r.worker;
                final e = r.entry;
                final monthAdvances = _advancesForRow(r, advances);
                final remaining = _remainingForRow(r, advances);

                return [
                  _safe('${w.fullName} (${w.position})'),
                  _safe(_monthLabel(e.month)),
                  e.workedDaysCount.toString(),
                  _money(e.dailyRate),
                  _money(e.grossSalary),
                  _money(monthAdvances),
                  _money(remaining),
                  '${_money(e.netSalary)} (${_safeNum(e.employeePct)}%)',
                  '${_money(e.employerCost)} (+${_safeNum(e.employerPct)}%)',
                  _safe((e.note == null || e.note!.trim().isEmpty)
                      ? '-'
                      : e.note!),
                ];
              }),
              [
                'TOTALI',
                '',
                totalWorkedDays.toString(),
                '',
                _money(totalGross),
                _money(totalAdvances),
                _money(totalRemaining),
                _money(totalNet),
                _money(totalEmployerCost),
                '',
              ],
            ],
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 20),
          ...rows.expand((r) => [
                _payrollCard(r, advances),
                pw.SizedBox(height: 16),
              ]),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _summaryTop({
    required double totalGross,
    required double totalNet,
    required double totalEmployerCost,
    required int totalWorkedDays,
    required double totalAdvances,
    required double totalRemaining,
  }) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _sumBox('Totali Ditëve', totalWorkedDays.toString()),
        _sumBox('Totali Bruto', _money(totalGross), highlight: true),
        _sumBox('Totali Avanseve', _money(totalAdvances), orange: true),
        _sumBox('Totali që mbesin', _money(totalRemaining), blue: true),
        _sumBox('Totali Neto', _money(totalNet)),
        _sumBox('Totali Kosto', _money(totalEmployerCost)),
      ],
    );
  }

  static pw.Widget _sumBox(
    String title,
    String value, {
    bool highlight = false,
    bool orange = false,
    bool blue = false,
  }) {
    PdfColor bg = PdfColors.grey100;
    PdfColor border = PdfColors.grey400;
    PdfColor text = PdfColors.black;

    if (highlight) {
      bg = PdfColors.green50;
      border = PdfColors.green300;
      text = PdfColors.green800;
    } else if (orange) {
      bg = PdfColors.orange50;
      border = PdfColors.orange300;
      text = PdfColors.orange800;
    } else if (blue) {
      bg = PdfColors.blue50;
      border = PdfColors.blue300;
      text = PdfColors.blue800;
    }

    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _safe(title),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _safe(value),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _payrollCard(
    PayrollPdfRow row,
    List<WorkerAdvance> advances,
  ) {
    final worker = row.worker;
    final entry = row.entry;
    final workedDays = _decodeWorkedDays(entry.workedDaysJson);
    final rowAdvances = _advancesForWorkerMonth(
      worker.id,
      entry.month,
      advances,
    )..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final advancesByDay = _sumAdvancesByDay(rowAdvances);
    final monthAdvanceTotal = rowAdvances.fold<double>(
      0,
      (sum, a) => sum + a.amount,
    );
    final remaining = _remainingForRow(row, advances);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _safe('${worker.fullName} - ${worker.position}'),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Muaji: ${_safe(_monthLabel(entry.month))}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniBox('Ditë pune', entry.workedDaysCount.toString()),
              _miniBox('€/ditë', _money(entry.dailyRate)),
              _miniBox('Bruto', _money(entry.grossSalary), green: true),
              _miniBox('Avans', _money(monthAdvanceTotal), orange: true),
              _miniBox('Mbeten', _money(remaining), blue: true),
              _miniBox('Neto', _money(entry.netSalary)),
              _miniBox('Kosto', _money(entry.employerCost)),
            ],
          ),
          if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Shënim: ${_safe(entry.note!)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            'Kalendari i muajit',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _calendarGrid(
            monthYm: entry.month,
            workedDays: workedDays,
            advancesByDay: advancesByDay,
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _legendBox(PdfColors.green100, PdfColors.green700, 'Punë'),
              _legendBox(
                PdfColors.orange50,
                PdfColors.orange700,
                'Punë + avans',
              ),
              _legendBox(
                PdfColors.red50,
                PdfColors.red700,
                'Avans pa punë',
              ),
              _legendBox(
                PdfColors.red100,
                PdfColors.red700,
                'Pushim / E diel',
              ),
              _legendBox(PdfColors.grey100, PdfColors.grey700, 'Pa punë'),
            ],
          ),
          if (rowAdvances.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Lista e avanseve të muajit',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: const ['Data', 'Shuma', 'Shënim'],
              data: rowAdvances.map((a) {
                return [
                  _fmtDate(a.createdAt),
                  _money(a.amount),
                  _safe((a.note == null || a.note!.trim().isEmpty)
                      ? '-'
                      : a.note!),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _miniBox(
    String title,
    String value, {
    bool green = false,
    bool orange = false,
    bool blue = false,
  }) {
    PdfColor bg = PdfColors.grey100;
    PdfColor border = PdfColors.grey400;
    PdfColor text = PdfColors.black;

    if (green) {
      bg = PdfColors.green50;
      border = PdfColors.green300;
      text = PdfColors.green800;
    } else if (orange) {
      bg = PdfColors.orange50;
      border = PdfColors.orange300;
      text = PdfColors.orange800;
    } else if (blue) {
      bg = PdfColors.blue50;
      border = PdfColors.blue300;
      text = PdfColors.blue800;
    }

    return pw.Container(
      width: 88,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _safe(title),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _safe(value),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _legendBox(
    PdfColor bg,
    PdfColor border,
    String text,
  ) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border.all(color: border),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          _safe(text),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static pw.Widget _calendarGrid({
    required String monthYm,
    required Set<DateTime> workedDays,
    required Map<String, double> advancesByDay,
  }) {
    final year = _yearFromYm(monthYm);
    final month = _monthFromYm(monthYm);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDay = DateTime(year, month, 1);
    final leadingEmpty = firstDay.weekday - 1;

    final cells = <pw.Widget>[];

    for (final w in _weekdays) {
      final isSundayHeader = w == 'DIE';
      cells.add(
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            color: isSundayHeader ? PdfColors.red100 : PdfColors.grey200,
            border: pw.Border.all(
              color: isSundayHeader ? PdfColors.red300 : PdfColors.grey400,
            ),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            w,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: isSundayHeader ? PdfColors.red700 : PdfColors.black,
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(pw.Container());
    }

    for (int dayNumber = 1; dayNumber <= daysInMonth; dayNumber++) {
      final day = DateTime(year, month, dayNumber);
      final key = _dayKey(day);
      final isSunday = day.weekday == DateTime.sunday;
      final isWorked = workedDays.any((d) => _sameDate(d, day));
      final advanceAmount = advancesByDay[key] ?? 0.0;
      final hasAdvance = advanceAmount > 0;
      final hasAdvanceWithoutWork = hasAdvance && !isWorked;
      final hasAdvanceWithWork = hasAdvance && isWorked;

      PdfColor bgColor = PdfColors.grey100;
      PdfColor borderColor = PdfColors.grey400;
      PdfColor textColor = PdfColors.black;
      String stateText = '-';

      if (isSunday) {
        bgColor = PdfColors.red100;
        borderColor = PdfColors.red300;
        textColor = PdfColors.red700;
        stateText = 'Pushim';
      } else if (hasAdvanceWithoutWork) {
        bgColor = PdfColors.red50;
        borderColor = PdfColors.red700;
        textColor = PdfColors.red800;
        stateText = 'Avans';
      } else if (hasAdvanceWithWork) {
        bgColor = PdfColors.orange50;
        borderColor = PdfColors.orange700;
        textColor = PdfColors.orange800;
        stateText = 'Punë+Av';
      } else if (isWorked) {
        bgColor = PdfColors.green100;
        borderColor = PdfColors.green300;
        textColor = PdfColors.green800;
        stateText = 'Punë';
      }

      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          decoration: pw.BoxDecoration(
            color: bgColor,
            border: pw.Border.all(
              color: borderColor,
              width: hasAdvance ? 1.5 : 1,
            ),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                dayNumber.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                stateText,
                style: pw.TextStyle(
                  fontSize: 6.8,
                  color: textColor,
                ),
              ),
              if (hasAdvance) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  _moneyShort(advanceAmount),
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return pw.GridView(
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      crossAxisSpacing: 4,
      mainAxisSpacing: 4,
      children: cells,
    );
  }

  static List<WorkerAdvance> _advancesForWorkerMonth(
    int? workerId,
    String month,
    List<WorkerAdvance> advances,
  ) {
    if (workerId == null) return const [];
    return advances
        .where((a) => a.workerId == workerId && a.month == month)
        .toList();
  }

  static double _advancesForRow(
    PayrollPdfRow row,
    List<WorkerAdvance> advances,
  ) {
    return _advancesForWorkerMonth(row.worker.id, row.entry.month, advances)
        .fold(0.0, (sum, a) => sum + a.amount);
  }

  static double _remainingForRow(
    PayrollPdfRow row,
    List<WorkerAdvance> advances,
  ) {
    final remaining = row.entry.grossSalary - _advancesForRow(row, advances);
    return remaining < 0 ? 0.0 : remaining;
  }

  static Map<String, double> _sumAdvancesByDay(List<WorkerAdvance> advances) {
    final map = <String, double>{};
    for (final item in advances) {
      final key = _dayKey(item.createdAt);
      map[key] = (map[key] ?? 0.0) + item.amount;
    }
    return map;
  }

  static String _dayKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  static Set<DateTime> _decodeWorkedDays(String? jsonText) {
    if (jsonText == null || jsonText.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List) return {};
      return decoded.map<DateTime>((e) {
        final parts = e.toString().split('-');
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }).toSet();
    } catch (_) {
      return {};
    }
  }

  static bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int _yearFromYm(String ym) {
    final parts = ym.split('-');
    if (parts.isEmpty) return DateTime.now().year;
    return int.tryParse(parts[0]) ?? DateTime.now().year;
  }

  static int _monthFromYm(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return DateTime.now().month;
    return int.tryParse(parts[1]) ?? DateTime.now().month;
  }

  static String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? 1;
    if (month < 1 || month > 12) return ym;
    return '${_monthNames[month - 1]} $year';
  }

  static String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  static String _money(double v) => 'EUR ${v.toStringAsFixed(2)}';
  static String _moneyShort(double v) => v.toStringAsFixed(0);

  static String _safe(String s) {
    return s
        .replaceAll('€', 'EUR')
        .replaceAll('→', '->')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('\u00A0', ' ');
  }

  static String _safeNum(num v) => v.toString();
}

class PayrollPdfRow {
  final Worker worker;
  final PayrollEntry entry;

  PayrollPdfRow(this.worker, this.entry);
}
