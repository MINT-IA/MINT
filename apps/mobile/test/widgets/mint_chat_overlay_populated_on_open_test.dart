// Phase 97.5 W2-T4 — populated MintChatOverlay regression lock.
//
// Asserts the Option A path locked by the W1-T1 opener-pattern ADR
// (.planning/decisions/2026-05-12-p004-opener-pattern.md) :
//
//   1. The overlay body is NON-EMPTY on open — NarrativeSleeveCard
//      visible within one settle cycle. Closes the SCOUT D1 « tests
//      pass != feature works » trap surfaced 2026-05-12.
//   2. Happy path : user's computed_fact value appears in the hook
//      (Swiss thousands separator, e.g. « 7'056 »).
//   3. HOOK_FALLBACK : when computed_facts has no numeric entry, the
//      hook degrades gracefully to the verbatim fallback string
//      (mirrors backend narrative_sleeve_lint.HOOK_FALLBACK).
//   4. Header label : « Explique-moi » in FR locale (W2-T3 D2 fix).
//   5. Turn counter : « 0 / 3 » on opener (free-turn semantics — the
//      counter only increments on USER input).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/services/metaphor_lookup.dart';
import 'package:mint_mobile/widgets/mint_chat_overlay.dart';

Widget _harness({required Widget child}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(body: child),
  );
}

const _swissNativeVdHousing = SerializedCardContext(
  cardId: 'mon_3a_2026',
  cardType: 'pillar_3a',
  computedFacts: <String, dynamic>{'plafond_3a': 7056},
  groundingKeys: ['plafond_3a_2026'],
  lifeEvent: 'housing',
  canton: 'VD',
  archetype: 'swiss_native',
);

const _emptyFactsCard = SerializedCardContext(
  cardId: 'tax_optimization',
  cardType: 'tax_optimization',
  // No computed_facts entry — the hook must degrade to HOOK_FALLBACK.
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MintChatOverlay — Phase 97.5 W2-T4 populated-on-open lock', () {
    setUpAll(() {
      // Seed the metaphor resolver so the metaphor slot can render
      // for the known triplet (swiss_native.VD.housing).
      MetaphorLookup.debugSetLoaded(<String, dynamic>{
        'swiss_native': {
          'VD': {
            'housing': {
              'metaphor':
                  "À Lausanne, acheter, c'est planter un arbre — il faut des "
                  "années avant qu'il porte ombre, mais une fois enraciné, il tient.",
            },
          },
        },
      });
    });

    tearDownAll(() {
      MetaphorLookup.debugSetLoaded(null);
    });

    testWidgets('Happy path — NarrativeSleeveCard renders with user numbers',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _swissNativeVdHousing,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      // SC-1 — body is non-empty : the sleeve card is in the tree.
      expect(
        find.byKey(const Key('narrative_sleeve_card')),
        findsOneWidget,
        reason:
            'Option A opener must paint the NarrativeSleeveCard in the body '
            'on first frame. Empty body = the exact SCOUT D1 P004 regression.',
      );

      // 4 slots present.
      expect(find.byKey(const Key('narrative_sleeve_hook')), findsOneWidget);
      expect(find.byKey(const Key('narrative_sleeve_caption')), findsOneWidget);
      expect(find.byKey(const Key('narrative_sleeve_next_step')), findsOneWidget);
      // Metaphor block only renders when the lookup is non-empty.
      expect(
        find.byKey(const Key('narrative_sleeve_metaphor')),
        findsOneWidget,
        reason: 'Known triplet swiss_native.VD.housing must resolve.',
      );

      // Hook carries the Swiss-formatted plafond value (7056 → 7'056).
      expect(
        find.textContaining("7'056"),
        findsOneWidget,
        reason:
            "Hook must interpolate the user's computed_fact with the Swiss "
            "thousands separator (7056 → 7'056).",
      );
    });

    testWidgets('HOOK_FALLBACK — empty computed_facts degrades gracefully',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _emptyFactsCard,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('narrative_sleeve_card')), findsOneWidget,
          reason: 'HOOK_FALLBACK path still renders the card.');

      // The verbatim FR HOOK_FALLBACK string mirrors backend
      // narrative_sleeve_lint.HOOK_FALLBACK.
      expect(
        find.text('Voyons ensemble ce que ça change pour toi.'),
        findsOneWidget,
        reason:
            'Hook must degrade to the verbatim HOOK_FALLBACK string when no '
            'numeric computed_fact is available.',
      );

      // Metaphor block is HIDDEN on this card (no canton / no archetype
      // / no life_event) — NarrativeSleeveCard conditional render.
      expect(find.byKey(const Key('narrative_sleeve_metaphor')), findsNothing,
          reason: 'Metaphor block must hide on empty lookup.');
    });

    testWidgets('W2-T3 D2 — header shows FR label, not raw enum',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _swissNativeVdHousing,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      final headerText = tester.widget<Text>(
        find.byKey(const Key('chat_overlay_intent_label')),
      );
      expect(headerText.data, 'Explique-moi',
          reason: 'D2 — must be the localised FR label, never « explain ».');
    });

    testWidgets('W2-T3 D2 — reassure intent maps to « Rassure-moi »',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _swissNativeVdHousing,
          intent: 'reassure',
        ),
      ));
      await tester.pumpAndSettle();

      final headerText = tester.widget<Text>(
        find.byKey(const Key('chat_overlay_intent_label')),
      );
      expect(headerText.data, 'Rassure-moi');
    });

    testWidgets('Free-turn semantics — opener does NOT count against cap',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: const MintChatOverlay(
          sourceCard: _swissNativeVdHousing,
          intent: 'explain',
        ),
      ));
      await tester.pumpAndSettle();

      final counter = tester.widget<Text>(
        find.byKey(const Key('chat_turn_counter')),
      );
      expect(counter.data, '0 / 3',
          reason:
              'Opener is a FREE turn per W1-T1 ADR (Option A). The counter '
              'tracks USER-initiated turns only ; it MUST read « 0 / 3 » '
              'before the user types.');
    });
  });
}
