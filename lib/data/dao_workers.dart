import '../models/worker.dart';
import 'db.dart';

class WorkersDao {
  WorkersDao._();
  static final WorkersDao I = WorkersDao._();

  Future<List<Worker>> list() async {
    final rows = await AppDb.I.db.query('workers', orderBy: 'id DESC');
    return rows.map(Worker.fromMap).toList();
  }

  Future<int> insert(Worker w) async => AppDb.I.db.insert('workers', w.toMap());

  Future<void> update(Worker w) async {
    await AppDb.I.db.update('workers', w.toMap(), where: 'id=?', whereArgs: [w.id]);
  }

  Future<void> delete(int id) async {
    await AppDb.I.db.delete('workers', where: 'id=?', whereArgs: [id]);
  }
}
