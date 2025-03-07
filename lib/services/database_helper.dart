import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/trip.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'trips_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trips(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        distance REAL NOT NULL,
        transportationMode TEXT NOT NULL,
        steps INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE location_points(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tripId INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        speed REAL,
        heading REAL,
        timestamp INTEGER NOT NULL,
        activity TEXT,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');
  }

  // Trip methods
  Future<int> insertTrip(Trip trip) async {
    final db = await database;
    return await db.insert('trips', trip.toMap());
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await database;
    return await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<int> deleteTrip(int id) async {
    final db = await database;
    await db.delete(
      'location_points',
      where: 'tripId = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Trip?> getTrip(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    Trip trip = Trip.fromMap(maps.first);
    List<LocationPoint> locationPoints = await getLocationPointsForTrip(id);
    return trip.copyWith(locationPoints: locationPoints);
  }

  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      orderBy: 'startTime DESC',
    );

    return List.generate(maps.length, (i) {
      return Trip.fromMap(maps[i]);
    });
  }

  // Location point methods
  Future<int> insertLocationPoint(LocationPoint point) async {
    final db = await database;
    return await db.insert('location_points', point.toMap());
  }

  Future<List<LocationPoint>> getLocationPointsForTrip(int tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'location_points',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return LocationPoint.fromMap(maps[i]);
    });
  }

  Future<void> insertLocationPoints(List<LocationPoint> points) async {
    final db = await database;
    Batch batch = db.batch();
    
    for (var point in points) {
      batch.insert('location_points', point.toMap());
    }
    
    await batch.commit(noResult: true);
  }
}
