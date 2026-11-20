
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/api_config.dart';
import '../models/task.dart';

class TaskService {
  TaskService._();

  static const String _soapNamespace =
      'http://schemas.xmlsoap.org/soap/envelope/';

  static const String _serviceNamespace =
      'http://services.studyflow.com/';

  static final Uri _endpoint = Uri.parse(
    '${ApiConfig.baseUrl}/studyflow-backend/TaskService',
  );

  static Future<List<StudyTask>> getTasks({
    required String token,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:getTasks>
      <token>${_escapeXml(token)}</token>
    </ser:getTasks>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);
    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from TaskService.');
    }

    _checkSuccess(result);

    return result.childElements
        .where((element) => element.name.local == 'task')
        .map(StudyTask.fromXml)
        .toList();
  }

  static Future<List<StudyTask>> getTasksBySubjectId({
    required String token,
    required String subjectId,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:getTasksBySubjectId>
      <token>${_escapeXml(token)}</token>
      <subjectId>${_escapeXml(subjectId)}</subjectId>
    </ser:getTasksBySubjectId>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);
    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from TaskService.');
    }

    _checkSuccess(result);

    return result.childElements
        .where((element) => element.name.local == 'task')
        .map(StudyTask.fromXml)
        .toList();
  }

  static Future<StudyTask> getTask({
    required String token,
    required String taskId,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:getTask>
      <token>${_escapeXml(token)}</token>
      <taskId>${_escapeXml(taskId)}</taskId>
    </ser:getTask>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);
    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from TaskService.');
    }

    _checkSuccess(result);

    final taskElement = _findElement(result, 'task');

    if (taskElement == null) {
      throw Exception('Task not found in the response.');
    }

    return StudyTask.fromXml(taskElement);
  }

  static Future<void> createTask({
    required String token,
    int? subjectId,
    required String title,
    required String description,
    String? dueDate,
    required String priority,
    required String status,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:createTask>
      <token>${_escapeXml(token)}</token>
      <subjectId>${subjectId?.toString() ?? ''}</subjectId>
      <title>${_escapeXml(title)}</title>
      <description>${_escapeXml(description)}</description>
      <dueDate>${_escapeXml(dueDate ?? '')}</dueDate>
      <priority>${_escapeXml(priority.toUpperCase())}</priority>
      <status>${_escapeXml(status.toUpperCase())}</status>
    </ser:createTask>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);
    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from TaskService.');
    }

    _checkSuccess(result);
  }

  static Future<void> updateTask({
    required String token,
    required String taskId,
    int? subjectId,
    required String title,
    required String description,
    String? dueDate,
    required String priority,
    required String status,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:updateTask>
      <token>${_escapeXml(token)}</token>
      <taskId>${_escapeXml(taskId)}</taskId>
      <subjectId>${subjectId?.toString() ?? ''}</subjectId>
      <title>${_escapeXml(title)}</title>
      <description>${_escapeXml(description)}</description>
      <dueDate>${_escapeXml(dueDate ?? '')}</dueDate>
      <priority>${_escapeXml(priority.toUpperCase())}</priority>
      <status>${_escapeXml(status.toUpperCase())}</status>
    </ser:updateTask>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);
    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from TaskService.');
    }

    _checkSuccess(result);
  }

  static Future<void> deleteTask({
    required String token,
    required String taskId,
  }) async {
    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="$_soapNamespace"
    xmlns:ser="$_serviceNamespace">
  <soap:Header/>
  <soap:Body>
    <ser:deleteTask>
      <token>${_escapeXml(token)}</token>
      <taskId>${_escapeXml(taskId)}</taskId>
    </ser:deleteTask>
  </soap:Body>
</soap:Envelope>
''';

    final response = await _sendRequest(envelope);
    final document = _parseResponse(response);
    final result = _findElement(document, 'return');

    if (result == null) {
      throw Exception('Invalid response from TaskService.');
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
        'TaskService HTTP error: ${response.statusCode}',
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
