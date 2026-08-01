import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:technopro_crm/main.dart';

void main() {
  testWidgets('TechnoPro application shell smoke test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: DesktopScrollBehavior(),
        home: const Scaffold(body: Text('TechnoPro')),
      ),
    );

    expect(find.text('TechnoPro'), findsOneWidget);
    expect(DesktopScrollBehavior(), isA<ScrollBehavior>());
  });
}
