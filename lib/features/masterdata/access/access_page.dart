import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccessPage extends StatelessWidget {
  const AccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accesos')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Módulos (Backend)'),
            onTap: () => context.go('/masterdata/access/modulos-back'),
          ),
          ListTile(
            title: const Text('Grupos de módulos (Backend)'),
            onTap: () => context.go('/masterdata/access/grupos-back'),
          ),
          ListTile(
            title: const Text('Permisos por Rol (Backend)'),
            onTap: () => context.go('/masterdata/access/permisos-rol-back'),
          ),
          const Divider(height: 24),
          ListTile(
            title: const Text('Módulos (Front)'),
            onTap: () => context.go('/masterdata/access/mod-front'),
          ),
          ListTile(
            title: const Text('Grupos (Front)'),
            onTap: () => context.go('/masterdata/access/grupos-front'),
          ),
          ListTile(
            title: const Text('Enrolamiento Rol → Grupo Front'),
            onTap: () => context.go('/masterdata/access/enrolamiento-front'),
          ),
        ],
      ),
    );
  }
}
