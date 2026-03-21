import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
  Map<int, List<WorkerAdvance>> advancesByWorker = {};
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

    final payrollMap = <int, List<PayrollEntry>>{};
    final advanceMap = <int, List<WorkerAdvance>>{};
    for (final w in workers) {
      if (w.id == null) continue;
      final payrollList = await PayrollDao.I.listForWorker(w.id!);
      payrollList.sort((a, b) => b.month.compareTo(a.month));
      payrollMap[w.id!] = payrollList;

      final advanceList = await WorkerAdvancesDao.I.listForWorker(w.id!);
      advanceList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      advanceMap[w.id!] = advanceList;
    }

    payrollByWorker = payrollMap;
    advancesByWorker = advanceMap;

    if (mounted) {
      setState(() => loading = false);
    }
  }

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
    return int.tryParse(parts[0]) ?? DateTime.now().year;
  }

  String _ymFromYearMonth(int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return '$year-$mm';
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
    final yy = int.tryParse(parts[0]) ?? DateTime.now().year;
    if (mm < 1 || mm > 12) return ym.toUpperCase();
    return '${_monthNames[mm - 1]} $yy';
  }

  List<PayrollEntry> _entriesForWorker(Worker worker) {
    if (worker.id == null) return [];
    return payrollByWorker[worker.id!] ?? [];
  }

  List<WorkerAdvance> _advancesForWorker(Worker worker) {
    if (worker.id == null) return [];
    return advancesByWorker[worker.id!] ?? [];
  }

  double _advancesTotalForWorker(Worker worker) {
    return _advancesForWorker(worker).fold(0.0, (sum, e) => sum + e.amount);
  }

  double _remainingForWorker(Worker worker) {
    return math.max(
        0.0, _grossForWorker(worker) - _advancesTotalForWorker(worker));
  }

  PayrollEntry? _entryForWorkerMonth(Worker worker, String ym) {
    final list = _entriesForWorker(worker);
    for (final e in list) {
      if (e.month == ym) return e;
    }
    return null;
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

  int _workedDaysForWorker(Worker worker) {
    return _entriesForWorker(worker)
        .fold(0, (sum, e) => sum + e.workedDaysCount);
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

  double get _totalAdvancesAll {
    return workers.fold(0.0, (sum, w) => sum + _advancesTotalForWorker(w));
  }

  double get _totalRemainingAll {
    return workers.fold(0.0, (sum, w) => sum + _remainingForWorker(w));
  }

  int get _totalPayrollRowsAll {
    return workers.fold(0, (sum, w) => sum + _entriesForWorker(w).length);
  }

  int get _totalWorkedDaysAll {
    return workers.fold(0, (sum, w) => sum + _workedDaysForWorker(w));
  }

  PayrollEntry? _latestPayrollForWorker(Worker worker) {
    final list = [..._entriesForWorker(worker)];
    if (list.isEmpty) return null;
    list.sort((a, b) => b.month.compareTo(a.month));
    return list.first;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Set<DateTime> _decodeWorkedDays(String? jsonText) {
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

  bool _isSunday(DateTime d) => d.weekday == DateTime.sunday;

  Future<void> _addWorker() async {
    final nameC = TextEditingController();
    final posC = TextEditingController(text: 'Punëtor');
    final dailyRateC = TextEditingController(text: '35');

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
                controller: dailyRateC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Pagesa për ditë (€)',
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
      baseSalary: double.tryParse(dailyRateC.text.replaceAll(',', '.')) ?? 35,
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
              : 'Punëtori "${w.fullName}" ka ${payrollForWorker.length} rroga të regjistruara.\n\nNëse vazhdon, do të fshihen edhe rrogat e tij.\n\nA don me vazhdu?',
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

  Future<void> _payNowForWorker(Worker w) async {
    final ym = _ymNow();
    final existing = _entryForWorkerMonth(w, ym);

    if (existing != null) {
      await _openPayrollEditor(
        worker: w,
        existing: existing,
        lockToExistingMonth: true,
      );
    } else {
      await _openPayrollEditor(
        worker: w,
        existing: null,
        fixedYm: ym,
      );
    }

    await _loadWorkers();
  }

  Future<void> _openPayrollEditor({
    required Worker worker,
    PayrollEntry? existing,
    bool lockToExistingMonth = false,
    String? fixedYm,
  }) async {
    if (worker.id == null) return;

    final seedYm = fixedYm ?? existing?.month ?? _ymNow();
    int year = _yearFromYm(seedYm);
    int month = _monthFromYm(seedYm);

    final dailyRateC = TextEditingController(
      text: ((existing?.dailyRate ?? worker.baseSalary) <= 0
              ? 35
              : (existing?.dailyRate ?? worker.baseSalary))
          .toStringAsFixed(2),
    );
    final empPctC = TextEditingController(
      text: (existing?.employeePct ?? 5).toString(),
    );
    final emrPctC = TextEditingController(
      text: (existing?.employerPct ?? 10).toString(),
    );
    final noteC = TextEditingController(text: existing?.note ?? '');

    Set<DateTime> workedDays =
        _decodeWorkedDays(existing?.workedDaysJson).map(_dateOnly).toSet();

    List<WorkerAdvance> monthAdvances =
        await WorkerAdvancesDao.I.listForWorkerMonth(worker.id!, seedYm);

    Future<PayrollEntry?> findMonthEntry() async {
      final ym = _ymFromYearMonth(year, month);
      return PayrollDao.I.findForWorkerMonth(worker.id!, ym);
    }

    Future<List<WorkerAdvance>>
        ltc1q7mhxnw82zyzkjvdtv57geqjjsw0mhgrvq6nx83() async {
      final ym = _ymFromYearMonth(year, month);
      final list = await WorkerAdvancesDao.I.listForWorkerMonth(worker.id!, ym);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    List<WorkerAdvance> advancesForDay(DateTime day) {
      return monthAdvances.where((a) => _sameDate(a.createdAt, day)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    double totalAdvanceForDay(DateTime day) {
      return advancesForDay(day).fold(0.0, (sum, item) => sum + item.amount);
    }

    Future<void> refreshMonthAdvances(StateSetter setLocal) async {
      final refreshed = await ltc1q7mhxnw82zyzkjvdtv57geqjjsw0mhgrvq6nx83();
      setLocal(() {
        monthAdvances = refreshed;
      });
    }

    Future<void> openAdvanceDialogForDay(
      BuildContext dialogContext,
      StateSetter setLocal,
      DateTime day,
    ) async {
      final normalizedDay = _dateOnly(day);

      final amountC = TextEditingController();
      final noteC = TextEditingController();

      final result = await showDialog<bool>(
        context: dialogContext,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final dayItems = advancesForDay(normalizedDay);
              final dayTotal = dayItems.fold<double>(
                0.0,
                (sum, item) => sum + item.amount,
              );

              Future<void> reloadDayItems() async {
                final refreshed =
                    await ltc1q7mhxnw82zyzkjvdtv57geqjjsw0mhgrvq6nx83();
                setLocal(() {
                  monthAdvances = refreshed;
                });
                setSheetState(() {});
              }

              Future<void> addAdvanceForDay() async {
                final amount =
                    double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
                if (amount <= 0) return;

                final item = WorkerAdvance(
                  workerId: worker.id!,
                  month: _ymFromYearMonth(year, month),
                  amount: amount,
                  note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
                  createdAt: normalizedDay,
                );

                await WorkerAdvancesDao.I.insert(item);
                amountC.clear();
                noteC.clear();
                await reloadDayItems();
              }

              Future<void> deleteAdvanceForDay(WorkerAdvance item) async {
                if (item.id == null) return;
                await WorkerAdvancesDao.I.delete(item.id!);
                await reloadDayItems();
              }

              return AlertDialog(
                title: Text(
                  'Avansë për ${normalizedDay.day.toString().padLeft(2, '0')}.${normalizedDay.month.toString().padLeft(2, '0')}.${normalizedDay.year}',
                ),
                content: SizedBox(
                  width: 470,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.30),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gjithsej avansë për këtë ditë: ${eur(dayTotal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dayItems.isEmpty
                                    ? 'Ende nuk ka avansë për këtë ditë.'
                                    : 'Këto janë avansat e ruajtura për këtë ditë${workedDays.any((d) => _sameDate(d, normalizedDay)) ? ' pune' : ''}.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (dayItems.isNotEmpty) ...[
                          ...dayItems.map((item) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          eur(item.amount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.note == null ||
                                                  item.note!.trim().isEmpty
                                              ? 'Pa shënim'
                                              : item.note!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.78,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Fshij avancën',
                                    onPressed: () => deleteAdvanceForDay(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                        TextField(
                          controller: amountC,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Shuma e avansës (€)',
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
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Mbyll'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await addAdvanceForDay();
                    },
                    icon: const Icon(Icons.add_card),
                    label: const Text('Shto avans'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != null) {
        await refreshMonthAdvances(setLocal);
      } else {
        await refreshMonthAdvances(setLocal);
      }
    }

    void syncWorkedDaysMonth() {
      workedDays =
          workedDays.where((d) => d.year == year && d.month == month).toSet();
    }

    syncWorkedDaysMonth();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          syncWorkedDaysMonth();

          final daysInMonth = DateTime(year, month + 1, 0).day;
          final firstDay = DateTime(year, month, 1);
          final leadingEmpty = firstDay.weekday - 1;

          final dailyRate =
              double.tryParse(dailyRateC.text.replaceAll(',', '.')) ?? 0;
          final emp = double.tryParse(empPctC.text.replaceAll(',', '.')) ?? 0;
          final emr = double.tryParse(emrPctC.text.replaceAll(',', '.')) ?? 0;

          final workedCount = workedDays.length;
          final gross = dailyRate * workedCount;
          final net = gross * (1.0 - emp / 100.0);
          final cost = gross * (1.0 + emr / 100.0);

          void toggleDay(DateTime day) {
            if (_isSunday(day)) return;
            final normalized = _dateOnly(day);

            setLocal(() {
              final exists = workedDays.any((d) => _sameDate(d, normalized));
              if (exists) {
                workedDays.removeWhere((d) => _sameDate(d, normalized));
              } else {
                workedDays.add(normalized);
              }
            });
          }

          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Rroga mujore - ${worker.fullName}'
                  : 'Ndrysho rrogën - ${worker.fullName}',
            ),
            content: SizedBox(
              width: 860,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existing == null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.30),
                          ),
                        ),
                        child: Text(
                          'Për çdo muaj ruhet vetëm 1 rrogë. Nëse rroga ekziston për muajin e zgjedhur, ajo do të përditësohet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
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
                                isExpanded: true,
                                items: List.generate(12, (i) {
                                  final m = i + 1;
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(_monthNames[i]),
                                  );
                                }),
                                onChanged: lockToExistingMonth
                                    ? null
                                    : (v) async {
                                        if (v == null) return;
                                        month = v;
                                        final monthEntry =
                                            await findMonthEntry();
                                        final monthAdvanceList =
                                            await ltc1q7mhxnw82zyzkjvdtv57geqjjsw0mhgrvq6nx83();

                                        setLocal(() {
                                          workedDays = _decodeWorkedDays(
                                            monthEntry?.workedDaysJson,
                                          ).map(_dateOnly).toSet();

                                          dailyRateC.text = ((monthEntry
                                                              ?.dailyRate ??
                                                          worker.baseSalary) <=
                                                      0
                                                  ? 35
                                                  : (monthEntry?.dailyRate ??
                                                      worker.baseSalary))
                                              .toStringAsFixed(2);

                                          empPctC.text =
                                              (monthEntry?.employeePct ?? 5)
                                                  .toString();
                                          emrPctC.text =
                                              (monthEntry?.employerPct ?? 10)
                                                  .toString();
                                          noteC.text = monthEntry?.note ?? '';
                                          monthAdvances = monthAdvanceList;
                                        });
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dailyRateC,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Pagesa për ditë (€)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kalendar i punës (${_monthLabel(_ymFromYearMonth(year, month))})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kliko ditët që ka punu punëtori. Nga ikona e vogël në qoshe mundesh me shtu avans edhe kur nuk ka punu. Nëse dita ka avans dhe nuk është ditë pune, rrethi del i kuq. Nëse ka avans dhe është ditë pune, border-i del portokalli.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 7 + leadingEmpty + daysInMonth,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.05,
                            ),
                            itemBuilder: (context, index) {
                              const weekdays = [
                                'HËN',
                                'MAR',
                                'MËR',
                                'ENJ',
                                'PRE',
                                'SHT',
                                'DIE',
                              ];

                              if (index < 7) {
                                final isSundayHeader = index == 6;
                                return Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSundayHeader
                                        ? Colors.red.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSundayHeader
                                          ? Colors.red.withOpacity(0.30)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Text(
                                    weekdays[index],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isSundayHeader
                                          ? Colors.redAccent
                                          : Colors.white70,
                                    ),
                                  ),
                                );
                              }

                              final dayIndex = index - 7;
                              if (dayIndex < leadingEmpty) {
                                return const SizedBox.shrink();
                              }

                              final dayNumber = dayIndex - leadingEmpty + 1;
                              if (dayNumber > daysInMonth) {
                                return const SizedBox.shrink();
                              }

                              final day = DateTime(year, month, dayNumber);
                              final isSunday = _isSunday(day);
                              final isSelected =
                                  workedDays.any((d) => _sameDate(d, day));
                              final dayAdvanceTotal = totalAdvanceForDay(day);
                              final hasAdvance = dayAdvanceTotal > 0;

                              final hasAdvanceWithoutWork =
                                  hasAdvance && !isSelected;
                              final hasAdvanceOnWorkedDay =
                                  hasAdvance && isSelected;

                              final bgColor = isSunday
                                  ? Colors.red.withOpacity(0.08)
                                  : hasAdvanceWithoutWork
                                      ? Colors.red.withOpacity(0.12)
                                      : hasAdvanceOnWorkedDay
                                          ? Colors.orange.withOpacity(0.14)
                                          : isSelected
                                              ? Colors.green.withOpacity(0.20)
                                              : Colors.white.withOpacity(0.04);

                              final borderColor = isSunday
                                  ? Colors.red.withOpacity(0.24)
                                  : hasAdvanceWithoutWork
                                      ? Colors.redAccent.withOpacity(0.95)
                                      : hasAdvanceOnWorkedDay
                                          ? Colors.orangeAccent
                                              .withOpacity(0.95)
                                          : isSelected
                                              ? Colors.green.withOpacity(0.45)
                                              : Colors.white.withOpacity(0.08);

                              final textColor = isSunday
                                  ? Colors.redAccent
                                  : hasAdvanceWithoutWork
                                      ? Colors.redAccent
                                      : hasAdvanceOnWorkedDay
                                          ? Colors.orangeAccent
                                          : isSelected
                                              ? Colors.greenAccent
                                              : Colors.white;

                              return InkWell(
                                onTap: isSunday ? null : () => toggleDay(day),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: borderColor,
                                      width: hasAdvance ? 2.0 : 1,
                                    ),
                                    boxShadow: hasAdvance
                                        ? [
                                            BoxShadow(
                                              color: Colors.orange.withOpacity(
                                                0.16,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          onTap: isSunday
                                              ? null
                                              : () async {
                                                  await openAdvanceDialogForDay(
                                                    context,
                                                    setLocal,
                                                    day,
                                                  );
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: hasAdvance
                                                  ? Colors.orange.withOpacity(
                                                      0.22,
                                                    )
                                                  : Colors.white.withOpacity(
                                                      0.08,
                                                    ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: hasAdvance
                                                    ? Colors.orangeAccent
                                                    : Colors.white
                                                        .withOpacity(0.18),
                                              ),
                                            ),
                                            child: Icon(
                                              hasAdvance
                                                  ? Icons.payments
                                                  : Icons.add_card,
                                              size: 14,
                                              color: hasAdvance
                                                  ? Colors.orangeAccent
                                                  : Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$dayNumber',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isSunday
                                                  ? 'Pushim'
                                                  : (hasAdvanceWithoutWork
                                                      ? 'Avans'
                                                      : (hasAdvanceOnWorkedDay
                                                          ? 'Punë + Avans'
                                                          : (isSelected
                                                              ? 'Punë'
                                                              : '—'))),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: textColor.withOpacity(
                                                  0.90,
                                                ),
                                              ),
                                            ),
                                            if (hasAdvance) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                eur(dayAdvanceTotal),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.orangeAccent,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MiniInfoBadge(
                          label: 'Ditë të punuara',
                          value: '$workedCount',
                          icon: Icons.calendar_month,
                        ),
                        _MiniInfoBadge(
                          label: 'Pagesa / ditë',
                          value: eur(dailyRate),
                          icon: Icons.euro,
                        ),
                        _MiniInfoBadge(
                          label: 'Bruto',
                          value: eur(gross),
                          icon: Icons.account_balance_wallet,
                          highlightGreen: true,
                        ),
                        _MiniInfoBadge(
                          label: 'Neto',
                          value: eur(net),
                          icon: Icons.payments,
                        ),
                        _MiniInfoBadge(
                          label: 'Kosto firmës',
                          value: eur(cost),
                          icon: Icons.business_center,
                        ),
                        _MiniInfoBadge(
                          label: 'Avansat e muajit',
                          value: eur(
                            monthAdvances.fold(
                              0.0,
                              (sum, item) => sum + item.amount,
                            ),
                          ),
                          icon: Icons.add_card,
                        ),
                        _MiniInfoBadge(
                          label: 'I mbesin me marrë',
                          value: eur(
                            math.max(
                              0.0,
                              gross -
                                  monthAdvances.fold(
                                    0.0,
                                    (sum, item) => sum + item.amount,
                                  ),
                            ),
                          ),
                          icon: Icons.payments_outlined,
                        ),
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
                child:
                    Text(existing == null ? 'Ruaj rrogën' : 'Ruaj ndryshimet'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final ym = _ymFromYearMonth(year, month);
    final dailyRate =
        double.tryParse(dailyRateC.text.replaceAll(',', '.')) ?? 0;
    final gross = dailyRate * workedDays.length;

    final model = PayrollEntry(
      id: existing?.id,
      workerId: worker.id!,
      month: ym,
      grossSalary: gross,
      employeePct: double.tryParse(empPctC.text.replaceAll(',', '.')) ?? 0,
      employerPct: double.tryParse(emrPctC.text.replaceAll(',', '.')) ?? 0,
      note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      dailyRate: dailyRate,
      workedDaysJson: PayrollEntry.encodeWorkedDays(workedDays),
    );

    await PayrollDao.I.upsertByWorkerMonth(model);
  }

  Future<void> _exportPdfForWorker(Worker w) async {
    final rows = _entriesForWorker(w).map((e) => PayrollPdfRow(w, e)).toList();
    await _savePdf(
      title: 'Rrogat - ${w.fullName} (${w.position})',
      rows: rows,
      advances: _advancesForWorker(w),
      filename: 'rrogat_${w.fullName.replaceAll(" ", "_")}.pdf',
    );
  }

  Future<void> _exportPdfAll() async {
    final rows = <PayrollPdfRow>[];
    final advances = <WorkerAdvance>[];
    for (final w in workers) {
      for (final e in _entriesForWorker(w)) {
        rows.add(PayrollPdfRow(w, e));
      }
      advances.addAll(_advancesForWorker(w));
    }
    await _savePdf(
      title: 'Raport Rrogash - Krejt Punëtorët',
      rows: rows,
      advances: advances,
      filename: 'raport_rrogash_krejt.pdf',
    );
  }

  Future<void> _savePdf({
    required String title,
    required List<PayrollPdfRow> rows,
    required List<WorkerAdvance> advances,
    required String filename,
  }) async {
    if (rows.isEmpty) return;

    final bytes = await PayrollPdf.build(
      title: title,
      rows: rows,
      advances: advances,
    );

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
            await _openPayrollEditor(
              worker: worker,
              existing: existing,
              lockToExistingMonth: existing != null,
            );
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
                    final currentMonthEntry = _entryForWorkerMonth(w, _ymNow());
                    final hasCurrentMonthPayroll = currentMonthEntry != null;

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
                                          '${w.position} • Pagesa / ditë: ${eur(w.baseSalary)}',
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
                                            'Muaji i fundit: ${_monthLabel(latest.month)} • ${latest.workedDaysCount} ditë • Neto ${eur(latest.netSalary)}',
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasCurrentMonthPayroll
                                          ? Colors.green.shade700
                                          : null,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: hasCurrentMonthPayroll ? 4 : 1,
                                    ),
                                    onPressed: () => _payNowForWorker(w),
                                    icon: Icon(
                                      hasCurrentMonthPayroll
                                          ? Icons.edit_calendar
                                          : Icons.payments,
                                    ),
                                    label: Text(
                                      hasCurrentMonthPayroll
                                          ? 'NDRYSHO KËTË MUAJ'
                                          : 'PAGUAJ',
                                    ),
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
                                  label: 'Muaj të ruajtur',
                                  value: '${_entriesForWorker(w).length}',
                                  icon: Icons.receipt_long,
                                ),
                                _MiniInfoBadge(
                                  label: 'Ditë pune',
                                  value: '${_workedDaysForWorker(w)}',
                                  icon: Icons.calendar_month,
                                ),
                                _MiniInfoBadge(
                                  label: 'Bruto',
                                  value: eur(_grossForWorker(w)),
                                  icon: Icons.account_balance_wallet,
                                  highlightGreen: true,
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
                                _MiniInfoBadge(
                                  label: 'Avans i marrë',
                                  value: eur(_advancesTotalForWorker(w)),
                                  icon: Icons.add_card,
                                ),
                                _MiniInfoBadge(
                                  label: 'I mbesin me marrë',
                                  value: eur(_remainingForWorker(w)),
                                  icon: Icons.payments_outlined,
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
                title: 'Totali muajve',
                value: '$_totalPayrollRowsAll',
                icon: Icons.receipt_long,
              ),
              _TotalInfoCard(
                title: 'Totali ditëve',
                value: '$_totalWorkedDaysAll',
                icon: Icons.calendar_month,
              ),
              _TotalInfoCard(
                title: 'Totali Bruto',
                value: eur(_totalGrossAll),
                icon: Icons.account_balance_wallet,
                highlightGreen: true,
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
              _TotalInfoCard(
                title: 'Totali Avanseve',
                value: eur(_totalAdvancesAll),
                icon: Icons.add_card,
              ),
              _TotalInfoCard(
                title: 'Totali që mbesin',
                value: eur(_totalRemainingAll),
                icon: Icons.payments_outlined,
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
  List<WorkerAdvance> allAdvances = [];

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

  String _ymNow() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() => loading = true);

    payroll = widget.worker.id == null
        ? []
        : await PayrollDao.I.listForWorker(widget.worker.id!);

    allAdvances = widget.worker.id == null
        ? []
        : await WorkerAdvancesDao.I.listForWorker(widget.worker.id!);

    payroll.sort((a, b) => b.month.compareTo(a.month));
    allAdvances.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

  int get _totalWorkedDays {
    return payroll.fold(0, (sum, e) => sum + e.workedDaysCount);
  }

  double get _totalAdvances {
    return allAdvances.fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _remainingToReceive {
    return math.max(0.0, _totalGross - _totalAdvances);
  }

  PayrollEntry? get _currentMonthPayroll {
    final ym = _ymNow();
    for (final e in payroll) {
      if (e.month == ym) return e;
    }
    return null;
  }

  Future<void> _editPayroll(PayrollEntry entry) async {
    await widget.openPayrollEditor(worker: widget.worker, existing: entry);
    await _load();
  }

  Future<void> _payNow() async {
    final current = _currentMonthPayroll;

    if (current != null) {
      await widget.openPayrollEditor(
        worker: widget.worker,
        existing: current,
      );
    } else {
      await widget.openPayrollEditor(
        worker: widget.worker,
        existing: null,
      );
    }

    await _load();
  }

  Future<void> _deletePayrollRow(PayrollEntry entry) async {
    if (entry.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshij rrogën'),
        content: const Text('A je i sigurt që don me fshi këtë muaj/rrogë?'),
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
    final currentMonthPayroll = _currentMonthPayroll;
    final hasCurrentMonthPayroll = currentMonthPayroll != null;

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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
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
                                  '${w.position} • Pagesa / ditë: ${eur(w.baseSalary)}',
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasCurrentMonthPayroll
                                      ? Colors.green.shade700
                                      : null,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: hasCurrentMonthPayroll ? 4 : 1,
                                ),
                                onPressed: _payNow,
                                icon: Icon(
                                  hasCurrentMonthPayroll
                                      ? Icons.edit_calendar
                                      : Icons.payments,
                                ),
                                label: Text(
                                  hasCurrentMonthPayroll
                                      ? 'NDRYSHO KËTË MUAJ'
                                      : 'PAGUAJ',
                                ),
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
                            title: 'Ditë pune',
                            value: '$_totalWorkedDays',
                            icon: Icons.calendar_month,
                          ),
                          _TotalInfoCard(
                            title: 'Totali Bruto',
                            value: eur(_totalGross),
                            icon: Icons.account_balance_wallet,
                            highlightGreen: true,
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
                          _TotalInfoCard(
                            title: 'Totali Avanseve',
                            value: eur(_totalAdvances),
                            icon: Icons.add_card,
                          ),
                          _TotalInfoCard(
                            title: 'I mbesin me marrë',
                            value: eur(_remainingToReceive),
                            icon: Icons.payments_outlined,
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
                                    'Ky punëtor nuk ka ende rroga mujore.',
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
                                          dataRowMinHeight: 64,
                                          dataRowMaxHeight: 76,
                                          headingRowHeight: 56,
                                          columnSpacing: 20,
                                          horizontalMargin: 12,
                                          headingTextStyle: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                          dataTextStyle: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          columns: const [
                                            DataColumn(label: Text('Muaji')),
                                            DataColumn(label: Text('Ditë')),
                                            DataColumn(label: Text('€/ditë')),
                                            DataColumn(label: Text('Bruto')),
                                            DataColumn(
                                              label: Text('Net (punëtori)'),
                                            ),
                                            DataColumn(
                                              label: Text('Kosto (firma)'),
                                            ),
                                            DataColumn(label: Text('Shënim')),
                                            DataColumn(label: Text('Veprime')),
                                          ],
                                          rows: payroll.map((e) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  _MonthBadge(
                                                    widget.monthLabelBuilder(
                                                      e.month,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${e.workedDaysCount}'),
                                                ),
                                                DataCell(
                                                  _MoneyBadge(eur(e.dailyRate)),
                                                ),
                                                DataCell(
                                                  _MoneyBadge(
                                                    eur(e.grossSalary),
                                                    highlightStrong: true,
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
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.green
                                                                  .shade700,
                                                          foregroundColor:
                                                              Colors.white,
                                                          elevation: 3,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 14,
                                                            vertical: 12,
                                                          ),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              12,
                                                            ),
                                                          ),
                                                        ),
                                                        onPressed: () =>
                                                            _editPayroll(e),
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          size: 18,
                                                        ),
                                                        label: const Text(
                                                            'Ndrysho'),
                                                      ),
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .red.shade700,
                                                          foregroundColor:
                                                              Colors.white,
                                                          elevation: 3,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 14,
                                                            vertical: 12,
                                                          ),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              12,
                                                            ),
                                                          ),
                                                        ),
                                                        onPressed: () =>
                                                            _deletePayrollRow(
                                                                e),
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                        ),
                                                        label:
                                                            const Text('Fshij'),
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
  PayrollEntry? currentPayrollForMonth;

  double carriedDebtFromPreviousMonths = 0.0;
  double debtToCarryNextMonth = 0.0;

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

  int _compareYm(String a, String b) {
    return a.compareTo(b);
  }

  Map<String, double> _sumAdvancesByMonth(List<WorkerAdvance> list) {
    final map = <String, double>{};
    for (final item in list) {
      map[item.month] = (map[item.month] ?? 0.0) + item.amount;
    }
    return map;
  }

  Map<String, double> _grossByMonth(List<PayrollEntry> list) {
    final map = <String, double>{};
    for (final item in list) {
      map[item.month] = item.grossSalary;
    }
    return map;
  }

  double _calculateDebtBeforeMonth({
    required List<PayrollEntry> payrollList,
    required List<WorkerAdvance> advancesList,
    required String targetYm,
  }) {
    final grossMap = _grossByMonth(payrollList);
    final advanceMap = _sumAdvancesByMonth(advancesList);

    final allMonths = <String>{
      ...grossMap.keys,
      ...advanceMap.keys,
    }.toList()
      ..sort();

    double debt = 0.0;

    for (final ym in allMonths) {
      if (_compareYm(ym, targetYm) >= 0) break;

      final gross = grossMap[ym] ?? 0.0;
      final adv = advanceMap[ym] ?? 0.0;

      final remainingAfterMonth = gross - debt - adv;

      if (remainingAfterMonth >= 0) {
        debt = 0.0;
      } else {
        debt = remainingAfterMonth.abs();
      }
    }

    return debt;
  }

  Future<void> _loadAdvances() async {
    if (widget.worker.id == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        advances = [];
        currentPayrollForMonth = null;
        carriedDebtFromPreviousMonths = 0.0;
        debtToCarryNextMonth = 0.0;
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

      final payroll = await PayrollDao.I.findForWorkerMonth(
        widget.worker.id!,
        selectedYm,
      );

      final allPayroll = await PayrollDao.I.listForWorker(widget.worker.id!);

      final allAdvances = await WorkerAdvancesDao.I.listForWorker(
        widget.worker.id!,
      );

      final previousDebt = _calculateDebtBeforeMonth(
        payrollList: allPayroll,
        advancesList: allAdvances,
        targetYm: selectedYm,
      );

      final currentMonthGross = payroll?.grossSalary ?? 0.0;
      final currentMonthAdvances =
          list.fold(0.0, (sum, item) => sum + item.amount);

      final carryNext = math.max(
        0.0,
        previousDebt + currentMonthAdvances - currentMonthGross,
      );

      if (!mounted) return;
      setState(() {
        advances = list;
        currentPayrollForMonth = payroll;
        carriedDebtFromPreviousMonths = previousDebt;
        debtToCarryNextMonth = carryNext;
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

  double get _monthGrossSalary => currentPayrollForMonth?.grossSalary ?? 0.0;

  double get _totalAdvances {
    return advances.fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _remainingSalary {
    return math.max(
      0.0,
      _monthGrossSalary - carriedDebtFromPreviousMonths - _totalAdvances,
    );
  }

  bool get _isRemainingNegative => false;

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
              if (currentPayrollForMonth == null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.30),
                    ),
                  ),
                  child: const Text(
                    'Për këtë muaj nuk ka ende rrogë të regjistruar. Avancat do të ruhen dhe nëse e kalojnë rrogën, diferenca bartet për muajin tjetër.',
                  ),
                ),
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
                title: 'Totali Bruto',
                value: _fmtPdfMoney(_monthGrossSalary),
                highlight: true,
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                title: 'Borxhi i bartur',
                value: _fmtPdfMoney(carriedDebtFromPreviousMonths),
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                title: 'Gjithsej avancë',
                value: _fmtPdfMoney(_totalAdvances),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _pdfSummaryCard(
                title: 'I mbesin pa marrë',
                value: _fmtPdfMoney(_remainingSalary),
                highlight: true,
              ),
              pw.SizedBox(width: 10),
              _pdfSummaryCard(
                title: 'Bartet muajin tjetër',
                value: _fmtPdfMoney(debtToCarryNextMonth),
                negative: debtToCarryNextMonth > 0,
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
                title: 'Totali Bruto',
                value: eur(_monthGrossSalary),
                icon: Icons.account_balance_wallet,
                highlight: true,
              ),
              _AdvanceInfoCard(
                title: 'Borxhi i bartur',
                value: eur(carriedDebtFromPreviousMonths),
                icon: Icons.history,
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
                highlight: true,
              ),
              _AdvanceInfoCard(
                title: 'Bartet muajin tjetër',
                value: eur(debtToCarryNextMonth),
                icon: Icons.redo,
                negative: debtToCarryNextMonth > 0,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (currentPayrollForMonth == null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.30),
                ),
              ),
              child: Text(
                'Për ${_monthLabel(selectedYm)} nuk ka ende rrogë të regjistruar. Totali Bruto aktualisht është 0.00 € derisa të ruhet rroga e muajit. Nëse ka avancë më shumë se rroga, diferenca bartet për muajin tjetër.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
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
                              dataRowMinHeight: 64,
                              dataRowMaxHeight: 76,
                              headingRowHeight: 56,
                              columnSpacing: 20,
                              horizontalMargin: 12,
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              dataTextStyle: const TextStyle(
                                color: Colors.white,
                              ),
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
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              elevation: 3,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () => _editAdvance(e),
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 18,
                                            ),
                                            label: const Text('Ndrysho'),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              foregroundColor: Colors.white,
                                              elevation: 3,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () => _deleteAdvance(e),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            label: const Text('Fshij'),
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
  final bool highlightStrong;

  const _MoneyBadge(
    this.text, {
    this.highlightStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: highlightStrong
            ? LinearGradient(
                colors: [
                  Colors.green.shade800,
                  Colors.green.shade600,
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.18),
                  Colors.green.withOpacity(0.12),
                ],
              ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlightStrong
              ? Colors.greenAccent.withOpacity(0.45)
              : Colors.green.withOpacity(0.25),
        ),
        boxShadow: highlightStrong
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
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
  final bool highlightGreen;

  const _MiniInfoBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.highlightGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = highlightGreen
        ? Colors.green.withOpacity(0.12)
        : Colors.white.withOpacity(0.04);

    final borderColor = highlightGreen
        ? Colors.greenAccent.withOpacity(0.45)
        : Colors.white.withOpacity(0.08);

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: highlightGreen
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.22),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
                    color: highlightGreen ? Colors.greenAccent : Colors.white,
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
  final bool highlightGreen;

  const _TotalInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlightGreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgGradient = highlightGreen
        ? [
            Colors.green.shade900.withOpacity(0.95),
            Colors.green.shade700.withOpacity(0.90),
          ]
        : [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.04),
          ];

    final borderColor = highlightGreen
        ? Colors.greenAccent.withOpacity(0.45)
        : Colors.white.withOpacity(0.10);

    final avatarBg = highlightGreen
        ? Colors.white.withOpacity(0.12)
        : Colors.green.withOpacity(0.16);

    final iconColor = highlightGreen ? Colors.white : Colors.greenAccent;
    final titleColor = highlightGreen ? Colors.white70 : Colors.white70;
    final valueColor = highlightGreen ? Colors.white : Colors.white;

    return Container(
      constraints: const BoxConstraints(minWidth: 235),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradient,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: highlightGreen
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(14),
            ),
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
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                      letterSpacing: 0.2,
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
    final bgColor = negative
        ? Colors.red.shade900.withOpacity(0.20)
        : highlight
            ? Colors.green.shade900.withOpacity(0.25)
            : Colors.white.withOpacity(0.05);

    final borderColor = negative
        ? Colors.redAccent.withOpacity(0.45)
        : highlight
            ? Colors.greenAccent.withOpacity(0.35)
            : Colors.white.withOpacity(0.10);

    final iconBg = negative
        ? Colors.red.withOpacity(0.16)
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
      constraints: const BoxConstraints(minWidth: 235),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: (negative ? Colors.red : Colors.black).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
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
                      fontWeight: FontWeight.w900,
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
