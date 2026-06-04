// Phase 96 D-06 — MintCardActionBar verb routing tests.
//
// Validates the dispatch contract: which verb fires which callback,
// what payload (sourceCard + intent) flows through. The actual overlay
// open + GoRouter push live behind a thin host wrapper that records
// the dispatch — this isolates the routing contract from GoRouter's
// internal types, which are not trivially constructible in widget tests.
//
// Routing contract (D-06):
//   « Explique-moi » → MintChatOverlay open with intent='explain'
//   « Simule »      → context.push('/explore?simulate=<card_id>') (no LLM)
//   « Rassure-moi » → MintChatOverlay open with intent='reassure'

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';

const _fixture = SerializedCardContext(
  cardId: 'mon_3a_2026',
  cardType: 'pillar_3a',
);

class _DispatchRecord {
  String? lastIntent;
  String? lastSimulateDeepLink;
}

/// Test host wrapper — mirrors the wiring pattern that card screens use
/// (see Task 4 §3 in 96-01-PLAN.md). Records the dispatch so the test
/// can assert the contract without touching GoRouter or the overlay
/// builder. This is the production wiring shape; the only difference
/// is the recorder vs. real `MintChatOverlay.show` / `context.push`.
class _CardHost extends StatefulWidget {
  final _DispatchRecord record;
  const _CardHost({required this.record});

  @override
  State<_CardHost> createState() => _CardHostState();
}

class _CardHostState extends State<_CardHost> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return MintCardActionBar(
      sourceCard: _fixture,
      expanded: _expanded,
      onExplain: () => widget.record.lastIntent = 'explain',
      onSimulate: () => widget.record.lastSimulateDeepLink =
          '/explore?simulate=${_fixture.cardId}',
      onReassure: () => widget.record.lastIntent = 'reassure',
    );
  }

  void toggle() => setState(() => _expanded = !_expanded);
}

Widget _harness(_DispatchRecord record) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(body: _CardHost(record: record)),
  );
}

void main() {
  group('MintCardActionBar routing contract', () {
    testWidgets('« Explique-moi » dispatches intent=explain', (tester) async {
      final record = _DispatchRecord();
      await tester.pumpWidget(_harness(record));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explique-moi'));
      await tester.pumpAndSettle();

      expect(record.lastIntent, 'explain');
      expect(record.lastSimulateDeepLink, isNull);
    });

    testWidgets('« Rassure-moi » dispatches intent=reassure', (tester) async {
      final record = _DispatchRecord();
      await tester.pumpWidget(_harness(record));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rassure-moi'));
      await tester.pumpAndSettle();

      expect(record.lastIntent, 'reassure');
      expect(record.lastSimulateDeepLink, isNull);
    });

    testWidgets(
      '« Simule » dispatches /explore?simulate=<card_id> '
      '(zero LLM call per D-06)',
      (tester) async {
        final record = _DispatchRecord();
        await tester.pumpWidget(_harness(record));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simule'));
        await tester.pumpAndSettle();

        expect(
          record.lastSimulateDeepLink,
          '/explore?simulate=mon_3a_2026',
        );
        // Critical: Simule must NEVER dispatch an overlay intent — it's
        // the LLM-free path.
        expect(record.lastIntent, isNull);
      },
    );

    testWidgets('expanded toggles between false (height 0) and true (>=48)',
        (tester) async {
      final record = _DispatchRecord();
      await tester.pumpWidget(_harness(record));
      await tester.pumpAndSettle();

      // Starts expanded=true per fixture default.
      final initialSize = tester.getSize(find.byType(MintCardActionBar));
      expect(initialSize.height, greaterThanOrEqualTo(48.0));

      // Toggle off → height collapses to ~0.
      final state =
          tester.state<_CardHostState>(find.byType(_CardHost));
      state.toggle();
      await tester.pumpAndSettle();

      final collapsedSize = tester.getSize(find.byType(MintCardActionBar));
      expect(collapsedSize.height, lessThan(1.0));
    });
  });
}
