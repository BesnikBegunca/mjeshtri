import 'package:mjeshtri/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/product_calc_item.dart';

class CalcProductsDao {
  CalcProductsDao._();
  static final CalcProductsDao I = CalcProductsDao._();

  static const table = 'calc_products';

  Future<Database> get _db async => AppDb.I.db;

  Future<List<ProductCalcItem>> list() async {
    final db = await _db;
    final rows = await db.query(
      table,
      orderBy: 'emertimi COLLATE NOCASE ASC',
    );
    return rows.map(ProductCalcItem.fromMap).toList();
  }

  Future<int> insert(ProductCalcItem item) async {
    final db = await _db;

    final data = {
      'kodi': item.kodi.trim(),
      'emertimi': item.emertimi.trim(),
      'pako': item.pako.trim(),
      'sasiaPer100m2': item.sasiaPer100m2,
      'vleraPer100m2': item.vleraPer100m2,
      'tvshPer100m2': item.tvshPer100m2,
    };

    return db.insert(table, data);
  }

  Future<int> update(ProductCalcItem item) async {
    if (item.id == null) {
      throw Exception('Produkti nuk ka ID për update.');
    }

    final db = await _db;

    final data = {
      'kodi': item.kodi.trim(),
      'emertimi': item.emertimi.trim(),
      'pako': item.pako.trim(),
      'sasiaPer100m2': item.sasiaPer100m2,
      'vleraPer100m2': item.vleraPer100m2,
      'tvshPer100m2': item.tvshPer100m2,
    };

    return db.update(
      table,
      data,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}