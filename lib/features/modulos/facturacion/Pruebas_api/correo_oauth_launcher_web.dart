import 'dart:html' as html;
import 'correo_oauth_result.dart';

Future<ResultadoAperturaOAuth> abrirUrlOAuth(
  Future<String> Function() obtenerUrl,
) async {
  // Open synchronously from the button gesture so browser popup protection
  // does not block the tab while the API creates the OAuth state.
  final ventana = html.window.open('about:blank', '_blank');
  try {
    final url = await obtenerUrl();
    if (ventana != null) ventana.location.href = url;
    return ResultadoAperturaOAuth(url: url, abierta: ventana != null);
  } catch (_) {
    ventana?.close();
    rethrow;
  }
}
