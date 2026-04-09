// ────────────────────────────────────────────────────────────
//  Phase 12 / Plan 12-02 — WCAG 2.1 AA all-touched-surfaces gate
//  D-04: floor gate (4.5:1 normal / 3:1 large + 44pt tap targets)
//  on every v2.2-touched UI surface category.
// ────────────────────────────────────────────────────────────
//
// This test complements (does NOT replace) the strict S0–S5 AAA gate at
// `apps/mobile/test/theme/aaa_tokens_contrast_test.dart`. Here we exercise
// Flutter's built-in `meetsGuideline` matchers against representative
// scaffolds for each major v2.2 UI surface category:
//
//   S0  Landing             — title + body + CTA on craie
//   S1  Intent screen       — chip row + CTA
//   S2  Aujourd'hui home    — primary text + secondary text
//   S3  Coach bubble        — coach text on coachBubble surface
//   S4  Response card       — title + body + tap targets
//   S5  Debt alert banner   — alert text on warning surface
//   X1  Ton chooser         — segmented control (Phase 12-01)
//   X2  Profile drawer      — list rows + dividers
//   X3  Generic alert       — neutral toast
//
// Each surface is harnessed as a minimal MaterialApp scaffold using the
// SAME MintColors tokens the production widgets consume. We do NOT import
// production screens (parallel-safety: Plan 12-02 must not touch lib/).
// If a real surface drifts away from the AA floor, the corresponding
// MintColors token pair flips here as well.
//
// Each test asserts:
//   1. textContrastGuideline   (WCAG AA: 4.5:1 normal, 3:1 large)
//   2. androidTapTargetGuideline (48dp)
//   3. iOSTapTargetGuideline    (44pt)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Builds a minimal MaterialApp wrapper at a stable phone viewport so
/// `meetsGuideline` evaluates against deterministic geometry.
Widget _harness({required Widget body, Color? background}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(
        backgroundColor: background ?? MintColors.craie,
        body: SafeArea(child: body),
      ),
    ),
  );
}

Future<void> _expectAllGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
}

void main() {
  group('WCAG 2.1 AA — all touched v2.2 surfaces', () {
    testWidgets('S0 Landing — title + body + CTA on craie', (tester) async {
      await tester.pumpWidget(
        _harness(
          background: MintColors.craie,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mint te dit ce que personne n\'a interet a te dire.',
                  style: TextStyle(
                    color: MintColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Une intelligence calme et fiable, dans ta poche.',
                  style: TextStyle(
                    color: MintColors.textSecondaryAaa,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.accent,
                    foregroundColor: MintColors.white,
                    minimumSize: const Size(220, 48),
                  ),
                  onPressed: () {},
                  child: const Text('Je veux commencer'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('S1 Intent screen — chip row + CTA', (tester) async {
      await tester.pumpWidget(
        _harness(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pourquoi tu es la?',
                  style: TextStyle(
                    color: MintColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final label in const [
                      'Comprendre ma situation',
                      'Eviter une mauvaise surprise',
                      'Preparer une decision',
                    ])
                      ActionChip(
                        label: Text(label),
                        labelStyle: TextStyle(color: MintColors.textPrimary),
                        backgroundColor: MintColors.white,
                        onPressed: () {},
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.accent,
                    foregroundColor: MintColors.white,
                    minimumSize: const Size(220, 48),
                  ),
                  onPressed: () {},
                  child: const Text('Continuer'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('S2 Aujourd\'hui — primary + secondary text', (tester) async {
      await tester.pumpWidget(
        _harness(
          background: MintColors.white,
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Aujourd\'hui',
                style: TextStyle(
                  color: MintColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Trois choses te concernent en ce moment.',
                style:
                    TextStyle(color: MintColors.textSecondaryAaa, fontSize: 15),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < 3; i++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Carte $i',
                    style: TextStyle(color: MintColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Detail discret pour la carte $i',
                    style: TextStyle(color: MintColors.textSecondaryAaa),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: MintColors.textPrimary),
                    onPressed: () {},
                  ),
                ),
                const Divider(),
              ],
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('S3 Coach bubble — text on coachBubble surface',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          background: MintColors.coachBubble,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MintColors.coachBubble,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Voici ce que ton 2e pilier implique pour toi.',
                style: TextStyle(
                  color: MintColors.textPrimary,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('S4 Response card — title + body + tap target', (tester) async {
      await tester.pumpWidget(
        _harness(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: MintColors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ce qu\'on a appris',
                      style: TextStyle(
                        color: MintColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trois implications discretes pour ta situation.',
                      style: TextStyle(
                        color: MintColors.textSecondaryAaa,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'En savoir plus',
                        style: TextStyle(color: MintColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('S5 Debt alert — alert text on warning surface',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MintColors.white,
                border: Border.all(color: MintColors.errorAaa, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: MintColors.errorAaa),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Une dette a forte charge demande attention.',
                      style: TextStyle(
                        color: MintColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('X1 Ton chooser — segmented control (Phase 12-01 surface)',
        (tester) async {
      int selected = 1; // direct = default
      await tester.pumpWidget(
        _harness(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    for (final entry in const [
                      MapEntry(0, 'Doux'),
                      MapEntry(1, 'Direct'),
                      MapEntry(2, 'Cru'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: selected == entry.key
                                    ? MintColors.accent
                                    : MintColors.white,
                                foregroundColor: selected == entry.key
                                    ? MintColors.white
                                    : MintColors.textPrimary,
                              ),
                              onPressed: () =>
                                  setState(() => selected = entry.key),
                              child: Text(entry.value),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('X2 Profile drawer — list rows + dividers', (tester) async {
      await tester.pumpWidget(
        _harness(
          background: MintColors.white,
          body: ListView(
            children: [
              for (final label in const [
                'Voix',
                'Langue',
                'Confidentialite',
                'A propos',
              ]) ...[
                ListTile(
                  title: Text(
                    label,
                    style: TextStyle(color: MintColors.textPrimary),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      color: MintColors.textSecondaryAaa),
                  onTap: () {},
                ),
                Divider(color: MintColors.textSecondaryAaa.withOpacity(0.2)),
              ],
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });

    testWidgets('X3 Generic neutral alert toast', (tester) async {
      await tester.pumpWidget(
        _harness(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: MintColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Ton non enregistre — on reessaiera.',
                style: TextStyle(color: MintColors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expectAllGuidelines(tester);
    });
  });
}
