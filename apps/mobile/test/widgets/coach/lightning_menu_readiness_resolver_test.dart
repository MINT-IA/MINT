import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

void main() {
  LightningMenuItem item(String action) => LightningMenuItem(
        title: action,
        subtitle: 'subtitle',
        icon: Icons.bolt,
        action: action,
        tone: MintSurfaceTone.bleu,
      );

  group('LightningMenuReadinessResolver', () {
    test('puts stabilize_budget first when readiness asks for it', () {
      final items = [
        item('maintain_plan'),
        item('stabilize_budget'),
        item('define_target'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'stabilize_budget'},
        itemsByActionId: {for (final item in items) item.action: item},
        fallbackItems: items,
      );

      expect(resolved.map((item) => item.action), [
        'stabilize_budget',
        'maintain_plan',
        'define_target',
      ]);
    });

    test('keeps fallback order when readiness is absent', () {
      final items = [
        item('maintain_plan'),
        item('define_target'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: null,
        itemsByActionId: {for (final item in items) item.action: item},
        fallbackItems: items,
      );

      expect(resolved, items);
    });

    test('keeps fallback order when next action id is unknown', () {
      final items = [
        item('maintain_plan'),
        item('define_target'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'unknown_action'},
        itemsByActionId: {for (final item in items) item.action: item},
        fallbackItems: items,
      );

      expect(resolved, items);
    });

    test('does not duplicate the prioritized action', () {
      final items = [
        item('complete_pillar_avs'),
        item('maintain_plan'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'complete_pillar_avs'},
        itemsByActionId: {for (final item in items) item.action: item},
        fallbackItems: items,
      );

      expect(
        resolved.where((item) => item.action == 'complete_pillar_avs').length,
        1,
      );
    });
  });

  group('LightningMenu readiness wiring', () {
    Future<String?> pumpMenuForAction(
      WidgetTester tester,
      String nextActionId,
      String label,
    ) async {
      String? capturedRoute;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: LightningMenu(
              profile: null,
              capMemory: const CapMemory(),
              readiness: {'next_action_id': nextActionId},
              onSendMessage: (_) {},
              onNavigate: (route) => capturedRoute = route,
            ),
          ),
        ),
      );

      await tester.tap(find.text(label).first);
      await tester.pump();
      return capturedRoute;
    }

    testWidgets('routes complete_pillar_avs to the AVS scan guide',
        (tester) async {
      final capturedRoute = await pumpMenuForAction(
        tester,
        'complete_pillar_avs',
        'Scanner un document',
      );

      expect(capturedRoute, '/scan/avs-guide');
    });

    testWidgets('routes stabilize_budget to budget setup', (tester) async {
      final capturedRoute = await pumpMenuForAction(
        tester,
        'stabilize_budget',
        'Mon budget',
      );

      expect(capturedRoute, '/budget/setup');
    });
  });
}
