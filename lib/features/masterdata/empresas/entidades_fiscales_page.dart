import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import 'empresas_providers.dart';
import 'entidades_fiscales_models.dart';

class EntidadesFiscalesPage extends ConsumerStatefulWidget {
  const EntidadesFiscalesPage({super.key});

  @override
  ConsumerState<EntidadesFiscalesPage> createState() =>
      _EntidadesFiscalesPageState();
}

class _EntidadesFiscalesPageState extends ConsumerState<EntidadesFiscalesPage> {
  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authControllerProvider).roleId == 1;
    final entities = ref.watch(entidadesFiscalesListProvider);
    final branches = ref.watch(sucursalesFiscalesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entidades fiscales'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () {
              ref.invalidate(entidadesFiscalesListProvider);
              ref.invalidate(sucursalesFiscalesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _editEntity(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar entidad'),
            )
          : null,
      body: !isAdmin
          ? const Center(child: Text('Acceso exclusivo de ADMIN.'))
          : entities.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (items) => branches.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
                data: (options) => items.isEmpty
                    ? const Center(
                        child: Text('No hay entidades fiscales registradas.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _entityCard(items[index], options),
                      ),
              ),
            ),
    );
  }

  Widget _entityCard(
    EntidadFiscalModel entity,
    List<SucursalFiscalOption> options,
  ) {
    final label = entity.nombreLegal ?? 'Nombre legal pendiente';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.person_outline),
              title: Text(label),
              subtitle: Text(
                'RFC ${entity.rfc}  •  Persona ${entity.tipoPersona.toLowerCase()}\n'
                'Estado: ${entity.estadoValidacion}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Editar datos fiscales',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editEntity(entity: entity),
                  ),
                  IconButton(
                    tooltip: 'Vincular sucursal',
                    icon: const Icon(Icons.add_link),
                    onPressed: () => _linkBranch(entity, options),
                  ),
                ],
              ),
            ),
            if (entity.origenCandidato != null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Candidato tomado de DAT_SUC.RFC. Requiere validar constancia fiscal.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if (entity.sucursales.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('Sin sucursales vinculadas.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entity.sucursales
                    .map(
                      (link) => ActionChip(
                        avatar: Icon(
                          link.estadoValidacion == 'VALIDADA'
                              ? Icons.verified_outlined
                              : Icons.pending_outlined,
                          size: 18,
                        ),
                        label: Text(
                          '${link.suc} · ${link.estadoValidacion.toLowerCase()}',
                        ),
                        onPressed: () => _editLink(entity, link),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editEntity({EntidadFiscalModel? entity}) async {
    final formKey = GlobalKey<FormState>();
    final rfc = TextEditingController(text: entity?.rfc ?? '');
    final legalName = TextEditingController(text: entity?.nombreLegal ?? '');
    final commercialName = TextEditingController(
      text: entity?.nombreComercial ?? '',
    );
    final regime = TextEditingController(text: entity?.regimenFiscal ?? '');
    final postalCode = TextEditingController(text: entity?.cpFiscal ?? '');
    final address = TextEditingController(text: entity?.domicilioFiscal ?? '');
    final evidence = TextEditingController(
      text: entity?.referenciaValidacion ?? '',
    );
    var personType = entity?.tipoPersona ?? 'FISICA';
    var status = entity?.estadoValidacion ?? 'PENDIENTE';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            entity == null ? 'Nueva entidad fiscal' : 'Editar entidad',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: rfc,
                      enabled: entity == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'RFC'),
                      validator: entity == null
                          ? (value) => (value == null || value.trim().isEmpty)
                                ? 'RFC requerido'
                                : null
                          : null,
                    ),
                    if (entity == null)
                      DropdownButtonFormField<String>(
                        initialValue: personType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de persona',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FISICA',
                            child: Text('Física'),
                          ),
                          DropdownMenuItem(
                            value: 'MORAL',
                            child: Text('Moral'),
                          ),
                        ],
                        onChanged: (value) => setDialogState(
                          () => personType = value ?? 'FISICA',
                        ),
                      ),
                    TextFormField(
                      controller: legalName,
                      decoration: const InputDecoration(
                        labelText: 'Nombre legal según constancia fiscal',
                      ),
                    ),
                    TextFormField(
                      controller: commercialName,
                      decoration: const InputDecoration(
                        labelText: 'Nombre comercial (opcional)',
                      ),
                    ),
                    TextFormField(
                      controller: regime,
                      decoration: const InputDecoration(
                        labelText: 'Régimen fiscal (clave SAT)',
                      ),
                    ),
                    TextFormField(
                      controller: postalCode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Código postal fiscal',
                      ),
                    ),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(
                        labelText: 'Domicilio fiscal',
                      ),
                    ),
                    if (entity != null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Estado de validación',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'PENDIENTE',
                            child: Text('Pendiente'),
                          ),
                          DropdownMenuItem(
                            value: 'VALIDADA',
                            child: Text('Validada'),
                          ),
                          DropdownMenuItem(
                            value: 'INACTIVA',
                            child: Text('Inactiva'),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => status = value ?? 'PENDIENTE'),
                      ),
                      TextFormField(
                        controller: evidence,
                        decoration: const InputDecoration(
                          labelText: 'Referencia de constancia/revisión',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (status == 'VALIDADA' &&
                    (legalName.text.trim().isEmpty ||
                        regime.text.trim().isEmpty ||
                        !RegExp(r'^\d{5}$').hasMatch(postalCode.text.trim()) ||
                        evidence.text.trim().isEmpty)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Para validar: nombre legal, régimen, CP y referencia.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final api = ref.read(empresasApiProvider);
      final payload = <String, dynamic>{
        'nombreLegal': _emptyToNull(legalName.text),
        'nombreComercial': _emptyToNull(commercialName.text),
        'regimenFiscal': _emptyToNull(regime.text),
        'cpFiscal': _emptyToNull(postalCode.text),
        'domicilioFiscal': _emptyToNull(address.text),
      };
      try {
        if (entity == null) {
          await api.createEntidadFiscal({
            ...payload,
            'rfc': rfc.text.trim().toUpperCase(),
            'tipoPersona': personType,
          });
        } else {
          await api.updateEntidadFiscal(entity.idEntidadFiscal, {
            ...payload,
            'estadoValidacion': status,
            'referenciaValidacion': _emptyToNull(evidence.text),
          });
        }
        _refresh();
        _message(
          entity == null
              ? 'Entidad creada pendiente de validación.'
              : 'Entidad actualizada.',
        );
      } catch (error) {
        _message('No se guardó la entidad: $error');
      }
    }
    rfc.dispose();
    legalName.dispose();
    commercialName.dispose();
    regime.dispose();
    postalCode.dispose();
    address.dispose();
    evidence.dispose();
  }

  Future<void> _linkBranch(
    EntidadFiscalModel entity,
    List<SucursalFiscalOption> options,
  ) async {
    if (options.isEmpty) return;
    final date = TextEditingController();
    var suc = options.first.suc;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Vincular sucursal a ${entity.rfc}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: suc,
                decoration: const InputDecoration(labelText: 'Sucursal'),
                items: options
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.suc,
                        child: Text(
                          '${item.suc} · ${item.descripcion ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => suc = value ?? suc),
              ),
              TextField(
                controller: date,
                decoration: const InputDecoration(
                  labelText: 'Vigencia inicial (AAAA-MM-DD, si se conoce)',
                ),
              ),
              const SizedBox(height: 8),
              const Text('El vínculo se guarda como PENDIENTE de revisión.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Vincular'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await ref.read(empresasApiProvider).linkEntidadFiscalSucursal(
          entity.idEntidadFiscal,
          {'suc': suc, 'vigenteDesde': _emptyToNull(date.text)},
        );
        _refresh();
        _message('Vínculo creado pendiente de validación.');
      } catch (error) {
        _message('No se guardó el vínculo: $error');
      }
    }
    date.dispose();
  }

  Future<void> _editLink(
    EntidadFiscalModel entity,
    EntidadFiscalSucursalModel link,
  ) async {
    final from = TextEditingController(text: link.vigenteDesde ?? '');
    final until = TextEditingController(text: link.vigenteHasta ?? '');
    final evidence = TextEditingController(
      text: link.referenciaValidacion ?? '',
    );
    var status = link.estadoValidacion;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Vínculo ${link.suc} · ${entity.rfc}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(
                    value: 'PENDIENTE',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem(value: 'VALIDADA', child: Text('Validada')),
                  DropdownMenuItem(value: 'INACTIVA', child: Text('Inactiva')),
                ],
                onChanged: (value) =>
                    setDialogState(() => status = value ?? 'PENDIENTE'),
              ),
              TextField(
                controller: from,
                decoration: const InputDecoration(
                  labelText: 'Vigencia inicial (AAAA-MM-DD)',
                ),
              ),
              TextField(
                controller: until,
                decoration: const InputDecoration(
                  labelText: 'Vigencia final (AAAA-MM-DD; para cerrar)',
                ),
              ),
              TextField(
                controller: evidence,
                decoration: const InputDecoration(
                  labelText: 'Referencia de validación',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await ref.read(empresasApiProvider).updateEntidadFiscalSucursal(
          entity.idEntidadFiscal,
          link.idRelacion,
          {
            'estadoValidacion': status,
            'vigenteDesde': _emptyToNull(from.text),
            'vigenteHasta': _emptyToNull(until.text),
            'referenciaValidacion': _emptyToNull(evidence.text),
          },
        );
        _refresh();
        _message('Vínculo actualizado.');
      } catch (error) {
        _message('No se guardó el vínculo: $error');
      }
    }
    from.dispose();
    until.dispose();
    evidence.dispose();
  }

  void _refresh() => ref.invalidate(entidadesFiscalesListProvider);

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
