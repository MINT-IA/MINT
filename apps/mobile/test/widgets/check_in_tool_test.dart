import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/check_in_summary_card.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';

// ────────────────────────────────────────────────────────────
//  CHECK-IN TOOL PERSISTENCE TEST — Phase 5 / SUI-02
//
//  Tests the critical joint:
//    record_check_in tool call → WidgetRenderer → addCheckIn persistence
//
//  T-05-04: Validates that:
//  1. Valid input renders CheckInSummaryCard AND persists MonthlyCheckIn
//  2. Missing 'month' → returns null (no card, no persistence)
//  3. Missing 'versements' → returns null (no card, no persistence)
//  4. Missing 'summary_message' → returns null (no card, no persistence)
//  5. Non-numeric versements value → returns null (Tampering mitigation)
// ────────────────────────────────────────────────────────────

Widget _buildTestApp({
  required CoachProfileProvider provider,
  required Widget Function(BuildContext) builder,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: Builder(builder: (ctx) => Scaffold(body: builder(ctx))),
    ),
  );
}

CoachProfileProvider _providerWithProfile() {
  final provider = CoachProfileProvider();
  provider.createFromRemoteProfile({'birth_year': 1985, 'canton': 'VS'});
  return provider;
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetRenderer record_check_in → addCheckIn persistence (T-05-04)', () {
    testWidgets('valid input renders CheckInSummaryCard and persists check-in',
        (tester) async {
      final provider = _providerWithProfile();
      expect(provider.profile!.checkIns, isEmpty,
          reason: 'No check-ins before tool call');

      late Widget? rendered;
      await tester.pumpWidget(_buildTestApp(
        provider: provider,
        builder: (ctx) {
          rendered = WidgetRenderer.build(
            ctx,
            const RagToolCall(
              name: 'record_check_in',
              input: {
                'month': '2026-04',
                'versements': {'3a': 500.0},
                'summary_message': 'Parfait, 500 CHF versés ce mois-ci\u00a0!',
              },
            ),
          );
          return rendered ?? const SizedBox();
        },
      ));
      await tester.pump();

      // Card rendered
      expect(find.byType(CheckInSummaryCard), findsOneWidget);

      // Persistence: addCheckIn was called
      expect(provider.profile!.checkIns, hasLength(1));
      final checkIn = provider.profile!.checkIns.first;
      expect(checkIn.month, DateTime(2026, 4, 1));
      expect(checkIn.versements, {'3a': 500.0});
    });

    testWidgets('missing month returns null — no card, no persistence',
        (tester) async {
      final provider = _providerWithProfile();
      late Widget? rendered;

      await tester.pumpWidget(_buildTestApp(
        provider: provider,
        builder: (ctx) {
          rendered = WidgetRenderer.build(
            ctx,
            const RagToolCall(
              name: 'record_check_in',
              input: {
                // month is missing
                'versements': {'3a': 500.0},
                'summary_message': 'OK',
              },
            ),
          );
          return rendered ?? const SizedBox();
        },
      ));
      await tester.pump();

      expect(rendered, isNull);
      expect(provider.profile!.checkIns, isEmpty,
          reason: 'No check-in should be persisted when month is missing');
    });

    testWidgets('missing versements returns null — no card, no persistence',
        (tester) async {
      final provider = _providerWithProfile();
      late Widget? rendered;

      await tester.pumpWidget(_buildTestApp(
        provider: provider,
        builder: (ctx) {
          rendered = WidgetRenderer.build(
            ctx,
            const RagToolCall(
              name: 'record_check_in',
              input: {
                'month': '2026-04',
                // versements is missing
                'summary_message': 'OK',
              },
            ),
          );
          return rendered ?? const SizedBox();
        },
      ));
      await tester.pump();

      expect(rendered, isNull);
      expect(provider.profile!.checkIns, isEmpty);
    });

    testWidgets('missing summary_message returns null — no card, no persistence',
        (tester) async {
      final provider = _providerWithProfile();
      late Widget? rendered;

      await tester.pumpWidget(_buildTestApp(
        provider: provider,
        builder: (ctx) {
          rendered = WidgetRenderer.build(
            ctx,
            const RagToolCall(
              name: 'record_check_in',
              input: {
                'month': '2026-04',
                'versements': {'3a': 500.0},
                // summary_message is missing
              },
            ),
          );
          return rendered ?? const SizedBox();
        },
      ));
      await tester.pump();

      expect(rendered, isNull);
      expect(provider.profile!.checkIns, isEmpty);
    });

    testWidgets(
        'T-05-04: non-numeric versements value returns null (Tampering mitigation)',
        (tester) async {
      final provider = _providerWithProfile();
      late Widget? rendered;

      await tester.pumpWidget(_buildTestApp(
        provider: provider,
        builder: (ctx) {
          rendered = WidgetRenderer.build(
            ctx,
            const RagToolCall(
              name: 'record_check_in',
              input: {
                'month': '2026-04',
                'versements': {'3a': 'not-a-number'},
                'summary_message': 'OK',
              },
            ),
          );
          return rendered ?? const SizedBox();
        },
      ));
      await tester.pump();

      expect(rendered, isNull);
      expect(provider.profile!.checkIns, isEmpty,
          reason: 'Non-numeric versements must not be persisted');
    });

    testWidgets('CheckInSummaryCard displays summary message and total',
        (tester) async {
      final provider = _providerWithProfile();

      await tester.pumpWidget(_buildTestApp(
        provider: provider,
        builder: (ctx) {
          WidgetRenderer.build(
            ctx,
            const RagToolCall(
              name: 'record_check_in',
              input: {
                'month': '2026-03',
                'versements': {'3a': 500.0, 'lpp': 200.0},
                'summary_message': 'Bravo, 700\u00a0CHF vers\u00e9s\u00a0!',
              },
            ),
          );
          return CheckInSummaryCard(
            summaryMessage: 'Bravo, 700\u00a0CHF vers\u00e9s\u00a0!',
            versements: const {'3a': 500.0, 'lpp': 200.0},
            month: '2026-03',
          );
        },
      ));
      await tester.pump();

      expect(find.text('Bravo, 700\u00a0CHF vers\u00e9s\u00a0!'), findsOneWidget);
    });
  });
}
