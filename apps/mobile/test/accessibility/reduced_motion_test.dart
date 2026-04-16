// ACCESS-07 (P8b-03): reduced-motion fallback for the 3 motion sites.
//
// Sites covered:
//   1. MintTrameConfiance bloom (D-08, validated in pre-existing MTC tests)
//   2. BlinkingCursor — coach typing/streaming indicator
//   3. MintEntrance — onboarding (and global hero) entrance animation
//
// In each case, when MediaQuery.disableAnimations is true, no animation
// controller should be left running after a single short pump.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

Widget _withReducedMotion(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Material(child: child),
    ),
  );
}

void main() {
  testWidgets('BlinkingCursor: no running animation under reduced-motion',
      (tester) async {
    await tester.pumpWidget(_withReducedMotion(
      const SizedBox(width: 8, height: 14, child: BlinkingCursor()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse,
        reason: 'Streaming cursor must collapse to a static glyph.');
  });

  testWidgets('MintEntrance: skips fade+slide wrapper under reduced-motion',
      (tester) async {
    await tester.pumpWidget(_withReducedMotion(
      const MintEntrance(child: Text('hello')),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    // Under reduced-motion, MintEntrance.build returns the child directly:
    // no Opacity, no Transform.translate ancestor between MintEntrance and
    // the child Text.
    expect(find.text('hello'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MintEntrance),
        matching: find.byType(Opacity),
      ),
      findsNothing,
      reason: 'MintEntrance must not wrap its child in Opacity under reduced-motion.',
    );
    expect(
      find.descendant(
        of: find.byType(MintEntrance),
        matching: find.byType(Transform),
      ),
      findsNothing,
      reason: 'MintEntrance must not wrap its child in Transform.translate under reduced-motion.',
    );
  });

  testWidgets('MintTrameConfiance bloom: settles within 50ms under reduced-motion',
      (tester) async {
    final confidence = EnhancedConfidence(
      completeness: 75,
      accuracy: 80,
      freshness: 70,
      understanding: 72,
      combined: 74,
      level: 'high',
      baseResult: const ProjectionConfidence(
        score: 75,
        level: 'high',
        prompts: [],
        assumptions: [],
      ),
    );
    await tester.pumpWidget(_withReducedMotion(
      MintTrameConfiance.inline(
        confidence: confidence,
        bloomStrategy: BloomStrategy.firstAppearance,
      ),
    ));
    // Per D-05: reduced-motion fallback is 50ms opacity-only linear.
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.hasRunningAnimations, isFalse,
        reason: 'MTC bloom must settle to final state within 50ms fallback.');
  });
}
