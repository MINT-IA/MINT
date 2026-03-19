import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/local_fallback_service.dart';

void main() {
  // ── Topic detection via keywords ────────────────────────────────

  group('generateFallback — topic matching', () {
    test('matches 3a topic from "pilier 3a" keyword', () {
      final response = LocalFallbackService.generateFallback(
        userMessage: 'Comment fonctionne le pilier 3a ?',
      );
      expect(response, contains('3e pilier'));
      expect(response, contains('7\u00a0258'));
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

  // ── Compliance ──────────────────────────────────────────────────

  group('generateFallback — compliance', () {
    test('every response contains standard disclaimer', () {
      final topics = [
        'pilier 3a', '2e pilier', 'rente avs',
        'impôts', 'budget', 'hypotheque',
        'pension', 'lamal', 'héritage',
        'crédit', 'random question',
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
        'garanti', 'certain', 'assuré', 'sans risque',
        'optimal', 'meilleur', 'parfait', 'conseiller',
      ];
      final topics = [
        'pilier 3a', '2e pilier', 'rente avs', 'impôts',
        'budget', 'hypotheque', 'pension', 'lamal',
        'héritage', 'crédit', 'random',
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
