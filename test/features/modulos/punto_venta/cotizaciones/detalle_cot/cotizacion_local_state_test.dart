import 'package:flutter_test/flutter_test.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/detalle_cot/cotizacion_local_state.dart';

void main() {
  test('suma contramovimientos relacionados en totales locales', () {
    final now = DateTime(2026, 6, 26);
    final state = CotizacionLocalState(
      idfol: 'DF01-20260626-CP-0001',
      loading: false,
      error: null,
      items: [
        CotizacionLocalItem(
          id: 'counter',
          idfol: 'DF01-20260626-CP-0001',
          des: 'FLAT TOP W 86 ADD +3.00',
          ctd: -1,
          pvta: 50,
          pvtat: -50,
          ticketRel: 'DF01133240102',
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        CotizacionLocalItem(
          id: 'lens',
          idfol: 'DF01-20260626-CP-0001',
          des: 'FLAT TOP W 86 ADD +3.00',
          ctd: 1,
          pvta: 50,
          pvtat: 50,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ],
    );

    expect(state.items.first.isRelatedCounterMovement, isTrue);
    expect(state.total, 0);
    expect(state.totalPiezas, 0);
  });
}
