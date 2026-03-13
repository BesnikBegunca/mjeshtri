import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../page/punet_page.dart';

class JobReportPdf {
  static Future<List<int>> buildSingleJob({
    required JobProject job,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          _header('Raport i Punës / Objektit'),
          pw.SizedBox(height: 10),
          _jobInfo(job),
          pw.SizedBox(height: 16),
          _summary(job),
          pw.SizedBox(height: 20),
          _workersTable(job),
          pw.SizedBox(height: 20),
          _expensesTable(job),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<List<int>> buildAllJobs({
    required List<JobProject> jobs,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          final items = <pw.Widget>[
            _header('Raport i Krejt Punëve'),
            pw.SizedBox(height: 16),
            _allJobsTable(jobs),
          ];

          for (final job in jobs) {
            items.addAll([
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.grey200,
                child: pw.Text(
                  job.name,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _jobInfo(job),
              pw.SizedBox(height: 10),
              _summary(job),
            ]);
          }

          return items;
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

  static pw.Widget _jobInfo(JobProject job) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _line('Emri i punës', job.name),
          _line('Klienti', job.clientName ?? '—'),
          _line('Data', _fmtDate(job.createdAt)),
          _line('Qarkullimi', _money(job.contractAmount)),
          _line('Shënim', job.note ?? '—'),
        ],
      ),
    );
  }

  static pw.Widget _summary(JobProject job) {
    final workersTotal = _workersTotal(job);
    final expensesTotal = _expensesTotal(job);
    final investment = workersTotal + expensesTotal;
    final profit = job.contractAmount - investment;

    return pw.Row(
      children: [
        _sumBox('Punëtorë', _money(workersTotal)),
        pw.SizedBox(width: 8),
        _sumBox('Shpenzime', _money(expensesTotal)),
        pw.SizedBox(width: 8),
        _sumBox('Investimi', _money(investment)),
        pw.SizedBox(width: 8),
        _sumBox('Fitimi', _money(profit)),
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

  static pw.Widget _workersTable(JobProject job) {
    if (job.workerEntries.isEmpty) {
      return pw.Text('Nuk ka punëtorë të shtuar.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Punëtorët',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const [
            'Punëtori',
            'Pozita',
            'Ditë',
            'Pagesa ditore',
            'Totali',
            'Shënim',
          ],
          data: job.workerEntries
              .map(
                (e) => [
                  e.workerName,
                  e.workerPosition ?? '—',
                  e.days.toString(),
                  _money(e.dailyRate),
                  _money(e.total),
                  e.note ?? '—',
                ],
              )
              .toList(),
        ),
      ],
    );
  }

  static pw.Widget _expensesTable(JobProject job) {
    if (job.expenses.isEmpty) {
      return pw.Text('Nuk ka shpenzime të shtuara.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Shpenzimet',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const [
            'Përshkrimi',
            'Shuma',
            'Shënim',
          ],
          data: job.expenses
              .map(
                (e) => [
                  e.title,
                  _money(e.amount),
                  e.note ?? '—',
                ],
              )
              .toList(),
        ),
      ],
    );
  }

  static pw.Widget _allJobsTable(List<JobProject> jobs) {
    if (jobs.isEmpty) {
      return pw.Text('Nuk ka punë.');
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      headers: const [
        'Puna',
        'Klienti',
        'Qarkullimi',
        'Punëtorë',
        'Shpenzime',
        'Investimi',
        'Fitimi',
      ],
      data: jobs.map((job) {
        final workers = _workersTotal(job);
        final expenses = _expensesTotal(job);
        final investment = workers + expenses;
        final profit = job.contractAmount - investment;

        return [
          job.name,
          job.clientName ?? '—',
          _money(job.contractAmount),
          _money(workers),
          _money(expenses),
          _money(investment),
          _money(profit),
        ];
      }).toList(),
    );
  }

  static pw.Widget _line(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static double _workersTotal(JobProject job) {
    return job.workerEntries.fold(0, (sum, e) => sum + e.total);
  }

  static double _expensesTotal(JobProject job) {
    return job.expenses.fold(0, (sum, e) => sum + e.amount);
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