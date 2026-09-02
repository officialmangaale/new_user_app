import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/nature/widgets/nature_refresh_indicator.dart';

/// The refresh wrapper replaces a visual, nothing else. These tests pin the two
/// things that would matter if it did more: the callback must fire once per
/// gesture, and a second pull must not start a second refresh while one is
/// still running.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Future<void> Function() onRefresh) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NatureRefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.builder(
              itemCount: 30,
              itemBuilder: (context, index) =>
                  SizedBox(height: 60, child: Text('row $index')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a pull past the threshold runs the callback once', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(host(() async => refreshes++));

    await tester.fling(find.text('row 0'), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('a short pull does not run the callback', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(host(() async => refreshes++));

    await tester.drag(find.text('row 0'), const Offset(0, 20));
    await tester.pumpAndSettle();

    expect(refreshes, 0);
  });

  testWidgets('a second pull cannot start a refresh while one is running', (
    tester,
  ) async {
    var refreshes = 0;
    final gate = Completer<void>();

    await tester.pumpWidget(
      host(() {
        refreshes++;
        return gate.future;
      }),
    );

    await tester.fling(find.text('row 0'), const Offset(0, 320), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(refreshes, 1);

    // Pull again while the first refresh is still in flight.
    await tester.fling(find.text('row 0'), const Offset(0, 320), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      refreshes,
      1,
      reason: 'concurrent refreshes must not stack up duplicate API calls',
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the loading leaf stops when the refresh completes', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(host(() => gate.future));

    await tester.fling(find.text('row 0'), const Offset(0, 320), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    gate.complete();
    // If the spin controller kept repeating after the refresh resolved, this
    // would hang forever rather than fail — which is exactly the hazard being
    // guarded here.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes cleanly mid-refresh', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(host(() => gate.future));

    await tester.fling(find.text('row 0'), const Offset(0, 320), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tear it down while the leaf is still turning.
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SizedBox.shrink())),
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
