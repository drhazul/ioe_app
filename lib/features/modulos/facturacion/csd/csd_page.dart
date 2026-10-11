import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';

import 'csd_models.dart';
import 'csd_providers.dart';

/// Regimenes mas usados del catalogo del SAT. El certificado no trae el
/// regimen, por eso se captura al subirlo.
const _regimenes = <String, String>{
  '601': '601 · General de Ley Personas Morales',
  '603': '603 · Personas Morales con Fines no Lucrativos',
  '605': '605 · Sueldos y Salarios',
  '606': '606 · Arrendamiento',
  '612': '612 · Actividades Empresariales y Profesionales',
  '621': '621 · Incorporación Fiscal',
  '626': '626 · Régimen Simplificado de Confianza',
};

class CsdPage extends ConsumerStatefulWidget {
  const CsdPage({super.key});

  @override
  ConsumerState<CsdPage> createState() => _CsdPageState();
}

class _CsdPageState extends ConsumerState<CsdPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();

  /// Cuenta del PAC de esta razon social. Opcional: sin ella se usa la
  /// del .env, que es como trabajaba antes de manejar varios RFC.
  final _pacUsuarioCtrl = TextEditingController();
  final _pacPasswordCtrl = TextEditingController();
  bool _verPacPassword = false;

  String _regimen = '612';
  bool _verPassword = false;
  bool _guardando = false;

  PlatformFile? _cer;
  PlatformFile? _key;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _cpCtrl.dispose();
    _pacUsuarioCtrl.dispose();
    _pacPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirArchivo({required bool esCer}) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [esCer ? 'cer' : 'key'],
      // withData: en web no hay ruta, los bytes son la unica via.
      withData: true,
    );
    final archivo = resultado?.files.firstOrNull;
    if (archivo == null || archivo.bytes == null) return;
    setState(() {
      if (esCer) {
        _cer = archivo;
      } else {
        _key = archivo;
      }
    });
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cer = _cer?.bytes;
    final key = _key?.bytes;
    if (cer == null || key == null) {
      _aviso('Selecciona el archivo .cer y el .key.', error: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      final resumen = await ref
          .read(csdApiProvider)
          .guardar(
            cer: Uint8List.fromList(cer),
            key: Uint8List.fromList(key),
            password: _passwordCtrl.text,
            regimenFiscal: _regimen,
            codigoPostal: _cpCtrl.text.trim(),
            quadrumUsuario: _pacUsuarioCtrl.text,
            quadrumPassword: _pacPasswordCtrl.text,
          );

      if (!mounted) return;
      final rfc = '${resumen['rfc'] ?? ''}';
      final dias = resumen['diasRestantes'];
      _aviso('Certificado de $rfc cargado. Vigencia: $dias días.');

      setState(() {
        _cer = null;
        _key = null;
        _passwordCtrl.clear();
        _cpCtrl.clear();
        _pacUsuarioCtrl.clear();
        _pacPasswordCtrl.clear();
      });
      ref.invalidate(csdListProvider);
    } catch (error) {
      if (!mounted) return;
      _aviso(
        apiErrorMessage(error, fallback: 'No se pudo cargar el certificado'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aviso(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(csdListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación · Certificados (CSD)'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(csdListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _formulario(context),
            const SizedBox(height: 12),
            Expanded(
              child: listaAsync.when(
                data: (certificados) => _CsdList(certificados: certificados),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    apiErrorMessage(
                      e,
                      fallback: 'No se pudieron cargar los certificados',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cargar o renovar certificado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'El RFC y el nombre se leen del propio certificado. '
                'El régimen y el código postal se capturan porque el .cer no los trae.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _BotonArchivo(
                    etiqueta: 'Certificado (.cer)',
                    archivo: _cer,
                    onPressed: _guardando
                        ? null
                        : () => _elegirArchivo(esCer: true),
                  ),
                  _BotonArchivo(
                    etiqueta: 'Llave privada (.key)',
                    archivo: _key,
                    onPressed: _guardando
                        ? null
                        : () => _elegirArchivo(esCer: false),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_verPassword,
                      enabled: !_guardando,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de la llave',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _verPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _verPassword = !_verPassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Captura la contraseña'
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      controller: _pacUsuarioCtrl,
                      enabled: !_guardando,
                      decoration: const InputDecoration(
                        labelText: 'Usuario de Quadrum',
                        hintText: 'Opcional',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      controller: _pacPasswordCtrl,
                      obscureText: !_verPacPassword,
                      enabled: !_guardando,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de Quadrum',
                        hintText: 'Opcional',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _verPacPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _verPacPassword = !_verPacPassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        // O las dos o ninguna: un usuario sin contrasena no
                        // sirve para timbrar.
                        final usuario = _pacUsuarioCtrl.text.trim();
                        if (usuario.isNotEmpty && (v == null || v.isEmpty)) {
                          return 'Falta la contraseña de esa cuenta';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: _regimen,
                      decoration: const InputDecoration(
                        labelText: 'Régimen fiscal',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _regimenes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: _guardando
                          ? null
                          : (v) => setState(() => _regimen = v ?? '612'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: _cpCtrl,
                      enabled: !_guardando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'C.P. de expedición',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().length != 5)
                          ? 'Son 5 dígitos'
                          : null,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_guardando ? 'Cargando...' : 'Cargar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonArchivo extends StatelessWidget {
  const _BotonArchivo({
    required this.etiqueta,
    required this.archivo,
    required this.onPressed,
  });

  final String etiqueta;
  final PlatformFile? archivo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cargado = archivo != null;
    return SizedBox(
      width: 260,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(cargado ? Icons.check_circle : Icons.attach_file),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(etiqueta),
            Text(
              cargado ? archivo!.name : 'Sin seleccionar',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CsdList extends StatelessWidget {
  const _CsdList({required this.certificados});

  final List<CsdModel> certificados;

  @override
  Widget build(BuildContext context) {
    if (certificados.isEmpty) {
      return const Card(
        elevation: 0,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Todavía no hay certificados cargados.'),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    'RFC',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NOMBRE O RAZÓN SOCIAL',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: Text(
                    'NO. CERTIFICADO',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'RÉGIMEN',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'C.P.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    'CUENTA PAC',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'VENCE',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: certificados.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final csd = certificados[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  color: csd.activo ? null : Colors.grey.shade100,
                  child: Row(
                    children: [
                      SizedBox(width: 140, child: Text(csd.rfc)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(csd.nombre ?? '-')),
                      SizedBox(width: 190, child: Text(csd.noCertificado)),
                      SizedBox(width: 80, child: Text(csd.regimenFiscal)),
                      SizedBox(width: 70, child: Text(csd.codigoPostal)),
                      SizedBox(
                        width: 150,
                        child: Text(
                          csd.quadrumUsuario?.trim().isNotEmpty == true
                              ? csd.quadrumUsuario!
                              : 'la del .env',
                          style: TextStyle(
                            fontStyle: csd.quadrumUsuario == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: csd.quadrumUsuario == null
                                ? Colors.grey.shade600
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 110, child: Text(_fecha(csd.validoHasta))),
                      SizedBox(width: 130, child: _Estado(csd: csd)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fecha(DateTime? fecha) {
    if (fecha == null) return '-';
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }
}

class _Estado extends StatelessWidget {
  const _Estado({required this.csd});

  final CsdModel csd;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final (color, icono) = switch (csd.estado) {
      'VENCIDO' => (esquema.error, Icons.error_outline),
      'POR VENCER' => (Colors.orange.shade800, Icons.warning_amber_outlined),
      'REEMPLAZADO' => (esquema.outline, Icons.history),
      _ => (Colors.green.shade700, Icons.verified_outlined),
    };

    return Row(
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            csd.estado,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
