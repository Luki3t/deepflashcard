import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

const noInternetMessage =
    'No internet connection. Check your connection and try again.';

/// Turns a download failure into a sentence a user can act on, instead of
/// showing raw exception text such as a DioException dump.
String friendlyNetworkError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return noInternetMessage;
      case DioExceptionType.badResponse:
        return 'The download server is not responding properly. '
            'Please try again later.';
      case DioExceptionType.cancel:
        return 'The download was cancelled.';
      default:
        if (error.error is SocketException) return noInternetMessage;
    }
  }
  if (error is SocketException || error is TimeoutException) {
    return noInternetMessage;
  }
  return 'Something went wrong. Please try again.';
}

/// Quick reachability probe: a DNS lookup fails fast when the device is
/// offline, whereas some download APIs just wait silently for a connection.
Future<bool> hasInternetConnection({
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final result = await InternetAddress.lookup(
      'dl.google.com',
    ).timeout(timeout);
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
