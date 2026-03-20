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

  Future<PayrollEntry?> findForWorkerMonth(int workerId, String month) async {
    final rows = await AppDb.I.db.query(
      'payroll_entries',
      where: 'workerId=? AND month=?',
      whereArgs: [workerId, month],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return PayrollEntry.fromMap(rows.first);
  }

  Future<void> update(PayrollEntry e) async {
    await AppDb.I.db.update(
      'payroll_entries',
      e.toMap(),
      where: 'id=?',
      whereArgs: [e.id],
    );
  }

  Future<int> insert(PayrollEntry e) async {
    return AppDb.I.db.insert('payroll_entries', e.toMap());
  }

  Future<void> upsertByWorkerMonth(PayrollEntry e) async {
    final existing = await findForWorkerMonth(e.workerId, e.month);

    if (existing == null) {
      await insert(e);
    } else {
      await update(
        e.copyWith(id: existing.id),
      );
    }
  }

  Future<void> delete(int id) async {
    await AppDb.I.db.delete(
      'payroll_entries',
      where: 'id=?',
      whereArgs: [id],
    );
  }
}
