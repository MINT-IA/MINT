// Phase 8b Plan 02 — Spiekermann microtypographie enforcement for S0–S5.
//
// Four rule groups:
//   1. AESTH-01 — 4pt baseline: every literal integer inside SizedBox
//      (width/height) and EdgeInsets.* on the 6 S0–S5 source files is a
//      multiple of 4. Lines can opt out with `// microtypo:exempt` (used
//      for glyph metrics: blinking cursors, badge dots, etc).
//   2. AESTH-02 — Max 3 distinct heading levels per file. "Heading" =
//      any MintTextStyles.{display*, headline*, title*, brandLogo} call.
//   3. AESTH-03 — Aesop demotion on S4 response card: the file must not
//      reference `MintTextStyles.displayLarge`, `displayMedium`,
//      `displayHero`, or `displaySmall`. The sentence carries the
//      rhythm, not the number.
//   4. AESTH-07 — MUJI 4-line grammar: ResponseCardWidget sheet variant's
//      body Column contains exactly 4 direct `_S4BodySlot` children
//      (verified via a widget pump + Semantics labels `s4-slot-*`).
//
// Reference: D-05 allows a dart-side widget/golden test instead of lint
// plumbing. D-06 mandates the 4 MUJI slots. D-07 governs the MTC slot,
// which is wrapped inside slot 4 (next action) to keep the count at 4.
//
// Scope: the 6 S0–S5 files frozen by Phase 8b D-01.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';

const List<String> _s0s5Files = <String>[
  'lib/screens/landing_screen.dart',
  'lib/screens/onboarding/intent_screen.dart',
  'lib/screens/main_tabs/mint_home_screen.dart',
  'lib/widgets/coach/coach_message_bubble.dart',
  'lib/widgets/coach/response_card_widget.dart',
  'lib/widgets/report/debt_alert_banner.dart',
];

/// Regex that grabs a line only if it names a SizedBox/EdgeInsets spacing
/// constructor. Integers on any other line (animation durations, font sizes,
/// Icon `size:`, maxLines, widths on decorative Containers, border widths)
/// are considered non-spacing and skipped.
final RegExp _spacingLine = RegExp(
  r'(SizedBox\s*\(|EdgeInsets\.(all|only|symmetric|fromLTRB))',
);

/// Integer literals (no decimals) inside a spacing line — these must be
/// multiples of 4. Decimal literals (0.5, 1.5 border widths) are ignored by
/// the `(?!\.)` lookahead.
final RegExp _intLiteral = RegExp(r'(?<![\w.])(\d+)(?!\.\d)');

/// Heading-tier MintTextStyles (fontSize >= 20 OR fontWeight >= w600
/// per MintTextStyles source of truth).
const Set<String> _headingStyles = <String>{
  'displayHero',
  'displayLarge',
  'displayMedium',
  'displaySmall',
  'headlineLarge',
  'headlineMedium',
  'headlineSmall',
  'titleLarge',
  'titleMedium',
  'brandLogo',
};

/// Display-tier styles that must NOT appear in S4 (Aesop demotion).
const Set<String> _aesopForbidden = <String>{
  'displayHero',
  'displayLarge',
  'displayMedium',
  'displaySmall',
};

String _readFile(String relPath) {
  // Tests run from apps/mobile/. Walk up if the cwd drifts.
  final candidates = <String>[
    relPath,
    'apps/mobile/$relPath',
  ];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Source file not found: $relPath (cwd=${Directory.current.path})');
}

void main() {
  group('AESTH-01 · 4pt baseline grid on S0–S5 spacing', () {
    for (final path in _s0s5Files) {
      test(path, () {
        final source = _readFile(path);
        final offenders = <String>[];
        final lines = source.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!_spacingLine.hasMatch(line)) continue;
          if (line.contains('microtypo:exempt')) continue;
          // Strip string literals so integers inside 'foo42bar' don't leak.
          final stripped = line.replaceAll(RegExp(r"'[^']*'"), "''");
          for (final m in _intLiteral.allMatches(stripped)) {
            final n = int.parse(m.group(1)!);
            if (n == 0) continue;
            if (n % 4 != 0) {
              offenders.add('  L${i + 1}: $n → ${line.trim()}');
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'Non-4pt spacing literals in $path:\n${offenders.join('\n')}',
        );
      });
    }
  });

  group('AESTH-02 · Max 3 heading-tier styles per S0–S5 surface', () {
    for (final path in _s0s5Files) {
      test(path, () {
        final source = _readFile(path);
        final found = <String>{};
        final re = RegExp(r'MintTextStyles\.(\w+)');
        for (final m in re.allMatches(source)) {
          final name = m.group(1)!;
          if (_headingStyles.contains(name)) found.add(name);
        }
        expect(
          found.length,
          lessThanOrEqualTo(3),
          reason:
              'More than 3 heading-tier styles in $path: ${found.toList()..sort()}',
        );
      });
    }
  });

  group('AESTH-03 · Aesop number demotion on S4 response card', () {
    test('response_card_widget.dart has no display-tier headline numbers',
        () {
      final source =
          _readFile('lib/widgets/coach/response_card_widget.dart');
      for (final forbidden in _aesopForbidden) {
        expect(
          source.contains('MintTextStyles.$forbidden'),
          isFalse,
          reason:
              'S4 (response_card_widget.dart) must not shout numbers via '
              'MintTextStyles.$forbidden — the sentence carries the rhythm '
              '(AESTH-03 / feedback_anti_shame_situated_learning).',
        );
      }
    });
  });

  group('AESTH-07 · MUJI 4-line grammar on S4 sheet body', () {
    testWidgets('ResponseCardWidget.sheet body renders exactly 4 MUJI slots',
        (tester) async {
      final card = ResponseCard(
        id: 'test-muji',
        type: ResponseCardType.pillar3a,
        title: 'Pilier 3a',
        subtitle: 'Versement annuel maximal',
        premierEclairage: const PremierEclairage(
          value: 7258,
          unit: 'CHF',
          explanation: 'Plafond legal salarie LPP',
        ),
        cta: const CardCta(
          label: 'Simuler un versement',
          route: '/pilier-3a',
        ),
        urgency: CardUrgency.low,
        disclaimer: 'Outil educatif.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponseCardWidget(card: card),
          ),
        ),
      );
      await tester.pump();

      final slots = find.bySemanticsLabel(RegExp(r'^s4-slot-[1-4]$'));
      expect(
        slots,
        findsNWidgets(4),
        reason: 's4 sheet body must render exactly 4 MUJI slots (D-06)',
      );
    });
  });
}
