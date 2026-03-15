import 'package:flutter/material.dart';

import '../data/dao_firma.dart';
import '../models/firma_info.dart';

class FirmaPage extends StatefulWidget {
  const FirmaPage({super.key});

  @override
  State<FirmaPage> createState() => _FirmaPageState();
}

class _FirmaPageState extends State<FirmaPage> {
  final emriC = TextEditingController();
  final descriptionC = TextEditingController();
  final nrTelC = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    emriC.addListener(_refreshPreview);
    descriptionC.addListener(_refreshPreview);
    nrTelC.addListener(_refreshPreview);

    _load();
  }

  @override
  void dispose() {
    emriC.removeListener(_refreshPreview);
    descriptionC.removeListener(_refreshPreview);
    nrTelC.removeListener(_refreshPreview);

    emriC.dispose();
    descriptionC.dispose();
    nrTelC.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => loading = true);

    try {
      final firma = await FirmaDao.I.get();

      emriC.text = firma.emri;
      descriptionC.text = firma.description;
      nrTelC.text = firma.nrTel;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë leximit: $e')),
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);

    try {
      final item = FirmaInfo(
        emri: emriC.text.trim(),
        description: descriptionC.text.trim(),
        nrTel: nrTelC.text.trim(),
      );

      await FirmaDao.I.save(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Të dhënat e firmës u ruajtën me sukses.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë ruajtjes: $e')),
      );
    }

    if (mounted) {
      setState(() => saving = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded),
            SizedBox(width: 10),
            Expanded(child: Text('Fshiji të dhënat e firmës?')),
          ],
        ),
        content: const Text(
          'A je i sigurt që don me i fshi të dhënat e firmës?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Jo'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Po'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirmaDao.I.clear();

      emriC.clear();
      descriptionC.clear();
      nrTelC.clear();

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Të dhënat e firmës u fshinë.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gabim gjatë fshirjes: $e')),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.18),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(0.95),
                  cs.primaryContainer.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Firma',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menaxho të dhënat bazë të firmës dhe shiko preview-n në kohë reale.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.10),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Të dhënat e firmës',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plotëso informacionet që do të përdoren në sistem dhe në preview.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emriC,
                    decoration: _inputDecoration(
                      label: 'Emri i firmës',
                      hint: 'p.sh. Mjeshtri SHPK',
                      icon: Icons.apartment_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionC,
                    maxLines: 4,
                    decoration: _inputDecoration(
                      label: 'Përshkrimi',
                      hint: 'p.sh. Fasada, ngjyrosje, izolime, kalkulim',
                      icon: Icons.description_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nrTelC,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      label: 'Nr. tel',
                      hint: 'p.sh. 049 123 123',
                      icon: Icons.phone_rounded,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Duke ruajtur...' : 'Ruaj'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: saving ? null : _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Rifresko'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: saving ? null : _clear,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Fshiji'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.10),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.preview_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Preview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [
                          cs.surfaceContainerHighest.withOpacity(0.35),
                          cs.surface.withOpacity(0.90),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.business_center_rounded,
                                color: cs.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                emriC.text.isEmpty
                                    ? 'Emri i firmës'
                                    : emriC.text,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  descriptionC.text.isEmpty
                                      ? 'Përshkrimi i firmës'
                                      : descriptionC.text,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_in_talk_rounded,
                                size: 20,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nrTelC.text.isEmpty
                                      ? 'Nr. tel'
                                      : 'Tel: ${nrTelC.text}',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
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
          ),
        ],
      ),
    );
  }
}
