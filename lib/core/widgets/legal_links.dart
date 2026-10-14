import 'package:flutter/material.dart';
import '../legal_url_stub.dart'
    if (dart.library.js_interop) '../legal_url_web.dart'
    as platform;

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  void _open(BuildContext context, String path) {
    if (platform.openLegalUrl(path)) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Documento público'),
        content: SelectableText('https://erp.ioebusiness.com.mx$path'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => _open(context, '/legal/privacidad.html'),
          child: const Text('Política de Privacidad'),
        ),
        TextButton(
          onPressed: () => _open(context, '/legal/terminos.html'),
          child: const Text('Condiciones del Servicio'),
        ),
      ],
    ),
  );
}
