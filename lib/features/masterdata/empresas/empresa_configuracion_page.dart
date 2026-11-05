import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import 'empresa_creditos_config.dart';
import 'empresas_providers.dart';

class EmpresaConfiguracionPage extends ConsumerWidget {
  const EmpresaConfiguracionPage({super.key, required this.idempresa});
  final int idempresa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authControllerProvider).roleId == 1;
    if (!admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración')),
        body: const Center(child: Text('Acceso exclusivo de ADMIN')),
      );
    }
    final config = ref.watch(empresaCreditosConfigProvider(idempresa));
    final empresa = ref.watch(empresaProvider(idempresa)).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración · ${empresa?.razonSocial ?? idempresa}'),
      ),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiErrorMessage(e)),
              TextButton(
                onPressed: () =>
                    ref.invalidate(empresaCreditosConfigProvider(idempresa)),
                child: const Text('Recargar'),
              ),
            ],
          ),
        ),
        data: (data) => _CreditosEditor(
          key: ObjectKey(data),
          idempresa: idempresa,
          config: data,
        ),
      ),
    );
  }
}

class _CreditosEditor extends ConsumerStatefulWidget {
  const _CreditosEditor({
    super.key,
    required this.idempresa,
    required this.config,
  });
  final int idempresa;
  final EmpresaCreditosConfig config;
  @override
  ConsumerState<_CreditosEditor> createState() => _CreditosEditorState();
}

class _CreditosEditorState extends ConsumerState<_CreditosEditor> {
  late String _modo = widget.config.modo;
  late bool _permitir = widget.config.permitir;
  bool _busy = false;
  bool get _dirty =>
      _modo != widget.config.modo || _permitir != widget.config.permitir;

  Future<void> _save(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(empresaCreditosConfigProvider(widget.idempresa));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSucursal(SucursalCreditosConfig item) async {
    String choice = item.permitir == null
        ? 'HEREDAR'
        : item.permitir!
        ? 'PERMITIR'
        : 'BLOQUEAR';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Créditos · ${item.suc}'),
          content: DropdownButtonFormField<String>(
            initialValue: choice,
            items: const [
              DropdownMenuItem(
                value: 'HEREDAR',
                child: Text('Heredar valor de empresa'),
              ),
              DropdownMenuItem(
                value: 'PERMITIR',
                child: Text('Permitir parcialidades'),
              ),
              DropdownMenuItem(
                value: 'BLOQUEAR',
                child: Text('Exigir pago total'),
              ),
            ],
            onChanged: (v) => setDialog(() => choice = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, choice),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _save(
      () => ref
          .read(empresasApiProvider)
          .saveCreditosSucursal(
            widget.idempresa,
            item.suc,
            permitir: result == 'HEREDAR' ? null : result == 'PERMITIR',
            version: item.version,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'CONFIGURACIÓN DE CRÉDITOS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Permitir pago en parcialidades en créditos',
                  ),
                  subtitle: const Text(
                    'Desactivado: cada crédito debe liquidarse por su saldo pendiente completo.',
                  ),
                  value: _permitir,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _permitir = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _modo,
                  decoration: const InputDecoration(labelText: 'Alcance'),
                  items: const [
                    DropdownMenuItem(
                      value: 'EMPRESA',
                      child: Text('Toda la empresa'),
                    ),
                    DropdownMenuItem(
                      value: 'SUCURSAL',
                      child: Text('Configurar por sucursal'),
                    ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _modo = v!),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Toda la empresa aplica el mismo valor a todas las sucursales. Por sucursal usa excepciones; heredar toma el valor de empresa. Las excepciones se conservan al cambiar el alcance.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || !_dirty
                      ? null
                      : () => _save(
                          () => ref
                              .read(empresasApiProvider)
                              .saveCreditosConfig(
                                widget.idempresa,
                                modo: _modo,
                                permitir: _permitir,
                                version: widget.config.version,
                              ),
                        ),
                  child: const Text('Guardar regla de empresa'),
                ),
              ],
            ),
          ),
        ),
        if (_dirty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Guarde la regla antes de editar sucursales. Los valores efectivos mostrados corresponden a la configuración guardada.',
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        for (final item in widget.config.sucursales)
          Card(
            child: ListTile(
              title: Text('${item.suc} · ${item.descripcion}'),
              subtitle: Text(
                '${item.permitir == null
                    ? 'Hereda empresa'
                    : item.permitir!
                    ? 'Excepción: permitir'
                    : 'Excepción: pago total'}\nEfectivo: ${item.efectivo ? 'permite parcialidades' : 'exige pago total'}',
              ),
              trailing: IconButton(
                tooltip: 'Configurar sucursal',
                icon: const Icon(Icons.tune),
                onPressed: _busy || _dirty || widget.config.modo != 'SUCURSAL'
                    ? null
                    : () => _editSucursal(item),
              ),
            ),
          ),
        TextButton(
          onPressed: _busy
              ? null
              : () => ref.invalidate(
                  empresaCreditosConfigProvider(widget.idempresa),
                ),
          child: const Text('Recargar configuración guardada'),
        ),
      ],
    );
  }
}
