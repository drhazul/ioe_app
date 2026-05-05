import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'attendance_local_queue_service.dart';
import 'reloj_checador_app_api.dart';

class AttendanceSyncWorker {
  AttendanceSyncWorker({
    required AttendanceLocalQueueService queue,
    required RelojChecadorAppApi api,
    required String deviceId,
  }) : _queue = queue,
       _api = api,
       _deviceId = deviceId;

  final AttendanceLocalQueueService _queue;
  final RelojChecadorAppApi _api;
  final String _deviceId;
  final Battery _battery = Battery();
  static const _uuid = Uuid();

  Timer? _syncTimer;
  Timer? _heartbeatTimer;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    // First heartbeat and sync on start.
    await _enqueueHeartbeat();
    await _drainQueue();

    _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(_drainQueue());
    });

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(_enqueueHeartbeat());
    });
  }

  Future<void> stop() async {
    _running = false;
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _syncTimer = null;
    _heartbeatTimer = null;
  }

  Future<void> _enqueueHeartbeat() async {
    try {
      int level = -1;
      String charging = 'unknown';

      if (!kIsWeb) {
        try {
          level = await _battery.batteryLevel;
          final status = await _battery.batteryState;
          charging = status.name;
        } catch (_) {
          // Ignore battery plugin edge-cases; heartbeat still sent.
        }
      }

      final clientId = _uuid.v4().toUpperCase();
      await _queue.enqueue(
        endpoint: '/reloj-checador/auditoria',
        payload: {
          'EVENTO': 'HEARTBEAT',
          'DETALLE': 'battery=$level;charging=$charging',
          'DEVICE_ID': _deviceId,
          'CLIENT_ID_UNICO': clientId,
          'FECHA_HORA_LOCAL': DateTime.now().toIso8601String(),
        },
        headers: const <String, dynamic>{},
        recordType: 'AUDIT',
        priority: 1,
        clientId: clientId,
      );
    } catch (_) {
      // Heartbeat must never break UI flow.
    }
  }

  Future<void> _drainQueue() async {
    if (!_running) return;

    final pending = await _queue.pullPending(limit: 50);
    for (final row in pending) {
      if (!_running) return;

      try {
        if (row.endpoint == '/reloj-checador/timelog') {
          await _api.createTimelogQueued(row.payload, row.headers);
        } else if (row.endpoint == '/reloj-checador/auditoria') {
          await _api.createAuditLogQueued(row.payload, row.headers);
        }
        await _queue.markSynced(row.id);
      } catch (_) {
        await _queue.markRetry(row.id, row.attempts + 1);
      }
    }

    await _queue.cleanupSyncedOlderThan7Days();
  }
}
