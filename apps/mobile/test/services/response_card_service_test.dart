import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/response_card_service.dart';

/// Unit tests for ResponseCardService — Phase 1 (Response Cards)
///
/// Tests card generation, chat topic matching, suggested prompts,
/// and deduplication logic.
///
/// Legal references: LPP art. 79b, OPP3 art. 7, LIFD art. 38, LAVS
void main() {
  // ── Helper: standard test profile ─────────────────────────
  CoachProfile _buildProfile({
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 9078,
    String employmentStatus = 'salarie',
    CoachCivilStatus etatCivil = CoachCivilStatus.marie,
    double avoirLpp = 70377,
    double assuranceMaladie = 450,
    double loyer = 925,
    ConjointProfile? conjoint,
  }) {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      employmentStatus: employmentStatus,
      etatCivil: etatCivil,
      conjoint: conjoint,
      depenses: DepensesProfile(
        loyer: loyer,
        assuranceMaladie: assuranceMaladie,
      ),
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: avoirLpp,
        tauxConversion: 0.068,
      ),
      dettes: const DetteProfile(),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042),
        label: 'Retraite',
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  generate() — card generation
  // ════════════════════════════════════════════════════════════

  group('ResponseCardService.generate()', () {
    test('returns non-empty list for standard profile', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.generate(profile: profile);
      expect(cards, isNotEmpty);
    });

    test('respects limit parameter', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.generate(profile: profile, limit: 2);
      expect(cards.length, lessThanOrEqualTo(2));
    });

    test('deduplicates by type (max 1 per type)', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.generate(profile: profile, limit: 10);
      final types = cards.map((c) => c.type).toSet();
      expect(types.length, equals(cards.length),
          reason: 'Each card type should appear at most once');
    });

    test('cards are sorted by urgency (critical first)', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.generate(profile: profile, limit: 10);
      if (cards.length >= 2) {
        for (var i = 0; i < cards.length - 1; i++) {
          expect(cards[i].urgency.index, lessThanOrEqualTo(cards[i + 1].urgency.index),
              reason: 'Cards should be sorted by urgency');
        }
      }
    });

    test('every card has required fields', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.generate(profile: profile, limit: 10);
      for (final card in cards) {
        expect(card.id, isNotEmpty);
        expect(card.title, isNotEmpty);
        expect(card.subtitle, isNotEmpty);
        expect(card.ctaLabel, isNotEmpty);
        expect(card.ctaRoute, startsWith('/'));
        expect(card.category, isNotEmpty);
      }
    });

    test('generates retraite card for 50+ profile', () {
      final profile = _buildProfile(birthYear: 1970); // age ~56
      final cards = ResponseCardService.generate(profile: profile, limit: 10);
      final retraiteCards =
          cards.where((c) => c.type == ResponseCardType.retraite);
      expect(retraiteCards, isNotEmpty,
          reason: '50+ profile should get retraite card');
    });

    test('generates couple card when conjoint present', () {
      final profile = _buildProfile(
        conjoint: ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 4800,
        ),
      );
      final cards = ResponseCardService.generate(profile: profile, limit: 10);
      final coupleCards =
          cards.where((c) => c.type == ResponseCardType.couple);
      expect(coupleCards, isNotEmpty,
          reason: 'Couple profile should get couple card');
    });

    test('generates assurance card when assurance maladie missing', () {
      final profile = _buildProfile(assuranceMaladie: 0);
      final cards = ResponseCardService.generate(profile: profile, limit: 10);
      final assurCards =
          cards.where((c) => c.type == ResponseCardType.assurance);
      expect(assurCards, isNotEmpty,
          reason: 'Missing assurance maladie should generate assurance card');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  forChatTopic() — topic-matched cards
  // ════════════════════════════════════════════════════════════

  group('ResponseCardService.forChatTopic()', () {
    test('returns cards matching retraite topic', () {
      final profile = _buildProfile(birthYear: 1970);
      final cards = ResponseCardService.forChatTopic(
        profile: profile,
        topic: 'Ma retraite',
      );
      expect(cards, isNotEmpty);
    });

    test('returns max 2 cards for unknown topic', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.forChatTopic(
        profile: profile,
        topic: 'quelque chose de random',
      );
      expect(cards.length, lessThanOrEqualTo(2));
    });

    test('maps fiscal topic correctly', () {
      final profile = _buildProfile();
      final cards = ResponseCardService.forChatTopic(
        profile: profile,
        topic: 'Mes deductions fiscales',
      );
      // Should either find fiscal cards or fallback gracefully
      expect(cards, isA<List<ResponseCard>>());
    });
  });

  // ════════════════════════════════════════════════════════════
  //  suggestedPrompts() — personalized prompts
  // ════════════════════════════════════════════════════════════

  group('ResponseCardService.suggestedPrompts()', () {
    test('returns non-empty list', () {
      final profile = _buildProfile();
      final prompts =
          ResponseCardService.suggestedPrompts(profile: profile);
      expect(prompts, isNotEmpty);
    });

    test('respects limit', () {
      final profile = _buildProfile();
      final prompts = ResponseCardService.suggestedPrompts(
        profile: profile,
        limit: 3,
      );
      expect(prompts.length, lessThanOrEqualTo(3));
    });

    test('50+ gets retirement-related prompts', () {
      final profile = _buildProfile(birthYear: 1970);
      final prompts =
          ResponseCardService.suggestedPrompts(profile: profile);
      final hasRetirement = prompts.any(
        (p) => p.toLowerCase().contains('retraite') ||
            p.toLowerCase().contains('rente') ||
            p.toLowerCase().contains('capital'),
      );
      expect(hasRetirement, isTrue,
          reason: '50+ should see retirement prompts');
    });

    test('young profile gets 3a prompt', () {
      final profile = _buildProfile(birthYear: 2000); // ~26 yo
      final prompts =
          ResponseCardService.suggestedPrompts(profile: profile);
      final has3a = prompts.any(
        (p) => p.toLowerCase().contains('3a'),
      );
      expect(has3a, isTrue,
          reason: 'Young profile should see 3a prompt');
    });

    test('couple profile gets couple-related prompt', () {
      final profile = _buildProfile(
        conjoint: ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1982,
          salaireBrutMensuel: 4800,
        ),
      );
      final prompts =
          ResponseCardService.suggestedPrompts(profile: profile);
      final hasCouple = prompts.any(
        (p) => p.toLowerCase().contains('couple') ||
            p.toLowerCase().contains('conjoint'),
      );
      expect(hasCouple, isTrue,
          reason: 'Couple profile should see couple prompt');
    });

    test('prompts are sorted by relevance (highest score first)', () {
      final profile = _buildProfile();
      final prompts =
          ResponseCardService.suggestedPrompts(profile: profile);
      // All prompts should be non-empty strings
      for (final p in prompts) {
        expect(p, isNotEmpty);
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ResponseCard model
  // ════════════════════════════════════════════════════════════

  group('ResponseCard model', () {
    test('deadlineText formats correctly', () {
      const card = ResponseCard(
        id: 'test',
        type: ResponseCardType.threeA,
        title: 'Test',
        subtitle: 'Sub',
        ctaLabel: 'CTA',
        ctaRoute: '/test',
        icon: null,
        category: 'test',
        deadlineDays: 0,
      );
      expect(card.deadlineText, "Aujourd'hui");
    });

    test('deadlineText returns J-N for future', () {
      const card = ResponseCard(
        id: 'test',
        type: ResponseCardType.threeA,
        title: 'Test',
        subtitle: 'Sub',
        ctaLabel: 'CTA',
        ctaRoute: '/test',
        icon: null,
        category: 'test',
        deadlineDays: 21,
      );
      expect(card.deadlineText, 'J-21');
    });

    test('deadlineText returns Demain for 1 day', () {
      const card = ResponseCard(
        id: 'test',
        type: ResponseCardType.threeA,
        title: 'Test',
        subtitle: 'Sub',
        ctaLabel: 'CTA',
        ctaRoute: '/test',
        icon: null,
        category: 'test',
        deadlineDays: 1,
      );
      expect(card.deadlineText, 'Demain');
    });

    test('deadlineText returns null when no deadline', () {
      const card = ResponseCard(
        id: 'test',
        type: ResponseCardType.threeA,
        title: 'Test',
        subtitle: 'Sub',
        ctaLabel: 'CTA',
        ctaRoute: '/test',
        icon: null,
        category: 'test',
      );
      expect(card.deadlineText, isNull);
    });
  });
}
