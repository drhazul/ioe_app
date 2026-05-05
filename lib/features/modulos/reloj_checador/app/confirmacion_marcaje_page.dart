import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'reloj_checador_app_models.dart';

typedef Colaborador = ColaboradorGestionModel;

class ConfirmacionMarcajePage extends StatelessWidget {
  const ConfirmacionMarcajePage({super.key, required this.colaborador});

  final Colaborador colaborador;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmación de marcaje')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Marcaje confirmado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Colaborador: ${colaborador.nombreCompleto}'),
                Text('ID empleado: ${colaborador.idEmpleado}'),
                Text('PIN: ${colaborador.pin}'),
                Text('Sucursal: ${colaborador.sucursalCodigo}'),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.go('/marcaje'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver a Marcaje'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

