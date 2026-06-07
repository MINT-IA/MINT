import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/local_fallback_service.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

void main() {
  setUp(RegulatorySyncService.clearCache);
  tearDown(RegulatorySyncService.clearCache);

  // ── Topic detection via keywords ────────────────────────────────

  group('generateFallback — topic matching', () {
    test('matches 3a topic from "pilier 3a" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Comment fonctionne le pilier 3a ?',
      );
      expect(response, contains('3e pilier'));
      expect(response, contains('7\u00a0258'));
      expect(response, contains('marge déductible'));
      expect(response, isNot(contains('avec avantage fiscal')));
      expect(response, isNot(contains('En 2025')));
    });

    test('scores independent no-LPP 3a question as expert guidance', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
      ).toLowerCase();

      expect(response, contains('marge 3a à vérifier'));
      expect(response, contains('min(20'));
      expect(response, contains('revenu déterminant'));
      expect(response, contains('donnée manquante'));
      expect(response, contains('indépendant'));
      expect(response, contains('sans lpp'));
      expect(response, contains('revenu net d\'activité'));
      expect(response, contains('plafond'));
      expect(response, contains('budget mensuel'));
      expect(response, contains('provenance et fraîcheur'));
      expect(response, contains('revenu professionnel: donnée absente'));
      expect(response,
          contains('versements 3a planifiés: aucun versement planifié connu'));
      expect(response, contains('date par champ non affichée'));
      expect(response, contains('confirmations manquantes'));
      expect(response, contains('comparer avant de verser'));
      expect(response, contains('carte de décision'));
      expect(response, contains('marge légale 3a'));
      expect(response, contains('capacité mensuelle'));
      expect(response, contains('couverture risque'));
      expect(response, contains('fiscalité'));
      expect(response, contains('prochaine action prudente'));
      expect(response,
          contains('ne traite pas le plafond comme un montant à verser'));
      expect(response, contains('lpp facultative'));
      expect(response, contains('couverture accident'));
      expect(response, contains('perte de gain'));
      expect(response, contains('liquidité'));
      expect(response, isNot(contains('7\u00a0258')));
      expect(response, isNot(contains('salarié')));
      expect(response, isNot(contains('ouvre')));
      expect(response, isNot(contains('fintech')));
      expect(response, isNot(contains('versement 3a 2026')));
      expect(response, isNot(contains('impact fiscal indicatif')));
      expect(response, isNot(contains('2\u00a0218 chf')));
      expect(response, isNot(contains('7\u00a0137 chf')));
      expect(response, isNot(contains('3\u00a0068 chf')));
      expect(response, isNot(contains('meilleur')));
      expect(response, isNot(contains('optimal')));
      expect(response, isNot(contains('sans risque')));
      expect(response, isNot(contains('marge légale restante serait')));
      expect(response, isNot(contains('86\u00a0400')));
      expect(response, isNot(contains('11\u00a0280')));
    });

    test('independent no-LPP 3a guidance uses profile facts when available',
        () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
        context: const CoachContext(
          archetype: 'independent_no_lpp',
          dataReliability: {
            'independentNetProfessionalIncomeAnnual': 'userInput',
          },
          knownValues: {
            'self_employed_net_income_annual': 86400,
            'annual_3a_contribution': 6000,
          },
        ),
      )!;

      expect(response, contains('Marge 3a à vérifier'));
      expect(response, contains('86\u00a0400\u00a0CHF/an'));
      expect(response, contains('6\u00a0000\u00a0CHF/an'));
      expect(response, contains('11\u00a0280\u00a0CHF/an'));
      expect(response, contains('marge légale restante'));
      expect(response, contains('Faits MINT'));
      expect(response, contains('Provenance et fraîcheur'));
      expect(response, contains('revenu professionnel: saisie dans MINT'));
      expect(response, contains('versements 3a planifiés: plan MINT'));
      expect(response, contains('date par champ non affichée'));
      expect(response, contains('Confirmations manquantes'));
      expect(response, contains('Comparer avant de verser'));
      expect(response, contains('base professionnelle déclarée dans MINT'));
      expect(response, contains('revenu déterminant fiscal/AVS'));
      expect(response, contains('Carte de décision'));
      expect(response, contains('Marge légale 3a'));
      expect(response, contains('Capacité mensuelle'));
      expect(response, contains('Couverture risque'));
      expect(response, contains('Fiscalité'));
      expect(response, contains('LPP facultative'));
      expect(response, contains('Prochaine action prudente'));
      expect(response, contains('Marge légale ≠ capacité mensuelle'));
      expect(response, isNot(contains('2\u00a0218')));
      expect(response, isNot(contains('Impact fiscal indicatif')));
      expect(response, isNot(contains('meilleur')));
      expect(response, isNot(contains('optimal')));
      expect(response, isNot(contains('sans risque')));
    });

    test('independent no-LPP context does not require magic prompt wording',
        () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Combien verser en 3a ?',
        context: const CoachContext(
          archetype: 'independent_no_lpp',
          knownValues: {
            'self_employed_net_income_annual': 86400,
            'annual_3a_contribution': 6000,
          },
        ),
      )!;

      expect(response, contains('Marge 3a à vérifier'));
      expect(response, contains('11\u00a0280\u00a0CHF/an'));
      expect(response, contains('revenu déterminant fiscal/AVS'));
      expect(response, contains('Carte de décision'));
      expect(response, contains('Capacité mensuelle'));
      expect(response, contains('Prochaine action prudente'));
      expect(response, isNot(contains('Versement 3a 2026')));
    });

    test('independent no-LPP 3a guidance labels unknown provenance honestly',
        () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Combien verser en 3a ?',
        context: const CoachContext(
          archetype: 'independent_no_lpp',
          knownValues: {
            'self_employed_net_income_annual': 86400,
            'annual_3a_contribution': 6000,
          },
        ),
      )!;

      expect(response, contains('Provenance et fraîcheur'));
      expect(response, contains('revenu professionnel: source non affichée'));
      expect(response, contains('date par champ non affichée'));
      expect(response, isNot(contains('source bancaire connectée')));
    });

    test('independent no-LPP 3a guidance maps income provenance labels', () {
      const expectedLabels = {
        'estimated': 'estimation MINT',
        'userInput': 'saisie dans MINT',
        'crossValidated': 'saisie vérifiée',
        'certificate': 'document scanné',
        'openBanking': 'source bancaire connectée',
      };

      for (final entry in expectedLabels.entries) {
        final response = LocalFallbackService.generateSpecializedFallback(
          userMessage: 'Combien verser en 3a ?',
          context: CoachContext(
            archetype: 'independent_no_lpp',
            dataReliability: {
              'independentNetProfessionalIncomeAnnual': entry.key,
            },
            knownValues: const {
              'self_employed_net_income_annual': 86400,
              'annual_3a_contribution': 6000,
            },
          ),
        )!;

        expect(
          response,
          contains('revenu professionnel: ${entry.value}'),
          reason: 'source ${entry.key} should map to ${entry.value}',
        );
        expect(response, contains('date par champ non affichée'));
      }
    });

    test('independent no-LPP 3a guidance uses explicit 3a plan provenance', () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Combien verser en 3a ?',
        context: const CoachContext(
          archetype: 'independent_no_lpp',
          dataReliability: {
            'independentNetProfessionalIncomeAnnual': 'userInput',
            'annual_3a_contribution': 'certificate',
          },
          knownValues: {
            'self_employed_net_income_annual': 86400,
            'annual_3a_contribution': 6000,
          },
        ),
      )!;

      expect(response, contains('revenu professionnel: saisie dans MINT'));
      expect(response, contains('versements 3a planifiés: document scanné'));
      expect(response, isNot(contains('versements 3a planifiés: plan MINT')));
    });

    test('independent no-LPP 3a guidance uses production 3a source key', () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Combien verser en 3a ?',
        context: const CoachContext(
          archetype: 'independent_no_lpp',
          dataReliability: {
            'independentNetProfessionalIncomeAnnual': 'userInput',
            'plannedContributions.3a': 'userInput',
          },
          knownValues: {
            'self_employed_net_income_annual': 86400,
            'annual_3a_contribution': 6000,
          },
        ),
      )!;

      expect(response, contains('revenu professionnel: saisie dans MINT'));
      expect(response, contains('versements 3a planifiés: saisie dans MINT'));
      expect(response, isNot(contains('versements 3a planifiés: plan MINT')));
    });

    test('independent no-LPP 3a guidance labels missing income and plan', () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
        context: const CoachContext(archetype: 'independent_no_lpp'),
      )!;

      expect(response, contains('Donnée manquante côté MINT'));
      expect(
          response, contains('revenu professionnel: donnée absente côté MINT'));
      expect(
        response,
        contains(
          'versements 3a planifiés: aucun versement planifié connu dans MINT',
        ),
      );
      expect(response, contains('date par champ non affichée'));
      expect(response, isNot(contains('marge légale restante serait')));
    });

    test('does not use no-LPP guidance when independent user declares LPP', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Je suis indépendant avec LPP, combien verser en 3a ?',
      ).toLowerCase();

      expect(response, isNot(contains('lpp facultative')));
      expect(response, isNot(contains('budget mensuel')));
    });

    test('does not use no-LPP guidance for conflicting LPP affiliation wording',
        () {
      final response = LocalFallbackService.generateFallback(
        userMessage:
            'Je suis indépendant avec LPP, pas de caisse de pension claire, combien verser en 3a ?',
      ).toLowerCase();

      expect(response, isNot(contains('lpp facultative')));
      expect(response, isNot(contains('budget mensuel')));
    });

    test('recognizes no-LPP wording without the LPP acronym', () {
      final response = LocalFallbackService.generateFallback(
        userMessage:
            'Je suis freelance pas de caisse de pension, que faire avec mon troisième pilier ?',
      ).toLowerCase();

      expect(response, contains('revenu net d\'activité'));
      expect(response, contains('budget mensuel'));
      expect(response, contains('lpp facultative'));
    });

    test('uses regulatory cache for 3a ceilings in local guidance', () {
      RegulatorySyncService.setMockCache({
        'pillar3a.income_rate_without_lpp': 0.25,
        'pillar3a.max_without_lpp': 40000,
        'pillar3a.max_with_lpp': 8000,
      });

      final specialized = LocalFallbackService.generateFallback(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
      );
      expect(specialized, contains('25\u00a0%'));
      expect(specialized, contains('40\u00a0000\u00a0CHF/an'));
      expect(specialized, isNot(contains('36\u00a0288')));

      final generic = LocalFallbackService.generateFallback(
        userMessage: 'Comment fonctionne le pilier 3a ?',
      );
      expect(generic, contains('8\u00a0000\u00a0CHF/an'));
      expect(generic, contains('25\u00a0% du revenu net'));
      expect(generic, contains('max. 40\u00a0000\u00a0CHF/an'));
    });

    test('matches lpp topic from "2e pilier" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Parle-moi du 2e pilier',
      );
      expect(response, contains('LPP'));
      expect(response, contains('6,8'));
    });

    test('matches avs topic from "rente avs" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Ma rente avs sera de combien ?',
      );
      expect(response, contains('AVS'));
      expect(response, contains('30\u00a0240'));
    });

    test('matches impots topic from "impôt" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Comment reduire mes impôts ?',
      );
      expect(response, contains('LIFD'));
      expect(response, contains('déductions'));
      expect(response, contains('impact indicatif'));
      expect(response, isNot(contains('économie d\'impôt')));
      expect(response, isNot(contains('économie fiscale')));
      expect(response, isNot(contains('avantage fiscal')));
      expect(response, isNot(contains('tax saving')));
    });

    test('matches budget topic from "épargne" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: "J'ai besoin d'aide avec mon épargne",
      );
      expect(response, contains('50/30/20'));
    });

    test('matches immobilier topic from "hypotheque" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Je cherche une hypotheque pour ma maison',
      );
      expect(response, contains('FINMA'));
      expect(response, contains('20\u00a0%'));
    });

    test('matches retraite topic from "pension" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Ma pension sera suffisante ?',
      );
      expect(response, contains('3 piliers'));
    });

    test('matches assurances topic from "lamal" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Combien coute la lamal ?',
      );
      expect(response, contains('LAMal'));
    });

    test('matches succession topic from "héritage" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: "J'ai recu un héritage, que faire ?",
      );
      expect(response, contains('CC art. 457'));
    });

    test('matches dette topic from "crédit" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'J\'ai un crédit à rembourser',
      );
      expect(response, contains('Caritas'));
    });
  });

  // ── Generic fallback ────────────────────────────────────────────

  group('generateFallback — generic', () {
    test('returns generic response when no topic matches', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Quel temps fait-il ?',
      );
      expect(response, contains('simulateurs'));
      expect(response, contains('profil'));
    });
  });

  group('generateSpecializedFallback', () {
    test('returns independent no-LPP 3a guidance for specialized topic', () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Je suis indépendant sans LPP, combien verser en 3a ?',
      )!
          .toLowerCase();

      expect(response, contains('revenu net d\'activité'));
      expect(response, contains('budget mensuel'));
      expect(response, isNot(contains('7\u00a0258')));
    });

    test('returns null for generic 3a topic', () {
      final response = LocalFallbackService.generateSpecializedFallback(
        userMessage: 'Comment fonctionne le pilier 3a ?',
      );

      expect(response, isNull);
    });
  });

  // ── Compliance ──────────────────────────────────────────────────

  group('generateFallback — compliance', () {
    test('every response contains standard disclaimer', () {
      final topics = [
        'pilier 3a',
        '2e pilier',
        'rente avs',
        'impôts',
        'budget',
        'hypotheque',
        'pension',
        'lamal',
        'héritage',
        'crédit',
        'random question',
        'indépendant sans lpp combien verser en 3a',
      ];
      for (final topic in topics) {
        final response = LocalFallbackService.generateFallback(
          userMessage: topic,
        );
        expect(response, contains('éducatif'),
            reason: 'Missing disclaimer for "$topic"');
      }
    });

    test('every response contains retry message', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Test',
      );
      expect(response, contains('réessaie'));
    });

    test('no response contains banned terms', () {
      const banned = [
        'garanti',
        'certain',
        'assuré',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
        'conseiller',
      ];
      final topics = [
        'pilier 3a',
        '2e pilier',
        'rente avs',
        'impôts',
        'budget',
        'hypotheque',
        'pension',
        'lamal',
        'héritage',
        'crédit',
        'random',
        'indépendant sans lpp combien verser en 3a',
      ];
      for (final topic in topics) {
        final response = LocalFallbackService.generateFallback(
          userMessage: topic,
        ).toLowerCase();
        for (final term in banned) {
          expect(response, isNot(contains(term)),
              reason: 'Found banned term "$term" in response for "$topic"');
        }
      }
    });
  });

  // ── detectedTopics override ─────────────────────────────────────

  group('generateFallback — detectedTopics override', () {
    test('uses detectedTopics when provided, ignoring message keywords', () {
      // Message mentions budget, but detectedTopics forces 3a
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Mon budget est serré',
        detectedTopics: ['3a'],
      );
      expect(response, contains('3e pilier'));
    });

    test('can target independent no-LPP 3a guidance from detectedTopics', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Question courte',
        detectedTopics: ['independent_no_lpp_3a'],
      ).toLowerCase();

      expect(response, contains('revenu net d\'activité'));
      expect(response, contains('budget mensuel'));
      expect(response, contains('lpp facultative'));
      expect(response, isNot(contains('7\u00a0258')));
    });

    test('prioritizes independent no-LPP 3a over generic detected 3a topic',
        () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Question courte',
        detectedTopics: ['3a', 'independent_no_lpp_3a'],
      ).toLowerCase();

      expect(response, contains('revenu net d\'activité'));
      expect(response, contains('budget mensuel'));
      expect(response, isNot(contains('7\u00a0258')));
    });

    test('falls back to generic if detectedTopics has unknown topic', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Test',
        detectedTopics: ['cryptocurrency'],
      );
      // Should get generic response
      expect(response, contains('simulateurs'));
    });
  });

  // ── Legal references in templates ───────────────────────────────

  group('generateFallback — legal references', () {
    test('3a template references OPP3 art. 7', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Parle moi du 3a',
      );
      expect(response, contains('OPP3 art. 7'));
    });

    test('lpp template references LPP art. 14', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Mon lpp',
      );
      expect(response, contains('LPP art. 14'));
    });

    test('avs template references LAVS art. 21-40', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Mon avs',
      );
      expect(response, contains('LAVS art. 21-40'));
    });
  });
}
