// STAB-19 smoke test (Phase 1 P0a, D-01 verification gate).
//
// Purpose: Prove that MintHomeScreen pumps inside a MultiProvider shell that
// contains the 4 providers historically missing in v2.1 (root cause of
// ProviderNotFoundException at runtime). The 4 providers are:
//   - MintStateProvider
//   - FinancialPlanProvider
//   - CoachEntryPayloadProvider
//   - OnboardingProvider
//
// They are now registered in apps/mobile/lib/app.dart:1010-1013. This test
// guards against future regressions by reconstructing the relevant slice of
// the app shell and asserting no exception is thrown during pump+settle.
//
// See: .planning/phases/01-p0a-code-unblockers/01-CONTEXT.md §D-01

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';

// The 4 providers under STAB-19 verification.
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';

// Other providers MintHomeScreen reads via context.watch / context.read.
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';

import 'package:mint_mobile/screens/main_tabs/mint_home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'STAB-19: MintHomeScreen pumps inside real MultiProvider shell '
    'without ProviderNotFoundException',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            // The 4 STAB-19 providers (focus of the test).
            ChangeNotifierProvider(create: (_) => MintStateProvider()),
            ChangeNotifierProvider(create: (_) => FinancialPlanProvider()),
            ChangeNotifierProvider(create: (_) => CoachEntryPayloadProvider()),
            ChangeNotifierProvider(create: (_) => OnboardingProvider()),
            // Co-providers consumed by MintHomeScreen.
            ChangeNotifierProvider(create: (_) => AnticipationProvider()),
            ChangeNotifierProvider(create: (_) => BiographyProvider()),
            ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
            ChangeNotifierProvider(create: (_) => ContextualCardProvider()),
            ChangeNotifierProvider(create: (_) => UserActivityProvider()),
          ],
          // ignore: prefer_const_constructors
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: const Locale('fr'),
            home: const MintHomeScreen(),
          ),
        ),
      );

      // Allow async provider init + first frame.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // The contract: no ProviderNotFoundException (or any exception)
      // surfaces during construction + first build.
      expect(
        tester.takeException(),
        isNull,
        reason: 'MintHomeScreen must build inside the MultiProvider shell '
            'without throwing. STAB-19 regression guard.',
      );
    },
  );
}
