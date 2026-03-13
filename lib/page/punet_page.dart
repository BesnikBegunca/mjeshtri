import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/dao_workers.dart';
import '../models/worker.dart';
import '../util/format.dart';
import '../util/job_report_pdf.dart';

class JobMemoryStore {
  JobMemoryStore._();
  static final JobMemoryStore I = JobMemoryStore._();

  final List<JobProject> jobs = [];
}

class PunetPage extends StatefulWidget {
  const PunetPage({super.key});

  @override
  State<PunetPage> createState() => _PunetPageState();
}

class _PunetPageState extends State<PunetPage> {
  bool loading = true;

  List<Worker> workers = [];
  List<JobProject> jobs = [];

  JobProject? selectedJob;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => loading = true);

    workers = await WorkersDao.I.list();
    jobs = JobMemoryStore.I.jobs;

    if (jobs.isEmpty) {
      jobs.add(
        JobProject(
          id: 1,
          name: 'Shtëpia e Kulturës',
          clientName: 'Komuna',
          contractAmount: 12000,
          note: 'Renovim i brendshëm dhe fasadë',
          createdAt: DateTime.now(),
          workerEntries: [],
          expenses: [],
        ),
      );
    }

    selectedJob = jobs.isNotEmpty ? jobs.first : null;

    setState(() => loading = false);
  }

  Future<void> _addJob() async {
    final nameC = TextEditingController();
    final clientC = TextEditingController();
    final amountC = TextEditingController(text: '0');
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shto punë / objekt'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: 'Emri i punës',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientC,
                decoration: const InputDecoration(
                  labelText: 'Klienti / Investitori',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qarkullimi / Vlera e kontratës (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                maxLines: 3,
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

    final name = nameC.text.trim();
    if (name.isEmpty) return;

    final job = JobProject(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      clientName: clientC.text.trim().isEmpty ? null : clientC.text.trim(),
      contractAmount: double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0,
      note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      createdAt: DateTime.now(),
      workerEntries: [],
      expenses: [],
    );

    setState(() {
      jobs.add(job);
      selectedJob = job;
    });
  }

  Future<void> _editJob(JobProject job) async {
    final nameC = TextEditingController(text: job.name);
    final clientC = TextEditingController(text: job.clientName ?? '');
    final amountC = TextEditingController(
      text: job.contractAmount.toStringAsFixed(2),
    );
    final noteC = TextEditingController(text: job.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ndrysho punën'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: 'Emri i punës',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientC,
                decoration: const InputDecoration(
                  labelText: 'Klienti / Investitori',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qarkullimi / Vlera e kontratës (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                maxLines: 3,
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

    setState(() {
      job.name = nameC.text.trim().isEmpty ? job.name : nameC.text.trim();
      job.clientName = clientC.text.trim().isEmpty ? null : clientC.text.trim();
      job.contractAmount =
          double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
      job.note = noteC.text.trim().isEmpty ? null : noteC.text.trim();
    });
  }

  Future<void> _deleteJob(JobProject job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshije punën?'),
        content: Text('A je i sigurt që don me e fshi "${job.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Jo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Po'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      jobs.removeWhere((e) => e.id == job.id);
      if (selectedJob?.id == job.id) {
        selectedJob = jobs.isNotEmpty ? jobs.first : null;
      }
    });
  }

  Future<void> _addWorkerToJob() async {
    final job = selectedJob;
    if (job == null) return;

    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuk ka punëtorë në databazë.')),
      );
      return;
    }

    Worker selectedWorker = workers.first;
    final daysC = TextEditingController(text: '1');
    final dailyRateC = TextEditingController(
      text: ((selectedWorker.baseSalary > 0
              ? selectedWorker.baseSalary / 26
              : 0))
          .toStringAsFixed(2),
    );
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          double currentTotal() {
            final d = int.tryParse(daysC.text) ?? 0;
            final r =
                double.tryParse(dailyRateC.text.replaceAll(',', '.')) ?? 0;
            return d * r;
          }

          return AlertDialog(
            title: const Text('Shto punëtor në punë'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Worker>(
                    value: selectedWorker,
                    items: workers
                        .map(
                          (w) => DropdownMenuItem<Worker>(
                            value: w,
                            child: Text('${w.fullName} • ${w.position}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() {
                        selectedWorker = v;
                        dailyRateC.text =
                            ((selectedWorker.baseSalary > 0
                                    ? selectedWorker.baseSalary / 26
                                    : 0))
                                .toStringAsFixed(2);
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Punëtori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ditë pune',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dailyRateC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Pagesa ditore (€)',
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Totali i punëtorit: ${eur(currentTotal())}',
                      style: Theme.of(context).textTheme.titleMedium,
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
                child: const Text('Shto'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final days = int.tryParse(daysC.text) ?? 0;
    final dailyRate = double.tryParse(dailyRateC.text.replaceAll(',', '.')) ?? 0;

    if (days <= 0) return;

    setState(() {
      job.workerEntries.add(
        JobWorkerEntry(
          id: DateTime.now().microsecondsSinceEpoch,
          workerId: selectedWorker.id!,
          workerName: selectedWorker.fullName,
          workerPosition: selectedWorker.position,
          days: days,
          dailyRate: dailyRate,
          note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
        ),
      );
    });
  }

  Future<void> _editWorkerEntry(JobProject job, JobWorkerEntry entry) async {
    Worker? existingWorker = workers
        .where((w) => w.id == entry.workerId)
        .cast<Worker?>()
        .firstOrNull;

    Worker selectedWorker = existingWorker ?? workers.first;

    final daysC = TextEditingController(text: entry.days.toString());
    final dailyRateC =
        TextEditingController(text: entry.dailyRate.toStringAsFixed(2));
    final noteC = TextEditingController(text: entry.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Ndrysho punëtorin'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Worker>(
                    value: selectedWorker,
                    items: workers
                        .map(
                          (w) => DropdownMenuItem<Worker>(
                            value: w,
                            child: Text('${w.fullName} • ${w.position}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => selectedWorker = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Punëtori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ditë pune',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dailyRateC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Pagesa ditore (€)',
                            border: OutlineInputBorder(),
                          ),
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

    setState(() {
      entry.workerId = selectedWorker.id!;
      entry.workerName = selectedWorker.fullName;
      entry.workerPosition = selectedWorker.position;
      entry.days = int.tryParse(daysC.text) ?? entry.days;
      entry.dailyRate =
          double.tryParse(dailyRateC.text.replaceAll(',', '.')) ??
              entry.dailyRate;
      entry.note = noteC.text.trim().isEmpty ? null : noteC.text.trim();
    });
  }

  void _deleteWorkerEntry(JobProject job, int id) {
    setState(() {
      job.workerEntries.removeWhere((e) => e.id == id);
    });
  }

  Future<void> _addExpense() async {
    final job = selectedJob;
    if (job == null) return;

    final titleC = TextEditingController();
    final amountC = TextEditingController(text: '0');
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shto shpenzim'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                decoration: const InputDecoration(
                  labelText: 'Përshkrimi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
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

    final title = titleC.text.trim();
    if (title.isEmpty) return;

    setState(() {
      job.expenses.add(
        JobExpense(
          id: DateTime.now().microsecondsSinceEpoch,
          title: title,
          amount: double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0,
          note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
        ),
      );
    });
  }

  Future<void> _editExpense(JobExpense e) async {
    final titleC = TextEditingController(text: e.title);
    final amountC = TextEditingController(text: e.amount.toStringAsFixed(2));
    final noteC = TextEditingController(text: e.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ndrysho shpenzimin'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                decoration: const InputDecoration(
                  labelText: 'Përshkrimi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
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

    setState(() {
      e.title = titleC.text.trim().isEmpty ? e.title : titleC.text.trim();
      e.amount = double.tryParse(amountC.text.replaceAll(',', '.')) ?? e.amount;
      e.note = noteC.text.trim().isEmpty ? null : noteC.text.trim();
    });
  }

  void _deleteExpense(JobProject job, int id) {
    setState(() {
      job.expenses.removeWhere((e) => e.id == id);
    });
  }

  Future<void> _exportPdfSelected() async {
    final job = selectedJob;
    if (job == null) return;

    final bytes = await JobReportPdf.buildSingleJob(job: job);

    await _savePdf(
      bytes: bytes,
      filename: 'puna_${job.name.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _exportPdfAll() async {
    if (jobs.isEmpty) return;

    final bytes = await JobReportPdf.buildAllJobs(jobs: jobs);

    await _savePdf(
      bytes: bytes,
      filename: 'raporti_i_puneve.pdf',
    );
  }

  Future<void> _savePdf({
    required List<int> bytes,
    required String filename,
  }) async {
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

  double _workersTotal(JobProject job) {
    return job.workerEntries.fold(0.0, (sum, e) => sum + e.total);
  }

  double _expensesTotal(JobProject job) {
    return job.expenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  double _investmentTotal(JobProject job) {
    return _workersTotal(job) + _expensesTotal(job);
  }

  double _profit(JobProject job) {
    return job.contractAmount - _investmentTotal(job);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final job = selectedJob;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Evidenca e Punëve / Objekteve',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _addJob,
              icon: const Icon(Icons.add_business),
              label: const Text('Shto punë'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: job == null ? null : () => _editJob(job),
              icon: const Icon(Icons.edit),
              label: const Text('Ndrysho'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: job == null ? null : () => _deleteJob(job),
              icon: const Icon(Icons.delete),
              label: const Text('Fshij'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: job == null ? null : _exportPdfSelected,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF (kjo punë)'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: jobs.isEmpty ? null : _exportPdfAll,
              icon: const Icon(Icons.download),
              label: const Text('PDF (krejt)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 520,
          child: DropdownButtonFormField<JobProject>(
            value: selectedJob,
            items: jobs
                .map(
                  (j) => DropdownMenuItem<JobProject>(
                    value: j,
                    child: Text(j.name),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => selectedJob = v),
            decoration: const InputDecoration(
              labelText: 'Zgjedh punën',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (job == null)
          Expanded(
            child: Center(
              child: Text(
                'Nuk ka punë të zgjedhur.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.name,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                _InfoRow('Klienti', job.clientName ?? '—'),
                                _InfoRow('Data', _fmtDate(job.createdAt)),
                                _InfoRow('Qarkullimi', eur(job.contractAmount)),
                                _InfoRow('Shënim', job.note ?? '—'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SummaryCard(
                              title: 'Punëtorë',
                              value: eur(_workersTotal(job)),
                              icon: Icons.groups,
                            ),
                            _SummaryCard(
                              title: 'Shpenzime',
                              value: eur(_expensesTotal(job)),
                              icon: Icons.receipt_long,
                            ),
                            _SummaryCard(
                              title: 'Investimi',
                              value: eur(_investmentTotal(job)),
                              icon: Icons.account_balance_wallet,
                            ),
                            _SummaryCard(
                              title: 'Fitimi',
                              value: eur(_profit(job)),
                              icon: Icons.trending_up,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Punëtorët në këtë punë',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: _addWorkerToJob,
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Shto punëtor'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Punëtori')),
                                DataColumn(label: Text('Pozita')),
                                DataColumn(label: Text('Ditë')),
                                DataColumn(label: Text('Pagesa ditore')),
                                DataColumn(label: Text('Totali')),
                                DataColumn(label: Text('Shënim')),
                                DataColumn(label: Text('Veprime')),
                              ],
                              rows: job.workerEntries.map((e) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(e.workerName)),
                                    DataCell(Text(e.workerPosition ?? '—')),
                                    DataCell(Text(e.days.toString())),
                                    DataCell(_MoneyBadge(eur(e.dailyRate))),
                                    DataCell(_MoneyBadge(eur(e.total))),
                                    DataCell(Text(e.note ?? '—')),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () =>
                                                _editWorkerEntry(job, e),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteWorkerEntry(job, e.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Shpenzimet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: _addExpense,
                                icon: const Icon(Icons.add_card),
                                label: const Text('Shto shpenzim'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Përshkrimi')),
                                DataColumn(label: Text('Shuma')),
                                DataColumn(label: Text('Shënim')),
                                DataColumn(label: Text('Veprime')),
                              ],
                              rows: job.expenses.map((e) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(e.title)),
                                    DataCell(_ExpenseBadge(eur(e.amount))),
                                    DataCell(Text(e.note ?? '—')),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _editExpense(e),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteExpense(job, e.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class JobProject {
  int id;
  String name;
  String? clientName;
  double contractAmount;
  String? note;
  DateTime createdAt;
  List<JobWorkerEntry> workerEntries;
  List<JobExpense> expenses;

  JobProject({
    required this.id,
    required this.name,
    this.clientName,
    required this.contractAmount,
    this.note,
    required this.createdAt,
    required this.workerEntries,
    required this.expenses,
  });
}

class JobWorkerEntry {
  int id;
  int workerId;
  String workerName;
  String? workerPosition;
  int days;
  double dailyRate;
  String? note;

  JobWorkerEntry({
    required this.id,
    required this.workerId,
    required this.workerName,
    this.workerPosition,
    required this.days,
    required this.dailyRate,
    this.note,
  });

  double get total => days * dailyRate;
}

class JobExpense {
  int id;
  String title;
  double amount;
  String? note;

  JobExpense({
    required this.id,
    required this.title,
    required this.amount,
    this.note,
  });
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _ExpenseBadge extends StatelessWidget {
  final String text;
  const _ExpenseBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.16),
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

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}