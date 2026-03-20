import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/dao_calc_products.dart';
import '../data/dao_firma.dart';
import '../models/firma_info.dart';
import '../models/product_calc_item.dart';
import '../util/format.dart';

class KalkuloPage extends StatefulWidget {
  const KalkuloPage({super.key});

  @override
  State<KalkuloPage> createState() => _KalkuloPageState();
}

class _KalkuloPageState extends State<KalkuloPage> {
  final m2C = TextEditingController();

  FirmaInfo firma = FirmaInfo.empty();

  List<ProductCalcItem> products = [];
  final Set<int> selectedProductIds = {};

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
      firma = await FirmaDao.I.get();
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
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: cs.primary.withOpacity(0.10),
                    ),
                    child: Icon(
                      Icons.playlist_add_check_circle_outlined,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Zgjedh produktet për kalkulim'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: products.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: theme.dividerColor),
                          color: cs.surfaceContainerHighest.withOpacity(0.22),
                        ),
                        child: const Text('Nuk ka produkte të regjistruara.'),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: products.map((x) {
                            final checked =
                                x.id != null && tempSelected.contains(x.id);

                            final totalPer100 =
                                x.vleraPer100m2 + x.tvshPer100m2;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: checked
                                      ? cs.primary.withOpacity(0.45)
                                      : theme.dividerColor.withOpacity(0.8),
                                ),
                                color: checked
                                    ? cs.primary.withOpacity(0.06)
                                    : cs.surfaceContainerHighest
                                        .withOpacity(0.18),
                                boxShadow: checked
                                    ? [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.08),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: CheckboxListTile(
                                value: checked,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                title: Text(
                                  x.emertimi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
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
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

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
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: cs.primary.withOpacity(0.10),
                    ),
                    child: Icon(
                      item == null
                          ? Icons.add_box_outlined
                          : Icons.edit_note_outlined,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(item == null ? 'Shto produkt' : 'Përditëso produktin'),
                ],
              ),
              content: SizedBox(
                width: 760,
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
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.75),
                          ),
                          color: cs.surfaceContainerHighest.withOpacity(0.20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vlerat bazë për 100m²',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _previewRow(
                              'Sasia/100m²',
                              sasiaPer100.toStringAsFixed(2),
                            ),
                            _previewRow(
                              'Vlera/100m²',
                              eur(vleraPer100),
                            ),
                            _previewRow(
                              'TVSH/100m²',
                              eur(tvshPer100),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            Text(
                              'Preview për ${m2.toStringAsFixed(2)} m²',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _previewRow(
                              'Sasia totale',
                              sasiaTotale.toStringAsFixed(2),
                            ),
                            _previewRow(
                              'Vlera totale',
                              eur(vleraTotale),
                            ),
                            _previewRow(
                              'TVSH totale',
                              eur(tvshTotale),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            _previewRow(
                              'Vlera + TVSH',
                              eur(gjithsej),
                              bold: true,
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Fshije produktin?'),
          content: Text('A je i sigurt që don me fshi "${item.emertimi}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Jo'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Po'),
            ),
          ],
        );
      },
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

    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zgjedh të paktën një produkt për faturë.'),
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
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;

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
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: cs.primary.withOpacity(0.10),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Gjenero faturën'),
                ],
              ),
              content: SizedBox(
                width: 580,
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.75),
                          ),
                          borderRadius: BorderRadius.circular(20),
                          color: cs.surfaceContainerHighest.withOpacity(0.20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zgjedh kolonat për PDF',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
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
                              style: theme.textTheme.bodyMedium,
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
                _pdfInfoBox(
                  'Produkte',
                  '${calcProducts.length}',
                ),
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
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
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
                    pw.Divider(),
                    pw.Text(
                      'TOTALI FINAL: ${_invoiceMoney(materialTotalMeTvsh)}',
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
          .withOpacity(.20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.75),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            cs.surface,
            cs.surfaceContainerLowest.withOpacity(0.35),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroHeader(
                  title: 'Kalkulo',
                  subtitle:
                      'Kalkulim premium i materialeve dhe gjenerim profesional i faturës',
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
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
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
                                    fontWeight: FontWeight.w900,
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
                                  width: 320,
                                  child: TextField(
                                    controller: m2C,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: _inputDecoration(
                                      label: 'Sipërfaqja (m²)',
                                      hint: 'p.sh. 120',
                                      prefixIcon: const Icon(
                                        Icons.square_foot_outlined,
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: cs.surfaceContainerHighest
                                        .withOpacity(0.20),
                                    border: Border.all(
                                      color:
                                          theme.dividerColor.withOpacity(0.75),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: cs.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Kjo faqe llogarit vetëm materialet',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
                              total: materialTotalMeTvsh,
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
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.18),
                            border: Border.all(
                              color: theme.dividerColor,
                            ),
                          ),
                          child: const Text(
                            'Nuk ka produkte. Shto produkte për kalkulim.',
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.7),
                              ),
                              borderRadius: BorderRadius.circular(20),
                              color: cs.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Theme(
                                data: theme.copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: DataTable(
                                  headingRowHeight: 58,
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 72,
                                  columnSpacing: 24,
                                  headingRowColor:
                                      WidgetStateProperty.resolveWith(
                                    (_) => cs.primary.withOpacity(0.07),
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
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 240,
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
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FilledButton.tonalIcon(
                                                onPressed: () =>
                                                    _openProductDialog(
                                                  item: item,
                                                ),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text('Ndrysho'),
                                              ),
                                              const SizedBox(width: 8),
                                              FilledButton.tonalIcon(
                                                style: FilledButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _deleteProduct(item),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                ),
                                                label: const Text('Fshij'),
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

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.12),
            cs.secondary.withOpacity(0.06),
            cs.surfaceContainerHighest.withOpacity(0.22),
          ],
        ),
        border: Border.all(
          color: cs.primary.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: cs.surface,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
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
                        fontWeight: FontWeight.w900,
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
            .withOpacity(0.18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.75),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
        ),
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
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.16),
            cs.primary.withOpacity(0.07),
          ],
        ),
        border: Border.all(
          color: cs.primary.withOpacity(0.40),
          width: 1.3,
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
        color: cs.surfaceContainerHighest.withOpacity(0.20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
