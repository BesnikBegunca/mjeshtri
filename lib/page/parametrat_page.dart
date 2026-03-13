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

  Future<void> _load() async {
    setState(() => loading = true);
    p = await ParametersDao.I.get();

    litersC.text = p.litersPer100.toStringAsFixed(2);
    wasteC.text = p.wastePct.toStringAsFixed(2);
    coatsC.text = p.coats.toString();

    bucketPriceC.text = p.bucketPrice.toStringAsFixed(2);
    laborCategoryC.text = p.laborCategory;

    setState(() => loading = false);
  }

  Future<void> _save() async {
    final liters = double.tryParse(litersC.text.replaceAll(',', '.')) ?? 0;
    final waste = double.tryParse(wasteC.text.replaceAll(',', '.')) ?? 0;
    final coats = int.tryParse(coatsC.text) ?? 1;

    final bucketPrice = double.tryParse(bucketPriceC.text.replaceAll(',', '.')) ?? 0;
    final laborCat = laborCategoryC.text.trim().isEmpty ? 'Punë dore' : laborCategoryC.text.trim();

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
      const SnackBar(content: Text('Parametrat u ruajtën ✅')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Parametrat', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: litersC,
                decoration: const InputDecoration(labelText: 'Sa litra shkojnë në 100m²', border: OutlineInputBorder()),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: wasteC,
                decoration: const InputDecoration(labelText: 'Humbje (%)', border: OutlineInputBorder()),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: coatsC,
                decoration: const InputDecoration(labelText: 'Shtresa (coats)', border: OutlineInputBorder()),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: bucketPriceC,
                decoration: const InputDecoration(labelText: 'Çmimi i kovës 25L (€)', border: OutlineInputBorder()),
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: laborCategoryC,
                decoration: const InputDecoration(labelText: 'Kategoria e punës (nga Qmimore)', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Ruaj')),
      ],
    );
  }
}
