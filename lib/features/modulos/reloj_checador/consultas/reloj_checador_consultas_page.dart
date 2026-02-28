import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/auth/auth_controller.dart';

import 'download_helper.dart';
import 'reloj_checador_consultas_models.dart';
import 'reloj_checador_consultas_providers.dart';

class RelojChecadorConsultasPage extends ConsumerStatefulWidget {
  const RelojChecadorConsultasPage({super.key});

  @override
  ConsumerState<RelojChecadorConsultasPage> createState() =>
      _RelojChecadorConsultasPageState();
}

class _RelojChecadorConsultasPageState
    extends ConsumerState<RelojChecadorConsultasPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _timelogSucCtrl = TextEditingController();
  final _timelogUserCtrl = TextEditingController();
  final _timelogFromCtrl = TextEditingController();
  final _timelogToCtrl = TextEditingController();

  final _incSucCtrl = TextEditingController();
  final _incUserCtrl = TextEditingController();

  final _docSucCtrl = TextEditingController();
  final _docUserCtrl = TextEditingController();
  final _docIncCtrl = TextEditingController();

  final _ovrSucCtrl = TextEditingController();
  final _ovrUserCtrl = TextEditingController();

  final _policySucCtrl = TextEditingController();
  final _policyDeptoCtrl = TextEditingController();
  final _policyEarlyCtrl = TextEditingController(text: '15');
  final _policyLateCtrl = TextEditingController(text: '15');
  final _policyLatCtrl = TextEditingController();
  final _policyLonCtrl = TextEditingController();
  final _policyRadiusCtrl = TextEditingController();
  final _policyGpsMaxCtrl = TextEditingController(text: '50');
  final _policyShiftStartCtrl = TextEditingController();
  final _policyShiftEndCtrl = TextEditingController();
  final _policyLunchStartCtrl = TextEditingController();
  final _policyLunchEndCtrl = TextEditingController();
  final _policyOtDailyCtrl = TextEditingController(text: '3');
  final _policyOtWeeklyCtrl = TextEditingController(text: '9');

  bool _policyRequireGps = false;
  bool _policyRequireLiveness = false;
  bool _policyEnforceWindows = false;
  bool _policyActive = true;

  bool _loadingTimelogs = false;
  bool _loadingIncidencias = false;
  bool _loadingDocumentos = false;
  bool _loadingOverrides = false;
  bool _loadingPolicy = false;

  List<TimelogItem> _timelogs = const [];
  List<IncidenciaItem> _incidencias = const [];
  List<DocumentoItem> _documentos = const [];
  List<OverrideItem> _overrides = const [];

  bool _canManage = false;
  bool _canPolicy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
      await _loadTimelogs();
      await _loadIncidencias();
      await _loadDocumentos();
      await _loadOverrides();
    });
  }

  Future<void> _bootstrap() async {
    final auth = ref.read(authControllerProvider);
    if ((auth.username ?? '').trim().isNotEmpty) {
      _policySucCtrl.text = _timelogSucCtrl.text;
    }

    try {
      final canManage = await ref.read(
        relojChecadorCanManageOverridesProvider.future,
      );
      if (!mounted) return;
      setState(() => _canManage = canManage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _canManage = false);
    }

    if (_canManage) {
      await _detectPolicyPermission();
    }
  }

  Future<void> _detectPolicyPermission() async {
    final api = ref.read(relojChecadorConsultasApiProvider);
    final suc = (_policySucCtrl.text.trim().isEmpty)
        ? (_timelogSucCtrl.text.trim())
        : _policySucCtrl.text.trim();
    if (suc.isEmpty) {
      setState(() => _canPolicy = false);
      return;
    }

    try {
      final canPolicy = await api.canManagePolicies(suc: suc);
      if (!mounted) return;
      setState(() => _canPolicy = canPolicy);
      if (canPolicy) {
        await _loadPolicy();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _canPolicy = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timelogSucCtrl.dispose();
    _timelogUserCtrl.dispose();
    _timelogFromCtrl.dispose();
    _timelogToCtrl.dispose();
    _incSucCtrl.dispose();
    _incUserCtrl.dispose();
    _docSucCtrl.dispose();
    _docUserCtrl.dispose();
    _docIncCtrl.dispose();
    _ovrSucCtrl.dispose();
    _ovrUserCtrl.dispose();
    _policySucCtrl.dispose();
    _policyDeptoCtrl.dispose();
    _policyEarlyCtrl.dispose();
    _policyLateCtrl.dispose();
    _policyLatCtrl.dispose();
    _policyLonCtrl.dispose();
    _policyRadiusCtrl.dispose();
    _policyGpsMaxCtrl.dispose();
    _policyShiftStartCtrl.dispose();
    _policyShiftEndCtrl.dispose();
    _policyLunchStartCtrl.dispose();
    _policyLunchEndCtrl.dispose();
    _policyOtDailyCtrl.dispose();
    _policyOtWeeklyCtrl.dispose();
    super.dispose();
  }

  bool get _isAdmin => ref.read(authControllerProvider).roleId == 1;

  Future<void> _loadTimelogs() async {
    setState(() => _loadingTimelogs = true);
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      final res = await api.listTimelogs(
        TimelogFilters(
          suc: _timelogSucCtrl.text.trim().isEmpty
              ? null
              : _timelogSucCtrl.text.trim(),
          idUsuario: int.tryParse(_timelogUserCtrl.text.trim()),
          dateFrom: _timelogFromCtrl.text.trim().isEmpty
              ? null
              : _timelogFromCtrl.text.trim(),
          dateTo: _timelogToCtrl.text.trim().isEmpty
              ? null
              : _timelogToCtrl.text.trim(),
          page: 1,
          limit: 100,
        ),
      );
      if (!mounted) return;
      setState(() => _timelogs = res.items);
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudieron cargar timelogs: ${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() => _loadingTimelogs = false);
      }
    }
  }

  Future<void> _loadIncidencias() async {
    setState(() => _loadingIncidencias = true);
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      final res = await api.listIncidencias(
        suc: _incSucCtrl.text.trim().isEmpty ? null : _incSucCtrl.text.trim(),
        idUsuario: int.tryParse(_incUserCtrl.text.trim()),
        page: 1,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _incidencias = res.items);
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudieron cargar incidencias: ${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() => _loadingIncidencias = false);
      }
    }
  }

  Future<void> _loadDocumentos() async {
    setState(() => _loadingDocumentos = true);
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      final res = await api.listDocumentos(
        suc: _docSucCtrl.text.trim().isEmpty ? null : _docSucCtrl.text.trim(),
        userId: int.tryParse(_docUserCtrl.text.trim()),
        incId: int.tryParse(_docIncCtrl.text.trim()),
        page: 1,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _documentos = res.items);
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudieron cargar documentos: ${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() => _loadingDocumentos = false);
      }
    }
  }

  Future<void> _loadOverrides() async {
    if (!_canManage) return;
    setState(() => _loadingOverrides = true);
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      final res = await api.listOverrides(
        suc: _ovrSucCtrl.text.trim().isEmpty ? null : _ovrSucCtrl.text.trim(),
        idUsuario: int.tryParse(_ovrUserCtrl.text.trim()),
        activeOnly: false,
        page: 1,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _overrides = res.items);
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudieron cargar overrides: ${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() => _loadingOverrides = false);
      }
    }
  }

  Future<void> _loadPolicy() async {
    if (!_canPolicy) return;
    final suc = _policySucCtrl.text.trim();
    if (suc.isEmpty) {
      _showError('Captura SUC para cargar policy');
      return;
    }

    setState(() => _loadingPolicy = true);
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      final policy = await api.getPolicy(
        suc: suc,
        idDepto: int.tryParse(_policyDeptoCtrl.text.trim()),
      );
      if (!mounted) return;

      setState(() {
        _policyEarlyCtrl.text = policy.allowEarlyMin.toString();
        _policyLateCtrl.text = policy.allowLateMin.toString();
        _policyRequireGps = policy.requireGps;
        _policyLatCtrl.text = policy.geofenceLat?.toString() ?? '';
        _policyLonCtrl.text = policy.geofenceLon?.toString() ?? '';
        _policyRadiusCtrl.text = policy.geofenceRadiusM?.toString() ?? '';
        _policyGpsMaxCtrl.text = policy.gpsMaxAccuracyM.toString();
        _policyRequireLiveness = policy.requireLiveness;
        _policyEnforceWindows = policy.enforceWindows;
        _policyShiftStartCtrl.text = policy.shiftStart ?? '';
        _policyShiftEndCtrl.text = policy.shiftEnd ?? '';
        _policyLunchStartCtrl.text = policy.lunchStart ?? '';
        _policyLunchEndCtrl.text = policy.lunchEnd ?? '';
        _policyOtDailyCtrl.text = policy.overtimeDailyLimit.toString();
        _policyOtWeeklyCtrl.text = policy.overtimeWeeklyLimit.toString();
      });
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo cargar policy: ${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() => _loadingPolicy = false);
      }
    }
  }

  Future<void> _savePolicy() async {
    final suc = _policySucCtrl.text.trim();
    if (suc.isEmpty) {
      _showError('SUC es requerida para guardar policy');
      return;
    }

    setState(() => _loadingPolicy = true);
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      await api.upsertPolicy({
        'SUC': suc,
        if (_policyDeptoCtrl.text.trim().isNotEmpty)
          'IDDEPTO': int.parse(_policyDeptoCtrl.text.trim()),
        'ALLOW_EARLY_MIN': int.tryParse(_policyEarlyCtrl.text.trim()) ?? 15,
        'ALLOW_LATE_MIN': int.tryParse(_policyLateCtrl.text.trim()) ?? 15,
        'REQUIRE_GPS': _policyRequireGps ? 1 : 0,
        if (_policyLatCtrl.text.trim().isNotEmpty)
          'GEOFENCE_LAT': double.parse(_policyLatCtrl.text.trim()),
        if (_policyLonCtrl.text.trim().isNotEmpty)
          'GEOFENCE_LON': double.parse(_policyLonCtrl.text.trim()),
        if (_policyRadiusCtrl.text.trim().isNotEmpty)
          'GEOFENCE_RADIUS_M': int.parse(_policyRadiusCtrl.text.trim()),
        'GPS_MAX_ACCURACY_M': int.tryParse(_policyGpsMaxCtrl.text.trim()) ?? 50,
        'REQUIRE_LIVENESS': _policyRequireLiveness ? 1 : 0,
        if (_policyShiftStartCtrl.text.trim().isNotEmpty)
          'SHIFT_START': _policyShiftStartCtrl.text.trim(),
        if (_policyShiftEndCtrl.text.trim().isNotEmpty)
          'SHIFT_END': _policyShiftEndCtrl.text.trim(),
        if (_policyLunchStartCtrl.text.trim().isNotEmpty)
          'LUNCH_START': _policyLunchStartCtrl.text.trim(),
        if (_policyLunchEndCtrl.text.trim().isNotEmpty)
          'LUNCH_END': _policyLunchEndCtrl.text.trim(),
        'ENFORCE_WINDOWS': _policyEnforceWindows ? 1 : 0,
        'OVERTIME_DAILY_LIMIT_HOURS':
            double.tryParse(_policyOtDailyCtrl.text.trim()) ?? 3,
        'OVERTIME_WEEKLY_LIMIT_HOURS':
            double.tryParse(_policyOtWeeklyCtrl.text.trim()) ?? 9,
        'ACTIVE': _policyActive ? 1 : 0,
      });

      if (!mounted) return;
      _showOk('Policy guardada correctamente');
      await _loadPolicy();
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo guardar policy: ${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() => _loadingPolicy = false);
      }
    }
  }

  Future<void> _openCreateIncidenciaDialog() async {
    String tipo = 'VACACIONES';
    final motivoCtrl = TextEditingController();
    final sucCtrl = TextEditingController(text: _incSucCtrl.text.trim());
    final userCtrl = TextEditingController(text: _incUserCtrl.text.trim());
    DateTime ini = DateTime.now();
    DateTime fin = DateTime.now();

    Future<void> pickDate(bool isStart, StateSetter setModal) async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: isStart ? ini : fin,
      );
      if (picked == null) return;
      setModal(() {
        if (isStart) {
          ini = picked;
          if (fin.isBefore(ini)) fin = ini;
        } else {
          fin = picked;
        }
      });
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return AlertDialog(
              title: const Text('Nueva incidencia'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: tipo,
                        items:
                            const [
                                  'VACACIONES',
                                  'PERMISO_GOCE',
                                  'PERMISO_SIN_GOCE',
                                  'INCAPACIDAD',
                                  'FALTA',
                                  'RETARDO',
                                  'OTRO',
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setModal(() => tipo = v ?? tipo),
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => pickDate(true, setModal),
                              child: Text('Inicio: ${_fmtDate(ini)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => pickDate(false, setModal),
                              child: Text('Fin: ${_fmtDate(fin)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: motivoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sucCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SUC (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: userCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'IDUSUARIO (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final api = ref.read(relojChecadorConsultasApiProvider);
                      await api.createIncidencia({
                        'TIPO': tipo,
                        'FECHA_INI': _fmtDateApi(ini),
                        'FECHA_FIN': _fmtDateApi(fin),
                        if (motivoCtrl.text.trim().isNotEmpty)
                          'MOTIVO': motivoCtrl.text.trim(),
                        if (sucCtrl.text.trim().isNotEmpty)
                          'SUC': sucCtrl.text.trim(),
                        if (userCtrl.text.trim().isNotEmpty)
                          'IDUSUARIO': int.parse(userCtrl.text.trim()),
                      });
                      if (!mounted) return;
                      Navigator.of(this.context).pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      _showError('Error al crear incidencia: ${_errorText(e)}');
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    motivoCtrl.dispose();
    sucCtrl.dispose();
    userCtrl.dispose();

    if (created == true) {
      _showOk('Incidencia creada');
      await _loadIncidencias();
    }
  }

  Future<void> _updateIncidenciaStatus(String idInc, String estatus) async {
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      await api.updateIncidenciaStatus(idInc, {'ESTATUS': estatus});
      if (!mounted) return;
      _showOk('Incidencia actualizada: $estatus');
      await _loadIncidencias();
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo actualizar incidencia: ${_errorText(e)}');
    }
  }

  Future<void> _openUploadDocumentoDialog() async {
    final sucCtrl = TextEditingController(text: _docSucCtrl.text.trim());
    final userCtrl = TextEditingController(text: _docUserCtrl.text.trim());
    final incCtrl = TextEditingController(text: _docIncCtrl.text.trim());
    String tipo = 'JUSTIFICANTE';
    PlatformFile? picked;

    final uploaded = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return AlertDialog(
              title: const Text('Subir documento'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: tipo,
                        items:
                            const [
                                  'EXPEDIENTE',
                                  'JUSTIFICANTE',
                                  'INE',
                                  'CONTRATO',
                                  'OTRO',
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setModal(() => tipo = v ?? tipo),
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sucCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SUC (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: userCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'IDUSUARIO (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: incCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'IDINC (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: const [
                              'pdf',
                              'png',
                              'jpg',
                              'jpeg',
                              'webp',
                            ],
                          );
                          if (res == null || res.files.isEmpty) return;
                          setModal(() => picked = res.files.first);
                        },
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Seleccionar archivo'),
                      ),
                      if (picked != null)
                        Text(
                          '${picked!.name} (${picked!.size} bytes)',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: picked == null
                      ? null
                      : () async {
                          try {
                            final bytes = picked!.bytes;
                            if (bytes == null || bytes.isEmpty) {
                              _showError('Archivo sin bytes para subir');
                              return;
                            }

                            final api = ref.read(
                              relojChecadorConsultasApiProvider,
                            );
                            await api.uploadDocumento({
                              'TIPO': tipo,
                              'FILE_NAME': picked!.name,
                              'MIME_TYPE': picked!.extension == 'pdf'
                                  ? 'application/pdf'
                                  : 'image/${picked!.extension ?? 'jpeg'}',
                              'CONTENT_BASE64': base64Encode(bytes),
                              if (sucCtrl.text.trim().isNotEmpty)
                                'SUC': sucCtrl.text.trim(),
                              if (userCtrl.text.trim().isNotEmpty)
                                'IDUSUARIO': int.parse(userCtrl.text.trim()),
                              if (incCtrl.text.trim().isNotEmpty)
                                'IDINC': int.parse(incCtrl.text.trim()),
                            });

                            if (!mounted) return;
                            Navigator.of(this.context).pop(true);
                          } catch (e) {
                            if (!mounted) return;
                            _showError(
                              'No se pudo subir documento: ${_errorText(e)}',
                            );
                          }
                        },
                  child: const Text('Subir'),
                ),
              ],
            );
          },
        );
      },
    );

    sucCtrl.dispose();
    userCtrl.dispose();
    incCtrl.dispose();

    if (uploaded == true) {
      _showOk('Documento cargado');
      await _loadDocumentos();
    }
  }

  Future<void> _downloadDocumento(DocumentoItem doc) async {
    try {
      final api = ref.read(relojChecadorConsultasApiProvider);
      final downloaded = await api.downloadDocumento(doc.idDoc);
      final bytes = downloaded['bytes'] as dynamic;
      final mime = downloaded['mimeType'] as String? ?? doc.mimeType;

      if (!supportsDownload) {
        _showError('Descarga disponible en web para este MVP');
        return;
      }

      await saveBytesFile(bytes, doc.fileName, mime);
      if (!mounted) return;
      _showOk('Descarga iniciada: ${doc.fileName}');
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo descargar: ${_errorText(e)}');
    }
  }

  Future<void> _openCreateOverrideDialog() async {
    final userCtrl = TextEditingController(text: _ovrUserCtrl.text.trim());
    final sucCtrl = TextEditingController(text: _ovrSucCtrl.text.trim());
    final reasonCtrl = TextEditingController();
    String tipo = 'OUT_OF_WINDOW';
    DateTime validUntil = DateTime.now().add(const Duration(hours: 2));

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return AlertDialog(
              title: const Text('Crear override'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: userCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'IDUSUARIO',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sucCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SUC (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const [
                                'OUT_OF_WINDOW',
                                'OUT_OF_GEOFENCE',
                                'SEQUENCE_OVERRIDE',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) => setModal(() => tipo = v ?? tipo),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Razon',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate: validUntil,
                        );
                        if (date == null) return;
                        if (!context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(validUntil),
                        );
                        if (time == null) return;
                        setModal(() {
                          validUntil = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: Text('Vence: ${_fmtDateTime(validUntil)}'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final userId = int.tryParse(userCtrl.text.trim());
                      if (userId == null || userId <= 0) {
                        _showError('IDUSUARIO invalido');
                        return;
                      }
                      if (reasonCtrl.text.trim().isEmpty) {
                        _showError('Captura razon del override');
                        return;
                      }

                      final api = ref.read(relojChecadorConsultasApiProvider);
                      await api.createOverride({
                        'IDUSUARIO': userId,
                        if (sucCtrl.text.trim().isNotEmpty)
                          'SUC': sucCtrl.text.trim(),
                        'TIPO': tipo,
                        'REASON': reasonCtrl.text.trim(),
                        'VALID_UNTIL': validUntil.toUtc().toIso8601String(),
                      });

                      if (!mounted) return;
                      Navigator.of(this.context).pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      _showError('No se pudo crear override: ${_errorText(e)}');
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    userCtrl.dispose();
    sucCtrl.dispose();
    reasonCtrl.dispose();

    if (created == true) {
      _showOk('Override creado');
      await _loadOverrides();
    }
  }

  Future<void> _revokeOverride(OverrideItem item) async {
    final reasonCtrl = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revocar override'),
          content: TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Razon de revocacion',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Revocar'),
            ),
          ],
        );
      },
    );

    if (accepted != true) {
      reasonCtrl.dispose();
      return;
    }

    try {
      final reason = reasonCtrl.text.trim();
      if (reason.isEmpty) {
        _showError('Captura razon para revocar');
        return;
      }

      final api = ref.read(relojChecadorConsultasApiProvider);
      await api.revokeOverride(item.idOvr, reason);
      if (!mounted) return;
      _showOk('Override revocado');
      await _loadOverrides();
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo revocar override: ${_errorText(e)}');
    } finally {
      reasonCtrl.dispose();
    }
  }

  void _showOk(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reloj checador - Consultas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Timelogs'),
            Tab(text: 'Incidencias'),
            Tab(text: 'Documentos'),
            Tab(text: 'Policy/Overrides'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelogsTab(),
          _buildIncidenciasTab(),
          _buildDocumentosTab(),
          _buildPolicyOverridesTab(),
        ],
      ),
    );
  }

  Widget _buildTimelogsTab() {
    return Column(
      children: [
        _filtersCard(
          title: 'Filtros timelogs',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _input(_timelogSucCtrl, 'SUC', width: 130),
              _input(_timelogUserCtrl, 'IDUSUARIO', width: 130, isNumber: true),
              _input(_timelogFromCtrl, 'Desde YYYY-MM-DD', width: 160),
              _input(_timelogToCtrl, 'Hasta YYYY-MM-DD', width: 160),
              FilledButton.icon(
                onPressed: _loadingTimelogs ? null : _loadTimelogs,
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
              OutlinedButton.icon(
                onPressed: _loadingTimelogs
                    ? null
                    : () {
                        _timelogSucCtrl.clear();
                        _timelogUserCtrl.clear();
                        _timelogFromCtrl.clear();
                        _timelogToCtrl.clear();
                        _loadTimelogs();
                      },
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingTimelogs
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _timelogs.length,
                  itemBuilder: (context, index) {
                    final item = _timelogs[index];
                    return ListTile(
                      title: Text('${item.tipo} - ${item.suc}'),
                      subtitle: Text(
                        '${item.username ?? '-'} (${item.idUsuario ?? '-'}) | ${_fmtDateTime(item.fcnr)}',
                      ),
                      trailing: _isAdmin
                          ? IconButton(
                              tooltip: 'Correccion admin',
                              icon: const Icon(Icons.edit_note),
                              onPressed: () => _openTimelogCorrection(item),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildIncidenciasTab() {
    return Column(
      children: [
        _filtersCard(
          title: 'Incidencias',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _input(_incSucCtrl, 'SUC', width: 130),
              _input(_incUserCtrl, 'IDUSUARIO', width: 130, isNumber: true),
              FilledButton.icon(
                onPressed: _loadingIncidencias ? null : _loadIncidencias,
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
              OutlinedButton.icon(
                onPressed: _openCreateIncidenciaDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nueva incidencia'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingIncidencias
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _incidencias.length,
                  itemBuilder: (context, index) {
                    final item = _incidencias[index];
                    return ListTile(
                      title: Text('${item.tipo} - ${item.estatus}'),
                      subtitle: Text(
                        '${item.suc} | ${item.username ?? item.idUsuario ?? '-'} | ${_fmtDate(item.fechaIni)} - ${_fmtDate(item.fechaFin)}',
                      ),
                      trailing: _canManage
                          ? PopupMenuButton<String>(
                              onSelected: (v) =>
                                  _updateIncidenciaStatus(item.idInc, v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'APROBADA',
                                  child: Text('Aprobar'),
                                ),
                                PopupMenuItem(
                                  value: 'RECHAZADA',
                                  child: Text('Rechazar'),
                                ),
                                PopupMenuItem(
                                  value: 'CERRADA',
                                  child: Text('Cerrar'),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDocumentosTab() {
    return Column(
      children: [
        _filtersCard(
          title: 'Documentos',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _input(_docSucCtrl, 'SUC', width: 130),
              _input(_docUserCtrl, 'IDUSUARIO', width: 130, isNumber: true),
              _input(_docIncCtrl, 'IDINC', width: 130, isNumber: true),
              FilledButton.icon(
                onPressed: _loadingDocumentos ? null : _loadDocumentos,
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
              OutlinedButton.icon(
                onPressed: _openUploadDocumentoDialog,
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingDocumentos
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _documentos.length,
                  itemBuilder: (context, index) {
                    final doc = _documentos[index];
                    return ListTile(
                      title: Text(doc.fileName),
                      subtitle: Text(
                        '${doc.tipo} | ${doc.suc} | ${doc.fileSize} bytes',
                      ),
                      trailing: IconButton(
                        onPressed: () => _downloadDocumento(doc),
                        icon: const Icon(Icons.download),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPolicyOverridesTab() {
    if (!_canManage) {
      return const Center(
        child: Text('No tienes permisos para policies/overrides.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_canPolicy)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Policy (solo admin)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _input(_policySucCtrl, 'SUC', width: 130),
                      _input(
                        _policyDeptoCtrl,
                        'IDDEPTO',
                        width: 130,
                        isNumber: true,
                      ),
                      _input(
                        _policyEarlyCtrl,
                        'Early min',
                        width: 120,
                        isNumber: true,
                      ),
                      _input(
                        _policyLateCtrl,
                        'Late min',
                        width: 120,
                        isNumber: true,
                      ),
                      _input(_policyLatCtrl, 'GEOFENCE LAT', width: 140),
                      _input(_policyLonCtrl, 'GEOFENCE LON', width: 140),
                      _input(
                        _policyRadiusCtrl,
                        'Radius m',
                        width: 120,
                        isNumber: true,
                      ),
                      _input(
                        _policyGpsMaxCtrl,
                        'GPS max m',
                        width: 120,
                        isNumber: true,
                      ),
                      _input(_policyShiftStartCtrl, 'SHIFT_START', width: 120),
                      _input(_policyShiftEndCtrl, 'SHIFT_END', width: 120),
                      _input(_policyLunchStartCtrl, 'LUNCH_START', width: 120),
                      _input(_policyLunchEndCtrl, 'LUNCH_END', width: 120),
                      _input(_policyOtDailyCtrl, 'OT diario', width: 110),
                      _input(_policyOtWeeklyCtrl, 'OT semanal', width: 110),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('REQUIRE_GPS'),
                    value: _policyRequireGps,
                    onChanged: (v) => setState(() => _policyRequireGps = v),
                  ),
                  SwitchListTile(
                    title: const Text('REQUIRE_LIVENESS'),
                    value: _policyRequireLiveness,
                    onChanged: (v) =>
                        setState(() => _policyRequireLiveness = v),
                  ),
                  SwitchListTile(
                    title: const Text('ENFORCE_WINDOWS'),
                    value: _policyEnforceWindows,
                    onChanged: (v) => setState(() => _policyEnforceWindows = v),
                  ),
                  SwitchListTile(
                    title: const Text('ACTIVE'),
                    value: _policyActive,
                    onChanged: (v) => setState(() => _policyActive = v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _loadingPolicy ? null : _loadPolicy,
                        icon: const Icon(Icons.download),
                        label: const Text('Cargar'),
                      ),
                      FilledButton.icon(
                        onPressed: _loadingPolicy ? null : _savePolicy,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Policy no disponible para este rol.'),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overrides',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _input(_ovrSucCtrl, 'SUC', width: 130),
                    _input(
                      _ovrUserCtrl,
                      'IDUSUARIO',
                      width: 130,
                      isNumber: true,
                    ),
                    FilledButton.icon(
                      onPressed: _loadingOverrides ? null : _loadOverrides,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openCreateOverrideDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear override'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingOverrides)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._overrides.map(
                    (item) => ListTile(
                      title: Text('${item.tipo} - ${item.suc}'),
                      subtitle: Text(
                        'Usr ${item.idUsuario ?? '-'} | ${item.reason} | vence ${_fmtDateTime(item.validUntil)}',
                      ),
                      trailing: item.isActive
                          ? IconButton(
                              icon: const Icon(Icons.block),
                              onPressed: () => _revokeOverride(item),
                            )
                          : const Icon(Icons.check_circle_outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTimelogCorrection(TimelogItem item) async {
    final tipoValues = const [
      'ENTRADA',
      'SALIDA_COMER',
      'REGRESO_COMER',
      'SALIDA',
    ];

    var tipo = item.tipo.toUpperCase();
    if (!tipoValues.contains(tipo)) {
      tipo = 'ENTRADA';
    }

    final notesCtrl = TextEditingController(text: item.notes ?? '');
    final reasonCtrl = TextEditingController();
    final fcnrCtrl = TextEditingController(
      text: item.fcnr == null ? '' : _fmtDateTimeInput(item.fcnr!),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return AlertDialog(
              title: const Text('Correccion admin'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: tipo,
                        items: tipoValues
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModal(() => tipo = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fcnrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'FCNR (YYYY-MM-DD HH:mm o ISO)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Reason (requerido)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final reason = reasonCtrl.text.trim();
                      if (reason.isEmpty) {
                        _showError('Reason es requerido');
                        return;
                      }

                      final payload = <String, dynamic>{
                        'TIPO': tipo,
                        'REASON': reason,
                      };

                      final fcnrText = fcnrCtrl.text.trim();
                      if (fcnrText.isNotEmpty) {
                        final parsed = _parseDateTimeInput(fcnrText);
                        if (parsed == null) {
                          _showError('Formato FCNR invalido');
                          return;
                        }
                        payload['FCNR'] = parsed.toUtc().toIso8601String();
                      }

                      final notes = notesCtrl.text.trim();
                      payload['NOTES'] = notes.isEmpty ? null : notes;

                      final api = ref.read(relojChecadorConsultasApiProvider);
                      await api.updateTimelog(item.idTimelog, payload);

                      if (!mounted) return;
                      Navigator.of(this.context).pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      _showError(
                        'No se pudo corregir timelog: ${_errorText(e)}',
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    notesCtrl.dispose();
    reasonCtrl.dispose();
    fcnrCtrl.dispose();

    if (saved == true) {
      _showOk('Timelog corregido');
      await _loadTimelogs();
    }
  }

  Widget _filtersCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    double width = 140,
    bool isNumber = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              )
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  String _errorText(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final message = map['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      final message = error.message;
      if ((message ?? '').trim().isNotEmpty) {
        return message!.trim();
      }
    }
    return error.toString();
  }
}

String _fmtDate(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _fmtDateApi(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _fmtDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String _fmtDateTimeInput(DateTime value) {
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

DateTime? _parseDateTimeInput(String text) {
  final raw = text.trim();
  if (raw.isEmpty) return null;
  final isoCandidate = raw.replaceFirst(' ', 'T');
  return DateTime.tryParse(isoCandidate) ?? DateTime.tryParse(raw);
}
