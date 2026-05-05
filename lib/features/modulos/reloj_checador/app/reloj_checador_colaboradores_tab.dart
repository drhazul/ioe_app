import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';

enum _ColabAction {
  editar,
  resetPin,
  eliminarLogica,
  resetBiometria,
  regenerarQr,
  enrolarHuella,
  enrolarRostro,
  credencialQr,
  documentos,
}

class RelojChecadorColaboradoresTab extends ConsumerStatefulWidget {
  const RelojChecadorColaboradoresTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  ConsumerState<RelojChecadorColaboradoresTab> createState() =>
      _RelojChecadorColaboradoresTabState();
}

class _RelojChecadorColaboradoresTabState
    extends ConsumerState<RelojChecadorColaboradoresTab> {
  bool _busy = false;
  bool _manualRefreshing = false;
  List<ColaboradorGestionModel>? _colaboradoresCache;
  static const List<String> _departamentos = <String>[
    'Operaciones',
    'Taller',
    'Sistemas',
    'Cajas',
    'Inventarios',
    'Limpieza',
    'RRHH',
    'Finanzas',
  ];
  static const Map<String, List<String>> _cargosPorDepartamento =
      <String, List<String>>{
        'Operaciones': <String>[
          'Jefe de Operaciones',
          'Gerente Sucursal',
          'Auxiliar Inventarios',
          'Supervisor Caja',
        ],
        'Taller': <String>[
          'Jefe de Taller',
          'Analista',
          'Auxiliar',
          'Encargado Maquila',
          'Optometrista',
        ],
        'Sistemas': <String>[
          'Encargado Desarrollo',
          'Encargado TI',
          'Auxiliar Sistemas',
        ],
        'Cajas': <String>['Supervisor Caja', 'Auxiliar'],
        'Inventarios': <String>['Auxiliar Inventarios', 'Auxiliar'],
        'Limpieza': <String>['Auxiliar'],
        'RRHH': <String>['Director General', 'Director Ejecutivo'],
        'Finanzas': <String>['Director Ejecutivo', 'Analista'],
      };

  List<String> _cargosDe(String departamento) =>
      _cargosPorDepartamento[departamento] ?? const <String>[];

  bool _expedienteBasicoOk(ColaboradorGestionModel row) {
    return row.nombreCompleto.trim().isNotEmpty &&
        row.sucursalId > 0 &&
        (row.horarioId ?? 0) > 0;
  }

  bool _expedienteCompleto(ColaboradorGestionModel row) {
    if (!_expedienteBasicoOk(row)) return false;
    return row.documentacionCompleta && row.hasFace && row.hasFingerprint;
  }

  String _expedienteLabel(ColaboradorGestionModel row) {
    if (!_expedienteBasicoOk(row)) return 'Incompleto';
    if (_expedienteCompleto(row)) return 'Completo';
    return 'Parcial';
  }

  Color _expedienteColor(ColaboradorGestionModel row) {
    final label = _expedienteLabel(row);
    if (label == 'Completo') return const Color(0xFF2E7D32);
    if (label == 'Parcial') return const Color(0xFFFFB300);
    return const Color(0xFFF57C00);
  }

  IconData _expedienteIcon(ColaboradorGestionModel row) {
    return _expedienteLabel(row) == 'Completo'
        ? Icons.verified
        : Icons.warning_amber_rounded;
  }

  final Random _rng = Random();

  String _generateRandomPin4() =>
      _rng.nextInt(10000).toString().padLeft(4, '0');

  String _resolveRol({required int privilegio, required bool esAdminReloj}) {
    return (esAdminReloj || privilegio == 14) ? 'ADMIN' : 'TRABAJADOR';
  }

  bool _isExpedienteAutoCompleto({
    required String nombre,
    required String matricula,
    required String pin,
    required int? sucursalId,
  }) {
    return nombre.trim().isNotEmpty &&
        matricula.trim().isNotEmpty &&
        pin.trim().isNotEmpty &&
        (sucursalId ?? 0) > 0;
  }

  String _sanitizeMatricula(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '').trim();
  }

  bool _looksLikeHashedPin(String value) {
    final text = value.trim();
    return text.length > 20 || text.startsWith(r'$2');
  }

  bool _isMatriculaDuplicada({
    required String matricula,
    int? excludeColaboradorId,
  }) {
    final target = matricula.trim().toUpperCase();
    if (target.isEmpty) return false;
    final rows =
        _colaboradoresCache ??
        ref.read(colaboradoresLiveProvider).valueOrNull ??
        const <ColaboradorGestionModel>[];
    return rows.any((row) {
      if (excludeColaboradorId != null && row.id == excludeColaboradorId) {
        return false;
      }
      return row.idEmpleado.trim().toUpperCase() == target;
    });
  }

  void _postFrameSnack(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _safePop(BuildContext targetContext, [Object? result]) {
    if (!mounted) return;
    if (!context.mounted || !targetContext.mounted) return;
    final navigator = Navigator.of(targetContext, rootNavigator: true);
    if (!navigator.mounted) return;
    navigator.pop(result);
  }

  bool _isValidRfc(String value) {
    if (value.isEmpty) return true;
    return RegExp(r'^[A-Z0-9]{1,13}$').hasMatch(value.toUpperCase());
  }

  bool _isValidCurp(String value) {
    if (value.isEmpty) return true;
    return RegExp(r'^[A-Z0-9]{1,18}$').hasMatch(value.toUpperCase());
  }

  bool _isValidNss(String value) {
    if (value.isEmpty) return true;
    return RegExp(r'^\d{11}$').hasMatch(value);
  }

  Future<void> _refreshColaboradoresInBackground() async {
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final fresh = await api.getColaboradores();
      final filtrados = fresh
          .where((e) => ((e.estado as bool?) ?? false) == true)
          .toList(growable: false);
      debugPrint('RAW: ${fresh.length}');
      debugPrint('FILTRADOS: ${filtrados.length}');
      if (!mounted) return;
      setState(() {
        _colaboradoresCache = List<ColaboradorGestionModel>.unmodifiable(
          filtrados,
        );
      });
    } catch (_) {
      // actualización silenciosa: no interrumpir UI
    } finally {
      if (mounted) {
        setState(() => _manualRefreshing = false);
      }
      ref.invalidate(colaboradoresLiveProvider);
    }
  }

  Widget _buildFilterBar(WidgetRef ref) {
    final sucursalesAsync = ref.watch(sucursalesCatalogProvider);
    final sucursales = sucursalesAsync.valueOrNull ?? const [];
    final selectedSucursalId = ref.watch(colabFilterSucursalIdProvider);
    final selectedDepto = ref.watch(colabFilterDepartamentoProvider);
    final selectedCargo = ref.watch(colabFilterCargoProvider);
    final searchText = ref.watch(colabFilterSearchProvider);

    final deptosAsync = ref.watch(colabDepartamentosOptionsProvider);
    final deptos = deptosAsync.valueOrNull ?? const [];

    final cargosAsync = ref.watch(colabCargosOptionsProvider(selectedDepto));
    final cargos = cargosAsync.valueOrNull ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return isWide
            ? Row(
                children: _buildFilterChildren(
                  context, ref, sucursales,
                  selectedSucursalId, selectedDepto, selectedCargo, searchText,
                  deptos, cargos,
                ),
              )
            : Column(
                children: _buildFilterChildren(
                  context, ref, sucursales,
                  selectedSucursalId, selectedDepto, selectedCargo, searchText,
                  deptos, cargos,
                ),
              );
      },
    );
  }

  List<Widget> _buildFilterChildren(
    BuildContext context, WidgetRef ref,
    List<SucursalOptionModel> sucursales,
    int? selectedSucursalId,
    String? selectedDepto,
    String? selectedCargo,
    String searchText,
    List<Map<String, dynamic>> deptos,
    List<Map<String, dynamic>> cargos,
  ) {
    return [
      Expanded(
        child: _filterDropdown<int?>(
          value: selectedSucursalId,
          hint: 'Todas las sucursales',
          items: sucursales,
          labelBuilder: (s) => '${s.codigo} - ${s.nombre}',
          valueBuilder: (s) => s.id,
          onChanged: (v) => ref.read(colabFilterSucursalIdProvider.notifier).state = v,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _filterDropdown<String?>(
          value: selectedDepto,
          hint: 'Todos los departamentos',
          items: deptos,
          labelBuilder: (d) => (d as Map<String, dynamic>)['NOMBRE'] as String? ?? '',
          valueBuilder: (d) => (d as Map<String, dynamic>)['NOMBRE'] as String? ?? '',
          onChanged: (v) {
            ref.read(colabFilterDepartamentoProvider.notifier).state = v;
            ref.read(colabFilterCargoProvider.notifier).state = null;
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _filterDropdown<String?>(
          value: selectedCargo,
          hint: 'Todos los cargos',
          items: cargos,
          labelBuilder: (c) => (c as Map<String, dynamic>)['NOMBRE'] as String? ?? '',
          valueBuilder: (c) => (c as Map<String, dynamic>)['NOMBRE'] as String? ?? '',
          onChanged: (v) => ref.read(colabFilterCargoProvider.notifier).state = v,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        height: 48,
        child: IconButton(
          onPressed: () {
            ref.read(colabFilterSucursalIdProvider.notifier).state = null;
            ref.read(colabFilterDepartamentoProvider.notifier).state = null;
            ref.read(colabFilterCargoProvider.notifier).state = null;
            ref.read(colabFilterSearchProvider.notifier).state = '';
          },
          icon: const Icon(Icons.clear_all),
          tooltip: 'Limpiar filtros',
          style: IconButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD4D8DF)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: TextEditingController.fromValue(
              TextEditingValue(text: searchText),
            ),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre completo...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => ref.read(colabFilterSearchProvider.notifier).state = v,
          ),
        ),
      ),
    ];
  }

  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required List<dynamic> items,
    required String Function(dynamic) labelBuilder,
    required dynamic Function(dynamic) valueBuilder,
    required void Function(T?) onChanged,
  }) {
    return SizedBox(
      height: 48,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: Text(hint, overflow: TextOverflow.ellipsis),
            items: [
              DropdownMenuItem<T>(
                value: null,
                child: Text(hint, overflow: TextOverflow.ellipsis),
              ),
              ...items.map((item) {
                final v = valueBuilder(item) as T;
                return DropdownMenuItem<T>(
                  value: v,
                  child: Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog({
    required List<SucursalOptionModel> sucursales,
    required List<HorarioModel> horarios,
  }) async {
    final matriculaCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: _generateRandomPin4());
    final nombreCtrl = TextEditingController();
    final apellidoCtrl = TextEditingController();
    final apellidoPaternoCtrl = TextEditingController();
    final apellidoMaternoCtrl = TextEditingController();
    final rfcCtrl = TextEditingController();
    final curpCtrl = TextEditingController();
    final nssCtrl = TextEditingController();
    final matriculaFocus = FocusNode();
    final pinFocus = FocusNode();
    final nombreFocus = FocusNode();
    final apellidoFocus = FocusNode();
    final rfcFocus = FocusNode();
    final curpFocus = FocusNode();
    final nssFocus = FocusNode();

    var selectedSuc = sucursales.isNotEmpty ? sucursales.first : null;
    final selectedExtraSucIds = <int>{};
    DateTime? vencimiento;
    var privilegio = 0;
    var estado = true;
    var appAccess = true;
    const gpsAllowed = false;
    const qrAllowed = false;
    const esAdminReloj = false;
    var jornadaTipo = 'DIURNA';
    var estatusContrato = 'PLANTA';
    var selectedDepartamento = _departamentos.first;
    var selectedCargo = _cargosDe(_departamentos.first).isNotEmpty
        ? _cargosDe(_departamentos.first).first
        : '';
    var localSaving = false;
    var loadingMatricula = false;
    var hidePin = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !localSaving,
        builder: (dialogContext) {
          return StatefulBuilder(
            key: UniqueKey(),
            builder: (dialogContext, setDialogState) {
              Future<void> loadMatriculaForSucursal(
                SucursalOptionModel? suc,
              ) async {
                if (suc == null || localSaving || loadingMatricula) return;
                setDialogState(() => loadingMatricula = true);
                try {
                  final api = ref.read(relojChecadorAppApiProvider);
                  final nextId = await api.getNextIdEmpleado(
                    sucursalCodigo: suc.codigo,
                  );
                  if (!dialogContext.mounted) return;
                  setDialogState(() => matriculaCtrl.text = nextId);
                } catch (_) {
                  // fallback silencioso, no bloquear alta
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() => loadingMatricula = false);
                  }
                }
              }

              if (matriculaCtrl.text.trim().isEmpty &&
                  selectedSuc != null &&
                  !loadingMatricula) {
                Future.microtask(() => loadMatriculaForSucursal(selectedSuc));
              }

              Future<void> pickVencimiento() async {
                final picked = await showDatePicker(
                  context: dialogContext,
                  initialDate: vencimiento ?? DateTime.now(),
                  firstDate: DateTime(2020, 1, 1),
                  lastDate: DateTime(2100, 12, 31),
                );
                if (picked != null) {
                  setDialogState(() => vencimiento = picked);
                }
              }

              if (selectedSuc != null &&
                  matriculaCtrl.text.trim().isEmpty &&
                  !loadingMatricula) {
                Future.microtask(() => loadMatriculaForSucursal(selectedSuc));
              }

              Future<void> pickSucursalesMultiples() async {
                final temp = Set<int>.from(selectedExtraSucIds);
                await showDialog<void>(
                  context: dialogContext,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setInnerState) {
                      return AlertDialog(
                        title: const Text('Asignar sucursales adicionales'),
                        content: SizedBox(
                          width: 360,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final suc in sucursales)
                                  CheckboxListTile(
                                    dense: true,
                                    value: temp.contains(suc.id),
                                    onChanged: (value) {
                                      if (value == true) {
                                        temp.add(suc.id);
                                      } else {
                                        temp.remove(suc.id);
                                      }
                                      setInnerState(() {});
                                    },
                                    title: Text(
                                      '${suc.codigo} - ${suc.nombre}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => _safePop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () {
                              _safePop(ctx);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  selectedExtraSucIds
                                    ..clear()
                                    ..addAll(temp);
                                });
                              });
                            },
                            child: const Text('Aplicar'),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text('Nuevo Colaborador'),
                content: SizedBox(
                  width: 540,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nombreCtrl,
                          focusNode: nombreFocus,
                          enabled: !localSaving,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            helperText: 'Máximo 50 caracteres para reportes',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLength: 50,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: apellidoCtrl,
                          focusNode: apellidoFocus,
                          enabled: !localSaving,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                            helperText: 'Máximo 50 caracteres para reportes',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLength: 50,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: apellidoPaternoCtrl,
                          enabled: !localSaving,
                          decoration: const InputDecoration(
                            labelText: 'Apellido Paterno',
                            helperText: 'Opcional',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLength: 50,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: apellidoMaternoCtrl,
                          enabled: !localSaving,
                          decoration: const InputDecoration(
                            labelText: 'Apellido Materno',
                            helperText: 'Opcional',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLength: 50,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: matriculaCtrl,
                          focusNode: matriculaFocus,
                          readOnly: true,
                          maxLength: 20,
                          decoration: InputDecoration(
                            labelText: 'ID (Matrícula)',
                            hintText: 'Generación automática por sucursal',
                            helperText:
                                'Máximo 20 caracteres (ID único del reloj)',
                            errorText:
                                _isMatriculaDuplicada(
                                  matricula: matriculaCtrl.text,
                                )
                                ? 'El ID (Matrícula) ya se encuentra registrado'
                                : null,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: loadingMatricula
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: pinCtrl,
                          focusNode: pinFocus,
                          enabled: !localSaving,
                          obscureText: hidePin,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'PIN (Contraseña)',
                            helperText:
                                'PIN protegido. Deja vacío para conservar; captura PIN numérico para cambiar.',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              onPressed: localSaving
                                  ? null
                                  : () => setDialogState(
                                      () => hidePin = !hidePin,
                                    ),
                              icon: Icon(
                                hidePin
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedDepartamento,
                          decoration: const InputDecoration(
                            labelText: 'Departamento',
                            helperText: 'Máximo 50 caracteres para reportes',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _departamentos
                              .map(
                                (d) => DropdownMenuItem<String>(
                                  value: d,
                                  child: Text(d),
                                ),
                              )
                              .toList(),
                          onChanged: localSaving
                              ? null
                              : (value) {
                                  final nextDept =
                                      value ?? _departamentos.first;
                                  final cargos = _cargosDe(nextDept);
                                  setDialogState(() {
                                    selectedDepartamento = nextDept;
                                    selectedCargo = cargos.isNotEmpty
                                        ? cargos.first
                                        : '';
                                  });
                                },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCargo.isEmpty
                              ? null
                              : selectedCargo,
                          decoration: const InputDecoration(
                            labelText: 'Cargo',
                            helperText: 'Máximo 50 caracteres para reportes',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _cargosDe(selectedDepartamento)
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: localSaving
                              ? null
                              : (value) => setDialogState(
                                  () => selectedCargo = value ?? '',
                                ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<SucursalOptionModel>(
                          initialValue: selectedSuc,
                          decoration: const InputDecoration(
                            labelText: 'Sucursal principal',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: sucursales
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('${s.codigo} - ${s.nombre}'),
                                ),
                              )
                              .toList(),
                          onChanged: localSaving
                              ? null
                              : (value) async {
                                  setDialogState(() => selectedSuc = value);
                                  await loadMatriculaForSucursal(value);
                                },
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: localSaving
                              ? null
                              : pickSucursalesMultiples,
                          icon: const Icon(Icons.account_tree),
                          label: Text(
                            selectedExtraSucIds.isEmpty
                                ? 'Asignar múltiples sucursales'
                                : '${selectedExtraSucIds.length} sucursales vinculadas',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: selectedExtraSucIds
                              .map(
                                (id) => sucursales
                                    .where((s) => s.id == id)
                                    .map(
                                      (s) => Chip(
                                        label: Text(s.codigo),
                                        onDeleted: localSaving
                                            ? null
                                            : () => setDialogState(
                                                () => selectedExtraSucIds
                                                    .remove(id),
                                              ),
                                      ),
                                    )
                                    .first,
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: localSaving ? null : pickVencimiento,
                          icon: const Icon(Icons.event),
                          label: Text(
                            vencimiento == null
                                ? 'Vencimiento contrato'
                                : 'Vence: ${_dateIso(vencimiento!)}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: privilegio,
                          decoration: const InputDecoration(
                            labelText: 'Privilegio',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Normal')),
                            DropdownMenuItem(value: 14, child: Text('Admin')),
                          ],
                          onChanged: localSaving
                              ? null
                              : (value) => setDialogState(
                                  () => privilegio = value ?? 0,
                                ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: jornadaTipo,
                          decoration: const InputDecoration(
                            labelText: 'Jornada LFT',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'DIURNA',
                              child: Text('DIURNA (8h)'),
                            ),
                            DropdownMenuItem(
                              value: 'NOCTURNA',
                              child: Text('NOCTURNA (7h)'),
                            ),
                            DropdownMenuItem(
                              value: 'MIXTA',
                              child: Text('MIXTA (7.5h)'),
                            ),
                          ],
                          onChanged: localSaving
                              ? null
                              : (value) => setDialogState(
                                  () => jornadaTipo = value ?? 'DIURNA',
                                ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: estatusContrato,
                          decoration: const InputDecoration(
                            labelText: 'Estatus Contrato',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'PRUEBA_30',
                              child: Text('PRUEBA_30'),
                            ),
                            DropdownMenuItem(
                              value: 'PRUEBA_90',
                              child: Text('PRUEBA_90'),
                            ),
                            DropdownMenuItem(
                              value: 'PLANTA',
                              child: Text('PLANTA'),
                            ),
                            DropdownMenuItem(
                              value: 'BAJA',
                              child: Text('BAJA'),
                            ),
                          ],
                          onChanged: localSaving
                              ? null
                              : (value) => setDialogState(
                                  () => estatusContrato = value ?? 'PLANTA',
                                ),
                        ),
                        SwitchListTile(
                          value: estado,
                          onChanged: localSaving
                              ? null
                              : (value) => setDialogState(() => estado = value),
                          title: const Text('Activo'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          value: appAccess,
                          onChanged: localSaving
                              ? null
                              : (value) =>
                                    setDialogState(() => appAccess = value),
                          title: const Text('Acceso App'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Datos Adicionales (Opcional)'),
                          children: [
                            TextFormField(
                              controller: rfcCtrl,
                              focusNode: rfcFocus,
                              enabled: !localSaving,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 13,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'RFC (opcional)',
                                helperText: 'Formato oficial (13 caracteres)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText:
                                    _isValidRfc(
                                      rfcCtrl.text.trim().toUpperCase(),
                                    )
                                    ? null
                                    : 'RFC inválido: solo letras/números, máx 13',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: curpCtrl,
                              focusNode: curpFocus,
                              enabled: !localSaving,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 18,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]'),
                                ),
                              ],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'CURP (opcional)',
                                helperText: 'Formato oficial (18 caracteres)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText:
                                    _isValidCurp(
                                      curpCtrl.text.trim().toUpperCase(),
                                    )
                                    ? null
                                    : 'CURP inválido: solo letras/números, máx 18',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: nssCtrl,
                              focusNode: nssFocus,
                              enabled: !localSaving,
                              keyboardType: TextInputType.number,
                              maxLength: 11,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'NSS (opcional)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: _isValidNss(nssCtrl.text.trim())
                                    ? null
                                    : 'NSS inválido: 11 dígitos',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localSaving
                        ? null
                        : () => _safePop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        localSaving ||
                            _isMatriculaDuplicada(matricula: matriculaCtrl.text)
                        ? null
                        : () async {
                            final matricula = _sanitizeMatricula(
                              matriculaCtrl.text,
                            );
                            final pinInput = pinCtrl.text.trim();
                            final nombre = nombreCtrl.text.trim();
                            final apellido = apellidoCtrl.text.trim();
                            final apellidoPaterno = apellidoPaternoCtrl.text.trim();
                            final apellidoMaterno = apellidoMaternoCtrl.text.trim();
                            final rfc = rfcCtrl.text.trim().toUpperCase();
                            final curp = curpCtrl.text.trim().toUpperCase();
                            final nss = nssCtrl.text.trim();
                            if (!_isValidRfc(rfc)) {
                              _postFrameSnack(
                                'RFC inválido: solo letras/números, máximo 13',
                              );
                              return;
                            }
                            if (!_isValidCurp(curp)) {
                              _postFrameSnack(
                                'CURP inválido: solo letras/números, máximo 18',
                              );
                              return;
                            }
                            if (!_isValidNss(nss)) {
                              _postFrameSnack(
                                'NSS inválido: debe tener 11 dígitos',
                              );
                              return;
                            }
                            if (matricula.isEmpty ||
                                nombre.isEmpty ||
                                apellido.isEmpty) {
                              _postFrameSnack(
                                'Nombre, apellido, matrícula e ID son requeridos',
                              );
                              return;
                            }
                            if (_isMatriculaDuplicada(matricula: matricula)) {
                              _postFrameSnack(
                                'El ID (Matrícula) ya se encuentra registrado.',
                              );
                              return;
                            }
                            final sucursalEffective =
                                selectedSuc ??
                                (sucursales.isNotEmpty
                                    ? sucursales.first
                                    : null);
                            if (sucursalEffective == null) {
                              _postFrameSnack('No hay sucursal disponible');
                              return;
                            }
                            final departamentoEffective =
                                selectedDepartamento.trim().isEmpty
                                ? _departamentos.first
                                : selectedDepartamento.trim();
                            final cargoEffective = selectedCargo.trim().isEmpty
                                ? 'General'
                                : selectedCargo.trim();
                            if (pinInput.isEmpty) {
                              _postFrameSnack('PIN requerido');
                              return;
                            }
                            final pinIsValid = RegExp(
                              r'^\d+$',
                            ).hasMatch(pinInput);
                            if (!pinIsValid) {
                              _postFrameSnack('PIN inválido: usa solo números');
                              return;
                            }
                            final pin = pinInput.trim();
                            setDialogState(() => localSaving = true);
                            setState(() => _busy = true);
                            try {
                              final api = ref.read(relojChecadorAppApiProvider);
                              final allSucursales = <int>{
                                sucursalEffective.id,
                                ...selectedExtraSucIds,
                              }.toList();
                              final idEmpleadoToSave = matricula;
                              final hasRfcCurp =
                                  rfc.isNotEmpty && curp.isNotEmpty;
                              final autoExpediente =
                                  _isExpedienteAutoCompleto(
                                    nombre: '$nombre $apellido',
                                    matricula: idEmpleadoToSave,
                                    pin: pin,
                                    sucursalId: sucursalEffective.id,
                                  ) &&
                                  hasRfcCurp;

                              final created = await api.createColaborador(
                                ColaboradorCreateRequest(
                                  idEmpleado: idEmpleadoToSave,
                                  pin: pin,
                                  nombre: nombre,
                                  apellido: apellido,
                                  apellidoPaterno: apellidoPaterno,
                                  apellidoMaterno: apellidoMaterno,
                                  sucursalId: sucursalEffective.id,
                                  sucursalesIds: allSucursales,
                                  departamento: departamentoEffective,
                                  cargo: cargoEffective,
                                  tipoContrato: 'PLANTA',
                                  estatusColaborador: 'Activo',
                                  privilegio: privilegio,
                                  estado: estado,
                                  appAccess: appAccess,
                                  gpsAllowed: gpsAllowed,
                                  qrAllowed: qrAllowed,
                                  rfc: rfc.isEmpty ? null : rfc,
                                  curp: curp.isEmpty ? null : curp,
                                  nss: nss.isEmpty ? null : nss,
                                  jornadaTipo: jornadaTipo,
                                  estatusContrato: estatusContrato,
                                  documentacionCompleta: autoExpediente,
                                  horarioId: 1,
                                  vencimientoContrato: vencimiento == null
                                      ? null
                                      : _dateIso(vencimiento!),
                                  esAdminDispositivo: esAdminReloj,
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  final current = List<ColaboradorGestionModel>.from(
                                    _colaboradoresCache ?? const <ColaboradorGestionModel>[],
                                  );
                                  current.removeWhere((e) => e.id == created.id);
                                  current.add(created);
                                  current.sort(
                                    (a, b) => a.nombre
                                        .toLowerCase()
                                        .compareTo(b.nombre.toLowerCase()),
                                  );
                                  _colaboradoresCache =
                                      List<ColaboradorGestionModel>.unmodifiable(current);
                                });
                              }
                              if (!mounted ||
                                  !context.mounted ||
                                  !dialogContext.mounted) {
                                return;
                              }
                              ref.invalidate(colaboradoresLiveProvider);
                              ref.invalidate(sucursalesCatalogProvider);
                              ref.invalidate(
                                relojChecadorContextProvider(null),
                              );
                              ref.invalidate(horariosCatalogProvider);
                              ref.invalidate(asistenciaReporteProvider);
                              ref.invalidate(solicitudesIncidenciasProvider);
                              ref.invalidate(ausenciasCalendarioProvider);
                              ref.invalidate(reporteSolicitudesProvider);

                              await _refreshColaboradoresInBackground();
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                _safePop(dialogContext);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Colaborador creado. Matrícula: $matricula',
                                      ),
                                    ),
                                  );
                                });
                              }
                            } on DioException catch (e) {
                              final code = e.response?.statusCode ?? 0;
                              final falseNegative = code == 500 || code == 409;
                              if (falseNegative) {
                                ref.invalidate(colaboradoresLiveProvider);
                                ref.invalidate(sucursalesCatalogProvider);
                                ref.invalidate(
                                  relojChecadorContextProvider(null),
                                );
                                ref.invalidate(horariosCatalogProvider);
                                ref.invalidate(asistenciaReporteProvider);
                                ref.invalidate(solicitudesIncidenciasProvider);
                                ref.invalidate(ausenciasCalendarioProvider);
                                ref.invalidate(reporteSolicitudesProvider);
                                await _refreshColaboradoresInBackground();
                                if (mounted &&
                                    context.mounted &&
                                    dialogContext.mounted) {
                                  _safePop(dialogContext);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Aviso: Datos actualizados (con observaciones del servidor).',
                                        ),
                                      ),
                                    );
                                  });
                                }
                              } else if (mounted) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_friendlyDioMessage(e)),
                                    ),
                                  );
                                });
                              }
                            } catch (e) {
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                _safePop(dialogContext);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error técnico: $e'),
                                    ),
                                  );
                                });
                              }
                            } finally {
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                setDialogState(() => localSaving = false);
                              }
                              if (mounted) {
                                setState(() => _busy = false);
                              }
                            }
                          },
                    icon: localSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      matriculaCtrl.dispose();
      pinCtrl.dispose();
      nombreCtrl.dispose();
      apellidoCtrl.dispose();
      apellidoPaternoCtrl.dispose();
      apellidoMaternoCtrl.dispose();
      rfcCtrl.dispose();
      curpCtrl.dispose();
      nssCtrl.dispose();
      if (matriculaFocus.hasFocus) matriculaFocus.unfocus();
      if (pinFocus.hasFocus) pinFocus.unfocus();
      if (nombreFocus.hasFocus) nombreFocus.unfocus();
      if (apellidoFocus.hasFocus) apellidoFocus.unfocus();
      if (rfcFocus.hasFocus) rfcFocus.unfocus();
      if (curpFocus.hasFocus) curpFocus.unfocus();
      if (nssFocus.hasFocus) nssFocus.unfocus();
      matriculaFocus.dispose();
      pinFocus.dispose();
      nombreFocus.dispose();
      apellidoFocus.dispose();
      rfcFocus.dispose();
      curpFocus.dispose();
      nssFocus.dispose();
    }
  }

  Future<void> _runAction(
    ColaboradorGestionModel row,
    _ColabAction action,
  ) async {
    if (widget.readOnly &&
        action != _ColabAction.credencialQr &&
        action != _ColabAction.documentos) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil supervisor: solo lectura en colaboradores'),
        ),
      );
      return;
    }

    if (action == _ColabAction.editar) {
      final sucursales =
          ref.read(sucursalesCatalogProvider).valueOrNull ?? const [];
      final horarios =
          ref.read(horariosCatalogProvider).valueOrNull ?? const [];
      if (sucursales.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay sucursales para editar colaborador'),
          ),
        );
        return;
      }
      await _showEditDialog(
        row: row,
        sucursales: sucursales,
        horarios: horarios,
      );
      return;
    }
    if (action == _ColabAction.resetPin) {
      await _showResetPinDialog(row);
      return;
    }
    if (action == _ColabAction.eliminarLogica) {
      await _deleteColaborador(row, hard: true);
      return;
    }
    if (action == _ColabAction.resetBiometria) {
      await _resetBiometria(row);
      return;
    }
    if (action == _ColabAction.regenerarQr ||
        action == _ColabAction.credencialQr) {
      await _showQrCredential(row);
      return;
    }
    if (action == _ColabAction.documentos) {
      await _showDocumentosDialog(row);
      return;
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      late final String tipo;
      late final String successText;
      if (action == _ColabAction.enrolarHuella) {
        tipo = 'FP';
        successText = 'Solicitud de huella enviada';
      } else {
        tipo = 'FACE';
        successText = 'Solicitud de rostro enviada';
      }
      await api.solicitarEnrolamiento(row.id, tipo: tipo);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$successText (${row.pin})')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDioMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo enviar comando: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showEditDialog({
    required ColaboradorGestionModel row,
    required List<SucursalOptionModel> sucursales,
    required List<HorarioModel> horarios,
  }) async {
    final matriculaCtrl = TextEditingController(text: row.idEmpleado);
    final oldPin = row.pin.trim();
    final oldMatriculaOriginal = row.idEmpleado.trim();
    final pinCtrl = TextEditingController(
      text: _looksLikeHashedPin(oldPin) ? '••••' : oldPin,
    );
    final nombreCtrl = TextEditingController(text: row.nombre);
    final apellidoCtrl = TextEditingController(text: row.apellido);
    final apellidoPaternoCtrl = TextEditingController(text: row.apellidoPaterno);
    final apellidoMaternoCtrl = TextEditingController(text: row.apellidoMaterno);
    final rfcCtrl = TextEditingController(text: row.rfc ?? '');
    final curpCtrl = TextEditingController(text: row.curp ?? '');
    final nssCtrl = TextEditingController(text: row.nss ?? '');
    final matriculaFocus = FocusNode();
    final pinFocus = FocusNode();
    final nombreFocus = FocusNode();
    final apellidoFocus = FocusNode();
    final rfcFocus = FocusNode();
    final curpFocus = FocusNode();
    final nssFocus = FocusNode();

    var localSaving = false;
    SucursalOptionModel? selectedSuc;
    for (final item in sucursales) {
      if (item.id == row.sucursalId) {
        selectedSuc = item;
        break;
      }
    }
    selectedSuc ??= sucursales.first;
    final selectedExtraSucIds = <int>{
      for (final id in row.sucursalesIds)
        if (id != row.sucursalId) id,
    };
    HorarioModel? selectedHorario;
    for (final item in horarios) {
      if (item.id == row.horarioId) {
        selectedHorario = item;
        break;
      }
    }
    var privilegio = row.privilegio;
    var estado = row.estado;
    var appAccess = row.appAccess;
    var gpsAllowed = row.gpsAllowed;
    var qrAllowed = row.qrAllowed;
    var esAdminReloj = row.esAdminDispositivo;
    var jornadaTipo = row.jornadaTipo.trim().isEmpty
        ? 'DIURNA'
        : row.jornadaTipo.trim().toUpperCase();
    var estatusContrato = row.estatusContrato.trim().isEmpty
        ? 'PLANTA'
        : row.estatusContrato.trim().toUpperCase();
    DateTime? vencimiento = row.vencimientoContrato;
    var selectedDepartamento = row.departamento.trim().isEmpty
        ? _departamentos.first
        : row.departamento.trim();
    if (!_departamentos.contains(selectedDepartamento)) {
      selectedDepartamento = _departamentos.first;
    }
    final cargosIniciales = _cargosDe(selectedDepartamento);
    var selectedCargo = row.cargo.trim();
    if (selectedCargo.isEmpty) {
      selectedCargo = cargosIniciales.isNotEmpty ? cargosIniciales.first : '';
    } else if (cargosIniciales.isNotEmpty &&
        !cargosIniciales.contains(selectedCargo)) {
      selectedCargo = cargosIniciales.first;
    }
    var showDatosAdicionales = false;
    var hidePin = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            key: UniqueKey(),
            builder: (dialogContext, setDialogState) {
              Future<void> pickVencimiento() async {
                final picked = await showDatePicker(
                  context: dialogContext,
                  initialDate: vencimiento ?? DateTime.now(),
                  firstDate: DateTime(2020, 1, 1),
                  lastDate: DateTime(2100, 12, 31),
                );
                if (picked != null) {
                  setDialogState(() => vencimiento = picked);
                }
              }

              Future<void> pickSucursalesMultiples() async {
                final temp = Set<int>.from(selectedExtraSucIds);
                await showDialog<void>(
                  context: dialogContext,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setInnerState) {
                      return AlertDialog(
                        title: const Text('Asignar sucursales adicionales'),
                        content: SizedBox(
                          width: 360,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final suc in sucursales)
                                  CheckboxListTile(
                                    dense: true,
                                    value: temp.contains(suc.id),
                                    onChanged: (value) {
                                      if (value == true) {
                                        temp.add(suc.id);
                                      } else {
                                        temp.remove(suc.id);
                                      }
                                      setInnerState(() {});
                                    },
                                    title: Text(
                                      '${suc.codigo} - ${suc.nombre}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => _safePop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () {
                              _safePop(ctx);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  selectedExtraSucIds
                                    ..clear()
                                    ..addAll(temp);
                                });
                              });
                            },
                            child: const Text('Aplicar'),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(
                  'Editar ${row.idEmpleado.isEmpty ? row.pin : row.idEmpleado}',
                ),
                content: SizedBox(
                  width: 540,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(dialogContext).size.height * 0.78,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nombreCtrl,
                            focusNode: nombreFocus,
                            enabled: !localSaving,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: apellidoCtrl,
                            focusNode: apellidoFocus,
                            enabled: !localSaving,
                            decoration: const InputDecoration(
                              labelText: 'Apellido',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: apellidoPaternoCtrl,
                            enabled: !localSaving,
                            decoration: const InputDecoration(
                              labelText: 'Apellido Paterno',
                              helperText: 'Opcional',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: apellidoMaternoCtrl,
                            enabled: !localSaving,
                            decoration: const InputDecoration(
                              labelText: 'Apellido Materno',
                              helperText: 'Opcional',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: matriculaCtrl,
                            focusNode: matriculaFocus,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'ID (Matrícula)',
                              errorText: null,
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: pinCtrl,
                            focusNode: pinFocus,
                            enabled: !localSaving,
                            readOnly: pinCtrl.text.trim() == '••••',
                            obscureText: hidePin,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'PIN (Contraseña)',
                              helperText: _looksLikeHashedPin(oldPin)
                                  ? 'PIN protegido. Deja vacío para conservar; captura PIN numérico para cambiar.'
                                  : 'PIN protegido. Deja vacío para conservar; captura PIN numérico para cambiar.',
                              hintText: _looksLikeHashedPin(oldPin)
                                  ? '••••'
                                  : null,
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 96,
                                minHeight: 40,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: localSaving
                                        ? null
                                        : () {
                                            setDialogState(
                                              () => hidePin = !hidePin,
                                            );
                                          },
                                    icon: Icon(
                                      hidePin
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Reset PIN',
                                    onPressed: localSaving
                                        ? null
                                        : () {
                                            final newPin =
                                                (Random().nextInt(9000) + 1000)
                                                    .toString();
                                            setDialogState(() {
                                              pinCtrl.text = newPin;
                                              hidePin = false;
                                            });
                                          },
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDepartamento,
                            decoration: const InputDecoration(
                              labelText: 'Departamento',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _departamentos
                                .map(
                                  (d) => DropdownMenuItem<String>(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: localSaving
                                ? null
                                : (value) {
                                    final nextDept =
                                        value ?? _departamentos.first;
                                    final cargos = _cargosDe(nextDept);
                                    setDialogState(() {
                                      selectedDepartamento = nextDept;
                                      selectedCargo = cargos.isNotEmpty
                                          ? cargos.first
                                          : '';
                                    });
                                  },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCargo.isEmpty
                                ? null
                                : selectedCargo,
                            decoration: const InputDecoration(
                              labelText: 'Cargo',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _cargosDe(selectedDepartamento)
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: localSaving
                                ? null
                                : (value) => setDialogState(
                                    () => selectedCargo = value ?? '',
                                  ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<SucursalOptionModel>(
                            initialValue: selectedSuc,
                            decoration: const InputDecoration(
                              labelText: 'Sucursal principal',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: sucursales
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('${s.codigo} - ${s.nombre}'),
                                  ),
                                )
                                .toList(),
                            onChanged: localSaving
                                ? null
                                : (value) {
                                    setDialogState(() => selectedSuc = value);
                                  },
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: localSaving
                                ? null
                                : pickSucursalesMultiples,
                            icon: const Icon(Icons.account_tree),
                            label: Text(
                              selectedExtraSucIds.isEmpty
                                  ? 'Asignar múltiples sucursales'
                                  : '${selectedExtraSucIds.length} sucursales vinculadas',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: selectedExtraSucIds
                                .map(
                                  (id) => sucursales
                                      .where((s) => s.id == id)
                                      .map(
                                        (s) => Chip(
                                          label: Text(s.codigo),
                                          onDeleted: localSaving
                                              ? null
                                              : () => setDialogState(
                                                  () => selectedExtraSucIds
                                                      .remove(id),
                                                ),
                                        ),
                                      )
                                      .first,
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: localSaving ? null : pickVencimiento,
                            icon: const Icon(Icons.event),
                            label: Text(
                              vencimiento == null
                                  ? 'Vencimiento de contrato'
                                  : 'Vence: ${_dateIso(vencimiento!)}',
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: privilegio,
                            decoration: const InputDecoration(
                              labelText: 'Privilegio',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Normal')),
                              DropdownMenuItem(value: 14, child: Text('Admin')),
                            ],
                            onChanged: localSaving
                                ? null
                                : (value) => setDialogState(
                                    () => privilegio = value ?? 0,
                                  ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: jornadaTipo,
                            decoration: const InputDecoration(
                              labelText: 'Jornada',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'DIURNA',
                                child: Text('DIURNA'),
                              ),
                              DropdownMenuItem(
                                value: 'NOCTURNA',
                                child: Text('NOCTURNA'),
                              ),
                              DropdownMenuItem(
                                value: 'MIXTA',
                                child: Text('MIXTA'),
                              ),
                            ],
                            onChanged: localSaving
                                ? null
                                : (value) => setDialogState(
                                    () => jornadaTipo = value ?? 'DIURNA',
                                  ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: estatusContrato,
                            decoration: const InputDecoration(
                              labelText: 'Estatus contrato',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'PRUEBA_30',
                                child: Text('PRUEBA_30'),
                              ),
                              DropdownMenuItem(
                                value: 'PRUEBA_90',
                                child: Text('PRUEBA_90'),
                              ),
                              DropdownMenuItem(
                                value: 'PLANTA',
                                child: Text('PLANTA'),
                              ),
                              DropdownMenuItem(
                                value: 'BAJA',
                                child: Text('BAJA'),
                              ),
                            ],
                            onChanged: localSaving
                                ? null
                                : (value) => setDialogState(
                                    () => estatusContrato = value ?? 'PLANTA',
                                  ),
                          ),
                          SwitchListTile(
                            value: estado,
                            onChanged: localSaving
                                ? null
                                : (value) =>
                                      setDialogState(() => estado = value),
                            title: const Text('Activo'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            value: appAccess,
                            onChanged: localSaving
                                ? null
                                : (value) =>
                                      setDialogState(() => appAccess = value),
                            title: const Text('Acceso App'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            initiallyExpanded: showDatosAdicionales,
                            onExpansionChanged: (value) {
                              setDialogState(
                                () => showDatosAdicionales = value,
                              );
                            },
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: const Text('Datos Adicionales (Opcional)'),
                            children: [
                              TextFormField(
                                controller: rfcCtrl,
                                focusNode: rfcFocus,
                                enabled: !localSaving,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 13,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9]'),
                                  ),
                                ],
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'RFC (opcional)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText:
                                      _isValidRfc(
                                        rfcCtrl.text.trim().toUpperCase(),
                                      )
                                      ? null
                                      : 'RFC inválido: solo letras/números, máx 13',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: curpCtrl,
                                focusNode: curpFocus,
                                enabled: !localSaving,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 18,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9]'),
                                  ),
                                ],
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'CURP (opcional)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText:
                                      _isValidCurp(
                                        curpCtrl.text.trim().toUpperCase(),
                                      )
                                      ? null
                                      : 'CURP inválido: solo letras/números, máx 18',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: nssCtrl,
                                focusNode: nssFocus,
                                enabled: !localSaving,
                                keyboardType: TextInputType.number,
                                maxLength: 11,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'NSS (opcional)',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  errorText: _isValidNss(nssCtrl.text.trim())
                                      ? null
                                      : 'NSS inválido: 11 dígitos',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localSaving
                        ? null
                        : () => _safePop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        localSaving ||
                            (matriculaCtrl.text.trim().toUpperCase() !=
                                    oldMatriculaOriginal.toUpperCase() &&
                                _isMatriculaDuplicada(
                                  matricula: matriculaCtrl.text,
                                  excludeColaboradorId: row.id,
                                ))
                        ? null
                        : () async {
                            if (selectedSuc == null) return;
                            final matricula = _sanitizeMatricula(
                              matriculaCtrl.text,
                            );
                            final pinInput = pinCtrl.text.trim();
                            final nombre = nombreCtrl.text.trim();
                            final apellido = apellidoCtrl.text.trim();
                            final apellidoPaterno = apellidoPaternoCtrl.text.trim();
                            final apellidoMaterno = apellidoMaternoCtrl.text.trim();
                            final rfc = rfcCtrl.text.trim().toUpperCase();
                            final curp = curpCtrl.text.trim().toUpperCase();
                            final nss = nssCtrl.text.trim();
                            if (!_isValidRfc(rfc)) {
                              _postFrameSnack(
                                'RFC inválido: solo letras/números, máximo 13',
                              );
                              return;
                            }
                            if (!_isValidCurp(curp)) {
                              _postFrameSnack(
                                'CURP inválido: solo letras/números, máximo 18',
                              );
                              return;
                            }
                            if (!_isValidNss(nss)) {
                              _postFrameSnack(
                                'NSS inválido: debe tener 11 dígitos',
                              );
                              return;
                            }
                            final selectedDepartamentoTrim =
                                selectedDepartamento.trim();
                            final selectedCargoTrim = selectedCargo.trim();
                            final oldMatricula = row.idEmpleado.trim();
                            final oldNombre = row.nombre.trim();
                            final oldApellido = row.apellido.trim();
                            final oldApellidoPaterno = row.apellidoPaterno.trim();
                            final oldApellidoMaterno = row.apellidoMaterno.trim();
                            final oldDepartamento = row.departamento.trim();
                            final oldCargo = row.cargo.trim();
                            if (nombre.isEmpty || apellido.isEmpty) {
                              _postFrameSnack('Nombre y apellido requeridos');
                              return;
                            }
                            if (matricula != oldMatricula &&
                                matricula.isEmpty) {
                              _postFrameSnack(
                                'Matrícula no puede quedar vacía si fue editada',
                              );
                              return;
                            }
                            if (matricula != oldMatricula &&
                                _isMatriculaDuplicada(
                                  matricula: matricula,
                                  excludeColaboradorId: row.id,
                                )) {
                              _postFrameSnack(
                                'El ID (Matrícula) ya se encuentra registrado.',
                              );
                              return;
                            }
                            final pinInputNormalized = pinInput.contains('•')
                                ? ''
                                : pinInput.trim();
                            if (pinInputNormalized.isNotEmpty &&
                                pinInputNormalized != oldPin) {
                              final pinIsValid = RegExp(
                                r'^\d+$',
                              ).hasMatch(pinInputNormalized);
                              if (!pinIsValid) {
                                _postFrameSnack(
                                  'PIN inválido: usa solo números',
                                );
                                return;
                              }
                            }
                            final autoExpediente = _isExpedienteAutoCompleto(
                              nombre: '$nombre $apellido',
                              matricula: matricula,
                              pin: pinInputNormalized.isEmpty
                                  ? oldPin
                                  : pinInputNormalized,
                              sucursalId: selectedSuc!.id,
                            );
                            final payload = <String, dynamic>{};
                            final nextMatricula = matricula.isEmpty
                                ? oldMatricula
                                : matricula;
                            if (nextMatricula != oldMatricula) {
                              payload['id_empleado'] = nextMatricula;
                            }
                            if (pinInputNormalized.isNotEmpty &&
                                pinInputNormalized != oldPin) {
                              payload['pin'] = pinInputNormalized.trim();
                            }
                            if (nombre != oldNombre) {
                              payload['nombre'] = nombre;
                            }
                            if (apellido != oldApellido) {
                              payload['apellido'] = apellido;
                            }
                            if (apellidoPaterno != oldApellidoPaterno) {
                              payload['apellido_paterno'] = apellidoPaterno;
                            }
                            if (apellidoMaterno != oldApellidoMaterno) {
                              payload['apellido_materno'] = apellidoMaterno;
                            }
                            if (selectedDepartamentoTrim != oldDepartamento) {
                              payload['departamento'] =
                                  selectedDepartamentoTrim;
                            }
                            if (selectedCargoTrim != oldCargo) {
                              payload['cargo'] = selectedCargoTrim;
                            }
                            if (selectedSuc!.id != row.sucursalId) {
                              payload['sucursal_id'] = selectedSuc!.id;
                            }
                            final nextHorarioId = selectedHorario?.id ?? 1;
                            if (nextHorarioId != row.horarioId) {
                              payload['horario_id'] = nextHorarioId;
                            }
                            if (privilegio != row.privilegio) {
                              payload['privilegio'] = privilegio;
                            }
                            final nextRol = _resolveRol(
                              privilegio: privilegio,
                              esAdminReloj: esAdminReloj,
                            );
                            final oldRol = _resolveRol(
                              privilegio: row.privilegio,
                              esAdminReloj: row.esAdminDispositivo,
                            );
                            if (nextRol != oldRol) {
                              payload['rol'] = nextRol;
                            }
                            if (estado != row.estado) {
                              payload['estado'] = estado;
                            }
                            if (appAccess != row.appAccess) {
                              payload['app_access'] = appAccess;
                            }
                            if (gpsAllowed != row.gpsAllowed) {
                              payload['gps_allowed'] = gpsAllowed;
                            }
                            if (qrAllowed != row.qrAllowed) {
                              payload['qr_allowed'] = qrAllowed;
                            }
                            if (jornadaTipo !=
                                row.jornadaTipo.trim().toUpperCase()) {
                              payload['jornada_tipo'] = jornadaTipo;
                            }
                            if (estatusContrato !=
                                row.estatusContrato.trim().toUpperCase()) {
                              payload['estatus_contrato'] = estatusContrato;
                            }
                            if (esAdminReloj != row.esAdminDispositivo) {
                              payload['es_admin_dispositivo'] = esAdminReloj;
                            }
                            final vencimientoIso = vencimiento == null
                                ? null
                                : _dateIso(vencimiento!);
                            final oldVencimientoIso =
                                row.vencimientoContrato == null
                                ? null
                                : _dateIso(row.vencimientoContrato!);
                            if (vencimientoIso != oldVencimientoIso) {
                              payload['vencimiento_contrato'] = vencimientoIso;
                            }

                            final oldRfc = (row.rfc ?? '').trim().toUpperCase();
                            if (rfc != oldRfc) {
                              if (rfc.isNotEmpty) payload['rfc'] = rfc;
                            }
                            final oldCurp = (row.curp ?? '')
                                .trim()
                                .toUpperCase();
                            if (curp != oldCurp) {
                              if (curp.isNotEmpty) payload['curp'] = curp;
                            }
                            final oldNss = (row.nss ?? '').trim();
                            if (nss != oldNss) {
                              if (nss.isNotEmpty) payload['nss'] = nss;
                            }
                            if (autoExpediente != row.documentacionCompleta) {
                              payload['documentacion_completa'] =
                                  autoExpediente;
                            }

                            final nextSucIds = <int>{
                              selectedSuc!.id,
                              ...selectedExtraSucIds,
                            }.toList()..sort();
                            final oldSucIds = <int>{
                              row.sucursalId,
                              ...row.sucursalesIds,
                            }.toList()..sort();
                            if (nextSucIds.length != oldSucIds.length ||
                                !nextSucIds.asMap().entries.every(
                                  (entry) =>
                                      entry.value == oldSucIds[entry.key],
                                )) {
                              payload['sucursales_ids'] = nextSucIds;
                            }

                            payload.removeWhere((key, value) {
                              if (value == null) return true;
                              if (value is String && value.trim().isEmpty) {
                                return true;
                              }
                              if (value is Iterable && value.isEmpty) {
                                return true;
                              }
                              return false;
                            });
                            if (payload.isEmpty) {
                              _postFrameSnack('Sin cambios para guardar');
                              return;
                            }

                            setDialogState(() => localSaving = true);
                            setState(() => _busy = true);
                            try {
                              final api = ref.read(relojChecadorAppApiProvider);
                              await api.updateColaborador(row.id, payload);
                              if (!mounted ||
                                  !context.mounted ||
                                  !dialogContext.mounted) {
                                return;
                              }
                              ref.invalidate(colaboradoresLiveProvider);
                              ref.invalidate(sucursalesCatalogProvider);
                              ref.invalidate(
                                relojChecadorContextProvider(null),
                              );
                              ref.invalidate(horariosCatalogProvider);
                              ref.invalidate(asistenciaReporteProvider);
                              ref.invalidate(solicitudesIncidenciasProvider);
                              ref.invalidate(ausenciasCalendarioProvider);
                              ref.invalidate(reporteSolicitudesProvider);
                              await _refreshColaboradoresInBackground();
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                _safePop(dialogContext);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Colaborador actualizado'),
                                    ),
                                  );
                                });
                              }
                            } on DioException catch (e) {
                              final code = e.response?.statusCode ?? 0;
                              final falseNegative = code == 500 || code == 409;
                              ref.invalidate(colaboradoresLiveProvider);
                              ref.invalidate(sucursalesCatalogProvider);
                              ref.invalidate(
                                relojChecadorContextProvider(null),
                              );
                              ref.invalidate(horariosCatalogProvider);
                              ref.invalidate(asistenciaReporteProvider);
                              ref.invalidate(solicitudesIncidenciasProvider);
                              ref.invalidate(ausenciasCalendarioProvider);
                              ref.invalidate(reporteSolicitudesProvider);
                              await _refreshColaboradoresInBackground();
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                _safePop(dialogContext);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        falseNegative
                                            ? 'Aviso: Datos actualizados (con observaciones del servidor).'
                                            : _friendlyDioMessage(e),
                                      ),
                                    ),
                                  );
                                });
                              }
                            } catch (e) {
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                _safePop(dialogContext);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error técnico: $e'),
                                    ),
                                  );
                                });
                              }
                            } finally {
                              if (mounted &&
                                  context.mounted &&
                                  dialogContext.mounted) {
                                setDialogState(() => localSaving = false);
                              }
                              if (mounted) {
                                setState(() => _busy = false);
                              }
                            }
                          },
                    icon: localSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Guardar cambios'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      matriculaCtrl.dispose();
      pinCtrl.dispose();
      nombreCtrl.dispose();
      apellidoCtrl.dispose();
      apellidoPaternoCtrl.dispose();
      apellidoMaternoCtrl.dispose();
      rfcCtrl.dispose();
      curpCtrl.dispose();
      nssCtrl.dispose();
      if (matriculaFocus.hasFocus) matriculaFocus.unfocus();
      if (pinFocus.hasFocus) pinFocus.unfocus();
      if (nombreFocus.hasFocus) nombreFocus.unfocus();
      if (apellidoFocus.hasFocus) apellidoFocus.unfocus();
      if (rfcFocus.hasFocus) rfcFocus.unfocus();
      if (curpFocus.hasFocus) curpFocus.unfocus();
      if (nssFocus.hasFocus) nssFocus.unfocus();
      matriculaFocus.dispose();
      pinFocus.dispose();
      nombreFocus.dispose();
      apellidoFocus.dispose();
      rfcFocus.dispose();
      curpFocus.dispose();
      nssFocus.dispose();
    }
  }

  Future<void> _showResetPinDialog(ColaboradorGestionModel row) async {
    final pin = _generateRandomPin4();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Resetear PIN - ${row.idEmpleado.isEmpty ? row.pin : row.idEmpleado}',
        ),
        content: Text('Nuevo PIN generado: $pin'),
        actions: [
          TextButton(
            onPressed: () => _safePop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _safePop(dialogContext, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      await api.updateColaborador(row.id, {
        'pin': pin,
        'rol': _resolveRol(
          privilegio: row.privilegio,
          esAdminReloj: row.esAdminDispositivo,
        ),
      });
      if (!mounted || !context.mounted) return;
      await _refreshColaboradoresInBackground();
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PIN actualizado: $pin')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDioMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo resetear PIN: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteColaborador(
    ColaboradorGestionModel row, {
    required bool hard,
  }) async {
    final fullName = row.nombreCompleto.trim().isNotEmpty
        ? row.nombreCompleto.trim()
        : '${row.nombre} ${row.apellido}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Colaborador'),
        content: Text(
          hard
              ? '¿Eliminar a $fullName de forma definitiva?'
              : '¿Eliminar a $fullName?',
        ),
        actions: [
          TextButton(
            onPressed: () => _safePop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _safePop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      await api.deleteColaborador(row.id, hard: hard);
      if (!mounted) return;
      setState(() {
        _colaboradoresCache = (_colaboradoresCache ?? const [])
            .where((e) => e.id != row.id)
            .toList(growable: false);
      });
      ref.invalidate(colaboradoresLiveProvider);
      await _refreshColaboradoresInBackground();
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hard
                ? 'Colaborador eliminado físicamente'
                : 'Colaborador dado de baja',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode ?? 0;
      final rejectionMessage = status == 409
          ? 'No se puede eliminar el colaborador porque tiene historial vinculado.'
          : _friendlyDioMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(rejectionMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetBiometria(ColaboradorGestionModel row) async {
    final fullName = row.nombreCompleto.trim().isNotEmpty
        ? row.nombreCompleto.trim()
        : '${row.nombre} ${row.apellido}'.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset biometría'),
        content: Text('Resetear rostro/huella para $fullName?'),
        actions: [
          TextButton(
            onPressed: () => _safePop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _safePop(ctx, true),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      await api.resetBiometriaColaborador(row.id);
      if (!mounted) return;
      ref.invalidate(colaboradoresLiveProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biometría reseteada')));
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDioMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDocumentosDialog(ColaboradorGestionModel row) async {
    List<ColaboradorDocumentoModel> documentos = const [];
    bool loading = true;
    bool uploading = false;

    Future<void> reload(StateSetter setDialogState) async {
      setDialogState(() => loading = true);
      try {
        final api = ref.read(relojChecadorAppApiProvider);
        documentos = await api.getColaboradorDocumentos(row.id);
      } finally {
        setDialogState(() => loading = false);
      }
    }

    Future<void> upload(String tipoDoc, StateSetter setDialogState) async {
      setDialogState(() => uploading = true);
      try {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        if (picked == null || picked.files.isEmpty) return;
        final file = picked.files.first;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('No se pudo leer archivo seleccionado.');
        }

        final api = ref.read(relojChecadorAppApiProvider);
        await api.uploadColaboradorDocumento(
          colaboradorId: row.id,
          tipoDoc: tipoDoc,
          bytes: bytes,
          fileName: file.name,
        );

        await reload(setDialogState);
      } finally {
        setDialogState(() => uploading = false);
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (loading && documentos.isEmpty) {
              Future.microtask(() => reload(setDialogState));
            }

            Widget content;
            if (loading && documentos.isEmpty) {
              content = const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              content = SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: uploading
                              ? null
                              : () => upload('RFC', setDialogState),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir RFC'),
                        ),
                        OutlinedButton.icon(
                          onPressed: uploading
                              ? null
                              : () => upload('CURP', setDialogState),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir CURP'),
                        ),
                        OutlinedButton.icon(
                          onPressed: uploading
                              ? null
                              : () => upload('NSS', setDialogState),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir NSS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: documentos.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Sin documentos cargados'),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: documentos.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = documentos[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.description_outlined,
                                  ),
                                  title: Text(
                                    '${doc.tipoDoc} - ${doc.fileName}',
                                  ),
                                  subtitle: Text(
                                    doc.uploadedAt == null
                                        ? doc.fileUrl
                                        : '${_dateIso(doc.uploadedAt!)} | ${doc.fileUrl}',
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Text('Documentos - ${row.pin}'),
              content: content,
              actions: [
                TextButton(
                  onPressed: () => _safePop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      ref.invalidate(colaboradoresLiveProvider);
    }
  }

  Future<void> _showQrCredential(ColaboradorGestionModel row) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final qr = await api.getColaboradorQrCredential(row.id);
      await _showQrCredentialData(qr, titlePin: row.pin);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar credencial QR: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showQrCredentialData(
    ColaboradorQrCredential qr, {
    String? titlePin,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Credencial QR - ${titlePin ?? qr.pin}'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: qr.token,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  qr.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('PIN: ${qr.pin}'),
                if ((qr.sucursalCodigo ?? '').isNotEmpty)
                  Text('Sucursal: ${qr.sucursalCodigo}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _safePop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(colaboradoresRealtimeBridgeProvider);
    final colaboradoresAsync = ref.watch(colaboradoresLiveProvider);
    final sucursalesAsync = ref.watch(sucursalesCatalogProvider);
    final horariosAsync = ref.watch(horariosCatalogProvider);
    final liveRows = colaboradoresAsync.valueOrNull;
    if (liveRows != null) {
      _colaboradoresCache = List<ColaboradorGestionModel>.unmodifiable(
        liveRows.toList(growable: false),
      );
      if (_manualRefreshing) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _manualRefreshing = false);
        });
      }
    }
    final rowsForRender =
        _colaboradoresCache ?? const <ColaboradorGestionModel>[];
    final showSpinner =
        rowsForRender.isEmpty &&
        (_manualRefreshing || colaboradoresAsync.isLoading);
    final showError =
        rowsForRender.isEmpty &&
        colaboradoresAsync.hasError &&
        !colaboradoresAsync.isLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy
                  ? null
                  : () async {
                      final sucursales =
                          sucursalesAsync.valueOrNull ?? const [];
                      final horarios = horariosAsync.valueOrNull ?? const [];
                      if (sucursales.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No hay sucursales disponibles'),
                          ),
                        );
                        return;
                      }
                      await _showCreateDialog(
                        sucursales: sucursales,
                        horarios: horarios,
                      );
                    },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo'),
            ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _manualRefreshing = true);
                        ref.invalidate(colaboradoresLiveProvider);
                        ref.invalidate(sucursalesCatalogProvider);
                        ref.invalidate(horariosCatalogProvider);
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Refrescar'),
              ),
            ),
            const SizedBox(height: 12),
            _buildFilterBar(ref),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4D8DF)),
                ),
                child: showSpinner
                    ? const Center(child: CircularProgressIndicator())
                    : showError
                    ? Center(
                        child: Text(
                          'Error cargando colaboradores: ${colaboradoresAsync.error}',
                        ),
                      )
                    : rowsForRender.isEmpty
                    ? const Center(child: Text('Sin colaboradores registrados'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFF606973),
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'ID (Matrícula)',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Sucursal',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Departamento',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Cargo',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Nombre Completo',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Expediente',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Acciones',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                            rows: rowsForRender
                                .map(
                                  (row) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          row.idEmpleado.trim().isEmpty
                                              ? row.id.toString()
                                              : row.idEmpleado.trim(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${row.sucursalCodigo} - ${row.sucursalNombre}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          row.departamento.trim().isEmpty
                                              ? '-'
                                              : row.departamento.trim(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          row.cargo.trim().isEmpty
                                              ? '-'
                                              : row.cargo.trim(),
                                        ),
                                      ),
                                      DataCell(Text(row.nombreCompleto)),
                                      DataCell(
                                        Row(
                                          children: [
                                            Icon(
                                              _expedienteIcon(row),
                                              color: _expedienteColor(row),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(_expedienteLabel(row)),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        PopupMenuButton<_ColabAction>(
                                          enabled: !_busy,
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (action) =>
                                              _runAction(row, action),
                                          itemBuilder: (context) {
                                            if (widget.readOnly) {
                                              return const [
                                                PopupMenuItem(
                                                  value:
                                                      _ColabAction.credencialQr,
                                                  child: Text(
                                                    'Generar Credencial QR',
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _ColabAction.documentos,
                                                  child: Text(
                                                    'Gestión de Documentos',
                                                  ),
                                                ),
                                              ];
                                            }
                                            return const [
                                              PopupMenuItem(
                                                value: _ColabAction.editar,
                                                child: Text(
                                                  'Editar colaborador',
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: _ColabAction.resetPin,
                                                child: Text('Resetear PIN'),
                                              ),
                                              PopupMenuItem(
                                                value:
                                                    _ColabAction.eliminarLogica,
                                                child: Text(
                                                  'Eliminar Colaborador',
                                                ),
                                              ),
                                              PopupMenuDivider(),
                                              PopupMenuItem(
                                                value:
                                                    _ColabAction.resetBiometria,
                                                child: Text(
                                                  'Resetear biometría',
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: _ColabAction.regenerarQr,
                                                child: Text(
                                                  'Regenerar código QR',
                                                ),
                                              ),
                                              PopupMenuDivider(),
                                              PopupMenuItem(
                                                value:
                                                    _ColabAction.credencialQr,
                                                child: Text(
                                                  'Generar Credencial QR',
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: _ColabAction.documentos,
                                                child: Text(
                                                  'Gestión de Documentos',
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value:
                                                    _ColabAction.enrolarHuella,
                                                child: Text('Enrolar Huella'),
                                              ),
                                              PopupMenuItem(
                                                value:
                                                    _ColabAction.enrolarRostro,
                                                child: Text('Enrolar Face ID'),
                                              ),
                                            ];
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyDioMessage(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  if (status == 409) {
    return 'Error: La Matrícula/ID ya está registrada en el sistema';
  }
  if (status == 400) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final message = map['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List && message.isNotEmpty) {
        final first = message.first?.toString().trim() ?? '';
        if (first.isNotEmpty) return first;
      }
    }
    return 'Error de formato o campos no permitidos';
  }
  if (status == 500 && data != null) {
    return 'Error 500: Conflicto en el formato del PIN o datos duplicados';
  }
  if (status == 500) {
    return 'Error 500: Conflicto en el formato del PIN o datos duplicados';
  }
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) {
      final raw = message.trim();
      return status == null ? raw : 'HTTP $status: $raw';
    }
    if (message is List && message.isNotEmpty) {
      final first = message.first?.toString().trim() ?? '';
      if (first.isNotEmpty) {
        return status == null ? first : 'HTTP $status: $first';
      }
    }
    final detail = (map['detail'] ?? map['error'] ?? map['constraint'])
        ?.toString()
        .trim();
    if ((detail ?? '').isNotEmpty) {
      return status == null ? detail! : 'HTTP $status: $detail';
    }
  } else if (data is String && data.trim().isNotEmpty) {
    return status == null ? data.trim() : 'HTTP $status: ${data.trim()}';
  }
  if ((e.message ?? '').trim().isNotEmpty) {
    final msg = e.message!.trim();
    return status == null ? msg : 'HTTP $status: $msg';
  }
  return status == null
      ? 'No se pudo completar la acción. Revisa conexión e intenta de nuevo.'
      : 'HTTP $status: No se pudo completar la acción.';
}

String _dateIso(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
