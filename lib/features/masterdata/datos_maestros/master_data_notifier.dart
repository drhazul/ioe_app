import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/dio_provider.dart';

import '../../modulos/reloj_checador/app/reloj_checador_app_providers.dart';
import '../deptos/deptos_providers.dart';
import '../puestos/puestos_providers.dart';
import '../sucursales/sucursales_providers.dart';
import 'configuracion_maestra_api.dart';
import 'configuracion_maestra_models.dart';

class MasterDataState {
  const MasterDataState({
    required this.model,
    required this.loading,
    required this.saving,
    this.errorMessage,
  });

  final ConfiguracionMaestraModel model;
  final bool loading;
  final bool saving;
  final String? errorMessage;

  factory MasterDataState.initial() {
    return MasterDataState(
      model: ConfiguracionMaestraModel.empty(),
      loading: true,
      saving: false,
    );
  }

  MasterDataState copyWith({
    ConfiguracionMaestraModel? model,
    bool? loading,
    bool? saving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MasterDataState(
      model: model ?? this.model,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final configuracionMaestraApiProvider = Provider<ConfiguracionMaestraApi>(
  (ref) => ConfiguracionMaestraApi(ref.read(dioProvider)),
);

final masterDataNotifierProvider =
    StateNotifierProvider.autoDispose<MasterDataNotifier, MasterDataState>(
      (ref) => MasterDataNotifier(
        ref: ref,
        api: ref.read(configuracionMaestraApiProvider),
      )..load(),
    );

class MasterDataNotifier extends StateNotifier<MasterDataState> {
  MasterDataNotifier({required this.ref, required this.api})
    : super(MasterDataState.initial());

  final Ref ref;
  final ConfiguracionMaestraApi api;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final model = await api.fetchConfiguracionMaestra();
      state = state.copyWith(model: model, loading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'No se pudo cargar configuración: $e',
      );
    }
  }

  void setNombreEmpresa(String value) {
    state = state.copyWith(
      model: state.model.copyWith(nombreEmpresa: value.trim()),
      clearError: true,
    );
  }

  void setNitEmpresa(String value) {
    state = state.copyWith(
      model: state.model.copyWith(nitEmpresa: value.trim()),
      clearError: true,
    );
  }

  void setGpsObligatorio(bool value) {
    state = state.copyWith(
      model: state.model.copyWith(gpsObligatorio: value),
      clearError: true,
    );
  }

  void setLivenessObligatorio(bool value) {
    state = state.copyWith(
      model: state.model.copyWith(livenessObligatorio: value),
      clearError: true,
    );
  }

  void addDepartamento(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final exists = state.model.departamentos.any(
      (item) => item.toUpperCase() == text.toUpperCase(),
    );
    if (exists) return;
    final next = List<String>.from(state.model.departamentos)..add(text);
    state = state.copyWith(
      model: state.model.copyWith(departamentos: next),
      clearError: true,
    );
  }

  void removeDepartamento(String value) {
    final next = state.model.departamentos
        .where((item) => item.toUpperCase() != value.toUpperCase())
        .toList(growable: false);
    state = state.copyWith(
      model: state.model.copyWith(departamentos: next),
      clearError: true,
    );
  }

  void addCargo(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    final exists = state.model.cargos.any(
      (item) => item.toUpperCase() == text.toUpperCase(),
    );
    if (exists) return;
    final next = List<String>.from(state.model.cargos)..add(text);
    state = state.copyWith(
      model: state.model.copyWith(cargos: next),
      clearError: true,
    );
  }

  void removeCargo(String value) {
    final next = state.model.cargos
        .where((item) => item.toUpperCase() != value.toUpperCase())
        .toList(growable: false);
    state = state.copyWith(
      model: state.model.copyWith(cargos: next),
      clearError: true,
    );
  }

  Future<bool> saveAll() async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      final saved = await api.saveConfiguracionMaestra(state.model);
      state = state.copyWith(model: saved, saving: false, clearError: true);
      syncAll();
      return true;
    } catch (e) {
      state = state.copyWith(
        saving: false,
        errorMessage: 'No se pudo guardar configuración: $e',
      );
      return false;
    }
  }

  void syncAll() {
    ref.invalidate(colaboradoresLiveProvider);
    ref.invalidate(sucursalesCatalogProvider);
    ref.invalidate(relojChecadorContextProvider(null));
    ref.invalidate(asistenciaReporteProvider);
    ref.invalidate(reporteSolicitudesProvider);
    ref.invalidate(asistenciaReporteQueryProvider);

    ref.invalidate(sucursalesListProvider);
    ref.invalidate(sucursalesGestionListProvider);
    ref.invalidate(deptosListProvider);
    ref.invalidate(puestosListProvider);
  }
}
