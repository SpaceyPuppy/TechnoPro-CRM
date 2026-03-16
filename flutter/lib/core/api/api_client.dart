import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String get _baseUrl {
  if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/v1';
  return 'http://localhost:3000/api/v1';
}

/// Base URL for constructing file/attachment URLs.
String get apiBaseUrl => _baseUrl;

/// In-memory token — updated by AuthNotifier on login/logout/init.
/// The interceptor reads this synchronously, avoiding async storage race conditions.
final tokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(tokenProvider);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      handler.next(error);
    },
  ));

  return dio;
});

/// Extracts a meaningful message from a Dio error.
String apiErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error'] is Map) {
    return (data['error']['message'] as String?) ?? 'An error occurred';
  }
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      'Connection timed out — is the server running?',
    DioExceptionType.connectionError => 'Cannot reach server — check your connection',
    _ => e.message ?? 'An error occurred',
  };
}
