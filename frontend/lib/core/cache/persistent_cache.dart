import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'cache_entry.dart';

// ignore: constant_identifier_names
const TABLES = ["units", "foods", "recipes_full", "recipe_list_items"];

/// SQLite-based persistent cache
class PersistentCache {
  static const String _dbName = 'zest_persistent_cache.db';
  static const int _dbVersion = 1;

  Database? _db;
  final _initCompleter = Completer<void>();

  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );

    _initCompleter.complete();
  }

  Future<void> _createDb(Database db, int version) async {
    // sort of auto generated tables for units, foods, recipes etc.
    await db.transaction((txn) async {
      for (final tableName in TABLES) {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          key TEXT PRIMARY KEY,
          data TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          item_timestamp INTEGER
        )
      ''');

        await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_cached_at
        ON $tableName(cached_at)
      ''');

        await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_${tableName}_item_timestamp
        ON $tableName(item_timestamp)
      ''');
      }
    });
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here
  }

  Future<Database> get database async {
    await _initCompleter.future;
    return _db!;
  }

  Future<CacheEntry<T>?> get<T>(
    String tableName,
    String key,
    T Function(dynamic) decoder,
  ) async {
    final db = await database;

    final results = await db.query(
      tableName,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return CacheEntry<T>(
      key: row['key'] as String,
      data: decoder(jsonDecode(row['data'] as String)),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
      itemTimestamp: DateTime.fromMillisecondsSinceEpoch(
          row['item_timestamp'] as int? ?? 0),
    );
  }

  Future<void> put<T>(
    String tableName,
    CacheEntry<T> entry,
    dynamic Function(T) encoder,
  ) async {
    final db = await database;

    await db.insert(
        tableName,
        {
          'key': entry.key,
          'data': jsonEncode(encoder(entry.data)),
          'cached_at': entry.cachedAt.millisecondsSinceEpoch,
          'item_timestamp': entry.itemTimestamp?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CacheEntry<T>>> getAll<T>(
    String tableName,
    T Function(dynamic) decoder,
  ) async {
    final db = await database;

    final results = await db.query(tableName);

    return results.map((row) {
      return CacheEntry<T>(
        key: row['key'] as String,
        data: decoder(jsonDecode(row['data'] as String)),
        cachedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
        itemTimestamp: DateTime.fromMillisecondsSinceEpoch(
          row['item_timestamp'] as int? ?? 0,
        ),
      );
    }).toList();
  }

  Future<void> remove(String tableName, String key) async {
    final db = await database;
    await db.delete(tableName, where: 'key = ?', whereArgs: [key]);
  }

  Future<void> removeTable(String tableName) async {
    final db = await database;
    await db.delete(tableName);
  }

  Future<void> removeExpired(String tableName, Duration ttl) async {
    final db = await database;
    final expiryTime = DateTime.now().subtract(ttl).millisecondsSinceEpoch;

    await db.delete(tableName, where: 'cached_at < ?', whereArgs: [expiryTime]);
  }

  Future<void> clear(String tableName) async {
    final db = await database;
    await db.delete(tableName);
  }

  Future<int> getCount(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE table_name = ?',
      [tableName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
