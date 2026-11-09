import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';

class LocalDbHelper {
  static Database? _database;

  Future<Database?> get database async {
    if (kIsWeb) {
      // Trên Web không sử dụng SQLite native file
      return null;
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE check_in_logs(
            id TEXT PRIMARY KEY,
            userId TEXT,
            timestamp TEXT,
            type TEXT
          )
        ''');
      },
    );
  }
}
