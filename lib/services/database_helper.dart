import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // Database Info
  static const _dbName = 'smartsilence.db';
  
  // --- STEP 1: INCREMENT VERSION ---
  static const _dbVersion = 2; // Changed from 1 to 2 to trigger migration

  // Table Names
  static const tableContexts = 'contexts';
  static const tableLogs = 'activity_logs';
  static const tableSchedules = 'schedules'; // New table

  // Column Names (Contexts)
  static const colId = 'id';
  static const colName = 'name';
  static const colType = 'type'; 
  static const colValue = 'value'; 
  static const colRadius = 'radius'; 
  static const colIsActive = 'is_active'; 

  // Column Names (Logs)
  static const colLogId = 'log_id';
  static const colTimestamp = 'timestamp'; 
  static const colTrigger = 'trigger_source'; 
  static const colAction = 'action_taken'; 

  // Initialize Database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      // --- STEP 2: ADD MIGRATION LOGIC HERE ---
      onUpgrade: _onUpgrade, 
    );
  }

  // Handle new database creation (First time install)
  Future<void> _onCreate(Database db, int version) async {
    // 1. Create Contexts Table
    await db.execute('''
      CREATE TABLE $tableContexts (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colName TEXT NOT NULL,
        $colType TEXT NOT NULL,
        $colValue TEXT NOT NULL,
        $colRadius INTEGER,
        $colIsActive INTEGER DEFAULT 1
      )
    ''');

    // 2. Create Logs Table
    await db.execute('''
      CREATE TABLE $tableLogs (
        $colLogId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colTimestamp INTEGER NOT NULL,
        $colTrigger TEXT NOT NULL,
        $colAction TEXT NOT NULL
      )
    ''');

    // 3. Create Schedules Table (New)
    await db.execute('''
      CREATE TABLE $tableSchedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT,
        time TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  // --- STEP 3: HANDLE UPDATES FOR EXISTING USERS ---
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // If user has version 1, add the new 'schedules' table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSchedules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day TEXT,
          time TEXT,
          is_active INTEGER DEFAULT 1
        )
      ''');
      print("MIGRATION: Database upgraded to version 2 (Schedules table created)");
    }
  }

  // ---------------------------------------------------
  // CRUD Operations 
  // ---------------------------------------------------

  // Create Context
  Future<int> insertContext(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(tableContexts, row);
  }

  // Get Contexts
  Future<List<Map<String, dynamic>>> getAllContexts() async {
    Database db = await database;
    return await db.query(tableContexts);
  }

  // Clear Logs
  Future<void> clearAllLogs() async {
    final db = await database;
    await db.delete(tableLogs);
  }

  // Delete Context
  Future<void> deleteContext(int id) async {
    final db = await database;
    await db.delete(tableContexts, where: '$colId = ?', whereArgs: [id]);
  }

  // Update Context Name
  Future<void> updateContextName(int id, String newName) async {
    final db = await database;
    await db.update(tableContexts, {colName: newName}, where: '$colId = ?', whereArgs: [id]);
  }

  // Toggle Context
  Future<int> toggleContext(int id, int isActive) async {
    Database db = await database;
    return await db.update(tableContexts, {colIsActive: isActive}, where: '$colId = ?', whereArgs: [id]);
  }

  // Log Event
  Future<int> logEvent(String trigger, String action) async {
    Database db = await database;
    Map<String, dynamic> row = {
      colTimestamp: DateTime.now().millisecondsSinceEpoch,
      colTrigger: trigger,
      colAction: action,
    };
    return await db.insert(tableLogs, row);
  }

  // Get Recent Logs
  Future<List<Map<String, dynamic>>> getRecentLogs() async {
    Database db = await database;
    int sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    
    return await db.query(
      tableLogs,
      where: '$colTimestamp > ?',
      whereArgs: [sevenDaysAgo],
      orderBy: '$colTimestamp DESC',
    );
  }

  // Get Silence Count By Day (Fixed Query)
  Future<List<Map<String, dynamic>>> getSilenceCountByDay() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        CASE CAST(strftime('%w', datetime(timestamp/1000, 'unixepoch', 'localtime')) AS INTEGER)
          WHEN 0 THEN 'Sunday'
          WHEN 1 THEN 'Monday'
          WHEN 2 THEN 'Tuesday'
          WHEN 3 THEN 'Wednesday'
          WHEN 4 THEN 'Thursday'
          WHEN 5 THEN 'Friday'
          WHEN 6 THEN 'Saturday'
        END as day_name,
        COUNT(*) as silence_count
      FROM $tableLogs
      WHERE $colAction = 'SILENT'
      GROUP BY day_name
    ''');
  }

  // Insert Schedule
  Future<void> insertSchedule(String day, String time) async {
    final db = await database;
    await db.insert(
      tableSchedules, 
      {'day': day, 'time': time, 'is_active': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print("Schedule Automated: $day at $time");
  }
}