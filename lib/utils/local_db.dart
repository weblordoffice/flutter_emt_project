import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'emtrack.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tires (
            tireId        INTEGER PRIMARY KEY,
            tireSerialNo  TEXT,
            sizeName      TEXT,
            typeName      TEXT,
            manufacturerName TEXT,
            dispositionId INTEGER,
            dispositionName  TEXT,
            vehicleNumber TEXT,
            wheelPosition TEXT,
            currentTreadDepth REAL,
            outsideTread  REAL,
            insideTread   REAL,
            currentPressure REAL,
            currentHours  REAL,
            currentMiles  REAL,
            originalTread REAL,
            removeAt      REAL,
            locationId    INTEGER,
            parentAccountId INTEGER,
            tireStatusName TEXT,
            percentageWorn REAL,
            updatedAt     TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_installs (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            payload       TEXT NOT NULL,
            tireId        INTEGER,
            vehicleId     INTEGER,
            wheelPosition TEXT,
            tireSerialNo  TEXT,
            createdAt     TEXT NOT NULL,
            syncStatus    TEXT DEFAULT 'pending'
          )
        ''');
      },
    );
  }



  static Future<void> saveTires(List<Map<String, dynamic>> tires) async {
    final db = await database;
    final batch = db.batch();

    for (final t in tires) {
      batch.insert(
        'tires',
        {
          'tireId':           t['tireId'],
          'tireSerialNo':     t['tireSerialNo'],
          'sizeName':         t['sizeName'],
          'typeName':         t['typeName'],
          'manufacturerName': t['manufacturerName'],
          'dispositionId':    t['dispositionId'],
          'dispositionName':  t['dispositionName'],
          'vehicleNumber':    t['vehicleNumber'],
          'wheelPosition':    t['wheelPosition'],
          'currentTreadDepth': t['currentTreadDepth'],
          'outsideTread':     t['outsideTread'],
          'insideTread':      t['insideTread'],
          'currentPressure':  t['currentPressure'],
          'currentHours':     t['currentHours'],
          'currentMiles':     t['currentMiles'],
          'originalTread':    t['originalTread'],
          'removeAt':         t['removeAt'],
          'locationId':       t['locationId'],
          'parentAccountId':  t['parentAccountId'],
          'tireStatusName':   t['tireStatusName'],
          'percentageWorn':   t['percentageWorn'],
          'updatedAt':        DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("✅ LocalDB: ${tires.length} tires saved");
  }

  static Future<List<Map<String, dynamic>>> getInventoryTires({
    int? parentAccountId,
    int? locationId,
  }) async {
    final db = await database;

    String where = "(dispositionId = 8 OR LOWER(dispositionName) = 'inventory')";
    List<dynamic> args = [];

    if (parentAccountId != null) {
      where += " AND parentAccountId = ?";
      args.add(parentAccountId);
    }

    if (locationId != null) {
      where += " AND locationId = ?";
      args.add(locationId);
    }

    final result = await db.query(
      'tires',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'tireSerialNo ASC',
    );

    print("✅ LocalDB Inventory Tires: ${result.length}");
    return result;
  }

  static Future<List<Map<String, dynamic>>> searchInventoryTires({
    required String query,
    int? parentAccountId,
    int? locationId,
  }) async {
    final db = await database;
    final q = '%${query.toLowerCase()}%';

    String where = "(dispositionId = 8 OR LOWER(dispositionName) = 'inventory')"
        " AND (LOWER(tireSerialNo) LIKE ? OR LOWER(sizeName) LIKE ?"
        " OR LOWER(manufacturerName) LIKE ? OR LOWER(vehicleNumber) LIKE ?)";
    List<dynamic> args = [q, q, q, q];

    if (parentAccountId != null) {
      where += " AND parentAccountId = ?";
      args.add(parentAccountId);
    }

    if (locationId != null) {
      where += " AND locationId = ?";
      args.add(locationId);
    }

    final result = await db.query(
      'tires',
      where: where,
      whereArgs: args,
      orderBy: 'tireSerialNo ASC',
    );

    print("🔎 LocalDB Search '$query': ${result.length} results");
    return result;
  }

  /// Ek tire ka disposition update karo locally (install ke baad)
  static Future<void> updateTireDisposition({
    required int tireId,
    required int dispositionId,
    required String dispositionName,
    String? wheelPosition,
    int? vehicleId,
  }) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'dispositionId':   dispositionId,
      'dispositionName': dispositionName,
      'updatedAt':       DateTime.now().toIso8601String(),
    };
    if (wheelPosition != null) updateData['wheelPosition'] = wheelPosition;

    await db.update(
      'tires',
      updateData,
      where: 'tireId = ?',
      whereArgs: [tireId],
    );
    print("✅ LocalDB: tireId=$tireId disposition updated to $dispositionName");
  }

  // ══════════════════════════════════════════════
  // 🟡 PENDING INSTALLS — Offline Queue
  // ══════════════════════════════════════════════

  static Future<void> addPendingInstall(Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('pending_installs', {
      'payload':      payload.toString(), // JSON string
      'tireId':       payload['tireId'],
      'vehicleId':    payload['vehicleId'],
      'wheelPosition': payload['wheelPosition'],
      'tireSerialNo': payload['tireSerialNo'],
      'createdAt':    DateTime.now().toIso8601String(),
      'syncStatus':   'pending',
    });
    print("✅ LocalDB: Pending install added for tire ${payload['tireId']}");
  }

  static Future<List<Map<String, dynamic>>> getPendingInstalls() async {
    final db = await database;
    return await db.query(
      'pending_installs',
      where: "syncStatus = 'pending'",
      orderBy: 'createdAt ASC',
    );
  }

  static Future<void> markInstallSynced(int id) async {
    final db = await database;
    await db.update(
      'pending_installs',
      {'syncStatus': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
    print("✅ LocalDB: pending_install id=$id marked synced");
  }

  static Future<int> getPendingInstallsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_installs WHERE syncStatus = 'pending'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}