import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivy_kiosk/app/vivy_app.dart';

void main() {
  testWidgets('shows the clock surface and progressively reveals recording', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VivyApp()));
    await tester.pump();

    expect(find.text('VIVY'), findsNothing);
    expect(find.text('Up next'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Recording')), findsOneWidget);
    expect(find.text('Storage'), findsNothing);

    final clock = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
    );
    expect(clock, findsOneWidget);
    final center = tester.getCenter(clock);
    expect((center.dx - 640).abs(), lessThan(4));
    expect((center.dy - 400).abs(), lessThan(4));

    await tester.tapAt(const Offset(640, 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getCenter(find.byIcon(Icons.tune_rounded)).dx,
      greaterThan(1120),
    );

    await tester.tap(find.bySemanticsLabel(RegExp('Recording')));
    await tester.pumpAndSettle();

    expect(find.text('Recording'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('2 minutes'), findsOneWidget);
  });

  testWidgets('uses a two-column settings workspace on Xperia landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VivyApp()));
    await tester.pump();
    await tester.tapAt(const Offset(320, 180));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Material palette'), findsOneWidget);
    expect(find.text('Clock type'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Recording cache'), findsOneWidget);
    expect(find.byType(Scrollable), findsAtLeastNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
