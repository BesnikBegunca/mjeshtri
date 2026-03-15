import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/dao_worker_advances.dart';
import '../data/dao_workers.dart';
import '../models/worker.dart';
import '../models/worker_advance.dart';
import '../util/format.dart';

class AvancatPage extends StatefulWidget {
  const AvancatPage({super.key});

  @override
  State<AvancatPage> createState() => _AvancatPageState();
}

class _AvancatPageState extends State<AvancatPage> {
  bool loading = true;
  String? errorText;

  List<Worker> workers = [];
  Worker? selectedWorker;

  List<WorkerAdvance> advances = [];

  late int selectedYear;
  late int selectedMonth;

  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    _loadAll();
  }

  String get selectedYm =>
      '${selectedYear.toString().padLeft(4, '0')}-${selectedMonth.toString().padLeft(2, '0')}';

  String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;

    final mm = int.tryParse(parts[1]) ?? 0;
    final yy = int.tryParse(parts[0]) ?? DateTime.now().year;

    if (mm < 1 || mm > 12) return ym;
    return '${_monthNames[mm - 1]} $yy';
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  String _fmtPdfMoney(double value) {
    return '${value.toStringAsFixed(2)} EURO';
  }

  String _safeFileName(String text) {
    return text
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(' ', '_')
        .trim();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }

    try {
      final loadedWorkers = await WorkersDao.I.list();

      Worker? nextSelected;
      List<WorkerAdvance> nextAdvances = [];

      if (loadedWorkers.isNotEmpty) {
        if (selectedWorker != null) {
          final found = loadedWorkers.where((w) => w.id == selectedWorker!.id);
          nextSelected = found.isNotEmpty ? found.first : loadedWorkers.first;
        } else {
          nextSelected = loadedWorkers.first;
        }

        if (nextSelected.id != null) {
          nextAdvances = await WorkerAdvancesDao.I.listForWorkerMonth(
            nextSelected.id!,
            selectedYm,
          );
        }
      }

      if (!mounted) return;

      setState(() {
        workers = loadedWorkers;
        selectedWorker = nextSelected;
        advances = nextAdvances;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = e.toString();
      });
    }
  }

  Future<void> _loadAdvances() async {
    final w = selectedWorker;
    if (w == null || w.id == null) {
      if (!mounted) return;
      setState(() {
        advances = [];
        errorText = null;
      });
      return;
    }

    try {
      final list =
          await WorkerAdvancesDao.I.listForWorkerMonth(w.id!, selectedYm);

      if (!mounted) return;
      setState(() {
        advances = list;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        advances = [];
      });
    }
  }

  Future<void> _refreshPage() async {
    await _loadAll();
  }

  Future<void> _selectWorker(Worker? w) async {
    if (!mounted) return;
    setState(() {
      selectedWorker = w;
      errorText = null;
    });
    await _loadAdvances();
  }

  double get _baseSalary => selectedWorker?.baseSalary ?? 0;

  double get _totalAdvances {
    return advances.fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _remainingSalary {
    return _baseSalary - _totalAdvances;
  }

  bool get _isRemainingNegative => _remainingSalary < 0;

  Future<void> _pickMonthYear() async {
    int tempMonth = selectedMonth;
    final yearC = TextEditingController(text: selectedYear.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Zgjedh muajin'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Muaji',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: tempMonth,
                        items: List.generate(12, (i) {
                          return DropdownMenuItem(
                            value: i + 1,
                            child: Text(_monthNames[i]),
                          );
                        }),
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => tempMonth = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Viti',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anulo'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ruaj'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    selectedMonth = tempMonth;
    selectedYear = int.tryParse(yearC.text.trim()) ?? DateTime.now().year;

    await _loadAdvances();
  }

  Future<void> _addAdvance() async {
    final w = selectedWorker;
    if (w == null || w.id == null) return;

    final amountC = TextEditingController();
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Shto avancë - ${w.fullName}'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Shuma (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(
                  labelText: 'Shënim',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;

    try {
      final item = WorkerAdvance(
        workerId: w.id!,
        month: selectedYm,
        amount: amount,
        note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
        createdAt: DateTime.now(),
      );

      await WorkerAdvancesDao.I.insert(item);
      await _loadAdvances();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avanca u shtua me sukses.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë shtimit: $e')),
      );
    }
  }

  Future<void> _editAdvance(WorkerAdvance item) async {
    final amountC = TextEditingController(text: item.amount.toStringAsFixed(2));
    final noteC = TextEditingController(text: item.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ndrysho avancën'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Shuma (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(
                  labelText: 'Shënim',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final amount = double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;

    try {
      final updated = item.copyWith(
        amount: amount,
        note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      );

      await WorkerAdvancesDao.I.update(updated);
      await _loadAdvances();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avanca u ndryshua me sukses.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë ndryshimit: $e')),
      );
    }
  }

  Future<void> _deleteAdvance(WorkerAdvance item) async {
    if (item.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshij avancën'),
        content: const Text('A je i sigurt që don me fshi këtë avancë?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fshij'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await WorkerAdvancesDao.I.delete(item.id!);
      await _loadAdvances();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avanca u fshi me sukses.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë fshirjes: $e')),
      );
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();

    final worker = selectedWorker;
    final monthLabel = _monthLabel(selectedYm);
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey400,
                  width: 1,
                ),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RAPORTI I AVANCAVE',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Punëtori: ${worker?.fullName ?? '-'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Pozita: ${worker?.position ?? '-'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Muaji: $monthLabel',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Data e gjenerimit: ${_fmtDate(now)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _pdfSummaryCard(
                title: 'Rroga bazë',
                value: _fmtPdfMoney(_baseSalary),
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                title: 'Gjithsej avancë',
                value: _fmtPdfMoney(_totalAdvances),
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                title: 'I mbesin pa marrë',
                value: _fmtPdfMoney(_remainingSalary),
                highlight: !_isRemainingNegative,
                negative: _isRemainingNegative,
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          advances.isEmpty
              ? pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'Nuk ka avancë për këtë punëtor në këtë muaj.',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                )
              : pw.TableHelper.fromTextArray(
                  headers: const [
                    'Data',
                    'Muaji',
                    'Avanca',
                    'Shënim',
                  ],
                  data: advances.map((e) {
                    return [
                      _fmtDate(e.createdAt),
                      _monthLabel(e.month),
                      _fmtPdfMoney(e.amount),
                      (e.note == null || e.note!.trim().isEmpty)
                          ? '-'
                          : e.note!,
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 10,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(70),
                    1: const pw.FixedColumnWidth(85),
                    2: const pw.FixedColumnWidth(90),
                    3: const pw.FlexColumnWidth(),
                  },
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.6,
                  ),
                  rowDecoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                  ),
                  oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfSummaryCard({
    required String title,
    required String value,
    bool highlight = false,
    bool negative = false,
  }) {
    final bgColor = negative
        ? PdfColors.red50
        : (highlight ? PdfColors.green50 : PdfColors.grey100);

    final borderColor = negative
        ? PdfColors.red300
        : (highlight ? PdfColors.green300 : PdfColors.grey400);

    final valueColor = negative
        ? PdfColors.red800
        : (highlight ? PdfColors.green800 : PdfColors.black);

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: borderColor),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsPdf() async {
    final worker = selectedWorker;
    if (worker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Së pari zgjedhe punëtorin.')),
      );
      return;
    }

    try {
      final bytes = await _buildPdfBytes();
      final fileName =
          'avancat_${_safeFileName(worker.fullName)}_${selectedYm}.pdf';

      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
          ),
        ],
      );

      if (location != null) {
        final file = File(location.path);
        await file.writeAsBytes(bytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF u ruajt me sukses:\n${file.path}')),
        );
        return;
      }

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë ruajtjes së PDF: $e')),
      );
    }
  }

  Future<void> _previewPdf() async {
    final worker = selectedWorker;
    if (worker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Së pari zgjedhe punëtorin.')),
      );
      return;
    }

    try {
      final bytes = await _buildPdfBytes();

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'avancat_${_safeFileName(worker.fullName)}_${selectedYm}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë hapjes së PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ka ndodhë një gabim gjatë ngarkimit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                errorText!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Provo prap'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Menaxhimi i Avancave',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshPage,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: selectedWorker == null ? null : _previewPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Preview PDF'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: selectedWorker == null ? null : _saveAsPdf,
              icon: const Icon(Icons.save_alt),
              label: const Text('Save as PDF'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: selectedWorker == null ? null : _addAdvance,
              icon: const Icon(Icons.add_card),
              label: const Text('Shto avancë'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickMonthYear,
              icon: const Icon(Icons.calendar_month),
              label: Text(_monthLabel(selectedYm)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 520,
          child: DropdownButtonFormField<Worker>(
            value: selectedWorker,
            items: workers
                .map(
                  (w) => DropdownMenuItem(
                    value: w,
                    child: Text('${w.fullName} • ${w.position}'),
                  ),
                )
                .toList(),
            onChanged: workers.isEmpty ? null : _selectWorker,
            decoration: const InputDecoration(
              labelText: 'Zgjedh punëtorin',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (selectedWorker != null)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AdvanceInfoCard(
                title: 'Rroga bazë',
                value: eur(_baseSalary),
                icon: Icons.account_balance_wallet,
              ),
              _AdvanceInfoCard(
                title: 'Gjithsej avancë',
                value: eur(_totalAdvances),
                icon: Icons.remove_circle_outline,
              ),
              _AdvanceInfoCard(
                title: 'I mbesin pa marrë',
                value: eur(_remainingSalary),
                icon: Icons.payments,
                highlight: !_isRemainingNegative,
                negative: _isRemainingNegative,
              ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: selectedWorker == null
                ? Center(
                    child: Text(
                      'Nuk ka punëtorë të regjistruar.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : advances.isEmpty
                    ? Center(
                        child: Text(
                          'Nuk ka avancë për ${selectedWorker!.fullName} në ${_monthLabel(selectedYm)}.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Data')),
                                  DataColumn(label: Text('Muaji')),
                                  DataColumn(label: Text('Avanca')),
                                  DataColumn(label: Text('Shënim')),
                                  DataColumn(label: Text('Veprime')),
                                ],
                                rows: advances.map((e) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(_fmtDate(e.createdAt))),
                                      DataCell(Text(_monthLabel(e.month))),
                                      DataCell(_MoneyBadge(eur(e.amount))),
                                      DataCell(Text(e.note ?? '—')),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Ndrysho',
                                              icon: const Icon(Icons.edit),
                                              onPressed: () => _editAdvance(e),
                                            ),
                                            IconButton(
                                              tooltip: 'Fshij',
                                              icon: const Icon(Icons.delete),
                                              onPressed: () =>
                                                  _deleteAdvance(e),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

class _AdvanceInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool highlight;
  final bool negative;

  const _AdvanceInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = negative
        ? Colors.red.withOpacity(0.45)
        : highlight
            ? Colors.green.withOpacity(0.40)
            : Colors.white.withOpacity(0.10);

    final bgColor = negative
        ? Colors.red.withOpacity(0.10)
        : highlight
            ? Colors.green.withOpacity(0.10)
            : Colors.white.withOpacity(0.05);

    final avatarBg = negative
        ? Colors.red.withOpacity(0.18)
        : highlight
            ? Colors.green.withOpacity(0.18)
            : Colors.white.withOpacity(0.08);

    final iconColor = negative
        ? Colors.redAccent
        : highlight
            ? Colors.greenAccent
            : Colors.white;

    final valueColor = negative
        ? Colors.redAccent
        : highlight
            ? Colors.greenAccent
            : Colors.white;

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarBg,
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyBadge extends StatelessWidget {
  final String text;
  const _MoneyBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.orangeAccent,
            ),
      ),
    );
  }
}
