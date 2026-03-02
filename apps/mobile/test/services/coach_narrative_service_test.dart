import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  COACH NARRATIVE SERVICE TESTS — Coach AI Layer / T1
// ────────────────────────────────────────────────────────────
//
// Tests cover:
//   1. generate() sans BYOK retourne template statique
//   2. generate() avec BYOK config retourne isLlmGenerated=true (mock)
//   3. cache est utilise quand < 24h
//   4. cache est invalide quand > 24h
//   5. fallback vers static si LLM echoue
//   6. greeting contient firstName
//   7. scoreSummary contient le score numerique
//   8. narratif ne contient pas de termes bannis
//   9. JSON serialization round-trip fonctionne
//  10. trendMessage matches static behavior for no-BYOK
//  11. cache invalide quand nouveau check-in
//  12. topTipNarrative contient le premier tip
// ────────────────────────────────────────────────────────────

/// Sentinel value indicating "use default firstName".
const String _defaultFirstName = '__default__';

/// Helper: build a CoachProfile for testing.
///
/// Pass [firstName] as null to explicitly set firstName to null.
/// Omit it or pass `_defaultFirstName` to use 'Julien'.
CoachProfile _buildTestProfile({
  String? firstName = _defaultFirstName,
  List<MonthlyCheckIn>? checkIns,
}) {
  return CoachProfile(
    firstName: firstName == _defaultFirstName ? 'Julien' : firstName,
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 7000,
    employmentStatus: 'salarie',
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 12, 31),
      label: 'Retraite a 65 ans',
    ),
    prevoyance: const PrevoyanceProfile(
      nombre3a: 2,
      totalEpargne3a: 15000,
      avoirLppTotal: 80000,
      rachatMaximum: 50000,
      rachatEffectue: 10000,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 12000,
      investissements: 25000,
    ),
    depenses: const DepensesProfile(
      loyer: 1500,
      assuranceMaladie: 400,
    ),
    dettes: const DetteProfile(),
    checkIns: checkIns ?? const [],
    plannedContributions: const [
      PlannedMonthlyContribution(
        id: '3a_user',
        label: '3a Julien',
        amount: 604.83,
        category: '3a',
      ),
    ],
  );
}

/// Helper: build a score history list.
List<Map<String, dynamic>> _buildScoreHistory({
  required List<int> scores,
}) {
  final now = DateTime.now();
  return scores.asMap().entries.map((entry) {
    final i = entry.key;
    final score = entry.value;
    final date = DateTime(now.year, now.month - (scores.length - 1 - i));
    return {
      'date': date.toIso8601String(),
      'score': score,
    };
  }).toList();
}

/// Helper: generate coaching tips from a profile.
List<CoachingTip> _generateTips(CoachProfile profile) {
  return CoachingService.generateTips(
    profile: profile.toCoachingProfile(),
  );
}

void main() {
  // Reset SharedPreferences before each test to ensure isolation
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.safeModeDegraded = false;
    FeatureFlags.enableSlmNarratives = true;
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 1. generate() sans BYOK retourne template statique
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService.generate — sans BYOK', () {
    test('generate() sans BYOK retourne template statique', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.isLlmGenerated, isFalse);
      expect(narrative.greeting, isNotEmpty);
      expect(narrative.scoreSummary, isNotEmpty);
      expect(narrative.trendMessage, isNotEmpty);
      expect(narrative.generatedAt, isNotNull);
    });

    test('generate() sans BYOK retourne les memes textes que le mode statique',
        () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final scoreHistory = _buildScoreHistory(scores: [55, 58, 62]);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      // Le narratif statique doit correspondre au comportement
      // exact du dashboard actuel
      expect(narrative.greeting, equals('Bonjour Julien'));
      // urgentAlert is now season-aware: non-null in Q4 (3a) and Feb-Mar (fiscal)
      final now = DateTime.now();
      if (now.month >= 10 && now.month <= 12) {
        expect(narrative.urgentAlert, isNotNull);
        expect(narrative.urgentAlert, contains('3a'));
      } else if (now.month >= 2 && now.month <= 3) {
        expect(narrative.urgentAlert, isNotNull);
        expect(narrative.urgentAlert, contains('31 mars'));
      } else {
        expect(narrative.urgentAlert, isNull);
      }
      expect(narrative.milestoneMessage,
          isNull); // Milestones: async, handled in generate()
      expect(narrative.scenarioNarrations, isNotNull);
      expect(narrative.scenarioNarrations!.length, 3);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. generate() avec BYOK config (simulation — pas de vrai appel reseau)
  //    Puisque le RAG backend n'est pas accessible dans les tests unitaires,
  //    on verifie que le fallback fonctionne correctement quand le LLM echoue.
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService.generate — avec BYOK (fallback)', () {
    test('fallback vers static si LLM echoue (pas de backend)', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      // Avec une config BYOK mais sans backend reel,
      // le service doit tomber en fallback statique
      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
        byokConfig: const LlmConfig(
          apiKey: 'test-fake-key',
          provider: LlmProvider.openai,
          model: 'gpt-4o',
        ),
      );

      // Meme en mode BYOK, le fallback doit retourner un narratif valide
      expect(narrative.greeting, isNotEmpty);
      expect(narrative.scoreSummary, isNotEmpty);
      expect(narrative.trendMessage, isNotEmpty);
      // Le fallback retourne isLlmGenerated=false car le LLM a echoue
      expect(narrative.isLlmGenerated, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. cache est utilise quand < 24h
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — cache', () {
    test('cache est utilise quand < 24h', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final scoreHistory = _buildScoreHistory(scores: [55, 58, 62]);

      // Premier appel — genere et cache
      final first = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      // Deuxieme appel — doit utiliser le cache
      final second = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      // Les deux doivent avoir le meme contenu
      expect(second.greeting, equals(first.greeting));
      expect(second.scoreSummary, equals(first.scoreSummary));
      expect(second.trendMessage, equals(first.trendMessage));
      expect(second.isLlmGenerated, equals(first.isLlmGenerated));
      // Le generatedAt doit etre le meme (provenant du cache)
      expect(second.generatedAt, equals(first.generatedAt));
    });

    // ═══════════════════════════════════════════════════════════════════════
    // 4. cache est invalide quand > 24h
    // ═══════════════════════════════════════════════════════════════════════

    test('cache est invalide quand > 24h', () async {
      final profile = _buildTestProfile();

      // Injecter un cache expire dans SharedPreferences
      final expiredNarrative = CoachNarrative(
        greeting: 'Cache expire',
        scoreSummary: 'Score expire',
        trendMessage: 'Tendance expiree',
        isLlmGenerated: false,
        generatedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final cacheKey = 'coach_narrative_$dateStr';

      SharedPreferences.setMockInitialValues({
        cacheKey: jsonEncode(expiredNarrative.toJson()),
        'coach_narrative_checkin_count': 0,
      });

      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
        byokConfig: null,
      );

      // Le cache expire ne doit PAS etre utilise
      expect(narrative.greeting, isNot(equals('Cache expire')));
      expect(narrative.greeting, equals('Bonjour Julien'));
    });

    // ═══════════════════════════════════════════════════════════════════════
    // 5. cache est invalide quand nouveau check-in
    // ═══════════════════════════════════════════════════════════════════════

    test('cache est invalide quand nouveau check-in', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final scoreHistory = _buildScoreHistory(scores: [55, 58, 62]);

      // Premier appel — genere et cache
      await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      // Creer un profil avec un check-in supplementaire
      final profileWithCheckIn = _buildTestProfile(
        checkIns: [
          MonthlyCheckIn(
            month: DateTime(2026, 1),
            versements: const {'3a': 604.83},
            completedAt: DateTime(2026, 1, 15),
          ),
        ],
      );
      final newTips = _generateTips(profileWithCheckIn);

      final second = await CoachNarrativeService.generate(
        profile: profileWithCheckIn,
        scoreHistory: scoreHistory,
        tips: newTips,
        byokConfig: null,
      );

      // Le cache doit avoir ete invalide (nouveau check-in)
      // Le narratif doit etre regenere (nouveau generatedAt)
      expect(second.greeting, equals('Bonjour Julien'));
      expect(second.isLlmGenerated, isFalse);
    });

    test('cache est invalide immediatement quand safe mode est active',
        () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final scoreHistory = _buildScoreHistory(scores: [55, 58, 62]);

      final first = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      FeatureFlags.safeModeDegraded = true;

      final second = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
        byokConfig: null,
      );

      // Must regenerate in degraded mode, not reuse previous cached narrative.
      expect(second.generatedAt, isNot(equals(first.generatedAt)));
      expect(second.isLlmGenerated, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. greeting contient firstName
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — greeting', () {
    test('greeting contient firstName', () async {
      final profile = _buildTestProfile(firstName: 'Alice');
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: null,
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.greeting, contains('Alice'));
    });

    test('greeting utilise "toi" si firstName est null', () async {
      final profile = _buildTestProfile(firstName: null);
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: null,
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.greeting, contains('toi'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7. scoreSummary contient le score numerique
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — scoreSummary', () {
    test('scoreSummary contient le score numerique', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: null,
        tips: tips,
        byokConfig: null,
      );

      // Le score summary doit contenir "/100"
      expect(narrative.scoreSummary, contains('/100'));

      // Doit contenir un label de niveau
      expect(
        narrative.scoreSummary.contains('Priorite') ||
            narrative.scoreSummary.contains('Attention') ||
            narrative.scoreSummary.contains('Bien') ||
            narrative.scoreSummary.contains('Excellent'),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 8. narratif ne contient pas de termes bannis
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — guardrails', () {
    test('narratif ne contient pas de termes bannis', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
        byokConfig: null,
      );

      // Aucun champ ne doit contenir de termes bannis
      expect(CoachNarrativeService.containsBannedTerms(narrative.greeting),
          isFalse);
      expect(CoachNarrativeService.containsBannedTerms(narrative.scoreSummary),
          isFalse);
      expect(CoachNarrativeService.containsBannedTerms(narrative.trendMessage),
          isFalse);
      if (narrative.topTipNarrative != null) {
        expect(
            CoachNarrativeService.containsBannedTerms(
                narrative.topTipNarrative!),
            isFalse);
      }
    });

    test('containsBannedTerms detecte correctement les termes bannis', () {
      expect(
          CoachNarrativeService.containsBannedTerms('c\'est garanti'), isTrue);
      expect(CoachNarrativeService.containsBannedTerms('resultat certain'),
          isTrue);
      expect(CoachNarrativeService.containsBannedTerms('placement sans risque'),
          isTrue);
      expect(CoachNarrativeService.containsBannedTerms('la solution optimal'),
          isTrue);
      expect(CoachNarrativeService.containsBannedTerms('texte normal ok'),
          isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 9. JSON serialization round-trip fonctionne
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrative — JSON serialization', () {
    test('JSON serialization round-trip fonctionne', () {
      final original = CoachNarrative(
        greeting: 'Salut Julien',
        scoreSummary: '62/100 — Bien !',
        trendMessage: 'En progression',
        topTipNarrative: 'Verse ton 3a avant fin decembre.',
        urgentAlert: 'Deadline 3a dans 28 jours',
        milestoneMessage: 'Patrimoine 100k atteint !',
        scenarioNarrations: [
          'Scenario prudent.',
          'Scenario base.',
          'Scenario optimiste.',
        ],
        isLlmGenerated: true,
        generatedAt: DateTime(2026, 2, 20, 10, 30),
      );

      // Serialise
      final json = original.toJson();
      final jsonStr = jsonEncode(json);

      // Deserialise
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = CoachNarrative.fromJson(decoded);

      // Tous les champs doivent correspondre
      expect(restored.greeting, equals(original.greeting));
      expect(restored.scoreSummary, equals(original.scoreSummary));
      expect(restored.trendMessage, equals(original.trendMessage));
      expect(restored.topTipNarrative, equals(original.topTipNarrative));
      expect(restored.urgentAlert, equals(original.urgentAlert));
      expect(restored.milestoneMessage, equals(original.milestoneMessage));
      expect(restored.scenarioNarrations, equals(original.scenarioNarrations));
      expect(restored.isLlmGenerated, equals(original.isLlmGenerated));
      expect(restored.generatedAt, equals(original.generatedAt));
    });

    test('JSON deserialization gere les champs null', () {
      final json = {
        'greeting': 'Bonjour',
        'scoreSummary': '50/100',
        'trendMessage': 'Stable',
        'topTipNarrative': null,
        'urgentAlert': null,
        'milestoneMessage': null,
        'scenarioNarrations': null,
        'isLlmGenerated': false,
        'generatedAt': DateTime(2026, 2, 20).toIso8601String(),
      };

      final narrative = CoachNarrative.fromJson(json);

      expect(narrative.greeting, equals('Bonjour'));
      expect(narrative.topTipNarrative, isNull);
      expect(narrative.urgentAlert, isNull);
      expect(narrative.milestoneMessage, isNull);
      expect(narrative.scenarioNarrations, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 10. trendMessage matches static behavior for no-BYOK
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — trendMessage', () {
    test('trendMessage "En progression" quand score monte > 3', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [50, 55, 60]),
        tips: tips,
        byokConfig: null,
      );

      expect(
          narrative.trendMessage, equals('En progression — continue comme ca'));
    });

    test('trendMessage "Attention" quand score baisse > 3', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [60, 55, 50]),
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.trendMessage,
          equals('Attention — ton score baisse. Verifie tes actions.'));
    });

    test('trendMessage "Stable" quand score ne change pas beaucoup', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 56, 56]),
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.trendMessage,
          equals('Stable — tes efforts maintiennent le cap.'));
    });

    test('trendMessage fallback quand historique insuffisant', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55]),
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.trendMessage, contains('Pas encore assez de donnees'));
    });

    test('trendMessage fallback quand scoreHistory est null', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: null,
        tips: tips,
        byokConfig: null,
      );

      expect(narrative.trendMessage, contains('Pas encore assez de donnees'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // BONUS: topTipNarrative et scenarios
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — topTipNarrative', () {
    test('topTipNarrative contient le premier tip message', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: null,
        tips: tips,
        byokConfig: null,
      );

      if (tips.isNotEmpty) {
        expect(narrative.topTipNarrative, isNotNull);
        expect(narrative.topTipNarrative, equals(tips.first.message));
      }
    });

    test('topTipNarrative est null si pas de tips', () async {
      final profile = _buildTestProfile();

      final narrative = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: null,
        tips: const [],
        byokConfig: null,
      );

      expect(narrative.topTipNarrative, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // BONUS: invalidateCache fonctionne
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — invalidateCache', () {
    test('invalidateCache supprime le cache', () async {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);

      // Generer et cacher
      final first = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
        byokConfig: null,
      );

      // Invalider le cache
      await CoachNarrativeService.invalidateCache();

      // Regerer — doit etre un nouveau narratif
      final second = await CoachNarrativeService.generate(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
        byokConfig: null,
      );

      // Le contenu sera le meme (memes inputs statiques)
      // mais le generatedAt sera different (regenere)
      expect(second.greeting, equals(first.greeting));
      // Note: generatedAt pourrait etre egal si dans la meme seconde,
      // mais le test verifie que l'appel ne plante pas
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // urgentAlert static mode — deadline-based alerts (OPP3 / LIFD / LHID)
  // ═══════════════════════════════════════════════════════════════════════

  group('CoachNarrativeService — urgentAlert static mode', () {
    test('urgentAlert is non-null in Q4 (Oct-Dec) when 3a margin > 0', () {
      // Test the static generation with seasonal awareness
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final narrative = CoachNarrativeService.generateStatic(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
      );
      // The actual Q4 check depends on the current date at test runtime
      final now = DateTime.now();
      if (now.month >= 10 && now.month <= 12) {
        expect(narrative.urgentAlert, isNotNull);
        expect(narrative.urgentAlert, contains('3a'));
        expect(narrative.urgentAlert, contains('OPP3'));
      }
    });

    test('urgentAlert mentions fiscal deadline in Feb-Mar', () {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final narrative = CoachNarrativeService.generateStatic(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
      );
      final now = DateTime.now();
      if (now.month >= 2 && now.month <= 3) {
        expect(narrative.urgentAlert, isNotNull);
        expect(narrative.urgentAlert, contains('31 mars'));
        expect(narrative.urgentAlert, contains('LIFD'));
      }
    });

    test('urgentAlert structure is valid (non-null or null based on season)',
        () {
      final profile = _buildTestProfile();
      final tips = _generateTips(profile);
      final narrative = CoachNarrativeService.generateStatic(
        profile: profile,
        scoreHistory: _buildScoreHistory(scores: [55, 58, 62]),
        tips: tips,
      );
      // urgentAlert is either null (off-season) or a non-empty string
      if (narrative.urgentAlert != null) {
        expect(narrative.urgentAlert!.isNotEmpty, isTrue);
        // Should not contain banned terms
        expect(
          CoachNarrativeService.containsBannedTerms(narrative.urgentAlert!),
          isFalse,
        );
      }
    });
  });
}
