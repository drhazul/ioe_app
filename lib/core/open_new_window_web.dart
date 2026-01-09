import 'package:web/web.dart' as web;

bool openNewWindow(String path) {
  final normalized = path.startsWith('/') ? path : '/$path';
  final base = Uri.base;
  final hasHash = base.fragment.isNotEmpty;

  final target = hasHash
      ? base.replace(fragment: normalized)
      : base.replace(path: normalized, fragment: '');

  web.window.open(target.toString(), '_blank');
  return true;
}
