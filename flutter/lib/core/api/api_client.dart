import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/logout_callback_provider.dart';

const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _kApiHost = String.fromEnvironment('API_HOST');

/// Normalises a host or URL to the API base expected by the native app.
String normalizeServerUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return value;

  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    value = 'https://$value';
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null || parsed.host.isEmpty) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  var path = parsed.path.replaceFirst(RegExp(r'/+$'), '');
  if (!path.endsWith('/api/v1')) {
    path = '$path/api/v1';
  }

  return parsed
      .replace(path: path, query: null, fragment: null)
      .toString()
      .replaceFirst(RegExp(r'/+$'), '');
}

String get _defaultBaseUrl {
  if (_kApiBaseUrl.isNotEmpty) return normalizeServerUrl(_kApiBaseUrl);
  if (_kApiHost.isNotEmpty) {
    final legacyUrl = _kApiHost.contains('://')
        ? _kApiHost
        : 'http://$_kApiHost:3000';
    return normalizeServerUrl(legacyUrl);
  }
  if (Platform.isAndroid) return 'http://10.0.2.2:3000/api/v1';
  return 'http://localhost:3000/api/v1';
}

/// Configurable server URL — set from login screen, persisted in AuthStorage.
/// Falls back to platform default if not set.
final serverUrlProvider = StateProvider<String>((ref) => _defaultBaseUrl);

/// In-memory token — updated by AuthNotifier on login/logout/init.
/// The interceptor reads this synchronously, avoiding async storage race conditions.
final tokenProvider = StateProvider<String?>((ref) => null);

/// True while the server is reachable; flips to false on connection-level errors
/// and resets to true on the next successful response. Drives the offline banner.
final serverReachableProvider = StateProvider<bool>((ref) => true);

final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(serverUrlProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
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
      // Remove Content-Type on requests with no body — Fastify rejects
      // DELETE/GET with Content-Type: application/json but empty body
      if (options.data == null) {
        options.headers.remove('Content-Type');
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      ref.read(serverReachableProvider.notifier).state = true;
      handler.next(response);
    },
    onError: (error, handler) {
      // Handle 401 Unauthorized — trigger full logout
      if (error.response?.statusCode == 401) {
        ref.read(logoutCallbackProvider)?.call();
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
