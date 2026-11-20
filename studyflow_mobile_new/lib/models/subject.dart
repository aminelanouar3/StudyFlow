
import 'package:xml/xml.dart';

class Subject {
  final int id;
  final String name;
  final String? description;
  final String? color;
  final String? createdAt;

  const Subject({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.createdAt,
  });

  factory Subject.fromXml(XmlElement element) {
    String? getValue(String tag) {
      for (final child in element.childElements) {
        if (child.name.local == tag) {
          final value = child.innerText.trim();
          return value.isEmpty ? null : value;
        }
      }
      return null;
    }

    return Subject(
      id: int.tryParse(getValue('id') ?? '') ?? 0,
      name: getValue('name') ?? 'Unnamed subject',
      description: getValue('description'),
      color: getValue('color'),
      createdAt: getValue('createdAt'),
    );
  }
}
