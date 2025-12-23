import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern to ensure only one instance of the database exists
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // Database Info
  static const _dbName = 'smartsilence.db';
  static const _dbVersion = 1;

  // Table Names
  static const tableContexts = 'contexts';
  static const tableLogs = 'activity_logs';

  // Column Names (Contexts Table)
  static const colId = 'id';
  static const colName = 'name';
  static const colType = 'type'; // 'GEOFENCE' or 'WIFI'
  static const colValue = 'value'; // Lat/Long string or SSID name
  static const colRadius = 'radius'; // For Geofence only
  static const colIsActive = 'is_active'; // 1 = true, 0 = false

  // Column Names (Logs Table)
  static const colLogId = 'log_id';
  static const colTimestamp = 'timestamp'; // Unix timestamp
  static const colTrigger = 'trigger_source'; // 'MANUAL', 'GEOFENCE', 'WIFI'
  static const colAction = 'action_taken'; // 'SILENT', 'RINGER'

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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create Contexts Table (For Feature 1: Context Awareness)
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

    // 2. Create Logs Table (For Feature 3: Forecasting)
    // We log every silence event to analyze patterns later
    await db.execute('''
      CREATE TABLE $tableLogs (
        $colLogId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colTimestamp INTEGER NOT NULL,
        $colTrigger TEXT NOT NULL,
        $colAction TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------
  // CRUD Operations for Contexts (Feature 1)
  // ---------------------------------------------------

  // Create a new Context (Place or Wi-Fi)
  Future<int> insertContext(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(tableContexts, row);
  }

  // Get all saved contexts to display on 'Places' page
  Future<List<Map<String, dynamic>>> getAllContexts() async {
    Database db = await database;
    return await db.query(tableContexts);
  }

  // Toggle a context on/off
  Future<int> toggleContext(int id, int isActive) async {
    Database db = await database;
    return await db.update(
      tableContexts,
      {colIsActive: isActive},
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  // Delete a context
  Future<int> deleteContext(int id) async {
    Database db = await database;
    return await db.delete(
      tableContexts,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------
  // Operations for Forecasting Logic (Feature 3)
  // ---------------------------------------------------

  // Log an event whenever the mode changes
  Future<int> logEvent(String trigger, String action) async {
    Database db = await database;
    Map<String, dynamic> row = {
      colTimestamp: DateTime.now().millisecondsSinceEpoch,
      colTrigger: trigger,
      colAction: action,
    };
    return await db.insert(tableLogs, row);
  }

  // Fetch logs for the past 7 days to analyze
  Future<List<Map<String, dynamic>>> getRecentLogs() async {
    Database db = await database;
    // Calculate timestamp for 7 days ago
    int sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    
    return await db.query(
      tableLogs,
      where: '$colTimestamp > ?',
      whereArgs: [sevenDaysAgo],
      orderBy: '$colTimestamp DESC',
    );
  }
  
  // Advanced: Get usage count by day of week (Monday=1, Sunday=7)
  // This helps us generate the chart on the Insights Page
  Future<List<Map<String, dynamic>>> getSilenceCountByDay() async {
    Database db = await database;
    // SQLite query to group by day. 
    // Note: strftime('%w') returns 0-6 where 0 is Sunday.
    // We select raw query for analytics.
    return await db.rawQuery('''
      SELECT strftime('%w', datetime($colTimestamp / 1000, 'unixepoch')) as day, count(*) as count 
      FROM $tableLogs 
      WHERE $colAction = 'SILENT' 
      GROUP BY day
    ''');
  }
}