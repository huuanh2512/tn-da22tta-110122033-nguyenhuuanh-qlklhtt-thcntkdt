import 'dart:async';

typedef AccessTokenProvider = Future<String?> Function();

class AuthTokenProviderRegistry {
  AuthTokenProviderRegistry._();

  static AccessTokenProvider? _provider;

  static void configure(AccessTokenProvider? provider) {
    _provider = provider;
  }

  static Future<String?> currentToken() {
    return _provider?.call() ?? Future<String?>.value(null);
  }
}