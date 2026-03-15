import 'package:flutter/material.dart';
import '../data/dao_parameters.dart';
import '../models/parameters.dart';

class ParametratPage extends StatefulWidget {
  const ParametratPage({super.key});

  @override
  State<ParametratPage> createState() => _ParametratPageState();
}

class _ParametratPageState extends State<ParametratPage> {
  bool loading = true;
  bool saving = false;
  late Parameters p;

  final litersC = TextEditingController();
  final wasteC = TextEditingController();
  final coatsC = TextEditingController();

  final bucketPriceC = TextEditingController();
  final laborCategoryC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    litersC.dispose();
    wasteC.dispose();
    coatsC.dispose();
    bucketPriceC.dispose();
    laborCategoryC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    p = await ParametersDao.I.get();

    litersC.text = p.litersPer100.toStringAsFixed(2);
    wasteC.text = p.wastePct.toStringAsFixed(2);
    coatsC.text = p.coats.toString();

    bucketPriceC.text = p.bucketPrice.toStringAsFixed(2);
    laborCategoryC.text = p.laborCategory;

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);

    final liters = double.tryParse(litersC.text.replaceAll(',', '.')) ?? 0;
    final waste = double.tryParse(wasteC.text.replaceAll(',', '.')) ?? 0;
    final coats = int.tryParse(coatsC.text) ?? 1;

    final bucketPrice =
        double.tryParse(bucketPriceC.text.replaceAll(',', '.')) ?? 0;
    final laborCat = laborCategoryC.text.trim().isEmpty
        ? 'Punë dore'
        : laborCategoryC.text.trim();

    final newP = Parameters(
      litersPer100: liters.clamp(0, 9999),
      wastePct: waste.clamp(0, 100),
      coats: coats.clamp(1, 10),
      bucketPrice: bucketPrice.clamp(0, 999999),
      laborCategory: laborCat,
    );

    await ParametersDao.I.save(newP);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('Parametrat u ruajtën ✅'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );

    await _load();

    if (mounted) {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(
            title: 'Parametrat për ngjyrosje',
            subtitle:
                'Konfiguro konsumin, humbjet, shtresat dhe parametrat bazë për llogaritje.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: saving ? null : _load,
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
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Duke ruajtur...' : 'Ruaj parametrat'),
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
                    title: 'Litrat / 100m²',
                    value: litersC.text,
                    icon: Icons.opacity_outlined,
                    color: Colors.blue,
                  ),
                  _MiniStatCard(
                    width: cardWidth,
                    title: 'Humbja (%)',
                    value: wasteC.text,
                    icon: Icons.trending_down_rounded,
                    color: Colors.orange,
                  ),
                  _MiniStatCard(
                    width: cardWidth,
                    title: 'Shtresat',
                    value: coatsC.text,
                    icon: Icons.layers_outlined,
                    color: Colors.purple,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: cs.outline.withOpacity(0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Konfigurimi i parametrave',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ndrysho vlerat që përdoren për kalkulimin e ngjyrosjes.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _InputCard(
                            width: 330,
                            title: 'Konsumi i ngjyrës',
                            icon: Icons.opacity_outlined,
                            child: TextField(
                              controller: litersC,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _inputDecoration(
                                context,
                                label: 'Sa litra shkojnë në 100m²',
                                icon: Icons.water_drop_outlined,
                              ),
                            ),
                          ),
                          _InputCard(
                            width: 280,
                            title: 'Humbja',
                            icon: Icons.percent_rounded,
                            child: TextField(
                              controller: wasteC,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _inputDecoration(
                                context,
                                label: 'Humbje (%)',
                                icon: Icons.trending_down_rounded,
                              ),
                            ),
                          ),
                          _InputCard(
                            width: 240,
                            title: 'Shtresat',
                            icon: Icons.layers_outlined,
                            child: TextField(
                              controller: coatsC,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                context,
                                label: 'Shtresa (coats)',
                                icon: Icons.format_paint_outlined,
                              ),
                            ),
                          ),
                          _InputCard(
                            width: 300,
                            title: 'Çmimi i kovës',
                            icon: Icons.shopping_bag_outlined,
                            child: TextField(
                              controller: bucketPriceC,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _inputDecoration(
                                context,
                                label: 'Çmimi i kovës 25L (€)',
                                icon: Icons.euro_rounded,
                              ),
                            ),
                          ),
                          _InputCard(
                            width: 420,
                            title: 'Kategoria e punës',
                            icon: Icons.category_outlined,
                            child: TextField(
                              controller: laborCategoryC,
                              decoration: _inputDecoration(
                                context,
                                label: 'Kategoria e punës (nga Qmimore)',
                                icon: Icons.work_outline_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.primary.withOpacity(0.12),
                          ),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Këto vlera përdoren në kalkulimet e ngjyrosjes.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: saving ? null : _save,
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(saving ? 'Duke ruajtur...' : 'Ruaj'),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: cs.outline.withOpacity(0.18),
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
        border: Border.all(
          color: cs.outline.withOpacity(0.10),
        ),
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
                  Icons.palette_outlined,
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
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

class _InputCard extends StatelessWidget {
  final double width;
  final String title;
  final IconData icon;
  final Widget child;

  const _InputCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outline.withOpacity(0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
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
