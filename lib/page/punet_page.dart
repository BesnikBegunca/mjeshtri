import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/dao_jobs.dart';
import '../data/dao_workers.dart';
import '../models/job_project.dart';
import '../models/worker.dart';
import '../util/format.dart';
import '../util/job_report_pdf.dart';

class PunetPage extends StatefulWidget {
  const PunetPage({super.key});

  @override
  State<PunetPage> createState() => _PunetPageState();
}

class _PunetPageState extends State<PunetPage> {
  bool loading = true;

  List<Worker> workers = [];
  List<JobProject> jobs = [];

  int? selectedJobId;

  List<JobProject> get activeJobs => jobs.where((e) => !e.isCompleted).toList();

  List<JobProject> get completedJobs =>
      jobs.where((e) => e.isCompleted).toList();

  JobProject? get selectedJob {
    if (selectedJobId == null) return null;
    return jobs.where((e) => e.id == selectedJobId).firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => loading = true);

    workers = await WorkersDao.I.list();
    jobs = await JobsDao.I.listJobs();

    if (activeJobs.isNotEmpty) {
      selectedJobId = activeJobs.first.id;
    } else if (completedJobs.isNotEmpty) {
      selectedJobId = completedJobs.first.id;
    } else {
      selectedJobId = null;
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _reloadJobs({int? keepSelectedId}) async {
    jobs = await JobsDao.I.listJobs();

    if (jobs.isEmpty) {
      selectedJobId = null;
    } else {
      final wantedId = keepSelectedId ?? selectedJobId;
      final exists = jobs.any((e) => e.id == wantedId);

      if (wantedId != null && exists) {
        selectedJobId = wantedId;
      } else if (activeJobs.isNotEmpty) {
        selectedJobId = activeJobs.first.id;
      } else if (completedJobs.isNotEmpty) {
        selectedJobId = completedJobs.first.id;
      } else {
        selectedJobId = jobs.first.id;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDetails(JobProject job) async {
    if (job.id == null) return;

    setState(() {
      selectedJobId = job.id;
    });

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              JobProject? currentJob =
                  jobs.where((e) => e.id == job.id).firstOrNull;

              if (currentJob == null) {
                return const SizedBox(
                  width: 1000,
                  height: 500,
                  child: Center(
                    child: Text('Ky projekt nuk u gjet më.'),
                  ),
                );
              }

              Future<void> refreshModal() async {
                await _reloadJobs(keepSelectedId: currentJob!.id);
                setModalState(() {});
              }

              return SizedBox(
                width: 1400,
                height: MediaQuery.of(context).size.height * 0.90,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            (currentJob.isCompleted
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary)
                                .withOpacity(0.18),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: (currentJob.isCompleted
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.primary)
                                  .withOpacity(0.16),
                            ),
                            child: Icon(
                              currentJob.isCompleted
                                  ? Icons.task_alt_rounded
                                  : Icons.apartment_rounded,
                              color: currentJob.isCompleted
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentJob.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Detajet e plota të projektit, punëtorët, shpenzimet dhe fitimi.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusChip(isCompleted: currentJob.isCompleted),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'Mbyll',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(18),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: _buildDetailsView(
                                currentJob,
                                onRefresh: refreshModal,
                                onDeleteAndClose: () async {
                                  await _deleteJob(currentJob!);
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _addJob() async {
    final nameC = TextEditingController();
    final clientC = TextEditingController();
    final amountC = TextEditingController(text: '0');
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.add_business_rounded),
            SizedBox(width: 10),
            Text('Shto punë / objekt'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PremiumTextField(
                controller: nameC,
                label: 'Emri i punës',
                icon: Icons.business_center_rounded,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: clientC,
                label: 'Klienti / Investitori',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: amountC,
                label: 'Qarkullimi / Vlera e kontratës (€)',
                icon: Icons.payments_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: noteC,
                label: 'Shënim',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameC.text.trim();
    if (name.isEmpty) return;

    final id = await JobsDao.I.insertJob(
      JobProject(
        name: name,
        clientName: clientC.text.trim().isEmpty ? null : clientC.text.trim(),
        contractAmount: double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0,
        note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
        createdAt: DateTime.now(),
        isCompleted: false,
        completedAt: null,
      ),
    );

    await _reloadJobs(keepSelectedId: id);
  }

  Future<void> _editJob(JobProject job) async {
    final nameC = TextEditingController(text: job.name);
    final clientC = TextEditingController(text: job.clientName ?? '');
    final amountC =
        TextEditingController(text: job.contractAmount.toStringAsFixed(2));
    final noteC = TextEditingController(text: job.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded),
            SizedBox(width: 10),
            Text('Ndrysho punën'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PremiumTextField(
                controller: nameC,
                label: 'Emri i punës',
                icon: Icons.business_center_rounded,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: clientC,
                label: 'Klienti / Investitori',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: amountC,
                label: 'Qarkullimi / Vlera e kontratës (€)',
                icon: Icons.payments_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: noteC,
                label: 'Shënim',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    job.name = nameC.text.trim().isEmpty ? job.name : nameC.text.trim();
    job.clientName = clientC.text.trim().isEmpty ? null : clientC.text.trim();
    job.contractAmount =
        double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0;
    job.note = noteC.text.trim().isEmpty ? null : noteC.text.trim();

    await JobsDao.I.updateJob(job);
    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _deleteJob(JobProject job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Fshije punën?'),
          ],
        ),
        content: Text('A je i sigurt që don me e fshi "${job.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Jo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Po'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (job.id == null) return;

    await JobsDao.I.deleteJob(job.id!);
    await _reloadJobs();
  }

  Future<void> _finishProject(JobProject job) async {
    if (job.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.task_alt_rounded, color: Colors.green),
            SizedBox(width: 10),
            Text('Përfundo projektin'),
          ],
        ),
        content: Text(
          'A je i sigurt që don me e përfundu projektin "${job.name}"?\n\n'
          'Pas kësaj projekti kalon te lista e projekteve të përfunduara.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Përfundo'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    job.isCompleted = true;
    job.completedAt = DateTime.now();

    await JobsDao.I.updateJob(job);
    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _addWorkerToJob(JobProject job) async {
    if (job.id == null) return;

    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuk ka punëtorë në databazë.')),
      );
      return;
    }

    Worker selectedWorker = workers.first;
    final daysC = TextEditingController(text: '1');
    final dailyRateC = TextEditingController(
      text: (selectedWorker.baseSalary > 0 ? selectedWorker.baseSalary : 0)
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded),
                SizedBox(width: 10),
                Text('Shto punëtor në punë'),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedWorker.id,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    items: workers
                        .where((w) => w.id != null)
                        .map(
                          (w) => DropdownMenuItem<int>(
                            value: w.id!,
                            child: Text('${w.fullName} • ${w.position}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final found = workers.where((w) => w.id == v).firstOrNull;
                      if (found == null) return;

                      setLocal(() {
                        selectedWorker = found;
                        dailyRateC.text = (selectedWorker.baseSalary > 0
                                ? selectedWorker.baseSalary
                                : 0)
                            .toStringAsFixed(2);
                      });
                    },
                    decoration:
                        _inputDecoration('Punëtori', Icons.badge_outlined),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysC,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            'Ditë pune',
                            Icons.calendar_today,
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dailyRateC,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration(
                            'Pagesa ditore (€)',
                            Icons.euro_rounded,
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteC,
                    decoration: _inputDecoration('Shënim', Icons.notes_rounded),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calculate_rounded,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Totali i punëtorit: ${eur(currentTotal())}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
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
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Shto'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final days = int.tryParse(daysC.text) ?? 0;
    final dailyRate =
        double.tryParse(dailyRateC.text.replaceAll(',', '.')) ?? 0;

    if (days <= 0) return;
    if (selectedWorker.id == null) return;

    await JobsDao.I.insertWorkerEntry(
      JobWorkerEntry(
        jobId: job.id!,
        workerId: selectedWorker.id!,
        workerName: selectedWorker.fullName,
        workerPosition: selectedWorker.position,
        days: days,
        dailyRate: dailyRate,
        note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      ),
    );

    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _editWorkerEntry(JobProject job, JobWorkerEntry entry) async {
    if (workers.isEmpty) return;

    Worker? existingWorker =
        workers.where((w) => w.id == entry.workerId).firstOrNull;

    Worker selectedWorker = existingWorker ?? workers.first;

    final daysC = TextEditingController(text: entry.days.toString());
    final dailyRateC =
        TextEditingController(text: entry.dailyRate.toStringAsFixed(2));
    final noteC = TextEditingController(text: entry.note ?? '');

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded),
                SizedBox(width: 10),
                Text('Ndrysho punëtorin'),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedWorker.id,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    items: workers
                        .where((w) => w.id != null)
                        .map(
                          (w) => DropdownMenuItem<int>(
                            value: w.id!,
                            child: Text('${w.fullName} • ${w.position}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final found = workers.where((w) => w.id == v).firstOrNull;
                      if (found == null) return;

                      setLocal(() => selectedWorker = found);
                    },
                    decoration:
                        _inputDecoration('Punëtori', Icons.badge_outlined),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysC,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            'Ditë pune',
                            Icons.calendar_today,
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dailyRateC,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration(
                            'Pagesa ditore (€)',
                            Icons.euro_rounded,
                          ),
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteC,
                    decoration: _inputDecoration('Shënim', Icons.notes_rounded),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.28)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined, color: Colors.blue),
                        const SizedBox(width: 10),
                        Text(
                          'Totali: ${eur(currentTotal())}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
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
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Ruaj'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;
    if (entry.id == null) return;
    if (selectedWorker.id == null) return;

    entry.workerId = selectedWorker.id!;
    entry.workerName = selectedWorker.fullName;
    entry.workerPosition = selectedWorker.position;
    entry.days = int.tryParse(daysC.text) ?? entry.days;
    entry.dailyRate = double.tryParse(dailyRateC.text.replaceAll(',', '.')) ??
        entry.dailyRate;
    entry.note = noteC.text.trim().isEmpty ? null : noteC.text.trim();

    await JobsDao.I.updateWorkerEntry(entry);
    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _deleteWorkerEntry(JobProject job, int? id) async {
    if (id == null) return;
    await JobsDao.I.deleteWorkerEntry(id);
    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _addExpense(JobProject job) async {
    if (job.id == null) return;

    final titleC = TextEditingController();
    final amountC = TextEditingController(text: '0');
    final noteC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded),
            SizedBox(width: 10),
            Text('Shto shpenzim'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PremiumTextField(
                controller: titleC,
                label: 'Përshkrimi',
                icon: Icons.description_outlined,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: amountC,
                label: 'Shuma (€)',
                icon: Icons.euro_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: noteC,
                label: 'Shënim',
                icon: Icons.notes_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleC.text.trim();
    if (title.isEmpty) return;

    await JobsDao.I.insertExpense(
      JobExpense(
        jobId: job.id!,
        title: title,
        amount: double.tryParse(amountC.text.replaceAll(',', '.')) ?? 0,
        note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
      ),
    );

    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _editExpense(JobProject job, JobExpense e) async {
    final titleC = TextEditingController(text: e.title);
    final amountC = TextEditingController(text: e.amount.toStringAsFixed(2));
    final noteC = TextEditingController(text: e.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded),
            SizedBox(width: 10),
            Text('Ndrysho shpenzimin'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PremiumTextField(
                controller: titleC,
                label: 'Përshkrimi',
                icon: Icons.description_outlined,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: amountC,
                label: 'Shuma (€)',
                icon: Icons.euro_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                controller: noteC,
                label: 'Shënim',
                icon: Icons.notes_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Ruaj'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (e.id == null) return;

    e.title = titleC.text.trim().isEmpty ? e.title : titleC.text.trim();
    e.amount = double.tryParse(amountC.text.replaceAll(',', '.')) ?? e.amount;
    e.note = noteC.text.trim().isEmpty ? null : noteC.text.trim();

    await JobsDao.I.updateExpense(e);
    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _deleteExpense(JobProject job, int? id) async {
    if (id == null) return;
    await JobsDao.I.deleteExpense(id);
    await _reloadJobs(keepSelectedId: job.id);
  }

  Future<void> _exportPdfForJob(JobProject job) async {
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
      SnackBar(
        content: Text('PDF u ruajt: ${loc.path}'),
        behavior: SnackBarBehavior.floating,
      ),
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

  static InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(width: 1.4),
      ),
    );
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.18),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.18),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evidenca e Punëve / Objekteve',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addJob,
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('Shto punë'),
                      ),
                      OutlinedButton.icon(
                        onPressed: job == null ? null : () => _editJob(job),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Ndrysho'),
                      ),
                      OutlinedButton.icon(
                        onPressed: job == null ? null : () => _deleteJob(job),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Fshij'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            job == null ? null : () => _exportPdfForJob(job),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('PDF (kjo punë)'),
                      ),
                      ElevatedButton.icon(
                        onPressed: jobs.isEmpty ? null : _exportPdfAll,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('PDF (krejt)'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _JobsTableCard(
                        tableWidth: constraints.maxWidth,
                        title: 'Projektet aktive',
                        subtitle: 'Punët që janë ende në proces',
                        icon: Icons.work_outline_rounded,
                        color: Colors.blue,
                        count: activeJobs.length,
                        jobs: activeJobs,
                        selectedJobId: selectedJobId,
                        onDetailsTap: _openDetails,
                        profitBuilder: _profit,
                        dateBuilder: _fmtDate,
                      ),
                      const SizedBox(height: 16),
                      _JobsTableCard(
                        tableWidth: constraints.maxWidth,
                        title: 'Projektet e përfunduara',
                        subtitle: 'Historiku i projekteve të mbyllura',
                        icon: Icons.task_alt_rounded,
                        color: Colors.green,
                        count: completedJobs.length,
                        jobs: completedJobs,
                        selectedJobId: selectedJobId,
                        onDetailsTap: _openDetails,
                        profitBuilder: _profit,
                        dateBuilder: _fmtDate,
                      ),
                      const SizedBox(height: 16),
                      if (jobs.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                            color: Theme.of(context).cardColor,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 52,
                                color: Colors.white.withOpacity(0.65),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nuk ka asnjë punë të regjistruar.',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: Colors.white.withOpacity(0.02),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kliko "Detaje" për me e hap projektin në dritare të veçantë.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsView(
    JobProject job, {
    required Future<void> Function() onRefresh,
    required Future<void> Function() onDeleteAndClose,
  }) {
    final bool isCompleted = job.isCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 340,
              child: _SummaryCard(
                title: 'Punëtorë',
                value: eur(_workersTotal(job)),
                icon: Icons.groups_rounded,
                accent: Colors.blue,
                fullWidth: true,
              ),
            ),
            SizedBox(
              width: 340,
              child: _SummaryCard(
                title: 'Shpenzime',
                value: eur(_expensesTotal(job)),
                icon: Icons.receipt_long_rounded,
                accent: Colors.orange,
                fullWidth: true,
              ),
            ),
            SizedBox(
              width: 340,
              child: _SummaryCard(
                title: 'Investimi',
                value: eur(_investmentTotal(job)),
                icon: Icons.account_balance_wallet_rounded,
                accent: Colors.purple,
                fullWidth: true,
              ),
            ),
            SizedBox(
              width: 340,
              child: _SummaryCard(
                title: 'Fitimi',
                value: eur(_profit(job)),
                icon: _profit(job) >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                accent: _profit(job) >= 0 ? Colors.green : Colors.red,
                fullWidth: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Informacionet e projektit',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    _StatusChip(isCompleted: job.isCompleted),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Klienti',
                  value: job.clientName ?? '—',
                ),
                _InfoTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Data e krijimit',
                  value: _fmtDate(job.createdAt),
                ),
                _InfoTile(
                  icon: Icons.euro_rounded,
                  label: 'Qarkullimi',
                  value: eur(job.contractAmount),
                ),
                _InfoTile(
                  icon: Icons.notes_rounded,
                  label: 'Shënim',
                  value: job.note ?? '—',
                ),
                if (job.isCompleted)
                  _InfoTile(
                    icon: Icons.task_alt_rounded,
                    label: 'Përfunduar më',
                    value: job.completedAt == null
                        ? '—'
                        : _fmtDate(job.completedAt!),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isCompleted)
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _finishProject(job);
                          await onRefresh();
                        },
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text('Përfundo projektin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _editJob(job);
                        await onRefresh();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Ndrysho projektin'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _exportPdfForJob(job),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Printo PDF'),
                    ),
                    ElevatedButton.icon(
                      onPressed: onDeleteAndClose,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Fshij Projektin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _TableSectionCard(
          icon: Icons.groups_2_rounded,
          title: 'Punëtorët në këtë punë',
          action: !isCompleted
              ? ElevatedButton.icon(
                  onPressed: () async {
                    await _addWorkerToJob(job);
                    await onRefresh();
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Shto punëtor'),
                )
              : null,
          child: job.workerEntries.isEmpty
              ? const _EmptySection(
                  icon: Icons.group_off_rounded,
                  text: 'Nuk ka punëtorë të regjistruar për këtë projekt.',
                )
              : _StyledDataTable(
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
                          isCompleted
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.lock_outline_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Vetëm lexim'),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Ndrysho',
                                      icon: const Icon(Icons.edit_rounded),
                                      onPressed: () async {
                                        await _editWorkerEntry(job, e);
                                        await onRefresh();
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Fshij',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () async {
                                        await _deleteWorkerEntry(job, e.id);
                                        await onRefresh();
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 14),
        _TableSectionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Shpenzimet',
          action: !isCompleted
              ? ElevatedButton.icon(
                  onPressed: () async {
                    await _addExpense(job);
                    await onRefresh();
                  },
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Shto shpenzim'),
                )
              : null,
          child: job.expenses.isEmpty
              ? const _EmptySection(
                  icon: Icons.receipt_long_outlined,
                  text: 'Nuk ka shpenzime të regjistruara për këtë projekt.',
                )
              : _StyledDataTable(
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
                          isCompleted
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.lock_outline_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Vetëm lexim'),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Ndrysho',
                                      icon: const Icon(Icons.edit_rounded),
                                      onPressed: () async {
                                        await _editExpense(job, e);
                                        await onRefresh();
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Fshij',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () async {
                                        await _deleteExpense(job, e.id);
                                        await onRefresh();
                                      },
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
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _JobsTableCard extends StatelessWidget {
  final double tableWidth;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int count;
  final List<JobProject> jobs;
  final int? selectedJobId;
  final Future<void> Function(JobProject job) onDetailsTap;
  final double Function(JobProject job) profitBuilder;
  final String Function(DateTime date) dateBuilder;

  const _JobsTableCard({
    required this.tableWidth,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.count,
    required this.jobs,
    required this.selectedJobId,
    required this.onDetailsTap,
    required this.profitBuilder,
    required this.dateBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _GlassCard(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: color.withOpacity(0.14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  _StatPill(
                    icon: icon,
                    text: '$count projekte',
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (jobs.isEmpty)
                _EmptySection(
                  icon: icon,
                  text: 'Nuk ka projekte në këtë listë.',
                )
              else
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.08),
                        Colors.white.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: tableWidth,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.white.withOpacity(0.06),
                          ),
                          child: DataTable(
                            horizontalMargin: 22,
                            columnSpacing: 30,
                            headingRowHeight: 60,
                            dataRowMinHeight: 68,
                            dataRowMaxHeight: 74,
                            headingRowColor: MaterialStatePropertyAll(
                              color.withOpacity(0.10),
                            ),
                            columns: const [
                              DataColumn(label: Text('Emri')),
                              DataColumn(label: Text('Klienti')),
                              DataColumn(label: Text('Vlera')),
                              DataColumn(label: Text('Fitimi')),
                              DataColumn(label: Text('Statusi')),
                              DataColumn(label: Text('Veprime')),
                            ],
                            rows: jobs.map((p) {
                              final profit = profitBuilder(p);
                              final isSelected = p.id == selectedJobId;

                              return DataRow(
                                selected: isSelected,
                                color:
                                    MaterialStateProperty.resolveWith<Color?>(
                                  (states) {
                                    if (isSelected) {
                                      return color.withOpacity(0.10);
                                    }
                                    return null;
                                  },
                                ),
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: tableWidth * 0.24,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: color.withOpacity(0.12),
                                            ),
                                            child: Icon(
                                              Icons.apartment_rounded,
                                              size: 20,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: tableWidth * 0.18,
                                      child: Text(
                                        p.clientName ?? '—',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: tableWidth * 0.12,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child:
                                            _MoneyBadge(eur(p.contractAmount)),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: tableWidth * 0.12,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: profit >= 0
                                            ? _MoneyBadge(eur(profit))
                                            : _DangerBadge(eur(profit)),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: tableWidth * 0.12,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _StatusChip(
                                            isCompleted: p.isCompleted),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: tableWidth * 0.14,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: ElevatedButton.icon(
                                          onPressed: () => onDetailsTap(p),
                                          icon: const Icon(
                                              Icons.open_in_new_rounded),
                                          label: const Text('Detaje'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                color.withOpacity(0.14),
                                            foregroundColor: color,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: BorderSide(
                                                color: color.withOpacity(0.30),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

class _TableSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? action;

  const _TableSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(icon),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StyledDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const _StyledDataTable({
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1200),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.white.withOpacity(0.06),
              ),
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 58,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 70,
                headingRowColor: MaterialStatePropertyAll(
                  Theme.of(context).colorScheme.primary.withOpacity(0.08),
                ),
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(width: 1.4),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isCompleted;

  const _StatusChip({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? Colors.green : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.task_alt_rounded : Icons.timelapse_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isCompleted ? 'I përfunduar' : 'Aktiv',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _StatPill({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final bool fullWidth;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : 235,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: accent.withOpacity(0.12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.16),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

class _DangerBadge extends StatelessWidget {
  final String text;
  const _DangerBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
            ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptySection({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.025),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Colors.white60),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
