import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'clientes_models.dart';
import 'clientes_providers.dart';
import 'cliente_form_page.dart';

class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  final _searchCtrl = TextEditingController();
  String _searchBy = 'NOMBRE';
  FactClientShpModel? _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de cliente'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(clientesListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: clientesAsync.when(
        data: (clientes) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clientesListProvider);
            await ref.read(clientesListProvider.future);
          },
          child: LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final filtered = _filter(clientes);
            if (_selected != null && !filtered.contains(_selected)) {
              _selected = null;
            }

            final listPanel = _ClientesList(
              clientes: filtered,
              selected: _selected,
              onSelect: (c) => setState(() => _selected = c),
            );

            final detailPanel = _ClienteDetail(cliente: _selected);

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _SearchBar(
                  controller: _searchCtrl,
                  searchBy: _searchBy,
                  onSearchByChanged: (v) => setState(() => _searchBy = v),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _selected = null;
                  }),
                  onSearch: () => setState(() {}),
                ),
                const SizedBox(height: 10),
                if (isNarrow) ...[
                  listPanel,
                  const SizedBox(height: 10),
                  detailPanel,
                ] else
                  SizedBox(
                    height: 520,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: listPanel),
                        const SizedBox(width: 10),
                        Expanded(child: detailPanel),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  List<FactClientShpModel> _filter(List<FactClientShpModel> clientes) {
    final term = _searchCtrl.text.trim().toLowerCase();
    if (term.isEmpty) return clientes;
    return clientes.where((c) {
      switch (_searchBy) {
        case 'RFC':
          return c.rfcReceptor.toLowerCase().contains(term);
        case 'IDC':
          return c.idc.toString().toLowerCase().contains(term);
        case 'NOMBRE':
        default:
          return c.razonSocialReceptor.toLowerCase().contains(term);
      }
    }).toList();
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 960,
          child: ClienteFormBody(
            onSaved: () => ref.invalidate(clientesListProvider),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searchBy,
    required this.onSearchByChanged,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final String searchBy;
  final ValueChanged<String> onSearchByChanged;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Text('Buscar por:'),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: searchBy,
              items: const [
                DropdownMenuItem(value: 'NOMBRE', child: Text('NOMBRE')),
                DropdownMenuItem(value: 'RFC', child: Text('RFC')),
                DropdownMenuItem(value: 'IDC', child: Text('IDC')),
              ],
              onChanged: (v) => onSearchByChanged(v ?? 'NOMBRE'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Digite búsqueda',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Buscar',
              onPressed: onSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Limpiar',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientesList extends StatelessWidget {
  const _ClientesList({
    required this.clientes,
    required this.selected,
    required this.onSelect,
  });

  final List<FactClientShpModel> clientes;
  final FactClientShpModel? selected;
  final ValueChanged<FactClientShpModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                SizedBox(width: 70, child: Text('SUC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 8),
                SizedBox(width: 120, child: Text('IDC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 8),
                Expanded(child: Text('NOMBRE O RAZÓN SOCIAL', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 140, child: Text('RFC', style: TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(width: 120, child: Text('NCEL', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: clientes.length,
              itemBuilder: (_, index) {
                final c = clientes[index];
                final selectedRow = selected?.idc == c.idc;
                return InkWell(
                  onTap: () => onSelect(c),
                  child: Container(
                    color: selectedRow ? Colors.blue.shade50 : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text(c.suc ?? '-')),
                        const SizedBox(width: 8),
                        SizedBox(width: 120, child: Text(c.idc.toString())),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.razonSocialReceptor, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 140, child: Text(c.rfcReceptor, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 120, child: Text(c.ncel ?? '-', overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const Divider(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClienteDetail extends StatelessWidget {
  const _ClienteDetail({required this.cliente});

  final FactClientShpModel? cliente;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: cliente == null
            ? const Center(child: Text('Selecciona un cliente para ver el detalle'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'IDC', value: cliente!.idc.toString()),
                    _DetailRow(label: 'Razón social', value: cliente!.razonSocialReceptor),
                    _DetailRow(label: 'RFC receptor', value: cliente!.rfcReceptor),
                    _DetailRow(label: 'Domicilio', value: cliente!.domicilio),
                    _DetailRow(label: 'Email receptor', value: cliente!.emailReceptor),
                    _DetailRow(label: 'Tel/Cel', value: cliente!.ncel),
                    _DetailRow(label: 'RFC emisor', value: cliente!.rfcEmisor),
                    _DetailRow(label: 'Uso CFDI', value: cliente!.usoCfdi),
                    _DetailRow(label: 'Código postal receptor', value: cliente!.codigoPostalReceptor),
                    _DetailRow(label: 'Régimen fiscal receptor', value: cliente!.regimenFiscalReceptor.toString()),
                    _DetailRow(label: 'Sucursal', value: cliente!.suc),
                    _DetailRow(label: 'Tipo', value: cliente!.tipo),
                    _DetailRow(label: 'Cliente UNI', value: cliente!.clientUni?.toString()),
                    _DetailRow(label: 'Crédito', value: cliente!.iCred?.toString()),
                    _DetailRow(label: 'Descuento aplicado', value: cliente!.descuentoApli?.toString()),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 170, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value?.trim().isNotEmpty == true ? value! : '-')),
        ],
      ),
    );
  }
}
