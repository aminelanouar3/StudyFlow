
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/auth_response.dart';

class AuthenticationService {
  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static Future<AuthResponse> _send(
    String operation,
    Map<String, String> parameters,
  ) async {
    final parameterXml = parameters.entries
        .map((entry) =>
            '<${entry.key}>${_escape(entry.value)}</${entry.key}>')
        .join();

    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:ser="${ApiConfig.namespace}">
  <soap:Header/>
  <soap:Body>
    <ser:$operation>
      $parameterXml
    </ser:$operation>
  </soap:Body>
</soap:Envelope>
''';

    final response = await http
        .post(
          Uri.parse(ApiConfig.baseUrl),
          headers: {
            'Content-Type': 'text/xml; charset=utf-8',
            'SOAPAction': '""',
          },
          body: envelope,
        )
        .timeout(ApiConfig.timeout);

    if (response.body.isEmpty) {
      throw Exception('The server returned an empty response.');
    }

    final authResponse = AuthResponse.fromXml(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        authResponse.message.isNotEmpty
            ? authResponse.message
            : 'Server error: HTTP ${response.statusCode}',
      );
    }

    return authResponse;
  }

  // REGISTER
  static Future<AuthResponse> register(
    String fullName,
    String email,
    String password,
  ) {
    return _send('register', {
      'fullName': fullName,
      'email': email,
      'password': password,
    });
  }

  // VERIFY EMAIL
  static Future<AuthResponse> verifyEmail(
    String email,
    String code,
  ) {
    return _send('verifyEmail', {
      'email': email,
      'code': code,
    });
  }

  // RESEND EMAIL VERIFICATION CODE
  static Future<AuthResponse> resendVerificationCode(
    String email,
  ) {
    return _send('resendVerificationCode', {
      'email': email,
    });
  }

  // FORGOT PASSWORD
  static Future<AuthResponse> forgotPassword(
    String email,
  ) {
    return _send('forgotPassword', {
      'email': email,
    });
  }

  // VERIFY PASSWORD RESET CODE
  static Future<AuthResponse> verifyResetCode(
    String email,
    String code,
  ) {
    return _send('verifyResetCode', {
      'email': email,
      'code': code,
    });
  }

  // RESET PASSWORD
  static Future<AuthResponse> resetPassword(
    String email,
    String code,
    String newPassword,
  ) {
    return _send('resetPassword', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  // LOGIN
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _send('login', {
      'email': email,
      'password': password,
    });
  }

  // LOGOUT
  static Future<AuthResponse> logout({
    required String token,
  }) {
    return _send('logout', {
      'token': token,
    });
  }

  // GET PROFILE
  static Future<AuthResponse> getProfile({
    required String token,
  }) {
    return _send('getProfile', {
      'token': token,
    });
  }

    // CHANGE PASSWORD
  static Future<AuthResponse> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) {
    return _send('changePassword', {
      'token': token,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

    // CHANGE FULL NAME
  static Future<AuthResponse> changeFullName({
    required String token,
    required String currentPassword,
    required String newFullName,
  }) {
    return _send('changeFullName', {
      'token': token,
      'currentPassword': currentPassword,
      'newFullName': newFullName,
    });
  }

  // REQUEST EMAIL CHANGE
  static Future<AuthResponse> requestEmailChange({
    required String token,
    required String currentPassword,
    required String newEmail,
  }) {
    return _send('requestEmailChange', {
      'token': token,
      'currentPassword': currentPassword,
      'newEmail': newEmail,
    });
  }

  // VERIFY EMAIL CHANGE
  static Future<AuthResponse> verifyEmailChange({
    required String token,
    required String code,
  }) {
    return _send('verifyEmailChange', {
      'token': token,
      'code': code,
    });
  }
}
