import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/dao_jobs.dart';
import '../models/job_project.dart';
import '../util/format.dart';
import '../util/qarkullimi_vjetor_pdf.dart';

class QarkullimiVjetorPage extends StatefulWidget {
  const QarkullimiVjetorPage({super.key});

  @override
  State<QarkullimiVjetorPage> createState() => _QarkullimiVjetorPageState();
}

class _QarkullimiVjetorPageState extends State<QarkullimiVjetorPage> {
  bool loading = true;
  late int selectedYear;

  List<JobProject> allJobs = [];

  @override
  void initState() {
    super.initState();
    selectedYear = DateTime.now().year;
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => loading = true);

    allJobs = await JobsDao.I.listJobs();

    final years = _availableYearsFrom(allJobs);
    if (!years.contains(selectedYear)) {
      selectedYear = years.first;
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  List<int> _availableYearsFrom(List<JobProject> jobs) {
    final years = jobs.map((e) => e.createdAt.year).toSet().toList()..sort();

    if (years.isEmpty) {
      years.add(DateTime.now().year);
    } else if (!years.contains(DateTime.now().year)) {
      years.add(DateTime.now().year);
      years.sort();
    }

    return years.reversed.toList();
  }

  List<int> _availableYears() {
    return _availableYearsFrom(allJobs);
  }

  List<JobProject> _jobsForYear(int year) {
    return allJobs.where((j) => j.createdAt.year == year).toList()
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
    if (allJobs.isEmpty) return;

    final bytes = await QarkullimiVjetorPdf.buildAllJobs(
      jobs: allJobs,
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
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('PDF u ruajt: ${loc.path}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final years = _availableYears();
    if (!years.contains(selectedYear)) {
      selectedYear = years.first;
    }

    final rows = _jobsForYear(selectedYear);

    final totalJobs = rows.length;
    final totalQarkullimi =
        rows.fold<double>(0, (s, e) => s + e.contractAmount);
    final totalExpenses = rows.fold<double>(0, (s, e) => s + _expensesTotal(e));
    final totalInvestment =
        rows.fold<double>(0, (s, e) => s + _investmentTotal(e));
    final totalProfit = rows.fold<double>(0, (s, e) => s + _profit(e));

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopHeaderCard(
            title: 'Qarkullimi Vjetor',
            subtitle:
                'Përmbledhje e projekteve, qarkullimit, investimeve dhe fitimit sipas vitit.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<int>(
                    value: selectedYear,
                    items: years
                        .map(
                          (y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text('Viti $y'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => selectedYear = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'Zgjedh vitin',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      filled: true,
                      fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: cs.outline.withOpacity(0.18),
                        ),
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadJobs,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: rows.isEmpty ? null : _exportPdfSelectedYear,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF (ky vit)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: allJobs.isEmpty ? null : _exportPdfAllYears,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('PDF (krejt)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 1400
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 900
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth >= 600
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    width: cardWidth,
                    title: 'Punë gjithsej',
                    value: totalJobs.toString(),
                    icon: Icons.work_outline_rounded,
                    color: Colors.indigo,
                  ),
                  _StatCard(
                    width: cardWidth,
                    title: 'Qarkullimi total',
                    value: eur(totalQarkullimi),
                    icon: Icons.payments_outlined,
                    color: Colors.green,
                  ),
                  _StatCard(
                    width: cardWidth,
                    title: 'Investimi total',
                    value: eur(totalInvestment),
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.blue,
                  ),
                  _StatCard(
                    width: cardWidth,
                    title: 'Shpenzimet totale',
                    value: eur(totalExpenses),
                    icon: Icons.receipt_long_outlined,
                    color: Colors.orange,
                  ),
                  _StatCard(
                    width: cardWidth,
                    title: 'Fitimi total',
                    value: eur(totalProfit),
                    icon: totalProfit < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    color: totalProfit < 0 ? Colors.red : Colors.purple,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: cs.outline.withOpacity(0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: rows.isEmpty
                    ? _EmptyState(selectedYear: selectedYear)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.table_chart_outlined,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tabela e qarkullimit',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Lista e të gjitha punëve për vitin $selectedYear',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: cs.outline.withOpacity(0.12),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SingleChildScrollView(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth,
                                          ),
                                          child: DataTable(
                                            columnSpacing: 28,
                                            horizontalMargin: 18,
                                            headingRowHeight: 58,
                                            dataRowMinHeight: 58,
                                            dataRowMaxHeight: 68,
                                            headingRowColor:
                                                WidgetStatePropertyAll(
                                              cs.primary.withOpacity(0.08),
                                            ),
                                            columns: [
                                              _buildColumn('Nr.'),
                                              _buildColumn('Data'),
                                              _buildColumn('Puna'),
                                              _buildColumn('Klienti'),
                                              _buildColumn('Qarkullimi'),
                                              _buildColumn('Shpenzime'),
                                              _buildColumn('Investimi'),
                                              _buildColumn('Fitimi'),
                                            ],
                                            rows: [
                                              ...List.generate(rows.length,
                                                  (index) {
                                                final job = rows[index];
                                                final expenses =
                                                    _expensesTotal(job);
                                                final investment =
                                                    _investmentTotal(job);
                                                final profit = _profit(job);

                                                return DataRow(
                                                  color: WidgetStateProperty
                                                      .resolveWith<Color?>(
                                                    (states) {
                                                      if (index.isEven) {
                                                        return cs.surface;
                                                      }
                                                      return cs
                                                          .surfaceContainerHighest
                                                          .withOpacity(0.18);
                                                    },
                                                  ),
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        '${index + 1}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(_fmtDate(
                                                          job.createdAt)),
                                                    ),
                                                    DataCell(
                                                      SizedBox(
                                                        width: 220,
                                                        child: Text(
                                                          job.name,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      SizedBox(
                                                        width: 170,
                                                        child: Text(
                                                          job.clientName ?? '—',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _MoneyBadge(eur(
                                                          job.contractAmount)),
                                                    ),
                                                    DataCell(
                                                      _ExpenseBadge(
                                                          eur(expenses)),
                                                    ),
                                                    DataCell(
                                                      _InvestBadge(
                                                          eur(investment)),
                                                    ),
                                                    DataCell(
                                                      _ProfitBadge(eur(profit)),
                                                    ),
                                                  ],
                                                );
                                              }),
                                              DataRow(
                                                color: WidgetStatePropertyAll(
                                                  cs.primary.withOpacity(0.10),
                                                ),
                                                cells: [
                                                  const DataCell(Text('')),
                                                  const DataCell(Text('')),
                                                  DataCell(
                                                    Text(
                                                      'TOTAL',
                                                      style: theme
                                                          .textTheme.titleSmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                  const DataCell(Text('—')),
                                                  DataCell(
                                                    _MoneyBadge(
                                                        eur(totalQarkullimi)),
                                                  ),
                                                  DataCell(
                                                    _ExpenseBadge(
                                                        eur(totalExpenses)),
                                                  ),
                                                  DataCell(
                                                    _InvestBadge(
                                                        eur(totalInvestment)),
                                                  ),
                                                  DataCell(
                                                    _ProfitBadge(
                                                        eur(totalProfit)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildColumn(String title) {
    return DataColumn(
      label: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _TopHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _TopHeaderCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.14),
            cs.secondary.withOpacity(0.08),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cs.outline.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: cs.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int selectedYear;

  const _EmptyState({
    required this.selectedYear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 36,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Nuk ka punë për vitin $selectedYear',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Kur të ketë të dhëna, tabela do të shfaqet këtu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: color.withOpacity(0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
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
    return _Badge(
      text: text,
      bg: Colors.green.withOpacity(0.16),
      border: Colors.green.withOpacity(0.35),
      textColor: Colors.greenAccent,
      icon: Icons.attach_money_rounded,
    );
  }
}

class _ExpenseBadge extends StatelessWidget {
  final String text;
  const _ExpenseBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return _Badge(
      text: text,
      bg: Colors.orange.withOpacity(0.14),
      border: Colors.orange.withOpacity(0.35),
      textColor: Colors.orangeAccent,
      icon: Icons.receipt_long_rounded,
    );
  }
}

class _InvestBadge extends StatelessWidget {
  final String text;
  const _InvestBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return _Badge(
      text: text,
      bg: Colors.blue.withOpacity(0.14),
      border: Colors.blue.withOpacity(0.35),
      textColor: Colors.lightBlueAccent,
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}

class _ProfitBadge extends StatelessWidget {
  final String text;
  const _ProfitBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final isNegative = text.startsWith('-');

    return _Badge(
      text: text,
      bg: isNegative
          ? Colors.red.withOpacity(0.16)
          : Colors.purple.withOpacity(0.16),
      border: isNegative
          ? Colors.red.withOpacity(0.35)
          : Colors.purple.withOpacity(0.35),
      textColor: isNegative ? Colors.redAccent : Colors.purpleAccent,
      icon:
          isNegative ? Icons.trending_down_rounded : Icons.trending_up_rounded,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color textColor;
  final IconData icon;

  const _Badge({
    required this.text,
    required this.bg,
    required this.border,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }
}
