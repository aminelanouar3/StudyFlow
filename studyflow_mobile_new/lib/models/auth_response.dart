
import 'package:xml/xml.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final int userId;
  final String? fullName;
  final String? email;

  const AuthResponse({
    required this.success,
    required this.userId,
    this.message,
    this.token,
    this.fullName,
    this.email,
  });

  factory AuthResponse.fromSoapXml(String xml) {
    final document = XmlDocument.parse(xml);

    XmlElement? returnElement;

    for (final element in document.descendantElements) {
      if (element.name.local == 'return') {
        returnElement = element;
        break;
      }
    }

    if (returnElement == null) {
      throw const FormatException(
        'Invalid SOAP response: return element not found.',
      );
    }

    String? getValue(String name) {
      for (final element in returnElement!.childElements) {
        if (element.name.local == name) {
          return element.innerText;
        }
      }
      return null;
    }

    final successValue = getValue('success');

    if (successValue == null) {
      throw const FormatException(
        'Invalid SOAP response: success field not found.',
      );
    }

    return AuthResponse(
      success: successValue.toLowerCase() == 'true' ||
          successValue == '1',
      message: getValue('message'),
      token: getValue('token'),
      userId: int.tryParse(getValue('userId') ?? '') ?? 0,
      fullName: getValue('fullName'),
      email: getValue('email'),
    );
  }
}
