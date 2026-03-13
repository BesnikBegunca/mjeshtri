import '../models/price_item.dart';
import 'db.dart';

class PricesDao {
  PricesDao._();
  static final PricesDao I = PricesDao._();

  Future<List<PriceItem>> list() async {
    final rows = await AppDb.I.db.query('price_items', orderBy: 'category ASC, name ASC');
    return rows.map(PriceItem.fromMap).toList();
  }

  Future<int> insert(PriceItem p) async => AppDb.I.db.insert('price_items', p.toMap());

  Future<void> update(PriceItem p) async {
    await AppDb.I.db.update('price_items', p.toMap(), where: 'id=?', whereArgs: [p.id]);
  }

  Future<void> delete(int id) async {
    await AppDb.I.db.delete('price_items', where: 'id=?', whereArgs: [id]);
  }
}
