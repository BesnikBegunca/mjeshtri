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

  /// 0 = aktive, 1 = perfunduara
  int selectedTopTab = 0;

  List<JobProject> get activeJobs =>
      jobs.where((e) => !(e.isCompleted)).toList();

  List<JobProject> get completedJobs =>
      jobs.where((e) => e.isCompleted).toList();

  List<JobProject> get visibleJobs =>
      selectedTopTab == 0 ? activeJobs : completedJobs;

  JobProject? get selectedJob {
    if (selectedJobId == null) return null;
    return jobs.where((e) => e.id == selectedJobId).firstOrNull;
  }

  bool get selectedJobIsCompleted => selectedJob?.isCompleted ?? false;

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
      selectedTopTab = 0;
    } else if (completedJobs.isNotEmpty) {
      selectedJobId = completedJobs.first.id;
      selectedTopTab = 1;
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
        final found = jobs.where((e) => e.id == wantedId).firstOrNull;
        if (found != null) {
          selectedTopTab = found.isCompleted ? 1 : 0;
        }
      } else if (activeJobs.isNotEmpty) {
        selectedJobId = activeJobs.first.id;
        selectedTopTab = 0;
      } else if (completedJobs.isNotEmpty) {
        selectedJobId = completedJobs.first.id;
        selectedTopTab = 1;
      } else {
        selectedJobId = jobs.first.id;
        selectedTopTab = jobs.first.isCompleted ? 1 : 0;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _changeTopTab(int index) {
    final targetList = index == 0 ? activeJobs : completedJobs;

    setState(() {
      selectedTopTab = index;

      if (targetList.isEmpty) {
        selectedJobId = null;
        return;
      }

      final currentVisible =
          targetList.where((e) => e.id == selectedJobId).firstOrNull;
      selectedJobId = currentVisible?.id ?? targetList.first.id;
    });
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
    final amountC = TextEditingController(
      text: job.contractAmount.toStringAsFixed(2),
    );
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
          'Pas kësaj nuk ka me u shfaq ma te projektet aktive, po ka me kalu te tab-i i projekteve të përfunduara.',
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

    final nextActive = activeJobs.where((e) => e.id != job.id).firstOrNull;
    await _reloadJobs(
      keepSelectedId: nextActive?.id ?? job.id,
    );
  }

  Future<void> _openCompletedJob(JobProject job) async {
    setState(() {
      selectedTopTab = 1;
      selectedJobId = job.id;
    });
  }

  Future<void> _addWorkerToJob() async {
    final job = selectedJob;
    if (job == null || job.id == null) return;

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
                    decoration: _inputDecoration(
                      'Punëtori',
                      Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysC,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                              'Ditë pune', Icons.calendar_today),
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
                        const Icon(Icons.calculate_rounded,
                            color: Colors.green),
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
                    decoration: _inputDecoration(
                      'Punëtori',
                      Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: daysC,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                              'Ditë pune', Icons.calendar_today),
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
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.28),
                      ),
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

  Future<void> _addExpense() async {
    final job = selectedJob;
    if (job == null || job.id == null) return;

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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
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
    final dropdownValue =
        visibleJobs.any((e) => e.id == selectedJobId) ? selectedJobId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                        Text(
                          'Menaxho projektet aktive dhe të përfunduara, punëtorët, shpenzimet dhe raportet PDF.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
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
                        onPressed: job == null ? null : _exportPdfSelected,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _TopSwitchTab(
                      selected: selectedTopTab == 0,
                      icon: Icons.work_outline_rounded,
                      title: 'Projektet aktive',
                      count: activeJobs.length,
                      color: Colors.blue,
                      onTap: () => _changeTopTab(0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TopSwitchTab(
                      selected: selectedTopTab == 1,
                      icon: Icons.task_alt_rounded,
                      title: 'Projektet e përfunduara',
                      count: completedJobs.length,
                      color: Colors.green,
                      onTap: () => _changeTopTab(1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          selectedTopTab == 0
                              ? Icons.folder_open_rounded
                              : Icons.inventory_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedTopTab == 0
                              ? 'Projektet aktive'
                              : 'Projektet e përfunduara',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const Spacer(),
                        _StatPill(
                          icon: selectedTopTab == 0
                              ? Icons.work_outline_rounded
                              : Icons.done_all_rounded,
                          text: '${visibleJobs.length} projekte',
                          color:
                              selectedTopTab == 0 ? Colors.blue : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: dropdownValue,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      items: visibleJobs
                          .where((j) => j.id != null)
                          .map(
                            (j) => DropdownMenuItem<int>(
                              value: j.id!,
                              child: Text(j.name),
                            ),
                          )
                          .toList(),
                      onChanged: visibleJobs.isEmpty
                          ? null
                          : (v) {
                              setState(() {
                                selectedJobId = v;
                              });
                            },
                      decoration: _inputDecoration(
                        selectedTopTab == 0
                            ? 'Zgjedh punën aktive'
                            : 'Zgjedh projektin e përfunduar',
                        selectedTopTab == 0
                            ? Icons.folder_open_rounded
                            : Icons.task_alt_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (job == null)
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                      jobs.isEmpty
                          ? 'Nuk ka asnjë punë të regjistruar.'
                          : 'Nuk ka punë të zgjedhur.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
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
                        child: _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        job.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _StatusChip(
                                      isCompleted: job.isCompleted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
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
                                    if (!job.isCompleted)
                                      ElevatedButton.icon(
                                        onPressed: () => _finishProject(job),
                                        icon: const Icon(
                                          Icons.task_alt_rounded,
                                        ),
                                        label: const Text('Përfundo projektin'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: _exportPdfSelected,
                                      icon: const Icon(
                                        Icons.print_rounded,
                                      ),
                                      label: const Text('Printo PDF'),
                                    ),
                                  ],
                                ),
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
                              icon: Icons.groups_rounded,
                              accent: Colors.blue,
                            ),
                            _SummaryCard(
                              title: 'Shpenzime',
                              value: eur(_expensesTotal(job)),
                              icon: Icons.receipt_long_rounded,
                              accent: Colors.orange,
                            ),
                            _SummaryCard(
                              title: 'Investimi',
                              value: eur(_investmentTotal(job)),
                              icon: Icons.account_balance_wallet_rounded,
                              accent: Colors.purple,
                            ),
                            _SummaryCard(
                              title: 'Fitimi',
                              value: eur(_profit(job)),
                              icon: _profit(job) >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              accent:
                                  _profit(job) >= 0 ? Colors.green : Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _TableSectionCard(
                    icon: Icons.groups_2_rounded,
                    title: 'Punëtorët në këtë punë',
                    action: !selectedJobIsCompleted
                        ? ElevatedButton.icon(
                            onPressed: _addWorkerToJob,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Shto punëtor'),
                          )
                        : null,
                    child: job.workerEntries.isEmpty
                        ? const _EmptySection(
                            icon: Icons.group_off_rounded,
                            text:
                                'Nuk ka punëtorë të regjistruar për këtë projekt.',
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
                                    selectedJobIsCompleted
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.lock_outline_rounded,
                                                  size: 18),
                                              SizedBox(width: 6),
                                              Text('Vetëm lexim'),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              IconButton(
                                                tooltip: 'Ndrysho',
                                                icon: const Icon(
                                                    Icons.edit_rounded),
                                                onPressed: () =>
                                                    _editWorkerEntry(job, e),
                                              ),
                                              IconButton(
                                                tooltip: 'Fshij',
                                                icon: const Icon(Icons
                                                    .delete_outline_rounded),
                                                onPressed: () =>
                                                    _deleteWorkerEntry(
                                                        job, e.id),
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
                    action: !selectedJobIsCompleted
                        ? ElevatedButton.icon(
                            onPressed: _addExpense,
                            icon: const Icon(Icons.add_card_rounded),
                            label: const Text('Shto shpenzim'),
                          )
                        : null,
                    child: job.expenses.isEmpty
                        ? const _EmptySection(
                            icon: Icons.receipt_long_outlined,
                            text:
                                'Nuk ka shpenzime të regjistruara për këtë projekt.',
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
                                    selectedJobIsCompleted
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.lock_outline_rounded,
                                                  size: 18),
                                              SizedBox(width: 6),
                                              Text('Vetëm lexim'),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              IconButton(
                                                tooltip: 'Ndrysho',
                                                icon: const Icon(
                                                    Icons.edit_rounded),
                                                onPressed: () =>
                                                    _editExpense(job, e),
                                              ),
                                              IconButton(
                                                tooltip: 'Fshij',
                                                icon: const Icon(Icons
                                                    .delete_outline_rounded),
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
                  if (completedJobs.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _GlassCard(
                      child: Padding(
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
                                    color: Colors.green.withOpacity(0.14),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Projektet e përfunduara',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Shiko historikun e projekteve të mbyllura me qarkullimin dhe fitimin e tyre.',
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
                                _StatPill(
                                  icon: Icons.done_all_rounded,
                                  text: '${completedJobs.length} projekte',
                                  color: Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.withOpacity(0.08),
                                    Colors.white.withOpacity(0.02),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor:
                                          Colors.white.withOpacity(0.06),
                                    ),
                                    child: DataTable(
                                      horizontalMargin: 22,
                                      columnSpacing: 30,
                                      headingRowHeight: 60,
                                      dataRowMinHeight: 72,
                                      dataRowMaxHeight: 76,
                                      headingRowColor: MaterialStatePropertyAll(
                                        Colors.green.withOpacity(0.10),
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('Projekti')),
                                        DataColumn(label: Text('Klienti')),
                                        DataColumn(
                                            label: Text('Përfunduar më')),
                                        DataColumn(label: Text('Qarkullimi')),
                                        DataColumn(label: Text('Fitimi')),
                                        DataColumn(label: Text('Veprime')),
                                      ],
                                      rows: completedJobs.map((p) {
                                        final profit = _profit(p);
                                        final isSelected =
                                            p.id == selectedJobId;

                                        return DataRow(
                                          selected: isSelected,
                                          color: MaterialStateProperty
                                              .resolveWith<Color?>(
                                            (states) {
                                              if (isSelected) {
                                                return Colors.green
                                                    .withOpacity(0.10);
                                              }
                                              return null;
                                            },
                                          ),
                                          cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      color: Colors.green
                                                          .withOpacity(0.12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.apartment_rounded,
                                                      size: 20,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 180),
                                                    child: Text(
                                                      p.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                p.clientName ?? '—',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.04),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.06),
                                                  ),
                                                ),
                                                child: Text(
                                                  p.completedAt == null
                                                      ? '—'
                                                      : _fmtDate(
                                                          p.completedAt!),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(_MoneyBadge(
                                                eur(p.contractAmount))),
                                            DataCell(
                                              profit >= 0
                                                  ? _MoneyBadge(eur(profit))
                                                  : _DangerBadge(eur(profit)),
                                            ),
                                            DataCell(
                                              Row(
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.10),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: Colors.blue
                                                            .withOpacity(0.22),
                                                      ),
                                                    ),
                                                    child: IconButton(
                                                      tooltip: 'Shiko detajet',
                                                      icon: const Icon(
                                                        Icons
                                                            .visibility_rounded,
                                                        color: Colors.blue,
                                                      ),
                                                      onPressed: () =>
                                                          _openCompletedJob(p),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.red
                                                          .withOpacity(0.10),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: Colors.red
                                                            .withOpacity(0.22),
                                                      ),
                                                    ),
                                                    child: IconButton(
                                                      tooltip: 'Printo PDF',
                                                      icon: const Icon(
                                                        Icons
                                                            .picture_as_pdf_rounded,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed: () async {
                                                        selectedJobId = p.id;
                                                        selectedTopTab = 1;
                                                        setState(() {});
                                                        await _exportPdfSelected();
                                                      },
                                                    ),
                                                  ),
                                                ],
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
                          ],
                        ),
                      ),
                    ),
                  ],
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

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

class _TopSwitchTab extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _TopSwitchTab({
    required this.selected,
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected
              ? color.withOpacity(0.14)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.45)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count projekte',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
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
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 235,
      child: Card(
        elevation: 0,
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
