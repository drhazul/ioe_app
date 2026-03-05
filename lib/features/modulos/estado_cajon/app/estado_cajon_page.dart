import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';

import 'estado_cajon_models.dart';
import 'estado_cajon_providers.dart';

class EstadoCajonPage extends ConsumerStatefulWidget {
  const EstadoCajonPage({super.key});

  @override
  ConsumerState<EstadoCajonPage> createState() => _EstadoCajonPageState();
}

class _EstadoCajonPageState extends ConsumerState<EstadoCajonPage> {
  bool _authorizationRequestedOnEntry = false;
  bool _authorizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentSession = ref.read(estadoCajonAuthSessionProvider);
      if (currentSession != null) {
        ref.read(estadoCajonAuthSessionProvider.notifier).clear();
      }
      _requestAuthorizationOnEntry();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(estadoCajonAuthSessionProvider);
    final fecha = ref.watch(estadoCajonFechaProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Regresar a punto de venta',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/punto-venta'),
        ),
        title: const Text('Estado de cajón (OPV)'),
        actions: [
          IconButton(
            tooltip: 'Seleccionar fecha',
            onPressed: _authorizing ? null : _pickFecha,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _authorizing ? null : _refreshResumen,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(
            fecha: fecha,
          ),
          const SizedBox(height: 10),
          if (session == null)
            const _AuthorizationPendingBlock(),
          if (session != null) _buildResumen(),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final resumenAsync = ref.watch(estadoCajonResumenProvider);

    return resumenAsync.when(
      loading: () => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _ErrorBlock(
        message: _errorMessage(error),
        onRetry: _refreshResumen,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No hay movimientos para la fecha seleccionada.'),
            ),
          );
        }

        final totalImpt = rows.fold<double>(0, (sum, row) => sum + row.impt);
        final totalImpr = rows.fold<double>(0, (sum, row) => sum + row.impr);
        final totalDifd = rows.fold<double>(0, (sum, row) => sum + row.difd);
        final opv = rows.first.opv.trim().isEmpty ? '-' : rows.first.opv;

        return Column(
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text(
                      'OPV:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Text(opv),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('FORM')),
                    DataColumn(label: Text('IMPT'), numeric: true),
                    DataColumn(label: Text('IMPR'), numeric: true),
                    DataColumn(label: Text('IMPE'), numeric: true),
                    DataColumn(label: Text('DIFD'), numeric: true),
                  ],
                  rows: [
                    ...rows.map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(_displayForm(row))),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(_money(row.impt)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(_money(row.impr)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(row.impe == null ? '-' : _money(row.impe!)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(_money(row.difd)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'TOTAL',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _money(totalImpt),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _money(totalImpr),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '-',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _money(totalDifd),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
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
    var retryOnFailure = false;
    try {
      final session = await ref
          .read(estadoCajonApiProvider)
          .autorizarSupervisor(passwordSupervisor: passwordSupervisor);
      if (!mounted) return;

      ref.read(estadoCajonAuthSessionProvider.notifier).setSession(session);
      ref.invalidate(estadoCajonResumenProvider);
      await ref.read(estadoCajonResumenProvider.future);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autorización de supervisor correcta.'),
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
      retryOnFailure = closeIfCancelled && _isAuthorizationError(error);
    } finally {
      if (mounted) {
        setState(() => _authorizing = false);
      }
    }

    if (retryOnFailure && mounted) {
      await _startAuthorization(closeIfCancelled: true);
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
            title: const Text('Autorización supervisor'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Capture la contraseña de un usuario con rol SUPERVISOR.',
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
                            validationError = 'La contraseña es obligatoria.';
                          });
                          return;
                        }
                        Navigator.of(ctx).pop(value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Contraseña supervisor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: TextStyle(color: Colors.red.shade700),
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
                      validationError = 'La contraseña es obligatoria.';
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

  Future<void> _pickFecha() async {
    final current = ref.read(estadoCajonFechaProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Fecha de consulta',
    );
    if (!mounted) return;
    if (picked == null) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);
    ref.read(estadoCajonFechaProvider.notifier).state = normalized;
    await _refreshResumen();
  }

  Future<void> _refreshResumen() async {
    final session = ref.read(estadoCajonAuthSessionProvider);
    if (session == null) {
      await _startAuthorization(closeIfCancelled: true);
      return;
    }

    ref.invalidate(estadoCajonResumenProvider);
    try {
      await ref.read(estadoCajonResumenProvider.future);
    } catch (error) {
      if (_isAuthorizationError(error)) {
        ref.read(estadoCajonAuthSessionProvider.notifier).clear();
      }
    }
  }

  String _displayForm(EstadoCajonResumenRow row) {
    final form = row.form.trim();
    final nom = row.nom.trim();
    if (nom.isEmpty) return form.isEmpty ? '-' : form;
    if (form.isEmpty) return nom;
    return '$form - $nom';
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return apiErrorMessage(error, fallback: 'No se pudo consultar estado de cajón.');
  }

  bool _isAuthorizationError(Object error) {
    final msg = _errorMessage(error).toLowerCase();
    return msg.contains('autoriz') || msg.contains('supervisor');
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.fecha,
  });

  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Fecha: $y-$m-$d',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
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
          children: [
            const Text(
              'Se requiere autorización de supervisor para visualizar el estado de cajón.',
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Esperando autorización...'),
              ],
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
