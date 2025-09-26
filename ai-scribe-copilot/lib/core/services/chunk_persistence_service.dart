import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../utils/logger.dart';
import '../models/recording_chunk.dart';

class ChunkPersistenceService {
  ChunkPersistenceService({required this.logger});

  final Logger logger;
  Database? _database;
  final _uuid = const Uuid();

  Future<void> ensureInitialized() async {
    if (_database != null) {
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'recording_chunks.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chunks (
            id TEXT PRIMARY KEY,
            sessionId TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            filePath TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            uploadedAt TEXT,
            retryCount INTEGER NOT NULL
          );
        ''');
      },
    );
  }

  Future<RecordingChunk> addChunk({
    required String sessionId,
    required int sequence,
    required String filePath,
  }) async {
    final chunk = RecordingChunk(
      id: _uuid.v4(),
      sessionId: sessionId,
      sequence: sequence,
      filePath: filePath,
      createdAt: DateTime.now().toUtc(),
      retryCount: 0,
    );
    await _database!.insert('chunks', chunk.toJson());
    logger.d('Persisted chunk ${chunk.id} for session $sessionId');
    return chunk;
  }

  Future<void> markUploaded(String chunkId) async {
    await _database!.update(
      'chunks',
      {
        'uploadedAt': DateTime.now().toUtc().toIso8601String(),
        'retryCount': 0,
      },
      where: 'id = ?',
      whereArgs: [chunkId],
    );
  }

  Future<void> incrementRetry(String chunkId) async {
    await _database!.rawUpdate(
      'UPDATE chunks SET retryCount = retryCount + 1 WHERE id = ?',
      [chunkId],
    );
  }

  Future<void> deleteChunk(String chunkId) async {
    final chunk = await getChunkById(chunkId);
    if (chunk != null) {
      final file = File(chunk.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _database!.delete(
      'chunks',
      where: 'id = ?',
      whereArgs: [chunkId],
    );
  }

  Future<RecordingChunk?> getChunkById(String chunkId) async {
    final rows = await _database!.query(
      'chunks',
      where: 'id = ?',
      whereArgs: [chunkId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return RecordingChunk.fromJson(rows.first);
  }

  Future<List<RecordingChunk>> pendingChunks({String? sessionId}) async {
    final where = <String>[];
    final args = <Object?>[];
    where.add('uploadedAt IS NULL');
    if (sessionId != null) {
      where.add('sessionId = ?');
      args.add(sessionId);
    }
    final rows = await _database!.query(
      'chunks',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'createdAt ASC',
    );
    return rows.map(RecordingChunk.fromJson).toList();
  }

  Future<void> clearSession(String sessionId) async {
    final rows = await _database!.query(
      'chunks',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    for (final row in rows) {
      final file = File(row['filePath'] as String);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _database!.delete(
      'chunks',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }
}
