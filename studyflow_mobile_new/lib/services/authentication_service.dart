
import '../models/auth_response.dart';
import 'soap_client.dart';

class AuthenticationService {
  AuthenticationService._();

  static Future<AuthResponse> _call({
    required String operation,
    required Map<String, String> parameters,
  }) async {
    final xml = await SoapClient.send(
      operation: operation,
      parameters: parameters,
    );

    return AuthResponse.fromSoapXml(xml);
  }

  // 1. Register
  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _call(
      operation: 'register',
      parameters: {
        'fullName': fullName,
        'email': email,
        'password': password,
      },
    );
  }

  // 2. Change password
  static Future<AuthResponse> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) {
    return _call(
      operation: 'changePassword',
      parameters: {
        'token': token,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  // 3. Login
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _call(
      operation: 'login',
      parameters: {
        'email': email,
        'password': password,
      },
    );
  }

  // 4. Logout
  static Future<AuthResponse> logout({
    required String token,
  }) {
    return _call(
      operation: 'logout',
      parameters: {
        'token': token,
      },
    );
  }

  // 5. Verify email change
  static Future<AuthResponse> verifyEmailChange({
    required String token,
    required String code,
  }) {
    return _call(
      operation: 'verifyEmailChange',
      parameters: {
        'token': token,
        'code': code,
      },
    );
  }

  // 6. Request email change
  static Future<AuthResponse> requestEmailChange({
    required String token,
    required String currentPassword,
    required String newEmail,
  }) {
    return _call(
      operation: 'requestEmailChange',
      parameters: {
        'token': token,
        'currentPassword': currentPassword,
        'newEmail': newEmail,
      },
    );
  }

  // 7. Resend verification code
  static Future<AuthResponse> resendVerificationCode({
    required String email,
  }) {
    return _call(
      operation: 'resendVerificationCode',
      parameters: {
        'email': email,
      },
    );
  }

  // 8. Verify password reset code
  static Future<AuthResponse> verifyResetCode({
    required String email,
    required String code,
  }) {
    return _call(
      operation: 'verifyResetCode',
      parameters: {
        'email': email,
        'code': code,
      },
    );
  }

  // 9. Verify email
  static Future<AuthResponse> verifyEmail({
    required String email,
    required String code,
  }) {
    return _call(
      operation: 'verifyEmail',
      parameters: {
        'email': email,
        'code': code,
      },
    );
  }

  // 10. Forgot password
  static Future<AuthResponse> forgotPassword({
    required String email,
  }) {
    return _call(
      operation: 'forgotPassword',
      parameters: {
        'email': email,
      },
    );
  }

  // 11. Reset password
  static Future<AuthResponse> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _call(
      operation: 'resetPassword',
      parameters: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
    );
  }

  // 12. Get profile
  static Future<AuthResponse> getProfile({
    required String token,
  }) {
    return _call(
      operation: 'getProfile',
      parameters: {
        'token': token,
      },
    );
  }

  // 13. Change full name
  static Future<AuthResponse> changeFullName({
    required String token,
    required String currentPassword,
    required String newFullName,
  }) {
    return _call(
      operation: 'changeFullName',
      parameters: {
        'token': token,
        'currentPassword': currentPassword,
        'newFullName': newFullName,
      },
    );
  }
}
