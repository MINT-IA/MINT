// Wave 1b Plan 05 — golden snapshots (6 tools × default state).
// One golden PNG per Wave 1a tool, rendered in FR locale at a fixed
// padding for visual diff stability. Goldens live under
// apps/mobile/test/goldens/coach_citation_chip_<tool>.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/coach_citation_chips_section.dart';

import '../../golden_screenshots/tolerant_comparator.dart';

void main() {
  // 1.5% pixel-diff tolerance — absorbs macOS↔Linux rendering deltas
  // (font hinting, anti-aliasing). Pattern from repo at
  // test/golden_screenshots/tolerant_comparator.dart.
  goldenFileComparator = TolerantGoldenFileComparator(
    Uri.parse('test/widgets/coach/coach_citation_chip_golden_test.dart'),
  );

  for (final tool in const [
    'budget_snapshot',
    'retirement_projection',
    'cross_pillar_analysis',
    'couple_optimization',
    'cap_status',
    'retrieve_memories',
  ]) {
    testWidgets('golden — chip for $tool', (tester) async {
      final chip = ToolCallCitationChip(
        toolName: tool,
        inputsHash: 'a' * 64,
        computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
        rawResponse: const {'_test': true},
      );
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child:
                CoachCitationChipsSection(chips: [chip], onChipTap: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CoachCitationChipsSection),
        matchesGoldenFile('../../goldens/coach_citation_chip_$tool.png'),
      );
    });
  }
}
