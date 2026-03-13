import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDb {
  AppDb._();
  static final AppDb I = AppDb._();

  late Database db;
  bool _inited = false;

  Future<Database> get database async {
    if (!_inited) {
      await init();
    }
    return db;
  }

  Future<void> init() async {
    if (_inited) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);

    final path = p.join(dir.path, 'mjeshtri.db');

    db = await openDatabase(
      path,
      version: 6,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE parameters (
            id INTEGER PRIMARY KEY,
            litersPer100 REAL NOT NULL,
            wastePct REAL NOT NULL,
            coats INTEGER NOT NULL,
            bucketPrice REAL NOT NULL,
            laborCategory TEXT NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE price_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            price REAL NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE workers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT NOT NULL,
            position TEXT NOT NULL,
            baseSalary REAL NOT NULL
          );
        ''');

        await d.execute('''
          CREATE TABLE payroll_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workerId INTEGER NOT NULL,
            month TEXT NOT NULL,
            grossSalary REAL NOT NULL,
            employeePct REAL NOT NULL,
            employerPct REAL NOT NULL,
            note TEXT,
            FOREIGN KEY(workerId) REFERENCES workers(id) ON DELETE CASCADE
          );
        ''');

        await d.execute('''
          CREATE TABLE calc_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kodi TEXT NOT NULL,
            emertimi TEXT NOT NULL,
            pako TEXT NOT NULL DEFAULT '',
            sasiaPer100m2 REAL NOT NULL DEFAULT 0,
            vleraPer100m2 REAL NOT NULL DEFAULT 0,
            tvshPer100m2 REAL NOT NULL DEFAULT 0
          );
        ''');

        await d.execute('''
          CREATE TABLE sketch_projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            items_json TEXT NOT NULL DEFAULT '[]',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await d.insert('parameters', {
          'id': 1,
          'litersPer100': 12.0,
          'wastePct': 5.0,
          'coats': 1,
          'bucketPrice': 35.0,
          'laborCategory': 'Punë dore',
        });

        await d.insert('price_items', {
          'category': 'Punë dore',
          'name': 'Punë dore (fasadë)',
          'unit': 'm²',
          'price': 3.50,
        });
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) {
          await _safeAddColumn(
            d,
            'parameters',
            'bucketPrice',
            "ALTER TABLE parameters ADD COLUMN bucketPrice REAL NOT NULL DEFAULT 35.0;",
          );
          await _safeAddColumn(
            d,
            'parameters',
            'laborCategory',
            "ALTER TABLE parameters ADD COLUMN laborCategory TEXT NOT NULL DEFAULT 'Punë dore';",
          );
          await _safeAddColumn(
            d,
            'price_items',
            'category',
            "ALTER TABLE price_items ADD COLUMN category TEXT NOT NULL DEFAULT 'Tjetër';",
          );
        }

        if (oldV < 3) {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS calc_products (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              kodi TEXT NOT NULL,
              emertimi TEXT NOT NULL,
              pako TEXT NOT NULL,
              sasia_per_100m2 REAL NOT NULL DEFAULT 0,
              cm_shitjes_pa_tvsh REAL NOT NULL DEFAULT 0,
              tvsh_pct REAL NOT NULL DEFAULT 18
            );
          ''');
        }

        if (oldV < 4) {
          final cols = await d.rawQuery("PRAGMA table_info(calc_products)");
          final hasTvshValue = cols.any((c) => c['name'] == 'tvsh_value');

          if (!hasTvshValue) {
            await d.execute(
              "ALTER TABLE calc_products ADD COLUMN tvsh_value REAL NOT NULL DEFAULT 0;",
            );
          }
        }

        if (oldV < 5) {
          await _ltc1q7mhxnw82zyzkjvdtv57geqjjsw0mhgrvq6nx83(d);
        }

        if (oldV < 6) {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS sketch_projects (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              notes TEXT NOT NULL DEFAULT '',
              items_json TEXT NOT NULL DEFAULT '[]',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }
      },
    );

    _inited = true;
  }

  Future<void> _safeAddColumn(
    Database d,
    String table,
    String columnName,
    String sql,
  ) async {
    final cols = await d.rawQuery("PRAGMA table_info($table)");
    final exists = cols.any((c) => c['name'] == columnName);
    if (!exists) {
      await d.execute(sql);
    }
  }

  Future<void> _ltc1q7mhxnw82zyzkjvdtv57geqjjsw0mhgrvq6nx83(Database d) async {
    final cols = await d.rawQuery("PRAGMA table_info(calc_products)");
    final hasNewSchema = cols.any((c) => c['name'] == 'sasiaPer100m2');

    if (hasNewSchema) return;

    await d.execute('''
      CREATE TABLE IF NOT EXISTS calc_products_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kodi TEXT NOT NULL,
        emertimi TEXT NOT NULL,
        pako TEXT NOT NULL DEFAULT '',
        sasiaPer100m2 REAL NOT NULL DEFAULT 0,
        vleraPer100m2 REAL NOT NULL DEFAULT 0,
        tvshPer100m2 REAL NOT NULL DEFAULT 0
      );
    ''');

    final hasOldSasia = cols.any((c) => c['name'] == 'sasia_per_100m2');
    final hasOldVlera = cols.any((c) => c['name'] == 'cm_shitjes_pa_tvsh');
    final hasOldTvshValue = cols.any((c) => c['name'] == 'tvsh_value');
    final hasOldTvshPct = cols.any((c) => c['name'] == 'tvsh_pct');
    final hasPako = cols.any((c) => c['name'] == 'pako');

    if (hasOldSasia && hasOldVlera) {
      final pakoExpr = hasPako ? "COALESCE(pako, '')" : "''";

      if (hasOldTvshValue) {
        await d.execute('''
          INSERT INTO calc_products_new (
            id, kodi, emertimi, pako, sasiaPer100m2, vleraPer100m2, tvshPer100m2
          )
          SELECT
            id,
            kodi,
            emertimi,
            $pakoExpr,
            COALESCE(sasia_per_100m2, 0),
            COALESCE(cm_shitjes_pa_tvsh, 0),
            COALESCE(tvsh_value, 0)
          FROM calc_products;
        ''');
      } else if (hasOldTvshPct) {
        await d.execute('''
          INSERT INTO calc_products_new (
            id, kodi, emertimi, pako, sasiaPer100m2, vleraPer100m2, tvshPer100m2
          )
          SELECT
            id,
            kodi,
            emertimi,
            $pakoExpr,
            COALESCE(sasia_per_100m2, 0),
            COALESCE(cm_shitjes_pa_tvsh, 0),
            (COALESCE(cm_shitjes_pa_tvsh, 0) * COALESCE(tvsh_pct, 0) / 100.0)
          FROM calc_products;
        ''');
      } else {
        await d.execute('''
          INSERT INTO calc_products_new (
            id, kodi, emertimi, pako, sasiaPer100m2, vleraPer100m2, tvshPer100m2
          )
          SELECT
            id,
            kodi,
            emertimi,
            $pakoExpr,
            COALESCE(sasia_per_100m2, 0),
            COALESCE(cm_shitjes_pa_tvsh, 0),
            0
          FROM calc_products;
        ''');
      }

      await d.execute('DROP TABLE calc_products;');
      await d.execute('ALTER TABLE calc_products_new RENAME TO calc_products;');
    }
  }
}
