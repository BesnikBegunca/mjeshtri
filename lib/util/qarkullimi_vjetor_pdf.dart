import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/job_project.dart';

class QarkullimiVjetorPdf {
  QarkullimiVjetorPdf._();

  static Future<List<int>> buildForYear({
    required int year,
    required List<JobProject> jobs,
  }) async {
    final pdf = pw.Document();

    final rows = [...jobs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final totalJobs = rows.length;
    final totalQarkullimi =
        rows.fold<double>(0, (s, e) => s + e.contractAmount);
    final totalExpenses = rows.fold<double>(0, (s, e) => s + _expensesTotal(e));
    final totalInvestment =
        rows.fold<double>(0, (s, e) => s + _investmentTotal(e));
    final totalProfit = rows.fold<double>(0, (s, e) => s + _profit(e));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          _header('Qarkullimi Vjetor - $year'),
          pw.SizedBox(height: 10),
          _summaryRow(
            totalJobs: totalJobs,
            totalQarkullimi: totalQarkullimi,
            totalExpenses: totalExpenses,
            totalInvestment: totalInvestment,
            totalProfit: totalProfit,
          ),
          pw.SizedBox(height: 16),
          _jobsTable(rows),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<List<int>> buildAllJobs({
    required List<JobProject> jobs,
  }) async {
    final pdf = pw.Document();

    final years = jobs.map((e) => e.createdAt.year).toSet().toList()..sort();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          final widgets = <pw.Widget>[
            _header('Qarkullimi Vjetor - Krejt Vitet'),
            pw.SizedBox(height: 12),
          ];

          for (final year in years.reversed) {
            final rows = jobs.where((j) => j.createdAt.year == year).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

            final totalJobs = rows.length;
            final totalQarkullimi =
                rows.fold<double>(0, (s, e) => s + e.contractAmount);
            final totalExpenses =
                rows.fold<double>(0, (s, e) => s + _expensesTotal(e));
            final totalInvestment =
                rows.fold<double>(0, (s, e) => s + _investmentTotal(e));
            final totalProfit = rows.fold<double>(0, (s, e) => s + _profit(e));

            widgets.addAll([
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.grey300,
                child: pw.Text(
                  'Viti $year',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _summaryRow(
                totalJobs: totalJobs,
                totalQarkullimi: totalQarkullimi,
                totalExpenses: totalExpenses,
                totalInvestment: totalInvestment,
                totalProfit: totalProfit,
              ),
              pw.SizedBox(height: 10),
              _jobsTable(rows),
              pw.SizedBox(height: 18),
            ]);
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Gjeneruar më: ${_fmtDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _summaryRow({
    required int totalJobs,
    required double totalQarkullimi,
    required double totalExpenses,
    required double totalInvestment,
    required double totalProfit,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _sumBox('Punë gjithsej', totalJobs.toString()),
            pw.SizedBox(width: 8),
            _sumBox('Qarkullimi', _money(totalQarkullimi)),
            pw.SizedBox(width: 8),
            _sumBox('Shpenzime', _money(totalExpenses)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _sumBox('Investimi', _money(totalInvestment)),
            pw.SizedBox(width: 8),
            _sumBox('Fitimi', _money(totalProfit)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Container()),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sumBox(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _jobsTable(List<JobProject> jobs) {
    if (jobs.isEmpty) {
      return pw.Text('Nuk ka punë.');
    }

    final totalQarkullimi =
        jobs.fold<double>(0, (s, e) => s + e.contractAmount);
    final totalExpenses = jobs.fold<double>(0, (s, e) => s + _expensesTotal(e));
    final totalInvestment =
        jobs.fold<double>(0, (s, e) => s + _investmentTotal(e));
    final totalProfit = jobs.fold<double>(0, (s, e) => s + _profit(e));

    final data = <List<String>>[];

    for (var i = 0; i < jobs.length; i++) {
      final job = jobs[i];
      final expenses = _expensesTotal(job);
      final investment = _investmentTotal(job);
      final profit = _profit(job);

      data.add([
        '${i + 1}',
        _fmtDate(job.createdAt),
        job.name,
        job.clientName ?? '—',
        _money(job.contractAmount),
        _money(expenses),
        _money(investment),
        _money(profit),
      ]);
    }

    data.add([
      '',
      '',
      'TOTAL',
      '—',
      _money(totalQarkullimi),
      _money(totalExpenses),
      _money(totalInvestment),
      _money(totalProfit),
    ]);

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      headers: const [
        'Nr.',
        'Data',
        'Puna',
        'Klienti',
        'Qarkullimi',
        'Shpenzime',
        'Investimi',
        'Fitimi',
      ],
      data: data,
    );
  }

  static double _workersTotal(JobProject job) {
    return job.workerEntries.fold<double>(0.0, (sum, e) => sum + e.total);
  }

  static double _expensesTotal(JobProject job) {
    return job.expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  static double _investmentTotal(JobProject job) {
    return _workersTotal(job) + _expensesTotal(job);
  }

  static double _profit(JobProject job) {
    return job.contractAmount - _investmentTotal(job);
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _money(num value) {
    return '${value.toStringAsFixed(2)} EURO';
  }
}
