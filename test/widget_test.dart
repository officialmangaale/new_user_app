import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turquoise_delivery/app/app.dart';

void main() {
  testWidgets('launches the turquoise delivery app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurquoiseApp()));
    expect(find.text('turquoise'), findsOneWidget);
  });

  testWidgets('guest can enter home and switch bottom navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: TurquoiseApp()));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Explore as guest'), findsOneWidget);

    await tester.tap(find.text('Explore as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('Good evening'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded).last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('Good evening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login route supports back navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurquoiseApp()));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('Continue with mobile number'));
    await tester.tap(find.text('Continue with mobile number'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('What’s your number?'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Explore as guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
