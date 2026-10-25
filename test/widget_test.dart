// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/config/routes/app_routes.dart';
import 'package:billing_app/features/birthday/presentation/pages/birthday_greeting_page.dart';

void main() {
  testWidgets('birthday greeting fits and scrolls on a small phone',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );

    expect(find.byType(BirthdayGreetingPage), findsOneWidget);
    expect(find.text('Happy\nBirthday!'), findsOneWidget);
    expect(find.text('28 October 2004'), findsOneWidget);
    await tester.ensureVisible(find.text('28 October 2004'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
