import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

void main() {
  LightningMenuItem item(String id, String action) => LightningMenuItem(
        id: id,
        title: id,
        subtitle: 'subtitle',
        icon: Icons.bolt,
        action: action,
        tone: MintSurfaceTone.bleu,
      );

  group('LightningMenuReadinessResolver', () {
    test('puts stabilize_budget first when readiness asks for it', () {
      final items = [
        item('maintain_plan', 'Où j’en suis ?'),
        item('stabilize_budget', 'Mon budget ce mois'),
        item('define_target', '/profile/bilan'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'stabilize_budget'},
        itemsById: {for (final item in items) item.id: item},
        fallbackItems: items,
      );

      expect(resolved.map((item) => item.id), [
        'stabilize_budget',
        'maintain_plan',
        'define_target',
      ]);
    });

    test('keeps fallback order when readiness is absent', () {
      final items = [
        item('maintain_plan', 'Où j’en suis ?'),
        item('define_target', '/profile/bilan'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: null,
        itemsById: {for (final item in items) item.id: item},
        fallbackItems: items,
      );

      expect(resolved, items);
    });

    test('keeps fallback order when next action id is unknown', () {
      final items = [
        item('maintain_plan', 'Où j’en suis ?'),
        item('define_target', '/profile/bilan'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'unknown_action'},
        itemsById: {for (final item in items) item.id: item},
        fallbackItems: items,
      );

      expect(resolved, items);
    });

    test('does not duplicate the prioritized action', () {
      final items = [
        item('complete_pillar_avs', '/scan/avs-guide'),
        item('maintain_plan', 'Où j’en suis ?'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'complete_pillar_avs'},
        itemsById: {for (final item in items) item.id: item},
        fallbackItems: items,
      );

      expect(
        resolved.where((item) => item.id == 'complete_pillar_avs').length,
        1,
      );
    });

    test('does not leak readiness ids into the chat action payload', () {
      final items = [
        item('maintain_plan', 'Où j’en suis ?'),
        item('stabilize_budget', 'Mon budget ce mois'),
      ];

      final resolved = LightningMenuReadinessResolver.prioritize(
        readiness: const {'next_action_id': 'stabilize_budget'},
        itemsById: {for (final item in items) item.id: item},
        fallbackItems: items,
      );

      expect(resolved.first.id, 'stabilize_budget');
      expect(resolved.first.action, isNot('stabilize_budget'));
    });
  });

  group('LightningMenu readiness wiring', () {
    Future<String?> pumpMenuForAction(
      WidgetTester tester,
      String nextActionId,
      Finder target,
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

      await tester.tap(target);
      await tester.pump();
      return capturedRoute;
    }

    testWidgets('routes complete_pillar_avs to the AVS scan guide',
        (tester) async {
      final capturedRoute = await pumpMenuForAction(
        tester,
        'complete_pillar_avs',
        find.text('Scanner un document').first,
      );

      expect(capturedRoute, '/scan/avs-guide');
    });

    testWidgets('routes stabilize_budget to budget setup', (tester) async {
      final capturedRoute = await pumpMenuForAction(
        tester,
        'stabilize_budget',
        find.byIcon(Icons.receipt_long_outlined).first,
      );

      expect(capturedRoute, '/budget/setup');
    });

    test('keeps French ARB titles action-first, not possessive', () {
      final arb = jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
          as Map<String, dynamic>;
      final titles = arb.entries.where(
        (entry) =>
            entry.key.startsWith('lightningMenu') &&
            entry.key.endsWith('Title'),
      );
      for (final prefix in ['Mon ', 'Ma ', 'Mes ', 'Notre ', 'Nos ']) {
        expect(
          titles.where((entry) => (entry.value as String).startsWith(prefix)),
          isEmpty,
        );
      }
    });
  });
}
