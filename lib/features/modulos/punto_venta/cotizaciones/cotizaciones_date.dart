/// SQL process dates are Mexico local times. The API serializes Date values
/// as UTC instants; display them in the operator's local timezone like payment.
String formatCotizacionDate(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$d/$m/$y';
}
