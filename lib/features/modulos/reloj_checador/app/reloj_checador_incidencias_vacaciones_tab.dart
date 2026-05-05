import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'reloj_checador_app_models.dart';
import 'reloj_checador_app_providers.dart';

class RelojChecadorIncidenciasVacacionesTab extends ConsumerStatefulWidget {
  const RelojChecadorIncidenciasVacacionesTab({super.key});

  @override
  ConsumerState<RelojChecadorIncidenciasVacacionesTab> createState() =>
      _RelojChecadorIncidenciasVacacionesTabState();
}

class _RelojChecadorIncidenciasVacacionesTabState
    extends ConsumerState<RelojChecadorIncidenciasVacacionesTab>
    with AutomaticKeepAliveClientMixin {
  final _motivoCtrl = TextEditingController();
  final _misSolicitudesScrollCtrl = ScrollController();

  DateTimeRange? _selectedRange;
  int? _selectedTipoId;
  String? _evidenciaUrl;
  String? _evidenciaNombre;
  bool _busy = false;
  bool _adminModeValidated = false;
  int? _updatingSolicitudId;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _misSolicitudesScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _selectedRange ??
        DateTimeRange(start: now, end: now.add(const Duration(days: 1)));
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() => _selectedRange = picked);
  }

  Future<void> _uploadEvidence() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final api = ref.read(relojChecadorAppApiProvider);
      final url = await api.uploadEvidenciaIncidencia(
        filePath: file.path,
        bytes: file.bytes,
        fileName: file.name,
      );

      if (!mounted) return;
      setState(() {
        _evidenciaUrl = url;
        _evidenciaNombre = file.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidencia cargada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo subir evidencia: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSolicitud({
    required int colaboradorId,
    required int tipoId,
  }) async {
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona rango de fechas')),
      );
      return;
    }
    if (_selectedRange!.end.isBefore(_selectedRange!.start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('fecha_fin no puede ser menor que fecha_inicio'),
        ),
      );
      return;
    }
    final solicitudes = ref.read(solicitudesIncidenciasProvider).valueOrNull ?? const <SolicitudIncidenciaModel>[];
    final tieneCruceAprobado = solicitudes.any((s) {
      final isAprobado = s.estatus.trim().toUpperCase() == 'APROBADO';
      final sameColab = s.colaboradorId == colaboradorId;
      if (!isAprobado || !sameColab) return false;
      return _rangesOverlap(
        _selectedRange!.start,
        _selectedRange!.end,
        s.fechaInicio,
        s.fechaFin,
      );
    });
    if (tieneCruceAprobado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe solicitud aprobada en ese rango'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      await api.createSolicitudIncidencia(
        SolicitudIncidenciaCreateRequest(
          colaboradorId: colaboradorId,
          tipoId: tipoId,
          fechaInicio: _selectedRange!.start,
          fechaFin: _selectedRange!.end,
          motivo: _motivoCtrl.text.trim().isEmpty
              ? null
              : _motivoCtrl.text.trim(),
          evidenciaUrl: (_evidenciaUrl ?? '').trim().isEmpty
              ? null
              : _evidenciaUrl!.trim(),
        ),
      );

      ref.invalidate(solicitudesIncidenciasProvider);
      ref.invalidate(ausenciasCalendarioProvider);
      ref.invalidate(vacacionesDashboardProvider(colaboradorId));
      ref.invalidate(asistenciaReporteProvider);
      ref.invalidate(reporteSolicitudesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud enviada')));
      setState(() {
        _motivoCtrl.clear();
        _selectedRange = null;
        _evidenciaUrl = null;
        _evidenciaNombre = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _aprobarSolicitudRapida(SolicitudIncidenciaModel row) async {
    await _updateSolicitudEstado(row, 'APROBADO');
  }

  Future<void> _rechazarSolicitudRapida(SolicitudIncidenciaModel row) async {
    await _updateSolicitudEstado(row, 'RECHAZADO');
  }

  Future<bool> _ensureAdminModeValidated() async {
    if (_adminModeValidated) return true;
    final ctrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Validar acceso admin'),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Clave RRHH',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final ok = ctrl.text.trim() == 'RRHH_SECRET';
                  Navigator.of(dialogContext).pop(ok);
                },
                child: const Text('Validar'),
              ),
            ],
          );
        },
      );
      if (!mounted) return false;
      if (ok == true) {
        setState(() => _adminModeValidated = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modo admin habilitado')),
        );
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clave incorrecta')),
      );
      return false;
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _updateSolicitudEstado(
    SolicitudIncidenciaModel row,
    String estatus,
  ) async {
    if (_busy) return;
    final adminOk = await _ensureAdminModeValidated();
    if (!mounted) return;
    if (!adminOk) return;

    final estatusTarget = estatus.trim().toUpperCase();
    if (estatusTarget == 'APROBADO') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          var dialogLoading = false;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Confirmación'),
              content: const Text('¿Estás seguro de aprobar esta solicitud?'),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: dialogLoading
                      ? null
                      : () {
                          setDialogState(() => dialogLoading = true);
                          Navigator.of(dialogContext).pop(true);
                        },
                  child: dialogLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aprobar'),
                ),
              ],
            ),
          );
        },
      );
      if (!mounted) return;
      if (confirmed != true) return;
    }

    setState(() => _updatingSolicitudId = row.id);
    try {
      final api = ref.read(relojChecadorAppApiProvider);
      await api.updateSolicitudIncidenciaEstatus(
        solicitudId: row.id,
        estatus: estatusTarget,
      );
      if (!mounted) return;
      final label = estatusTarget == 'APROBADO'
          ? 'aprobada'
          : 'rechazada';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud #${row.id} $label')),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(solicitudesIncidenciasProvider);
        ref.invalidate(ausenciasCalendarioProvider);
        ref.invalidate(reporteSolicitudesProvider);
        ref.invalidate(asistenciaReporteProvider);
        if (row.colaboradorId > 0) {
          ref.invalidate(vacacionesDashboardProvider(row.colaboradorId));
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    } finally {
      if (mounted) setState(() => _updatingSolicitudId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colaboradoresAsync = ref.watch(colaboradoresLiveProvider);
    final tiposAsync = ref.watch(permisosTiposProvider);
    final solicitudesAsync = ref.watch(solicitudesIncidenciasProvider);
    final ausenciasAsync = ref.watch(ausenciasCalendarioProvider);
    final selectedColaboradorId = ref.watch(incidenciasColaboradorProvider);

    final colaboradores =
        colaboradoresAsync.valueOrNull ?? const <ColaboradorGestionModel>[];
    final selectedId =
        selectedColaboradorId ??
        (colaboradores.isNotEmpty ? colaboradores.first.id : null);
    final selectedColab = selectedId == null
        ? null
        : colaboradores.where((item) => item.id == selectedId).isEmpty
        ? null
        : colaboradores.where((item) => item.id == selectedId).first;

    if (selectedId != null && selectedColaboradorId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(incidenciasColaboradorProvider.notifier).state = selectedId;
      });
    }

    final dashboardAsync = selectedId == null
        ? const AsyncValue<VacacionesDashboardModel>.loading()
        : ref.watch(vacacionesDashboardProvider(selectedId));

    final hasRange = _selectedRange != null;
    final isRangeValid =
        _selectedRange == null ||
        !_selectedRange!.end.isBefore(_selectedRange!.start);
    final canSubmit =
        !_busy &&
        selectedId != null &&
        _selectedTipoId != null &&
        hasRange &&
        isRangeValid;

    final width = MediaQuery.sizeOf(context).width;
    final isCompactTablet = width < 1300;

    Widget calendarCard(double height) {
      return SizedBox(
        height: height,
        child: Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ausenciasAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Center(
                        child: Text('Sin incidencias registradas'),
                      ),
                      data: (events) {
                        final selectedDay = _selectedDay ?? DateTime.now();
                        final sameDayEvents = events
                            .where(
                              (e) => _isDateInRange(
                                selectedDay,
                                e.fechaInicio,
                                e.fechaFin,
                              ),
                            )
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calendario de Ausencias Aprobadas',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TableCalendar<AusenciaCalendarioItem>(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2100, 12, 31),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              eventLoader: (day) => events
                                  .where(
                                    (e) =>
                                        _isDateInRange(day, e.fechaInicio, e.fechaFin),
                                  )
                                  .toList(),
                              calendarStyle: const CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color: Color(0xFF4DB6AC),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: Color(0xFF1A237E),
                                  shape: BoxShape.circle,
                                ),
                                markerDecoration: BoxDecoration(
                                  color: Color(0xFFE65100),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: sameDayEvents.isEmpty
                                  ? const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Sin incidencias registradas'),
                                    )
                                  : ListView.separated(
                                      itemCount: sameDayEvents.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 10),
                                      itemBuilder: (context, index) {
                                        final row = sameDayEvents[index];
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.event_busy),
                                          title: Text(
                                            '${row.pin} - ${row.colaboradorNombre}',
                                          ),
                                          subtitle: Text(
                                            '${row.tipoNombre} (${_dateIso(row.fechaInicio)} a ${_dateIso(row.fechaFin)})',
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    Widget solicitudesCard(double height) {
      return SizedBox(
        height: height,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: solicitudesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Sin incidencias registradas'),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('Sin incidencias registradas'),
                  );
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      dense: true,
                      title: Text('${row.pin} - ${row.colaboradorNombre}'),
                      subtitle: Text(
                        '${row.tipoNombre} | ${_dateIso(row.fechaInicio)} - ${_dateIso(row.fechaFin)}'
                        '${(row.motivo ?? '').isNotEmpty ? '\n${row.motivo}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (row.estatus.trim().toUpperCase() == 'PENDIENTE')
                            IconButton(
                              tooltip: 'Aprobar',
                              onPressed: _updatingSolicitudId != null
                                  ? null
                                  : () => _aprobarSolicitudRapida(row),
                              icon: _updatingSolicitudId == row.id
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2E7D32),
                                    ),
                            ),
                          _StatusChip(estatus: row.estatus),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    }

    final calendarHeight = isCompactTablet ? 520.0 : 560.0;
    final solicitudesHeight = isCompactTablet ? 340.0 : 560.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: width < 980 ? width - 84 : 320,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: selectedId,
                        decoration: const InputDecoration(
                          labelText: 'Colaborador',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: colaboradores
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.idEmpleado.trim().isEmpty ? c.pin : c.idEmpleado} - ${c.nombreCompleto}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  ref
                                          .read(
                                            incidenciasColaboradorProvider
                                                .notifier,
                                          )
                                          .state =
                                      value,
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: tiposAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('Error tipos'),
                        data: (tipos) {
                          final initial =
                              _selectedTipoId ??
                              (tipos.isNotEmpty ? tipos.first.id : null);
                          if (_selectedTipoId == null && tipos.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() => _selectedTipoId = tipos.first.id);
                            });
                          }
                          return DropdownButtonFormField<int>(
                            initialValue: initial,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de permiso',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: tipos
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text(t.nombre),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _selectedTipoId = value),
                          );
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedRange == null
                            ? 'Seleccionar rango'
                            : '${_dateIso(_selectedRange!.start)} a ${_dateIso(_selectedRange!.end)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _uploadEvidence,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _evidenciaUrl == null
                            ? 'Subir evidencia'
                            : 'Evidencia lista',
                      ),
                    ),
                    if (_evidenciaUrl != null)
                      Chip(
                        label: Text(
                          _evidenciaNombre == null
                              ? 'Archivo adjunto'
                              : 'Adjunto: $_evidenciaNombre',
                        ),
                        onDeleted: _busy
                            ? null
                            : () => setState(() {
                                _evidenciaUrl = null;
                                _evidenciaNombre = null;
                              }),
                      ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _motivoCtrl,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Motivo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: canSubmit
                          ? () => _saveSolicitud(
                              colaboradorId: selectedId,
                              tipoId: _selectedTipoId!,
                            )
                          : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Enviar Solicitud'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis Solicitudes',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _ensureAdminModeValidated,
                          icon: Icon(
                            _adminModeValidated
                                ? Icons.verified_user
                                : Icons.admin_panel_settings_outlined,
                          ),
                          label: Text(
                            _adminModeValidated
                                ? 'Admin validado'
                                : 'Validar admin',
                          ),
                        ),
                        if (!_adminModeValidated)
                          const Text(
                            'Aprobar/Rechazar visible solo con acceso admin',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    solicitudesAsync.when(
                      loading: () =>
                          const LinearProgressIndicator(minHeight: 2),
                      error: (_, _) =>
                          const Text('No se pudo cargar Mis Solicitudes'),
                      data: (rows) {
                        final mine = rows
                            .where(
                              (r) => selectedId != null && r.colaboradorId == selectedId,
                            )
                            .toList(growable: false);
                        if (mine.isEmpty) {
                          return const Text('Sin solicitudes registradas');
                        }
                        return SizedBox(
                          height: 320,
                          child: Scrollbar(
                            controller: _misSolicitudesScrollCtrl,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _misSolicitudesScrollCtrl,
                              itemCount: mine.length,
                              separatorBuilder: (_, _) => const Divider(height: 10),
                              itemBuilder: (context, index) {
                                final row = mine[index];
                                final pendiente =
                                    row.estatus.trim().toUpperCase() == 'PENDIENTE';
                                final updating = _updatingSolicitudId == row.id;
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.assignment_outlined),
                                  title: Text(
                                    row.tipoNombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Fechas: ${_dateIso(row.fechaInicio)} a ${_dateIso(row.fechaFin)}\n'
                                    'Motivo: ${(row.motivo ?? '').trim().isEmpty ? 'Sin motivo' : row.motivo!.trim()}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_adminModeValidated && pendiente) ...[
                                        IconButton(
                                          tooltip: 'APROBAR',
                                          onPressed: updating
                                              ? null
                                              : (_updatingSolicitudId != null)
                                              ? null
                                              : () => _aprobarSolicitudRapida(row),
                                          icon: const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'RECHAZAR',
                                          onPressed: updating
                                              ? null
                                              : (_updatingSolicitudId != null)
                                              ? null
                                              : () => _rechazarSolicitudRapida(row),
                                          icon: const Icon(
                                            Icons.cancel,
                                            color: Color(0xFFC62828),
                                          ),
                                        ),
                                      ],
                                      if (updating)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        _StatusChip(estatus: row.estatus),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            dashboardAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (_, _) =>
                  const Text('No se pudo calcular dashboard de vacaciones'),
              data: (data) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    title: 'Días Disponibles',
                    value: '${data.diasDisponibles}',
                    color: const Color(0xFF1B5E20),
                  ),
                  _MetricCard(
                    title: 'Días Tomados',
                    value: '${data.diasTomados}',
                    color: const Color(0xFFBF360C),
                  ),
                  _MetricCard(
                    title: 'Próximas Vacaciones',
                    value: '${data.proximasVacaciones.length}',
                    color: const Color(0xFF0D47A1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!isCompactTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: calendarCard(calendarHeight)),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: solicitudesCard(solicitudesHeight)),
                ],
              )
            else ...[
              calendarCard(calendarHeight),
              const SizedBox(height: 12),
              solicitudesCard(solicitudesHeight),
            ],
            if (selectedColab != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Empleado: ${selectedColab.pin} - ${selectedColab.nombreCompleto}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4D8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.estatus});

  final String estatus;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (estatus == 'APROBADO') {
      color = const Color(0xFF2E7D32);
    } else if (estatus == 'RECHAZADO') {
      color = const Color(0xFFC62828);
    } else {
      color = const Color(0xFFEF6C00);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        estatus,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

bool _isDateInRange(DateTime day, DateTime start, DateTime end) {
  final d = DateTime(day.year, day.month, day.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

bool _rangesOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  final as = DateTime(aStart.year, aStart.month, aStart.day);
  final ae = DateTime(aEnd.year, aEnd.month, aEnd.day);
  final bs = DateTime(bStart.year, bStart.month, bStart.day);
  final be = DateTime(bEnd.year, bEnd.month, bEnd.day);
  return !ae.isBefore(bs) && !be.isBefore(as);
}

String _dateIso(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _dioMessage(DioException e) {
  final status = e.response?.statusCode ?? 0;
  if (status == 500) {
    return 'Error de servidor: No se pudo actualizar el estatus. Revise la conexión con la base de datos.';
  }
  final data = e.response?.data;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  if ((e.message ?? '').trim().isNotEmpty) return e.message!.trim();
  return 'Error de red';
}
