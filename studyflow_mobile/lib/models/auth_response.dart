
import 'package:xml/xml.dart';

class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final int userId;
  final String? fullName;
  final String? email;

  const AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.userId = 0,
    this.fullName,
    this.email,
  });

  factory AuthResponse.fromXml(String xml) {
    final document = XmlDocument.parse(xml);

    final fault = document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'faultstring');

    if (fault.isNotEmpty) {
      throw Exception(fault.first.innerText);
    }

    final elements = document.descendants.whereType<XmlElement>();

    String getValue(String tag) {
      final matches = elements.where(
        (element) => element.name.local == tag,
      );

      return matches.isEmpty ? '' : matches.first.innerText.trim();
    }

    final successValue = getValue('success').toLowerCase();

    return AuthResponse(
      success: successValue == 'true',
      message: getValue('message'),
      token: getValue('token').isEmpty ? null : getValue('token'),
      userId: int.tryParse(getValue('userId')) ?? 0,
      fullName: getValue('fullName').isEmpty
          ? null
          : getValue('fullName'),
      email: getValue('email').isEmpty
          ? null
          : getValue('email'),
    );
  }
}
