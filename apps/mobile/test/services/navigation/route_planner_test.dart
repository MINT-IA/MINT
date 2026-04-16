// test/services/navigation/route_planner_test.dart
//
// Unit tests for RoutePlanner + ReadinessGate.
// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §6
//
// Golden couple (CLAUDE.md §8):
//   Julien: birthYear=1977, salaireBrut=122207, canton=VS, archetype=swiss_native
//   Lauren: birthYear=1982, salaireBrut=67000,  canton=VS, archetype=expat_us

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/readiness_gate.dart';
import 'package:mint_mobile/services/navigation/route_planner.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

// ════════════════════════════════════════════════════════════════
//  TEST FIXTURES
// ════════════════════════════════════════════════════════════════

/// A minimal [ScreenRegistry] with a representative set of surfaces for tests.
///
/// Field keys use the canonical names from [ReadinessGate] / [MintScreenRegistry]:
/// 'salaireBrut', 'avoirLpp', 'rachatMaximum', 'epargne3a', 'epargne'.
InMemoryScreenRegistry _testRegistry() {
  return const InMemoryScreenRegistry([
    // B — Decision Canvas: requires salary + age
    ScreenEntry(
      route: '/rente-vs-capital',
      intentTag: 'retirement_choice',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['salaireBrut', 'age'],
      optionalFields: ['avoirLpp', 'canton'],
      prefillFromProfile: true,
    ),
    // B — Decision Canvas: requires canton + netIncome
    ScreenEntry(
      route: '/fiscal',
      intentTag: 'cantonal_comparison',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['canton', 'netIncome'],
    ),
    // B — Decision Canvas: requires salary + canton
    ScreenEntry(
      route: '/mortgage/affordability',
      intentTag: 'housing_purchase',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['salaireBrut', 'canton'],
      optionalFields: ['epargne'],
    ),
    // B — Decision Canvas: requires rachatMaximum (non-critical → partial)
    ScreenEntry(
      route: '/lpp-deep/rachat',
      intentTag: 'lpp_rachat',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['rachatMaximum'],
      optionalFields: ['avoirLpp'],
    ),
    // B — Decision Canvas: requires age + canton (for 3a)
    ScreenEntry(
      route: '/3a-deep/staggered-withdrawal',
      intentTag: 'tax_optimization_3a',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['age', 'canton'],
      optionalFields: ['avoirLpp'],
    ),
    // C — Roadmap Flow: no required fields
    ScreenEntry(
      route: '/naissance',
      intentTag: 'life_event_birth',
      behavior: ScreenBehavior.roadmapFlow,
    ),
    // C — Roadmap Flow: requires civilStatus (non-critical)
    ScreenEntry(
      route: '/divorce',
      intentTag: 'life_event_divorce',
      behavior: ScreenBehavior.roadmapFlow,
      requiredFields: ['civilStatus'],
    ),
    // B — Decision Canvas: requires salary + employmentStatus
    ScreenEntry(
      route: '/invalidite',
      intentTag: 'disability_gap',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['salaireBrut', 'employmentStatus'],
    ),
    // B — budget: requires netIncome, fallback to onboarding
    ScreenEntry(
      route: '/budget',
      intentTag: 'budget_overview',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: ['netIncome'],
      fallbackRoute: '/onboarding/quick-start',
    ),
    // A — Direct Answer: never opens a screen
    ScreenEntry(
      route: '',
      intentTag: 'score_query',
      behavior: ScreenBehavior.directAnswer,
    ),
    // D — Capture: not routable from chat
    ScreenEntry(
      route: '/documents',
      intentTag: 'document_scan',
      behavior: ScreenBehavior.captureUtility,
      preferFromChat: false,
    ),
  ]);
}

/// Build a fully populated CoachProfile for Julien (golden couple).
///
/// Julien: born 1977, salary 122'207 CHF/an, canton VS, swiss_native.
CoachProfile _julienProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    nationality: 'CH',
    employmentStatus: 'salarie',
    salaireBrutMensuel: 122207 / 12,
    etatCivil: CoachCivilStatus.marie,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      tauxConversion: 0.068,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
  );
}

/// Build a minimal profile with only the bare minimum fields set.
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: 'ZH',
    salaireBrutMensuel: 0, // No income set
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050, 1, 1),
      label: 'Retraite',
    ),
  );
}

/// Build a partial profile: salary set, canton set, but no LPP data.
CoachProfile _partialProfile() {
  return CoachProfile(
    birthYear: 1980,
    canton: 'BE',
    salaireBrutMensuel: 6000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045, 1, 1),
      label: 'Retraite',
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════

void main() {
  late InMemoryScreenRegistry registry;
  late ReadinessGate gate;

  setUp(() {
    registry = _testRegistry();
    gate = const ReadinessGate();
  });

  // ── RoutePlanner — core behavior ──────────────────────────────

  group('RoutePlanner — unknown intent', () {
    test('unknown intent tag → conversationOnly', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('completely_unknown_intent');
      expect(decision.action, RouteAction.conversationOnly);
      expect(decision.route, isNull);
    });

    test('empty intent tag → conversationOnly', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('');
      expect(decision.action, RouteAction.conversationOnly);
    });
  });

  group('RoutePlanner — low confidence', () {
    test('confidence < 0.5 → conversationOnly regardless of intent', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('retirement_choice', confidence: 0.3);
      expect(decision.action, RouteAction.conversationOnly);
    });

    test('confidence == 0.0 → conversationOnly', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('budget_overview', confidence: 0.0);
      expect(decision.action, RouteAction.conversationOnly);
    });

    test('confidence exactly at threshold (0.5) proceeds to routing', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('budget_overview', confidence: 0.5);
      // Julien has salary set, so budget should open
      expect(decision.action, isNot(RouteAction.conversationOnly));
    });

    test('confidence > 0.5 proceeds to routing', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      expect(
        decision.action,
        anyOf(RouteAction.openScreen, RouteAction.openWithWarning),
      );
    });
  });

  group('RoutePlanner — directAnswer behavior', () {
    test('directAnswer surface → conversationOnly (never navigates)', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('score_query', confidence: 0.9);
      expect(decision.action, RouteAction.conversationOnly);
    });
  });

  group('RoutePlanner — preferFromChat = false', () {
    test('document_scan not routable from chat → conversationOnly', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('document_scan', confidence: 0.95);
      expect(decision.action, RouteAction.conversationOnly);
    });
  });

  group('RoutePlanner — known intent + ready profile → openScreen', () {
    test('retirement_choice with full profile → openScreen', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      expect(decision.action, RouteAction.openScreen);
      expect(decision.route, '/rente-vs-capital');
    });

    test('openScreen decision sets correct route', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('retirement_choice', confidence: 0.85);
      expect(decision.route, '/rente-vs-capital');
    });

    test('openScreen provides prefill data from profile', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      expect(decision.prefill, isNotNull);
    });

    test('tax_optimization_3a with canton + age → openScreen', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('tax_optimization_3a', confidence: 0.8);
      expect(decision.action, RouteAction.openScreen);
      expect(decision.route, '/3a-deep/staggered-withdrawal');
    });

    test('life_event_birth (no required fields) → openScreen', () {
      final planner = RoutePlanner(registry: registry, profile: _minimalProfile());
      final decision = planner.plan('life_event_birth', confidence: 0.9);
      expect(decision.action, RouteAction.openScreen);
      expect(decision.route, '/naissance');
    });

    test('budget_overview with salary set → openScreen', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('budget_overview', confidence: 0.9);
      expect(decision.action, RouteAction.openScreen);
      expect(decision.route, '/budget');
    });

    test('disability_gap with salary + employmentStatus → openScreen', () {
      final planner = RoutePlanner(registry: registry, profile: _julienProfile());
      final decision = planner.plan('disability_gap', confidence: 0.8);
      expect(decision.action, RouteAction.openScreen);
      expect(decision.route, '/invalidite');
    });
  });

  group('RoutePlanner — known intent + partial profile → openWithWarning', () {
    test('lpp_rachat without rachatMaximum → openWithWarning (partial)', () {
      // rachatMaximum is NOT in _criticalFields → produces partial, not blocked
      final profile = _partialProfile();
      final planner = RoutePlanner(registry: registry, profile: profile);
      final decision = planner.plan('lpp_rachat', confidence: 0.8);
      expect(decision.action, RouteAction.openWithWarning);
      expect(decision.route, '/lpp-deep/rachat');
      expect(decision.missingFields, contains('rachatMaximum'));
    });

    test('retirement_choice without LPP data → openScreen (salary+age present)', () {
      // salary + age present; avoirLpp is optional → ready
      final profile = _partialProfile();
      final planner = RoutePlanner(registry: registry, profile: profile);
      final decision = planner.plan('retirement_choice', confidence: 0.85);
      // salary and age are present, avoirLpp is optional
      expect(
        decision.action,
        anyOf(RouteAction.openScreen, RouteAction.openWithWarning),
      );
      expect(decision.route, '/rente-vs-capital');
    });
  });

  group('RoutePlanner — known intent + blocked profile → askFirst', () {
    test('retirement_choice without salary → askFirst', () {
      final profile = _minimalProfile(); // salary = 0
      final planner = RoutePlanner(registry: registry, profile: profile);
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      expect(decision.action, RouteAction.askFirst);
      expect(decision.missingFields, isNotEmpty);
      expect(decision.missingFields, contains('salaireBrut'));
    });

    test('budget_overview without salary → redirects to fallbackRoute', () {
      final profile = _minimalProfile();
      final planner = RoutePlanner(registry: registry, profile: profile);
      final decision = planner.plan('budget_overview', confidence: 0.9);
      // V11-6: When blocked AND fallbackRoute is set, the planner redirects
      // to the fallback route (openWithWarning) instead of askFirst.
      expect(decision.action, RouteAction.openWithWarning);
      expect(decision.route, '/onboarding/quick-start');
      expect(decision.missingFields, isNotEmpty);
    });

    test('askFirst decision has no route', () {
      final profile = _minimalProfile();
      final planner = RoutePlanner(registry: registry, profile: profile);
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      expect(decision.action, RouteAction.askFirst);
      expect(decision.route, isNull);
    });

    test('askFirst decision includes missing fields list', () {
      final profile = _minimalProfile();
      final planner = RoutePlanner(registry: registry, profile: profile);
      final decision = planner.plan('retirement_choice', confidence: 0.9);
      expect(decision.missingFields, isNotNull);
      expect(decision.missingFields!.isNotEmpty, isTrue);
    });
  });

  // ── Golden couple — Julien ──────────────────────────────────────

  group('Golden couple — Julien (swiss_native, VS, 122207 CHF/an)', () {
    late RoutePlanner plannerJulien;

    setUp(() {
      plannerJulien = RoutePlanner(
        registry: registry,
        profile: _julienProfile(),
      );
    });

    test('retirement_choice → openScreen /rente-vs-capital', () {
      final d = plannerJulien.plan('retirement_choice', confidence: 0.9);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/rente-vs-capital');
    });

    test('cantonal_comparison → openScreen /fiscal', () {
      final d = plannerJulien.plan('cantonal_comparison', confidence: 0.85);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/fiscal');
    });

    test('housing_purchase → openScreen /mortgage/affordability', () {
      final d = plannerJulien.plan('housing_purchase', confidence: 0.8);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/mortgage/affordability');
    });

    test('lpp_rachat (Julien has rachatMaximum=539414) → openScreen', () {
      final d = plannerJulien.plan('lpp_rachat', confidence: 0.9);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/lpp-deep/rachat');
    });

    test('tax_optimization_3a → openScreen /3a-deep/staggered-withdrawal', () {
      final d = plannerJulien.plan('tax_optimization_3a', confidence: 0.85);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/3a-deep/staggered-withdrawal');
    });

    test('disability_gap → openScreen /invalidite', () {
      final d = plannerJulien.plan('disability_gap', confidence: 0.8);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/invalidite');
    });

    test('budget_overview → openScreen /budget', () {
      final d = plannerJulien.plan('budget_overview', confidence: 0.9);
      expect(d.action, RouteAction.openScreen);
      expect(d.route, '/budget');
    });

    test('willNavigate is true for all B-type surfaces', () {
      final intents = [
        'retirement_choice',
        'cantonal_comparison',
        'housing_purchase',
        'lpp_rachat',
        'tax_optimization_3a',
        'disability_gap',
        'budget_overview',
      ];
      for (final intent in intents) {
        final d = plannerJulien.plan(intent, confidence: 0.85);
        expect(
          d.willNavigate,
          isTrue,
          reason: 'Expected willNavigate for intent: $intent, got ${d.action}',
        );
      }
    });
  });

  // ── ReadinessGate — unit tests ──────────────────────────────────

  group('ReadinessGate — evaluate', () {
    test('empty requiredFields → ready', () {
      final result = gate.evaluate(
        const ScreenEntry(
          route: '/naissance',
          intentTag: 'life_event_birth',
          behavior: ScreenBehavior.roadmapFlow,
        ),
        _minimalProfile(),
      );
      expect(result.level, ReadinessLevel.ready);
      expect(result.missingFields, isEmpty);
    });

    test('all required fields present → ready', () {
      final result = gate.evaluate(
        const ScreenEntry(
          route: '/rente-vs-capital',
          intentTag: 'retirement_choice',
          behavior: ScreenBehavior.decisionCanvas,
          requiredFields: ['salaireBrut', 'age'],
        ),
        _julienProfile(),
      );
      expect(result.level, ReadinessLevel.ready);
    });

    test('critical field (salaireBrut) missing → blocked', () {
      final result = gate.evaluate(
        const ScreenEntry(
          route: '/rente-vs-capital',
          intentTag: 'retirement_choice',
          behavior: ScreenBehavior.decisionCanvas,
          requiredFields: ['salaireBrut', 'age'],
        ),
        _minimalProfile(), // salary = 0
      );
      expect(result.level, ReadinessLevel.blocked);
      expect(result.missingFields, contains('salaireBrut'));
    });

    test('non-critical field (avoirLpp) missing → partial', () {
      final result = gate.evaluate(
        const ScreenEntry(
          route: '/rente-vs-capital',
          intentTag: 'retirement_choice',
          behavior: ScreenBehavior.decisionCanvas,
          requiredFields: ['salaireBrut', 'avoirLpp'],
        ),
        _partialProfile(), // salary OK (6000), no LPP
      );
      // salaireBrut present, avoirLpp missing (non-critical) → partial
      expect(result.level, ReadinessLevel.partial);
      expect(result.missingFields, contains('avoirLpp'));
    });

    test('static check() convenience method works', () {
      final result = ReadinessGate.check(
        const ScreenEntry(
          route: '/naissance',
          intentTag: 'life_event_birth',
          behavior: ScreenBehavior.roadmapFlow,
        ),
        _julienProfile(),
      );
      expect(result.level, ReadinessLevel.ready);
    });
  });

  // ── RouteDecision — computed properties ─────────────────────────

  group('RouteDecision — willNavigate', () {
    test('openScreen → willNavigate true', () {
      const d = RouteDecision.openScreen('/budget');
      expect(d.willNavigate, isTrue);
    });

    test('openWithWarning → willNavigate true', () {
      const d = RouteDecision.openWithWarning(
        '/budget',
        missingFields: ['prevoyance.avoirLppTotal'],
      );
      expect(d.willNavigate, isTrue);
    });

    test('askFirst → willNavigate false', () {
      const d = RouteDecision.askFirst(['salaireBrutMensuel']);
      expect(d.willNavigate, isFalse);
    });

    test('conversationOnly → willNavigate false', () {
      const d = RouteDecision.conversationOnly();
      expect(d.willNavigate, isFalse);
    });
  });

  group('RouteDecision — equality', () {
    test('same action + route are equal', () {
      const d1 = RouteDecision.openScreen('/budget');
      const d2 = RouteDecision.openScreen('/budget');
      expect(d1, equals(d2));
    });

    test('different routes are not equal', () {
      const d1 = RouteDecision.openScreen('/budget');
      const d2 = RouteDecision.openScreen('/fiscal');
      expect(d1, isNot(equals(d2)));
    });
  });

  // ── InMemoryScreenRegistry ──────────────────────────────────────

  group('InMemoryScreenRegistry', () {
    test('findByIntent returns correct entry', () {
      final entry = registry.findByIntent('retirement_choice');
      expect(entry, isNotNull);
      expect(entry!.route, '/rente-vs-capital');
    });

    test('findByIntent returns null for unknown tag', () {
      final entry = registry.findByIntent('unknown_tag_xyz');
      expect(entry, isNull);
    });

    test('findByRoute returns correct entry', () {
      final entry = registry.findByRoute('/rente-vs-capital');
      expect(entry, isNotNull);
      expect(entry!.intentTag, 'retirement_choice');
    });

    test('findByRoute returns null for unknown route', () {
      final entry = registry.findByRoute('/does-not-exist');
      expect(entry, isNull);
    });

    test('all returns all registered entries', () {
      // The test registry has 11 entries
      expect(registry.all.length, greaterThanOrEqualTo(10));
    });
  });
}
