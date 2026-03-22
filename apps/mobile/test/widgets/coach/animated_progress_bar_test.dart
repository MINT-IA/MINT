// ────────────────────────────────────────────────────────────
//  ANIMATED PROGRESS BAR — Widget tests
// ────────────────────────────────────────────────────────────
//
//  Tests:
//  1.  Renders without crashing
//  2.  Shows label when provided
//  3.  No label element when label is null
//  4.  Progress 0.0 does not crash
//  5.  Progress 1.0 does not crash
//  6.  Out-of-range value (> 1.0) is clamped — no crash
//  7.  Negative progress clamped — no crash
//  8.  Custom color does not crash
//  9.  Custom duration does not crash
//  10. LinearProgressIndicator is present in tree
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/animated_progress_bar.dart';

// ── Helper ──────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

// ── Tests ───────────────────────────────────────────────────

void main() {
  group('AnimatedProgressBar', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: 0.5),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('LinearProgressIndicator is present in tree', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: 0.7),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows label text when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(
          progress: 0.3,
          label: '3/10 étapes',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3/10 étapes'), findsOneWidget);
    });

    testWidgets('no Text widget for label when label is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: 0.6),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      // No Text widget should be present (only LinearProgressIndicator)
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('progress 0.0 does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: 0.0),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('progress 1.0 does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: 1.0),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('out-of-range progress (> 1.0) is clamped — no crash',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: 1.5),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('negative progress is clamped — no crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(progress: -0.2),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('custom color does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(
          progress: 0.4,
          color: Color(0xFF24B14D),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('custom duration does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(
          progress: 0.5,
          duration: Duration(milliseconds: 100),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressBar), findsOneWidget);
    });

    testWidgets('label + progress renders both label and indicator',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedProgressBar(
          progress: 0.5,
          label: '5 étapes complètes',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('5 étapes complètes'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
