import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kApiHost = String.fromEnvironment('API_HOST');

String get _baseUrl {
  if (_kApiHost.isNotEmpty) return 'http://$_kApiHost:3000/api/v1';
  if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/v1';
  return 'http://localhost:3000/api/v1';
}

/// Base URL for constructing file/attachment URLs.
String get apiBaseUrl => _baseUrl;

/// In-memory token — updated by AuthNotifier on login/logout/init.
/// The interceptor reads this synchronously, avoiding async storage race conditions.
final tokenProvider = StateProvider<String?>((ref) => null);

/// True while the server is reachable; flips to false on connection-level errors
/// and resets to true on the next successful response. Drives the offline banner.
final serverReachableProvider = StateProvider<bool>((ref) => true);

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
    onResponse: (response, handler) {
      ref.read(serverReachableProvider.notifier).state = true;
      handler.next(response);
    },
    onError: (error, handler) {
      // Handle 401 Unauthorized — logout user
      if (error.response?.statusCode == 401) {
        ref.read(tokenProvider.notifier).state = null;
        // Optionally trigger app-level logout/navigation here if needed
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        ref.read(serverReachableProvider.notifier).state = false;
      }
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
