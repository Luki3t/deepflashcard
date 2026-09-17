import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flashcards/core/utils/network_error.dart';

void main() {
  final request = RequestOptions(path: 'https://example.com/pack.zip');

  DioException dio(DioExceptionType type, {Object? error}) =>
      DioException(requestOptions: request, type: type, error: error);

  test(
    'connection problems read as "no internet", not a DioException dump',
    () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final message = friendlyNetworkError(dio(type));
        expect(message, noInternetMessage, reason: '$type');
        expect(message, isNot(contains('DioException')));
      }
    },
  );

  test('an unknown Dio error caused by a socket failure is "no internet"', () {
    expect(
      friendlyNetworkError(
        dio(DioExceptionType.unknown, error: const SocketException('down')),
      ),
      noInternetMessage,
    );
  });

  test('a bad server response gets its own message', () {
    final message = friendlyNetworkError(dio(DioExceptionType.badResponse));
    expect(message, isNot(noInternetMessage));
    expect(message, contains('try again later'));
  });

  test('plain socket and timeout errors are "no internet"', () {
    expect(
      friendlyNetworkError(const SocketException('Failed host lookup')),
      noInternetMessage,
    );
    expect(friendlyNetworkError(TimeoutException('slow')), noInternetMessage);
  });

  test('anything else gets a generic message without exception text', () {
    final message = friendlyNetworkError(Exception('Checksum mismatch'));
    expect(message, isNot(contains('Exception')));
    expect(message, isNot(contains('Checksum')));
  });
}
