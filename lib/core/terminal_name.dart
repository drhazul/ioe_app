import 'terminal_name_stub.dart'
    if (dart.library.io) 'terminal_name_io.dart'
    if (dart.library.html) 'terminal_name_web.dart';

String getTerminalName() => terminalName();
