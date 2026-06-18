import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_api.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_models.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/pago/pago_cotizacion_providers.dart';

class _FakePagoCotizacionApi extends PagoCotizacionApi {
  _FakePagoCotizacionApi({
    required this.previewResponse,
    required this.printPreviewResponse,
  }) : super(Dio());

  final PagoCierrePreviewResponse previewResponse;
  final PagoCierrePrintPreviewResponse printPreviewResponse;

  @override
  Future<PagoCierreContext> fetchContext(String idfol) async {
    return previewResponse.context;
  }

  @override
  Future<PagoCierrePreviewResponse> preview({
    required String idfol,
    required String tipotran,
    required bool rqfac,
    String? suc,
  }) async {
    return previewResponse;
  }

  @override
  Future<PagoCierrePrintPreviewResponse> fetchPrintPreview(String idfol) async {
    return printPreviewResponse;
  }

  @override
  Future<void> updateRqfac({
    required String idfol,
    required bool rqfac,
  }) async {}
}

void main() {
  test(
    'initialize rehydrates persisted forms when folio already pagado',
    () async {
      final previewResponse = PagoCierrePreviewResponse(
        ok: true,
        context: PagoCierreContext(
          idfol: 'DF10-20260618-VF-0001',
          suc: 'DF10',
          clien: 10460540001,
          esta: 'PAGADO',
          rqfacDefault: true,
          ivaIntegrado: 1,
          itemsCount: 3,
          totalBase: 220,
        ),
        totales: PagoCierreTotales(
          subtotal: 189.66,
          iva: 30.34,
          total: 220,
          totalBase: 220,
          ivaIntegrado: 1,
          tipotran: 'VF',
          rqfac: true,
        ),
      );

      final printPreviewResponse = PagoCierrePrintPreviewResponse(
        ok: true,
        idfol: 'DF10-20260618-VF-0001',
        header: PagoCierrePrintHeader(
          suc: 'DF10',
          desc: 'DF10 - XALAPA',
          encar: null,
          zona: null,
          rfc: null,
          direccion: null,
          contacto: null,
        ),
        items: const [],
        itemsGratis: const [],
        totals: PagoCierrePrintTotals(
          subtotal: 189.66,
          iva: 30.34,
          total: 220,
          totalBase: 220,
          ivaIntegrado: 1,
          tipotran: 'VF',
          rqfac: true,
          sumPagos: 220,
          faltante: 0,
          cambio: 0,
        ),
        formas: [
          PagoCierrePrintForma(
            idf: 'F-1',
            form: 'EFECTIVO',
            impp: 120,
            aut: null,
            fcn: DateTime.parse('2026-06-18T12:00:00.000Z'),
          ),
          PagoCierrePrintForma(
            idf: 'F-2',
            form: 'TARJETA',
            impp: 100,
            aut: 'REF-123',
            fcn: DateTime.parse('2026-06-18T12:00:01.000Z'),
          ),
        ],
        footer: PagoCierrePrintFooter(
          opv: 'opv',
          opvNombre: 'OPV PRUEBA',
          idfol: 'DF10-20260618-VF-0001',
          fcnm: DateTime.parse('2026-06-18T12:00:00.000Z'),
          clienteId: 10460540001,
          clienteNombre: 'CLIENTE PRUEBA',
        ),
        ords: const [],
      );

      final controller = PagoCotizacionController(
        _FakePagoCotizacionApi(
          previewResponse: previewResponse,
          printPreviewResponse: printPreviewResponse,
        ),
        idfol: 'DF10-20260618-VF-0001',
      );

      await controller.initialize(tipotran: 'VF', rqfac: false);

      expect(controller.state.initialized, isTrue);
      expect(controller.state.context?.esta, 'PAGADO');
      expect(controller.state.formas, hasLength(2));
      expect(controller.state.sumPagos, 220);
      expect(controller.state.totales?.total, 220);
      expect(controller.state.formas.first.form, 'EFECTIVO');
      expect(controller.state.formas.last.aut, 'REF-123');
    },
  );
}
