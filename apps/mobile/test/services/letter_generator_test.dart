import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/factory/letter_generator_service.dart';

/// Tests for LetterGeneratorService — automated letter templates.
///
/// Validates buyback request and tax certificate request letters.
/// Compliance: disclaimer must be present, no conseil juridique.
void main() {
  group('LetterGeneratorService — buyback request', () {
    test('Generate Buyback Request Letter', () async {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Jean Dupont',
        userAddress: 'Rue du Lac 1, 1000 Lausanne',
        insuranceNumber: '756.1234.5678.90',
      );

      expect(letter.title, contains('Demande de Rachat'));
      expect(letter.content, contains('Jean Dupont'));
      expect(letter.content, contains('756.1234.5678.90'));
      expect(letter.disclaimer, contains('conseil juridique'));
    });

    test('buyback request includes user address', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Marie Schmidt',
        userAddress: 'Bahnhofstrasse 10, 8001 Zürich',
        insuranceNumber: '756.9999.8888.77',
      );
      expect(letter.content, contains('Bahnhofstrasse 10, 8001 Zürich'));
    });

    test('buyback request mentions rachat keyword', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test User',
        userAddress: 'Test Address',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter.content.toLowerCase(), contains('rachat'));
    });

    test('buyback request includes EPL warning (LPP art. 79b al. 3)', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Test',
        insuranceNumber: '756.0000.0000.00',
      );
      // Should mention EPL or propriété du logement
      expect(letter.content, contains('propriété du logement'));
    });

    test('buyback request includes date', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Test',
        insuranceNumber: '756.0000.0000.00',
      );
      // Date should be in ISO format YYYY-MM-DD
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(letter.content, contains(today));
    });

    test('buyback request title is GeneratedLetter', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Test',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter, isA<GeneratedLetter>());
      expect(letter.title, isNotEmpty);
      expect(letter.content, isNotEmpty);
      expect(letter.disclaimer, isNotEmpty);
    });
  });

  group('LetterGeneratorService — tax certificate request', () {
    test('Template includes disclaimer footer', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Jean',
        year: 2024,
      );
      expect(letter.disclaimer, isNotEmpty);
      expect(letter.disclaimer, contains('responsabilité'));
    });

    test('tax certificate request includes year', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Marie',
        year: 2025,
      );
      expect(letter.content, contains('2025'));
    });

    test('tax certificate request mentions 3a and LPP', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Pierre',
        year: 2024,
      );
      expect(letter.content, contains('3a'));
      expect(letter.content, contains('LPP'));
    });

    test('tax certificate request includes user name', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Sophie Martin',
        year: 2024,
      );
      expect(letter.content, contains('Sophie Martin'));
    });

    test('tax certificate request title contains attestation', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Test',
        year: 2024,
      );
      expect(letter.title.toLowerCase(), contains('attestation'));
    });
  });

  group('LetterGeneratorService — compliance', () {
    test('disclaimer mentions Mint application', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Test',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter.disclaimer, contains('Mint'));
    });

    test('disclaimer mentions no conseil juridique (compliance)', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Test',
        year: 2024,
      );
      expect(letter.disclaimer, contains('conseil juridique'));
    });
  });
}
