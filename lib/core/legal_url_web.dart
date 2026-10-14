import 'package:web/web.dart' as web;

bool openLegalUrl(String path) {
  // Public HTML documents use server paths, never Flutter hash routes.
  final target = Uri.base.replace(path: path, query: '', fragment: '');
  return web.window.open(target.toString(), '_blank') != null;
}
