import 'correo_oauth_launcher_stub.dart'
    if (dart.library.html) 'correo_oauth_launcher_web.dart' as platform;
import 'correo_oauth_result.dart';

Future<ResultadoAperturaOAuth> abrirUrlOAuth(
  Future<String> Function() obtenerUrl,
) => platform.abrirUrlOAuth(obtenerUrl);
