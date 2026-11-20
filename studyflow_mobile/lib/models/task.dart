
import 'package:xml/xml.dart';

class Task {
  final int id;
  final int? subjectId;
  final String title;
  final String description;
  final String? dueDate;
  final String priority;
  final String status;
  final String? createdAt;

  const Task({
    required this.id,
    this.subjectId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.priority = 'MEDIUM',
    this.status = 'PENDING',
    this.createdAt,
  });

  factory Task.fromXml(XmlElement element) {
    String? read(String name) {
      for (final child in element.childElements) {
        if (child.name.local == name) {
          final value = child.innerText.trim();
          return value.isEmpty ? null : value;
        }
      }
      return null;
    }

    return Task(
      id: int.tryParse(read('id') ?? '') ?? 0,
      subjectId: int.tryParse(read('subjectId') ?? ''),
      title: read('title') ?? '',
      description: read('description') ?? '',
      dueDate: read('dueDate'),
      priority: (read('priority') ?? 'MEDIUM').toUpperCase(),
      status: (read('status') ?? 'PENDING').toUpperCase(),
      createdAt: read('createdAt'),
    );
  }
}

class TaskListResult {
  final bool success;
  final String message;
  final List<Task> tasks;

  const TaskListResult({
    required this.success,
    required this.message,
    this.tasks = const [],
  });
}

class TaskOperationResult {
  final bool success;
  final String message;
  final Task? task;

  const TaskOperationResult({
    required this.success,
    required this.message,
    this.task,
  });
}
