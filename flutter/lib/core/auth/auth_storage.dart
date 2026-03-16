import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/models/models.dart';

class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<UserModel?> getUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String token, UserModel user) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userKey, value: jsonEncode(user.toJson())),
    ]);
  }

  Future<void> clear() => _storage.deleteAll();
}
