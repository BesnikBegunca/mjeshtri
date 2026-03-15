import 'package:mjeshtri/data/db.dart';

import '../models/qmimorja_item.dart';

class QmimorjaDao {
  QmimorjaDao._();
  static final QmimorjaDao I = QmimorjaDao._();

  static const String table = 'qmimorja_items';

  Future<List<QmimorjaItem>> list() async {
    final rows = await AppDb.I.db.query(
      table,
      orderBy: 'category ASC, name ASC',
    );
    return rows.map((e) => QmimorjaItem.fromMap(e)).toList();
  }

  Future<int> insert(QmimorjaItem item) async {
    return AppDb.I.db.insert(
      table,
      item.toMap()..remove('id'),
    );
  }

  Future<void> update(QmimorjaItem item) async {
    await AppDb.I.db.update(
      table,
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> delete(int id) async {
    await AppDb.I.db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
