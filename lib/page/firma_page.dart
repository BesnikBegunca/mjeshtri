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
    _load();
  }

  @override
  void dispose() {
    emriC.dispose();
    descriptionC.dispose();
    nrTelC.dispose();
    super.dispose();
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
        title: const Text('Fshiji të dhënat e firmës?'),
        content:
            const Text('A je i sigurt që don me i fshi të dhënat e firmës?'),
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firma',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: emriC,
                    decoration: const InputDecoration(
                      labelText: 'Emri i firmës',
                      hintText: 'p.sh. Mjeshtri SHPK',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Përshkrimi',
                      hintText: 'p.sh. Fasada, ngjyrosje, izolime, kalkulim',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nrTelC,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nr. tel',
                      hintText: 'p.sh. 049 123 123',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Duke ruajtur...' : 'Ruaj'),
                      ),
                      OutlinedButton.icon(
                        onPressed: saving ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Rifresko'),
                      ),
                      OutlinedButton.icon(
                        onPressed: saving ? null : _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Fshiji'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emriC.text.isEmpty ? 'Emri i firmës' : emriC.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descriptionC.text.isEmpty
                        ? 'Përshkrimi i firmës'
                        : descriptionC.text,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nrTelC.text.isEmpty ? 'Nr. tel' : 'Tel: ${nrTelC.text}',
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
