import 'package:flutter/material.dart';
import '../data/dao_qmimorja.dart';
import '../models/qmimorja_item.dart';
import '../util/format.dart';

class QmimorePage extends StatefulWidget {
  const QmimorePage({super.key});

  @override
  State<QmimorePage> createState() => _QmimorePageState();
}

class _QmimorePageState extends State<QmimorePage> {
  bool loading = true;
  List<QmimorjaItem> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    items = await QmimorjaDao.I.list();
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _openEditor({QmimorjaItem? item}) async {
    final catC = TextEditingController(text: item?.category ?? 'Punë dore');
    final nameC = TextEditingController(text: item?.name ?? '');
    final unitC = TextEditingController(text: item?.unit ?? 'm²');
    final priceC = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(2) : '0',
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item == null
                    ? Icons.add_business_outlined
                    : Icons.edit_outlined,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item == null ? 'Shto çmim' : 'Ndrysho çmim',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: catC,
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  prefixIcon: const Icon(Icons.category_outlined),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameC,
                decoration: InputDecoration(
                  labelText: 'Emri',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitC,
                      decoration: InputDecoration(
                        labelText: 'Njësia (p.sh. m²)',
                        prefixIcon: const Icon(Icons.square_foot_outlined),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Çmimi (€)',
                        prefixIcon: const Icon(Icons.euro_rounded),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Ruaj'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );

    final category = catC.text.trim().isEmpty ? 'Tjetër' : catC.text.trim();
    final name = nameC.text.trim();
    final unit = unitC.text.trim().isEmpty ? 'm²' : unitC.text.trim();
    final price = double.tryParse(priceC.text.trim().replaceAll(',', '.')) ?? 0;

    catC.dispose();
    nameC.dispose();
    unitC.dispose();
    priceC.dispose();

    if (ok != true) return;
    if (name.isEmpty) return;

    final model = QmimorjaItem(
      id: item?.id,
      category: category,
      name: name,
      unit: unit,
      price: price,
    );

    if (item == null) {
      await QmimorjaDao.I.insert(model);
    } else {
      await QmimorjaDao.I.update(model);
    }

    await _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Fshij artikullin'),
        content: const Text('A je i sigurt që don me fshi këtë çmim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Fshij'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await QmimorjaDao.I.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalItems = items.length;
    final categories = items.map((e) => e.category).toSet().length;
    final avgPrice = items.isEmpty
        ? 0.0
        : items.fold<double>(0, (sum, e) => sum + e.price) / items.length;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(
            title: 'Qmimore',
            subtitle: 'Menaxho çmimet, kategoritë dhe njësitë e punës.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Shto çmim'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
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
              final cardWidth = constraints.maxWidth >= 1200
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 700
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MiniStatCard(
                    width: cardWidth,
                    title: 'Artikuj gjithsej',
                    value: '$totalItems',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.indigo,
                  ),
                  _MiniStatCard(
                    width: cardWidth,
                    title: 'Kategori',
                    value: '$categories',
                    icon: Icons.category_outlined,
                    color: Colors.orange,
                  ),
                  _MiniStatCard(
                    width: cardWidth,
                    title: 'Çmimi mesatar',
                    value: eur(avgPrice),
                    icon: Icons.euro_rounded,
                    color: Colors.green,
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
                child: items.isEmpty
                    ? _EmptyState(
                        onAdd: () => _openEditor(),
                      )
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
                                    Icons.table_rows_outlined,
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
                                        'Lista e çmimeve',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tabela e plotë e qmimores',
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
                                            dataRowMinHeight: 60,
                                            dataRowMaxHeight: 70,
                                            headingRowColor:
                                                WidgetStatePropertyAll(
                                              cs.primary.withOpacity(0.08),
                                            ),
                                            columns: [
                                              _buildColumn('Kategoria'),
                                              _buildColumn('Emri'),
                                              _buildColumn('Njësia'),
                                              _buildColumn('Çmimi'),
                                              _buildColumn('Veprime'),
                                            ],
                                            rows: List.generate(items.length,
                                                (index) {
                                              final e = items[index];

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
                                                    _CategoryChip(
                                                        text: e.category),
                                                  ),
                                                  DataCell(
                                                    SizedBox(
                                                      width: 260,
                                                      child: Text(
                                                        e.name,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    _UnitChip(text: e.unit),
                                                  ),
                                                  DataCell(
                                                    _PriceBadge(
                                                      text: eur(e.price),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Tooltip(
                                                          message: 'Ndrysho',
                                                          child: InkWell(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            onTap: () =>
                                                                _openEditor(
                                                                    item: e),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(10),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .blue
                                                                    .withOpacity(
                                                                        0.12),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 20,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Tooltip(
                                                          message: 'Fshij',
                                                          child: InkWell(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            onTap: () =>
                                                                _delete(e.id!),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(10),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .withOpacity(
                                                                        0.12),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 20,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
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
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _HeaderCard({
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
                  Icons.price_change_outlined,
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

class _MiniStatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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

class _CategoryChip extends StatelessWidget {
  final String text;

  const _CategoryChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepPurple.withOpacity(0.24),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.deepPurpleAccent,
            ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String text;

  const _UnitChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blueGrey.withOpacity(0.24),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final String text;

  const _PriceBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.withOpacity(0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.euro_rounded,
            size: 16,
            color: Colors.greenAccent,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.greenAccent,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({
    required this.onAdd,
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
                Icons.price_check_outlined,
                size: 38,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Nuk ka artikuj në qmimore',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Shto artikullin e parë dhe tabela do të shfaqet këtu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Shto çmim'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
