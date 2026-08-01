import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/models.dart';
import '../api/api_client.dart';
import 'auth_storage.dart';
import 'logout_callback_provider.dart';

class AuthState {
  final String? token;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.token, this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    String? token,
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearAuth = false,
  }) {
    return AuthState(
      token: clearAuth ? null : (token ?? this.token),
      user: clearAuth ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref, this._storage)
      : super(const AuthState(isLoading: true)) {
    _init();
  }

  final Ref _ref;
  final AuthStorage _storage;

  void _setToken(String? token) {
    _ref.read(tokenProvider.notifier).state = token;
  }

  Future<void> _init() async {
    // Restore saved server URL before anything else
    final savedUrl = await _storage.getServerUrl();
    if (savedUrl != null) {
      final normalisedUrl = normalizeServerUrl(savedUrl);
      _ref.read(serverUrlProvider.notifier).state = normalisedUrl;
      if (normalisedUrl != savedUrl) {
        await _storage.saveServerUrl(normalisedUrl);
      }
    }

    final token = await _storage.getToken();
    final user = await _storage.getUser();
    if (token != null && user != null) {
      _setToken(token);
      state = AuthState(token: token, user: user);
    } else {
      state = const AuthState();
    }
    // Register logout callback for Dio 401 handler (avoids circular import)
    _ref.read(logoutCallbackProvider.notifier).state = logout;
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dio = _ref.read(apiClientProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: LoginRequest(email: email, password: password).toJson(),
      );
      final body = LoginResponse.fromJson(res.data!['data'] as Map<String, dynamic>);
      _setToken(body.token);
      await _storage.save(body.token, body.user);
      state = AuthState(token: body.token, user: body.user);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: apiErrorMessage(e));
    }
  }

  Future<void> logout() async {
    _setToken(null);
    await _storage.clear();
    state = const AuthState();
  }
}

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref, ref.read(authStorageProvider));
});
