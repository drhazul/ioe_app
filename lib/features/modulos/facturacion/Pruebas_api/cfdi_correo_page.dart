import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';

import 'cfdi_correo_providers.dart';
import 'correo_oauth_launcher.dart';

class CfdiCorreoPage extends ConsumerStatefulWidget {
  const CfdiCorreoPage({super.key});

  @override
  ConsumerState<CfdiCorreoPage> createState() => _CfdiCorreoPageState();
}

class _CfdiCorreoPageState extends ConsumerState<CfdiCorreoPage> {
  final _nombreCtrl = TextEditingController();
  bool _nombreCargado = false;
  bool _guardando = false;
  bool _conectando = false;
  bool _probando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _aviso(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _guardar({
    required bool automatico,
    required String nombre,
  }) async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(cfdiCorreoApiProvider)
          .guardarConfiguracion(
            automatico: automatico,
            nombreRemitente: nombre.trim(),
          );
      ref.invalidate(cfdiCorreoConfigProvider);
      _aviso('Configuración guardada.');
    } catch (error) {
      _aviso(
        apiErrorMessage(error, fallback: 'No se pudo guardar la configuración'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _conectar() async {
    setState(() => _conectando = true);
    try {
      final resultado = await abrirUrlOAuth(
        () => ref.read(cfdiCorreoApiProvider).iniciarOAuth(),
      );
      if (!mounted) return;
      if (resultado.abierta) {
        _aviso(
          'Autoriza la cuenta Google y luego vuelve aquí para actualizar.',
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Conectar Gmail'),
            content: SelectableText(resultado.url),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: resultado.url));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Copiar enlace'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _aviso(
          apiErrorMessage(error, fallback: 'No se pudo iniciar OAuth Google'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  Future<void> _probar() async {
    final destinatarioCtrl = TextEditingController();
    final destinatario = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Probar envío'),
        content: TextField(
          controller: destinatarioCtrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo destinatario',
            hintText: 'correo@dominio.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, destinatarioCtrl.text.trim()),
            child: const Text('Enviar prueba'),
          ),
        ],
      ),
    );
    destinatarioCtrl.dispose();
    if (destinatario == null || destinatario.isEmpty) return;

    setState(() => _probando = true);
    try {
      final resultado = await ref
          .read(cfdiCorreoApiProvider)
          .probar(destinatario);
      if (mounted) {
        _aviso((resultado['mensaje'] ?? 'Gmail aceptó la prueba.').toString());
      }
    } catch (error) {
      if (mounted) {
        _aviso(
          apiErrorMessage(error, fallback: 'No se pudo enviar la prueba'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  Future<void> _reintentar(int id) async {
    try {
      await ref.read(cfdiCorreoApiProvider).reintentar(id);
      ref.invalidate(cfdiCorreoEnviosProvider);
      _aviso('Envío agregado a la cola.');
    } catch (error) {
      _aviso(
        apiErrorMessage(error, fallback: 'No se pudo reintentar el envío'),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(cfdiCorreoConfigProvider);
    final enviosAsync = ref.watch(cfdiCorreoEnviosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correo · FACTURA_QUADRUM'),
        actions: [
          IconButton(
            tooltip: 'Actualizar estado',
            onPressed: () {
              ref.invalidate(cfdiCorreoConfigProvider);
              ref.invalidate(cfdiCorreoEnviosProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              apiErrorMessage(
                error,
                fallback: 'No se pudo cargar la configuración de correo.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (config) {
          if (!_nombreCargado) {
            _nombreCtrl.text = (config['nombreRemitente'] ?? 'Facturación IOE')
                .toString();
            _nombreCargado = true;
          }
          final conectado = config['conectado'] == true;
          final automatico = config['automatico'] == true;
          final modoPruebas = config['modoPruebas'] == true;
          final cuenta = (config['cuentaConectada'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cuenta Gmail',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        conectado
                            ? 'Conectada: $cuenta'
                            : 'Sin cuenta conectada',
                      ),
                      if (modoPruebas) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Google OAuth está en modo de pruebas. La autorización puede vencer a los 7 días.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _conectando ? null : _conectar,
                            icon: _conectando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.link),
                            label: Text(
                              conectado
                                  ? 'Volver a conectar'
                                  : 'Conectar Gmail',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: !conectado || _probando ? null : _probar,
                            icon: const Icon(Icons.send),
                            label: Text(
                              _probando ? 'Enviando...' : 'Enviar prueba',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Envío automático',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nombreCtrl,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Nombre visible del remitente',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enviar después del timbrado'),
                        subtitle: const Text(
                          'Adjunta XML original y representación PDF al EMAILRECEPTOR del cliente.',
                        ),
                        value: automatico,
                        onChanged: !conectado || _guardando
                            ? null
                            : (value) => _guardar(
                                automatico: value,
                                nombre: _nombreCtrl.text,
                              ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _guardando
                              ? null
                              : () => _guardar(
                                  automatico: automatico,
                                  nombre: _nombreCtrl.text,
                                ),
                          child: Text(
                            _guardando ? 'Guardando...' : 'Guardar nombre',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Últimos envíos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              enviosAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(
                    error,
                    fallback: 'No se pudo cargar el historial.',
                  ),
                ),
                data: (envios) => envios.isEmpty
                    ? const Text('Todavía no hay envíos registrados.')
                    : Column(
                        children: envios
                            .map((envio) => _envioTile(envio))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _envioTile(Map<String, dynamic> envio) {
    final estado = (envio['estado'] ?? '').toString();
    final permiteReintento = {
      'REINTENTABLE',
      'ERROR_FINAL',
      'OMITIDO_SIN_DESTINATARIO',
    }.contains(estado);
    final destinatario = envio['destinatario']?.toString();
    final destino = destinatario == null ? null : 'Destino: $destinatario';
    final mensaje = envio['mensaje']?.toString();
    return Card(
      child: ListTile(
        title: Text('${(envio['idFol'] ?? 'CFDI')} · $estado'),
        subtitle: Text(
          [
            ?destino,
            ?mensaje,
            'Intentos: ${envio['intentos'] ?? 0}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: permiteReintento
            ? IconButton(
                tooltip: 'Reintentar',
                onPressed: () => _reintentar((envio['id'] as num).toInt()),
                icon: const Icon(Icons.refresh),
              )
            : null,
      ),
    );
  }
}
