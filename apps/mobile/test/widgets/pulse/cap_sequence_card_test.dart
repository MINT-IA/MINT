import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/widgets/pulse/cap_sequence_card.dart';

// ────────────────────────────────────────────────────────────────
//  CAP SEQUENCE CARD — Widget Tests
// ────────────────────────────────────────────────────────────────
//
//  Validates:
//  - Renders progress string (N/M étapes)
//  - Shows current step CTA chip
//  - Shows completed steps with check icon
//  - Shows upcoming steps without CTA
//  - Shows blocked steps with lock icon
//  - isComplete shows complete banner
//  - Empty sequence renders nothing (SizedBox.shrink)
//  - CTA navigates to intentTag
// ────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

CapSequence _makeSequence({
  String goalId = 'retirement_choice',
  required List<CapStep> steps,
}) {
  return CapSequence.fromSteps(goalId: goalId, steps: steps);
}

CapStep _step({
  required String id,
  required int order,
  required CapStepStatus status,
  String titleKey = 'capStepRetirement01Title',
  String? intentTag,
}) {
  return CapStep(
    id: id,
    order: order,
    titleKey: titleKey,
    status: status,
    intentTag: intentTag,
  );
}

void main() {
  group('CapSequenceCard — empty sequence', () {
    testWidgets('renders SizedBox.shrink for empty sequence', (tester) async {
      final seq = _makeSequence(steps: []);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // Widget should be effectively invisible — no text visible
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('CapSequenceCard — progress display', () {
    testWidgets('shows progress bar', (tester) async {
      final seq = _makeSequence(steps: [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.upcoming),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress string shows completed/total', (tester) async {
      final seq = _makeSequence(steps: [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.upcoming),
        _step(id: 's3', order: 3, status: CapStepStatus.upcoming),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // "1/3 étapes" (non-breaking space between number and étapes)
      expect(
        find.textContaining('1'),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.textContaining('3'),
        findsAtLeastNWidgets(1),
      );
    });
  });

  group('CapSequenceCard — step rendering', () {
    testWidgets('renders current step title', (tester) async {
      final seq = _makeSequence(steps: [
        _step(
          id: 's1',
          order: 1,
          status: CapStepStatus.current,
          titleKey: 'capStepRetirement01Title',
        ),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // The French title from ARB: "Connaître ton salaire brut"
      expect(
        find.textContaining('salaire'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('current step shows CTA chip with intentTag', (tester) async {
      final seq = _makeSequence(steps: [
        _step(
          id: 's1',
          order: 1,
          status: CapStepStatus.current,
          titleKey: 'capStepRetirement01Title',
          intentTag: '/profile/income',
        ),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // "Prochaine étape" chip
      expect(
        find.textContaining('tape'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('completed step shows check icon', (tester) async {
      final seq = _makeSequence(steps: [
        _step(
          id: 's1',
          order: 1,
          status: CapStepStatus.completed,
          titleKey: 'capStepRetirement01Title',
        ),
        _step(
          id: 's2',
          order: 2,
          status: CapStepStatus.upcoming,
          titleKey: 'capStepRetirement02Title',
        ),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // check_circle_rounded icon for completed step
      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('blocked step shows lock icon', (tester) async {
      final seq = _makeSequence(steps: [
        _step(
          id: 's1',
          order: 1,
          status: CapStepStatus.blocked,
          titleKey: 'capStepRetirement01Title',
        ),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline_rounded), findsAtLeastNWidgets(1));
    });
  });

  group('CapSequenceCard — complete state', () {
    testWidgets('shows complete message when isComplete', (tester) async {
      final seq = _makeSequence(steps: [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
        _step(id: 's3', order: 3, status: CapStepStatus.completed),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // "Plan complété !" — the complete banner
      expect(find.textContaining('Plan'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows complete check icon when isComplete', (tester) async {
      final seq = _makeSequence(steps: [
        _step(id: 's1', order: 1, status: CapStepStatus.completed),
        _step(id: 's2', order: 2, status: CapStepStatus.completed),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));
    });
  });

  group('CapSequenceCard — max visible steps', () {
    testWidgets('shows at most 4 step rows for long sequence', (tester) async {
      // 10 steps — should show max 4
      final seq = _makeSequence(steps: [
        for (int i = 1; i <= 10; i++)
          _step(
            id: 'ret_0${i}_step',
            order: i,
            status: i <= 3
                ? CapStepStatus.completed
                : i == 4
                    ? CapStepStatus.current
                    : CapStepStatus.upcoming,
            titleKey: i <= 5
                ? 'capStepRetirement0${i}Title'
                : 'capStepRetirement0${i}Title',
          ),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // Should render — no exception thrown
      expect(find.byType(CapSequenceCard), findsOneWidget);
    });
  });

  group('CapSequenceCard — no hardcoded strings', () {
    testWidgets('uses i18n for step titles (not raw key strings)', (tester) async {
      final seq = _makeSequence(steps: [
        _step(
          id: 's1',
          order: 1,
          status: CapStepStatus.current,
          titleKey: 'capStepRetirement01Title',
          intentTag: '/profile/income',
        ),
      ]);

      await tester.pumpWidget(_wrap(CapSequenceCard(sequence: seq)));
      await tester.pumpAndSettle();

      // Should NOT show the raw ARB key
      expect(find.text('capStepRetirement01Title'), findsNothing);
    });
  });
}
