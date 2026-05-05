import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sucursales_models.dart';
import 'sucursales_providers.dart';

class SucursalesPage extends ConsumerStatefulWidget {
  const SucursalesPage({
    super.key,
    this.embedded = false,
    this.allowConfiguration = true,
  });

  final bool embedded;
  final bool allowConfiguration;

  @override
  ConsumerState<SucursalesPage> createState() => _SucursalesPageState();
}

class _SucursalesPageState extends ConsumerState<SucursalesPage> {
  final Set<int> _selectedIds = <int>{};
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(sucursalesGestionListProvider);
    await ref.read(sucursalesGestionListProvider.future);
  }

  Future<void> _safeDialogPop(BuildContext dialogContext, [Object? result]) async {
    if (!mounted || !context.mounted || !dialogContext.mounted) return;
    FocusScope.of(dialogContext).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(dialogContext, rootNavigator: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !navigator.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (navigator.canPop()) navigator.pop(result);
    });
  }

  Future<void> _showEditor({SucursalGestionModel? row}) async {
    final isEdit = row != null;
    final codigoCtrl = TextEditingController(text: row?.codigo ?? '');
    final nombreCtrl = TextEditingController(text: row?.nombre ?? '');
    final empresaCtrl = TextEditingController(text: row?.empresa ?? '');
    final direccionCtrl = TextEditingController(text: row?.direccion ?? '');
    final telefonoCtrl = TextEditingController(text: row?.telefono ?? '');
    var activo = row?.estado ?? true;
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(isEdit ? 'Editar sucursal' : 'Agregar sucursal'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codigoCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Código sucursal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nombreCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Nombre sucursal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: empresaCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Empresa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: direccionCtrl,
                      enabled: !saving,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Dirección completa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: telefonoCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: activo,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => activo = value),
                      title: const Text('Activo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => _safeDialogPop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final codigo = codigoCtrl.text.trim();
                        final nombre = nombreCtrl.text.trim();
                        final empresa = empresaCtrl.text.trim();
                        if (codigo.isEmpty || nombre.isEmpty || empresa.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código, nombre y empresa son requeridos'),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => saving = true);
                        final payload = <String, dynamic>{
                          'codigo': codigo,
                          'nombre': nombre,
                          'empresa': empresa,
                          'activo': activo,
                          'estado': activo,
                        };
                        if (direccionCtrl.text.trim().isNotEmpty) {
                          payload['direccion_completa'] = direccionCtrl.text.trim();
                        }
                        if (telefonoCtrl.text.trim().isNotEmpty) {
                          payload['telefono'] = telefonoCtrl.text.trim();
                        }

                        try {
                          final api = ref.read(sucursalesApiProvider);
                          if (isEdit) {
                            await api.updateGestionSucursal(row.id, payload);
                          } else {
                            await api.createGestionSucursal(payload);
                          }
                          if (!mounted) return;
                          await _refresh();
                          if (!mounted || !context.mounted) return;
                          await _safeDialogPop(ctx);
                          if (!mounted || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Sucursal actualizada' : 'Sucursal agregada',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('No se pudo guardar: $e')),
                          );
                        }
                      },
                child: Text(isEdit ? 'Guardar cambios' : 'Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      codigoCtrl.dispose();
      nombreCtrl.dispose();
      empresaCtrl.dispose();
      direccionCtrl.dispose();
      telefonoCtrl.dispose();
    }
  }

  Future<void> _deleteSelected(List<SucursalGestionModel> rows) async {
    if (_selectedIds.isEmpty) return;
    final toDelete = rows.where((e) => _selectedIds.contains(e.id)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar sucursal'),
        content: Text('¿Eliminar ${toDelete.length} sucursal(es)?'),
        actions: [
          TextButton(
            onPressed: () => _safeDialogPop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _safeDialogPop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final api = ref.read(sucursalesApiProvider);
      for (final row in toDelete) {
        await api.deleteGestionSucursal(row.id);
      }
      if (!mounted) return;
      _selectedIds.clear();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sucursal(es) eliminada(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(sucursalesGestionListProvider);

    final body = asyncRows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        return Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _showEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF245FAE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _busy || _selectedIds.isEmpty
                        ? null
                        : () => _deleteSelected(rows),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Refrescar',
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh, size: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB8BDC7)),
                ),
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF67717E),
                      ),
                      columns: const [
                        DataColumn(label: SizedBox(width: 36, child: Text(''))),
                        DataColumn(
                          label: SizedBox(
                            width: 460,
                            child: Text(
                              'Nombre sucursal',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 320,
                            child: Text(
                              'Empresa',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 160,
                            child: Text(
                              'Estado',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 140,
                            child: Text(
                              'Acciones',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                      rows: [
                        for (var i = 0; i < rows.length; i++)
                          _buildRow(rows[i], i),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Sucursales')),
      body: body,
    );
  }

  DataRow _buildRow(SucursalGestionModel row, int index) {
    final selected = _selectedIds.contains(row.id);
    final background = selected
        ? const Color(0xFFAFCAE0)
        : const Color(0xFFF0F1F4);

    return DataRow(
      selected: selected,
      color: WidgetStateProperty.all(background),
      cells: [
        DataCell(
          Checkbox(
            value: selected,
            onChanged: _busy
                ? null
                : (value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds.add(row.id);
                      } else {
                        _selectedIds.remove(row.id);
                      }
                    });
                  },
          ),
        ),
        DataCell(
          SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 30 / 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(row.codigo, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ),
        DataCell(SizedBox(width: 320, child: Text(row.empresa))),
        DataCell(
          SizedBox(
            width: 160,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: row.estado
                      ? const Color(0xFFCFE8CD)
                      : const Color(0xFFF0D7DA),
                ),
                child: Text(
                  row.estado ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: row.estado ? const Color(0xFF1B6D28) : const Color(0xFFC62828),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 140,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditor(row: row);
                } else if (value == 'delete') {
                  setState(() => _selectedIds
                    ..clear()
                    ..add(row.id));
                  _deleteSelected(<SucursalGestionModel>[row]);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
              child: const Align(
                alignment: Alignment.center,
                child: Icon(Icons.more_vert, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
