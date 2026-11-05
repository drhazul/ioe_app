import 'package:ioe_app/core/env.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';

class MasterDataPage extends ConsumerWidget {
  const MasterDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authControllerProvider).roleId == 1;
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
            title: const Text('Departamentos'),
            onTap: () => context.go('/masterdata/deptos'),
          ),
          ListTile(
            title: const Text('Usuarios'),
            onTap: () => context.go('/masterdata/users'),
          ),
          ListTile(
            title: const Text('Empresas'),
            onTap: () => context.go('/masterdata/empresas'),
          ),
          if (isAdmin && Env.developmentBusinessEnabled)
            ListTile(
              title: const Text('Entidades fiscales y sucursales'),
              onTap: () => context.go('/masterdata/entidades-fiscales'),
            ),
          ListTile(
            title: const Text('Acceso por sucursal'),
            onTap: () => context.go('/masterdata/access-reg-suc'),
          ),
          ListTile(
            title: const Text('Compartir colaboradores entre sucursales'),
            onTap: () => context.go('/masterdata/access/suc-colab-acceso'),
          ),
          ListTile(
            title: const Text('Puestos (usa Roles)'),
            onTap: () => context.go('/masterdata/roles'),
          ),
          ListTile(
            title: const Text('Catalogo Cuentas'),
            onTap: () => context.go('/masterdata/cat-ctas'),
          ),
          ListTile(
            title: const Text('Formas de pago (DAT_FORM)'),
            onTap: () => context.go('/masterdata/dat-form'),
          ),
          ListTile(
            title: const Text('Datos Maestros (Empresa y Reglas)'),
            onTap: () => context.go('/masterdata/datos-maestros'),
          ),
        ],
      ),
    );
  }
}
