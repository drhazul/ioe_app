import 'package:ioe_app/core/time/business_datetime.dart';

/// FCN comercial llega sin zona y conserva sus componentes CDMX.
String formatCotizacionDate(DateTime? value) => formatBusinessDate(value);
