import 'correo_oauth_result.dart';

Future<ResultadoAperturaOAuth> abrirUrlOAuth(
  Future<String> Function() obtenerUrl,
) async => ResultadoAperturaOAuth(
  url: await obtenerUrl(),
  abierta: false,
);
