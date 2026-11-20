import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/api_config.dart';
import '../models/subject.dart';
import 'session_manager.dart';

class SubjectService {
  static const String _namespace = 'http://services.studyflow.com/';

  static Uri get _endpoint {
    final base = Uri.parse(ApiConfig.baseUrl);

    return base.replace(
      path: '/studyflow-backend/SubjectService',
      query: null,
      fragment: null,
    );
  }

  static String _escape(String value) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(value);
  }

  static List<XmlElement> _descendants(XmlElement element) {
    final result = <XmlElement>[];

    for (final child in element.childElements) {
      result.add(child);
      result.addAll(_descendants(child));
    }

    return result;
  }

  static String _directValue(XmlElement element, List<String> names) {
    for (final child in element.childElements) {
      if (names.contains(child.name.local)) {
        return child.innerText.trim();
      }
    }

    return '';
  }

  static String _nestedValue(XmlElement element, List<String> names) {
    for (final node in _descendants(element)) {
      if (names.contains(node.name.local) && node.childElements.isEmpty) {
        return node.innerText.trim();
      }
    }

    return '';
  }

  static SubjectOperationResult _parseResponse(
    String response, {
    bool parseList = false,
  }) {
    try {
      final document = XmlDocument.parse(response);
      final root = document.rootElement;
      final elements = _descendants(root);

      for (final element in elements) {
        if (element.name.local == 'Fault') {
          final message = _nestedValue(element, [
            'faultstring',
            'Text',
            'message',
          ]);

          return SubjectOperationResult(
            success: false,
            message: message.isEmpty ? 'SOAP request failed.' : message,
          );
        }
      }

      final successText = _nestedValue(root, ['success']).toLowerCase();

      final message = _nestedValue(root, ['message']);

      final success = successText == 'true' || successText == '1';

      final subjects = <Subject>[];

      if (parseList) {
        for (final element in elements) {
          if (element.name.local != 'subject') {
            continue;
          }

          final id = _directValue(element, ['id', 'subjectId']);

          final name = _directValue(element, ['name']);

          if (id.isEmpty || name.isEmpty) {
            continue;
          }

          final subject = Subject.fromXml(element);

          if (subject.id != 0 &&
              !subjects.any((item) => item.id == subject.id)) {
            subjects.add(subject);
          }
        }
      }

      Subject? subject;

      if (!parseList) {
        for (final element in elements) {
          if (element.name.local != 'subject') {
            continue;
          }

          final id = _directValue(element, ['id', 'subjectId']);

          final name = _directValue(element, ['name']);

          if (id.isNotEmpty && name.isNotEmpty) {
            subject = Subject.fromXml(element);
            break;
          }
        }
      }

      return SubjectOperationResult(
        success: success,
        message: message.isEmpty
            ? (success ? 'Operation successful.' : 'Operation failed.')
            : message,
        subject: subject,
        subjects: subjects,
      );
    } catch (e) {
      debugPrint('Subject XML parsing error: $e');

      return const SubjectOperationResult(
        success: false,
        message: 'Unable to read the server response.',
      );
    }
  }

  static Future<SubjectOperationResult> _send(
    String operation,
    Map<String, String> parameters, {
    bool parseList = false,
  }) async {
    try {
      final builder = StringBuffer()
        ..write(
          '<soapenv:Envelope '
          'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
          'xmlns:ser="$_namespace">',
        )
        ..write('<soapenv:Header/>')
        ..write('<soapenv:Body>')
        ..write('<ser:$operation>');

      // IMPORTANT:
      // The operation is namespace-qualified.
      // Its parameters are unqualified, according to the WSDL XSD.
      for (final entry in parameters.entries) {
        builder.write(
          '<${entry.key}>'
          '${_escape(entry.value)}'
          '</${entry.key}>',
        );
      }

      builder
        ..write('</ser:$operation>')
        ..write('</soapenv:Body>')
        ..write('</soapenv:Envelope>');

      final requestXml = builder.toString();

      final safeXml = requestXml.replaceAll(
        RegExp(r'(<token>).*?(</token>)', dotAll: true),
        '<token>[TOKEN HIDDEN]</token>',
      );

      debugPrint('========== SUBJECT SOAP ==========');
      debugPrint('Endpoint: $_endpoint');
      debugPrint('Operation: $operation');
      debugPrint('Token length: ${parameters['token']?.length ?? 0}');
      debugPrint('Request XML: $safeXml');

      final response = await http
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': '""',
            },
            body: utf8.encode(requestXml),
          )
          .timeout(ApiConfig.timeout);

      final responseBody = utf8.decode(response.bodyBytes);

      debugPrint('HTTP status: ${response.statusCode}');
      debugPrint('Response XML: $responseBody');
      debugPrint('==================================');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SubjectOperationResult(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }

      return _parseResponse(responseBody, parseList: parseList);
    } catch (e) {
      debugPrint('Subject SOAP error: $e');

      return SubjectOperationResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<SubjectOperationResult> getSubjects() async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      return const SubjectOperationResult(
        success: false,
        message: 'Your session has expired. Please log in again.',
      );
    }

    return _send('getSubjects', {'token': token}, parseList: true);
  }

  static Future<SubjectOperationResult> getSubject(int subjectId) async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      return const SubjectOperationResult(
        success: false,
        message: 'Your session has expired.',
      );
    }

    return _send('getSubject', {
      'token': token,
      'subjectId': subjectId.toString(),
    });
  }

  static Future<SubjectOperationResult> createSubject({
    required String name,
    required String description,
    required String color,
  }) async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      return const SubjectOperationResult(
        success: false,
        message: 'Your session has expired.',
      );
    }

    return _send('createSubject', {
      'token': token,
      'name': name,
      'description': description,
      'color': color,
    });
  }

  static Future<SubjectOperationResult> updateSubject({
    required int subjectId,
    required String name,
    required String description,
    required String color,
  }) async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      return const SubjectOperationResult(
        success: false,
        message: 'Your session has expired.',
      );
    }

    return _send('updateSubject', {
      'token': token,
      'subjectId': subjectId.toString(),
      'name': name,
      'description': description,
      'color': color,
    });
  }

  static Future<SubjectOperationResult> deleteSubject({
    required int subjectId,
    required bool deleteTasks,
  }) async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      return const SubjectOperationResult(
        success: false,
        message: 'Your session has expired.',
      );
    }

    return _send('deleteSubject', {
      'token': token,
      'subjectId': subjectId.toString(),
      'deleteTasks': deleteTasks.toString(),
    });
  }
}
