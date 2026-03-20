import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'package:ioe_app/features/masterdata/users/users_models.dart';
import 'package:ioe_app/features/masterdata/users/users_providers.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../pagos_servicios/ps_models.dart';
import '../cotizaciones/cotizaciones_models.dart';
import '../cotizaciones/pago/pago_cotizacion_models.dart';
import '../devoluciones/devoluciones_models.dart';
import 'reimpresion_models.dart';
import 'reimpresion_providers.dart';

enum _ReimpresionTicketModule {
  cotizacion,
  devolucion,
  pagoServicios,
  desconocido,
}

class ReimpresionPage extends ConsumerStatefulWidget {
  const ReimpresionPage({super.key});

  @override
  ConsumerState<ReimpresionPage> createState() => _ReimpresionPageState();
}

class _ReimpresionPageState extends ConsumerState<ReimpresionPage> {
  final _searchCtrl = TextEditingController();
  final _opvCtrl = TextEditingController();
  final _sucCtrl = TextEditingController();
  final _fcnmCtrl = TextEditingController();
  String _userSuc = '';
  String _userOpv = '';
  bool _isAdminUser = false;
  bool _contextReady = false;
  bool _authorizationRequestedOnEntry = false;
  bool _authorizing = false;
  bool _printingTicket = false;
  PvCtrFolAsvrModel? _selected;
  ReimpresionPanelQuery _query = const ReimpresionPanelQuery();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(reimpresionAuthSessionProvider.notifier).state = null;
      await _initializeContext();
      await _requestAuthorizationOnEntry();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _opvCtrl.dispose();
    _sucCtrl.dispose();
    _fcnmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_contextReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final usersAsync = _isAdminUser
        ? ref.watch(usersListProvider)
        : const AsyncData<List<UserModel>>(<UserModel>[]);
    final sucursalesAsync = _isAdminUser
        ? ref.watch(sucursalesListProvider)
        : const AsyncData<List<SucursalModel>>(<SucursalModel>[]);
    final users = usersAsync.asData?.value ?? const <UserModel>[];
    final sucursales = sucursalesAsync.asData?.value ?? const <SucursalModel>[];
    final sucursalOptions = _buildSucursalOptions(sucursales);
    if (_isAdminUser &&
        !usersAsync.isLoading &&
        !sucursalesAsync.isLoading &&
        !usersAsync.hasError &&
        !sucursalesAsync.hasError) {
      _syncAdminSelection(sucursalOptions: sucursalOptions, users: users);
    }
    final opvOptions = _buildOpvOptions(users, _sucCtrl.text);
    final adminCatalogLoading = _isAdminUser &&
        (usersAsync.isLoading || sucursalesAsync.isLoading);
    final adminCatalogError =
        usersAsync.asError?.error ?? sucursalesAsync.asError?.error;

    final authSession = ref.watch(reimpresionAuthSessionProvider);
    final query = ref.watch(reimpresionPanelQueryProvider);
    final reimpresionesAsync = ref.watch(reimpresionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reimpresion de ticket'),
        actions: [
          IconButton(
            onPressed: _authorizing ? null : _refreshList,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: reimpresionesAsync.when(
          data: (pageResult) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TopFilters(
                opvCtrl: _opvCtrl,
                sucCtrl: _sucCtrl,
                fcnmCtrl: _fcnmCtrl,
                searchCtrl: _searchCtrl,
                onPickFcnm: _pickFcnm,
                onSearch: _applyFilters,
                onClear: _clearFilters,
                authorizing: _authorizing,
                lockSucOpv: !_isAdminUser,
                isAdmin: _isAdminUser,
                adminCatalogLoading: adminCatalogLoading,
                adminCatalogError: adminCatalogError,
                selectedSucursal: _sucCtrl.text.trim().toUpperCase(),
                selectedOpv: _opvCtrl.text.trim().toUpperCase(),
                sucursalOptions: sucursalOptions,
                opvOptions: opvOptions,
                onSucursalChanged: (value) =>
                    _onAdminSucursalChanged(value, users),
                onOpvChanged: _onAdminOpvChanged,
              ),
              const SizedBox(height: 12),
              if (authSession == null) const _AuthorizationPendingBlock(),
              if (authSession != null && !query.hasCriteria)
                const _SearchRequiredBlock(),
              if (authSession != null &&
                  query.hasCriteria &&
                  pageResult.data.isEmpty)
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Sin resultados para los filtros capturados.'),
                  ),
                ),
              if (authSession != null &&
                  query.hasCriteria &&
                  pageResult.data.isNotEmpty) ...[
                _ReimpresionTable(
                  folios: pageResult.data,
                  selected: _selected,
                  onSelect: (folio) {
                    _onSelectRow(folio);
                  },
                ),
                const SizedBox(height: 8),
                _PaginationBar(
                  result: pageResult,
                  onPrev: () => _goToPage(pageResult.page - 1),
                  onNext: () => _goToPage(pageResult.page + 1),
                ),
              ],
            ],
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TopFilters(
                opvCtrl: _opvCtrl,
                sucCtrl: _sucCtrl,
                fcnmCtrl: _fcnmCtrl,
                searchCtrl: _searchCtrl,
                onPickFcnm: _pickFcnm,
                onSearch: _applyFilters,
                onClear: _clearFilters,
                authorizing: _authorizing,
                lockSucOpv: !_isAdminUser,
                isAdmin: _isAdminUser,
                adminCatalogLoading: adminCatalogLoading,
                adminCatalogError: adminCatalogError,
                selectedSucursal: _sucCtrl.text.trim().toUpperCase(),
                selectedOpv: _opvCtrl.text.trim().toUpperCase(),
                sucursalOptions: sucursalOptions,
                opvOptions: opvOptions,
                onSucursalChanged: (value) =>
                    _onAdminSucursalChanged(value, users),
                onOpvChanged: _onAdminOpvChanged,
              ),
              const SizedBox(height: 12),
              _ErrorBlock(
                message: _errorMessage(e),
                onRetry: _refreshList,
              ),
            ],
          ),
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TopFilters(
                opvCtrl: _opvCtrl,
                sucCtrl: _sucCtrl,
                fcnmCtrl: _fcnmCtrl,
                searchCtrl: _searchCtrl,
                onPickFcnm: _pickFcnm,
                onSearch: _applyFilters,
                onClear: _clearFilters,
                authorizing: _authorizing,
                lockSucOpv: !_isAdminUser,
                isAdmin: _isAdminUser,
                adminCatalogLoading: adminCatalogLoading,
                adminCatalogError: adminCatalogError,
                selectedSucursal: _sucCtrl.text.trim().toUpperCase(),
                selectedOpv: _opvCtrl.text.trim().toUpperCase(),
                sucursalOptions: sucursalOptions,
                opvOptions: opvOptions,
                onSucursalChanged: (value) =>
                    _onAdminSucursalChanged(value, users),
                onOpvChanged: _onAdminOpvChanged,
              ),
              const SizedBox(height: 12),
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeContext() async {
    final today = _todayYmd();
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();

    var suc = '';
    var opv = '';
    var isAdminUser = false;
    if (token != null && token.isNotEmpty) {
      final payload = _decodeJwt(token);
      suc = (payload['suc'] ?? payload['SUC'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      opv = (payload['opv'] ?? payload['OPV'] ?? payload['username'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final roleId = int.tryParse(
        (payload['roleId'] ?? payload['ROLEID'] ?? payload['IDROL'] ?? '')
            .toString()
            .trim(),
      );
      final username = (payload['username'] ?? payload['USERNAME'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final roleCode = (payload['roleCode'] ??
              payload['ROLECODE'] ??
              payload['rolCodigo'] ??
              payload['ROLCODIGO'] ??
              '')
          .toString()
          .trim()
          .toUpperCase();
      isAdminUser = roleId == 1 || username == 'ADMIN' || roleCode == 'ADMIN';
    }

    if (!mounted) return;

    _sucCtrl.text = suc;
    _opvCtrl.text = opv;
    _fcnmCtrl.text = today;
    final next = ReimpresionPanelQuery(
      suc: suc,
      opv: opv,
      fcnm: today,
      page: 1,
      pageSize: 20,
    );
    ref.read(reimpresionPanelQueryProvider.notifier).state = next;
    setState(() {
      _userSuc = suc;
      _userOpv = opv;
      _isAdminUser = isAdminUser;
      _query = next;
      _contextReady = true;
    });
  }

  void _syncAdminSelection({
    required List<_FilterSelectOption> sucursalOptions,
    required List<UserModel> users,
  }) {
    if (!_isAdminUser || sucursalOptions.isEmpty) return;

    var selectedSuc = _sucCtrl.text.trim().toUpperCase();
    if (!sucursalOptions.any((item) => item.value == selectedSuc)) {
      selectedSuc = sucursalOptions.first.value;
    }

    final opvOptions = _buildOpvOptions(users, selectedSuc);
    final currentOpv = _opvCtrl.text.trim().toUpperCase();
    var selectedOpv = currentOpv;
    if (!opvOptions.any((item) => item.value == selectedOpv)) {
      final preferredOpv = _userOpv.trim().toUpperCase();
      if (preferredOpv.isNotEmpty &&
          opvOptions.any((item) => item.value == preferredOpv)) {
        selectedOpv = preferredOpv;
      } else {
        selectedOpv = opvOptions.isNotEmpty ? opvOptions.first.value : '';
      }
    }

    final needsUpdate =
        selectedSuc != _sucCtrl.text.trim().toUpperCase() ||
        selectedOpv != currentOpv;
    if (!needsUpdate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _sucCtrl.text = selectedSuc;
        _opvCtrl.text = selectedOpv;
      });
    });
  }

  void _onAdminSucursalChanged(String? value, List<UserModel> users) {
    if (!_isAdminUser || value == null) return;
    final suc = value.trim().toUpperCase();
    final options = _buildOpvOptions(users, suc);
    final current = _opvCtrl.text.trim().toUpperCase();
    String nextOpv = '';
    if (options.any((item) => item.value == current)) {
      nextOpv = current;
    } else if (options.isNotEmpty) {
      nextOpv = options.first.value;
    }
    setState(() {
      _sucCtrl.text = suc;
      _opvCtrl.text = nextOpv;
      _selected = null;
    });
  }

  void _onAdminOpvChanged(String? value) {
    if (!_isAdminUser || value == null) return;
    setState(() {
      _opvCtrl.text = value.trim().toUpperCase();
      _selected = null;
    });
  }

  List<_FilterSelectOption> _buildSucursalOptions(
    List<SucursalModel> sucursales,
  ) {
    final options = <_FilterSelectOption>[];
    for (final sucursal in sucursales) {
      final suc = sucursal.suc.trim().toUpperCase();
      if (suc.isEmpty) continue;
      final desc = (sucursal.desc ?? '').trim();
      final label = desc.isEmpty ? suc : '$suc - $desc';
      options.add(_FilterSelectOption(value: suc, label: label));
    }
    options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  List<_FilterSelectOption> _buildOpvOptions(List<UserModel> users, String suc) {
    final sucNorm = suc.trim().toUpperCase();
    if (sucNorm.isEmpty) return const [];
    final byOpv = <String, _FilterSelectOption>{};

    for (final user in users) {
      final userSuc = (user.suc ?? '').trim().toUpperCase();
      if (userSuc != sucNorm) continue;
      if (!_isActivo(user)) continue;
      if (!_isOpvOrSupervisor(user)) continue;

      final username = user.username.trim().toUpperCase();
      if (username.isEmpty || byOpv.containsKey(username)) continue;

      final display = user.displayName.trim();
      final role = _roleLabel(user);
      final label = display.isEmpty || display.toUpperCase() == username
          ? '$username · $role'
          : '$username - $display · $role';
      byOpv[username] = _FilterSelectOption(value: username, label: label);
    }

    final options = byOpv.values.toList(growable: false);
    options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  bool _isOpvOrSupervisor(UserModel user) {
    final role =
        '${user.rolCodigo ?? ''} ${user.rolNombre ?? ''}'.trim().toUpperCase();
    if (role.isEmpty) return false;
    return role.contains('OPV') ||
        role.contains('SUPERVISOR') ||
        role.contains('SUPERPV');
  }

  bool _isActivo(UserModel user) {
    final estatus = user.estatus.trim().toUpperCase();
    if (estatus.isEmpty) return true;
    return estatus == 'ACTIVO' ||
        estatus == 'A' ||
        estatus == '1' ||
        estatus == 'TRUE';
  }

  String _roleLabel(UserModel user) {
    final code = (user.rolCodigo ?? '').trim();
    final name = (user.rolNombre ?? '').trim();
    if (name.isNotEmpty &&
        code.isNotEmpty &&
        name.toUpperCase() != code.toUpperCase()) {
      return '$code/$name';
    }
    final value = name.isNotEmpty ? name : code;
    return value.isEmpty ? 'ROL' : value.toUpperCase();
  }

  Future<void> _requestAuthorizationOnEntry() async {
    if (!mounted) return;
    if (_authorizationRequestedOnEntry) return;
    _authorizationRequestedOnEntry = true;
    await _startAuthorization(closeIfCancelled: true);
  }

  Future<void> _startAuthorization({required bool closeIfCancelled}) async {
    final passwordSupervisor = await _showAuthorizationDialog();
    if (!mounted) return;

    if (passwordSupervisor == null) {
      if (closeIfCancelled) {
        context.go('/punto-venta');
      }
      return;
    }

    setState(() => _authorizing = true);
    try {
      final session = await ref
          .read(reimpresionApiProvider)
          .autorizarSupervisor(passwordSupervisor: passwordSupervisor);
      if (!mounted) return;
      ref.read(reimpresionAuthSessionProvider.notifier).state = session;
      ref.invalidate(reimpresionListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autorizacion de supervisor correcta.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No autorizado'),
          content: Text(_errorMessage(error)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (closeIfCancelled && _isAuthorizationError(error)) {
        await _startAuthorization(closeIfCancelled: true);
      }
    } finally {
      if (mounted) {
        setState(() => _authorizing = false);
      }
    }
  }

  Future<String?> _showAuthorizationDialog() async {
    if (!mounted) return null;

    var passwordValue = '';
    String? validationError;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: const Text('Autorizacion supervisor'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Capture la contrasena de un usuario con rol SUPERVISOR.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        passwordValue = value;
                        if (validationError != null) {
                          setLocalState(() {
                            validationError = null;
                          });
                        }
                      },
                      onSubmitted: (submitted) {
                        final value = submitted.trim();
                        if (value.isEmpty) {
                          setLocalState(() {
                            validationError = 'La contrasena es obligatoria.';
                          });
                          return;
                        }
                        Navigator.of(ctx).pop(value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Contrasena supervisor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final value = passwordValue.trim();
                  if (value.isEmpty) {
                    setLocalState(() {
                      validationError = 'La contrasena es obligatoria.';
                    });
                    return;
                  }
                  Navigator.of(ctx).pop(value);
                },
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  void _applyFilters() {
    final fcnmText = _fcnmCtrl.text.trim();
    if (fcnmText.isNotEmpty && _parseSqlDate(fcnmText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FCNM invalido. Use formato YYYY-MM-DD.'),
        ),
      );
      return;
    }

    final suc = _isAdminUser
        ? _sucCtrl.text.trim().toUpperCase()
        : _userSuc.trim().toUpperCase();
    final opv = _isAdminUser
        ? _opvCtrl.text.trim().toUpperCase()
        : _userOpv.trim().toUpperCase();
    final next = ReimpresionPanelQuery(
      suc: suc,
      opv: opv,
      search: _searchCtrl.text.trim(),
      fcnm: fcnmText,
      page: 1,
      pageSize: 20,
    );
    setState(() {
      _selected = null;
      _query = next;
    });
    ref.read(reimpresionPanelQueryProvider.notifier).state = next;
    ref.invalidate(reimpresionListProvider);
  }

  void _clearFilters() {
    final today = _todayYmd();
    final suc = _isAdminUser
        ? _sucCtrl.text.trim().toUpperCase()
        : _userSuc.trim().toUpperCase();
    final opv = _isAdminUser
        ? _opvCtrl.text.trim().toUpperCase()
        : _userOpv.trim().toUpperCase();
    setState(() {
      _searchCtrl.clear();
      _sucCtrl.text = suc;
      _opvCtrl.text = opv;
      _fcnmCtrl.text = today;
      _selected = null;
      _query = ReimpresionPanelQuery(
        suc: suc,
        opv: opv,
        fcnm: today,
        page: 1,
        pageSize: 20,
      );
    });
    ref.read(reimpresionPanelQueryProvider.notifier).state = _query;
    ref.invalidate(reimpresionListProvider);
  }

  Future<void> _pickFcnm() async {
    final current = _parseSqlDate(_fcnmCtrl.text.trim()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Fecha FCNM',
    );
    if (!mounted) return;
    if (picked == null) return;

    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    _fcnmCtrl.text = '$y-$m-$d';
  }

  Future<void> _refreshList() async {
    final session = ref.read(reimpresionAuthSessionProvider);
    if (session == null) {
      await _startAuthorization(closeIfCancelled: true);
      return;
    }
    ref.invalidate(reimpresionListProvider);
    try {
      await ref.read(reimpresionListProvider.future);
    } catch (error) {
      if (!mounted) return;
      if (_isAuthorizationError(error)) {
        ref.read(reimpresionAuthSessionProvider.notifier).state = null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    }
  }

  void _goToPage(int nextPage) {
    if (nextPage < 1) return;
    final updated = _query.copyWith(page: nextPage);
    setState(() {
      _selected = null;
      _query = updated;
    });
    ref.read(reimpresionPanelQueryProvider.notifier).state = updated;
    ref.invalidate(reimpresionListProvider);
  }

  DateTime? _parseSqlDate(String value) {
    final text = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
    final parts = text.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    return parsed;
  }

  String _todayYmd() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _onSelectRow(PvCtrFolAsvrModel row) async {
    if (_printingTicket || _authorizing) return;
    setState(() => _selected = row);

    final widthMm = await _selectTicketWidth(context);
    if (!mounted || widthMm == null) return;

    setState(() => _printingTicket = true);
    try {
      await _printPreviewForRow(row, widthMm: widthMm);
    } catch (error) {
      if (!mounted) return;
      final detail = apiErrorMessage(
        error,
        fallback: 'No se pudo obtener la vista previa de impresiÃ³n.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reimprimir ${row.idfol}: $detail')),
      );
    } finally {
      if (mounted) {
        setState(() => _printingTicket = false);
      }
    }
  }

  Future<void> _printPreviewForRow(
    PvCtrFolAsvrModel row, {
    required double widthMm,
  }) async {
    final candidates = _moduleCandidates(row);
    Object? lastError;
    for (final module in candidates) {
      try {
        switch (module) {
          case _ReimpresionTicketModule.cotizacion:
            await _printCotizacionTicket(row.idfol, widthMm: widthMm);
            return;
          case _ReimpresionTicketModule.devolucion:
            await _printDevolucionTicket(row.idfol, widthMm: widthMm);
            return;
          case _ReimpresionTicketModule.pagoServicios:
            await _printPagoServiciosTicket(row.idfol, widthMm: widthMm);
            return;
          case _ReimpresionTicketModule.desconocido:
            break;
        }
      } catch (error) {
        lastError = error;
        if (!_canTryNextModule(error)) {
          rethrow;
        }
      }
    }

    if (lastError != null) throw lastError;
    throw StateError('No se pudo resolver mÃ³dulo de impresiÃ³n para ${row.idfol}.');
  }

  bool _canTryNextModule(Object error) {
    final msg = apiErrorMessage(error, fallback: '').toLowerCase();
    return msg.contains('404') ||
        msg.contains('no existe') ||
        msg.contains('not found') ||
        msg.contains('folio') && msg.contains('no ');
  }

  List<_ReimpresionTicketModule> _moduleCandidates(PvCtrFolAsvrModel row) {
    final inferred = _resolveTicketModule(row);
    final ordered = <_ReimpresionTicketModule>[
      if (inferred != _ReimpresionTicketModule.desconocido) inferred,
      _ReimpresionTicketModule.cotizacion,
      _ReimpresionTicketModule.devolucion,
      _ReimpresionTicketModule.pagoServicios,
    ];
    final seen = <_ReimpresionTicketModule>{};
    return ordered.where((item) => seen.add(item)).toList(growable: false);
  }

  _ReimpresionTicketModule _resolveTicketModule(PvCtrFolAsvrModel row) {
    final aut = (row.aut ?? '').trim().toUpperCase();
    if (aut == 'DCA' || aut == 'DVF') return _ReimpresionTicketModule.devolucion;
    if (aut == 'CA' || aut == 'VF' || aut == 'CP') {
      return _ReimpresionTicketModule.cotizacion;
    }
    if (aut == 'PS' ||
        aut == 'AD' ||
        aut == 'AP' ||
        aut == 'CR' ||
        aut == 'DC' ||
        aut == 'DG') {
      return _ReimpresionTicketModule.pagoServicios;
    }

    final idfol = row.idfol.trim().toUpperCase();
    if (idfol.contains('-DCA-') || idfol.contains('-DVF-')) {
      return _ReimpresionTicketModule.devolucion;
    }
    if (idfol.contains('-PS-')) {
      return _ReimpresionTicketModule.pagoServicios;
    }
    return _ReimpresionTicketModule.desconocido;
  }

  Future<void> _printCotizacionTicket(
    String idfol, {
    required double widthMm,
  }) async {
    final preview = await ref.read(reimpresionApiProvider).fetchCotizacionPrintPreview(
          idfol,
        );
    final nonCashFormas = preview.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);
    final doc = _buildCotizacionTicketPdfExact(preview, widthMm: widthMm);
    await Printing.layoutPdf(
      name: 'cotizacion_${preview.idfol}.pdf',
      onLayout: (_) async => doc.save(),
    );
    if (!mounted || nonCashFormas.isEmpty) return;
    final openVoucher = await _confirmOpenVoucherPreview(context);
    if (!mounted || !openVoucher) return;
    final voucherDoc = _buildCotizacionVoucherPdfExact(
      preview,
      widthMm: widthMm,
      nonCashFormas: nonCashFormas,
    );
    await Printing.layoutPdf(
      name: 'cotizacion_${preview.idfol}_voucher.pdf',
      onLayout: (_) async => voucherDoc.save(),
    );
  }

  Future<void> _printDevolucionTicket(
    String idfol, {
    required double widthMm,
  }) async {
    final preview = await ref.read(reimpresionApiProvider).fetchDevolucionPrintPreview(
          idfol,
        );
    final nonCashFormas = preview.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);
    final doc = _buildDevolucionTicketPdfExact(preview, widthMm: widthMm);
    await Printing.layoutPdf(
      name: 'devolucion_${preview.idfolDev}.pdf',
      onLayout: (_) async => doc.save(),
    );
    if (!mounted || nonCashFormas.isEmpty) return;
    final openVoucher = await _confirmOpenVoucherPreview(context);
    if (!mounted || !openVoucher) return;
    final voucherDoc = _buildDevolucionVoucherPdfExact(
      preview,
      widthMm: widthMm,
      nonCashFormas: nonCashFormas,
    );
    await Printing.layoutPdf(
      name: 'devolucion_${preview.idfolDev}_voucher.pdf',
      onLayout: (_) async => voucherDoc.save(),
    );
  }

  Future<void> _printPagoServiciosTicket(
    String idfol, {
    required double widthMm,
  }) async {
    final api = ref.read(reimpresionApiProvider);
    final summary = await api.fetchPsSummary(idfol);
    PsDetalleResponse? detalle;
    try {
      detalle = await api.fetchPsDetalle(idfol);
    } catch (_) {
      detalle = null;
    }
    final nonCashFormas = summary.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);
    final doc = _buildPsTicketPdfExact(
      summary: summary,
      detalle: detalle,
      widthMm: widthMm,
    );
    await Printing.layoutPdf(
      name: 'ps_${summary.idfol}.pdf',
      onLayout: (_) async => doc.save(),
    );
    if (!mounted || nonCashFormas.isEmpty) return;
    final openVoucher = await _confirmOpenVoucherPreview(context);
    if (!mounted || !openVoucher) return;
    final voucherDoc = _buildPsVoucherPdfExact(
      summary: summary,
      detalle: detalle,
      widthMm: widthMm,
      nonCashFormas: nonCashFormas,
    );
    await Printing.layoutPdf(
      name: 'ps_${summary.idfol}_voucher.pdf',
      onLayout: (_) async => voucherDoc.save(),
    );
  }

  Future<bool> _confirmOpenVoucherPreview(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Abrir voucher'),
          content: const Text(
            'Se cerrÃ³ la vista previa del ticket. Â¿Desea abrir ahora la vista previa del voucher?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('SÃ­'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<double?> _selectTicketWidth(BuildContext context) {
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecciona ancho de impresion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('58 mm (ticket compacto)'),
              onTap: () => Navigator.of(ctx).pop(58.0),
            ),
            ListTile(
              title: const Text('80 mm (ticket estandar)'),
              onTap: () => Navigator.of(ctx).pop(80.0),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  pw.Document _buildCotizacionTicketPdfExact(
    PagoCierrePrintPreviewResponse data, {
    required double widthMm,
  }) {
    final doc = pw.Document();
    final header = data.header;
    final totals = data.totals;
    final footer = data.footer;

    final widthPt = _mmToPt(widthMm);
    final pageHeightMm = _estimateCotizacionTicketHeightMmExact(data, widthMm);
    final leftMarginPt = _mmToPt(2);
    final pageFormat = PdfPageFormat(widthPt, _mmToPt(pageHeightMm), marginAll: 0);
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final isCotizacionAbierta = totals.tipotran.trim().toUpperCase() == 'CA';
    final nonCashFormas = data.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);

    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'SUC: ${header.suc}  ${header.desc ?? ''}'.trim(),
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          if ((header.direccion ?? '').isNotEmpty)
            pw.Text(header.direccion!, style: pw.TextStyle(fontSize: smallFontSize)),
          if ((header.contacto ?? '').isNotEmpty)
            pw.Text('Contacto: ${header.contacto}', style: pw.TextStyle(fontSize: smallFontSize)),
          if ((header.rfc ?? '').isNotEmpty)
            pw.Text('RFC: ${header.rfc}', style: pw.TextStyle(fontSize: smallFontSize)),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'DETALLE',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          if (data.items.isEmpty)
            pw.Text('Sin articulos registrados', style: pw.TextStyle(fontSize: smallFontSize))
          else
            ...[
              for (var i = 0; i < data.items.length; i++)
                _buildCotizacionTicketDetalleItemExact(
                  data.items[i],
                  index: i,
                  baseFontSize: baseFontSize,
                  smallFontSize: smallFontSize,
                ),
            ],
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'TOTALES',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          _ticketRowExact('Total base', _money(totals.totalBase), baseFontSize),
          if (!isCotizacionAbierta) ...[
            _ticketRowExact('Subtotal', _money(totals.subtotal), baseFontSize),
            _ticketRowExact('IVA', _money(totals.iva), baseFontSize),
            _ticketRowExact('Total final', _money(totals.total), baseFontSize),
            _ticketRowExact('Pagos', _money(totals.sumPagos), baseFontSize),
            _ticketRowExact('Faltante', _money(totals.faltante), baseFontSize),
            _ticketRowExact('Cambio', _money(totals.cambio), baseFontSize),
          ],
          if (!isCotizacionAbierta) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'FORMAS',
              style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
            ),
            if (data.formas.isEmpty)
              pw.Text('Sin formas de pago', style: pw.TextStyle(fontSize: smallFontSize))
            else
              ...data.formas.map((f) {
                final ref = (f.aut ?? '').trim();
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _ticketRowExact(f.form, _money(f.impp), baseFontSize),
                    if (ref.isNotEmpty)
                      pw.Text('REF: $ref', style: pw.TextStyle(fontSize: smallFontSize)),
                  ],
                );
              }),
            pw.SizedBox(height: 4),
          ],
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'TRANSACCION',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('OPV: ${opvLabel.isEmpty ? '-' : opvLabel}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('IDFOLIO: ${footer.idfol}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('FCNM: ${_fmtDateTime(footer.fcnm)}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text(
            'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toString() ?? '-'})',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'RESUMEN DE ORDS',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          if (data.ords.isEmpty)
            pw.Text('Sin ORDs ligadas', style: pw.TextStyle(fontSize: smallFontSize))
          else
            ...data.ords.map((ord) {
              final ordUpc = _resolveCotizacionOrdUpcExact(ord, data.items);
              final ordDesc = (ord.desc ?? '').trim();
              return pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORD: ${ord.iord}', style: pw.TextStyle(fontSize: baseFontSize)),
                    pw.Text(
                      'DES: ${ordDesc.isEmpty ? '-' : ordDesc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                    pw.Text(
                      'UPC: ${ordUpc.isEmpty ? '-' : ordUpc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                  ],
                ),
              );
            }),
          if (nonCashFormas.isNotEmpty)
            pw.Text(
              'GRACIAS POR SU CONFIANZA',
              style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
    return doc;
  }

  pw.Document _buildCotizacionVoucherPdfExact(
    PagoCierrePrintPreviewResponse data, {
    required double widthMm,
    required List<PagoCierrePrintForma> nonCashFormas,
  }) {
    final doc = pw.Document();
    if (nonCashFormas.isEmpty) return doc;

    final header = data.header;
    final footer = data.footer;
    final widthPt = _mmToPt(widthMm);
    final pageHeightMm = _estimateVoucherHeightMmExact(
      voucherCount: nonCashFormas.length,
      widthMm: widthMm,
    );
    final leftMarginPt = _mmToPt(2);
    final pageFormat = PdfPageFormat(widthPt, _mmToPt(pageHeightMm), marginAll: 0);
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          ...nonCashFormas.map(
            (forma) => _buildCotizacionVoucherSectionExact(
              forma: forma,
              idfol: footer.idfol,
              suc: header.suc,
              clienteNombre: footer.clienteNombre,
              clienteId: footer.clienteId?.toString(),
              tra: null,
              fecha: forma.fcn ?? footer.fcnm,
              baseFontSize: baseFontSize,
              smallFontSize: smallFontSize,
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _buildCotizacionTicketDetalleItemExact(
    PagoCierrePrintItem item, {
    required int index,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final name = (item.des ?? item.art ?? '-').trim();
    final qty = item.ctd.toStringAsFixed(2);
    final unit = _money(item.pvta);
    final imp = _money(item.importe);
    final upc = (item.upc ?? '').trim();
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        color: index.isEven ? PdfColors.white : PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('UPC: ${upc.isEmpty ? '-' : upc}', style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text('$qty x $unit = $imp', style: pw.TextStyle(fontSize: smallFontSize)),
        ],
      ),
    );
  }

  pw.Widget _buildCotizacionVoucherSectionExact({
    required PagoCierrePrintForma forma,
    required String idfol,
    required String suc,
    required String? clienteNombre,
    required String? clienteId,
    required String? tra,
    required DateTime? fecha,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final form = forma.form.trim().isEmpty ? '-' : forma.form.trim().toUpperCase();
    final impd = _money(forma.impp);
    final autRef = (forma.aut ?? '').trim().isEmpty ? '-' : forma.aut!.trim();
    final clienteNom = (clienteNombre ?? '').trim().isEmpty ? '-' : clienteNombre!.trim();
    final clienteCodigo = (clienteId ?? '').trim().isEmpty ? '-' : clienteId!.trim();
    final traValue = (tra ?? '').trim().isEmpty ? '-' : tra!.trim();

    pw.Widget lineText(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1, bottom: 1),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: smallFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildVoucherCutLineExact(smallFontSize: smallFontSize),
          pw.Text('VOUCHER', style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(
            'SOPORTE RECEPCION\nPAGO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Detalle', style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold)),
          lineText('FORM   $form'),
          lineText('IMPD   $impd'),
          lineText('AUT o REF   $autRef'),
          pw.SizedBox(height: 6),
          lineText('Nombre de cliente   $clienteNom'),
          lineText('IDC   $clienteCodigo'),
          lineText('FCN   ${_fmtDateTime(fecha)}'),
          pw.SizedBox(height: 16),
          lineText('____________________________'),
          lineText('Firma cliente'),
          lineText('SUC   $suc   TRA   $traValue'),
          lineText('IDFOL   $idfol', bold: true),
        ],
      ),
    );
  }

  double _estimateCotizacionTicketHeightMmExact(
    PagoCierrePrintPreviewResponse data,
    double widthMm,
  ) {
    final is58 = widthMm <= 58;
    final charsPerLine = is58 ? 28 : 34;
    final lineMm = is58 ? 3.3 : 3.9;
    final isCotizacionAbierta = data.totals.tipotran.trim().toUpperCase() == 'CA';
    final footer = data.footer;
    double mm = 0;

    mm += 6;
    mm += _measureTextHeightMmExact(
      'SUC: ${data.header.suc}  ${data.header.desc ?? ''}'.trim(),
      charsPerLine,
      lineMm,
    );
    if ((data.header.direccion ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMmExact(data.header.direccion!, charsPerLine, lineMm);
    }
    if ((data.header.contacto ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMmExact('Contacto: ${data.header.contacto}', charsPerLine, lineMm);
    }
    if ((data.header.rfc ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMmExact('RFC: ${data.header.rfc}', charsPerLine, lineMm);
    }

    mm += 8;
    if (data.items.isEmpty) {
      mm += lineMm;
    } else {
      for (final item in data.items) {
        final name = (item.des ?? item.art ?? '-').trim();
        final upc = (item.upc ?? '').trim();
        mm += _measureTextHeightMmExact(name, charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('UPC: ${upc.isEmpty ? '-' : upc}', charsPerLine, lineMm);
        mm += lineMm;
        mm += 1.4;
      }
    }

    mm += 8;
    mm += lineMm;
    if (!isCotizacionAbierta) {
      mm += lineMm * 6;
      mm += 5;
      if (data.formas.isEmpty) {
        mm += lineMm;
      } else {
        for (final f in data.formas) {
          mm += lineMm;
          final ref = (f.aut ?? '').trim();
          if (ref.isNotEmpty) {
            mm += _measureTextHeightMmExact('REF: $ref', charsPerLine, lineMm);
          }
        }
      }
      mm += 2;
    }

    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');
    mm += 7;
    mm += _measureTextHeightMmExact('OPV: ${opvLabel.isEmpty ? '-' : opvLabel}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('IDFOLIO: ${footer.idfol}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('FCNM: ${_fmtDateTime(footer.fcnm)}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact(
      'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toString() ?? '-'})',
      charsPerLine,
      lineMm,
    );

    mm += 7;
    if (data.ords.isEmpty) {
      mm += lineMm;
    } else {
      for (final ord in data.ords) {
        final ordUpc = _resolveCotizacionOrdUpcExact(ord, data.items);
        final ordDesc = (ord.desc ?? '').trim();
        mm += lineMm;
        mm += _measureTextHeightMmExact('DES: ${ordDesc.isEmpty ? '-' : ordDesc}', charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('UPC: ${ordUpc.isEmpty ? '-' : ordUpc}', charsPerLine, lineMm);
        mm += 2.5;
      }
    }

    mm += is58 ? 10.0 : 16.0;
    final minMm = is58 ? 180.0 : 230.0;
    final maxMm = is58 ? 1800.0 : 2400.0;
    return mm.clamp(minMm, maxMm).toDouble();
  }

  String _resolveCotizacionOrdUpcExact(
    PagoCierrePrintOrd ord,
    List<PagoCierrePrintItem> items,
  ) {
    final iord = ord.iord.trim().toUpperCase();
    final ordArt = (ord.art ?? '').trim().toUpperCase();
    final upcs = <String>{};
    for (final item in items) {
      final itemOrd = (item.ord ?? '').trim().toUpperCase();
      final upc = (item.upc ?? '').trim();
      if (itemOrd == iord && upc.isNotEmpty) upcs.add(upc);
    }
    if (upcs.isEmpty && ordArt.isNotEmpty) {
      for (final item in items) {
        final itemArt = (item.art ?? '').trim().toUpperCase();
        final upc = (item.upc ?? '').trim();
        if (itemArt == ordArt && upc.isNotEmpty) upcs.add(upc);
      }
    }
    return upcs.join(', ');
  }

  pw.Document _buildDevolucionTicketPdfExact(
    DevolucionPrintPreviewResponse data, {
    required double widthMm,
  }) {
    final doc = pw.Document();
    final header = data.header;
    final totals = data.totals;
    final footer = data.footer;
    final ords = _collectDevolucionOrdsFromItemsExact(data.items);
    final fcnTrans = _resolveDevolucionTicketDateExact(data.formas);
    final isCotizacionAbierta = totals.tipotran.trim().toUpperCase() == 'CA';
    final widthPt = _mmToPt(widthMm);
    final pageFormat = PdfPageFormat(
      widthPt,
      _mmToPt(_estimateDevolucionTicketHeightMmExact(data, widthMm)),
      marginAll: 0,
    );
    final leftMarginPt = _mmToPt(2);
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');
    final nonCashFormas = data.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'SUC: ${header.suc}  ${header.desc ?? ''}'.trim(),
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          if ((header.direccion ?? '').isNotEmpty)
            pw.Text(header.direccion!, style: pw.TextStyle(fontSize: smallFontSize)),
          if ((header.contacto ?? '').isNotEmpty)
            pw.Text('Contacto: ${header.contacto}', style: pw.TextStyle(fontSize: smallFontSize)),
          if ((header.rfc ?? '').isNotEmpty)
            pw.Text('RFC: ${header.rfc}', style: pw.TextStyle(fontSize: smallFontSize)),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'DETALLE',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          if (data.items.isEmpty)
            pw.Text('Sin articulos registrados', style: pw.TextStyle(fontSize: smallFontSize))
          else
            ...[
              for (var i = 0; i < data.items.length; i++)
                _buildDevolucionTicketDetalleItemExact(
                  data.items[i],
                  index: i,
                  baseFontSize: baseFontSize,
                  smallFontSize: smallFontSize,
                ),
            ],
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'TOTALES',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          _ticketRowExact('Total base', _money(totals.totalBase), baseFontSize),
          if (!isCotizacionAbierta) ...[
            _ticketRowExact('Subtotal', _money(totals.subtotal), baseFontSize),
            _ticketRowExact('IVA', _money(totals.iva), baseFontSize),
            _ticketRowExact('Total final', _money(totals.total), baseFontSize),
            _ticketRowExact('Pagos', _money(totals.sumPagos), baseFontSize),
            _ticketRowExact('Faltante', _money(totals.faltante), baseFontSize),
            _ticketRowExact('Cambio', _money(totals.cambio), baseFontSize),
          ],
          if (!isCotizacionAbierta) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'FORMAS',
              style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
            ),
            if (data.formas.isEmpty)
              pw.Text('Sin formas de pago', style: pw.TextStyle(fontSize: smallFontSize))
            else
              ...data.formas.map((f) {
                final ref = (f.aut ?? '').trim();
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _ticketRowExact(f.form, _money(f.impp), baseFontSize),
                    if (ref.isNotEmpty)
                      pw.Text('REF: $ref', style: pw.TextStyle(fontSize: smallFontSize)),
                    if (f.fcn != null)
                      pw.Text('FCN: ${_fmtDateTime(f.fcn)}', style: pw.TextStyle(fontSize: smallFontSize)),
                  ],
                );
              }),
            pw.SizedBox(height: 4),
          ],
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'TRANSACCION',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('OPV: ${opvLabel.isEmpty ? '-' : opvLabel}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('IDFOL DEV: ${footer.idfolDev}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('IDFOL ORIG: ${footer.idfolOrig}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('FCNM: ${_fmtDateTime(fcnTrans)}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('ESTADO: ${footer.esta ?? '-'}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('AUT: ${footer.aut ?? '-'}', style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text(
            'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toStringAsFixed(0) ?? '-'})',
            style: pw.TextStyle(fontSize: baseFontSize),
          ),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text(
            'RESUMEN DE ORDS',
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          if (ords.isEmpty)
            pw.Text('Sin ORDs ligadas', style: pw.TextStyle(fontSize: smallFontSize))
          else
            ...ords.map((ord) {
              return pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORD: ${ord.ord}', style: pw.TextStyle(fontSize: baseFontSize)),
                    pw.Text(
                      'DES: ${ord.description.isEmpty ? '-' : ord.description}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                    pw.Text(
                      'UPC: ${ord.upc.isEmpty ? '-' : ord.upc}',
                      style: pw.TextStyle(fontSize: smallFontSize),
                    ),
                  ],
                ),
              );
            }),
          if (nonCashFormas.isNotEmpty)
            pw.Text(
              'GRACIAS POR SU CONFIANZA',
              style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
    return doc;
  }

  pw.Document _buildDevolucionVoucherPdfExact(
    DevolucionPrintPreviewResponse data, {
    required double widthMm,
    required List<DevolucionPrintForma> nonCashFormas,
  }) {
    final doc = pw.Document();
    if (nonCashFormas.isEmpty) return doc;

    final header = data.header;
    final totals = data.totals;
    final footer = data.footer;
    final fcnTrans = _resolveDevolucionTicketDateExact(data.formas);
    final widthPt = _mmToPt(widthMm);
    final pageFormat = PdfPageFormat(
      widthPt,
      _mmToPt(_estimateVoucherHeightMmExact(voucherCount: nonCashFormas.length, widthMm: widthMm)),
      marginAll: 0,
    );
    final leftMarginPt = _mmToPt(2);
    final baseFontSize = widthMm <= 58 ? 9.0 : 10.0;
    final smallFontSize = widthMm <= 58 ? 8.0 : 9.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          ...nonCashFormas.map(
            (forma) => _buildDevolucionVoucherSectionExact(
              forma: forma,
              idfol: footer.idfolDev,
              suc: header.suc,
              clienteNombre: footer.clienteNombre,
              clienteId: footer.clienteId?.toStringAsFixed(0),
              tra: null,
              fecha: forma.fcn ?? fcnTrans,
              totalOperacion: totals.total,
              baseFontSize: baseFontSize,
              smallFontSize: smallFontSize,
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  List<_DevolucionTicketOrdSummary> _collectDevolucionOrdsFromItemsExact(
    List<DevolucionPrintItem> items,
  ) {
    final byOrd = <String, List<DevolucionPrintItem>>{};
    for (final item in items) {
      final ord = (item.ord ?? '').trim();
      if (ord.isEmpty) continue;
      byOrd.putIfAbsent(ord, () => <DevolucionPrintItem>[]).add(item);
    }
    final result = <_DevolucionTicketOrdSummary>[];
    for (final entry in byOrd.entries) {
      final upcs = <String>{};
      final descriptions = <String>{};
      for (final item in entry.value) {
        final upc = (item.upc ?? '').trim();
        final description = (item.des ?? item.art ?? '').trim();
        if (upc.isNotEmpty) upcs.add(upc);
        if (description.isNotEmpty) descriptions.add(description);
      }
      result.add(
        _DevolucionTicketOrdSummary(
          ord: entry.key,
          upc: upcs.join(', '),
          description: descriptions.join(' | '),
        ),
      );
    }
    result.sort((a, b) => a.ord.compareTo(b.ord));
    return result;
  }

  DateTime? _resolveDevolucionTicketDateExact(List<DevolucionPrintForma> formas) {
    DateTime? latest;
    for (final forma in formas) {
      final current = forma.fcn;
      if (current == null) continue;
      if (latest == null || current.isAfter(latest)) latest = current;
    }
    return latest;
  }

  pw.Widget _buildDevolucionVoucherSectionExact({
    required DevolucionPrintForma forma,
    required String idfol,
    required String suc,
    required String? clienteNombre,
    required String? clienteId,
    required String? tra,
    required DateTime? fecha,
    required double totalOperacion,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final form = forma.form.trim().isEmpty ? '-' : forma.form.trim().toUpperCase();
    final impd = _money(totalOperacion);
    final autRef = (forma.aut ?? '').trim().isEmpty ? '-' : forma.aut!.trim();
    final clienteNom = (clienteNombre ?? '').trim().isEmpty ? '-' : clienteNombre!.trim();
    final clienteCodigo = (clienteId ?? '').trim().isEmpty ? '-' : clienteId!.trim();
    final traValue = (tra ?? '').trim().isEmpty ? '-' : tra!.trim();

    pw.Widget lineText(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1, bottom: 1),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: smallFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildVoucherCutLineExact(smallFontSize: smallFontSize),
          pw.Text('VOUCHER', style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(
            'SOPORTE RECEPCION\nPAGO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Detalle', style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold)),
          lineText('FORM   $form'),
          lineText('IMPD   $impd'),
          lineText('AUT o REF   $autRef'),
          pw.SizedBox(height: 6),
          lineText('Nombre de cliente   $clienteNom'),
          lineText('IDC   $clienteCodigo'),
          lineText('FCN   ${_fmtDateTime(fecha)}'),
          pw.SizedBox(height: 16),
          lineText('____________________________'),
          lineText('Firma cliente'),
          lineText('SUC   $suc   TRA   $traValue'),
          lineText('IDFOL   $idfol', bold: true),
        ],
      ),
    );
  }

  pw.Widget _buildDevolucionTicketDetalleItemExact(
    DevolucionPrintItem item, {
    required int index,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final name = (item.des ?? item.art ?? '-').trim();
    final qty = item.ctd.toStringAsFixed(2);
    final unit = _money(item.pvta);
    final imp = _money(item.importe);
    final upc = (item.upc ?? '').trim();
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        color: index.isEven ? PdfColors.white : PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('UPC: ${upc.isEmpty ? '-' : upc}', style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text('$qty x $unit = $imp', style: pw.TextStyle(fontSize: smallFontSize)),
        ],
      ),
    );
  }

  double _estimateDevolucionTicketHeightMmExact(
    DevolucionPrintPreviewResponse data,
    double widthMm,
  ) {
    final is58 = widthMm <= 58;
    final charsPerLine = is58 ? 28 : 34;
    final lineMm = is58 ? 3.3 : 3.9;
    final isCotizacionAbierta = data.totals.tipotran.trim().toUpperCase() == 'CA';
    final ords = _collectDevolucionOrdsFromItemsExact(data.items);
    double mm = 0;
    mm += 6;
    mm += _measureTextHeightMmExact('SUC: ${data.header.suc}  ${data.header.desc ?? ''}'.trim(), charsPerLine, lineMm);
    if ((data.header.direccion ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMmExact(data.header.direccion!, charsPerLine, lineMm);
    }
    if ((data.header.contacto ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMmExact('Contacto: ${data.header.contacto}', charsPerLine, lineMm);
    }
    if ((data.header.rfc ?? '').trim().isNotEmpty) {
      mm += _measureTextHeightMmExact('RFC: ${data.header.rfc}', charsPerLine, lineMm);
    }
    mm += 8;
    if (data.items.isEmpty) {
      mm += lineMm;
    } else {
      for (final item in data.items) {
        final name = (item.des ?? item.art ?? '-').trim();
        final upc = (item.upc ?? '').trim();
        mm += _measureTextHeightMmExact(name, charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('UPC: ${upc.isEmpty ? '-' : upc}', charsPerLine, lineMm);
        mm += lineMm + 1.4;
      }
    }
    mm += 8;
    mm += lineMm;
    if (!isCotizacionAbierta) {
      mm += lineMm * 6;
      mm += 5;
      if (data.formas.isEmpty) {
        mm += lineMm;
      } else {
        for (final forma in data.formas) {
          mm += lineMm;
          final ref = (forma.aut ?? '').trim();
          if (ref.isNotEmpty) {
            mm += _measureTextHeightMmExact('REF: $ref', charsPerLine, lineMm);
          }
          if (forma.fcn != null) mm += lineMm;
        }
      }
    }
    final footer = data.footer;
    final opvLabel = [
      if ((footer.opv ?? '').trim().isNotEmpty) footer.opv!.trim(),
      if ((footer.opvNombre ?? '').trim().isNotEmpty) footer.opvNombre!.trim(),
    ].join(' - ');
    mm += 7;
    mm += _measureTextHeightMmExact('OPV: ${opvLabel.isEmpty ? '-' : opvLabel}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('IDFOL DEV: ${footer.idfolDev}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('IDFOL ORIG: ${footer.idfolOrig}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('FCNM: ${_fmtDateTime(_resolveDevolucionTicketDateExact(data.formas))}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('ESTADO: ${footer.esta ?? '-'}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('AUT: ${footer.aut ?? '-'}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact(
      'CLIENTE: ${footer.clienteNombre ?? '-'} (${footer.clienteId?.toStringAsFixed(0) ?? '-'})',
      charsPerLine,
      lineMm,
    );
    mm += 7;
    if (ords.isEmpty) {
      mm += lineMm;
    } else {
      for (final ord in ords) {
        mm += _measureTextHeightMmExact('ORD: ${ord.ord}', charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('DES: ${ord.description.isEmpty ? '-' : ord.description}', charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('UPC: ${ord.upc.isEmpty ? '-' : ord.upc}', charsPerLine, lineMm);
        mm += 2.5;
      }
    }
    mm += is58 ? 10 : 16;
    final minMm = is58 ? 170.0 : 220.0;
    final maxMm = is58 ? 1400.0 : 1900.0;
    return mm.clamp(minMm, maxMm).toDouble();
  }

  pw.Document _buildPsTicketPdfExact({
    required PsPagoSummary summary,
    required double widthMm,
    PsDetalleResponse? detalle,
  }) {
    final doc = pw.Document();
    final header = detalle?.header;
    final ticket = detalle?.ticket ?? const <PsTicketLine>[];
    final ords = _collectPsOrdsFromTicketExact(ticket);
    final opvValue = (header?.opv ?? '').trim();
    final opvmValue = (header?.opvm ?? '').trim();
    final opvLabel = [
      if (opvValue.isNotEmpty) opvValue,
      if (opvmValue.isNotEmpty) opvmValue,
    ].join(' - ');
    final transDate = _resolvePsTicketDateExact(summary.formas);
    final nonCashFormas = summary.formas
        .where((f) => f.form.trim().toUpperCase() != 'EFECTIVO')
        .toList(growable: false);
    final widthPt = _mmToPt(widthMm);
    final pageHeightMm = _estimatePsTicketHeightMmExact(summary, ticket, widthMm);
    final line = '-' * (widthMm <= 58 ? 30 : 38);
    final baseFont = widthMm <= 58 ? 9.0 : 10.0;
    final smallFont = widthMm <= 58 ? 8.0 : 9.0;
    final sucLabel = _textOrDashExact(header?.suc ?? summary.suc);
    final clienteIdLabel = header?.clien?.toString() ?? '-';
    final clienteNombreLabel = _textOrDashExact(header?.razonSocialReceptor);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(widthPt, _mmToPt(pageHeightMm), marginAll: 0),
        margin: pw.EdgeInsets.only(left: _mmToPt(2)),
        maxPages: 120,
        build: (_) => [
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text('SUC: $sucLabel', style: pw.TextStyle(fontSize: baseFont)),
          pw.SizedBox(height: 2),
          pw.Text('MODULO: PAGO DE SERVICIOS', style: pw.TextStyle(fontSize: smallFont)),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text('DETALLE', style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold)),
          if (ticket.isEmpty)
            pw.Text('Sin articulos registrados', style: pw.TextStyle(fontSize: smallFont))
          else
            ...[
              for (var i = 0; i < ticket.length; i++)
                _buildPsTicketDetalleItemExact(
                  ticket[i],
                  index: i,
                  baseFontSize: baseFont,
                  smallFontSize: smallFont,
                ),
            ],
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text('TOTALES', style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold)),
          _ticketRowExact('Total base', _money(summary.total), baseFont),
          _ticketRowExact('Subtotal', _money(summary.total), baseFont),
          _ticketRowExact('IVA', _money(0), baseFont),
          _ticketRowExact('Total final', _money(summary.total), baseFont),
          _ticketRowExact('Pagos', _money(summary.pagado), baseFont),
          _ticketRowExact('Faltante', _money(summary.restante), baseFont),
          _ticketRowExact('Cambio', _money(summary.cambio), baseFont),
          pw.SizedBox(height: 4),
          pw.Text('FORMAS', style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold)),
          if (summary.formas.isEmpty)
            pw.Text('Sin formas de pago', style: pw.TextStyle(fontSize: smallFont))
          else
            ...summary.formas.map((f) {
              final ref = (f.aut ?? '').trim();
              return pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _ticketRowExact(f.form, _money(f.impp), baseFont),
                    if (ref.isNotEmpty)
                      pw.Text('REF: $ref', style: pw.TextStyle(fontSize: smallFont)),
                    if (f.fcn != null)
                      pw.Text('FCN: ${_fmtDateTime(f.fcn)}', style: pw.TextStyle(fontSize: smallFont)),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text('TRANSACCION', style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold)),
          pw.Text('OPV: ${opvLabel.isEmpty ? '-' : opvLabel}', style: pw.TextStyle(fontSize: baseFont)),
          pw.Text('IDFOLIO: ${summary.idfol}', style: pw.TextStyle(fontSize: baseFont)),
          pw.Text('FCNM: ${_fmtDateTime(transDate)}', style: pw.TextStyle(fontSize: baseFont)),
          pw.Text('CLIENTE: $clienteNombreLabel ($clienteIdLabel)', style: pw.TextStyle(fontSize: baseFont)),
          pw.SizedBox(height: 4),
          pw.Text(line, style: pw.TextStyle(fontSize: smallFont)),
          pw.Text('RESUMEN DE ORDS', style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold)),
          if (ords.isEmpty)
            pw.Text('Sin ORDs ligadas', style: pw.TextStyle(fontSize: smallFont))
          else
            ...ords.map((ord) {
              return pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORD: ${ord.ord}', style: pw.TextStyle(fontSize: baseFont)),
                    pw.Text(
                      'DES: ${ord.description.isEmpty ? '-' : ord.description}',
                      style: pw.TextStyle(fontSize: smallFont),
                    ),
                    pw.Text(
                      'UPC: ${ord.upc.isEmpty ? '-' : ord.upc}',
                      style: pw.TextStyle(fontSize: smallFont),
                    ),
                  ],
                ),
              );
            }),
          if (nonCashFormas.isNotEmpty)
            pw.Text(
              'GRACIAS POR SU CONFIANZA',
              style: pw.TextStyle(fontSize: smallFont, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
    return doc;
  }

  pw.Document _buildPsVoucherPdfExact({
    required PsPagoSummary summary,
    required double widthMm,
    required List<PsFormaPagoItem> nonCashFormas,
    PsDetalleResponse? detalle,
  }) {
    final doc = pw.Document();
    if (nonCashFormas.isEmpty) return doc;
    final header = detalle?.header;
    final transDate = _resolvePsTicketDateExact(summary.formas);
    final sucValue = summary.suc.trim();
    final sucLabel = sucValue.isEmpty ? '-' : sucValue;
    final widthPt = _mmToPt(widthMm);
    final pageFormat = PdfPageFormat(
      widthPt,
      _mmToPt(_estimateVoucherHeightMmExact(voucherCount: nonCashFormas.length, widthMm: widthMm)),
      marginAll: 0,
    );
    final leftMarginPt = _mmToPt(2);
    final baseFont = widthMm <= 58 ? 9.0 : 10.0;
    final smallFont = widthMm <= 58 ? 8.0 : 9.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.only(left: leftMarginPt),
        maxPages: 120,
        build: (_) => [
          ...nonCashFormas.map(
            (forma) => _buildPsVoucherSectionExact(
              forma: forma,
              idfol: summary.idfol,
              suc: sucLabel,
              clienteNombre: header?.razonSocialReceptor,
              clienteId: header?.clien?.toString(),
              tra: header?.tra,
              fecha: forma.fcn ?? transDate,
              totalOperacion: summary.total,
              baseFontSize: baseFont,
              smallFontSize: smallFont,
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  List<_PsTicketOrdSummary> _collectPsOrdsFromTicketExact(List<PsTicketLine> ticket) {
    final byOrd = <String, List<PsTicketLine>>{};
    for (final line in ticket) {
      final ord = (line.ord ?? '').trim();
      if (ord.isEmpty) continue;
      byOrd.putIfAbsent(ord, () => <PsTicketLine>[]).add(line);
    }
    final result = <_PsTicketOrdSummary>[];
    for (final entry in byOrd.entries) {
      final upcs = <String>{};
      final descriptions = <String>{};
      for (final line in entry.value) {
        final upc = (line.upc ?? '').trim();
        final description = (line.des ?? line.art ?? '').trim();
        if (upc.isNotEmpty) upcs.add(upc);
        if (description.isNotEmpty) descriptions.add(description);
      }
      result.add(
        _PsTicketOrdSummary(
          ord: entry.key,
          upc: upcs.join(', '),
          description: descriptions.join(' | '),
        ),
      );
    }
    result.sort((a, b) => a.ord.compareTo(b.ord));
    return result;
  }

  DateTime? _resolvePsTicketDateExact(List<PsFormaPagoItem> formas) {
    DateTime? latest;
    for (final forma in formas) {
      final current = forma.fcn;
      if (current == null) continue;
      if (latest == null || current.isAfter(latest)) latest = current;
    }
    return latest;
  }

  pw.Widget _buildPsTicketDetalleItemExact(
    PsTicketLine item, {
    required int index,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final name = (item.des ?? item.art ?? '-').trim();
    final qtyValue = item.ctd ?? 1;
    final qty = qtyValue.toStringAsFixed(2);
    final unitValue = item.pvta ?? (qtyValue != 0 ? (item.total ?? 0) / qtyValue : 0);
    final unit = _money(unitValue);
    final impValue = item.total ?? item.pvtat ?? (qtyValue * unitValue);
    final imp = _money(impValue);
    final upc = (item.upc ?? '').trim();
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: pw.BoxDecoration(
        color: index.isEven ? PdfColors.white : PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name, style: pw.TextStyle(fontSize: baseFontSize)),
          pw.Text('UPC: ${upc.isEmpty ? '-' : upc}', style: pw.TextStyle(fontSize: smallFontSize)),
          pw.Text('$qty x $unit = $imp', style: pw.TextStyle(fontSize: smallFontSize)),
        ],
      ),
    );
  }

  pw.Widget _buildPsVoucherSectionExact({
    required PsFormaPagoItem forma,
    required String idfol,
    required String suc,
    required String? clienteNombre,
    required String? clienteId,
    required String? tra,
    required DateTime? fecha,
    required double totalOperacion,
    required double baseFontSize,
    required double smallFontSize,
  }) {
    final form = forma.form.trim().isEmpty ? '-' : forma.form.trim().toUpperCase();
    final impd = _money(totalOperacion);
    final autRef = (forma.aut ?? '').trim().isEmpty ? '-' : forma.aut!.trim();
    final clienteNom = (clienteNombre ?? '').trim().isEmpty ? '-' : clienteNombre!.trim();
    final clienteCodigo = (clienteId ?? '').trim().isEmpty ? '-' : clienteId!.trim();
    final traValue = (tra ?? '').trim().isEmpty ? '-' : tra!.trim();

    pw.Widget lineText(String text, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1, bottom: 1),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: smallFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildVoucherCutLineExact(smallFontSize: smallFontSize),
          pw.Text('VOUCHER', style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(
            'SOPORTE RECEPCION\nPAGO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Detalle', style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold)),
          lineText('FORM   $form'),
          lineText('IMPD   $impd'),
          lineText('AUT o REF   $autRef'),
          lineText('Nombre de cliente   $clienteNom'),
          lineText('IDC   $clienteCodigo'),
          lineText('FCN   ${_fmtDateTime(fecha)}'),
          pw.SizedBox(height: 16),
          lineText('____________________________'),
          lineText('Firma cliente'),
          lineText('SUC   $suc   TRA   $traValue'),
          lineText('IDFOL   $idfol', bold: true),
        ],
      ),
    );
  }

  double _estimatePsTicketHeightMmExact(
    PsPagoSummary summary,
    List<PsTicketLine> ticket,
    double widthMm,
  ) {
    final is58 = widthMm <= 58;
    final charsPerLine = is58 ? 28 : 34;
    final lineMm = is58 ? 3.3 : 3.9;
    final ords = _collectPsOrdsFromTicketExact(ticket);
    double mm = 0;
    mm += 6;
    mm += _measureTextHeightMmExact('SUC: ${summary.suc}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('MODULO: PAGO DE SERVICIOS', charsPerLine, lineMm);
    mm += 8;
    if (ticket.isEmpty) {
      mm += lineMm;
    } else {
      for (final item in ticket) {
        final name = (item.des ?? item.art ?? '-').trim();
        final upc = (item.upc ?? '').trim();
        mm += _measureTextHeightMmExact(name, charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('UPC: ${upc.isEmpty ? '-' : upc}', charsPerLine, lineMm);
        mm += lineMm;
        mm += 1.4;
      }
    }
    mm += 8;
    mm += lineMm * 7;
    mm += 5;
    if (summary.formas.isEmpty) {
      mm += lineMm;
    } else {
      for (final forma in summary.formas) {
        mm += lineMm;
        final ref = (forma.aut ?? '').trim();
        if (ref.isNotEmpty) {
          mm += _measureTextHeightMmExact('REF: $ref', charsPerLine, lineMm);
        }
        if (forma.fcn != null) mm += lineMm;
      }
    }
    mm += 7;
    mm += _measureTextHeightMmExact('OPV: -', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('IDFOLIO: ${summary.idfol}', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('FCNM: -', charsPerLine, lineMm);
    mm += _measureTextHeightMmExact('CLIENTE: - (-)', charsPerLine, lineMm);
    mm += 7;
    if (ords.isEmpty) {
      mm += lineMm;
    } else {
      for (final ord in ords) {
        mm += _measureTextHeightMmExact('ORD: ${ord.ord}', charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('DES: ${ord.description.isEmpty ? '-' : ord.description}', charsPerLine, lineMm);
        mm += _measureTextHeightMmExact('UPC: ${ord.upc.isEmpty ? '-' : ord.upc}', charsPerLine, lineMm);
        mm += 2.5;
      }
    }
    mm += is58 ? 10 : 16;
    final minMm = is58 ? 180.0 : 230.0;
    final maxMm = is58 ? 1800.0 : 2400.0;
    return mm.clamp(minMm, maxMm).toDouble();
  }

  pw.Widget _buildVoucherCutLineExact({required double smallFontSize}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text('----------------', style: pw.TextStyle(fontSize: smallFontSize)),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            'âœ‚',
            style: pw.TextStyle(fontSize: smallFontSize + 1, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              '----------------',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: smallFontSize),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _ticketRowExact(String label, String value, double fontSize) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: fontSize))),
        pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
      ],
    );
  }

  double _estimateVoucherHeightMmExact({
    required int voucherCount,
    required double widthMm,
  }) {
    final is58 = widthMm <= 58;
    final perVoucher = is58 ? 108.0 : 120.0;
    final padding = is58 ? 14.0 : 18.0;
    final minMm = is58 ? 140.0 : 170.0;
    final maxMm = is58 ? 1800.0 : 2400.0;
    final mm = (voucherCount * perVoucher) + padding;
    return mm.clamp(minMm, maxMm).toDouble();
  }

  double _measureTextHeightMmExact(String text, int charsPerLine, double lineMm) {
    final value = text.trim();
    if (value.isEmpty) return 0;
    final normalized = value.replaceAll('\r', '');
    var totalLines = 0;
    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        totalLines += 1;
        continue;
      }
      totalLines += math.max(1, (line.length / charsPerLine).ceil());
    }
    return totalLines * lineMm;
  }

  String _textOrDashExact(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  double _mmToPt(double mm) => mm * (72.0 / 25.4);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _fmtDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(local.day)}/${p2(local.month)}/${local.year} ${p2(local.hour)}:${p2(local.minute)}';
  }

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return apiErrorMessage(error, fallback: 'No se pudo consultar reimpresiones.');
  }

  bool _isAuthorizationError(Object error) {
    final msg = _errorMessage(error).toLowerCase();
    return msg.contains('autoriz') || msg.contains('supervisor');
  }
}

class _DevolucionTicketOrdSummary {
  const _DevolucionTicketOrdSummary({
    required this.ord,
    required this.upc,
    required this.description,
  });

  final String ord;
  final String upc;
  final String description;
}

class _PsTicketOrdSummary {
  const _PsTicketOrdSummary({
    required this.ord,
    required this.upc,
    required this.description,
  });

  final String ord;
  final String upc;
  final String description;
}

class _FilterSelectOption {
  const _FilterSelectOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class _TopFilters extends StatelessWidget {
  const _TopFilters({
    required this.opvCtrl,
    required this.sucCtrl,
    required this.fcnmCtrl,
    required this.searchCtrl,
    required this.onPickFcnm,
    required this.onSearch,
    required this.onClear,
    required this.authorizing,
    required this.lockSucOpv,
    required this.isAdmin,
    required this.adminCatalogLoading,
    required this.adminCatalogError,
    required this.selectedSucursal,
    required this.selectedOpv,
    required this.sucursalOptions,
    required this.opvOptions,
    required this.onSucursalChanged,
    required this.onOpvChanged,
  });

  final TextEditingController opvCtrl;
  final TextEditingController sucCtrl;
  final TextEditingController fcnmCtrl;
  final TextEditingController searchCtrl;
  final VoidCallback onPickFcnm;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final bool authorizing;
  final bool lockSucOpv;
  final bool isAdmin;
  final bool adminCatalogLoading;
  final Object? adminCatalogError;
  final String selectedSucursal;
  final String selectedOpv;
  final List<_FilterSelectOption> sucursalOptions;
  final List<_FilterSelectOption> opvOptions;
  final ValueChanged<String?> onSucursalChanged;
  final ValueChanged<String?> onOpvChanged;

  @override
  Widget build(BuildContext context) {
    final blockFields = authorizing || adminCatalogLoading;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isAdmin) ...[
              _DropdownField(
                label: 'Sucursal',
                value: selectedSucursal,
                options: sucursalOptions,
                enabled: !blockFields && sucursalOptions.isNotEmpty,
                onChanged: onSucursalChanged,
              ),
              _DropdownField(
                label: 'OPV',
                value: selectedOpv,
                options: opvOptions,
                enabled: !blockFields && opvOptions.isNotEmpty,
                onChanged: onOpvChanged,
              ),
            ] else ...[
              _SmallField(
                label: 'Sucursal',
                controller: sucCtrl,
                enabled: !authorizing && !lockSucOpv,
              ),
              _SmallField(
                label: 'OPV',
                controller: opvCtrl,
                enabled: !authorizing && !lockSucOpv,
              ),
            ],
            SizedBox(
              width: 200,
              child: TextField(
                controller: fcnmCtrl,
                enabled: !authorizing,
                decoration: InputDecoration(
                  labelText: 'FCNM (YYYY-MM-DD)',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Seleccionar fecha',
                    onPressed: authorizing ? null : onPickFcnm,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 520,
              child: TextField(
                controller: searchCtrl,
                enabled: !authorizing,
                decoration: const InputDecoration(
                  labelText: 'Buscar IDFOL / CLIEN / razon social / OPV',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: authorizing ? null : onSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Limpiar',
              onPressed: authorizing ? null : onClear,
              icon: const Icon(Icons.clear),
            ),
            const Text(
              'Maximo 20 registros por pagina',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (isAdmin && adminCatalogLoading)
              const Text(
                'Cargando sucursales/usuarios...',
                style: TextStyle(fontSize: 12),
              ),
            if (isAdmin && adminCatalogError != null)
              Text(
                'No se pudieron cargar catalogos: $adminCatalogError',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_FilterSelectOption> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.any((item) => item.value == value)
        ? value
        : (options.isNotEmpty ? options.first.value : null);

    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$selected-${options.length}'),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.label),
              ),
            )
            .toList(growable: false),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _ReimpresionTable extends StatelessWidget {
  const _ReimpresionTable({
    required this.folios,
    required this.selected,
    required this.onSelect,
  });

  final List<PvCtrFolAsvrModel> folios;
  final PvCtrFolAsvrModel? selected;
  final ValueChanged<PvCtrFolAsvrModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 420,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 42,
              dataRowMaxHeight: 48,
              horizontalMargin: 12,
              columnSpacing: 20,
              columns: const [
                DataColumn(
                  label: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('OPV', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('IDFOL', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text(
                    'IDFOLINICIAL',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ORIGEN_AUT',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text('FCNM', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('TRA', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('CLIEN', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text(
                    'Razon social receptor',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                DataColumn(
                  label: Text('Importe', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
              rows: folios.map((c) {
                final selectedRow = selected?.idfol == c.idfol;
                final razonSocial = (c.razonSocialReceptor ?? '').trim();
                return DataRow(
                  selected: selectedRow,
                  onSelectChanged: (_) => onSelect(c),
                  cells: [
                    DataCell(_cellText(c.suc ?? '-')),
                    DataCell(_cellText(c.opv ?? '-')),
                    DataCell(_cellText(c.idfol)),
                    DataCell(_cellText(c.idfolinicial ?? '-')),
                    DataCell(_cellText((c.origenAut ?? '-').toUpperCase())),
                    DataCell(_cellText(_formatDate(c.fcnm))),
                    DataCell(_cellText(c.tra ?? '-')),
                    DataCell(_cellText(c.clien?.toString() ?? '-')),
                    DataCell(_cellText(razonSocial.isEmpty ? '-' : razonSocial)),
                    DataCell(_cellText(c.esta ?? '-')),
                    DataCell(_cellText(_formatMoney(c.impt), align: TextAlign.right)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String value, {TextAlign align = TextAlign.left}) {
    return Text(
      value,
      textAlign: align,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  String _formatMoney(double? value) {
    if (value == null) return '-';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _AuthorizationPendingBlock extends StatelessWidget {
  const _AuthorizationPendingBlock();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Se requiere autorizacion de supervisor para visualizar reimpresion de ticket.',
            ),
            SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Esperando autorizacion...'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchRequiredBlock extends StatelessWidget {
  const _SearchRequiredBlock();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Capture FCNM o busqueda por IDFOL, CLIEN, razon social u OPV para consultar.',
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.result,
    required this.onPrev,
    required this.onNext,
  });

  final ReimpresionPageResult result;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canPrev = result.page > 1;
    final canNext = result.totalPages > 0 && result.page < result.totalPages;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Pagina ${result.page} de ${result.totalPages == 0 ? 1 : result.totalPages}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Total: ${result.total}'),
            OutlinedButton.icon(
              onPressed: canPrev ? onPrev : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            FilledButton.icon(
              onPressed: canNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

