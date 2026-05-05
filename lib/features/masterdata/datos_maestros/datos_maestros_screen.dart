import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deptos/deptos_models.dart';
import '../deptos/deptos_providers.dart';
import '../roles/roles_models.dart';
import '../roles/roles_providers.dart';
import '../sucursales/sucursales_page.dart';
import 'configuracion_maestra_models.dart';
import 'master_data_notifier.dart';

class DatosMaestrosScreen extends ConsumerStatefulWidget {
  const DatosMaestrosScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<DatosMaestrosScreen> createState() =>
      _DatosMaestrosScreenState();
}

class _DatosMaestrosScreenState extends ConsumerState<DatosMaestrosScreen>
    with SingleTickerProviderStateMixin {
  final _empresaCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _empresaFocus = FocusNode();
  final _nitFocus = FocusNode();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _empresaCtrl.dispose();
    _nitCtrl.dispose();
    _empresaFocus.dispose();
    _nitFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masterDataNotifierProvider);
    final notifier = ref.read(masterDataNotifierProvider.notifier);
    final model = state.model;

    if (!_empresaFocus.hasFocus && _empresaCtrl.text != model.nombreEmpresa) {
      _empresaCtrl.text = model.nombreEmpresa;
      _empresaCtrl.selection = TextSelection.collapsed(
        offset: _empresaCtrl.text.length,
      );
    }
    if (!_nitFocus.hasFocus && _nitCtrl.text != model.nitEmpresa) {
      _nitCtrl.text = model.nitEmpresa;
      _nitCtrl.selection = TextSelection.collapsed(
        offset: _nitCtrl.text.length,
      );
    }

    final body = _buildBody(context, state, notifier, model);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF149A9A),
        foregroundColor: Colors.white,
        title: const Text('Reloj checador - App'),
      ),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    MasterDataState state,
    MasterDataNotifier notifier,
    ConfiguracionMaestraModel model,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: Column(
        children: [
          Material(
            color: const Color(0xFFF7F7FA),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.tune), text: 'Configuración'),
                Tab(icon: Icon(Icons.store), text: 'Sucursales'),
                Tab(icon: Icon(Icons.account_tree), text: 'Departamentos'),
                Tab(icon: Icon(Icons.badge), text: 'Cargos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: notifier.load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ((state.errorMessage ?? '').isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE7E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFC62828),
                              ),
                            ),
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFB71C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _DataCard(
                          title: 'Configuración Empresa',
                          child: Column(
                            children: [
                              TextField(
                                controller: _empresaCtrl,
                                focusNode: _empresaFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre empresa',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: notifier.setNombreEmpresa,
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _nitCtrl,
                                focusNode: _nitFocus,
                                decoration: const InputDecoration(
                                  labelText: 'NIT',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: notifier.setNitEmpresa,
                              ),
                            ],
                          ),
                        ),
                        _DataCard(
                          title: 'Reglas del Reloj',
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('GpsObligatorio'),
                                value: model.gpsObligatorio,
                                onChanged: notifier.setGpsObligatorio,
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('LivenessObligatorio'),
                                value: model.livenessObligatorio,
                                onChanged: notifier.setLivenessObligatorio,
                              ),
                            ],
                          ),
                        ),
                        _DataCard(
                          title: 'Catálogos',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Departamentos',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _buildInlineDeptos(context),
                              const Divider(height: 28),
                              const Text(
                                'Cargos',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _buildInlinePuestos(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            icon: state.saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            onPressed: state.saving
                                ? null
                                : () async {
                                    final ok = await notifier.saveAll();
                                    if (!mounted || !context.mounted) return;
                                    final msg = ok
                                        ? 'Configuración guardada y sincronizada'
                                        : 'No se pudo guardar configuración';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  },
                            label: const Text('Guardar Configuración'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SucursalesPage(embedded: true, allowConfiguration: true),
                const _DeptosCrudTab(),
                const _PuestosCrudTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDeptos(BuildContext context) {
    final asyncRows = ref.watch(deptosListProvider);
    final rows = asyncRows.valueOrNull ?? const <DeptoModel>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _openDeptoForm(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(deptosListProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refrescar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (asyncRows.isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: rows.map((d) => Chip(
              label: Text(d.nombre),
              onDeleted: () => _deleteDepto(context, d),
            )).toList(growable: false),
          ),
      ],
    );
  }

  Future<void> _openDeptoForm(BuildContext context, {DeptoModel? current}) async {
    final nombreCtrl = TextEditingController(text: current?.nombre ?? '');
    var activo = current?.activo ?? true;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: Text(current == null ? 'Nuevo departamento' : 'Editar departamento'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: activo,
                    onChanged: (value) => setLocalState(() => activo = value),
                    title: const Text('Activo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  if (nombre.isEmpty) return;
                  try {
                    final api = ref.read(deptosApiProvider);
                    final payload = <String, dynamic>{'NOMBRE': nombre, 'ACTIVO': activo};
                    if (current == null) {
                      await api.createDepto(payload);
                    } else {
                      await api.updateDepto(current.id, payload);
                    }
                    ref.invalidate(deptosListProvider);
                    ref.read(masterDataNotifierProvider.notifier).syncAll();
                    if (!mounted || !ctx.mounted) return;
                    Navigator.of(ctx, rootNavigator: true).pop();
                  } catch (_) {}
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nombreCtrl.dispose();
    }
  }

  Future<void> _deleteDepto(BuildContext context, DeptoModel row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar departamento'),
        content: Text('¿Eliminar "${row.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(deptosApiProvider).deleteDepto(row.id);
    ref.invalidate(deptosListProvider);
    ref.read(masterDataNotifierProvider.notifier).syncAll();
  }

  Widget _buildInlinePuestos(BuildContext context) {
    final asyncRows = ref.watch(rolesListProvider);
    final rows = asyncRows.valueOrNull ?? const <RoleModel>[];
    final deptos = ref.watch(deptosListProvider).valueOrNull ?? const <DeptoModel>[];
    final cargos = rows.where((r) => r.iddepartamento != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: deptos.isEmpty ? null : () => _openPuestoForm(context, deptos: deptos),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(rolesListProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refrescar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (asyncRows.isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: cargos.map((p) => Chip(
              label: Text(p.nombre),
              deleteIcon: const Icon(Icons.delete, size: 18),
              onDeleted: () => _deletePuesto(context, p),
            )).toList(growable: false),
          ),
      ],
    );
  }

  Future<void> _openPuestoForm(BuildContext context, {required List<DeptoModel> deptos, RoleModel? current}) async {
    final nombreCtrl = TextEditingController(text: current?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: current?.codigo ?? '');
    var activo = current?.activo ?? true;
    var idDepto = current?.iddepartamento ?? (deptos.isNotEmpty ? deptos.first.id : 0);
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: Text(current == null ? 'Nuevo cargo' : 'Editar cargo'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: idDepto == 0 ? null : idDepto,
                    items: deptos.map((d) => DropdownMenuItem<int>(value: d.id, child: Text(d.nombre))).toList(growable: false),
                    onChanged: (value) => setLocalState(() => idDepto = value ?? idDepto),
                    decoration: const InputDecoration(labelText: 'Departamento', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codigoCtrl,
                    decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Cargo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: activo,
                    onChanged: (value) => setLocalState(() => activo = value),
                    title: const Text('Activo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  final codigo = codigoCtrl.text.trim().toUpperCase();
                  if (nombre.isEmpty || codigo.isEmpty || idDepto <= 0) return;
                  try {
                    final payload = <String, dynamic>{
                      'CODIGO': codigo, 'NOMBRE': nombre, 'IDDEPTO': idDepto, 'ACTIVO': activo,
                    };
                    final api = ref.read(rolesApiProvider);
                    if (current == null) {
                      await api.createRole(payload);
                    } else {
                      await api.updateRole(current.id, payload);
                    }
                    ref.invalidate(rolesListProvider);
                    ref.read(masterDataNotifierProvider.notifier).syncAll();
                    if (!mounted || !ctx.mounted) return;
                    Navigator.of(ctx, rootNavigator: true).pop();
                  } catch (_) {}
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nombreCtrl.dispose();
      codigoCtrl.dispose();
    }
  }

  Future<void> _deletePuesto(BuildContext context, RoleModel row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cargo'),
        content: Text('¿Eliminar "${row.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(rolesApiProvider).deleteRole(row.id);
    ref.invalidate(rolesListProvider);
    ref.read(masterDataNotifierProvider.notifier).syncAll();
  }
}

class _DeptosCrudTab extends ConsumerStatefulWidget {
  const _DeptosCrudTab();

  @override
  ConsumerState<_DeptosCrudTab> createState() => _DeptosCrudTabState();
}

class _DeptosCrudTabState extends ConsumerState<_DeptosCrudTab> {
  bool _saving = false;

  Future<void> _openForm({DeptoModel? current}) async {
    final nombreCtrl = TextEditingController(text: current?.nombre ?? '');
    var activo = current?.activo ?? true;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: Text(
              current == null ? 'Nuevo departamento' : 'Editar departamento',
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: activo,
                    onChanged: _saving
                        ? null
                        : (value) => setLocalState(() => activo = value),
                    title: const Text('Activo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final nombre = nombreCtrl.text.trim();
                        if (nombre.isEmpty) return;
                        setLocalState(() => _saving = true);
                        try {
                          final api = ref.read(deptosApiProvider);
                          final payload = <String, dynamic>{
                            'NOMBRE': nombre,
                            'ACTIVO': activo,
                          };
                          if (current == null) {
                            await api.createDepto(payload);
                          } else {
                            await api.updateDepto(current.id, payload);
                          }
                          ref.invalidate(deptosListProvider);
                          ref
                              .read(masterDataNotifierProvider.notifier)
                              .syncAll();
                          if (!mounted || !ctx.mounted) return;
                          final navigator = Navigator.of(
                            ctx,
                            rootNavigator: true,
                          );
                          FocusScope.of(ctx).unfocus();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            if (navigator.canPop()) navigator.pop();
                          });
                        } finally {
                          if (ctx.mounted) {
                            setLocalState(() => _saving = false);
                          }
                        }
                      },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nombreCtrl.dispose();
    }
  }

  Future<void> _delete(DeptoModel row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar departamento'),
        content: Text('¿Eliminar "${row.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(deptosApiProvider).deleteDepto(row.id);
    ref.invalidate(deptosListProvider);
    ref.read(masterDataNotifierProvider.notifier).syncAll();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(deptosListProvider);
    return Container(
      color: const Color(0xFFF3F4F7),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(deptosListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refrescar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: asyncRows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Error: $error')),
              data: (rows) => ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      title: Text(row.nombre),
                      subtitle: Text(row.activo ? 'Activo' : 'Inactivo'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () => _openForm(current: row),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () => _delete(row),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PuestosCrudTab extends ConsumerStatefulWidget {
  const _PuestosCrudTab();

  @override
  ConsumerState<_PuestosCrudTab> createState() => _PuestosCrudTabState();
}

class _PuestosCrudTabState extends ConsumerState<_PuestosCrudTab> {
  bool _saving = false;

  Future<void> _openForm({
    required List<DeptoModel> deptos,
    RoleModel? current,
  }) async {
    final nombreCtrl = TextEditingController(text: current?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: current?.codigo ?? '');
    var activo = current?.activo ?? true;
    var idDepto = current?.iddepartamento ?? (deptos.isNotEmpty ? deptos.first.id : 0);
    if (idDepto == 0 && deptos.isNotEmpty) idDepto = deptos.first.id;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: Text(current == null ? 'Nuevo cargo' : 'Editar cargo'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: idDepto == 0 ? null : idDepto,
                    items: deptos.map((d) => DropdownMenuItem<int>(
                      value: d.id, child: Text(d.nombre),
                    )).toList(growable: false),
                    onChanged: _saving ? null : (value) => setLocalState(() => idDepto = value ?? idDepto),
                    decoration: const InputDecoration(labelText: 'Departamento', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codigoCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Cargo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: activo,
                    onChanged: _saving ? null : (value) => setLocalState(() => activo = value),
                    title: const Text('Activo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: _saving ? null : () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              FilledButton(
                onPressed: _saving ? null : () async {
                  final nombre = nombreCtrl.text.trim();
                  final codigo = codigoCtrl.text.trim().toUpperCase();
                  if (nombre.isEmpty || codigo.isEmpty || idDepto <= 0) return;
                  setLocalState(() => _saving = true);
                  try {
                    final payload = <String, dynamic>{
                      'CODIGO': codigo, 'NOMBRE': nombre, 'IDDEPTO': idDepto, 'ACTIVO': activo,
                    };
                    final api = ref.read(rolesApiProvider);
                    if (current == null) {
                      await api.createRole(payload);
                    } else {
                      await api.updateRole(current.id, payload);
                    }
                    ref.invalidate(rolesListProvider);
                    ref.read(masterDataNotifierProvider.notifier).syncAll();
                    if (!mounted || !ctx.mounted) return;
                    Navigator.of(ctx, rootNavigator: true).pop();
                  } finally {
                    if (ctx.mounted) setLocalState(() => _saving = false);
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nombreCtrl.dispose();
      codigoCtrl.dispose();
    }
  }

  Future<void> _delete(RoleModel row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cargo'),
        content: Text('¿Eliminar "${row.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(rolesApiProvider).deleteRole(row.id);
    ref.invalidate(rolesListProvider);
    ref.read(masterDataNotifierProvider.notifier).syncAll();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRoles = ref.watch(rolesListProvider);
    final deptos = ref.watch(deptosListProvider).valueOrNull ?? const <DeptoModel>[];
    return Container(
      color: const Color(0xFFF3F4F7),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: deptos.isEmpty ? null : () => _openForm(deptos: deptos),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(rolesListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refrescar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: asyncRoles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('Error: $error')),
              data: (rows) {
                final cargos = rows.where((r) => r.iddepartamento != null).toList();
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cargos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final row = cargos[index];
                    final deptoNombre = deptos
                        .where((d) => d.id == row.iddepartamento)
                        .map((d) => d.nombre)
                        .firstOrNull ?? '';
                    return Card(
                      child: ListTile(
                        title: Text('${row.nombre} (${row.codigo})'),
                        subtitle: Text(deptoNombre.isNotEmpty ? deptoNombre : 'IDDEPTO: ${row.iddepartamento}'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              onPressed: deptos.isEmpty ? null : () => _openForm(deptos: deptos, current: row),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              onPressed: () => _delete(row),
                              icon: const Icon(Icons.delete),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  } // end of _PuestosCrudTabState.build
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
