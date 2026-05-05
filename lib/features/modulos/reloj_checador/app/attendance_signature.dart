import 'dart:convert';

import 'package:crypto/crypto.dart';

// Canonical JSON serializer with deterministic key ordering.
String canonicalJson(Object? value) {
  final normalized = _canonicalize(value);
  return jsonEncode(normalized);
}

// HMAC SHA-256 signature: device_id + body + secret_key.
String buildAttendanceSignature({
  required String deviceId,
  required Map<String, dynamic> body,
  required String secret,
}) {
  final canonicalBody = canonicalJson(body);
  final payload = '$deviceId$canonicalBody';
  final digest = Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode(payload));
  return digest.toString();
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    final sorted = <String, Object?>{};
    for (final entry in entries) {
      sorted[entry.key.toString()] = _canonicalize(entry.value);
    }
    return sorted;
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
