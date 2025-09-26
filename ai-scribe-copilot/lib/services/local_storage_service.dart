import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';
import '../models/recording_session.dart';
import '../models/audio_chunk.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Database? _database;
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    await _initDatabase();
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'ai_scribe_copilot.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create patients table
        await db.execute('''
          CREATE TABLE patients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            dateOfBirth TEXT NOT NULL,
            medicalRecordNumber TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        // Create recording_sessions table
        await db.execute('''
          CREATE TABLE recording_sessions (
            id TEXT PRIMARY KEY,
            patientId TEXT NOT NULL,
            userId TEXT NOT NULL,
            status TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            totalChunks INTEGER NOT NULL,
            uploadedChunks INTEGER NOT NULL,
            transcription TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        // Create audio_chunks table
        await db.execute('''
          CREATE TABLE audio_chunks (
            id TEXT PRIMARY KEY,
            sessionId TEXT NOT NULL,
            sequenceNumber INTEGER NOT NULL,
            filePath TEXT NOT NULL,
            sizeBytes INTEGER NOT NULL,
            duration TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            status TEXT NOT NULL,
            presignedUrl TEXT,
            uploadedAt TEXT,
            retryCount INTEGER NOT NULL
          )
        ''');

        // Create indexes
        await db.execute('CREATE INDEX idx_sessions_patient ON recording_sessions(patientId)');
        await db.execute('CREATE INDEX idx_chunks_session ON audio_chunks(sessionId)');
        await db.execute('CREATE INDEX idx_chunks_status ON audio_chunks(status)');
      },
    );
  }

  // Patient operations
  Future<void> savePatient(Patient patient) async {
    if (_database == null) await initialize();
    
    await _database!.insert(
      'patients',
      patient.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Patient>> getPatients() async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query('patients');
    return maps.map((map) => Patient.fromJson(map)).toList();
  }

  Future<Patient?> getPatient(String id) async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return Patient.fromJson(maps.first);
    }
    return null;
  }

  Future<void> deletePatient(String id) async {
    if (_database == null) await initialize();
    
    await _database!.delete(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Session operations
  Future<void> saveSession(RecordingSession session) async {
    if (_database == null) await initialize();
    
    await _database!.insert(
      'recording_sessions',
      session.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RecordingSession>> getSessions() async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query('recording_sessions');
    return maps.map((map) => RecordingSession.fromJson(map)).toList();
  }

  Future<RecordingSession?> getSession(String id) async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'recording_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return RecordingSession.fromJson(maps.first);
    }
    return null;
  }

  Future<List<RecordingSession>> getSessionsByPatient(String patientId) async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'recording_sessions',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) => RecordingSession.fromJson(map)).toList();
  }

  Future<void> deleteSession(String id) async {
    if (_database == null) await initialize();
    
    await _database!.delete(
      'recording_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Chunk operations
  Future<void> saveChunk(AudioChunk chunk) async {
    if (_database == null) await initialize();
    
    await _database!.insert(
      'audio_chunks',
      chunk.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AudioChunk>> getChunks() async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query('audio_chunks');
    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<List<AudioChunk>> getChunksBySession(String sessionId) async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'audio_chunks',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'sequenceNumber ASC',
    );
    
    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<List<AudioChunk>> getPendingChunks() async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'audio_chunks',
      where: 'status = ?',
      whereArgs: [ChunkStatus.pending.name],
      orderBy: 'timestamp ASC',
    );
    
    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<List<AudioChunk>> getFailedChunks() async {
    if (_database == null) await initialize();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'audio_chunks',
      where: 'status = ?',
      whereArgs: [ChunkStatus.failed.name],
      orderBy: 'timestamp ASC',
    );
    
    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<void> deleteChunk(String id) async {
    if (_database == null) await initialize();
    
    await _database!.delete(
      'audio_chunks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteChunksBySession(String sessionId) async {
    if (_database == null) await initialize();
    
    await _database!.delete(
      'audio_chunks',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // Settings operations
  Future<void> saveSetting(String key, String value) async {
    if (_prefs == null) await initialize();
    await _prefs!.setString(key, value);
  }

  Future<String?> getSetting(String key) async {
    if (_prefs == null) await initialize();
    return _prefs!.getString(key);
  }

  Future<void> saveBoolSetting(String key, bool value) async {
    if (_prefs == null) await initialize();
    await _prefs!.setBool(key, value);
  }

  Future<bool> getBoolSetting(String key, {bool defaultValue = false}) async {
    if (_prefs == null) await initialize();
    return _prefs!.getBool(key) ?? defaultValue;
  }

  // Cleanup operations
  Future<void> clearAllData() async {
    if (_database == null) await initialize();
    
    await _database!.delete('audio_chunks');
    await _database!.delete('recording_sessions');
    await _database!.delete('patients');
  }

  Future<void> cleanupOldData({int daysOld = 30}) async {
    if (_database == null) await initialize();
    
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final cutoffString = cutoffDate.toIso8601String();
    
    // Delete old sessions and their chunks
    final oldSessions = await _database!.query(
      'recording_sessions',
      where: 'createdAt < ?',
      whereArgs: [cutoffString],
    );
    
    for (final session in oldSessions) {
      await _database!.delete(
        'audio_chunks',
        where: 'sessionId = ?',
        whereArgs: [session['id']],
      );
    }
    
    await _database!.delete(
      'recording_sessions',
      where: 'createdAt < ?',
      whereArgs: [cutoffString],
    );
  }

  Future<void> close() async {
    await _database?.close();
  }
}
