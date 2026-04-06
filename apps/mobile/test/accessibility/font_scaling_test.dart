import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  FONT SCALING 200% OVERFLOW TESTS
//  Phase 06 / QA Profond -- Plan 04, Task 1
// ────────────────────────────────────────────────────────────
//
// Validates:
//   - Key v2.0 widget patterns render without RenderFlex overflow
//     at 200% font scaling (textScaler: TextScaler.linear(2.0))
//   - Verifies responsive layouts adapt to large text
//
// See: QA-08 (WCAG 2.1 AA), T-06-09 (font scaling overflow).
// ────────────────────────────────────────────────────────────

/// Helper to wrap a widget in a MaterialApp with 200% text scaling.
Widget _scaledApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        textScaler: TextScaler.linear(2.0),
        size: Size(375, 812), // iPhone X viewport
      ),
      child: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

/// Helper to wrap a widget in a MaterialApp at 1.0x scaling (baseline).
Widget _normalApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        textScaler: TextScaler.linear(1.0),
        size: Size(375, 812),
      ),
      child: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════
  //  GROUP 1 -- 200% font scaling overflow tests
  // ═══════════════════════════════════════════════════════════

  group('200% font scaling -- no overflow', () {
    // Track overflow errors during each test
    late List<FlutterErrorDetails> overflowErrors;

    setUp(() {
      overflowErrors = [];
    });

    testWidgets('Card-like layout with title + subtitle at 2.0x', (tester) async {
      // Simulates the card pattern used across v2.0 (PremierEclairageCard,
      // HeroStatCard, AnticipationSignalCard)
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflowErrors.add(details);
        }
      };

      await tester.pumpWidget(
        _scaledApp(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(MintSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3 480 CHF/mois',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votre rente AVS estimee basee sur vos cotisations actuelles',
                    style: TextStyle(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Comprendre'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = oldHandler;

      expect(
        overflowErrors,
        isEmpty,
        reason:
            'Card layout should not overflow at 200% text scaling. '
            'Errors: ${overflowErrors.map((e) => e.exception).toList()}',
      );
    });

    testWidgets('Row with icon + text wraps correctly at 2.0x', (tester) async {
      // Simulates AnticipationSignalCard title row pattern
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflowErrors.add(details);
        }
      };

      await tester.pumpWidget(
        _scaledApp(
          child: Padding(
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: 20,
                  color: MintColors.primary,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    'Delai 3a -- Plus que 45 jours pour verser',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = oldHandler;

      expect(
        overflowErrors,
        isEmpty,
        reason:
            'Icon + text row should use Expanded to prevent overflow at 2.0x',
      );
    });

    testWidgets('Button row with two TextButtons at 2.0x', (tester) async {
      // Simulates AnticipationSignalCard dismiss/snooze row
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflowErrors.add(details);
        }
      };

      await tester.pumpWidget(
        _scaledApp(
          child: Padding(
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Plus tard'),
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Flexible(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Compris'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = oldHandler;

      expect(
        overflowErrors,
        isEmpty,
        reason:
            'Two buttons in a row should not overflow at 200% scaling',
      );
    });

    testWidgets('Intent chip grid at 2.0x uses Wrap for flow layout',
        (tester) async {
      // Simulates intent_screen chip selection pattern
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflowErrors.add(details);
        }
      };

      final chips = [
        'Retraite',
        'Premier emploi',
        'Logement',
        'Optimiser mes impots',
        'Famille',
        'Patrimoine',
      ];

      await tester.pumpWidget(
        _scaledApp(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(MintSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qu\'est-ce qui t\'amene ici ?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips
                        .map(
                          (label) => ChoiceChip(
                            label: Text(label),
                            selected: false,
                            onSelected: (_) {},
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = oldHandler;

      expect(
        overflowErrors,
        isEmpty,
        reason:
            'Intent chips in Wrap layout should flow to next line at 2.0x scaling',
      );
    });

    testWidgets('Disclaimer text at 2.0x does not overflow card width',
        (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflowErrors.add(details);
        }
      };

      await tester.pumpWidget(
        _scaledApp(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(MintSpacing.md),
              child: SizedBox(
                width: 343, // Card width within a standard phone
                child: Text(
                  'Outil educatif. Ne constitue pas un conseil financier. '
                  'Les projections sont indicatives et ne garantissent aucun resultat.',
                  style: TextStyle(
                    fontSize: 10,
                    color: MintColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = oldHandler;

      expect(
        overflowErrors,
        isEmpty,
        reason: 'Disclaimer text should wrap at 200% scaling',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 2 -- Baseline comparison (1.0x vs 2.0x)
  // ═══════════════════════════════════════════════════════════

  group('TextScaler baseline comparison', () {
    testWidgets('Text at 2.0x is visually larger than 1.0x', (tester) async {
      // Sanity check: 2.0x scaling actually works in the test environment
      final key1x = UniqueKey();
      final key2x = UniqueKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.0),
                ),
                child: Text('Hello', key: key1x),
              ),
              MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(2.0),
                ),
                child: Text('Hello', key: key2x),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final size1x = tester.getSize(find.byKey(key1x));
      final size2x = tester.getSize(find.byKey(key2x));

      expect(
        size2x.height,
        greaterThan(size1x.height),
        reason: 'Text at 2.0x should be taller than 1.0x',
      );
    });
  });
}
