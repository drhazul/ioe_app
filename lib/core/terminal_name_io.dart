import 'dart:io';

String terminalName() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return '';
  }
}
