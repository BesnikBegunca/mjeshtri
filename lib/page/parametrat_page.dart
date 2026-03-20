import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mjeshtri/models/firma_info.dart';

import '../data/dao_parameters.dart';
import '../data/dao_qmimorja.dart';
import '../data/dao_firma.dart';
import '../models/parameters.dart';
import '../models/qmimorja_item.dart';
import '../util/format.dart';
import '../util/parametrat_pdf.dart';

class ParametratPage extends StatefulWidget {
  const ParametratPage({super.key});

  @override
  State<ParametratPage> createState() => _ParametratPageState();
}

class _ParametratPageState extends State<ParametratPage> {
  bool loading = true;
  bool saving = false;
  bool generatingPdf = false;

  late Parameters p;
  FirmaInfo? firma;

  final laborCategoryC = TextEditingController();
  final m2C = TextEditingController();
  final fixedValueC = TextEditingController();

  final discountPercentC = TextEditingController();
  final discountFixedC = TextEditingController();

  final offerNoC = TextEditingController();
  final notesC = TextEditingController();

  /// Të dhënat e klientit
  final clientNameC = TextEditingController();
  final clientPhoneC = TextEditingController();
  final clientAddressC = TextEditingController();
  final clientEmailC = TextEditingController();

  List<QmimorjaItem> allItems = [];
  List<QmimorjaItem> laborItems = [];
  QmimorjaItem? selectedLabor;

  bool laborFixedValue = false;

  /// 0 = pa zbritje
  /// 1 = %
  /// 2 = vlere fikse
  int discountType = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    laborCategoryC.dispose();
    m2C.dispose();
    fixedValueC.dispose();
    discountPercentC.dispose();
    discountFixedC.dispose();
    offerNoC.dispose();
    notesC.dispose();

    clientNameC.dispose();
    clientPhoneC.dispose();
    clientAddressC.dispose();
    clientEmailC.dispose();

    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _load() async {
    setState(() => loading = true);

    try {
      p = await ParametersDao.I.get();
      allItems = await QmimorjaDao.I.list();

      try {
        firma = await FirmaDao.I.get();
      } catch (_) {
        firma = null;
      }

      laborCategoryC.text = p.laborCategory;

      _filterLaborItems();

      if (offerNoC.text.trim().isEmpty) {
        final ms = DateTime.now().millisecondsSinceEpoch.toString();
        final suffix = ms.length >= 6 ? ms.substring(ms.length - 6) : ms;
        offerNoC.text = 'OFF-${DateTime.now().year}-$suffix';
      }

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë leximit: $e')),
      );
    }
  }

  void _filterLaborItems() {
    final category = laborCategoryC.text.trim().toLowerCase();

    laborItems = allItems.where((x) {
      return x.category.trim().toLowerCase() == category;
    }).toList();

    if (laborItems.isEmpty) {
      selectedLabor = null;
      return;
    }

    final currentId = selectedLabor?.id;
    if (currentId != null) {
      try {
        selectedLabor = laborItems.firstWhere((x) => x.id == currentId);
        return;
      } catch (_) {}
    }

    try {
      selectedLabor = laborItems.firstWhere(
        (x) =>
            x.unit.toLowerCase().contains('m') ||
            x.unit.toLowerCase().contains('m2'),
      );
    } catch (_) {
      selectedLabor = laborItems.first;
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);

    try {
      final laborCat = laborCategoryC.text.trim().isEmpty
          ? 'Punë dore'
          : laborCategoryC.text.trim();

      final newP = Parameters(
        litersPer100: p.litersPer100,
        wastePct: p.wastePct,
        coats: p.coats,
        bucketPrice: p.bucketPrice,
        laborCategory: laborCat,
      );

      await ParametersDao.I.save(newP);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Kategoria e punës u ruajt me sukses ✅'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë ruajtjes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  double get _m2 => _toDouble(m2C.text);

  double get _fixedValue => _toDouble(fixedValueC.text);

  double get _laborPrice => (selectedLabor?.price ?? 0).toDouble();

  double get _subtotal {
    if (laborFixedValue) return _fixedValue;
    return _m2 * _laborPrice;
  }

  double get _discountPercent {
    if (discountType != 1) return 0;
    final v = _toDouble(discountPercentC.text);
    if (v < 0) return 0;
    if (v > 100) return 100;
    return v;
  }

  double get _discountFixed {
    if (discountType != 2) return 0;
    final v = _toDouble(discountFixedC.text);
    if (v < 0) return 0;
    return v;
  }

  double get _discountAmount {
    if (discountType == 1) {
      return _subtotal * (_discountPercent / 100);
    }
    if (discountType == 2) {
      return _discountFixed > _subtotal ? _subtotal : _discountFixed;
    }
    return 0;
  }

  double get _totalFinal {
    final total = _subtotal - _discountAmount;
    return total < 0 ? 0 : total;
  }

  String get _unitLabel => selectedLabor?.unit ?? 'm²';

  Future<void> _generatePdf() async {
    if (firma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nuk u gjet firma gjenerale. Shtoje te faqja Firma para gjenerimit të ofertës.',
          ),
        ),
      );
      return;
    }

    if (!laborFixedValue && selectedLabor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Zgjedhe artikullin e punës para gjenerimit të ofertës.'),
        ),
      );
      return;
    }

    if (clientNameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Shkruaje emrin e klientit para gjenerimit të ofertës.'),
        ),
      );
      return;
    }

    setState(() => generatingPdf = true);

    try {
      final bytes = await ParametratPdf.buildOffer(
        offerNo: offerNoC.text.trim().isEmpty ? '-' : offerNoC.text.trim(),
        offerDate: DateTime.now(),

        companyName: (firma?.emri ?? ''),
        companyAddress: (firma?.description ?? ''),
        companyPhone: (firma?.nrTel ?? ''),
        companyEmail: '',
        companyNuis: '',
        companyFiscalNo: '',

        /// Klienti tash përdoret realisht
        clientName: clientNameC.text.trim(),
        clientAddress: clientAddressC.text.trim(),
        clientPhone: clientPhoneC.text.trim(),
        clientEmail: clientEmailC.text.trim(),

        category: laborCategoryC.text.trim(),
        workName: selectedLabor?.name ?? 'Punë me vlerë fikse',
        unit: laborFixedValue ? 'copë' : _unitLabel,
        quantity: laborFixedValue ? 1 : _m2,
        unitPrice: laborFixedValue ? _fixedValue : _laborPrice,
        subtotal: _subtotal,
        discountLabel: discountType == 1
            ? 'Zbritje ${_discountPercent.toStringAsFixed(2)}%'
            : discountType == 2
                ? 'Zbritje fikse'
                : 'Pa zbritje',
        discountAmount: _discountAmount,
        total: _totalFinal,
        notes: notesC.text.trim(),
      );

      final safeClient = clientNameC.text
          .trim()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');

      final safeWork = (selectedLabor?.name ?? 'oferta')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');

      final location = await getSaveLocation(
        suggestedName:
            'oferta_${safeClient}_${safeWork}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (location == null) {
        if (!mounted) return;
        setState(() => generatingPdf = false);
        return;
      }

      final file = File(location.path);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Oferta u ruajt me sukses:\n${file.path}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë gjenerimit të PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => generatingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final firmaName = (firma?.emri ?? '').trim();
    final firmaAddress = (firma?.description ?? '').trim();

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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _HeaderCard(
            title: 'Parametrat',
            subtitle:
                'Kalkulo punën, apliko zbritje dhe gjenero ofertë/faturë për klientin.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: saving || generatingPdf ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Rifresko'),
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
                  onPressed: saving || generatingPdf ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Duke ruajtur...' : 'Ruaj kategorinë'),
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
                ElevatedButton.icon(
                  onPressed: generatingPdf || saving ? null : _generatePdf,
                  icon: generatingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    generatingPdf ? 'Duke gjeneruar...' : 'Gjenero ofertën',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth >= 1200
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth >= 760
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MiniStatCard(
                            width: cardWidth,
                            title: 'Kategoria aktuale',
                            value: laborCategoryC.text.isEmpty
                                ? '-'
                                : laborCategoryC.text,
                            icon: Icons.category_outlined,
                            color: cs.primary,
                          ),
                          _MiniStatCard(
                            width: cardWidth,
                            title: 'Zbritja',
                            value: discountType == 1
                                ? '${_discountPercent.toStringAsFixed(2)}%'
                                : discountType == 2
                                    ? eur(_discountFixed)
                                    : 'Pa zbritje',
                            icon: Icons.discount_outlined,
                            color: Colors.orange,
                          ),
                          _MiniStatCard(
                            width: cardWidth,
                            title: 'Totali final',
                            value: eur(_totalFinal),
                            icon: Icons.calculate_outlined,
                            color: Colors.deepPurple,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: cs.outline.withOpacity(0.10),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(16),
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
                                      'Kalkulimi i punës',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Zgjedh kategorinë, punën, zbritjen dhe llogarit totalin automatikisht.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
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
                                width: 360,
                                title: 'Kategoria e punës',
                                icon: Icons.category_outlined,
                                child: TextField(
                                  controller: laborCategoryC,
                                  onChanged: (_) {
                                    setState(() {
                                      _filterLaborItems();
                                    });
                                  },
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'p.sh. Punë dore',
                                    icon: Icons.work_outline_rounded,
                                  ),
                                ),
                              ),
                              _InputCard(
                                width: 320,
                                title: 'Sipërfaqja',
                                icon: Icons.square_foot_outlined,
                                child: TextField(
                                  controller: m2C,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Sipërfaqja në m²',
                                    icon: Icons.square_foot_outlined,
                                  ),
                                ),
                              ),
                              _InputCard(
                                width: 420,
                                title: 'Zgjedh punën',
                                icon: Icons.handyman_outlined,
                                child: DropdownButtonFormField<QmimorjaItem>(
                                  value: laborItems.contains(selectedLabor)
                                      ? selectedLabor
                                      : null,
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
                                      : (v) {
                                          setState(() {
                                            selectedLabor = v;
                                          });
                                        },
                                  decoration: _inputDecoration(
                                    context,
                                    label: laborItems.isEmpty
                                        ? 'Nuk ka punë në këtë kategori'
                                        : 'Zgjedh artikullin e punës',
                                    icon: Icons.list_alt_outlined,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color:
                                  cs.surfaceContainerHighest.withOpacity(0.25),
                              border: Border.all(
                                color: cs.outline.withOpacity(0.12),
                              ),
                            ),
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: laborFixedValue,
                                          onChanged: (v) {
                                            setState(() {
                                              laborFixedValue = v;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Përdor vlerë fikse',
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (laborFixedValue)
                                      SizedBox(
                                        width: 260,
                                        child: TextField(
                                          controller: fixedValueC,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                          decoration: _inputDecoration(
                                            context,
                                            label: 'Shuma fikse (€)',
                                            icon: Icons.euro_rounded,
                                          ),
                                        ),
                                      ),
                                    if (!laborFixedValue)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.07),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: cs.primary.withOpacity(0.15),
                                          ),
                                        ),
                                        child: Text(
                                          'Formula: ${_m2.toStringAsFixed(2)} m² × ${eur(_laborPrice)} = ${eur(_subtotal)}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(color: cs.outline.withOpacity(0.10)),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Apliko zbritje',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Pa zbritje'),
                                      selected: discountType == 0,
                                      onSelected: (_) {
                                        setState(() {
                                          discountType = 0;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Zbritje me %'),
                                      selected: discountType == 1,
                                      onSelected: (_) {
                                        setState(() {
                                          discountType = 1;
                                        });
                                      },
                                    ),
                                    ChoiceChip(
                                      label: const Text('Zbritje fikse'),
                                      selected: discountType == 2,
                                      onSelected: (_) {
                                        setState(() {
                                          discountType = 2;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (discountType == 1)
                                  SizedBox(
                                    width: 260,
                                    child: TextField(
                                      controller: discountPercentC,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: _inputDecoration(
                                        context,
                                        label: 'Zbritja në %',
                                        icon: Icons.percent_rounded,
                                      ),
                                    ),
                                  ),
                                if (discountType == 2)
                                  SizedBox(
                                    width: 260,
                                    child: TextField(
                                      controller: discountFixedC,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: _inputDecoration(
                                        context,
                                        label: 'Zbritja fikse (€)',
                                        icon: Icons.money_off_csred_outlined,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary.withOpacity(0.14),
                                  cs.primary.withOpacity(0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: cs.primary.withOpacity(0.18),
                              ),
                            ),
                            child: Wrap(
                              spacing: 18,
                              runSpacing: 18,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _SummaryPill(
                                  icon: Icons.category_outlined,
                                  label: 'Kategoria',
                                  value: laborCategoryC.text.isEmpty
                                      ? '-'
                                      : laborCategoryC.text,
                                ),
                                _SummaryPill(
                                  icon: Icons.work_outline_rounded,
                                  label: 'Puna',
                                  value: selectedLabor?.name ??
                                      (laborFixedValue
                                          ? 'Punë me vlerë fikse'
                                          : '-'),
                                ),
                                _SummaryPill(
                                  icon: Icons.straighten_outlined,
                                  label:
                                      laborFixedValue ? 'Njësia' : 'Sipërfaqja',
                                  value: laborFixedValue
                                      ? '1 copë'
                                      : '${_m2.toStringAsFixed(2)} $_unitLabel',
                                ),
                                _SummaryPill(
                                  icon: Icons.payments_outlined,
                                  label: 'Nën-total',
                                  value: eur(_subtotal),
                                ),
                                _SummaryPill(
                                  icon: Icons.discount_outlined,
                                  label: 'Zbritja',
                                  value: eur(_discountAmount),
                                ),
                                _TotalBox(total: _totalFinal),
                              ],
                            ),
                          ),
                          if (laborItems.isEmpty && !laborFixedValue) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Nuk u gjet asnjë artikull në Qmimore për kategorinë "${laborCategoryC.text.trim().isEmpty ? '-' : laborCategoryC.text.trim()}".',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  /// TË DHËNAT E KLIENTIT + OFERTA
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: cs.outline.withOpacity(0.10),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Të dhënat e klientit dhe ofertës',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _InputCard(
                                width: 320,
                                title: 'Emri i klientit',
                                icon: Icons.person_outline,
                                child: TextField(
                                  controller: clientNameC,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'p.sh. Filan Fisteku',
                                    icon: Icons.badge_outlined,
                                  ),
                                ),
                              ),
                              _InputCard(
                                width: 280,
                                title: 'Telefoni i klientit',
                                icon: Icons.phone_outlined,
                                child: TextField(
                                  controller: clientPhoneC,
                                  keyboardType: TextInputType.phone,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'p.sh. 044123123',
                                    icon: Icons.phone_android_outlined,
                                  ),
                                ),
                              ),
                              _InputCard(
                                width: 380,
                                title: 'Adresa e klientit',
                                icon: Icons.location_on_outlined,
                                child: TextField(
                                  controller: clientAddressC,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'p.sh. Kaçanik',
                                    icon: Icons.location_city_outlined,
                                  ),
                                ),
                              ),
                              _InputCard(
                                width: 380,
                                title: 'Email i klientit',
                                icon: Icons.email_outlined,
                                child: TextField(
                                  controller: clientEmailC,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'p.sh. klienti@email.com',
                                    icon: Icons.alternate_email_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _InputCard(
                                width: 280,
                                title: 'Nr. ofertës',
                                icon: Icons.numbers_outlined,
                                child: TextField(
                                  controller: offerNoC,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'p.sh. OFF-2026-001',
                                    icon: Icons.tag_outlined,
                                  ),
                                ),
                              ),
                              _InputCard(
                                width: 640,
                                title: 'Shënime',
                                icon: Icons.notes_outlined,
                                child: TextField(
                                  controller: notesC,
                                  maxLines: 4,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Shënime shtesë për ofertën',
                                    icon: Icons.sticky_note_2_outlined,
                                  ),
                                ),
                              ),
                            ],
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
      fillColor: cs.surfaceContainerHighest.withOpacity(0.30),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: cs.outline.withOpacity(0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: cs.primary,
          width: 1.3,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                  Icons.calculate_outlined,
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

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface.withOpacity(0.65),
        border: Border.all(
          color: cs.outline.withOpacity(0.10),
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
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
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

class _TotalBox extends StatelessWidget {
  final double total;

  const _TotalBox({
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.18),
            cs.primary.withOpacity(0.08),
          ],
        ),
        border: Border.all(
          color: cs.primary.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calculate_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Totali final',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                eur(total),
                style: theme.textTheme.titleLarge?.copyWith(
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
