import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:ioe_app/core/open_new_window.dart';
import 'home_providers.dart';
import 'home_models.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IOE - Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(homeModulesProvider.future),
        child: Builder(
          builder: (context) {
            if (auth.isLoading) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            if (!auth.isAuthenticated) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sesión no activa. Redirigiendo a login...'),
                  ),
                ],
              );
            }

            final modulesAsync = ref.watch(homeModulesProvider);

            return modulesAsync.when(
              data: (data) => _ModulesList(response: data),
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
              error: (e, st) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No se pudo cargar los módulos: $e'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModulesList extends StatelessWidget {
  const _ModulesList({required this.response});

  final HomeModulesResponse response;

  @override
  Widget build(BuildContext context) =>
      _ModulesListStateful(response: response);
}

class _ModulesListStateful extends StatefulWidget {
  const _ModulesListStateful({required this.response});

  final HomeModulesResponse response;

  @override
  State<_ModulesListStateful> createState() => _ModulesListStatefulState();
}

class _ModulesListStatefulState extends State<_ModulesListStateful> {
  String _searchApplied = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modulos = widget.response.modulos.where((m) => m.activo).toList();
    if (modulos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay módulos asignados a tu rol.'),
          ),
        ],
      );
    }

    final term = _searchApplied.trim().toLowerCase();
    final filtered = modulos.where((m) {
      if (term.isEmpty) return true;
      final text = ('${m.codigo} ${m.nombre}').toLowerCase();
      return text.contains(term);
    }).toList();

    final grouped = <String, List<HomeModule>>{};
    for (final m in filtered) {
      final depto = (m.depto ?? '').trim();
      final key = depto.isEmpty ? 'OTROS' : depto.toUpperCase();
      grouped.putIfAbsent(key, () => []).add(m);
    }

    final rrhhCatalog = _buildHrModulesForRole(
      roleId: widget.response.roleId,
      searchTerm: term,
      sourceModules: modulos,
    );
    if (rrhhCatalog.isEmpty) {
      grouped.remove('RRHH');
    } else {
      grouped['RRHH'] = rrhhCatalog;
    }

    final keys = grouped.keys.toList()..sort();
    if (keys.remove('OTROS')) keys.add('OTROS');
    for (final key in keys) {
      if (key == 'RRHH') continue;
      grouped[key]!.sort(
        (a, b) => a.nombre.toUpperCase().compareTo(b.nombre.toUpperCase()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchBar(
              searchController: _searchCtrl,
              onApplySearch: () =>
                  setState(() => _searchApplied = _searchCtrl.text),
              onClearSearch: () => setState(() {
                _searchCtrl.clear();
                _searchApplied = '';
              }),
            ),
            const SizedBox(height: 12),
            for (final key in keys) ...[
              _DeptoHeader(title: key),
              const SizedBox(height: 8),
              for (final modulo in grouped[key]!) _ModuleRow(module: modulo),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<HomeModule> _buildHrModulesForRole({
    required int roleId,
    required String searchTerm,
    required List<HomeModule> sourceModules,
  }) {
    final rrhhFromDb = sourceModules.where((m) {
      final code = m.codigo.trim().toUpperCase();
      final depto = (m.depto ?? '').trim().toUpperCase();
      return depto == 'RRHH' ||
          code.startsWith('RRHH_') ||
          code == 'RELOJ_CHECADOR';
    }).map((m) {
      final code = m.codigo.trim().toUpperCase();
      final nombre = code == 'RELOJ_CHECADOR'
          ? 'KIOSKO RELOJ CHECADOR'
          : m.nombre;
      return HomeModule(
        codigo: m.codigo,
        nombre: nombre,
        depto: 'RRHH',
        activo: m.activo,
      );
    }).toList();

    final curated = <HomeModule>[];
    for (final m in rrhhFromDb) {
      final code = m.codigo.trim().toUpperCase();
      if (code == 'RELOJ_CHECADOR') {
        curated.add(m);
        continue;
      }
      if (code == 'RRHH_CONSULTAS') {
        curated.add(
          const HomeModule(
            codigo: 'RELOJ_RRHH_CTRL',
            nombre: 'GESTION COLABORADORES Y NOMINA',
            depto: 'RRHH',
            activo: true,
          ),
        );
      }
    }

    late final List<HomeModule> visible;
    if (roleId == 1 || roleId == 2 || roleId == 0) {
      visible = curated;
    } else {
      visible = curated.where((m) {
        final code = m.codigo.trim().toUpperCase();
        return code == 'RELOJ_CHECADOR' || code == 'RRHH_ESS';
      }).toList();
    }

    if (searchTerm.isEmpty) return visible;
    final needle = searchTerm.toLowerCase();
    return visible.where((m) {
      final text = ('${m.codigo} ${m.nombre}').toLowerCase();
      return text.contains(needle);
    }).toList();
  }

}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.searchController,
    required this.onApplySearch,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final VoidCallback onApplySearch;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o código',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onApplySearch(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onApplySearch,
              icon: const Icon(Icons.search),
              label: const Text('Filtrar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _DeptoHeader extends StatelessWidget {
  const _DeptoHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final HomeModule module;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _navigate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(_iconForModuleCode(module.codigo), color: const Color(0xFF44525F)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.codigo,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.nombre,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Abrir en nueva ventana',
              icon: const Icon(Icons.open_in_new, color: Colors.grey),
              onPressed: () => _openInNewWindow(context),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ruta no configurada')));
  }

  void _navigate(BuildContext context) {
    final path = _resolveRoute();
    if (path == null) {
      _showComingSoon(context);
      return;
    }
    context.go(path);
  }

  void _openInNewWindow(BuildContext context) {
    final path = _resolveRoute();
    if (path == null) {
      _showComingSoon(context);
      return;
    }
    final opened = openRouteInNewWindow(path);
    if (!opened) {
      _navigate(context);
    }
  }

  String? _resolveRoute() {
    final moduloCode = module.codigo.toUpperCase();
    const routeByCode = <String, String>{
      'RRHH_MARCAJE': '/marcaje',
      'RRHH_SUCURSALES': '/sucursales',
      'RRHH_GEST_COLAB': '/colaboradores',
      'RRHH_CTRL_HR': '/horarios',
      'RRHH_INCIDENCIAS': '/incidencias',
      'RRHH_REPORTES': '/reporte',
      'RRHH_ESS': '/auto-servicio',
      'RRHH_CONSULTAS': '/reloj-checador/consultas',
      'RELOJ_RRHH_CTRL': '/reloj-checador/admin',
      'RELOJ_CHECADOR': '/reloj-checador',
      'PV_ENTREGA_CG': '/entrega-cajas',
      'PV_CAJAS': '/punto-de-venta',
      'DAT_CONS_CTAS': '/consulta-cuentas',
      'DAT_MA_PROV': '/proveedores',
      'SYS_DAT_MAE': '/masterdata',
    };
    return routeByCode[moduloCode];
  }

  IconData _iconForModuleCode(String codeRaw) {
    final code = codeRaw.trim().toUpperCase();
    if (code == 'RELOJ_CHECADOR') return Icons.fingerprint;
    if (code == 'RELOJ_RRHH_CTRL') return Icons.dashboard_customize;
    if (code == 'RRHH_GEST_COLAB') return Icons.people;
    if (code == 'RRHH_CTRL_HR') return Icons.schedule;
    if (code == 'RRHH_INCIDENCIAS') return Icons.event_note;
    if (code == 'RRHH_REPORTES') return Icons.bar_chart;
    if (code == 'RRHH_SUCURSALES') return Icons.business;
    return Icons.grid_view_rounded;
  }
}
