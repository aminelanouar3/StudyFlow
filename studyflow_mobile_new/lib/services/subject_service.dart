
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/api_config.dart';
import '../models/subject.dart';

class SubjectService {
  SubjectService._();

  static const String _soapNamespace =
      'http://schemas.xmlsoap.org/soap/envelope/';

  static const String _serviceNamespace =
      'http://services.studyflow.com/';

  static final Uri _endpoint = Uri.parse(
    '${ApiConfig.baseUrl}/studyflow-backend/SubjectService',
  );

  static Future<List<Subject>> getSubjects({
    required String token,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:getSubjects>
      <token>${_escapeXml(token)}</token>
    </ser:getSubjects>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);

    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from SubjectService.');
    }

    _checkSuccess(result);

    final subjects = <Subject>[];

    for (final element in result.childElements) {
      if (element.name.local == 'subject') {
        subjects.add(Subject.fromXml(element));
      }
    }

    return subjects;
  }

  static Future<void> createSubject({
    required String token,
    required String name,
    String? description,
    required String color,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:createSubject>
      <token>${_escapeXml(token)}</token>
      <name>${_escapeXml(name)}</name>
      <description>${_escapeXml(description ?? '')}</description>
      <color>${_escapeXml(color)}</color>
    </ser:createSubject>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);

    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from SubjectService.');
    }

    _checkSuccess(result);
  }

  static Future<http.Response> _sendRequest(String envelope) async {
    final response = await http
        .post(
          _endpoint,
          headers: const {
            'Content-Type': 'text/xml; charset=utf-8',
            'SOAPAction': '',
          },
          body: envelope,
          encoding: utf8,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'SubjectService HTTP error: ${response.statusCode}',
      );
    }

    return response;
  }

  static XmlDocument _parseResponse(http.Response response) {
    final document = XmlDocument.parse(response.body);

    final fault = _findElement(document, 'faultstring');

    if (fault != null) {
      throw Exception(fault.innerText.trim());
    }

    return document;
  }

  static void _checkSuccess(XmlElement result) {
    final successText = _getChildText(result, 'success');

    final success = successText?.toLowerCase() == 'true' ||
        successText == '1';

    if (!success) {
      final message = _getChildText(result, 'message');
      throw Exception(message ?? 'The operation failed.');
    }
  }

  static XmlElement? _findElement(
    XmlNode node,
    String localName,
  ) {
    for (final element in node.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) {
        return element;
      }
    }

    return null;
  }

  static String? _getChildText(
    XmlElement parent,
    String name,
  ) {
    for (final child in parent.childElements) {
      if (child.name.local == name) {
        return child.innerText.trim();
      }
    }

    return null;
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
