import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MasterDataPage extends StatelessWidget {
  const MasterDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos Maestros')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Accesos'),
            onTap: () => context.go('/masterdata/access'),
          ),
          ListTile(
            title: const Text('Roles'),
            onTap: () => context.go('/masterdata/roles'),
          ),
          ListTile(
            title: const Text('Módulos'),
            onTap: () => context.go('/masterdata/datmodulos'),
          ),
          ListTile(
            title: const Text('Departamentos'),
            onTap: () => context.go('/masterdata/deptos'),
          ),
          ListTile(
            title: const Text('Usuarios'),
            onTap: () => context.go('/masterdata/users'),
          ),
          ListTile(
            title: const Text('Acceso por sucursal'),
            onTap: () => context.go('/masterdata/access-reg-suc'),
          ),
          ListTile(
            title: const Text('Sucursales'),
            onTap: () => context.go('/masterdata/sucursales'),
          ),
          ListTile(
            title: const Text('Puestos'),
            onTap: () => context.go('/masterdata/puestos'),
          ),
        ],
      ),
    );
  }
}
