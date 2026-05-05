import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class QueuedSyncRecord {
  const QueuedSyncRecord({
    required this.id,
    required this.endpoint,
    required this.payload,
    required this.headers,
    required this.recordType,
    required this.priority,
    required this.clientId,
    required this.attempts,
  });

  final int id;
  final String endpoint;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> headers;
  final String recordType;
  final int priority;
  final String clientId;
  final int attempts;
}

class AttendanceLocalQueueService {
  AttendanceLocalQueueService();

  static const _uuid = Uuid();
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'attendance_secure_queue.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            endpoint TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            headers_json TEXT,
            record_type TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 2,
            estatus_sincronizacion INTEGER NOT NULL DEFAULT 0,
            client_id_unico TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at INTEGER,
            created_at INTEGER NOT NULL,
            synced_at INTEGER
          )
        ''');
        await db.execute(
          'CREATE UNIQUE INDEX idx_sync_queue_client_id ON sync_queue(client_id_unico)',
        );
        await db.execute(
          'CREATE INDEX idx_sync_queue_pending ON sync_queue(estatus_sincronizacion, priority, created_at)',
        );
      },
    );
    return _db!;
  }

  Future<String> enqueue({
    required String endpoint,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> headers,
    required String recordType,
    required int priority,
    String? clientId,
  }) async {
    final db = await _database();
    final id = (clientId ?? _uuid.v4()).toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('sync_queue', {
      'endpoint': endpoint,
      'payload_json': jsonEncode(payload),
      'headers_json': headers.isEmpty ? null : jsonEncode(headers),
      'record_type': recordType,
      'priority': priority,
      'estatus_sincronizacion': 0,
      'client_id_unico': id,
      'attempts': 0,
      'next_attempt_at': now,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return id;
  }

  Future<List<QueuedSyncRecord>> pullPending({int limit = 50}) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'sync_queue',
      where:
          'estatus_sincronizacion = 0 AND (next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: [now],
      orderBy: 'priority ASC, created_at ASC',
      limit: limit,
    );

    return rows
        .map((row) {
          return QueuedSyncRecord(
            id: (row['id'] as num).toInt(),
            endpoint: row['endpoint'] as String,
            payload: Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] as String?) ?? '{}') as Map,
            ),
            headers: Map<String, dynamic>.from(
              jsonDecode((row['headers_json'] as String?) ?? '{}') as Map,
            ),
            recordType: (row['record_type'] as String?) ?? 'MARCAJE',
            priority: (row['priority'] as num?)?.toInt() ?? 2,
            clientId: (row['client_id_unico'] as String?) ?? '',
            attempts: (row['attempts'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);
  }

  Future<void> markSynced(int id) async {
    final db = await _database();
    await db.update(
      'sync_queue',
      {
        'estatus_sincronizacion': 1,
        'synced_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markRetry(int id, int attempts) async {
    final db = await _database();
    final boundedAttempts = attempts.clamp(1, 4);
    final minutes = [1, 2, 4, 8][boundedAttempts - 1];
    final nextAt = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;

    await db.update(
      'sync_queue',
      {'attempts': attempts, 'next_attempt_at': nextAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cleanupSyncedOlderThan7Days() async {
    final db = await _database();
    final threshold = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    await db.delete(
      'sync_queue',
      where:
          'estatus_sincronizacion = 1 AND synced_at IS NOT NULL AND synced_at < ?',
      whereArgs: [threshold],
    );
  }
}
