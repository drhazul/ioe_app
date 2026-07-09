import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'reloj_checador_app_models.dart';

class RelojChecadorRealtimeClient {
  RelojChecadorRealtimeClient({required String baseUrl})
    : _baseUrl = _resolveSocketBase(baseUrl) {
    _socket = io.io(
      '$_baseUrl/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNewConnection()
          .setReconnectionAttempts(200)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(8000)
          .build(),
    );

    _socket.onConnect((_) {
      _connectedController.add(true);
    });
    _socket.onDisconnect((_) {
      _connectedController.add(false);
    });
    _socket.onConnectError((_) {
      _connectedController.add(false);
    });
    _socket.onError((_) {
      _connectedController.add(false);
    });

    _socket.on('new_punch', (payload) {
      final event = RelojRealtimePunchEvent.fromSocket(payload);
      if (event != null) {
        _punchController.add(event);
      }
    });

    _socket.on('template_updated', (payload) {
      final event = RelojRealtimeTemplateEvent.fromSocket(payload);
      if (event != null) {
        _templateController.add(event);
      }
    });
  }

  final String _baseUrl;
  late final io.Socket _socket;
  final _punchController = StreamController<RelojRealtimePunchEvent>.broadcast();
  final _templateController =
      StreamController<RelojRealtimeTemplateEvent>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  Stream<RelojRealtimePunchEvent> get punches => _punchController.stream;
  Stream<RelojRealtimeTemplateEvent> get templateUpdates =>
      _templateController.stream;
  Stream<bool> get connected => _connectedController.stream;

  void connect() {
    if (_socket.connected) return;
    _socket.connect();
  }

  void dispose() {
    _socket.dispose();
    _punchController.close();
    _templateController.close();
    _connectedController.close();
  }
}

String _resolveSocketBase(String rawBaseUrl) {
  final value = rawBaseUrl.trim();
  if (value.isEmpty) return 'http://localhost:3000';
  final uri = Uri.tryParse(value);
  if (uri == null) return 'http://localhost:3000';

  final host = uri.host.isEmpty ? 'localhost' : uri.host;
  final port = uri.hasPort ? ':${uri.port}' : '';
  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
  return '$scheme://$host$port';
}

