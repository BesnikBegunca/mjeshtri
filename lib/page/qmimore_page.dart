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

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Shto çmim' : 'Ndrysho çmim'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: catC,
                decoration: const InputDecoration(
                  labelText: 'Kategoria',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: 'Emri',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitC,
                      decoration: const InputDecoration(
                        labelText: 'Njësia (p.sh. m²)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceC,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Çmimi (€)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ruaj'),
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
    await QmimorjaDao.I.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Qmimore',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Shto'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kategoria')),
                  DataColumn(label: Text('Emri')),
                  DataColumn(label: Text('Njësia')),
                  DataColumn(label: Text('Çmimi')),
                  DataColumn(label: Text('Veprime')),
                ],
                rows: items.map((e) {
                  return DataRow(
                    cells: [
                      DataCell(Text(e.category)),
                      DataCell(Text(e.name)),
                      DataCell(Text(e.unit)),
                      DataCell(Text(eur(e.price))),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _openEditor(item: e),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              onPressed: () => _delete(e.id!),
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
        ),
      ],
    );
  }
}
