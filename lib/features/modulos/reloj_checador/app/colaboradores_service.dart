import 'reloj_checador_app_models.dart';

class ColaboradoresService {
  const ColaboradoresService();

  List<SucursalOptionModel> resolveSucursales(
    List<SucursalOptionModel> catalog,
    List<ColaboradorGestionModel> colaboradores,
  ) {
    if (catalog.isNotEmpty) return catalog;

    final byCode = <String, SucursalOptionModel>{};
    for (final c in colaboradores) {
      final code = c.sucursalCodigo.trim();
      if (code.isEmpty) continue;
      byCode.putIfAbsent(
        code,
        () => SucursalOptionModel(id: c.sucursalId, codigo: code, nombre: code),
      );
    }

    return byCode.values.toList()..sort((a, b) => a.codigo.compareTo(b.codigo));
  }

  List<String> uniqueDepartamentos({
    required List<ColaboradorGestionModel> colaboradores,
    int? sucursalId,
  }) {
    final set = <String>{};
    for (final c in colaboradores) {
      if (sucursalId != null && c.sucursalId != sucursalId) continue;
      final depto = c.departamento.trim();
      if (depto.isEmpty) continue;
      set.add(depto);
    }
    final out = set.toList()..sort();
    return out;
  }

  List<ColaboradorGestionModel> filterColaboradores({
    required List<ColaboradorGestionModel> colaboradores,
    int? sucursalId,
    String? departamento,
    String? search,
  }) {
    final term = (search ?? '').trim().toUpperCase();
    final termCompact = term.replaceAll(RegExp(r'\s+'), '');
    final dept = (departamento ?? '').trim().toUpperCase();

    return colaboradores.where((c) {
      if (sucursalId != null && c.sucursalId != sucursalId) return false;
      if (dept.isNotEmpty && c.departamento.trim().toUpperCase() != dept) {
        return false;
      }
      if (term.isEmpty) return true;
      final idEmpleado = c.idEmpleado.toUpperCase();
      final idEmpleadoCompact = idEmpleado.replaceAll(RegExp(r'\s+'), '');
      return idEmpleado.contains(term) ||
          idEmpleadoCompact.contains(termCompact) ||
          c.nombreCompleto.toUpperCase().contains(term) ||
          c.pin.toUpperCase().contains(term);
    }).toList();
  }
}
