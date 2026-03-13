import 'package:mjeshtri/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/vizato_sketch.dart';

class SketchProjectsDao {
  SketchProjectsDao._();
  static final SketchProjectsDao I = SketchProjectsDao._();

  Future<Database> get _db async => AppDb.I.database;

  Future<void> ensureTable() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sketch_projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        items_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insert(SketchProject item) async {
    await ensureTable();
    final db = await _db;
    return db.insert('sketch_projects', item.toMap());
  }

  Future<int> update(SketchProject item) async {
    await ensureTable();
    final db = await _db;
    return db.update(
      'sketch_projects',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    await ensureTable();
    final db = await _db;
    return db.delete(
      'sketch_projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SketchProject>> list() async {
    await ensureTable();
    final db = await _db;
    final rows = await db.query(
      'sketch_projects',
      orderBy: 'updated_at DESC',
    );
    return rows.map((e) => SketchProject.fromMap(e)).toList();
  }

  Future<SketchProject?> getById(int id) async {
    await ensureTable();
    final db = await _db;
    final rows = await db.query(
      'sketch_projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SketchProject.fromMap(rows.first);
  }
}
