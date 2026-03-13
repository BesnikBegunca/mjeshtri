import '../models/payroll_entry.dart';
import 'db.dart';

class PayrollDao {
  PayrollDao._();
  static final PayrollDao I = PayrollDao._();

  Future<List<PayrollEntry>> listForWorker(int workerId) async {
    final rows = await AppDb.I.db.query(
      'payroll_entries',
      where: 'workerId=?',
      whereArgs: [workerId],
      orderBy: 'month DESC, id DESC',
    );
    return rows.map(PayrollEntry.fromMap).toList();
  }
  Future<void> update(PayrollEntry e) async {
    await AppDb.I.db.update(
      'payroll_entries',
      e.toMap(),
      where: 'id=?',
      whereArgs: [e.id],
    );
  }


  Future<int> insert(PayrollEntry e) async => AppDb.I.db.insert('payroll_entries', e.toMap());

  Future<void> delete(int id) async {
    await AppDb.I.db.delete('payroll_entries', where: 'id=?', whereArgs: [id]);
  }
}
