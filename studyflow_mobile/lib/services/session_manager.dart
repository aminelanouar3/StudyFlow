
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_response.dart';
import 'authentication_service.dart';

class SessionManager {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<AuthResponse?> restoreSession() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await AuthenticationService.getProfile(
        token: token,
      );

      if (response.success) {
        return response;
      }

      await clearSession();
      return null;
    } catch (_) {
      // Keep the saved token if the server is temporarily unreachable.
      return null;
    }
  }
}
