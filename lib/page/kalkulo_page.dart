import 'package:flutter/material.dart';
import '../data/dao_calc_products.dart';
import '../data/dao_parameters.dart';
import '../data/dao_prices.dart';
import '../models/parameters.dart';
import '../models/price_item.dart';
import '../models/product_calc_item.dart';
import '../util/format.dart';

class KalkuloPage extends StatefulWidget {
  const KalkuloPage({super.key});

  @override
  State<KalkuloPage> createState() => _KalkuloPageState();
}

class _KalkuloPageState extends State<KalkuloPage> {
  final m2C = TextEditingController();

  Parameters? p;
  List<PriceItem> laborItems = [];
  PriceItem? selectedLabor;

  List<ProductCalcItem> products = [];
  final Set<int> selectedProductIds = {};

  bool includePaint = true;

  static const double bucketSize = 25.0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    m2C.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      p = await ParametersDao.I.get();

      final allPrices = await PricesDao.I.list();
      final cat = p?.laborCategory ?? 'Punë dore';

      laborItems = allPrices.where((x) => x.category == cat).toList();

      if (laborItems.isNotEmpty) {
        selectedLabor = laborItems.firstWhere(
          (x) => x.unit.toLowerCase().contains('m'),
          orElse: () => laborItems.first,
        );
      } else {
        selectedLabor = null;
      }

      products = await CalcProductsDao.I.list();

      final validIds =
          products.where((e) => e.id != null).map((e) => e.id!).toSet();
      selectedProductIds.removeWhere((id) => !validIds.contains(id));

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë leximit të të dhënave: $e')),
      );
    }
  }

  double _toDouble(String v) {
    return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
  }

  double _calcLiters(double m2) {
    final par = p;
    if (par == null || !includePaint) return 0;
    final base = (m2 * par.litersPer100 / 100.0) * par.coats;
    return base * (1.0 + par.wastePct / 100.0);
  }

  int _calcBuckets(double liters) {
    if (liters <= 0) return 0;
    return (liters / bucketSize).ceil();
  }

  List<ProductCalcItem> get _selectedProducts {
    return products
        .where((x) => x.id != null && selectedProductIds.contains(x.id))
        .toList();
  }

  void _toggleSelected(ProductCalcItem item, bool? checked) {
    if (item.id == null) return;

    setState(() {
      if (checked == true) {
        selectedProductIds.add(item.id!);
      } else {
        selectedProductIds.remove(item.id!);
      }
    });
  }

  Future<void> _openSelectProductsDialog() async {
    final tempSelected = <int>{...selectedProductIds};

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Zgjedh produktet për kalkulim'),
              content: SizedBox(
                width: 560,
                child: products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Nuk ka produkte të regjistruara.'),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: products.map((x) {
                            final checked =
                                x.id != null && tempSelected.contains(x.id);

                            final totalPer100 =
                                x.vleraPer100m2 + x.tvshPer100m2;

                            return CheckboxListTile(
                              value: checked,
                              contentPadding: EdgeInsets.zero,
                              title: Text(x.emertimi),
                              subtitle: Text(
                                '${x.kodi} • ${x.pako} • '
                                'Sasia/100m²: ${x.sasiaPer100m2.toStringAsFixed(2)} • '
                                'Vlera/100m²: ${eur(x.vleraPer100m2)} • '
                                'TVSH/100m²: ${eur(x.tvshPer100m2)} • '
                                'Gjithsej/100m²: ${eur(totalPer100)}',
                              ),
                              onChanged: (v) {
                                if (x.id == null) return;
                                setLocalState(() {
                                  if (v == true) {
                                    tempSelected.add(x.id!);
                                  } else {
                                    tempSelected.remove(x.id!);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Anulo'),
                ),
                TextButton(
                  onPressed: () {
                    setLocalState(() {
                      tempSelected.clear();
                      for (final x in products) {
                        if (x.id != null) tempSelected.add(x.id!);
                      }
                    });
                  },
                  child: const Text('Selekto krejt'),
                ),
                TextButton(
                  onPressed: () {
                    setLocalState(() {
                      tempSelected.clear();
                    });
                  },
                  child: const Text('Hiqi krejt'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      selectedProductIds
                        ..clear()
                        ..addAll(tempSelected);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Ruaj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openProductDialog({ProductCalcItem? item}) async {
    final kodiC = TextEditingController(text: item?.kodi ?? '');
    final emertimiC = TextEditingController(text: item?.emertimi ?? '');
    final pakoC = TextEditingController(text: item?.pako ?? '');
    final sasiaC = TextEditingController(
      text: item != null ? item.sasiaPer100m2.toString() : '',
    );
    final vleraC = TextEditingController(
      text: item != null ? item.vleraPer100m2.toString() : '',
    );
    final tvshC = TextEditingController(
      text: item != null ? item.tvshPer100m2.toString() : '0',
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final m2 = _toDouble(m2C.text);

            // KREJT këto ruhen për 100m²
            final sasiaPer100 = _toDouble(sasiaC.text);
            final vleraPer100 = _toDouble(vleraC.text);
            final tvshPer100 = _toDouble(tvshC.text);

            // Këto janë vetëm preview sipas m² aktuale
            final factor = m2 / 100.0;
            final sasiaTotale = sasiaPer100 * factor;
            final vleraTotale = vleraPer100 * factor;
            final tvshTotale = tvshPer100 * factor;
            final gjithsej = vleraTotale + tvshTotale;

            return AlertDialog(
              title: Text(item == null ? 'Shto produkt' : 'Përditëso produktin'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: kodiC,
                        decoration: const InputDecoration(
                          labelText: 'KODI',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emertimiC,
                        decoration: const InputDecoration(
                          labelText: 'EMËRTIMI',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pakoC,
                        decoration: const InputDecoration(
                          labelText: 'PAKO',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: sasiaC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'SASIA për 100m²',
                          hintText: 'p.sh. 60',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: vleraC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'VLERA për 100m²',
                          hintText: 'p.sh. 120.00',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tvshC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'TVSH për 100m²',
                          hintText: 'p.sh. 21.60',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Këto vlera ruhen për 100m²',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text('Sasia/100m²: ${sasiaPer100.toStringAsFixed(2)}'),
                            Text('Vlera/100m²: ${eur(vleraPer100)}'),
                            Text('TVSH/100m²: ${eur(tvshPer100)}'),
                            const Divider(),
                            Text(
                              'Preview për ${m2.toStringAsFixed(2)} m²',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text('Sasia totale: ${sasiaTotale.toStringAsFixed(2)}'),
                            Text('Vlera totale: ${eur(vleraTotale)}'),
                            Text('TVSH totale: ${eur(tvshTotale)}'),
                            const Divider(),
                            Text(
                              'Vlera + TVSH: ${eur(gjithsej)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Anulo'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final newItem = ProductCalcItem(
                        id: item?.id,
                        kodi: kodiC.text.trim(),
                        emertimi: emertimiC.text.trim(),
                        pako: pakoC.text.trim(),
                        sasiaPer100m2: _toDouble(sasiaC.text),
                        vleraPer100m2: _toDouble(vleraC.text),
                        tvshPer100m2: _toDouble(tvshC.text),
                      );

                      if (newItem.kodi.isEmpty || newItem.emertimi.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Plotëso KODI dhe EMËRTIMI.'),
                          ),
                        );
                        return;
                      }

                      if (item == null) {
                        final insertedId = await CalcProductsDao.I.insert(newItem);

                        if (insertedId <= 0) {
                          throw Exception('Insert nuk ktheu ID valide.');
                        }

                        // automatikisht shtohet në kalkulim sapo ruhet
                        selectedProductIds.add(insertedId);
                      } else {
                        await CalcProductsDao.I.update(newItem);
                        if (newItem.id != null) {
                          selectedProductIds.add(newItem.id!);
                        }
                      }

                      await _loadAll();

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }

                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            item == null
                                ? 'Produkti u shtua me sukses.'
                                : 'Produkti u përditësua me sukses.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gabim gjatë ruajtjes: $e')),
                      );
                    }
                  },
                  child: const Text('Ruaj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(ProductCalcItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fshije produktin?'),
        content: Text('A je i sigurt që don me fshi "${item.emertimi}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Jo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Po'),
          ),
        ],
      ),
    );

    if (ok == true && item.id != null) {
      selectedProductIds.remove(item.id!);
      await CalcProductsDao.I.delete(item.id!);
      await _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m2 = _toDouble(m2C.text);

    final liters = _calcLiters(m2);
    final buckets = _calcBuckets(liters);

    final bucketPrice = includePaint ? (p?.bucketPrice ?? 0) : 0;
    final paintTotal = buckets * bucketPrice;

    final laborPrice = selectedLabor?.price ?? 0;
    final laborTotal = m2 * laborPrice;

    final calcProducts = _selectedProducts;

    final materialTotalPaTvsh = calcProducts.fold<double>(
      0,
      (sum, x) => sum + x.vleraPaTvsh(m2),
    );

    final materialTotalTvsh = calcProducts.fold<double>(
      0,
      (sum, x) => sum + x.vleraTvsh(m2),
    );

    final materialTotalMeTvsh = calcProducts.fold<double>(
      0,
      (sum, x) => sum + x.vleraMeTvsh(m2),
    );

    final grandTotal = materialTotalMeTvsh + laborTotal + paintTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Kalkulo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              OutlinedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Rifresko'),
              ),
              FilledButton.icon(
                onPressed: () => _openProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Shto produkt'),
              ),
              OutlinedButton.icon(
                onPressed: _openSelectProductsDialog,
                icon: const Icon(Icons.playlist_add_check),
                label: Text('Zgjedh produktet (${selectedProductIds.length})'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p == null)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Duke i lexu parametrat...'),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: includePaint,
                          onChanged: (v) {
                            setState(() {
                              includePaint = v ?? true;
                            });
                          },
                        ),
                        const Text('Me ly'),
                      ],
                    ),
                    if (includePaint) ...[
                      Text('L/100m²: ${p!.litersPer100}'),
                      Text('Humbje: ${p!.wastePct}%'),
                      Text('Shtresa: ${p!.coats}'),
                      Text('Kova: ${bucketSize.toStringAsFixed(0)}L'),
                      Text('Çmimi kove: ${eur(p!.bucketPrice)}'),
                    ],
                    Text('Kategori pune: ${p!.laborCategory}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: m2C,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Sipërfaqja (m²)',
                    hintText: 'p.sh. 120',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 420,
                child: DropdownButtonFormField<PriceItem>(
                  value: selectedLabor,
                  items: laborItems
                      .map(
                        (x) => DropdownMenuItem(
                          value: x,
                          child: Text('${x.name} • ${eur(x.price)}/${x.unit}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedLabor = v),
                  decoration: const InputDecoration(
                    labelText: 'Zgjedh punën',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  if (includePaint) ...[
                    _StatPill(
                      icon: Icons.inventory_2_outlined,
                      label: 'Kova',
                      value: '$buckets',
                    ),
                    _StatPill(
                      icon: Icons.opacity_outlined,
                      label: 'Litra',
                      value: '${liters.toStringAsFixed(2)} L',
                    ),
                    _StatPill(
                      icon: Icons.format_paint_outlined,
                      label: 'Bojë',
                      value: eur(paintTotal),
                    ),
                  ],
                  _StatPill(
                    icon: Icons.handyman_outlined,
                    label: p?.laborCategory ?? 'Punë',
                    value: '${eur(laborTotal)} (${eur(laborPrice)}/m²)',
                  ),
                  _StatPill(
                    icon: Icons.widgets_outlined,
                    label: 'Materiale pa TVSH',
                    value: eur(materialTotalPaTvsh),
                  ),
                  _StatPill(
                    icon: Icons.percent_outlined,
                    label: 'TVSH totale',
                    value: eur(materialTotalTvsh),
                  ),
                  _StatPill(
                    icon: Icons.receipt_long_outlined,
                    label: 'Materiale me TVSH',
                    value: eur(materialTotalMeTvsh),
                  ),
                  _StatPill(
                    icon: Icons.checklist_outlined,
                    label: 'Produkte në kalkulim',
                    value: '${calcProducts.length}',
                  ),
                  _StatPill(
                    icon: Icons.calculate_outlined,
                    label: 'Totali final',
                    value: eur(grandTotal),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Produktet e materialit',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: products.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nuk ka produkte. Shto produkte për kalkulim.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Në kalkulim')),
                        DataColumn(label: Text('KODI')),
                        DataColumn(label: Text('EMËRTIMI')),
                        DataColumn(label: Text('PAKO')),
                        DataColumn(label: Text('SASIA totale')),
                        DataColumn(label: Text('VLERA totale')),
                        DataColumn(label: Text('TVSH totale')),
                        DataColumn(label: Text('VLERA + TVSH')),
                        DataColumn(label: Text('Veprime')),
                      ],
                      rows: products.map((item) {
                        final isSelected =
                            item.id != null && selectedProductIds.contains(item.id);

                        final sasia = item.qtyForM2(m2);
                        final vlera = item.vleraPaTvsh(m2);
                        final tvsh = item.vleraTvsh(m2);
                        final total = item.vleraMeTvsh(m2);

                        return DataRow(
                          selected: isSelected,
                          cells: [
                            DataCell(
                              Checkbox(
                                value: isSelected,
                                onChanged: (v) => _toggleSelected(item, v),
                              ),
                            ),
                            DataCell(Text(item.kodi)),
                            DataCell(Text(item.emertimi)),
                            DataCell(Text(item.pako)),
                            DataCell(Text(sasia.toStringAsFixed(2))),
                            DataCell(Text(eur(vlera))),
                            DataCell(Text(eur(tvsh))),
                            DataCell(Text(eur(total))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Ndrysho',
                                    onPressed: () => _openProductDialog(item: item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Fshij',
                                    onPressed: () => _deleteProduct(item),
                                    icon: const Icon(Icons.delete_outline),
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
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).cardColor.withOpacity(0.35),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}