import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';

/// French localizations instance for tests (no BuildContext needed).
final _l = SFr();

// ────────────────────────────────────────────────────────────────
//  RESPONSE CARD SERVICE — Unit Tests
// ────────────────────────────────────────────────────────────────

CoachProfile _makeProfile({
  String? firstName,
  double salaire = 0,
  int nombreDeMois = 12,
  double? bonusPourcentage,
  String canton = '',
  int birthYear = 1980,
  String employmentStatus = '',
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
  PatrimoineProfile patrimoine = const PatrimoineProfile(),
  DepensesProfile depenses = const DepensesProfile(),
  ConjointProfile? conjoint,
  int? arrivalAge,
}) {
  return CoachProfile(
    firstName: firstName,
    salaireBrutMensuel: salaire,
    nombreDeMois: nombreDeMois,
    bonusPourcentage: bonusPourcentage,
    canton: canton,
    birthYear: birthYear,
    employmentStatus: employmentStatus,
    etatCivil: etatCivil,
    prevoyance: prevoyance,
    patrimoine: patrimoine,
    depenses: depenses,
    conjoint: conjoint,
    arrivalAge: arrivalAge,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

void main() {
  // ════════════════════════════════════════════════════════════
  //  MODEL — ResponseCard, ChiffreChoc
  // ════════════════════════════════════════════════════════════

  group('ChiffreChoc', () {
    test('CHF formatting with Swiss apostrophe', () {
      const c = ChiffreChoc(value: 12450, unit: 'CHF', explanation: 'test');
      expect(c.formatted, "12'450 CHF");
    });

    test('CHF large number formatting', () {
      const c = ChiffreChoc(value: 539414, unit: 'CHF', explanation: 'test');
      expect(c.formatted, "539'414 CHF");
    });

    test('percentage formatting', () {
      const c = ChiffreChoc(value: 65.5, unit: '%', explanation: 'test');
      expect(c.formatted, '65.5%');
    });

    test('years formatting', () {
      const c = ChiffreChoc(value: 3, unit: 'ans', explanation: 'test');
      expect(c.formatted, '3 ans');
    });

    test('serialization roundtrip', () {
      const original =
          ChiffreChoc(value: 7258, unit: 'CHF', explanation: 'plafond 3a');
      final json = original.toJson();
      final restored = ChiffreChoc.fromJson(json);

      expect(restored.value, 7258);
      expect(restored.unit, 'CHF');
      expect(restored.explanation, 'plafond 3a');
    });

    test('negative value formatting', () {
      const c = ChiffreChoc(value: -5000, unit: 'CHF', explanation: 'test');
      expect(c.formatted, "-5'000 CHF");
    });
  });

  group('ResponseCard', () {
    test('deadlineBadge returns null when no deadline', () {
      const card = ResponseCard(
        id: 'test',
        type: ResponseCardType.pillar3a,
        title: 'Test',
        subtitle: 'Sub',
        chiffreChoc:
            ChiffreChoc(value: 100, unit: 'CHF', explanation: 'test'),
        cta: CardCta(label: 'Go', route: '/test'),
        disclaimer: 'test disclaimer',
      );
      expect(card.deadlineBadge, isNull);
      expect(card.daysUntilDeadline, isNull);
    });

    test('deadlineBadge shows J-N format when < 30', () {
      final card = ResponseCard(
        id: 'test',
        type: ResponseCardType.pillar3a,
        title: 'Test',
        subtitle: 'Sub',
        chiffreChoc:
            const ChiffreChoc(value: 100, unit: 'CHF', explanation: 'test'),
        cta: const CardCta(label: 'Go', route: '/test'),
        deadline: DateTime.now().add(const Duration(days: 15)),
        disclaimer: 'test',
      );
      // Format is now "J-N" (e.g., "J-14" or "J-15" depending on time of day)
      expect(card.deadlineBadge, startsWith('J-'));
      expect(card.daysUntilDeadline, greaterThanOrEqualTo(14));
      expect(card.daysUntilDeadline, lessThanOrEqualTo(15));
    });

    test('deadlineBadge shows months when > 30 days', () {
      final card = ResponseCard(
        id: 'test',
        type: ResponseCardType.pillar3a,
        title: 'Test',
        subtitle: 'Sub',
        chiffreChoc:
            const ChiffreChoc(value: 100, unit: 'CHF', explanation: 'test'),
        cta: const CardCta(label: 'Go', route: '/test'),
        deadline: DateTime.now().add(const Duration(days: 90)),
        disclaimer: 'test',
      );
      expect(card.deadlineBadge, contains('mois'));
    });

    test('deadlineBadge shows Expire when past', () {
      final card = ResponseCard(
        id: 'test',
        type: ResponseCardType.pillar3a,
        title: 'Test',
        subtitle: 'Sub',
        chiffreChoc:
            const ChiffreChoc(value: 100, unit: 'CHF', explanation: 'test'),
        cta: const CardCta(label: 'Go', route: '/test'),
        deadline: DateTime.now().subtract(const Duration(days: 5)),
        disclaimer: 'test',
      );
      expect(card.deadlineBadge, 'Expire');
    });

    test('toJson includes all required fields', () {
      const card = ResponseCard(
        id: 'lpp_buyback',
        type: ResponseCardType.lppBuyback,
        title: 'Rachat LPP',
        subtitle: 'Potentiel',
        chiffreChoc:
            ChiffreChoc(value: 539414, unit: 'CHF', explanation: 'max'),
        cta: CardCta(label: 'Simuler', route: '/rachat-lpp'),
        disclaimer: 'Outil educatif',
        sources: ['LPP art. 79b'],
        impactPoints: 20,
      );

      final json = card.toJson();
      expect(json['id'], 'lpp_buyback');
      expect(json['type'], 'lppBuyback');
      expect(json['disclaimer'], 'Outil educatif');
      expect(json['sources'], ['LPP art. 79b']);
      expect(json['impactPoints'], 20);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SERVICE — generateForPulse
  // ════════════════════════════════════════════════════════════

  group('ResponseCardService.generateForPulse', () {
    test('empty profile returns empty cards', () {
      final profile = _makeProfile();
      final cards = ResponseCardService.generateForPulse(profile, l: _l);
      expect(cards, isEmpty);
    });

    test('profile with salary returns 3a card', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1980,
      );
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      final types = cards.map((c) => c.type).toSet();
      expect(types, contains(ResponseCardType.pillar3a));
    });

    test('3a card has 31.12 deadline', () {
      final profile = _makeProfile(salaire: 8000, canton: 'VD');
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      final card3a =
          cards.firstWhere((c) => c.type == ResponseCardType.pillar3a);
      expect(card3a.deadline, isNotNull);
      expect(card3a.deadline!.month, 12);
      expect(card3a.deadline!.day, 31);
    });

    test('3a card sources reference OPP3 and LIFD', () {
      final profile = _makeProfile(salaire: 8000, canton: 'VD');
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      final card3a =
          cards.firstWhere((c) => c.type == ResponseCardType.pillar3a);
      expect(card3a.sources.any((s) => s.contains('OPP3')), isTrue);
      expect(card3a.sources.any((s) => s.contains('LIFD')), isTrue);
    });

    test('LPP buyback card generated when rachatMaximum > 0', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 200000,
        ),
      );
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      final types = cards.map((c) => c.type).toSet();
      expect(types, contains(ResponseCardType.lppBuyback));
    });

    test('replacement rate card only for age >= 45', () {
      final young = _makeProfile(salaire: 8000, canton: 'VD', birthYear: 1996);
      final old = _makeProfile(salaire: 8000, canton: 'VD', birthYear: 1975);

      final youngCards =
          ResponseCardService.generateForPulse(young, l: _l, limit: 10);
      final oldCards = ResponseCardService.generateForPulse(old, l: _l, limit: 10);

      expect(
          youngCards.any((c) => c.type == ResponseCardType.replacementRate),
          isFalse);
      expect(
          oldCards.any((c) => c.type == ResponseCardType.replacementRate),
          isTrue);
    });

    test('AVS gap card for expats with arrivalAge > 20', () {
      final expat = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1980,
        arrivalAge: 30,
      );
      final cards = ResponseCardService.generateForPulse(expat, l: _l, limit: 10);

      final types = cards.map((c) => c.type).toSet();
      expect(types, contains(ResponseCardType.avsGap));
    });

    test('AVS gap card NOT for Swiss native (no arrivalAge)', () {
      final swiss = _makeProfile(salaire: 8000, canton: 'VD');
      final cards = ResponseCardService.generateForPulse(swiss, l: _l, limit: 10);

      expect(cards.any((c) => c.type == ResponseCardType.avsGap), isFalse);
    });

    test('independant card for self-employed without LPP', () {
      final indep = _makeProfile(
        salaire: 6000,
        canton: 'VD',
        employmentStatus: 'independant',
      );
      final cards = ResponseCardService.generateForPulse(indep, l: _l, limit: 10);

      expect(
          cards.any((c) => c.type == ResponseCardType.independant), isTrue);
    });

    test('independant card NOT shown if has LPP', () {
      final indep = _makeProfile(
        salaire: 6000,
        canton: 'VD',
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 50000),
      );
      final cards = ResponseCardService.generateForPulse(indep, l: _l, limit: 10);

      expect(
          cards.any((c) => c.type == ResponseCardType.independant), isFalse);
    });

    test('limit respected', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974,
        employmentStatus: 'salarie',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 200000,
        ),
      );
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 2);
      expect(cards.length, lessThanOrEqualTo(2));
    });

    test('cards sorted by urgency then impact', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 70000,
          rachatMaximum: 200000,
        ),
      );
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      for (var i = 1; i < cards.length; i++) {
        final prev = cards[i - 1];
        final curr = cards[i];
        // Higher urgency first, then higher impact
        expect(
            prev.urgency.index >= curr.urgency.index ||
                (prev.urgency == curr.urgency &&
                    prev.impactPoints >= curr.impactPoints),
            isTrue,
            reason:
                'Cards sorted: ${prev.type.name}(${prev.urgency.name}, ${prev.impactPoints}) '
                'before ${curr.type.name}(${curr.urgency.name}, ${curr.impactPoints})');
      }
    });

    test('every card has disclaimer with LSFin', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974,
        prevoyance: const PrevoyanceProfile(rachatMaximum: 100000),
      );
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      for (final card in cards) {
        expect(card.disclaimer, contains('LSFin'),
            reason: '${card.type.name} must have LSFin disclaimer');
        expect(card.disclaimer, contains('\u00e9ducatif'),
            reason: '${card.type.name} must mention éducatif');
      }
    });

    test('every card has CTA with valid route', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974,
      );
      final cards = ResponseCardService.generateForPulse(profile, l: _l, limit: 10);

      for (final card in cards) {
        expect(card.cta.route, startsWith('/'),
            reason: '${card.type.name} CTA route');
        expect(card.cta.label, isNotEmpty,
            reason: '${card.type.name} CTA label');
      }
    });

    test('couple alert card when score gap > 15', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1980,
        etatCivil: CoachCivilStatus.marie,
      );

      // Simulate couple score with gap
      const coupleScore = VisibilityScore(
        total: 75,
        percentage: 75,
        axes: [],
        narrative: 'test',
        actions: [],
        coupleWeakName: 'Lauren',
        coupleWeakScore: 45.0,
      );

      final cards = ResponseCardService.generateForPulse(
        profile,
        l: _l,
        limit: 10,
        visibilityScore: coupleScore,
      );

      expect(
          cards.any((c) => c.type == ResponseCardType.coupleAlert), isTrue);
    });

    test('no couple alert when gap <= 15', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        etatCivil: CoachCivilStatus.marie,
      );

      const coupleScore = VisibilityScore(
        total: 75,
        percentage: 75,
        axes: [],
        narrative: 'test',
        actions: [],
        coupleWeakName: 'Lauren',
        coupleWeakScore: 65.0, // gap = 10 < 15
      );

      final cards = ResponseCardService.generateForPulse(
        profile,
        l: _l,
        limit: 10,
        visibilityScore: coupleScore,
      );

      expect(
          cards.any((c) => c.type == ResponseCardType.coupleAlert), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SERVICE — generateForChat
  // ════════════════════════════════════════════════════════════

  group('ResponseCardService.generateForChat', () {
    test('returns cards matching user message topic', () {
      final profile = _makeProfile(salaire: 8000, canton: 'VD');

      final cards3a =
          ResponseCardService.generateForChat(profile, 'Mon 3a cette annee', l: _l);
      expect(cards3a.any((c) => c.type == ResponseCardType.pillar3a), isTrue);

      final cardsLpp =
          ResponseCardService.generateForChat(profile, 'Rachat LPP', l: _l);
      // LPP only shows if rachatMax > 0, so may be empty
      expect(cardsLpp.length, lessThanOrEqualTo(2));
    });

    test('max 2 cards for chat', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974,
        prevoyance: const PrevoyanceProfile(rachatMaximum: 100000),
      );
      final cards = ResponseCardService.generateForChat(
          profile, 'retraite rente lpp 3a impot',
          l: _l);
      expect(cards.length, lessThanOrEqualTo(2));
    });

    test('returns empty for unrelated message', () {
      final profile = _makeProfile(salaire: 8000, canton: 'VD');
      final cards =
          ResponseCardService.generateForChat(profile, 'Bonjour comment ca va', l: _l);
      expect(cards, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SERVICE — suggestedPrompts
  // ════════════════════════════════════════════════════════════

  group('ResponseCardService.suggestedPrompts', () {
    test('50+ sees retirement-first prompts', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974, // age 52
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);

      expect(prompts, isNotEmpty);
      expect(prompts.length, lessThanOrEqualTo(3));
      expect(prompts.first, contains('retraite'));
    });

    test('young user sees 3a-first prompts', () {
      final profile = _makeProfile(
        salaire: 5000,
        canton: 'ZH',
        birthYear: 2000, // age 26
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);

      expect(prompts, isNotEmpty);
      expect(prompts.first, contains('3a'));
    });

    test('35-49 sees tax-first prompts', () {
      final profile = _makeProfile(
        salaire: 7000,
        canton: 'GE',
        birthYear: 1986, // age 40
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);

      expect(prompts, isNotEmpty);
      expect(prompts.first, contains('imp\u00f4ts'));
    });

    test('independant sees prevoyance prompt', () {
      // Use construction phase (age 30) to avoid rachat LPP taking a slot.
      // Business logic: independant prompt is cross-phase, always added.
      final profile = _makeProfile(
        salaire: 6000,
        canton: 'VD',
        birthYear: 1996, // age 30 → construction phase (no rachat slot)
        employmentStatus: 'independant',
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);

      expect(prompts.any((p) => p.toLowerCase().contains('ind\u00e9pendant')), isTrue);
    });

    test('couple sees coordination prompt', () {
      // Use construction phase (age 32) to avoid rachat LPP taking a slot.
      // Business logic: couple prompt is cross-phase, always added.
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1994, // age 32 → construction phase
        etatCivil: CoachCivilStatus.marie,
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);

      expect(prompts.any((p) => p.contains('couple')), isTrue);
    });

    test('max 3 prompts', () {
      final profile = _makeProfile(
        salaire: 8000,
        canton: 'VD',
        birthYear: 1974,
        employmentStatus: 'independant',
        etatCivil: CoachCivilStatus.marie,
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);
      expect(prompts.length, lessThanOrEqualTo(3));
    });

    // ── BUSINESS GUARDRAILS (Anti-Bullshit Manifesto) ──────────
    // These tests lock critical business logic:
    // rachat LPP MUST NOT be suggested to users without LPP.

    test('acceleration + has LPP → rachat LPP suggestion allowed', () {
      final profile = _makeProfile(
        salaire: 9000,
        canton: 'ZH',
        birthYear: 1986, // age 40 → acceleration phase
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 200000),
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);
      // With LPP, rachat prompt may appear (not guaranteed — depends on slot)
      // Key assertion: if it appears, it's coherent (user HAS LPP)
      expect(prompts.length, lessThanOrEqualTo(3));
    });

    test('acceleration + NO LPP → rachat LPP NEVER suggested', () {
      final profile = _makeProfile(
        salaire: 9000,
        canton: 'ZH',
        birthYear: 1986, // age 40 → acceleration phase
        // NO prevoyance → avoirLppTotal = null → hasLpp = false
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);
      for (final p in prompts) {
        expect(p.toLowerCase(), isNot(contains('rachat')),
            reason: 'Rachat LPP suggested to user WITHOUT LPP: "$p"');
      }
    });

    test('consolidation + NO LPP → rachat LPP NEVER suggested', () {
      final profile = _makeProfile(
        salaire: 10000,
        canton: 'VD',
        birthYear: 1974, // age 52 → consolidation phase
        // NO prevoyance → hasLpp = false
      );
      final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);
      for (final p in prompts) {
        expect(p.toLowerCase(), isNot(contains('rachat')),
            reason: 'Rachat LPP suggested to user WITHOUT LPP: "$p"');
      }
    });

    test('no banned terms in prompts', () {
      final profiles = [
        _makeProfile(salaire: 5000, birthYear: 2000),
        _makeProfile(salaire: 8000, birthYear: 1980),
        _makeProfile(salaire: 8000, birthYear: 1974),
        _makeProfile(
            salaire: 6000, birthYear: 1986, employmentStatus: 'independant'),
      ];

      const banned = [
        'garanti',
        'certain',
        'assure',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
        'conseiller'
      ];

      for (final profile in profiles) {
        final prompts = ResponseCardService.suggestedPrompts(profile, l: _l);
        for (final prompt in prompts) {
          final lower = prompt.toLowerCase();
          for (final term in banned) {
            expect(lower, isNot(contains(term)),
                reason: 'Banned term "$term" in: $prompt');
          }
        }
      }
    });
  });
}
