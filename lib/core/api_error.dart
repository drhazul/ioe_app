import 'package:dio/dio.dart';

String apiErrorMessage(Object error, {String fallback = 'Ocurrió un error'}) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];

      if (message is List) {
        return message.map((e) => '$e').join('\n');
      }
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final err = data['error'];
      if (err is String && err.trim().isNotEmpty) {
        return err.trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }

    final status = error.response?.statusCode;
    if (status != null) {
      return 'Error HTTP $status';
    }
  }

  final text = error.toString();
  return text.isNotEmpty ? text : fallback;
}
