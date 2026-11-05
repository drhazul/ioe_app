/// Calendario comercial recibido de API: ISO sin zona. Nunca convertir con
/// toLocal(): la zona del dispositivo puede ser distinta de CDMX.
final class BusinessDateTime {
  const BusinessDateTime._(this.calendar);
  final DateTime calendar;

  static BusinessDateTime? tryParse(Object? raw) {
    if (raw == null) return null;
    final text = raw is DateTime
        ? raw.toIso8601String()
        : raw.toString().trim();
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,7}))?)?$',
    ).firstMatch(text);
    if (m == null) return null;
    final year = int.parse(m[1]!);
    final month = int.parse(m[2]!);
    final day = int.parse(m[3]!);
    final hour = int.parse(m[4] ?? '0');
    final minute = int.parse(m[5] ?? '0');
    final second = int.parse(m[6] ?? '0');
    final micro = int.parse((m[7] ?? '').padRight(6, '0').substring(0, 6));
    // UTC aquí es contenedor de componentes; no representa instante real.
    // Evita normalización por horario de verano de la máquina cliente.
    final value = DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
      micro ~/ 1000,
      micro % 1000,
    );
    if (value.year != year ||
        value.month != month ||
        value.day != day ||
        value.hour != hour ||
        value.minute != minute ||
        value.second != second) {
      return null;
    }
    return BusinessDateTime._(value);
  }

  String toApiString() =>
      calendar.toIso8601String().replaceFirst(RegExp(r'Z$'), '');
}

/// Timestamp de auditoría: zona explícita obligatoria, conservar instante UTC.
final class UtcInstant {
  const UtcInstant._(this.value);
  final DateTime value;
  static UtcInstant? tryParse(Object? raw) {
    if (raw == null) return null;
    final text = raw is DateTime
        ? raw.toIso8601String()
        : raw.toString().trim();
    if (!RegExp(
      r'(?:Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    final value = DateTime.tryParse(text);
    return value == null ? null : UtcInstant._(value.toUtc());
  }
}

DateTime? parseBusinessDateTime(Object? value) =>
    BusinessDateTime.tryParse(value)?.calendar;
String businessDateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

/// Presenta componentes comerciales; no convierte según zona del dispositivo.
String formatBusinessDate(DateTime? value) {
  if (value == null) return '-';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year.toString().padLeft(4, '0')}';
}

String formatBusinessDateTime(DateTime? value) {
  if (value == null) return '-';
  return '${formatBusinessDate(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String businessCalendarIso(DateTime value) =>
    '${businessDateOnly(value)}T'
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:'
    '${value.second.toString().padLeft(2, '0')}.${value.millisecond.toString().padLeft(3, '0')}';
