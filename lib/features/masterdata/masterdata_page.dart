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
            title: const Text('Roles'),
            onTap: () => context.go('/masterdata/roles'),
          ),
          ListTile(
            title: const Text('Departamentos'),
            onTap: () => context.go('/masterdata/deptos'),
          ),
          ListTile(
            title: const Text('Usuarios'),
            onTap: () => context.go('/masterdata/users'),
          ),
        ],
      ),
    );
  }
}
