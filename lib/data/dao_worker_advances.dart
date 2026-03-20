import 'package:mjeshtri/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/worker_advance.dart';

class WorkerAdvancesDao {
  WorkerAdvancesDao._();
  static final WorkerAdvancesDao I = WorkerAdvancesDao._();

  Future<Database> get _db async => AppDb.I.database;

  Future<int> insert(WorkerAdvance item) async {
    final db = await _db;
    return db.insert('worker_advances', item.toMap());
  }

  Future<int> update(WorkerAdvance item) async {
    final db = await _db;
    return db.update(
      'worker_advances',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(
      'worker_advances',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<WorkerAdvance>> listForWorker(int workerId) async {
    final db = await _db;
    final rows = await db.query(
      'worker_advances',
      where: 'workerId = ?',
      whereArgs: [workerId],
      orderBy: 'month ASC, createdAt ASC, id ASC',
    );
    return rows.map((e) => WorkerAdvance.fromMap(e)).toList();
  }

  Future<List<WorkerAdvance>> listForWorkerMonth(
    int workerId,
    String month,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'worker_advances',
      where: 'workerId = ? AND month = ?',
      whereArgs: [workerId, month],
      orderBy: 'createdAt DESC, id DESC',
    );
    return rows.map((e) => WorkerAdvance.fromMap(e)).toList();
  }

  Future<double> totalForWorkerMonth(int workerId, String month) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM worker_advances
      WHERE workerId = ? AND month = ?
      ''',
      [workerId, month],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['total'] as num?) ?? 0).toDouble();
  }

  Future<double> totalForWorker(int workerId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM worker_advances
      WHERE workerId = ?
      ''',
      [workerId],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['total'] as num?) ?? 0).toDouble();
  }

  Future<List<String>> monthsForWorker(int workerId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT month
      FROM worker_advances
      WHERE workerId = ?
      ORDER BY month ASC
      ''',
      [workerId],
    );

    return rows
        .map((e) => (e['month']?.toString() ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> deleteForWorker(int workerId) async {
    final db = await _db;
    await db.delete(
      'worker_advances',
      where: 'workerId = ?',
      whereArgs: [workerId],
    );
  }
}
