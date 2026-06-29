// test/services/navigation/screen_registry_test.dart
//
// Unit tests for MintScreenRegistry + ScreenEntry invariants.
// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §4
//
// Golden couple (CLAUDE.md §8):
//   Julien: birthYear=1977, salaireBrut=122207 CHF/an, canton=VS
//   Lauren: birthYear=1982, salaireBrut=67000  CHF/an, canton=VS

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/route_category.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

void main() {
  // ── Invariants — all entries ──────────────────────────────────

  group('ScreenEntry invariants — all entries', () {
    test('all intent tags are unique', () {
      final tags = MintScreenRegistry.entries.map((e) => e.intentTag).toList();
      final unique = tags.toSet();
      expect(unique.length, equals(tags.length),
          reason: 'Duplicate intent tags found: '
              '${tags.where((t) => tags.where((x) => x == t).length > 1).toSet()}');
    });

    test('all routes start with / (or are empty for direct-answer stubs)', () {
      for (final entry in MintScreenRegistry.entries) {
        if (entry.route.isNotEmpty) {
          expect(entry.route, startsWith('/'),
              reason: 'Route "${entry.route}" for intent '
                  '"${entry.intentTag}" does not start with /');
        }
      }
    });

    test('all intent tags are non-empty snake_case strings', () {
      final snakeCasePattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final entry in MintScreenRegistry.entries) {
        expect(snakeCasePattern.hasMatch(entry.intentTag), isTrue,
            reason: '"${entry.intentTag}" is not valid snake_case');
      }
    });

    test('every entry has exactly one behavior assigned', () {
      for (final entry in MintScreenRegistry.entries) {
        // Just verifying the field is set (enum is non-null by construction)
        expect(ScreenBehavior.values.contains(entry.behavior), isTrue,
            reason: 'Entry "${entry.intentTag}" has invalid behavior');
      }
    });

    test('total entry count covers all registered surfaces (= 142)', () {
      // 07-06: dropped _coachWeeklyRecap (route /weekly-recap deleted in 07-04)
      // 53-01: +33 entries from registry parity fill (26 ROUTABLE + 7
      // NOT_CHAT_ROUTABLE) — see SCREEN-REGISTRY-COVERAGE.md.
      // Row 17/22: legacy redirect aliases such as /simulator/rente-capital
      // stay in GoRouter/route metadata, not in the Coach primary surface map.
      expect(MintScreenRegistry.entries.length, equals(142));
    });

    test('all routes are unique (no duplicate routes)', () {
      final routes = MintScreenRegistry.entries
          .map((e) => e.route)
          .where((r) => r.isNotEmpty)
          .toList();
      final uniqueRoutes = routes.toSet();
      expect(routes.length, uniqueRoutes.length,
          reason: 'Duplicate routes found: '
              '${routes.where((r) => routes.indexOf(r) != routes.lastIndexOf(r)).toSet()}');
    });

    test('chat-routable entries do not target legacy alias routes', () {
      final violations = <String>[];

      for (final entry in MintScreenRegistry.entries) {
        if (!entry.preferFromChat || entry.route.isEmpty) continue;

        final path = Uri.parse(entry.route).path;
        final meta = kRouteRegistry[path];
        if (meta == null) {
          violations.add('${entry.intentTag} -> ${entry.route} (unregistered)');
          continue;
        }
        if (meta.category == RouteCategory.alias) {
          violations.add('${entry.intentTag} -> ${entry.route}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Coach-routable ScreenRegistry entries must point to '
            'canonical destinations/flows, not compatibility aliases.',
      );
    });

    test('legacy chat intent aliases resolve to canonical routable routes', () {
      final violations = <String>[];

      for (final alias in MintScreenRegistry.chatIntentAliases.entries) {
        final raw = MintScreenRegistry.findByIntentStatic(alias.key);
        final canonical = MintScreenRegistry.findByIntentStatic(alias.value);
        final resolved =
            MintScreenRegistry.findChatEntryByIntentStatic(alias.key);

        if (raw == null) {
          violations.add('${alias.key} has no legacy registry entry');
          continue;
        }
        if (canonical == null) {
          violations.add('${alias.key} targets missing ${alias.value}');
          continue;
        }
        if (!canonical.preferFromChat) {
          violations.add('${alias.key} targets non-routable ${alias.value}');
          continue;
        }
        if (resolved == null || resolved.intentTag != canonical.intentTag) {
          violations.add('${alias.key} resolved to ${resolved?.intentTag}');
          continue;
        }

        final path = Uri.parse(canonical.route).path;
        final meta = kRouteRegistry[path];
        if (meta == null) {
          violations.add('${alias.value} -> ${canonical.route} unregistered');
        } else if (meta.category == RouteCategory.alias) {
          violations.add('${alias.value} -> ${canonical.route} is alias');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Every legacy Coach intent must resolve to a canonical '
            'chat-routable route so backend snapshots cannot reopen aliases.',
      );
    });
  });

  // ── findByIntent ──────────────────────────────────────────────

  group('findByIntentStatic', () {
    test('retirement_choice → /rente-vs-capital', () {
      final entry = MintScreenRegistry.findByIntentStatic('retirement_choice');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/rente-vs-capital'));
    });

    test('life_event_divorce → /divorce', () {
      final entry = MintScreenRegistry.findByIntentStatic('life_event_divorce');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/divorce'));
    });

    test('budget_overview → /budget', () {
      final entry = MintScreenRegistry.findByIntentStatic('budget_overview');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/budget'));
      expect(entry.behavior, equals(ScreenBehavior.decisionCanvas));
      expect(entry.preferFromChat, isTrue);
      expect(entry.requiredFields, contains('netIncome'));
      expect(entry.fallbackRoute, equals('/onboarding/quick'));
    });

    test('budget_overview fallback target is registered', () {
      final entry = MintScreenRegistry.findByIntentStatic('budget_overview')!;
      final fallback = MintScreenRegistry.findByRouteStatic(
        entry.fallbackRoute!,
      );

      expect(fallback, isNotNull);
      expect(fallback!.intentTag, equals('onboarding_quick'));
    });

    test('disability_gap → /invalidite', () {
      final entry = MintScreenRegistry.findByIntentStatic('disability_gap');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/invalidite'));
    });

    test('tax_optimization_3a → /3a-deep/staggered-withdrawal', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('tax_optimization_3a');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/3a-deep/staggered-withdrawal'));
    });

    test('housing_purchase → /hypotheque', () {
      final entry = MintScreenRegistry.findByIntentStatic('housing_purchase');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/hypotheque'));
    });

    test('cross_border → /segments/frontalier', () {
      final entry = MintScreenRegistry.findByIntentStatic('cross_border');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/segments/frontalier'));
    });

    test('self_employment → /segments/independant', () {
      final entry = MintScreenRegistry.findByIntentStatic('self_employment');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/segments/independant'));
    });

    test('life_event_birth → /naissance (salaireBrut + canton)', () {
      final entry = MintScreenRegistry.findByIntentStatic('life_event_birth');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/naissance'));
      expect(entry.requiredFields, equals(['salaireBrut', 'canton']));
    });

    test('document_scan → captureUtility behavior', () {
      final entry = MintScreenRegistry.findByIntentStatic('document_scan');
      expect(entry, isNotNull);
      expect(entry!.behavior, equals(ScreenBehavior.captureUtility));
    });

    test('explore_hub_retraite → /explore/retraite', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('explore_hub_retraite');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/explore/retraite'));
    });

    test('education_hub → /education/hub, preferFromChat true', () {
      final entry = MintScreenRegistry.findByIntentStatic('education_hub');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/education/hub'));
      expect(entry.preferFromChat, isTrue);
    });

    test('onboarding_quick → /onboarding/quick, preferFromChat false', () {
      final entry = MintScreenRegistry.findByIntentStatic('onboarding_quick');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/onboarding/quick'));
      expect(entry.preferFromChat, isFalse);
    });

    test('portfolio_overview → /portfolio, decisionCanvas', () {
      final entry = MintScreenRegistry.findByIntentStatic('portfolio_overview');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/portfolio'));
      expect(entry.behavior, equals(ScreenBehavior.decisionCanvas));
    });

    test('auth_login → /auth/login, preferFromChat false', () {
      final entry = MintScreenRegistry.findByIntentStatic('auth_login');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/auth/login'));
      expect(entry.preferFromChat, isFalse);
    });

    test('document_detail → /documents/:id, captureUtility', () {
      final entry = MintScreenRegistry.findByIntentStatic('document_detail');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/documents/:id'));
      expect(entry.behavior, equals(ScreenBehavior.captureUtility));
    });

    test('admin_observability → preferFromChat false', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('admin_observability');
      expect(entry, isNotNull);
      expect(entry!.preferFromChat, isFalse);
    });

    test(
        'financial_summary → /profile/bilan, captureUtility, preferFromChat true',
        () {
      final entry = MintScreenRegistry.findByIntentStatic('financial_summary');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/profile/bilan'));
      expect(entry.behavior, equals(ScreenBehavior.captureUtility));
      expect(entry.preferFromChat, isTrue);
      expect(entry.prefillFromProfile, isTrue);
    });

    test('financial_report is explicit synthesis recap, not decision canvas',
        () {
      final entry = MintScreenRegistry.findByIntentStatic('financial_report');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/rapport'));
      expect(entry.behavior, equals(ScreenBehavior.synthesisRecap));
      expect(entry.preferFromChat, isFalse);
      expect(entry.prefillFromProfile, isFalse);
    });

    test('legacy report aliases are not chat-routable destinations', () {
      final report = MintScreenRegistry.findByIntentStatic('report_overview');
      final reportV2 = MintScreenRegistry.findByIntentStatic('report_v2');

      expect(report, isNotNull);
      expect(report!.route, equals('/report'));
      expect(report.preferFromChat, isFalse);
      expect(report.prefillFromProfile, isFalse);

      expect(reportV2, isNotNull);
      expect(reportV2!.route, equals('/report/v2'));
      expect(reportV2.preferFromChat, isFalse);
      expect(reportV2.prefillFromProfile, isFalse);
    });

    test(
        'confidence_dashboard → /confidence, directAnswer, preferFromChat true',
        () {
      final entry =
          MintScreenRegistry.findByIntentStatic('confidence_dashboard');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/confidence'));
      expect(entry.behavior, equals(ScreenBehavior.directAnswer));
      expect(entry.preferFromChat, isTrue);
    });

    test('unknown intent tag returns null', () {
      final entry =
          MintScreenRegistry.findByIntentStatic('totally_unknown_xyz');
      expect(entry, isNull);
    });

    test('empty string returns null', () {
      final entry = MintScreenRegistry.findByIntentStatic('');
      expect(entry, isNull);
    });
  });

  // ── findByRouteStatic ─────────────────────────────────────────

  group('findByRouteStatic', () {
    test('/rente-vs-capital → retirement_choice', () {
      final entry = MintScreenRegistry.findByRouteStatic('/rente-vs-capital');
      expect(entry, isNotNull);
      expect(entry!.intentTag, equals('retirement_choice'));
    });

    test('legacy simulator alias is not a Coach-routable primary surface', () {
      final entry =
          MintScreenRegistry.findByRouteStatic('/simulator/rente-capital');

      expect(entry, isNull);
      expect(
        MintScreenRegistry.entries.map((e) => e.intentTag),
        isNot(contains('simulator_rente_capital')),
      );
    });

    test('/divorce → life_event_divorce', () {
      final entry = MintScreenRegistry.findByRouteStatic('/divorce');
      expect(entry, isNotNull);
      expect(entry!.intentTag, equals('life_event_divorce'));
    });

    test('/coach/chat → canonical chat route is chat-routable', () {
      final entry = MintScreenRegistry.findByRouteStatic('/coach/chat');
      expect(entry, isNotNull);
      expect(entry!.preferFromChat, isTrue);
    });

    test('unknown route returns null', () {
      final entry =
          MintScreenRegistry.findByRouteStatic('/does-not-exist-ever');
      expect(entry, isNull);
    });
  });

  // ── findByBehavior ────────────────────────────────────────────

  group('findByBehavior', () {
    test('directAnswer returns non-empty list', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.directAnswer);
      expect(results, isNotEmpty);
    });

    test('decisionCanvas returns ≥ 15 entries', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.decisionCanvas);
      expect(results.length, greaterThanOrEqualTo(15));
    });

    test('roadmapFlow returns ≥ 10 entries', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.roadmapFlow);
      expect(results.length, greaterThanOrEqualTo(10));
    });

    test('captureUtility returns ≥ 5 entries', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.captureUtility);
      expect(results.length, greaterThanOrEqualTo(5));
    });

    test('conversationPure returns non-empty list', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.conversationPure);
      expect(results, isNotEmpty);
    });

    test('synthesisRecap contains /rapport and stays out of decision canvases',
        () {
      final recap =
          MintScreenRegistry.findByBehavior(ScreenBehavior.synthesisRecap);
      final canvases =
          MintScreenRegistry.findByBehavior(ScreenBehavior.decisionCanvas);

      expect(recap.map((e) => e.intentTag), contains('financial_report'));
      expect(canvases.map((e) => e.intentTag),
          isNot(contains('financial_report')));
    });

    test('profile dossier is capture utility, not a decision canvas', () {
      final capture =
          MintScreenRegistry.findByBehavior(ScreenBehavior.captureUtility);
      final canvases =
          MintScreenRegistry.findByBehavior(ScreenBehavior.decisionCanvas);

      expect(capture.map((e) => e.intentTag), contains('financial_summary'));
      expect(canvases.map((e) => e.intentTag),
          isNot(contains('financial_summary')));
    });

    test('budget overview is a decision canvas, not an inline answer', () {
      final directAnswers =
          MintScreenRegistry.findByBehavior(ScreenBehavior.directAnswer);
      final canvases =
          MintScreenRegistry.findByBehavior(ScreenBehavior.decisionCanvas);

      expect(canvases.map((e) => e.intentTag), contains('budget_overview'));
      expect(directAnswers.map((e) => e.intentTag),
          isNot(contains('budget_overview')));
    });

    test('all entries in decisionCanvas have B behavior', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.decisionCanvas);
      for (final e in results) {
        expect(e.behavior, equals(ScreenBehavior.decisionCanvas),
            reason: 'Entry "${e.intentTag}" has wrong behavior');
      }
    });

    test('all entries in roadmapFlow have C behavior', () {
      final results =
          MintScreenRegistry.findByBehavior(ScreenBehavior.roadmapFlow);
      for (final e in results) {
        expect(e.behavior, equals(ScreenBehavior.roadmapFlow),
            reason: 'Entry "${e.intentTag}" has wrong behavior');
      }
    });
  });

  // ── chatRoutable ──────────────────────────────────────────────

  group('chatRoutable', () {
    test('returns non-empty list', () {
      final results = MintScreenRegistry.chatRoutable();
      expect(results, isNotEmpty);
    });

    test('all entries have preferFromChat == true', () {
      final results = MintScreenRegistry.chatRoutable();
      for (final e in results) {
        expect(e.preferFromChat, isTrue,
            reason: 'Entry "${e.intentTag}" in chatRoutable '
                'has preferFromChat == false');
      }
    });

    test('is a strict subset of all entries', () {
      final routable = MintScreenRegistry.chatRoutable().toSet();
      final all = MintScreenRegistry.entries.toSet();
      expect(routable.length, lessThan(all.length),
          reason: 'chatRoutable should be smaller than the full list '
              '(admin/auth entries are excluded)');
    });

    test(
        'non-routable surfaces are excluded '
        '(landing, achievements, byok, auth, admin, onboarding)', () {
      final routable = MintScreenRegistry.chatRoutable();
      final routeSet = routable.map((e) => e.intentTag).toSet();
      expect(routeSet, isNot(contains('landing')));
      expect(routeSet, isNot(contains('achievements')));
      expect(routeSet, isNot(contains('byok_settings')));
      expect(routeSet, isNot(contains('slm_settings')));
      expect(routeSet, isNot(contains('consent_settings')));
      expect(routeSet, isNot(contains('auth_login')));
      expect(routeSet, isNot(contains('auth_register')));
      expect(routeSet, isNot(contains('auth_forgot_password')));
      expect(routeSet, isNot(contains('auth_verify_email')));
      expect(routeSet, isNot(contains('home_shell')));
      expect(routeSet, isNot(contains('admin_observability')));
      expect(routeSet, isNot(contains('admin_analytics')));
      expect(routeSet, isNot(contains('onboarding_quick')));
      expect(routeSet, isNot(contains('onboarding_premier_eclairage')));
      expect(routeSet, isNot(contains('score_reveal')));
      expect(routeSet, isNot(contains('scan_review')));
      expect(routeSet, isNot(contains('scan_impact')));
      expect(routeSet, isNot(contains('coach_history')));
      expect(routeSet, isNot(contains('coach_checkin')));
      expect(routeSet, isNot(contains('coach_weekly_recap')));
      expect(routeSet, isNot(contains('open_banking_transactions')));
      expect(routeSet, isNot(contains('open_banking_consents')));
      expect(routeSet, isNot(contains('financial_report')));
    });

    test('key B surfaces are routable from chat', () {
      final routable = MintScreenRegistry.chatRoutable();
      final tags = routable.map((e) => e.intentTag).toSet();
      expect(
          tags,
          containsAll([
            'retirement_choice',
            'simulator_3a',
            'housing_purchase',
            'disability_gap',
            'withdrawal_sequencing',
          ]));
    });

    test('all C surfaces are routable from chat', () {
      final roadmap =
          MintScreenRegistry.findByBehavior(ScreenBehavior.roadmapFlow);
      for (final e in roadmap) {
        expect(e.preferFromChat, isTrue,
            reason: 'Roadmap surface "${e.intentTag}" should be chat-routable');
      }
    });
  });

  // ── InMemoryScreenRegistry ────────────────────────────────────

  group('InMemoryScreenRegistry', () {
    const registry = InMemoryScreenRegistry([
      ScreenEntry(
        route: '/retraite',
        intentTag: 'retirement_projection',
        behavior: ScreenBehavior.decisionCanvas,
        requiredFields: ['salaireBrut', 'age', 'canton'],
      ),
      ScreenEntry(
        route: '/naissance',
        intentTag: 'life_event_birth',
        behavior: ScreenBehavior.roadmapFlow,
      ),
    ]);

    test('findByIntent returns correct entry', () {
      final entry = registry.findByIntent('retirement_projection');
      expect(entry, isNotNull);
      expect(entry!.route, equals('/retraite'));
    });

    test('findByIntent returns null for unknown tag', () {
      expect(registry.findByIntent('unknown_xyz'), isNull);
    });

    test('findByRoute returns correct entry', () {
      final entry = registry.findByRoute('/naissance');
      expect(entry, isNotNull);
      expect(entry!.intentTag, equals('life_event_birth'));
    });

    test('findByRoute returns null for unknown route', () {
      expect(registry.findByRoute('/unknown'), isNull);
    });

    test('all returns unmodifiable list with correct count', () {
      expect(registry.all.length, equals(2));
    });
  });

  // ── MintScreenRegistry as ScreenRegistry instance ─────────────

  group('MintScreenRegistry as ScreenRegistry instance', () {
    const registry = MintScreenRegistry();

    test('findByIntent delegates to static lookup', () {
      final entry = registry.findByIntent('retirement_choice');
      expect(entry, isNotNull);
      expect(entry!.intentTag, equals('retirement_choice'));
    });

    test('findByIntent returns raw legacy entry without chat alias rewrite',
        () {
      final raw = registry.findByIntent('retirement_overview');
      final chat = registry.findChatEntryByIntent('retirement_overview');

      expect(raw, isNotNull);
      expect(raw!.intentTag, equals('retirement_overview'));
      expect(raw.route, equals('/retirement'));
      expect(raw.preferFromChat, isFalse);

      expect(chat, isNotNull);
      expect(chat!.intentTag, equals('retirement_projection'));
      expect(chat.route, equals('/retraite'));
    });

    test('findByRoute delegates to static lookup', () {
      final entry = registry.findByRoute('/divorce');
      expect(entry, isNotNull);
      expect(entry!.intentTag, equals('life_event_divorce'));
    });

    test('all returns the full entries list', () {
      expect(registry.all, equals(MintScreenRegistry.entries));
    });
  });
}
