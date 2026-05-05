import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';

class RelojChecadorHorariosTab extends ConsumerStatefulWidget {
  const RelojChecadorHorariosTab({super.key});

  @override
  ConsumerState<RelojChecadorHorariosTab> createState() =>
      _RelojChecadorHorariosTabState();
}

class _RelojChecadorHorariosTabState
    extends ConsumerState<RelojChecadorHorariosTab>
    with AutomaticKeepAliveClientMixin {
  static const List<_TurnoPreset> _presets = <_TurnoPreset>[
    _TurnoPreset('Matutino', '09:00', '14:00', '15:00', '18:00'),
    _TurnoPreset('Vespertino', '11:00', '15:00', '16:00', '20:00'),
    _TurnoPreset('Nocturno', '21:00', '00:30', '01:00', '05:00'),
    _TurnoPreset('Mixto', '10:00', '14:00', '15:00', '18:30'),
  ];

  bool _busy = false;
  DateTime _weekStart = _startOfWeek(DateTime.now());
  String? _selectedSucursal;
  String? _selectedDepartamento;
  String _confirmacion = 'PENDIENTE';
  Future<HorarioSemanalModel>? _weeklyFuture;
  HorarioSemanalModel? _lastWeeklyData;

  @override
  void initState() {
    super.initState();
    final api = ref.read(relojChecadorAppApiProvider);
    _weeklyFuture = api.getHorarioSemanal(
      weekStart: _weekStart,
      sucursal: _selectedSucursal,
      departamento: _selectedDepartamento,
    );
  }

  @override
  bool get wantKeepAlive => true;

  void _setStatePostFrame(VoidCallback fn) {
    if (!mounted) return;
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  void _reloadWeekly() {
    final api = ref.read(relojChecadorAppApiProvider);
    _setStatePostFrame(() {
      _weeklyFuture = api.getHorarioSemanal(
        weekStart: _weekStart,
        sucursal: _selectedSucursal,
        departamento: _selectedDepartamento,
      );
    });
  }

  void _triggerAsistenciaRefresh() {
    ref.invalidate(asistenciaReporteProvider);
    ref.invalidate(reporteSolicitudesProvider);
    ref.invalidate(solicitudesIncidenciasProvider);
    ref.invalidate(ausenciasCalendarioProvider);
    _reloadWeekly();
  }

  Future<void> _showHorarioDialog({HorarioModel? initial}) async {
    final nombreCtrl = TextEditingController(text: initial?.nombre ?? '');
    final entradaCtrl = TextEditingController(
      text: _timeShort(initial?.horaEntrada ?? '08:00:00'),
    );
    final salidaCtrl = TextEditingController(
      text: _timeShort(initial?.horaSalida ?? '17:00:00'),
    );
    final inicioEntradaCtrl = TextEditingController(
      text: _timeShort(initial?.inicioEntrada ?? initial?.horaEntrada ?? '08:00:00'),
    );
    final finEntradaCtrl = TextEditingController(
      text: _timeShort(initial?.finEntrada ?? initial?.horaEntrada ?? '08:15:00'),
    );
    final tolCtrl = TextEditingController(
      text: (initial?.toleranciaMinutos ?? 0).toString(),
    );
    final almuerzoCtrl = TextEditingController(
      text: (initial?.minutosAlmuerzo ?? 0).toString(),
    );
    final redondeoCtrl = TextEditingController(
      text: (initial?.redondeoEntrada ?? 0).toString(),
    );
    final otMinCtrl = TextEditingController(
      text: (initial?.otMinimoMinutos ?? 0).toString(),
    );

    var diaFestivo = initial?.diaFestivo ?? false;
    var esFlexible = initial?.esFlexible ?? false;
    var otRequiereAutorizacion = initial?.otRequiereAutorizacion ?? false;
    var localSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(initial == null ? 'Nuevo Turno LFT' : 'Editar Turno LFT'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Nota: Cambiar este horario afectará el cálculo de asistencia de todos los empleados vinculados.',
                          style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: nombreCtrl,
                          enabled: !localSaving,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del turno',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entradaCtrl,
                                readOnly: true,
                                enabled: !localSaving,
                                onTap: localSaving
                                    ? null
                                    : () async {
                                        final picked = await showTimePicker(
                                          context: dialogContext,
                                          initialTime: _parseTimeOfDay(
                                            entradaCtrl.text,
                                          ),
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                            () => entradaCtrl.text =
                                                _formatTimeOfDay(picked),
                                          );
                                        }
                                      },
                                decoration: const InputDecoration(
                                  labelText: 'Hora entrada',
                                  helperText: 'HH:mm',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: salidaCtrl,
                                readOnly: true,
                                enabled: !localSaving,
                                onTap: localSaving
                                    ? null
                                    : () async {
                                        final picked = await showTimePicker(
                                          context: dialogContext,
                                          initialTime: _parseTimeOfDay(
                                            salidaCtrl.text,
                                          ),
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                            () => salidaCtrl.text =
                                                _formatTimeOfDay(picked),
                                          );
                                        }
                                      },
                                decoration: const InputDecoration(
                                  labelText: 'Hora salida',
                                  helperText: 'HH:mm',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: inicioEntradaCtrl,
                                readOnly: true,
                                enabled: !localSaving,
                                onTap: localSaving
                                    ? null
                                    : () async {
                                        final picked = await showTimePicker(
                                          context: dialogContext,
                                          initialTime: _parseTimeOfDay(
                                            inicioEntradaCtrl.text,
                                          ),
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                            () => inicioEntradaCtrl.text =
                                                _formatTimeOfDay(picked),
                                          );
                                        }
                                      },
                                decoration: const InputDecoration(
                                  labelText: 'Checkpoint inicio',
                                  helperText: 'Rango válido entrada',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: finEntradaCtrl,
                                readOnly: true,
                                enabled: !localSaving,
                                onTap: localSaving
                                    ? null
                                    : () async {
                                        final picked = await showTimePicker(
                                          context: dialogContext,
                                          initialTime: _parseTimeOfDay(
                                            finEntradaCtrl.text,
                                          ),
                                        );
                                        if (picked != null) {
                                          setDialogState(
                                            () => finEntradaCtrl.text =
                                                _formatTimeOfDay(picked),
                                          );
                                        }
                                      },
                                decoration: const InputDecoration(
                                  labelText: 'Checkpoint fin',
                                  helperText: 'Rango válido entrada',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: tolCtrl,
                                enabled: !localSaving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Tolerancia (min)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: redondeoCtrl,
                                enabled: !localSaving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Redondeo entrada (min)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: almuerzoCtrl,
                                enabled: !localSaving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Descuento almuerzo (min)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: otMinCtrl,
                                enabled: !localSaving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'OT mínimo (min)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: esFlexible,
                          onChanged: localSaving
                              ? null
                              : (value) =>
                                    setDialogState(() => esFlexible = value),
                          title: const Text('Horario Flexible'),
                          subtitle: const Text('Si activo: retardo no aplica'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          value: otRequiereAutorizacion,
                          onChanged: localSaving
                              ? null
                              : (value) => setDialogState(
                                    () => otRequiereAutorizacion = value,
                                  ),
                          title: const Text('OT requiere autorización'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          value: diaFestivo,
                          onChanged: localSaving
                              ? null
                              : (value) =>
                                    setDialogState(() => diaFestivo = value),
                          title: const Text('Día festivo'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: localSaving
                        ? null
                        : () async {
                            final nombre = nombreCtrl.text.trim();
                            final entrada = entradaCtrl.text.trim();
                            final salida = salidaCtrl.text.trim();
                            final inicioEntrada = inicioEntradaCtrl.text.trim();
                            final finEntrada = finEntradaCtrl.text.trim();
                            final tolerancia = int.tryParse(tolCtrl.text.trim()) ?? 0;
                            final minutosAlmuerzo =
                                int.tryParse(almuerzoCtrl.text.trim()) ?? 0;
                            final redondeo =
                                int.tryParse(redondeoCtrl.text.trim()) ?? 0;
                            final otMin = int.tryParse(otMinCtrl.text.trim()) ?? 0;
                            final weeklyHours = _estimateWeeklyHours(
                              entrada: entrada,
                              salida: salida,
                              descuentoAlmuerzoMin: minutosAlmuerzo,
                            );
                            final toleranciaAjustada = weeklyHours > 48
                                ? (tolerancia < 15 ? 15 : tolerancia)
                                : tolerancia;

                            if (nombre.isEmpty ||
                                !_validTime(entrada) ||
                                !_validTime(salida) ||
                                !_validTime(inicioEntrada) ||
                                !_validTime(finEntrada)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Valida nombre y horas (HH:mm o HH:mm:ss).',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => localSaving = true);
                            _setStatePostFrame(() => _busy = true);

                            try {
                              final api = ref.read(relojChecadorAppApiProvider);
                              final payload = HorarioUpsertRequest(
                                nombre: nombre,
                                horaEntrada: entrada,
                                horaSalida: salida,
                                toleranciaMinutos: toleranciaAjustada,
                                diaFestivo: diaFestivo,
                                inicioEntrada: inicioEntrada,
                                finEntrada: finEntrada,
                                minutosAlmuerzo: minutosAlmuerzo,
                                redondeoEntrada: redondeo,
                                esFlexible: esFlexible,
                                otMinimoMinutos: otMin,
                                otRequiereAutorizacion: otRequiereAutorizacion,
                                horasJornadaMinutos: 480,
                                horasExtraMinimoMinutos: 0,
                                horasExtraRequiereAutorizacion: false,
                                activo: true,
                              );

                              if (initial == null) {
                                await api.createHorario(payload);
                              } else {
                                await api.updateHorario(initial.id, payload);
                              }

                              ref.invalidate(horariosCatalogProvider);
                              _triggerAsistenciaRefresh();
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                            } on DioException catch (e) {
                              if (!mounted) return;
                              setDialogState(() => localSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_dioMessage(e))),
                              );
                            } finally {
                              if (mounted) _setStatePostFrame(() => _busy = false);
                            }
                          },
                    icon: const Icon(Icons.save),
                    label: Text(initial == null ? 'Crear' : 'Actualizar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nombreCtrl.dispose();
      entradaCtrl.dispose();
      salidaCtrl.dispose();
      inicioEntradaCtrl.dispose();
      finEntradaCtrl.dispose();
      tolCtrl.dispose();
      almuerzoCtrl.dispose();
      redondeoCtrl.dispose();
      otMinCtrl.dispose();
    }
  }

  Future<void> _showTurnoCatalogDialog() async {
    final preset = ValueNotifier<_TurnoPreset>(_presets.first);
    final nombreCtrl = TextEditingController(text: preset.value.nombre);
    final entradaCtrl = TextEditingController(text: preset.value.hrEntrada);
    final salidaComidaCtrl = TextEditingController(
      text: preset.value.hrSalidaComida,
    );
    final regresoComidaCtrl = TextEditingController(
      text: preset.value.hrRegresoComida,
    );
    final salidaCtrl = TextEditingController(text: preset.value.hrSalida);
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Configurador de Turnos LFT'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<_TurnoPreset>(
                          initialValue: preset.value,
                          decoration: const InputDecoration(
                            labelText: 'Plantilla',
                            border: OutlineInputBorder(),
                          ),
                          items: _presets
                              .map(
                                (item) => DropdownMenuItem<_TurnoPreset>(
                                  value: item,
                                  child: Text(item.nombre),
                                ),
                              )
                              .toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  preset.value = value;
                                  nombreCtrl.text = value.nombre;
                                  entradaCtrl.text = value.hrEntrada;
                                  salidaComidaCtrl.text = value.hrSalidaComida;
                                  regresoComidaCtrl.text = value.hrRegresoComida;
                                  salidaCtrl.text = value.hrSalida;
                                  setDialogState(() {});
                                },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: nombreCtrl,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Nombre turno',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entradaCtrl,
                                enabled: !saving,
                                decoration: const InputDecoration(
                                  labelText: 'Entrada',
                                  helperText: 'HH:mm',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: salidaComidaCtrl,
                                enabled: !saving,
                                decoration: const InputDecoration(
                                  labelText: 'Salida comida',
                                  helperText: 'HH:mm',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: regresoComidaCtrl,
                                enabled: !saving,
                                decoration: const InputDecoration(
                                  labelText: 'Regreso comida',
                                  helperText: 'HH:mm',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: salidaCtrl,
                                enabled: !saving,
                                decoration: const InputDecoration(
                                  labelText: 'Salida',
                                  helperText: 'HH:mm',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Modo Flexible: sistema ajusta tolerancias automáticamente hasta 55h/semana.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final nombre = nombreCtrl.text.trim();
                            final hrEntrada = entradaCtrl.text.trim();
                            final hrSalidaComida = salidaComidaCtrl.text.trim();
                            final hrRegresoComida = regresoComidaCtrl.text.trim();
                            final hrSalida = salidaCtrl.text.trim();
                            if (nombre.isEmpty ||
                                !_validTime(hrEntrada) ||
                                !_validTime(hrSalidaComida) ||
                                !_validTime(hrRegresoComida) ||
                                !_validTime(hrSalida)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Completa horas válidas HH:mm'),
                                ),
                              );
                              return;
                            }
                            setDialogState(() => saving = true);
                            _setStatePostFrame(() => _busy = true);
                            try {
                              final api = ref.read(relojChecadorAppApiProvider);
                              await api.createTurnoCatalogo(
                                nombre: nombre,
                                hrEntrada: hrEntrada,
                                hrSalidaComida: hrSalidaComida,
                                hrRegresoComida: hrRegresoComida,
                                hrSalida: hrSalida,
                              );
                              ref.invalidate(turnosCatalogProvider);
                              ref.invalidate(horariosCatalogProvider);
                              _reloadWeekly();
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                            } on DioException catch (e) {
                              if (!mounted) return;
                              setDialogState(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_dioMessage(e))),
                              );
                            } finally {
                              if (mounted) _setStatePostFrame(() => _busy = false);
                            }
                          },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar plantilla'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      preset.dispose();
      nombreCtrl.dispose();
      entradaCtrl.dispose();
      salidaComidaCtrl.dispose();
      regresoComidaCtrl.dispose();
      salidaCtrl.dispose();
    }
  }

  Future<void> _confirmarSemana() async {
    final suc = (_selectedSucursal ?? '').trim();
    final depto = (_selectedDepartamento ?? '').trim();
    if (suc.isEmpty || depto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona sucursal y departamento para confirmar.'),
        ),
      );
      return;
    }

    _setStatePostFrame(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      await api.setHorarioConfirmacion(
        sucursal: suc,
        departamento: depto,
        semana: _weekStart,
        estatus: _confirmacion,
      );
      _reloadWeekly();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Semana $_confirmacion para $depto en $suc')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
    } finally {
      if (mounted) _setStatePostFrame(() => _busy = false);
    }
  }

  Future<void> _generarSemana() async {
    _setStatePostFrame(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      final res = await api.generarHorariosSiguienteSemana();
      _reloadWeekly();
      if (!mounted) return;
      final generated = res['generated']?.toString() ?? '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Semana siguiente generada. Confirmaciones: $generated')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
    } finally {
      if (mounted) _setStatePostFrame(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final turnosAsync = ref.watch(turnosCatalogProvider);
    final colaboradoresAsync = ref.watch(colaboradoresLiveProvider);
    final colaboradores = colaboradoresAsync.valueOrNull ?? const <ColaboradorGestionModel>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _showHorarioDialog(),
        icon: const Icon(Icons.schedule),
        label: const Text('Nuevo Horario'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(color: const Color(0xFFD4D8DF)),
              ),
              child: _buildToolbar(
                colaboradores: colaboradores,
                turnosCount: turnosAsync.valueOrNull?.length ?? 0,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4D8DF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: FutureBuilder<HorarioSemanalModel>(
                  future: _weeklyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error semanal: ${snapshot.error}'),
                      );
                    }
                    final data = snapshot.data;
                    if (data != null) {
                      _lastWeeklyData = data;
                    }
                    if (data == null || data.rows.isEmpty) {
                      return const Center(
                        child: Text('Sin programación semanal para filtros actuales'),
                      );
                    }
                    return _buildWeeklyTable(data, colaboradores);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar({
    required List<ColaboradorGestionModel> colaboradores,
    required int turnosCount,
  }) {
    final sucursales = _uniqueSucursales(colaboradores);
    final departamentos = _uniqueDepartamentos(colaboradores);
    final width = MediaQuery.sizeOf(context).width;
    final filterMaxWidth = (width * 0.22).clamp(150.0, 240.0);

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      _setStatePostFrame(() {
                        _weekStart = _startOfWeek(
                          _weekStart.subtract(const Duration(days: 7)),
                        );
                      });
                      _reloadWeekly();
                    },
              icon: const Icon(Icons.chevron_left),
              label: const Text('Semana anterior'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      _setStatePostFrame(() {
                        _weekStart = _startOfWeek(
                          _weekStart.add(const Duration(days: 7)),
                        );
                      });
                      _reloadWeekly();
                    },
              icon: const Icon(Icons.chevron_right),
              label: const Text('Semana siguiente'),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width < 900 ? 240 : 360),
              child: Text(
                'Semana: ${_dateShort(_weekStart)} - ${_dateShort(_weekStart.add(const Duration(days: 6)))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            _buildSemanaBadge(),
            Tooltip(
              message: 'Turnos catálogo: $turnosCount',
              child: const Icon(Icons.info_outline, color: Colors.blueGrey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 150, maxWidth: filterMaxWidth),
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedSucursal,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas'),
                  ),
                  ...sucursales.map((s) => DropdownMenuItem<String?>(
                        value: s,
                        child: Text(s),
                      )),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        _setStatePostFrame(() => _selectedSucursal = value);
                        _reloadWeekly();
                      },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 150, maxWidth: filterMaxWidth),
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedDepartamento,
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ...departamentos.map((d) => DropdownMenuItem<String?>(
                        value: d,
                        child: Text(d),
                      )),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        _setStatePostFrame(() => _selectedDepartamento = value);
                        _reloadWeekly();
                      },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 150, maxWidth: filterMaxWidth),
              child: DropdownButtonFormField<String>(
                initialValue: _confirmacion,
                decoration: const InputDecoration(
                  labelText: 'Confirmación Jefe',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'PENDIENTE',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'CONFIRMADO',
                    child: Text('Confirmado'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        _setStatePostFrame(() => _confirmacion = value);
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _showTurnoCatalogDialog,
              icon: const Icon(Icons.auto_awesome_mosaic),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              label: const Text('Plantillas', style: TextStyle(fontSize: 14)),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _generarSemana,
              icon: const Icon(Icons.auto_mode),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              label: const Text('Generar', style: TextStyle(fontSize: 14)),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _confirmarSemana,
              icon: const Icon(Icons.verified),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              label: const Text('Confirmar', style: TextStyle(fontSize: 14)),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _showConfirmacionesModal,
              icon: const Icon(Icons.visibility),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              label: const Text('Estatus', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSemanaBadge() {
    final week = _isoWeekNumber(_weekStart);
    final currentWeek = _isoWeekNumber(_startOfWeek(DateTime.now()));
    const primary = Color(0xFF5A35A5);
    final isCurrent = week == currentWeek;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? primary : Colors.transparent,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Sem $week',
        style: const TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  int _isoWeekNumber(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final thursday = normalized.add(Duration(days: 4 - normalized.weekday));
    final yearStart = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
  }

  Widget _buildWeeklyTable(
    HorarioSemanalModel data,
    List<ColaboradorGestionModel> colaboradores,
  ) {
    final rows = _applyClientFilters(data.rows, colaboradores);
    final groups = _groupRowsByColaborador(rows);

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin colaboradores para filtros actuales'),
          ),
        for (final group in groups)
          _ColaboradorWeeklyGroupTile(group: group, weekDays: data.days),
      ],
    );
  }

  List<String> _uniqueSucursales(List<ColaboradorGestionModel> colaboradores) {
    final set = <String>{};
    for (final c in colaboradores) {
      final code = c.sucursalCodigo.trim().toUpperCase();
      if (code.isNotEmpty) set.add(code);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> _uniqueDepartamentos(
    List<ColaboradorGestionModel> colaboradores,
  ) {
    final set = <String>{};
    for (final c in colaboradores) {
      final dept = c.departamento.trim().toUpperCase();
      if (dept.isNotEmpty) set.add(dept);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<HorarioSemanalRowModel> _applyClientFilters(
    List<HorarioSemanalRowModel> rows,
    List<ColaboradorGestionModel> colaboradores,
  ) {
    final allowedIds = <int>{};
    for (final c in colaboradores) {
      final sucOk = _selectedSucursal == null ||
          c.sucursalCodigo.trim().toUpperCase() ==
              _selectedSucursal!.trim().toUpperCase();
      final deptOk = _selectedDepartamento == null ||
          c.departamento.trim().toUpperCase() ==
              _selectedDepartamento!.trim().toUpperCase();
      if (sucOk && deptOk) {
        allowedIds.add(c.id);
      }
    }

    return rows.where((row) {
      if (allowedIds.isNotEmpty && !allowedIds.contains(row.colaboradorId)) {
        return false;
      }
      if (_selectedSucursal != null &&
          row.sucursal.trim().toUpperCase() !=
              _selectedSucursal!.trim().toUpperCase()) {
        return false;
      }
      if (_selectedDepartamento != null &&
          row.departamento.trim().toUpperCase() !=
              _selectedDepartamento!.trim().toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_HorarioGroup> _groupRowsByColaborador(List<HorarioSemanalRowModel> rows) {
    final map = <int, List<HorarioSemanalRowModel>>{};
    for (final row in rows) {
      map.putIfAbsent(row.colaboradorId, () => <HorarioSemanalRowModel>[]).add(row);
    }

    final groups = <_HorarioGroup>[];
    for (final entry in map.entries) {
      final source = entry.value;
      if (source.isEmpty) continue;
      final base = source.first;
      groups.add(
        _HorarioGroup(
          colaboradorId: base.colaboradorId,
          idEmpleado: base.idEmpleado,
          nombreCompleto: base.nombreCompleto,
          sucursal: base.sucursal,
          departamento: base.departamento,
          cargo: base.cargo,
          dailyRows: _buildDailyRows(source),
        ),
      );
    }
    groups.sort(
      (a, b) => '${a.idEmpleado} ${a.nombreCompleto}'
          .toUpperCase()
          .compareTo('${b.idEmpleado} ${b.nombreCompleto}'.toUpperCase()),
    );
    return groups;
  }

  List<_HorarioDailyRow> _buildDailyRows(List<HorarioSemanalRowModel> rows) {
    final byEvent = <String, HorarioSemanalRowModel>{};
    for (final row in rows) {
      byEvent[row.evento.trim().toUpperCase()] = row;
    }

    final dayNames = <String>[
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    final daily = <_HorarioDailyRow>[];
    for (var i = 0; i < 7; i++) {
      String pick(HorarioSemanalRowModel? row) {
        if (row == null) return '--';
        final source = <String>[
          row.lunes,
          row.martes,
          row.miercoles,
          row.jueves,
          row.viernes,
          row.sabado,
          row.domingo,
        ][i];
        final time = _timeFromStamp(source);
        return time.isEmpty ? '--' : time;
      }

      daily.add(
        _HorarioDailyRow(
          dayLabel: dayNames[i],
          hrEntrada: pick(byEvent['ENTRADA']),
          hrSalComida: pick(byEvent['SALIDA_COMER']),
          hrRegComida: pick(byEvent['REGRESO_COMER']),
          hrSalida: pick(byEvent['SALIDA']),
        ),
      );
    }

    return daily;
  }

  Future<void> _showConfirmacionesModal() async {
    final data = _lastWeeklyData;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ESTATUS DE CONFIRMACIONES'),
          content: SizedBox(
            width: 720,
            child: data == null || data.confirmaciones.isEmpty
                ? const Text('Sin confirmaciones para semana actual.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF606973),
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Snc',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Depto',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'SM',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Estatus',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      rows: data.confirmaciones
                          .map(
                            (c) => DataRow(
                              cells: [
                                DataCell(Text(c.sucursal)),
                                DataCell(Text(c.departamento)),
                                DataCell(Text(c.semana)),
                                DataCell(Text(c.estatus)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await _confirmarSemana();
                    },
              icon: const Icon(Icons.verified),
              label: const Text('Aplicar Estatus'),
            ),
          ],
        );
      },
    );
  }
}

class _TurnoPreset {
  final String nombre;
  final String hrEntrada;
  final String hrSalidaComida;
  final String hrRegresoComida;
  final String hrSalida;

  const _TurnoPreset(
    this.nombre,
    this.hrEntrada,
    this.hrSalidaComida,
    this.hrRegresoComida,
    this.hrSalida,
  );
}

class _HorarioGroup {
  final int colaboradorId;
  final String idEmpleado;
  final String nombreCompleto;
  final String sucursal;
  final String departamento;
  final String cargo;
  final List<_HorarioDailyRow> dailyRows;

  const _HorarioGroup({
    required this.colaboradorId,
    required this.idEmpleado,
    required this.nombreCompleto,
    required this.sucursal,
    required this.departamento,
    required this.cargo,
    required this.dailyRows,
  });
}

class _HorarioDailyRow {
  final String dayLabel;
  final String hrEntrada;
  final String hrSalComida;
  final String hrRegComida;
  final String hrSalida;

  const _HorarioDailyRow({
    required this.dayLabel,
    required this.hrEntrada,
    required this.hrSalComida,
    required this.hrRegComida,
    required this.hrSalida,
  });
}

class _ColaboradorWeeklyGroupTile extends StatelessWidget {
  const _ColaboradorWeeklyGroupTile({
    required this.group,
    required this.weekDays,
  });

  final _HorarioGroup group;
  final List<String> weekDays;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF8F9FA),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD4D8DF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        title: Text(
          '[${group.idEmpleado}] ${group.nombreCompleto}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
        subtitle: Text(
          '${group.sucursal} • ${group.departamento} • ${group.cargo}',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 10,
                headingRowColor: WidgetStateProperty.all(const Color(0xFF606973)),
                columns: const [
                  DataColumn(
                    label: Text(
                      'DÍA',
                      style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'HR ENTRADA',
                      style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'HR SAL COMID',
                      style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'HR RER COMID',
                      style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'HR SALIDA',
                      style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                    ),
                  ),
                ],
                rows: [
                  for (final item in group.dailyRows.asMap().entries)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${item.value.dayLabel}, ${_dateLongEs(index: item.key, weekDays: weekDays)}',
                            style: const TextStyle(fontFamily: 'Roboto'),
                          ),
                        ),
                        DataCell(Text(item.value.hrEntrada, style: const TextStyle(fontFamily: 'Roboto'))),
                        DataCell(Text(item.value.hrSalComida, style: const TextStyle(fontFamily: 'Roboto'))),
                        DataCell(Text(item.value.hrRegComida, style: const TextStyle(fontFamily: 'Roboto'))),
                        DataCell(Text(item.value.hrSalida, style: const TextStyle(fontFamily: 'Roboto'))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _startOfWeek(DateTime day) {
  final clean = DateTime(day.year, day.month, day.day);
  final diff = clean.weekday - DateTime.monday;
  return clean.subtract(Duration(days: diff));
}

String _timeShort(String value) {
  final text = value.trim();
  if (text.length >= 5) return text.substring(0, 5);
  return text;
}

TimeOfDay _parseTimeOfDay(String value) {
  final text = _timeShort(value);
  final parts = text.split(':');
  if (parts.length < 2) {
    return const TimeOfDay(hour: 8, minute: 0);
  }
  final hour = int.tryParse(parts[0]) ?? 8;
  final minute = int.tryParse(parts[1]) ?? 0;
  return TimeOfDay(
    hour: hour.clamp(0, 23),
    minute: minute.clamp(0, 59),
  );
}

String _formatTimeOfDay(TimeOfDay value) {
  final h = value.hour.toString().padLeft(2, '0');
  final m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

bool _validTime(String value) {
  final text = value.trim();
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$').hasMatch(text);
}

String _dioMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  if ((e.message ?? '').trim().isNotEmpty) {
    return e.message!.trim();
  }
  return 'Error de red';
}

String _dateShort(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _dateLongEs({required int index, required List<String> weekDays}) {
  if (index < 0 || index >= weekDays.length) return '--';
  final date = DateTime.tryParse(weekDays[index]);
  if (date == null) return weekDays[index];
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${date.day} de ${months[date.month - 1]} ${date.year}';
}

String _timeFromStamp(String raw) {
  final value = raw.trim();
  if (value.length >= 16) {
    return value.substring(11, 16);
  }
  return value;
}

double _estimateWeeklyHours({
  required String entrada,
  required String salida,
  required int descuentoAlmuerzoMin,
}) {
  final inParts = _timeShort(entrada).split(':');
  final outParts = _timeShort(salida).split(':');
  if (inParts.length < 2 || outParts.length < 2) return 0;
  final inMin = (int.tryParse(inParts[0]) ?? 0) * 60 + (int.tryParse(inParts[1]) ?? 0);
  var outMin = (int.tryParse(outParts[0]) ?? 0) * 60 + (int.tryParse(outParts[1]) ?? 0);
  if (outMin < inMin) {
    outMin += 24 * 60;
  }
  var dailyMin = outMin - inMin - descuentoAlmuerzoMin;
  if (dailyMin < 0) dailyMin = 0;
  return (dailyMin * 5) / 60.0;
}
