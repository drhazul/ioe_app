import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/core/time/business_datetime.dart';
import 'package:ioe_app/features/modulos/mb51/mb51_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/new_ord/new_ord_models.dart';

void main() {
  test('ORD transmite fecha elegida sin convertir calendario a instante', () {
    final request = CreateOrdFromQuoteLineRequest(
      idfol: 'PRUEBA',
      ticketId: '1',
      art: '1',
      descArt: 'PRUEBA',
      ctd: 1,
      clien: 1,
      estado: 'PENDIENTE',
      tipo: 'TALLADO',
      suc: 'TEST',
      opv: 'TEST',
      fechaEntrega: DateTime.utc(2026, 11, 4),
    );
    expect(request.toJson()['fechaEntrega'], '2026-11-04T00:00:00.000');
  });
  test('fecha comercial conserva calendario y hora sin zona del equipo', () {
    final date = BusinessDateTime.tryParse('2026-11-04T12:39:38.623')!;
    expect(
      [
        date.calendar.year,
        date.calendar.month,
        date.calendar.day,
        date.calendar.hour,
      ],
      [2026, 11, 4, 12],
    );
    expect(date.toApiString(), '2026-11-04T12:39:38.623');
    expect(businessCalendarIso(date.calendar), '2026-11-04T12:39:38.623');
  });
  test(
    'instante UTC exige contrato distinto; no borrar Z para ocultar error',
    () {
      expect(BusinessDateTime.tryParse('2026-11-05T00:39:38.623Z'), isNull);
      expect(UtcInstant.tryParse('2026-11-04T18:39:38.623'), isNull);
      expect(
        UtcInstant.tryParse(
          '2026-11-04T12:39:38.623-06:00',
        )!.value.toIso8601String(),
        '2026-11-04T18:39:38.623Z',
      );
    },
  );
  test('rechaza días inexistentes; conserva fin de mes y año', () {
    expect(BusinessDateTime.tryParse('2026-02-30'), isNull);
    expect(
      businessDateOnly(parseBusinessDateTime('2026-12-31T23:59:59.997')!),
      '2026-12-31',
    );
    expect(
      businessDateOnly(parseBusinessDateTime('2027-01-01T00:00:00')!),
      '2027-01-01',
    );
  });
  test('filtros MB51 envían calendario, sin UTC ni hora de dispositivo', () {
    final query = Mb51Filtros(
      fechaContDesde: DateTime(2026, 10, 31),
      fechaContHasta: DateTime(2026, 11, 4),
    );
    expect(query.toApiJson(), {
      'fechaContDesde': '2026-10-31',
      'fechaContHasta': '2026-11-04',
    });
  });
}
