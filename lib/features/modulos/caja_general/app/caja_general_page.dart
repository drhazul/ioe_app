import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/features/masterdata/users/users_models.dart';
import 'package:ioe_app/features/masterdata/users/users_providers.dart';

import 'caja_general_models.dart';
import 'caja_general_providers.dart';

class CajaGeneralPage extends ConsumerStatefulWidget {
  const CajaGeneralPage({super.key});

  @override
  ConsumerState<CajaGeneralPage> createState() => _CajaGeneralPageState();
}

class _CajaGeneralPageState extends ConsumerState<CajaGeneralPage> {
  late DateTime _fecha;
  static const _operationTipo = 'GLOBAL';
  String _suc = '';
  String? _tokenOpv;
  String? _selectedOpv;
  bool _contextReady = false;

  @override
  void initState() {
    super.initState();
    final filtros = ref.read(cajaGeneralFiltrosProvider);
    _fecha = filtros.fecha;
    final opv = filtros.opv.trim().toUpperCase();
    _selectedOpv = opv.isEmpty ? null : opv;
    _loadUserContext();
  }

  @override
  Widget build(BuildContext context) {
    if (!_contextReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja General'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildLayout(
          opvField: TextFormField(
            enabled: false,
            initialValue: '',
            decoration: InputDecoration(
              labelText: 'OPV',
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: 'No se pudieron cargar OPV: $error',
            ),
          ),
          selectedOpv: null,
        ),
        data: (users) {
          final options = _buildOpvOptions(users, _suc);
          final selectedOpv = _resolveSelectedOpv(options);

          if (selectedOpv != _selectedOpv) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedOpv = selectedOpv);
              _saveFiltros(opv: selectedOpv ?? '');
            });
          }

          final opvField = options.isEmpty
              ? TextFormField(
                  enabled: false,
                  initialValue: '',
                  decoration: const InputDecoration(
                    labelText: 'OPV',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText:
                        'No hay usuarios OPV/SUPERVISOR activos en tu sucursal.',
                  ),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey(
                    'cg-opv-$_suc-${selectedOpv ?? ''}-$options.length',
                  ),
                  initialValue: selectedOpv,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'OPV',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: options
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.opv,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedOpv = value);
                    _saveFiltros(opv: value);
                  },
                );

          return _buildLayout(
            opvField: opvField,
            selectedOpv: selectedOpv,
          );
        },
      ),
    );
  }

  Widget _buildLayout({
    required Widget opvField,
    required String? selectedOpv,
  }) {
    final sucReady = _suc.trim().isNotEmpty;
    final opvReady = (selectedOpv ?? '').trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Entrega de Caja General',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'La sucursal se toma del usuario logueado. Seleccione OPV y fecha.',
        ),
        const SizedBox(height: 14),
        TextFormField(
          enabled: false,
          initialValue: _suc,
          decoration: const InputDecoration(
            labelText: 'Sucursal (SUC)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (!sucReady) ...[
          const SizedBox(height: 6),
          Text(
            'No se pudo resolver la sucursal del usuario autenticado.',
            style: TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 10),
        opvField,
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickFecha,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: Text(_formatDate(_fecha)),
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: (!sucReady || !opvReady)
                  ? null
                  : () => _goEntregaOpv(selectedOpv),
              icon: const Icon(Icons.point_of_sale),
                label: const Text('Entrega de OPV'),
            ),
            OutlinedButton.icon(
              onPressed: sucReady ? _goResumenGlobal : null,
              icon: const Icon(Icons.query_stats),
                label: const Text('Resumen Global Dia'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadUserContext() async {
    final storage = ref.read(storageProvider);
    final token = await storage.getAccessToken();

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _contextReady = true);
      return;
    }

    final payload = _decodeJwt(token);
    if (!mounted) return;

    final suc = (payload['suc'] ?? payload['SUC'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final tokenOpv = (payload['opv'] ?? payload['OPV'] ?? payload['username'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    setState(() {
      _suc = suc;
      _tokenOpv = tokenOpv.isEmpty ? null : tokenOpv;
      if ((_selectedOpv ?? '').trim().isEmpty &&
          (_tokenOpv ?? '').trim().isNotEmpty) {
        _selectedOpv = _tokenOpv;
      }
      _contextReady = true;
    });
    _saveFiltros(opv: _selectedOpv ?? '');
  }

  List<_OpvOption> _buildOpvOptions(List<UserModel> users, String suc) {
    final sucNorm = suc.trim().toUpperCase();
    if (sucNorm.isEmpty) return const [];

    final map = <String, _OpvOption>{};
    for (final user in users) {
      final userSuc = (user.suc ?? '').trim().toUpperCase();
      if (userSuc != sucNorm) continue;
      if (!_isOpvOrSupervisor(user)) continue;
      if (!_isActivo(user)) continue;

      final opv = user.username.trim().toUpperCase();
      if (opv.isEmpty || map.containsKey(opv)) continue;

      final display = user.displayName.trim();
      final role = _roleLabel(user);
      final label = display.isEmpty || display.toUpperCase() == opv
          ? '$opv · $role'
          : '$opv - $display · $role';

      map[opv] = _OpvOption(opv: opv, label: label);
    }

    final options = map.values.toList(growable: false);
    options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  String? _resolveSelectedOpv(List<_OpvOption> options) {
    final selected = (_selectedOpv ?? '').trim().toUpperCase();
    if (selected.isNotEmpty && options.any((item) => item.opv == selected)) {
      return selected;
    }

    final tokenOpv = (_tokenOpv ?? '').trim().toUpperCase();
    if (tokenOpv.isNotEmpty && options.any((item) => item.opv == tokenOpv)) {
      return tokenOpv;
    }

    if (options.isNotEmpty) return options.first.opv;
    return null;
  }

  bool _isOpvOrSupervisor(UserModel user) {
    final normalizedRole =
        '${user.rolCodigo ?? ''} ${user.rolNombre ?? ''}'.trim().toUpperCase();
    if (normalizedRole.isEmpty) return false;
    return normalizedRole.contains('OPV') ||
        normalizedRole.contains('SUPERVISOR') ||
        normalizedRole.contains('SUPERPV');
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

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return Map<String, dynamic>.from(json.decode(payload) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Fecha de operación',
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _fecha = DateTime(picked.year, picked.month, picked.day);
    });
    _saveFiltros(opv: _selectedOpv ?? '');
  }

  void _goEntregaOpv(String? selectedOpv) {
    final suc = _suc.trim().toUpperCase();
    final opv = (selectedOpv ?? '').trim().toUpperCase();
    if (suc.isEmpty || opv.isEmpty) {
      _showMessage('No se pudo resolver sucursal u OPV para preparar entrega.');
      return;
    }
    _saveFiltros(opv: opv);
    context.go(
      '/caja-general/opv'
      '?suc=$suc'
      '&opv=$opv'
      '&fcn=${_formatDate(_fecha)}'
      '&tipo=$_operationTipo',
    );
  }

  void _goResumenGlobal() {
    final suc = _suc.trim().toUpperCase();
    if (suc.isEmpty) {
      _showMessage('No se pudo resolver la sucursal del usuario.');
      return;
    }
    _saveFiltros(opv: _selectedOpv ?? '');
    context.go(
      '/caja-general/global'
      '?suc=$suc'
      '&fcn=${_formatDate(_fecha)}'
      '&tipo=$_operationTipo',
    );
  }

  void _saveFiltros({required String opv}) {
    ref.read(cajaGeneralFiltrosProvider.notifier).state = CajaGeneralFiltros(
          suc: _suc,
          fecha: _fecha,
          opv: opv,
          tipo: _operationTipo,
        );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _OpvOption {
  const _OpvOption({
    required this.opv,
    required this.label,
  });

  final String opv;
  final String label;
}
