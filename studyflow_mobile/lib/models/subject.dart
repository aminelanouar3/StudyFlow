import 'package:xml/xml.dart';

class Subject {
  final int id;
  final String name;
  final String description;
  final String color;

  const Subject({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
  });

  factory Subject.fromXml(XmlElement element) {
    String read(List<String> names) {
      for (final child in element.childElements) {
        if (names.contains(child.name.local)) {
          return child.innerText.trim();
        }
      }
      return '';
    }

    return Subject(
      id: int.tryParse(read(['id', 'subjectId'])) ?? 0,
      name: read(['name']),
      description: read(['description']),
      color: read(['color']).isEmpty ? '#6C63FF' : read(['color']),
    );
  }
}

class SubjectOperationResult {
  final bool success;
  final String message;
  final Subject? subject;
  final List<Subject> subjects;

  const SubjectOperationResult({
    required this.success,
    required this.message,
    this.subject,
    this.subjects = const [],
  });
}
