
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/task.dart';
import '../config/api_config.dart';
import 'session_manager.dart';

class TaskService {
  static const String _namespace =
      'http://services.studyflow.com/';

  static const String _soapNamespace =
      'http://schemas.xmlsoap.org/soap/envelope/';

  static final Uri _endpoint = Uri.parse(
    'http://10.0.2.2:8080/studyflow-backend/TaskService',
  );

  Future<String> _sendRequest(
    String operation,
    Map<String, String> parameters,
  ) async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }

    final builder = XmlBuilder();

    builder.element(
      'soap:Envelope',
      nest: () {
        builder.attribute('xmlns:soap', _soapNamespace);
        builder.attribute('xmlns:tns', _namespace);

        builder.element(
          'soap:Body',
          nest: () {
            // Operation is in the services namespace.
            builder.element(
              'tns:$operation',
              nest: () {
                // Parameters are intentionally unqualified.
                builder.element(
                  'token',
                  nest: () {
                    builder.text(token);
                  },
                );

                for (final entry in parameters.entries) {
                  builder.element(
                    entry.key,
                    nest: () {
                      builder.text(entry.value);
                    },
                  );
                }
              },
            );
          },
        );
      },
    );

    final requestXml =
        builder.buildDocument().toXmlString();

    final response = await http
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'text/xml; charset=utf-8',
            'Accept': 'text/xml',
          },
          body: requestXml,
        )
        .timeout(ApiConfig.timeout);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'SOAP HTTP error: ${response.statusCode}\n'
        '${response.body}',
      );
    }

    final document = XmlDocument.parse(response.body);

    final faults = document.descendantElements.where(
      (element) => element.name.local == 'faultstring',
    );

    if (faults.isNotEmpty) {
      throw Exception(faults.first.innerText.trim());
    }

    return response.body;
  }

  XmlDocument _parse(String xml) {
    return XmlDocument.parse(xml);
  }

  String _read(XmlDocument document, String name) {
    final elements = document.descendantElements.where(
      (element) => element.name.local == name,
    );

    return elements.isEmpty
        ? ''
        : elements.first.innerText.trim();
  }

  bool _success(XmlDocument document) {
    return _read(document, 'success').toLowerCase() == 'true';
  }

  Task? _readTask(XmlDocument document) {
    final elements = document.descendantElements.where(
      (element) => element.name.local == 'task',
    );

    if (elements.isEmpty) return null;

    return Task.fromXml(elements.first);
  }

  List<Task> _readTasks(XmlDocument document) {
    return document.descendantElements
        .where((element) => element.name.local == 'task')
        .map((element) => Task.fromXml(element))
        .toList();
  }

  Future<TaskListResult> getTasks() async {
  try {
    final xml = await _sendRequest('getTasks', {});

    print('========== GLOBAL TASKS SOAP RESPONSE ==========');
    print(xml);
    print('================================================');

    final document = _parse(xml);
    final tasks = _readTasks(document);

    print('GLOBAL SUCCESS: ${_success(document)}');
    print('GLOBAL MESSAGE: ${_read(document, 'message')}');
    print('GLOBAL TASK COUNT: ${tasks.length}');

    for (final task in tasks) {
      print(
        'TASK: id=${task.id}, '
        'title=${task.title}, '
        'subjectId=${task.subjectId}, '
        'status=${task.status}',
      );
    }

    return TaskListResult(
      success: _success(document),
      message: _read(document, 'message'),
      tasks: tasks,
    );
  } catch (e) {
    print('GLOBAL TASK ERROR: $e');

    return TaskListResult(
      success: false,
      message: e.toString(),
    );
  }
}

  Future<TaskListResult> getTasksBySubjectId(
    int subjectId,
  ) async {
    try {
      final xml = await _sendRequest(
        'getTasksBySubjectId',
        {
          'subjectId': subjectId.toString(),
        },
      );

      final document = _parse(xml);

      return TaskListResult(
        success: _success(document),
        message: _read(document, 'message'),
        tasks: _readTasks(document),
      );
    } catch (e) {
      return TaskListResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<TaskOperationResult> getTask(int taskId) async {
    try {
      final xml = await _sendRequest(
        'getTask',
        {
          'taskId': taskId.toString(),
        },
      );

      final document = _parse(xml);

      return TaskOperationResult(
        success: _success(document),
        message: _read(document, 'message'),
        task: _readTask(document),
      );
    } catch (e) {
      return TaskOperationResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<TaskOperationResult> createTask({
    int? subjectId,
    required String title,
    required String description,
    String? dueDate,
    required String priority,
    required String status,
  }) async {
    try {
      final xml = await _sendRequest(
        'createTask',
        {
          'subjectId': subjectId?.toString() ?? '',
          'title': title,
          'description': description,
          'dueDate': dueDate ?? '',
          'priority': priority,
          'status': status,
        },
      );

      final document = _parse(xml);

      return TaskOperationResult(
        success: _success(document),
        message: _read(document, 'message'),
        task: _readTask(document),
      );
    } catch (e) {
      return TaskOperationResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<TaskOperationResult> updateTask({
    required int taskId,
    int? subjectId,
    required String title,
    required String description,
    String? dueDate,
    required String priority,
    required String status,
  }) async {
    try {
      final xml = await _sendRequest(
        'updateTask',
        {
          'taskId': taskId.toString(),
          'subjectId': subjectId?.toString() ?? '',
          'title': title,
          'description': description,
          'dueDate': dueDate ?? '',
          'priority': priority,
          'status': status,
        },
      );

      final document = _parse(xml);

      return TaskOperationResult(
        success: _success(document),
        message: _read(document, 'message'),
        task: _readTask(document),
      );
    } catch (e) {
      return TaskOperationResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<TaskOperationResult> deleteTask(int taskId) async {
    try {
      final xml = await _sendRequest(
        'deleteTask',
        {
          'taskId': taskId.toString(),
        },
      );

      final document = _parse(xml);

      return TaskOperationResult(
        success: _success(document),
        message: _read(document, 'message'),
      );
    } catch (e) {
      return TaskOperationResult(
        success: false,
        message: e.toString(),
      );
    }
  }
}
