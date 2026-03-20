import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll_entry.dart';
import '../models/worker.dart';

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
              'Net (punëtori)',
              'Kosto (firma)',
              'Shënim',
            ],
            data: [
              ...rows.map((r) {
                final w = r.worker;
                final e = r.entry;

                return [
                  _safe('${w.fullName} (${w.position})'),
                  _safe(_monthLabel(e.month)),
                  e.workedDaysCount.toString(),
                  _money(e.dailyRate),
                  _money(e.grossSalary),
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
                _payrollCard(r),
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
  }) {
    return pw.Row(
      children: [
        _sumBox('Totali Ditëve', totalWorkedDays.toString()),
        pw.SizedBox(width: 8),
        _sumBox('Totali Bruto', _money(totalGross), highlight: true),
        pw.SizedBox(width: 8),
        _sumBox('Totali Neto', _money(totalNet)),
        pw.SizedBox(width: 8),
        _sumBox('Totali Kosto', _money(totalEmployerCost)),
      ],
    );
  }

  static pw.Widget _sumBox(
    String title,
    String value, {
    bool highlight = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: highlight ? PdfColors.green50 : PdfColors.grey100,
          border: pw.Border.all(
            color: highlight ? PdfColors.green300 : PdfColors.grey400,
          ),
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
                color: highlight ? PdfColors.green800 : PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _payrollCard(PayrollPdfRow row) {
    final worker = row.worker;
    final entry = row.entry;
    final workedDays = _decodeWorkedDays(entry.workedDaysJson);

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
            'Kalendari i ditëve të punës',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _calendarGrid(
            monthYm: entry.month,
            workedDays: workedDays,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _legendBox(PdfColors.green100, PdfColors.green700, 'Punë'),
              pw.SizedBox(width: 10),
              _legendBox(PdfColors.red100, PdfColors.red700, 'Pushim / E diel'),
              pw.SizedBox(width: 10),
              _legendBox(PdfColors.grey100, PdfColors.grey700, 'Pa punë'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniBox(
    String title,
    String value, {
    bool green = false,
  }) {
    return pw.Container(
      width: 105,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: green ? PdfColors.green50 : PdfColors.grey100,
        border: pw.Border.all(
          color: green ? PdfColors.green300 : PdfColors.grey400,
        ),
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
              color: green ? PdfColors.green800 : PdfColors.black,
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
      final isSunday = day.weekday == DateTime.sunday;
      final isSelected = workedDays.any((d) => _sameDate(d, day));

      PdfColor bgColor = PdfColors.grey100;
      PdfColor borderColor = PdfColors.grey400;
      PdfColor textColor = PdfColors.black;

      if (isSunday) {
        bgColor = PdfColors.red100;
        borderColor = PdfColors.red300;
        textColor = PdfColors.red700;
      } else if (isSelected) {
        bgColor = PdfColors.green100;
        borderColor = PdfColors.green300;
        textColor = PdfColors.green800;
      }

      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            color: bgColor,
            border: pw.Border.all(color: borderColor),
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
                isSunday ? 'Pushim' : (isSelected ? 'Punë' : '-'),
                style: pw.TextStyle(
                  fontSize: 7,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.GridView(
      crossAxisCount: 7,
      childAspectRatio: 1.1,
      crossAxisSpacing: 4,
      mainAxisSpacing: 4,
      children: cells,
    );
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

  static String _money(double v) => 'EUR ${v.toStringAsFixed(2)}';

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
