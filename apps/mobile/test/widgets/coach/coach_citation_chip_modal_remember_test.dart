// Wave 1b Plan 06 — Souviens-toi CTA fires onRememberTap with the chip.
//
// Unskipped from Plan 01 stub. Asserts the modal's Souviens-toi button
// invokes the optional `onRememberTap` callback with the chip and pops the
// sheet. Persistence (save_insight tool wiring) is a Wave 2 follow-up;
// this test guards the UI hook only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/coach_citation_modal.dart';

void main() {
  testWidgets('Souviens-toi CTA fires onRememberTap with the chip',
      (tester) async {
    ToolCallCitationChip? remembered;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showCoachCitationModal(
                ctx,
                ToolCallCitationChip(
                  toolName: 'budget_snapshot',
                  inputsHash: 'b' * 64,
                  computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
                  rawResponse: const {'_test': true},
                ),
                onRememberTap: (c) => remembered = c,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('coachCitationModalRememberCta')),
    );
    await tester.pumpAndSettle();
    expect(remembered, isNotNull);
    expect(remembered!.toolName, 'budget_snapshot');
  });
}
