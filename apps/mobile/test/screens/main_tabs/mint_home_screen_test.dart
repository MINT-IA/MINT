// ignore_for_file: lines_longer_than_80_chars, prefer_const_constructors

/// MintHomeScreen — Section 0 show/hide tests (D-04, D-05).
///
/// Tests verify the _shouldShowPremierEclairage logic by injecting
/// SharedPreferences state and checking whether PremierEclairageCard appears.
///
/// MintStateProvider is pre-loaded with injectStateForTest so the spinner
/// is bypassed and the actual home body renders immediately.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart'
    show
        CoachProfile,
        FinancialArchetype,
        GoalA,
        GoalAType;
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/main_tabs/mint_home_screen.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/widgets/onboarding/premier_eclairage_card.dart';

// ─── SharedPreferences keys (must match ReportPersistenceService) ────────────

const _hasSeen = 'has_seen_premier_eclairage_v1';
const _intentKey = 'selected_onboarding_intent_v1';
const _snapshotKey = 'premier_eclairage_snapshot_v1';

const _sampleSnapshot = {
  'value': "7'258 CHF",
  'title': 'Test title',
  'subtitle': 'Test subtitle',
  'suggestedRoute': '/pilier-3a',
  'colorKey': 'success',
  'confidenceMode': 'real',
};

// ─── Minimal MintUserState for tests ─────────────────────────────────────────

GoalA _testGoalA() => GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2055, 12, 31),
  label: 'Retraite',
);

MintUserState _minimalState() => MintUserState(
      profile: CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 0,
        goalA: _testGoalA(),
      ),
      lifecyclePhase: LifecyclePhase.demarrage,
      archetype: FinancialArchetype.swissNative,
      confidenceScore: 30,
      capMemory: const CapMemory(),
      computedAt: DateTime(2026, 1, 1),
    );

// ─── Test builder ────────────────────────────────────────────────────────────

Widget buildTestWidget({
  bool hasSeen = false,
  String? selectedIntent = 'intentChip3a',
  Set<String> exploredSimulators = const {},
  Map<String, dynamic>? snapshot = _sampleSnapshot,
}) {
  final prefs = <String, Object>{
    _hasSeen: hasSeen,
    if (selectedIntent != null) _intentKey: selectedIntent,
    if (snapshot != null) _snapshotKey: jsonEncode(snapshot),
  };
  SharedPreferences.setMockInitialValues(prefs);

  final activityProvider = UserActivityProvider();
  for (final id in exploredSimulators) {
    activityProvider.markSimulatorExplored(id);
  }

  // Pre-inject state so home screen renders body (not spinner)
  final mintStateProvider = MintStateProvider()
    ..injectStateForTest(_minimalState());

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MintStateProvider>.value(
        value: mintStateProvider,
      ),
      ChangeNotifierProvider<UserActivityProvider>.value(
        value: activityProvider,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr')],
      locale: const Locale('fr'),
      home: const MintHomeScreen(),
    ),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('MintHomeScreen — PremierEclairageCard show/hide (D-04, D-05)', () {
    testWidgets(
        'card IS shown when hasSeen=false AND intent non-null AND no explored simulators',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        hasSeen: false,
        selectedIntent: 'intentChip3a',
        exploredSimulators: {},
      ));
      // Pump to allow async initState (SharedPreferences load) to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PremierEclairageCard), findsOneWidget);
    });

    testWidgets('card is NOT shown when hasSeen=true', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        hasSeen: true,
        selectedIntent: 'intentChip3a',
        exploredSimulators: {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PremierEclairageCard), findsNothing);
    });

    testWidgets(
        'card is NOT shown when exploredSimulators is non-empty (D-04 auto-dismiss)',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        hasSeen: false,
        selectedIntent: 'intentChip3a',
        exploredSimulators: {'pilier3a-simulator'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PremierEclairageCard), findsNothing);
    });

    testWidgets('card is NOT shown when selectedIntent is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        hasSeen: false,
        selectedIntent: null,
        exploredSimulators: {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PremierEclairageCard), findsNothing);
    });

    testWidgets(
        'card disappears after dismiss (markPremierEclairageSeen called)',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        hasSeen: false,
        selectedIntent: 'intentChip3a',
        exploredSimulators: {},
        snapshot: _sampleSnapshot,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Card is shown
      expect(find.byType(PremierEclairageCard), findsOneWidget);

      // Tap dismiss — PremierEclairageCard renders Close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Card gone
      expect(find.byType(PremierEclairageCard), findsNothing);
    });
  });
}
