
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

import '../config/api_config.dart';
import '../models/dashboard_data.dart';

class DashboardService {
  DashboardService._();

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static xml.XmlElement? _firstChild(
    xml.XmlElement parent,
    String name,
  ) {
    for (final child in parent.childElements) {
      if (child.name.local == name) {
        return child;
      }
    }
    return null;
  }

  static Future<DashboardData> getDashboard({
    required String token,
  }) async {
    final escapedToken = _escapeXml(token);

    final envelope = '''
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope
    xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:ser="http://services.studyflow.com/">
  <soap:Header/>
  <soap:Body>
    <ser:getDashboard>
      <token>$escapedToken</token>
    </ser:getDashboard>
  </soap:Body>
</soap:Envelope>
''';

    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/studyflow-backend/DashboardService',
      ),
      headers: {
        'Content-Type': 'text/xml; charset=utf-8',
        'SOAPAction': '',
      },
      body: envelope,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Dashboard request failed: HTTP ${response.statusCode}',
      );
    }

    final document = xml.XmlDocument.parse(response.body);

    final fault = document.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'Fault')
        .firstOrNull;

    if (fault != null) {
      throw Exception(fault.innerText.trim());
    }

    final returnElement = document.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'return')
        .firstOrNull;

    if (returnElement == null) {
      throw Exception('Dashboard response is missing.');
    }

    final successElement = _firstChild(returnElement, 'success');

    final success = successElement?.innerText.trim().toLowerCase() == 'true';

    if (!success) {
      final message = _firstChild(returnElement, 'message')?.innerText.trim();

      throw Exception(
        message == null || message.isEmpty
            ? 'Could not load dashboard.'
            : message,
      );
    }

    return DashboardData.fromXmlReturn(returnElement);
  }
}
