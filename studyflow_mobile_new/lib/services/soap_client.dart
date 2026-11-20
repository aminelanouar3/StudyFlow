
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SoapClient {
  SoapClient._();

  static const String _soapNamespace =
      'http://schemas.xmlsoap.org/soap/envelope/';

  static const String _serviceNamespace =
      'http://services.studyflow.com/';

  static Future<String> send({
    required String operation,
    required Map<String, String> parameters,
  }) async {
    final uri = Uri.parse(ApiConfig.authenticationEndpoint);

    final requestBody = _buildEnvelope(
      operation: operation,
      parameters: parameters,
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': '""',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      final fault = _extractSoapFault(response.body);

      if (fault != null) {
        throw Exception(fault);
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'SOAP request failed with HTTP ${response.statusCode}.',
        );
      }

      return response.body;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to connect to the StudyFlow server: $e',
      );
    }
  }

  static String _buildEnvelope({
    required String operation,
    required Map<String, String> parameters,
  }) {
    final buffer = StringBuffer();

    buffer.write(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<soapenv:Envelope '
      'xmlns:soapenv="$_soapNamespace" '
      'xmlns:ser="$_serviceNamespace">'
      '<soapenv:Header/>'
      '<soapenv:Body>'
      '<ser:$operation>',
    );

    for (final entry in parameters.entries) {
      // Local XSD elements are unqualified.
      buffer.write(
        '<${entry.key}>'
        '${_escapeXml(entry.value)}'
        '</${entry.key}>',
      );
    }

    buffer.write(
      '</ser:$operation>'
      '</soapenv:Body>'
      '</soapenv:Envelope>',
    );

    return buffer.toString();
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String? _extractSoapFault(String xml) {
    final faultMatch = RegExp(
      r'<(?:\w+:)?faultstring[^>]*>(.*?)</(?:\w+:)?faultstring>',
      dotAll: true,
    ).firstMatch(xml);

    return faultMatch?.group(1)?.trim();
  }
}
