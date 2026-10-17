import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/app_theme.dart';
import 'package:ioe_app/core/dio_provider.dart';

import 'colaboradores_taller_api.dart';

class ColaboradoresTallerPage extends ConsumerStatefulWidget {
  const ColaboradoresTallerPage({super.key});
  @override
  ConsumerState<ColaboradoresTallerPage> createState() =>
      _ColaboradoresTallerPageState();
}

class _ColaboradoresTallerPageState
    extends ConsumerState<ColaboradoresTallerPage> {
  late final ColaboradoresTallerApi _api;
  late Future<ColaboradoresTallerResultado> _future;
  String? _sucursalSeleccionada;
  String? _departamentoSeleccionado;
  String? _estatusSeleccionado;
  String? _sucursalPendiente;
  String? _departamentoPendiente;
  String? _estatusPendiente;
  String _nombreSeleccionado = '';
  String _apellidosSeleccionado = '';
  String _nombrePendiente = '';
  String _apellidosPendiente = '';
  List<String> _sucursalesDisponibles = const [];
  Map<String, String> _nombresSucursales = const {};

  @override
  void initState() {
    super.initState();
    _api = ColaboradoresTallerApi(ref.read(dioProvider));
    _future = _api.listar();
  }

  void _reload() {
    setState(() {
      _future = _api.listar();
    });
  }

  void _aplicarFiltros() {
    setState(() {
      _sucursalSeleccionada = _sucursalPendiente;
      _departamentoSeleccionado = _departamentoPendiente;
      _estatusSeleccionado = _estatusPendiente;
      _nombreSeleccionado = _nombrePendiente.trim();
      _apellidosSeleccionado = _apellidosPendiente.trim();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _sucursalPendiente = null;
      _departamentoPendiente = null;
      _estatusPendiente = null;
      _nombrePendiente = '';
      _apellidosPendiente = '';
      _sucursalSeleccionada = null;
      _departamentoSeleccionado = null;
      _estatusSeleccionado = null;
      _nombreSeleccionado = '';
      _apellidosSeleccionado = '';
    });
  }

  Future<void> _toggle(ColaboradorTaller item, bool activo) async {
    try {
      await _api.cambiarEstatus(item.idopv, activo);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    }
  }

  Future<void> _crear({ColaboradorTaller? colaborador}) async {
    final formKey = GlobalKey<FormState>();
    final nombre = TextEditingController(),
        apelp = TextEditingController(),
        apelM = TextEditingController();
    nombre.text = colaborador?.nombre ?? '';
    final apellidos = (colaborador?.apellidos ?? '').split(' ');
    apelp.text = apellidos.isEmpty ? '' : apellidos.first;
    apelM.text = apellidos.length > 1 ? apellidos.sublist(1).join(' ') : '';
    String? suc = colaborador?.suc;
    String departamento = colaborador?.departamento.toUpperCase() == 'BISELADO'
        ? 'BISELADO'
        : 'TALLER';
    final editando = colaborador != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: Text(
          editando ? 'Editar colaborador' : 'Registrar colaborador de taller',
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(nombre, 'Nombre'),
                  _field(apelp, 'Apellido paterno'),
                  _field(apelM, 'Apellido materno'),
                  DropdownButtonFormField<String>(
                    initialValue: departamento,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TALLER', child: Text('TALLER')),
                      DropdownMenuItem(
                        value: 'BISELADO',
                        child: Text('BISELADO'),
                      ),
                    ],
                    onChanged: (value) => departamento = value ?? 'TALLER',
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: suc,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    items: _sucursalesDisponibles
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _etiquetaSucursal(value),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => suc = value,
                    validator: (value) => value == null ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (editando) {
        await _api.actualizar(
          idopv: colaborador.idopv,
          nombre: nombre.text.trim(),
          apelp: apelp.text.trim(),
          apelM: apelM.text.trim(),
          suc: suc!,
          departamento: departamento,
        );
      } else {
        await _api.crear(
          nombre: nombre.text.trim(),
          apelp: apelp.text.trim(),
          apelM: apelM.text.trim(),
          suc: suc!,
          departamento: departamento,
        );
      }
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editando
                  ? 'Colaborador actualizado correctamente.'
                  : 'Colaborador registrado correctamente.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                e,
                fallback: editando
                    ? 'No se pudieron actualizar los datos del colaborador.'
                    : 'No se pudo registrar el colaborador.',
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
    ),
  );

  List<String> _sucursales(List<ColaboradorTaller> items) {
    final values = items
        .map((item) => item.suc)
        .where((s) => s.isNotEmpty)
        .toSet();
    return values.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Colaboradores de Taller'),
            Text(
              'Registro y activación de colaboradores',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: _crear,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navy,
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo colaborador'),
            ),
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.canvas, AppColors.canvasAlt],
          ),
        ),
        child: FutureBuilder<ColaboradoresTallerResultado>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar los colaboradores: ${snapshot.error}',
                ),
              );
            }
            final result =
                snapshot.data ??
                const ColaboradoresTallerResultado(items: [], sucursales: []);
            final allItems = result.items;
            final sucursales = result.sucursales.isEmpty
                ? _sucursales(allItems)
                : result.sucursales.map((item) => item.codigo).toList();
            _nombresSucursales = {
              for (final item in result.sucursales) item.codigo: item.nombre,
            };
            _sucursalesDisponibles = sucursales;
            final items = allItems.where((item) {
              final coincideSucursal =
                  _sucursalSeleccionada == null ||
                  item.suc == _sucursalSeleccionada;
              final coincideDepartamento =
                  _departamentoSeleccionado == null ||
                  item.departamento == _departamentoSeleccionado;
              final coincideEstatus =
                  _estatusSeleccionado == null ||
                  item.estatus.toUpperCase() == _estatusSeleccionado;
              final coincideNombre = _contiene(
                item.nombre,
                _nombreSeleccionado,
              );
              final coincideApellidos = _contiene(
                item.apellidos,
                _apellidosSeleccionado,
              );
              return coincideSucursal &&
                  coincideDepartamento &&
                  coincideEstatus &&
                  coincideNombre &&
                  coincideApellidos;
            }).toList();
            if (items.isEmpty) {
              return Column(
                children: [
                  _filters(sucursales),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No hay colaboradores para la sucursal seleccionada.',
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _filters(sucursales),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Scrollbar(
                        thumbVisibility: false,
                        interactive: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 980),
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Nombre')),
                                  DataColumn(label: Text('Apellidos')),
                                  DataColumn(label: Text('Sucursal')),
                                  DataColumn(label: Text('Departamento')),
                                  DataColumn(label: Text('Estatus')),
                                  DataColumn(label: Text('Acción')),
                                ],
                                rows: items
                                    .map(
                                      (item) => DataRow(
                                        cells: [
                                          DataCell(Text(item.idopv)),
                                          DataCell(Text(item.nombre)),
                                          DataCell(Text(item.apellidos)),
                                          DataCell(Text(item.suc)),
                                          DataCell(
                                            Text(
                                              _etiquetaDepartamento(
                                                item.departamento,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(item.estatus)),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () =>
                                                      _crear(colaborador: item),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text('Editar'),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.navy,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                ),
                                                Switch(
                                                  value:
                                                      item.estatus
                                                          .toUpperCase() ==
                                                      'ACTIVO',
                                                  onChanged: (value) =>
                                                      _toggle(item, value),
                                                ),
                                                Text(
                                                  item.estatus.toUpperCase() ==
                                                          'ACTIVO'
                                                      ? 'Activo'
                                                      : 'Inactivo',
                                                ),
                                              ],
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
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _etiquetaSucursal(String codigo) {
    final nombre = _nombresSucursales[codigo];
    return nombre == null || nombre.isEmpty ? codigo : '$codigo - $nombre';
  }

  String _etiquetaDepartamento(String departamento) {
    return departamento.trim().toUpperCase() == 'TALLER'
        ? 'TALLER'
        : departamento;
  }

  bool _contiene(String valor, String filtro) {
    final cleanFilter = filtro.trim().toUpperCase();
    if (cleanFilter.isEmpty) return true;
    return valor.toUpperCase().contains(cleanFilter);
  }

  Widget _filters(List<String> sucursales) => Card(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Filtrar colaboradores',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          _textFilter(
            label: 'Nombre',
            value: _nombrePendiente,
            onChanged: (value) => _nombrePendiente = value,
          ),
          _textFilter(
            label: 'Apellidos',
            value: _apellidosPendiente,
            onChanged: (value) => _apellidosPendiente = value,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _sucursalPendiente,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sucursal'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Seleccione'),
                  ),
                  ...sucursales.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        _etiquetaSucursal(s),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _sucursalPendiente = value),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: _departamentoPendiente,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Departamento'),
              items: const [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Seleccione'),
                ),
                DropdownMenuItem(value: 'TALLER', child: Text('TALLER')),
                DropdownMenuItem(value: 'BISELADO', child: Text('BISELADO')),
              ],
              onChanged: (value) =>
                  setState(() => _departamentoPendiente = value),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              initialValue: _estatusPendiente,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Estatus'),
              items: const [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Seleccione'),
                ),
                DropdownMenuItem(value: 'ACTIVO', child: Text('Activo')),
                DropdownMenuItem(value: 'INACTIVO', child: Text('Inactivo')),
              ],
              onChanged: (value) => setState(() => _estatusPendiente = value),
            ),
          ),
          FilledButton.icon(
            onPressed: _aplicarFiltros,
            icon: const Icon(Icons.search),
            label: const Text('Aplicar filtros'),
          ),
          OutlinedButton.icon(
            onPressed: _limpiarFiltros,
            icon: const Icon(Icons.clear),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    ),
  );

  Widget _textFilter({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) => SizedBox(
    width: 175,
    child: TextFormField(
      key: ValueKey('$label:$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    ),
  );
}
