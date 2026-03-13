import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll_entry.dart';
import '../models/worker.dart';

class PayrollPdf {
  static Future<Uint8List> build({
    required String title,
    required List<PayrollPdfRow> rows,
  }) async {
    final doc = pw.Document();

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
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: const [
              'Punëtori',
              'Muaji',
              'Bruto (EUR)',
              'Net (punëtori)',
              'Kosto (firma)',
              'Shënim',
            ],
            data: rows.map((r) {
              final w = r.worker;
              final e = r.entry;

              return [
                _safe('${w.fullName} (${w.position})'),
                _safe(e.month),
                _money(e.grossSalary),
                '${_money(e.netSalary)} (${_safeNum(e.employeePct)}%)',
                '${_money(e.employerCost)} (+${_safeNum(e.employerPct)}%)',
                _safe(e.note ?? ''),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// ✅ Format i sigurt për PDF (pa simbol €)
  static String _money(double v) => 'EUR ${v.toStringAsFixed(2)}';

  /// ✅ Që mos me fut karaktere që s’i përkrah fonti default i PDF
  static String _safe(String s) {
    return s
        .replaceAll('€', 'EUR')
        .replaceAll('→', '->')
        .replaceAll('–', '-') // en dash
        .replaceAll('—', '-') // em dash
        .replaceAll('\u00A0', ' '); // nbsp
  }

  static String _safeNum(num v) => v.toString();
}

class PayrollPdfRow {
  final Worker worker;
  final PayrollEntry entry;

  PayrollPdfRow(this.worker, this.entry);
}
