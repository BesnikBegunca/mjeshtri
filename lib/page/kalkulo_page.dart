import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/dao_calc_products.dart';
import '../data/dao_firma.dart';
import '../data/dao_parameters.dart';
import '../data/dao_qmimorja.dart';
import '../models/firma_info.dart';
import '../models/parameters.dart';
import '../models/product_calc_item.dart';
import '../models/qmimorja_item.dart';
import '../util/format.dart';

class KalkuloPage extends StatefulWidget {
  const KalkuloPage({super.key});

  @override
  State<KalkuloPage> createState() => _KalkuloPageState();
}

class _KalkuloPageState extends State<KalkuloPage> {
  final m2C = TextEditingController();
  final fixedLaborC = TextEditingController();

  Parameters? p;
  FirmaInfo firma = FirmaInfo.empty();

  List<QmimorjaItem> laborItems = [];
  QmimorjaItem? selectedLabor;

  List<ProductCalcItem> products = [];
  final Set<int> selectedProductIds = {};

  bool includePaint = true;
  bool laborFixedValue = false;

  static const double bucketSize = 25.0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    m2C.dispose();
    fixedLaborC.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      p = await ParametersDao.I.get();
      firma = await FirmaDao.I.get();

      final allPrices = await QmimorjaDao.I.list();
      final cat = (p?.laborCategory ?? 'Punë dore').trim().toLowerCase();

      laborItems = allPrices.where((x) {
        return x.category.trim().toLowerCase() == cat;
      }).toList();

      if (laborItems.isNotEmpty) {
        final currentId = selectedLabor?.id;

        if (currentId != null) {
          try {
            selectedLabor = laborItems.firstWhere((x) => x.id == currentId);
          } catch (_) {
            selectedLabor = laborItems.firstWhere(
              (x) => x.unit.toLowerCase().contains('m'),
              orElse: () => laborItems.first,
            );
          }
        } else {
          selectedLabor = laborItems.firstWhere(
            (x) => x.unit.toLowerCase().contains('m'),
            orElse: () => laborItems.first,
          );
        }
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

  String _invoiceMoney(num value) => '${value.toStringAsFixed(2)} EURO';

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(Icons.playlist_add_check_circle_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Zgjedh produktet për kalkulim'),
                  ),
                ],
              ),
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: checked
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).dividerColor,
                                ),
                                color: checked
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.06)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.25),
                              ),
                              child: CheckboxListTile(
                                value: checked,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(
                                  x.emertimi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${x.kodi} • ${x.pako} • '
                                    'Sasia/100m²: ${x.sasiaPer100m2.toStringAsFixed(2)} • '
                                    'Vlera/100m²: ${eur(x.vleraPer100m2)} • '
                                    'TVSH/100m²: ${eur(x.tvshPer100m2)} • '
                                    'Gjithsej/100m²: ${eur(totalPer100)}',
                                  ),
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
                              ),
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
                OutlinedButton(
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
                OutlinedButton(
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
            final double m2 = _toDouble(m2C.text);

            final double sasiaPer100 = _toDouble(sasiaC.text);
            final double vleraPer100 = _toDouble(vleraC.text);
            final double tvshPer100 = _toDouble(tvshC.text);

            final double factor = m2 / 100.0;
            final double sasiaTotale = sasiaPer100 * factor;
            final double vleraTotale = vleraPer100 * factor;
            final double tvshTotale = tvshPer100 * factor;
            final double gjithsej = vleraTotale + tvshTotale;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(item == null
                      ? Icons.add_box_outlined
                      : Icons.edit_note_outlined),
                  const SizedBox(width: 10),
                  Text(item == null ? 'Shto produkt' : 'Përditëso produktin'),
                ],
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PremiumTextField(
                        controller: kodiC,
                        label: 'KODI',
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: emertimiC,
                        label: 'EMËRTIMI',
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: pakoC,
                        label: 'PAKO',
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: sasiaC,
                        label: 'SASIA për 100m²',
                        hint: 'p.sh. 60',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: vleraC,
                        label: 'VLERA për 100m²',
                        hint: 'p.sh. 120.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: tvshC,
                        label: 'TVSH për 100m²',
                        hint: 'p.sh. 21.60',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Këto vlera ruhen për 100m²',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sasia/100m²: ${sasiaPer100.toStringAsFixed(2)}',
                            ),
                            Text('Vlera/100m²: ${eur(vleraPer100)}'),
                            Text('TVSH/100m²: ${eur(tvshPer100)}'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),
                            Text(
                              'Preview për ${m2.toStringAsFixed(2)} m²',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sasia totale: ${sasiaTotale.toStringAsFixed(2)}',
                            ),
                            Text('Vlera totale: ${eur(vleraTotale)}'),
                            Text('TVSH totale: ${eur(tvshTotale)}'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),
                            Text(
                              'Vlera + TVSH: ${eur(gjithsej)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
                        final insertedId =
                            await CalcProductsDao.I.insert(newItem);

                        if (insertedId <= 0) {
                          throw Exception('Insert nuk ktheu ID valide.');
                        }

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
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

  Future<void> _openInvoiceDialog() async {
    final m2 = _toDouble(m2C.text);
    final selectedProducts = _selectedProducts;

    if (m2 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shkruaje sipërfaqen (m²) para gjenerimit të faturës.'),
        ),
      );
      return;
    }

    if (selectedProducts.isEmpty && !includePaint && selectedLabor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nuk ka asgjë për me gjeneru në faturë.'),
        ),
      );
      return;
    }

    final invoiceNoC = TextEditingController(
      text:
          'F-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final clientC = TextEditingController();
    final projectC = TextEditingController();
    final noteC = TextEditingController();

    bool showCode = true;
    bool showName = true;
    bool showPack = false;
    bool showQty = true;
    bool showValue = true;
    bool showVat = true;
    bool showTotal = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final selectedCols = [
              showCode,
              showName,
              showPack,
              showQty,
              showValue,
              showVat,
              showTotal,
            ].where((e) => e).length;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: const [
                  Icon(Icons.receipt_long_outlined),
                  SizedBox(width: 10),
                  Text('Gjenero faturën'),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _PremiumTextField(
                        controller: invoiceNoC,
                        label: 'Nr. faturës',
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: clientC,
                        label: 'Klienti',
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: projectC,
                        label: 'Projekti / objekti',
                      ),
                      const SizedBox(height: 12),
                      _PremiumTextField(
                        controller: noteC,
                        label: 'Përshkrim shtesë',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zgjedh kolonat për PDF',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('Kodi'),
                                  selected: showCode,
                                  onSelected: (v) =>
                                      setLocalState(() => showCode = v),
                                ),
                                FilterChip(
                                  label: const Text('Emri'),
                                  selected: showName,
                                  onSelected: (v) =>
                                      setLocalState(() => showName = v),
                                ),
                                FilterChip(
                                  label: const Text('Pako'),
                                  selected: showPack,
                                  onSelected: (v) =>
                                      setLocalState(() => showPack = v),
                                ),
                                FilterChip(
                                  label: const Text('Sasia'),
                                  selected: showQty,
                                  onSelected: (v) =>
                                      setLocalState(() => showQty = v),
                                ),
                                FilterChip(
                                  label: const Text('Vlera'),
                                  selected: showValue,
                                  onSelected: (v) =>
                                      setLocalState(() => showValue = v),
                                ),
                                FilterChip(
                                  label: const Text('TVSH'),
                                  selected: showVat,
                                  onSelected: (v) =>
                                      setLocalState(() => showVat = v),
                                ),
                                FilterChip(
                                  label: const Text('Gjithsej'),
                                  selected: showTotal,
                                  onSelected: (v) =>
                                      setLocalState(() => showTotal = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Kolona të zgjedhura: $selectedCols',
                              style: Theme.of(context).textTheme.bodyMedium,
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
                FilledButton.icon(
                  onPressed: () async {
                    final hasAnyColumn = showCode ||
                        showName ||
                        showPack ||
                        showQty ||
                        showValue ||
                        showVat ||
                        showTotal;

                    if (!hasAnyColumn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Zgjedhe të paktën një kolonë për printim.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    await _generateInvoicePdf(
                      invoiceNo: invoiceNoC.text.trim(),
                      clientName: clientC.text.trim(),
                      projectName: projectC.text.trim(),
                      note: noteC.text.trim(),
                      showCode: showCode,
                      showName: showName,
                      showPack: showPack,
                      showQty: showQty,
                      showValue: showValue,
                      showVat: showVat,
                      showTotal: showTotal,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Gjenero PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateInvoicePdf({
    required String invoiceNo,
    required String clientName,
    required String projectName,
    required String note,
    required bool showCode,
    required bool showName,
    required bool showPack,
    required bool showQty,
    required bool showValue,
    required bool showVat,
    required bool showTotal,
  }) async {
    try {
      final double m2 = _toDouble(m2C.text);

      final double liters = _calcLiters(m2);
      final int buckets = _calcBuckets(liters);

      final double bucketPrice =
          includePaint ? (p?.bucketPrice ?? 0).toDouble() : 0.0;
      final double paintTotal = buckets * bucketPrice;

      final double laborPrice = (selectedLabor?.price ?? 0).toDouble();
      final double fixedLaborValue = _toDouble(fixedLaborC.text);
      final double laborTotal =
          laborFixedValue ? fixedLaborValue : (m2 * laborPrice);

      final calcProducts = _selectedProducts;

      final double materialTotalPaTvsh = calcProducts.fold<double>(
        0.0,
        (sum, x) => sum + x.vleraPaTvsh(m2),
      );

      final double materialTotalTvsh = calcProducts.fold<double>(
        0.0,
        (sum, x) => sum + x.vleraTvsh(m2),
      );

      final double materialTotalMeTvsh = calcProducts.fold<double>(
        0.0,
        (sum, x) => sum + x.vleraMeTvsh(m2),
      );

      final double grandTotal = materialTotalMeTvsh + laborTotal + paintTotal;

      final pdf = pw.Document();

      String today() {
        final d = DateTime.now();
        final dd = d.day.toString().padLeft(2, '0');
        final mm = d.month.toString().padLeft(2, '0');
        final yy = d.year.toString();
        return '$dd.$mm.$yy';
      }

      final headers = <String>[];
      if (showCode) headers.add('Kodi');
      if (showName) headers.add('Përshkrimi');
      if (showPack) headers.add('Pako');
      if (showQty) headers.add('Sasia');
      if (showValue) headers.add('Vlera');
      if (showVat) headers.add('TVSH');
      if (showTotal) headers.add('Gjithsej');

      final columnWidths = <int, pw.TableColumnWidth>{};
      int colIndex = 0;

      if (showCode) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(1.4);
      }
      if (showName) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(3.4);
      }
      if (showPack) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(1.6);
      }
      if (showQty) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(1.5);
      }
      if (showValue) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(1.7);
      }
      if (showVat) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(1.7);
      }
      if (showTotal) {
        columnWidths[colIndex++] = const pw.FlexColumnWidth(1.8);
      }

      List<pw.Widget> buildCells({
        String? code,
        String? name,
        String? pack,
        String? qty,
        String? value,
        String? vat,
        String? total,
        bool bold = false,
      }) {
        final cells = <pw.Widget>[];

        if (showCode) cells.add(_pdfCell(code ?? '', bold: bold));
        if (showName) cells.add(_pdfCell(name ?? '', bold: bold));
        if (showPack) cells.add(_pdfCell(pack ?? '', bold: bold));
        if (showQty) cells.add(_pdfCell(qty ?? '', bold: bold));
        if (showValue) cells.add(_pdfCell(value ?? '', bold: bold));
        if (showVat) cells.add(_pdfCell(vat ?? '', bold: bold));
        if (showTotal) cells.add(_pdfCell(total ?? '', bold: bold));

        return cells;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FATURË',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Nr. faturës: ${invoiceNo.isEmpty ? "-" : invoiceNo}',
                    ),
                    pw.Text('Data: ${today()}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      firma.emri.isEmpty ? 'Emri i firmës' : firma.emri,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (firma.description.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          firma.description,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    if (firma.nrTel.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          'Tel: ${firma.nrTel}',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Klienti',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(clientName.isEmpty ? '-' : clientName),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Projekti / objekti',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(projectName.isEmpty ? '-' : projectName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Përmbledhje',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _pdfInfoBox('Sipërfaqja', '${m2.toStringAsFixed(2)} m²'),
                _pdfInfoBox(
                  'Materiale pa TVSH',
                  _invoiceMoney(materialTotalPaTvsh),
                ),
                _pdfInfoBox(
                  'TVSH materiale',
                  _invoiceMoney(materialTotalTvsh),
                ),
                _pdfInfoBox(
                  'Materiale me TVSH',
                  _invoiceMoney(materialTotalMeTvsh),
                ),
                _pdfInfoBox('Puna', _invoiceMoney(laborTotal)),
                if (includePaint)
                  _pdfInfoBox('Bojë', _invoiceMoney(paintTotal)),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Artikujt e faturës',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.7),
              columnWidths: columnWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children:
                      headers.map((h) => _pdfCell(h, bold: true)).toList(),
                ),
                ...calcProducts.map((item) {
                  final qty = item.qtyForM2(m2);
                  final value = item.vleraPaTvsh(m2);
                  final vat = item.vleraTvsh(m2);
                  final total = item.vleraMeTvsh(m2);

                  return pw.TableRow(
                    children: buildCells(
                      code: item.kodi,
                      name: item.emertimi,
                      pack: item.pako,
                      qty: qty.toStringAsFixed(2),
                      value: _invoiceMoney(value),
                      vat: _invoiceMoney(vat),
                      total: _invoiceMoney(total),
                    ),
                  );
                }),
                pw.TableRow(
                  children: buildCells(
                    code: '',
                    name: laborFixedValue
                        ? '${p?.laborCategory ?? 'Punë'} (vlerë fikse)'
                        : (selectedLabor?.name ?? p?.laborCategory ?? 'Punë'),
                    pack: '',
                    qty: laborFixedValue
                        ? '1.00'
                        : '${m2.toStringAsFixed(2)} m²',
                    value: _invoiceMoney(laborTotal),
                    vat: '-',
                    total: _invoiceMoney(laborTotal),
                  ),
                ),
                if (includePaint)
                  pw.TableRow(
                    children: buildCells(
                      code: 'BOJE',
                      name:
                          'Bojë (${buckets.toString()} kova / ${liters.toStringAsFixed(2)} L)',
                      pack: '${bucketSize.toStringAsFixed(0)}L',
                      qty: '$buckets',
                      value: _invoiceMoney(paintTotal),
                      vat: '-',
                      total: _invoiceMoney(paintTotal),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 240,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Materiale pa TVSH: ${_invoiceMoney(materialTotalPaTvsh)}',
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'TVSH materiale: ${_invoiceMoney(materialTotalTvsh)}',
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Puna: ${_invoiceMoney(laborTotal)}'),
                    if (includePaint) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('Bojë: ${_invoiceMoney(paintTotal)}'),
                    ],
                    pw.Divider(),
                    pw.Text(
                      'TOTALI FINAL: ${_invoiceMoney(grandTotal)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (note.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'Shënim',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(note),
              ),
            ],
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(
                      width: 180,
                      height: 1,
                      color: PdfColors.grey600,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Nënshkrimi'),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(
                      width: 180,
                      height: 1,
                      color: PdfColors.grey600,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Pranuesi'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        name:
            'fatura_${invoiceNo.isEmpty ? DateTime.now().millisecondsSinceEpoch : invoiceNo}.pdf',
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë gjenerimit të faturës: $e')),
      );
    }
  }

  static pw.Widget _pdfInfoBox(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.75),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final double m2 = _toDouble(m2C.text);

    final double liters = _calcLiters(m2);
    final int buckets = _calcBuckets(liters);

    final double bucketPrice =
        includePaint ? (p?.bucketPrice ?? 0).toDouble() : 0.0;
    final double paintTotal = buckets * bucketPrice;

    final double laborPrice = (selectedLabor?.price ?? 0).toDouble();
    final double fixedLaborValue = _toDouble(fixedLaborC.text);
    final double laborTotal =
        laborFixedValue ? fixedLaborValue : (m2 * laborPrice);

    final calcProducts = _selectedProducts;

    final double materialTotalPaTvsh = calcProducts.fold<double>(
      0.0,
      (sum, x) => sum + x.vleraPaTvsh(m2),
    );

    final double materialTotalTvsh = calcProducts.fold<double>(
      0.0,
      (sum, x) => sum + x.vleraTvsh(m2),
    );

    final double materialTotalMeTvsh = calcProducts.fold<double>(
      0.0,
      (sum, x) => sum + x.vleraMeTvsh(m2),
    );

    final double grandTotal = materialTotalMeTvsh + laborTotal + paintTotal;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            cs.surface,
            cs.surfaceContainerLowest.withOpacity(0.55),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroHeader(
                  title: 'Kalkulo',
                  subtitle:
                      'Kalkulim profesional i materialit, bojës, punës dhe faturës',
                  trailing: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
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
                        label: Text(
                          'Zgjedh produktet (${selectedProductIds.length})',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _openInvoiceDialog,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Gjenero faturën'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (firma.emri.isNotEmpty ||
                    firma.description.isNotEmpty ||
                    firma.nrTel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PremiumCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: cs.primary.withOpacity(0.10),
                            ),
                            child: Icon(
                              Icons.business_outlined,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  firma.emri.isEmpty ? 'Firma' : firma.emri,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (firma.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    firma.description,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                                if (firma.nrTel.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text('Tel: ${firma.nrTel}'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (p == null)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Duke i lexu parametrat...'),
                  )
                else
                  _PremiumSectionCard(
                    title: 'Parametrat bazë',
                    icon: Icons.tune_outlined,
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SwitchChip(
                              icon: Icons.format_paint_outlined,
                              label: 'Ngjyrosje me bojë',
                              value: includePaint,
                              onChanged: (v) {
                                setState(() {
                                  includePaint = v;
                                });
                              },
                            ),
                            _InfoChip(
                              icon: Icons.work_outline,
                              label: 'Kategori pune',
                              value: p!.laborCategory,
                            ),
                            if (includePaint) ...[
                              _InfoChip(
                                icon: Icons.water_drop_outlined,
                                label: 'L/100m²',
                                value: '${p!.litersPer100}',
                              ),
                              _InfoChip(
                                icon: Icons.trending_down_outlined,
                                label: 'Humbje',
                                value: '${p!.wastePct}%',
                              ),
                              _InfoChip(
                                icon: Icons.layers_outlined,
                                label: 'Shtresa',
                                value: '${p!.coats}',
                              ),
                              _InfoChip(
                                icon: Icons.inventory_2_outlined,
                                label: 'Kova',
                                value: '${bucketSize.toStringAsFixed(0)}L',
                              ),
                              _InfoChip(
                                icon: Icons.payments_outlined,
                                label: 'Çmimi kove',
                                value: eur((p!.bucketPrice).toDouble()),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          _PremiumSectionCard(
                            title: 'Kalkulimi kryesor',
                            icon: Icons.calculate_outlined,
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: TextField(
                                    controller: m2C,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: _inputDecoration(
                                      label: laborFixedValue
                                          ? 'Sipërfaqja (m²) - vetëm për materiale'
                                          : 'Sipërfaqja (m²)',
                                      hint: 'p.sh. 120',
                                      prefixIcon: const Icon(
                                          Icons.square_foot_outlined),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(
                                  width: 440,
                                  child: DropdownButtonFormField<QmimorjaItem>(
                                    value: selectedLabor,
                                    items: laborItems
                                        .map(
                                          (x) => DropdownMenuItem<QmimorjaItem>(
                                            value: x,
                                            child: Text(
                                              '${x.name} • ${eur(x.price)}/${x.unit}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: laborItems.isEmpty
                                        ? null
                                        : (v) =>
                                            setState(() => selectedLabor = v),
                                    decoration: _inputDecoration(
                                      label: 'Zgjedh punën',
                                      prefixIcon:
                                          const Icon(Icons.handyman_outlined),
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PremiumSectionCard(
                            title: 'Puna',
                            icon: Icons.engineering_outlined,
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _SwitchChip(
                                  icon: Icons.price_change_outlined,
                                  label: 'Vlerë fikse për punën',
                                  value: laborFixedValue,
                                  onChanged: (v) {
                                    setState(() {
                                      laborFixedValue = v;
                                    });
                                  },
                                ),
                                if (laborFixedValue)
                                  SizedBox(
                                    width: 240,
                                    child: TextField(
                                      controller: fixedLaborC,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Shuma fikse',
                                        hint: 'p.sh. 300',
                                        prefixText: '€ ',
                                        prefixIcon: const Icon(
                                          Icons.euro_outlined,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                if (laborFixedValue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: cs.primary.withOpacity(.06),
                                      border: Border.all(
                                        color: cs.primary.withOpacity(.18),
                                      ),
                                    ),
                                    child: Text(
                                      'Kur kjo është aktive, puna nuk llogaritet me m².',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _PremiumSectionCard(
                        title: 'Përmbledhje e kalkulimit',
                        icon: Icons.analytics_outlined,
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            if (includePaint)
                              _PaintSummaryBox(
                                buckets: buckets,
                                liters: liters,
                                paintTotal: paintTotal,
                              ),
                            _StatPill(
                              icon: Icons.handyman_outlined,
                              label: laborFixedValue
                                  ? '${p?.laborCategory ?? 'Punë'} (fikse)'
                                  : (selectedLabor?.name ??
                                      p?.laborCategory ??
                                      'Punë'),
                              value: laborFixedValue
                                  ? eur(laborTotal)
                                  : '${eur(laborTotal)} (${eur(laborPrice)}/${selectedLabor?.unit ?? 'm²'})',
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
                            _TotalSummaryBox(
                              total: grandTotal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PremiumSectionCard(
                  title: 'Produktet e materialit',
                  icon: Icons.inventory_2_outlined,
                  trailing: products.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: cs.primary.withOpacity(0.08),
                            border: Border.all(
                              color: cs.primary.withOpacity(0.18),
                            ),
                          ),
                          child: Text(
                            '${products.length} produkte',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        )
                      : null,
                  child: products.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.25),
                            border: Border.all(
                              color: theme.dividerColor,
                            ),
                          ),
                          child: const Text(
                            'Nuk ka produkte. Shto produkte për kalkulim.',
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.7),
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Theme(
                                data: theme.copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: DataTable(
                                  headingRowHeight: 56,
                                  dataRowMinHeight: 58,
                                  dataRowMaxHeight: 68,
                                  columnSpacing: 24,
                                  headingRowColor:
                                      MaterialStateProperty.resolveWith(
                                    (_) => cs.primary.withOpacity(0.08),
                                  ),
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
                                    final isSelected = item.id != null &&
                                        selectedProductIds.contains(item.id);

                                    final double sasia = item.qtyForM2(m2);
                                    final double vlera = item.vleraPaTvsh(m2);
                                    final double tvsh = item.vleraTvsh(m2);
                                    final double total = item.vleraMeTvsh(m2);

                                    return DataRow(
                                      selected: isSelected,
                                      cells: [
                                        DataCell(
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (v) =>
                                                _toggleSelected(item, v),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            item.kodi,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              item.emertimi,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(item.pako)),
                                        DataCell(
                                          Text(sasia.toStringAsFixed(2)),
                                        ),
                                        DataCell(Text(eur(vlera))),
                                        DataCell(Text(eur(tvsh))),
                                        DataCell(
                                          Text(
                                            eur(total),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: cs.primary
                                                      .withOpacity(0.10),
                                                ),
                                                child: IconButton(
                                                  tooltip: 'Ndrysho',
                                                  onPressed: () =>
                                                      _openProductDialog(
                                                    item: item,
                                                  ),
                                                  icon: Icon(
                                                    Icons.edit_outlined,
                                                    color: cs.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: Colors.red
                                                      .withOpacity(0.08),
                                                ),
                                                child: IconButton(
                                                  tooltip: 'Fshij',
                                                  onPressed: () =>
                                                      _deleteProduct(item),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.16),
            cs.secondary.withOpacity(0.10),
            cs.surfaceContainerHighest.withOpacity(0.35),
          ],
        ),
        border: Border.all(
          color: cs.primary.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: cs.primary.withOpacity(0.14),
                  ),
                  child: Icon(
                    Icons.calculate_rounded,
                    size: 30,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;

  const _PremiumCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cs.surface,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PremiumSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _PremiumSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.75),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest.withOpacity(0.28),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: value
            ? cs.primary.withOpacity(0.10)
            : cs.surfaceContainerHighest.withOpacity(0.22),
        border: Border.all(
          color: value
              ? cs.primary.withOpacity(0.35)
              : Theme.of(context).dividerColor.withOpacity(0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: value ? cs.primary : null),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PaintSummaryBox extends StatelessWidget {
  final int buckets;
  final double liters;
  final double paintTotal;

  const _PaintSummaryBox({
    required this.buckets,
    required this.liters,
    required this.paintTotal,
  });

  @override
  Widget build(BuildContext context) {
    const greenColor = Colors.green;

    Widget item({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).cardColor.withOpacity(0.20),
          border: Border.all(
            color: greenColor.withOpacity(0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: greenColor),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: greenColor.withOpacity(0.55),
          width: 1.4,
        ),
        gradient: LinearGradient(
          colors: [
            greenColor.withOpacity(0.10),
            greenColor.withOpacity(0.04),
          ],
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          item(
            icon: Icons.inventory_2_outlined,
            label: 'Kova',
            value: '$buckets',
          ),
          item(
            icon: Icons.opacity_outlined,
            label: 'Litra',
            value: '${liters.toStringAsFixed(2)} L',
          ),
          item(
            icon: Icons.format_paint_outlined,
            label: 'Bojë',
            value: eur(paintTotal),
          ),
        ],
      ),
    );
  }
}

class _TotalSummaryBox extends StatelessWidget {
  final double total;

  const _TotalSummaryBox({
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.18),
            cs.primary.withOpacity(0.08),
          ],
        ),
        border: Border.all(
          color: cs.primary.withOpacity(0.45),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calculate_outlined,
            size: 24,
            color: cs.primary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Totali final',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                eur(total),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
              ),
            ],
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: cs.surfaceContainerHighest.withOpacity(0.24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: cs.primary.withOpacity(0.10),
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
