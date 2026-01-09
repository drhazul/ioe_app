import 'open_new_window_stub.dart' if (dart.library.html) 'open_new_window_web.dart';

bool openRouteInNewWindow(String path) {
  return openNewWindow(path);
}
