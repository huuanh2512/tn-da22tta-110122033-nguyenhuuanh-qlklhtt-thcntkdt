import 'dart:convert';

import 'package:authentication_module/data/models/user_result.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthenticationLocalDataSource {
  Future<void> saveUser(UserResult user);
  Future<UserResult?> getUser();
  Future<String?> getAccessToken();
  Future<String?> getUserId();
  Future<DateTime?> getLastActiveAt();
  Future<void> markUserActiveNow();
  Future<void> clearUser();
}

class AuthenticationLocalDataSourceImpl
    implements AuthenticationLocalDataSource {
  AuthenticationLocalDataSourceImpl({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _userPayloadKey = 'auth_user_payload';
  static const String _lastActiveAtKey = 'auth_last_active_at';
  static const String _userIdKey = 'auth_user_id';
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  final FlutterSecureStorage _secureStorage;
  UserResult? _cachedUser;

  Future<void> _safeSecureWrite({
    required String key,
    required String value,
  }) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      // Keep local auth flow resilient when secure storage is unavailable.
    }
  }

  Future<void> _safeSecureDelete({required String key}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // Keep local auth flow resilient when secure storage is unavailable.
    }
  }

  Future<String?> _safeSecureRead({required String key}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveUser(UserResult user) async {
    _cachedUser = user;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPayloadKey, jsonEncode(user.toJson()));
    await prefs.setString(
      _lastActiveAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );

    final String? userId = user.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString(_userIdKey, userId);
    } else {
      await prefs.remove(_userIdKey);
    }

    final String? accessToken = user.accessToken?.trim();
    if (accessToken != null && accessToken.isNotEmpty) {
      await _safeSecureWrite(key: _accessTokenKey, value: accessToken);
    } else {
      await _safeSecureDelete(key: _accessTokenKey);
    }

    final String? refreshToken = user.refreshToken?.trim();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _safeSecureWrite(key: _refreshTokenKey, value: refreshToken);
    } else {
      await _safeSecureDelete(key: _refreshTokenKey);
    }
  }

  @override
  Future<UserResult?> getUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawPayload = prefs.getString(_userPayloadKey);
    if (rawPayload == null || rawPayload.isEmpty) {
      return null;
    }

    final dynamic decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final String? accessToken = await _safeSecureRead(key: _accessTokenKey);
    final String? refreshToken = await _safeSecureRead(key: _refreshTokenKey);

    final UserResult restoredFromPayload = UserResult.fromJson(decoded);
    final String? safeAccessToken = (accessToken ?? '').trim().isNotEmpty
        ? accessToken
        : restoredFromPayload.accessToken;
    final String? safeRefreshToken = (refreshToken ?? '').trim().isNotEmpty
        ? refreshToken
        : restoredFromPayload.refreshToken;

    final UserResult restored = restoredFromPayload.copyWith(
      accessToken: safeAccessToken,
      refreshToken: safeRefreshToken,
    );
    _cachedUser = restored;
    return restored;
  }

  @override
  Future<String?> getAccessToken() async {
    final String? tokenFromSecure =
        await _safeSecureRead(key: _accessTokenKey);
    if (tokenFromSecure != null && tokenFromSecure.trim().isNotEmpty) {
      return tokenFromSecure;
    }

    final String? cachedToken = _cachedUser?.accessToken;
    if (cachedToken != null && cachedToken.trim().isNotEmpty) {
      return cachedToken;
    }

    final UserResult? restoredUser = await getUser();
    final String? restoredToken = restoredUser?.accessToken;
    if (restoredToken != null && restoredToken.trim().isNotEmpty) {
      return restoredToken;
    }

    return null;
  }

  @override
  Future<String?> getUserId() async {
    final String? cachedId = _cachedUser?.userId?.trim();
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_userIdKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final UserResult? restoredUser = await getUser();
    return restoredUser?.userId?.trim().isNotEmpty == true
        ? restoredUser!.userId
        : null;
  }

  @override
  Future<DateTime?> getLastActiveAt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_lastActiveAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Future<void> markUserActiveNow() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastActiveAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clearUser() async {
    _cachedUser = null;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPayloadKey);
    await prefs.remove(_lastActiveAtKey);
    await prefs.remove(_userIdKey);

    await _safeSecureDelete(key: _accessTokenKey);
    await _safeSecureDelete(key: _refreshTokenKey);
  }
}