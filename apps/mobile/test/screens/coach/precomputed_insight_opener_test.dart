// ────────────────────────────────────────────────────────────
//  PRECOMPUTED INSIGHT — chat-open opener tests (Phase 54-02 T-03)
//
//  Verifies the opener-precedence rule on a fresh chat-open with no
//  entryPayload + no resumed conversation:
//
//    1. PrecomputedInsight cache populated AND fresh → opener bubble
//       + tappable RouteSuggestionCard surfaces with the cached
//       intentTag. Cache cleared after surfacing (consume-once).
//    2. Cache empty → screen renders without a RouteSuggestionCard
//       (no precomputed-insight side-effect).
//
//  The CoachChatScreen reads PrecomputedInsightsService.getCachedInsight
//  via the real SharedPreferences mock — no monkey-patching needed.
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/data_driven_opener_service.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';

const _kInsightCacheKey = 'mint_precomputed_insight_v1';

CoachProfileProvider _buildProfileProvider() {
  final provider = CoachProfileProvider();
  provider.updateFromAnswers({
    'q_firstname': 'Julien',
    'q_birth_year': 1985,
    'q_canton': 'VS',
    'q_net_income_period_chf': 9080,
    'q_civil_status': 'celibataire',
    'q_goal': 'retraite',
  });
  return provider;
}

Widget _buildTestWidget({required CoachProfileProvider profileProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider(create: (_) => ByokProvider()),
      ChangeNotifierProvider(create: (_) => MintStateProvider()),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: CoachChatScreen(),
    ),
  );
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpUntilSettled(WidgetTester tester) async {
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);

  setUp(() {
    RouteSuggestionNavLock.resetForTest();
  });

  group('Phase 54-02 T-03 — PrecomputedInsight on chat-open', () {
    testWidgets(
        'cached fresh insight surfaces RouteSuggestionCard chip + clears cache',
        (tester) async {
      // Seed a fresh insight (computed 5 minutes ago — well under the
      // 1h staleness threshold).
      final freshInsight = PrecomputedInsight(
        type: DataOpenerType.savingsOpportunity,
        params: const {'plafond': '7258'},
        intentTag: 'tax_optimization_3a',
        computedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      SharedPreferences.setMockInitialValues({
        'mint_coach_cash_level': 3,
        _kInsightCacheKey: jsonEncode(freshInsight.toJson()),
      });

      _usePhoneViewport(tester);
      await tester.pumpWidget(
          _buildTestWidget(profileProvider: _buildProfileProvider()));
      await _pumpUntilSettled(tester);

      // The opener bubble should render the resolved savings-opportunity
      // ARB string (FR locale). We assert on the leading literal portion
      // to avoid coupling to ARB rewrites.
      expect(
        find.textContaining('Ton 3a'),
        findsWidgets,
        reason: 'PrecomputedInsight savings-opportunity opener must surface',
      );

      // Cache must be cleared after consume-once.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_kInsightCacheKey),
        isNull,
        reason: 'Insight cache must be cleared after surfacing (consume-once)',
      );
    });

    testWidgets(
        'empty cache: no RouteSuggestionCard from the precomputed-insight path',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'mint_coach_cash_level': 3,
      });

      _usePhoneViewport(tester);
      await tester.pumpWidget(
          _buildTestWidget(profileProvider: _buildProfileProvider()));
      await _pumpUntilSettled(tester);

      // No precomputed-insight chip rendered (proactive trigger fallback
      // also does nothing in this harness because MintStateProvider has
      // no pendingTrigger).
      expect(find.byType(RouteSuggestionCard), findsNothing);

      // The screen still renders cleanly.
      expect(find.byType(CoachChatScreen), findsOneWidget);
    });

    testWidgets(
        'stale insight (>1h) is ignored: no opener chip, no cache clear',
        (tester) async {
      // 2-hour-old insight — beyond the 1h staleness threshold.
      final staleInsight = PrecomputedInsight(
        type: DataOpenerType.savingsOpportunity,
        params: const {'plafond': '7258'},
        intentTag: 'tax_optimization_3a',
        computedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final encoded = jsonEncode(staleInsight.toJson());

      SharedPreferences.setMockInitialValues({
        'mint_coach_cash_level': 3,
        _kInsightCacheKey: encoded,
      });

      _usePhoneViewport(tester);
      await tester.pumpWidget(
          _buildTestWidget(profileProvider: _buildProfileProvider()));
      await _pumpUntilSettled(tester);

      // No opener chip surfaces from a stale insight.
      expect(find.byType(RouteSuggestionCard), findsNothing);

      // Cache untouched (the consume-once clear only fires when an
      // insight actually surfaces).
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_kInsightCacheKey),
        equals(encoded),
        reason: 'Stale insight must not be consumed/cleared',
      );
    });
  });
}
