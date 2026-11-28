import 'package:flutter/material.dart';

class TraspasosAlmacenesPage extends StatefulWidget {
  const TraspasosAlmacenesPage({super.key});

  @override
  State<TraspasosAlmacenesPage> createState() => _TraspasosAlmacenesPageState();
}

class _TraspasosAlmacenesPageState extends State<TraspasosAlmacenesPage> {
  final _docCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _almacenCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  String _estatus = '';

  @override
  void dispose() {
    _docCtrl.dispose();
    _usuarioCtrl.dispose();
    _almacenCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traspasos entre almacenes'),
        actions: [
          IconButton(
            tooltip: 'Nueva solicitud',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _createRequest,
          ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.center,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _textFilter(_docCtrl, 'Documento', 170),
                  _textFilter(_usuarioCtrl, 'Usuario', 170),
                  _textFilter(_almacenCtrl, 'Almacén', 170),
                  SizedBox(
                    width: 165,
                    child: DropdownButtonFormField<String>(
                      initialValue: _estatus,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Estatus',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'PENDIENTE',
                          child: Text('PENDIENTE'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _estatus = value ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    child: TextField(
                      controller: _fechaCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Fecha',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          tooltip: 'Seleccionar fecha',
                          onPressed: _pickDate,
                        ),
                      ),
                      onTap: _pickDate,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.search),
                    label: const Text('Aplicar filtros'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar filtros'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              clipBehavior: Clip.antiAlias,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textFilter(
    TextEditingController controller,
    String label,
    double width,
  ) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: (_) => _applyFilters(),
    ),
  );

  void _applyFilters() => setState(() {});

  void _clearFilters() {
    _docCtrl.clear();
    _usuarioCtrl.clear();
    _almacenCtrl.clear();
    _fechaCtrl.clear();
    setState(() {
      _estatus = '';
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_fechaCtrl.text) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null)
      _fechaCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _createRequest() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _NewTraspasoAlmacenDialog(),
    );
  }
}

class _NewTraspasoAlmacenDialog extends StatefulWidget {
  const _NewTraspasoAlmacenDialog();
  @override
  State<_NewTraspasoAlmacenDialog> createState() =>
      _NewTraspasoAlmacenDialogState();
}

class _NewTraspasoAlmacenDialogState extends State<_NewTraspasoAlmacenDialog> {
  final _sucOrigenCtrl = TextEditingController();
  final _almacenOrigenCtrl = TextEditingController();
  final _sucDestinoCtrl = TextEditingController();
  final _almacenDestinoCtrl = TextEditingController();

  @override
  void dispose() {
    _sucOrigenCtrl.dispose();
    _almacenOrigenCtrl.dispose();
    _sucDestinoCtrl.dispose();
    _almacenDestinoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva solicitud de traspaso'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Origen', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textEntry('Sucursal de origen', _sucOrigenCtrl),
            const SizedBox(height: 12),
            _textEntry('Almacén de origen', _almacenOrigenCtrl),
            const SizedBox(height: 20),
            const Text(
              'Destino',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _textEntry('Sucursal destino', _sucDestinoCtrl),
            const SizedBox(height: 12),
            _textEntry('Almacén destino', _almacenDestinoCtrl),
            if (_sameLocation)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'El almacén de origen y destino deben ser distintos.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Esta pantalla aún no consulta ni guarda datos. El listado y el guardado se habilitarán cuando se definan dentro del módulo.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Guardar solicitud'),
      ),
    ],
  );

  bool get _sameLocation =>
      _sucOrigenCtrl.text.trim().toUpperCase() ==
          _sucDestinoCtrl.text.trim().toUpperCase() &&
      _almacenOrigenCtrl.text.trim().toUpperCase() ==
          _almacenDestinoCtrl.text.trim().toUpperCase() &&
      _almacenOrigenCtrl.text.trim().isNotEmpty;

  Widget _textEntry(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      );
}
