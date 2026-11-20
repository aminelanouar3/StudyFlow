import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_mobile/app/app.dart';

void main() {
  testWidgets('StudyFlow app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyFlowApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}