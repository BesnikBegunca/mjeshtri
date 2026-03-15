import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/dao_payroll.dart';
import '../data/dao_worker_advances.dart';
import '../data/dao_workers.dart';
import '../models/payroll_entry.dart';
import '../models/worker.dart';
import '../models/worker_advance.dart';
import '../util/format.dart';
import '../util/payroll_pdf.dart';

class PunetoretPage extends StatefulWidget {
  const PunetoretPage({super.key});

  @override
  State<PunetoretPage> createState() => _PunetoretPageState();
}

class _PunetoretPageState extends State<PunetoretPage> {
  bool loading = true;

  List<Worker> workers = [];
  Map<int, List<PayrollEntry>> payrollByWorker = {};
  final Set<int> expandedStatsWorkerIds = {};

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
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => loading = true);

    workers = await WorkersDao.I.list();

    final map = <int, List<PayrollEntry>>{};
    for (final w in workers) {
      if (w.id == null) continue;
      map[w.id!] = await PayrollDao.I.listForWorker(w.id!);
    }

    payrollByWorker = map;

    if (mounted) {
      setState(() => loading = false);
    }
  }

  // ==================== HELPERS ====================

  String _ymNow() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  int _monthFromYm(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return DateTime.now().month;
    final mm = int.tryParse(parts[1]) ?? DateTime.now().month;
    return mm.clamp(1, 12);
  }

  int _yearFromYm(String ym) {
    final parts = ym.split('-');
    if (parts.isEmpty) return DateTime.now().year;
    final yy = int.tryParse(parts[0]) ?? DateTime.now().year;
    return yy;
  }

  String _ymFromYearMonth(int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return '$year-$mm';
  }

  int _calcDaysInclusive(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    final diff = b.difference(a).inDays;
    return diff >= 0 ? diff + 1 : 0;
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym.toUpperCase();

    final mm = int.tryParse(parts[1]) ?? 0;
    if (mm < 1 || mm > 12) return ym.toUpperCase();
    return _monthNames[mm - 1];
  }

  List<PayrollEntry> _entriesForWorker(Worker worker) {
    if (worker.id == null) return [];
    return payrollByWorker[worker.id!] ?? [];
  }

  double _grossForWorker(Worker worker) {
    return _entriesForWorker(worker).fold(0.0, (sum, e) => sum + e.grossSalary);
  }

  double _netForWorker(Worker worker) {
    return _entriesForWorker(worker).fold(0.0, (sum, e) => sum + e.netSalary);
  }

  double _costForWorker(Worker worker) {
    return _entriesForWorker(worker)
        .fold(0.0, (sum, e) => sum + e.employerCost);
  }

  double get _totalGrossAll {
    return workers.fold(0.0, (sum, w) => sum + _grossForWorker(w));
  }

  double get _totalNetAll {
    return workers.fold(0.0, (sum, w) => sum + _netForWorker(w));
  }

  double get _totalCostAll {
    return workers.fold(0.0, (sum, w) => sum + _costForWorker(w));
  }

  int get _totalPayrollRowsAll {
    return workers.fold(0, (sum, w) => sum + _entriesForWorker(w).length);
  }

  PayrollEntry? _latestPayrollForWorker(Worker worker) {
    final list = [..._entriesForWorker(worker)];
    if (list.isEmpty) return null;
    list.sort((a, b) => b.month.compareTo(a.month));
    return list.first;
  }

  // ==================== WORKER ====================

  Future<void> _addWorker() async {
    final nameC = TextEditingController();
    final posC = TextEditingController(text: 'Punëtor');
    final salaryC = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shto punëtor'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: 'Emri',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: posC,
                decoration: const InputDecoration(
                  labelText: 'Pozita',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Rroga bazë (€)',
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

    final name = nameC.text.trim();
    if (name.isEmpty) return;

    final worker = Worker(
      fullName: name,
      position: posC.text.trim().isEmpty ? 'Punëtor' : posC.text.trim(),
      baseSalary: double.tryParse(salaryC.text.replaceAll(',', '.')) ?? 0,
    );

    await WorkersDao.I.insert(worker);
    await _loadWorkers();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Punëtori u shtua me sukses.')),
    );
  }

  Future<void> _deleteWorker(Worker w) async {
    if (w.id == null) return;

    final payrollForWorker = await PayrollDao.I.listForWorker(w.id!);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshij punëtorin'),
        content: Text(
          payrollForWorker.isEmpty
              ? 'A je i sigurt që don me fshi punëtorin "${w.fullName}"?'
              : 'Punëtori "${w.fullName}" ka ${payrollForWorker.length} pagesa/rroga të regjistruara.\n\nNëse vazhdon, do të fshihen edhe rrogat e tij.\n\nA don me vazhdu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Fshij krejt'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    for (final p in payrollForWorker) {
      if (p.id != null) {
        await PayrollDao.I.delete(p.id!);
      }
    }

    await WorkersDao.I.delete(w.id!);
    await _loadWorkers();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Punëtori "${w.fullName}" u fshi me sukses.')),
    );
  }

  // ==================== PAYROLL ====================

  Future<void> _payNowForWorker(Worker w) async {
    await _openPayrollEditor(worker: w, existing: null);
    await _loadWorkers();
  }

  Future<void> _openPayrollEditor({
    required Worker worker,
    PayrollEntry? existing,
  }) async {
    final nowYm = _ymNow();
    int year =
        existing == null ? _yearFromYm(nowYm) : _yearFromYm(existing.month);
    int month =
        existing == null ? _monthFromYm(nowYm) : _monthFromYm(existing.month);

    bool dailyPay = false;
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    final daysC = TextEditingController(text: '');
    final customPayC = TextEditingController(text: '');

    final grossC = TextEditingController(
      text: (existing?.grossSalary ?? worker.baseSalary).toStringAsFixed(2),
    );
    final empPctC = TextEditingController(
      text: (existing?.employeePct ?? 5).toString(),
    );
    final emrPctC = TextEditingController(
      text: (existing?.employerPct ?? 10).toString(),
    );
    final noteC = TextEditingController(text: existing?.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickFrom() async {
            final d = await showDatePicker(
              context: context,
              initialDate: fromDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            setLocal(() {
              fromDate = d;
              final days = _calcDaysInclusive(fromDate, toDate);
              if (days > 0) daysC.text = days.toString();
            });
          }

          Future<void> pickTo() async {
            final d = await showDatePicker(
              context: context,
              initialDate: toDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            setLocal(() {
              toDate = d;
              final days = _calcDaysInclusive(fromDate, toDate);
              if (days > 0) daysC.text = days.toString();
            });
          }

          void syncGrossFromCustom() {
            final v = double.tryParse(customPayC.text.replaceAll(',', '.'));
            if (v != null) {
              grossC.text = v.toStringAsFixed(2);
            }
          }

          final gross = double.tryParse(grossC.text.replaceAll(',', '.')) ?? 0;
          final emp = double.tryParse(empPctC.text.replaceAll(',', '.')) ?? 0;
          final emr = double.tryParse(emrPctC.text.replaceAll(',', '.')) ?? 0;

          final net = gross * (1.0 - emp / 100.0);
          final cost = gross * (1.0 + emr / 100.0);

          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Paguaj rrogë - ${worker.fullName}'
                  : 'Ndrysho rrogë - ${worker.fullName}',
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Muaji',
                              border: OutlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: month,
                                isDense: true,
                                items: List.generate(12, (i) {
                                  final m = i + 1;
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(_monthNames[i]),
                                  );
                                }),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setLocal(() => month = v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller:
                                TextEditingController(text: year.toString()),
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Viti',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: dailyPay,
                      onChanged: (v) {
                        setLocal(() {
                          dailyPay = v ?? false;
                          if (dailyPay) {
                            final days = _calcDaysInclusive(fromDate, toDate);
                            if (days > 0) daysC.text = days.toString();
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paguaj në ditë (Custom Pay)'),
                      subtitle: const Text(
                        'P.sh. 35€ për 10 ditë, prej date në date.',
                      ),
                    ),
                    if (dailyPay) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickFrom,
                              icon: const Icon(Icons.date_range),
                              label: Text('Prej: ${_fmtDate(fromDate)}'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickTo,
                              icon: const Icon(Icons.event),
                              label: Text('Deri: ${_fmtDate(toDate)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: daysC,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    'Sa ditë (auto nga datat ose shkruje vet)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: customPayC,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Custom Pay (€)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setLocal(syncGrossFromCustom),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: grossC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bruto (€)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: empPctC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Kontribut punëtori (%)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: emrPctC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Kontribut firma (%)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteC,
                      decoration: const InputDecoration(
                        labelText: 'Shënim',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text('Net: ${eur(net)}')),
                        Expanded(child: Text('Kosto: ${eur(cost)}')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anulo'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(existing == null ? 'Paguaj' : 'Ruaj'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final ym = _ymFromYearMonth(year, month);

    final customPay = double.tryParse(customPayC.text.replaceAll(',', '.'));
    if (dailyPay && customPay != null) {
      grossC.text = customPay.toStringAsFixed(2);
      final days =
          int.tryParse(daysC.text) ?? _calcDaysInclusive(fromDate, toDate);
      final tag =
          'DailyPay: ${customPay.toStringAsFixed(2)}€ | $days ditë | ${_fmtDate(fromDate)} → ${_fmtDate(toDate)}';
      final base = noteC.text.trim();
      noteC.text = base.isEmpty ? tag : '$base | $tag';
    }

    final model = PayrollEntry(
      id: existing?.id,
      workerId: worker.id!,
      month: ym,
      grossSalary: double.tryParse(grossC.text.replaceAll(',', '.')) ?? 0,
      employeePct: double.tryParse(empPctC.text.replaceAll(',', '.')) ?? 0,
      employerPct: double.tryParse(emrPctC.text.replaceAll(',', '.')) ?? 0,
      note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
    );

    if (existing == null) {
      await PayrollDao.I.insert(model);
    } else {
      await PayrollDao.I.update(model);
    }
  }

  // ==================== PDF ====================

  Future<void> _exportPdfForWorker(Worker w) async {
    final rows = _entriesForWorker(w).map((e) => PayrollPdfRow(w, e)).toList();

    await _savePdf(
      title: 'Rrogat - ${w.fullName} (${w.position})',
      rows: rows,
      filename: 'rrogat_${w.fullName.replaceAll(" ", "_")}.pdf',
    );
  }

  Future<void> _exportPdfAll() async {
    final rows = <PayrollPdfRow>[];
    for (final w in workers) {
      for (final e in _entriesForWorker(w)) {
        rows.add(PayrollPdfRow(w, e));
      }
    }

    await _savePdf(
      title: 'Raport Rrogash - Krejt Punëtorët',
      rows: rows,
      filename: 'raport_rrogash_krejt.pdf',
    );
  }

  Future<void> _savePdf({
    required String title,
    required List<PayrollPdfRow> rows,
    required String filename,
  }) async {
    if (rows.isEmpty) return;

    final bytes = await PayrollPdf.build(title: title, rows: rows);

    final loc = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (loc == null) return;

    final file = File(loc.path);
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF u ruajt: ${loc.path}')),
    );
  }

  Future<void> _openWorkerDetails(Worker worker) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkerDetailsPage(
          worker: worker,
          monthNames: _monthNames,
          monthLabelBuilder: _monthLabel,
          openPayrollEditor: ({
            required Worker worker,
            PayrollEntry? existing,
          }) async {
            await _openPayrollEditor(worker: worker, existing: existing);
          },
          deletePayroll: (int id) async {
            await PayrollDao.I.delete(id);
          },
          exportPdfWorker: _exportPdfForWorker,
          deleteWorker: _deleteWorker,
        ),
      ),
    );

    await _loadWorkers();
  }

  void _toggleStats(Worker worker) {
    if (worker.id == null) return;
    setState(() {
      if (expandedStatsWorkerIds.contains(worker.id!)) {
        expandedStatsWorkerIds.remove(worker.id!);
      } else {
        expandedStatsWorkerIds.add(worker.id!);
      }
    });
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Evidenca e Punëtorëve',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: workers.isEmpty ? null : _exportPdfAll,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF (krejt)'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _addWorker,
              icon: const Icon(Icons.person_add),
              label: const Text('Shto punëtor'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: workers.isEmpty
              ? Card(
                  child: Center(
                    child: Text(
                      'Nuk ka punëtorë të regjistruar.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: workers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final w = workers[index];
                    final latest = _latestPayrollForWorker(w);
                    final showStats =
                        w.id != null && expandedStatsWorkerIds.contains(w.id!);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openWorkerDetails(w),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      Colors.green.withOpacity(0.16),
                                  child: Text(
                                    w.fullName.isNotEmpty
                                        ? w.fullName.trim()[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openWorkerDetails(w),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.fullName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${w.position} • Rroga bazë: ${eur(w.baseSalary)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white70,
                                              ),
                                        ),
                                        if (latest != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Pagesa e fundit: ${_monthLabel(latest.month)} • Neto ${eur(latest.netSalary)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.white60,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _payNowForWorker(w),
                                    icon: const Icon(Icons.payments),
                                    label: const Text('PAGUAJ'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _toggleStats(w),
                                    icon: Icon(
                                      showStats
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                    ),
                                    label: Text(
                                      showStats
                                          ? 'Mshefi statistikat'
                                          : 'Shfaq statistikat',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _openWorkerDetails(w),
                                    icon: const Icon(Icons.arrow_forward_ios),
                                    label: const Text('Detajet'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (showStats) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _MiniInfoBadge(
                                  label: 'Pagesa',
                                  value: '${_entriesForWorker(w).length}',
                                  icon: Icons.receipt_long,
                                ),
                                _MiniInfoBadge(
                                  label: 'Bruto',
                                  value: eur(_grossForWorker(w)),
                                  icon: Icons.account_balance_wallet,
                                ),
                                _MiniInfoBadge(
                                  label: 'Neto',
                                  value: eur(_netForWorker(w)),
                                  icon: Icons.payments,
                                ),
                                _MiniInfoBadge(
                                  label: 'Kosto firmës',
                                  value: eur(_costForWorker(w)),
                                  icon: Icons.business_center,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TotalInfoCard(
                title: 'Totali punëtorëve',
                value: '${workers.length}',
                icon: Icons.groups,
              ),
              _TotalInfoCard(
                title: 'Totali pagesave',
                value: '$_totalPayrollRowsAll',
                icon: Icons.receipt_long,
              ),
              _TotalInfoCard(
                title: 'Totali Bruto',
                value: eur(_totalGrossAll),
                icon: Icons.account_balance_wallet,
              ),
              _TotalInfoCard(
                title: 'Totali Neto',
                value: eur(_totalNetAll),
                icon: Icons.payments,
              ),
              _TotalInfoCard(
                title: 'Totali Kosto',
                value: eur(_totalCostAll),
                icon: Icons.business_center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WorkerDetailsPage extends StatefulWidget {
  final Worker worker;
  final List<String> monthNames;
  final String Function(String ym) monthLabelBuilder;
  final Future<void> Function({
    required Worker worker,
    PayrollEntry? existing,
  }) openPayrollEditor;
  final Future<void> Function(int id) deletePayroll;
  final Future<void> Function(Worker worker) exportPdfWorker;
  final Future<void> Function(Worker worker) deleteWorker;

  const WorkerDetailsPage({
    super.key,
    required this.worker,
    required this.monthNames,
    required this.monthLabelBuilder,
    required this.openPayrollEditor,
    required this.deletePayroll,
    required this.exportPdfWorker,
    required this.deleteWorker,
  });

  @override
  State<WorkerDetailsPage> createState() => _WorkerDetailsPageState();
}

class _WorkerDetailsPageState extends State<WorkerDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool loading = true;
  List<PayrollEntry> payroll = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    payroll = widget.worker.id == null
        ? []
        : await PayrollDao.I.listForWorker(widget.worker.id!);
    if (mounted) {
      setState(() => loading = false);
    }
  }

  double get _totalGross {
    return payroll.fold(0.0, (sum, e) => sum + e.grossSalary);
  }

  double get _totalNet {
    return payroll.fold(0.0, (sum, e) => sum + e.netSalary);
  }

  double get _totalEmployerCost {
    return payroll.fold(0.0, (sum, e) => sum + e.employerCost);
  }

  Future<void> _editPayroll(PayrollEntry entry) async {
    await widget.openPayrollEditor(worker: widget.worker, existing: entry);
    await _load();
  }

  Future<void> _payNow() async {
    await widget.openPayrollEditor(worker: widget.worker, existing: null);
    await _load();
  }

  Future<void> _deletePayrollRow(PayrollEntry entry) async {
    if (entry.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshij rrogën'),
        content: const Text('A je i sigurt që don me fshi këtë pagesë/rrogë?'),
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

    await widget.deletePayroll(entry.id!);
    await _load();
  }

  Future<void> _deleteWorkerAndClose() async {
    await widget.deleteWorker(widget.worker);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;

    return Scaffold(
      appBar: AppBar(
        title: Text(w.fullName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rrogat'),
            Tab(text: 'Avancat'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.green.withOpacity(0.16),
                            child: Text(
                              w.fullName.isNotEmpty
                                  ? w.fullName.trim()[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${w.position} • Rroga bazë: ${eur(w.baseSalary)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _payNow,
                                icon: const Icon(Icons.payments),
                                label: const Text('PAGUAJ'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    widget.exportPdfWorker(widget.worker),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Printo rrogat'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _deleteWorkerAndClose,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Fshij punëtor'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _TotalInfoCard(
                            title: 'Totali Bruto',
                            value: eur(_totalGross),
                            icon: Icons.account_balance_wallet,
                          ),
                          _TotalInfoCard(
                            title: 'Totali Neto',
                            value: eur(_totalNet),
                            icon: Icons.payments,
                          ),
                          _TotalInfoCard(
                            title: 'Totali Kosto',
                            value: eur(_totalEmployerCost),
                            icon: Icons.business_center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Card(
                          child: payroll.isEmpty
                              ? Center(
                                  child: Text(
                                    'Ky punëtor nuk ka ende pagesa/rroga.',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
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
                                            DataColumn(label: Text('Muaji')),
                                            DataColumn(label: Text('Bruto')),
                                            DataColumn(
                                                label: Text('Net (punëtori)')),
                                            DataColumn(
                                                label: Text('Kosto (firma)')),
                                            DataColumn(label: Text('Shënim')),
                                            DataColumn(label: Text('Veprime')),
                                          ],
                                          rows: payroll.map((e) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  _MonthBadge(
                                                    widget.monthLabelBuilder(
                                                        e.month),
                                                  ),
                                                ),
                                                DataCell(
                                                  _MoneyBadge(
                                                    eur(e.grossSalary),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${eur(e.netSalary)} (${e.employeePct}%)',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${eur(e.employerCost)} (+${e.employerPct}%)',
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 220,
                                                    child: Text(
                                                      e.note?.trim().isEmpty ==
                                                              true
                                                          ? '—'
                                                          : (e.note ?? '—'),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        tooltip: 'Ndrysho',
                                                        icon: const Icon(
                                                            Icons.edit),
                                                        onPressed: () =>
                                                            _editPayroll(e),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Fshij',
                                                        icon: const Icon(
                                                            Icons.delete),
                                                        onPressed: () =>
                                                            _deletePayrollRow(
                                                                e),
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
                      WorkerAdvancesTab(worker: widget.worker),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class WorkerAdvancesTab extends StatefulWidget {
  final Worker worker;

  const WorkerAdvancesTab({
    super.key,
    required this.worker,
  });

  @override
  State<WorkerAdvancesTab> createState() => _WorkerAdvancesTabState();
}

class _WorkerAdvancesTabState extends State<WorkerAdvancesTab> {
  bool loading = true;
  String? errorText;

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
    _loadAdvances();
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

  Future<void> _loadAdvances() async {
    if (widget.worker.id == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        advances = [];
      });
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }

    try {
      final list = await WorkerAdvancesDao.I.listForWorkerMonth(
        widget.worker.id!,
        selectedYm,
      );

      if (!mounted) return;
      setState(() {
        advances = list;
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

  double get _baseSalary => widget.worker.baseSalary;

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
    if (widget.worker.id == null) return;

    final amountC = TextEditingController();
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Shto avancë - ${widget.worker.fullName}'),
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
        workerId: widget.worker.id!,
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
                  'Punëtori: ${widget.worker.fullName}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Pozita: ${widget.worker.position}',
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
    try {
      final bytes = await _buildPdfBytes();
      final fileName =
          'avancat_${_safeFileName(widget.worker.fullName)}_$selectedYm.pdf';

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
    try {
      final bytes = await _buildPdfBytes();

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'avancat_${_safeFileName(widget.worker.fullName)}_$selectedYm',
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
                onPressed: _loadAdvances,
                icon: const Icon(Icons.refresh),
                label: const Text('Provo prap'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Avancat - ${widget.worker.fullName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickMonthYear,
                icon: const Icon(Icons.calendar_month),
                label: Text(_monthLabel(selectedYm)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _previewPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Preview PDF'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saveAsPdf,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save as PDF'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addAdvance,
                icon: const Icon(Icons.add_card),
                label: const Text('Shto avancë'),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              child: advances.isEmpty
                  ? Center(
                      child: Text(
                        'Nuk ka avancë për ${widget.worker.fullName} në ${_monthLabel(selectedYm)}.',
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
                                    DataCell(_AdvanceMoneyBadge(eur(e.amount))),
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
                                            onPressed: () => _deleteAdvance(e),
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
      ),
    );
  }
}

class _MonthBadge extends StatelessWidget {
  final String text;
  const _MonthBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.85),
              letterSpacing: 0.6,
            ),
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
        color: Colors.green.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.greenAccent,
            ),
      ),
    );
  }
}

class _AdvanceMoneyBadge extends StatelessWidget {
  final String text;
  const _AdvanceMoneyBadge(this.text);

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

class _MiniInfoBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniInfoBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _TotalInfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.16),
            child: Icon(icon, color: Colors.greenAccent),
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
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ],
      ),
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
