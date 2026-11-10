
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

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
    String parameters,
  ) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope
    xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:ser="${ApiConfig.namespace}">
  <soapenv:Header/>
  <soapenv:Body>
    <ser:$operation>
      $parameters
    </ser:$operation>
  </soapenv:Body>
</soapenv:Envelope>
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
      throw Exception('The SOAP server returned an empty response.');
    }

    final result = AuthResponse.fromXml(response.body);

    if (response.statusCode != 200 && result.message.isEmpty) {
      throw Exception('SOAP request failed: HTTP ${response.statusCode}');
    }

    return result;
  }

  // Register a new student account.
  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) {
    final parameters = '''
      <fullName>${_escape(fullName)}</fullName>
      <email>${_escape(email)}</email>
      <password>${_escape(password)}</password>
    ''';

    return _send('register', parameters);
  }

  // Authenticate an existing student.
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    final parameters = '''
      <email>${_escape(email)}</email>
      <password>${_escape(password)}</password>
    ''';

    return _send('login', parameters);
  }

  // End the current session.
  static Future<AuthResponse> logout({
    required String token,
  }) {
    final parameters = '''
      <token>${_escape(token)}</token>
    ''';

    return _send('logout', parameters);
  }

  // Retrieve the connected student's profile.
  static Future<AuthResponse> getProfile({
    required String token,
  }) {
    final parameters = '''
      <token>${_escape(token)}</token>
    ''';

    return _send('getProfile', parameters);
  }
}
