
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile_new/app/app.dart';

void main() {
  testWidgets('StudyFlow starts with session restoration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StudyFlowApp());

    expect(
      find.text('Restoring your session...'),
      findsOneWidget,
    );
  });
}
