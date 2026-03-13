import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../util/format.dart';
import '../util/qarkullimi_vjetor_pdf.dart';
import 'punet_page.dart';

class QarkullimiVjetorPage extends StatefulWidget {
  const QarkullimiVjetorPage({super.key});

  @override
  State<QarkullimiVjetorPage> createState() => _QarkullimiVjetorPageState();
}

class _QarkullimiVjetorPageState extends State<QarkullimiVjetorPage> {
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    selectedYear = DateTime.now().year;
  }

  List<JobProject> get _allJobs => JobMemoryStore.I.jobs;

  List<int> _availableYears() {
    final years = _allJobs.map((e) => e.createdAt.year).toSet().toList()..sort();

    if (years.isEmpty) {
      years.add(DateTime.now().year);
    } else if (!years.contains(DateTime.now().year)) {
      years.add(DateTime.now().year);
      years.sort();
    }

    return years.reversed.toList();
  }

  List<JobProject> _jobsForYear(int year) {
    return _allJobs.where((j) => j.createdAt.year == year).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

  Future<void> _exportPdfSelectedYear() async {
    final rows = _jobsForYear(selectedYear);
    if (rows.isEmpty) return;

    final bytes = await QarkullimiVjetorPdf.buildForYear(
      year: selectedYear,
      jobs: rows,
    );

    await _savePdf(
      bytes: bytes,
      filename: 'qarkullimi_vjetor_$selectedYear.pdf',
    );
  }

  Future<void> _exportPdfAllYears() async {
    if (_allJobs.isEmpty) return;

    final bytes = await QarkullimiVjetorPdf.buildAllJobs(
      jobs: _allJobs,
    );

    await _savePdf(
      bytes: bytes,
      filename: 'qarkullimi_vjetor_krejt.pdf',
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

  @override
  Widget build(BuildContext context) {
    final years = _availableYears();
    if (!years.contains(selectedYear)) {
      selectedYear = years.first;
    }

    final rows = _jobsForYear(selectedYear);

    final totalJobs = rows.length;
    final totalQarkullimi = rows.fold<double>(0, (s, e) => s + e.contractAmount);
    final totalExpenses = rows.fold<double>(0, (s, e) => s + _expensesTotal(e));
    final totalInvestment = rows.fold<double>(0, (s, e) => s + _investmentTotal(e));
    final totalProfit = rows.fold<double>(0, (s, e) => s + _profit(e));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Qarkullimi Vjetor',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: rows.isEmpty ? null : _exportPdfSelectedYear,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF (ky vit)'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _allJobs.isEmpty ? null : _exportPdfAllYears,
              icon: const Icon(Icons.download),
              label: const Text('PDF (krejt)'),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                value: selectedYear,
                items: years
                    .map(
                      (y) => DropdownMenuItem<int>(
                        value: y,
                        child: Text(y.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => selectedYear = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Viti',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              title: 'Punë gjithsej',
              value: totalJobs.toString(),
              icon: Icons.work_outline,
            ),
            _StatCard(
              title: 'Qarkullimi total',
              value: eur(totalQarkullimi),
              icon: Icons.payments_outlined,
            ),
            _StatCard(
              title: 'Investimi total',
              value: eur(totalInvestment),
              icon: Icons.account_balance_wallet_outlined,
            ),
            _StatCard(
              title: 'Shpenzimet totale',
              value: eur(totalExpenses),
              icon: Icons.receipt_long_outlined,
            ),
            _StatCard(
              title: 'Fitimi total',
              value: eur(totalProfit),
              icon: Icons.trending_up,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'Nuk ka punë për vitin $selectedYear.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 52,
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 64,
                                columns: const [
                                  DataColumn(label: Text('Nr.')),
                                  DataColumn(label: Text('Data')),
                                  DataColumn(label: Text('Puna')),
                                  DataColumn(label: Text('Klienti')),
                                  DataColumn(label: Text('Qarkullimi')),
                                  DataColumn(label: Text('Shpenzime')),
                                  DataColumn(label: Text('Investimi')),
                                  DataColumn(label: Text('Fitimi')),
                                ],
                                rows: [
                                  ...List.generate(rows.length, (index) {
                                    final job = rows[index];
                                    final expenses = _expensesTotal(job);
                                    final investment = _investmentTotal(job);
                                    final profit = _profit(job);

                                    return DataRow(
                                      cells: [
                                        DataCell(Text('${index + 1}')),
                                        DataCell(Text(_fmtDate(job.createdAt))),
                                        DataCell(Text(job.name)),
                                        DataCell(Text(job.clientName ?? '—')),
                                        DataCell(_MoneyBadge(eur(job.contractAmount))),
                                        DataCell(_ExpenseBadge(eur(expenses))),
                                        DataCell(_InvestBadge(eur(investment))),
                                        DataCell(_ProfitBadge(eur(profit))),
                                      ],
                                    );
                                  }),
                                  DataRow(
                                    color: WidgetStatePropertyAll(
                                      Colors.white.withOpacity(0.06),
                                    ),
                                    cells: [
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      DataCell(
                                        Text(
                                          'TOTAL',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const DataCell(Text('—')),
                                      DataCell(_MoneyBadge(eur(totalQarkullimi))),
                                      DataCell(_ExpenseBadge(eur(totalExpenses))),
                                      DataCell(_InvestBadge(eur(totalInvestment))),
                                      DataCell(_ProfitBadge(eur(totalProfit))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
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

class _InvestBadge extends StatelessWidget {
  final String text;
  const _InvestBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.lightBlueAccent,
            ),
      ),
    );
  }
}

class _ProfitBadge extends StatelessWidget {
  final String text;
  const _ProfitBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final isNegative = text.startsWith('-');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isNegative
            ? Colors.red.withOpacity(0.16)
            : Colors.purple.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNegative
              ? Colors.red.withOpacity(0.35)
              : Colors.purple.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isNegative ? Colors.redAccent : Colors.purpleAccent,
            ),
      ),
    );
  }
}