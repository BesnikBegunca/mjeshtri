import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/dao_payroll.dart';
import '../data/dao_workers.dart';
import '../models/payroll_entry.dart';
import '../models/worker.dart';
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
  Map<int, Worker> workerById = {};

  Worker? selected;
  List<PayrollEntry> payroll = [];

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => loading = true);
    workers = await WorkersDao.I.list();
    workerById = {for (final w in workers) w.id!: w};
    selected = workers.isNotEmpty ? workers.first : null;
    payroll = selected == null ? [] : await PayrollDao.I.listForWorker(selected!.id!);
    setState(() => loading = false);
  }

  Future<void> _selectWorker(Worker? w) async {
    selected = w;
    payroll = w == null ? [] : await PayrollDao.I.listForWorker(w.id!);
    setState(() {});
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
                decoration: const InputDecoration(labelText: 'Emri', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: posC,
                decoration: const InputDecoration(labelText: 'Pozita', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryC,
                decoration: const InputDecoration(labelText: 'Rroga bazë (€)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ruaj')),
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
  }

  // ==================== PAYROLL ====================

  /// ✅ PAGUAJ: shton rrogë të re për punëtorin e zgjedhur
  Future<void> _payNow() async {
    final w = selected;
    if (w == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgjedh punëtorin së pari.')),
      );
      return;
    }
    await _openPayrollEditor(worker: w, existing: null);
  }

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

  Future<void> _openPayrollEditor({required Worker worker, PayrollEntry? existing}) async {
    // defaults
    final nowYm = _ymNow();
    int year = existing == null ? _yearFromYm(nowYm) : _yearFromYm(existing.month);
    int month = existing == null ? _monthFromYm(nowYm) : _monthFromYm(existing.month);

    bool dailyPay = false;
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    final daysC = TextEditingController(text: '');
    final customPayC = TextEditingController(text: '');

    final grossC = TextEditingController(
      text: (existing?.grossSalary ?? worker.baseSalary).toStringAsFixed(2),
    );
    final empPctC = TextEditingController(text: (existing?.employeePct ?? 5).toString());
    final emrPctC = TextEditingController(text: (existing?.employerPct ?? 10).toString());
    final noteC = TextEditingController(text: existing?.note ?? '');

    // nëse është edit dhe note ka info dailyPay, s’e pars-ojmë (thjesht e lejmë manual)
    // (opsionale me pars-ue, po s’po e komplikoj)

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

          return AlertDialog(
            title: Text(existing == null ? 'Paguaj rrogë - ${worker.fullName}' : 'Ndrysho rrogë - ${worker.fullName}'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // MUJI (me emra)
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
                          controller: TextEditingController(text: year.toString()),
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

                  // CHECKBOX daily pay
                  CheckboxListTile(
                    value: dailyPay,
                    onChanged: (v) {
                      setLocal(() {
                        dailyPay = v ?? false;
                        if (dailyPay) {
                          // auto fill days
                          final days = _calcDaysInclusive(fromDate, toDate);
                          if (days > 0) daysC.text = days.toString();
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Paguaj në ditë (Custom Pay)'),
                    subtitle: const Text('P.sh. 35€ për 10 ditë, prej date në date.'),
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
                              labelText: 'Sa ditë (auto nga datat ose shkruje vet)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: customPayC,
                            keyboardType: TextInputType.number,
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

                  // BRUTO (normal ose merret nga custom pay)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: grossC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Bruto (€)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // KONTRIBUTET
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: empPctC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Kontribut punëtori (%)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emrPctC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Kontribut firma (%)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(labelText: 'Shënim', border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 12),

                  // PREVIEW
                  Builder(builder: (context) {
                    final gross = double.tryParse(grossC.text.replaceAll(',', '.')) ?? 0;
                    final emp = double.tryParse(empPctC.text.replaceAll(',', '.')) ?? 0;
                    final emr = double.tryParse(emrPctC.text.replaceAll(',', '.')) ?? 0;

                    final net = gross * (1.0 - emp / 100.0);
                    final cost = gross * (1.0 + emr / 100.0);

                    return Row(
                      children: [
                        Expanded(child: Text('Net: ${eur(net)}')),
                        Expanded(child: Text('Kosto: ${eur(cost)}')),
                      ],
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
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

    // build month string YYYY-MM
    final ym = _ymFromYearMonth(year, month);

    // if daily pay -> append note info + ensure gross from customPay if provided
    final customPay = double.tryParse(customPayC.text.replaceAll(',', '.'));
    if (dailyPay && customPay != null) {
      grossC.text = customPay.toStringAsFixed(2);
      final days = int.tryParse(daysC.text) ?? _calcDaysInclusive(fromDate, toDate);
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

    await _selectWorker(worker);
  }

  Future<void> _deletePayroll(int id) async {
    await PayrollDao.I.delete(id);
    if (selected != null) {
      await _selectWorker(selected);
    }
  }

  // ==================== PDF ====================

  Future<void> _exportPdfSelected() async {
    final w = selected;
    if (w == null) return;

    final rows = payroll.map((e) => PayrollPdfRow(w, e)).toList();
    await _savePdf(
      title: 'Rrogat - ${w.fullName} (${w.position})',
      rows: rows,
      filename: 'rrogat_${w.fullName.replaceAll(" ", "_")}.pdf',
    );
  }

  Future<void> _exportPdfAll() async {
    final rows = <PayrollPdfRow>[];
    for (final w in workers) {
      final list = await PayrollDao.I.listForWorker(w.id!);
      for (final e in list) {
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
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (loc == null) return;

    final file = File(loc.path);
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF u ruajt: ${loc.path}')),
    );
  }

  String _ymNow() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  // ======== helpers për mujin badge ========

  String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym.toUpperCase();

    final mm = int.tryParse(parts[1]) ?? 0;
    if (mm < 1 || mm > 12) return ym.toUpperCase();
    return _monthNames[mm - 1];
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Evidenca e Punëtorëve', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),

            ElevatedButton.icon(
              onPressed: _payNow,
              icon: const Icon(Icons.payments),
              label: const Text('PAGUAJ'),
            ),
            const SizedBox(width: 8),

            OutlinedButton.icon(
              onPressed: _exportPdfSelected,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF (punëtori)'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _exportPdfAll,
              icon: const Icon(Icons.download),
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

        SizedBox(
          width: 520,
          child: DropdownButtonFormField<Worker>(
            value: selected,
            items: workers
                .map((w) => DropdownMenuItem(
              value: w,
              child: Text('${w.fullName} • ${w.position}'),
            ))
                .toList(),
            onChanged: _selectWorker,
            decoration: const InputDecoration(
              labelText: 'Zgjedh punëtorin',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: Card(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Punëtori')),
                        DataColumn(label: Text('Muaji')),
                        DataColumn(label: Text('Bruto')),
                        DataColumn(label: Text('Net (punëtori)')),
                        DataColumn(label: Text('Kosto (firma)')),
                        DataColumn(label: Text('Veprime')),
                      ],
                      rows: payroll.map((e) {
                        final w = workerById[e.workerId];
                        final workerText = w == null ? '—' : '${w.fullName} (${w.position})';

                        return DataRow(cells: [
                          DataCell(Text(workerText)),
                          DataCell(_MonthBadge(_monthLabel(e.month))),
                          DataCell(_MoneyBadge(eur(e.grossSalary))),
                          DataCell(Text('${eur(e.netSalary)} (${e.employeePct}%)')),
                          DataCell(Text('${eur(e.employerCost)} (+${e.employerPct}%)')),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    if (w != null) {
                                      _openPayrollEditor(worker: w, existing: e);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deletePayroll(e.id!),
                                ),
                              ],
                            ),
                          ),
                        ]);
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
