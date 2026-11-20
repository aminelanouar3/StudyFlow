
import 'package:xml/xml.dart';

class StudyTask {
  final int id;
  final int? subjectId;
  final String title;
  final String? description;
  final String? dueDate;
  final String priority;
  final String status;
  final String? createdAt;

  const StudyTask({
    required this.id,
    this.subjectId,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    required this.status,
    this.createdAt,
  });

  factory StudyTask.fromXml(XmlElement element) {
    String? getValue(String tag) {
      for (final child in element.childElements) {
        if (child.name.local == tag) {
          final value = child.innerText.trim();
          return value.isEmpty ? null : value;
        }
      }
      return null;
    }

    return StudyTask(
      id: int.tryParse(getValue('id') ?? '') ?? 0,
      subjectId: int.tryParse(getValue('subjectId') ?? ''),
      title: getValue('title') ?? 'Untitled task',
      description: getValue('description'),
      dueDate: getValue('dueDate'),
      priority: (getValue('priority') ?? 'MEDIUM').toUpperCase(),
      status: (getValue('status') ?? 'PENDING').toUpperCase(),
      createdAt: getValue('createdAt'),
    );
  }

  DateTime? get parsedDueDate {
    if (dueDate == null || dueDate!.isEmpty) return null;

    return DateTime.tryParse(dueDate!.replaceFirst(' ', 'T'));
  }
}
