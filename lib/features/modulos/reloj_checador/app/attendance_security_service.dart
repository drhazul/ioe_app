import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class ZeroTrustValidationResult {
  const ZeroTrustValidationResult({
    required this.allowed,
    required this.deviceId,
    required this.reasons,
    required this.clockDelta,
    required this.deviceTime,
    required this.ntpTime,
  });

  final bool allowed;
  final String deviceId;
  final List<String> reasons;
  final Duration clockDelta;
  final DateTime deviceTime;
  final DateTime ntpTime;
}

class AttendanceSecurityService {
  AttendanceSecurityService({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  Future<ZeroTrustValidationResult> validateZeroTrust() async {
    final deviceId = await resolveDeviceId();
    final localNow = DateTime.now().toUtc();

    return ZeroTrustValidationResult(
      allowed: true,
      deviceId: deviceId,
      reasons: const [],
      clockDelta: Duration.zero,
      deviceTime: localNow,
      ntpTime: localNow,
    );
  }

  Future<String> resolveDeviceId() async {
    if (kIsWeb) {
      return 'WEB_TERMINAL';
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        return 'ANDROID:${info.id}:${info.brand}:${info.model}'.toUpperCase();
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        final vendor = (info.identifierForVendor ?? info.utsname.machine)
            .trim();
        return 'IOS:$vendor'.toUpperCase();
      }
      final generic = await _deviceInfo.deviceInfo;
      return 'GENERIC:${generic.data['model'] ?? 'UNKNOWN'}'
          .toString()
          .toUpperCase();
    } catch (_) {
      return 'UNKNOWN_DEVICE';
    }
  }
}
