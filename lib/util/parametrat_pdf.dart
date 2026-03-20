import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ParametratPdf {
  static Future<Uint8List> buildOffer({
    required String offerNo,
    required DateTime offerDate,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String companyNuis,
    required String companyFiscalNo,
    required String clientName,
    required String clientAddress,
    required String clientPhone,
    required String clientEmail,
    required String category,
    required String workName,
    required String unit,
    required double quantity,
    required double unitPrice,
    required double subtotal,
    required String discountLabel,
    required double discountAmount,
    required double total,
    required String notes,
  }) async {
    final doc = pw.Document();

    String fmt(double v) => '${v.toStringAsFixed(2)} EURO';
    String safe(String v) => v.trim().isEmpty ? '-' : v.trim();
    String dateText(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        safe(companyName),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Adresa: ${safe(companyAddress)}'),
                      pw.Text('Telefon: ${safe(companyPhone)}'),
                      pw.Text('Email: ${safe(companyEmail)}'),
                      pw.Text('NUIS / Biznesi: ${safe(companyNuis)}'),
                      pw.Text('Nr. fiskal: ${safe(companyFiscalNo)}'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OFERTË / FATURË',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Nr: ${safe(offerNo)}'),
                      pw.Text('Data: ${dateText(offerDate)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Të dhënat e klientit',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Emri: ${safe(clientName)}'),
                      pw.Text('Adresa: ${safe(clientAddress)}'),
                      pw.Text('Telefon: ${safe(clientPhone)}'),
                      pw.Text('Email: ${safe(clientEmail)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Përshkrimi i ofertës',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.8,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.7),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(0.9),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                children: [
                  _cell('Nr', bold: true, align: pw.TextAlign.center),
                  _cell('Përshkrimi', bold: true),
                  _cell('Kategoria', bold: true),
                  _cell('Sasia', bold: true, align: pw.TextAlign.right),
                  _cell('Çmimi', bold: true, align: pw.TextAlign.right),
                  _cell('Totali', bold: true, align: pw.TextAlign.right),
                ],
              ),
              pw.TableRow(
                children: [
                  _cell('1', align: pw.TextAlign.center),
                  _cell(workName),
                  _cell(safe(category)),
                  _cell(
                    '${quantity.toStringAsFixed(2)} $unit',
                    align: pw.TextAlign.right,
                  ),
                  _cell(fmt(unitPrice), align: pw.TextAlign.right),
                  _cell(fmt(subtotal), align: pw.TextAlign.right),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _summaryRow('Nën-total', fmt(subtotal)),
                  _summaryRow(discountLabel, fmt(discountAmount)),
                  pw.Divider(color: PdfColors.grey500),
                  _summaryRow(
                    'TOTALI FINAL',
                    fmt(total),
                    bold: true,
                    bigger: true,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 18),
          if (notes.trim().isNotEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Shënime',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(notes),
                ],
              ),
            ),
          pw.SizedBox(height: 32),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Pala ofertuese',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      height: 1,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(safe(companyName)),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Klienti',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Container(
                      height: 1,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(safe(clientName)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    bool bigger = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bigger ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bigger ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
