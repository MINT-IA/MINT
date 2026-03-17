import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/factory/letter_generator_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // generateBuybackRequest
  // ---------------------------------------------------------------------------
  group('LetterGeneratorService — generateBuybackRequest', () {
    test('title is "Demande de Rachat LPP"', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Julien Battaglia',
        userAddress: 'Route de Crans 10, 3963 Crans-Montana',
        insuranceNumber: '756.1234.5678.90',
      );
      expect(letter.title, 'Demande de Rachat LPP');
    });

    test('content includes user name', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Julien Battaglia',
        userAddress: 'Route de Crans 10',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter.content, contains('Julien Battaglia'));
    });

    test('content includes user address', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Rue du Rhone 42, 1204 Geneve',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter.content, contains('Rue du Rhone 42, 1204 Geneve'));
    });

    test('content includes insurance number', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Addr',
        insuranceNumber: '756.9999.8888.77',
      );
      expect(letter.content, contains('756.9999.8888.77'));
    });

    test('content mentions EPL and divorce blocking conditions', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Addr',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter.content, contains('EPL'));
      expect(letter.content, contains('divorce'));
    });

    test('content includes today date in ISO format', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Addr',
        insuranceNumber: '756.0000.0000.00',
      );
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(letter.content, contains(today));
    });

    test('disclaimer contains legal footer about responsibility', () {
      final letter = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Addr',
        insuranceNumber: '756.0000.0000.00',
      );
      expect(letter.disclaimer, contains('conseil juridique'));
      expect(letter.disclaimer, contains('responsabilit'));
      expect(letter.disclaimer, contains('Mint'));
    });
  });

  // ---------------------------------------------------------------------------
  // generateTaxCertificateRequest
  // ---------------------------------------------------------------------------
  group('LetterGeneratorService — generateTaxCertificateRequest', () {
    test('title is "Demande d\'attestation fiscale"', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Lauren Smith',
        year: 2025,
      );
      expect(letter.title, contains('attestation fiscale'));
    });

    test('content includes the requested year', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Test',
        year: 2024,
      );
      expect(letter.content, contains('2024'));
    });

    test('content includes user name', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Lauren Smith',
        year: 2025,
      );
      expect(letter.content, contains('Lauren Smith'));
    });

    test('content mentions 3a and LPP', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Test',
        year: 2025,
      );
      expect(letter.content, contains('3a'));
      expect(letter.content, contains('LPP'));
    });

    test('disclaimer is same legal footer as buyback letter', () {
      final buyback = LetterGeneratorService.generateBuybackRequest(
        userName: 'Test',
        userAddress: 'Addr',
        insuranceNumber: '756.0000.0000.00',
      );
      final tax = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Test',
        year: 2025,
      );
      expect(tax.disclaimer, buyback.disclaimer);
    });

    test('content includes today date', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Test',
        year: 2025,
      );
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(letter.content, contains(today));
    });
  });

  // ---------------------------------------------------------------------------
  // GeneratedLetter data class
  // ---------------------------------------------------------------------------
  group('GeneratedLetter — data class', () {
    test('holds title, content, and disclaimer', () {
      final letter = GeneratedLetter(
        title: 'Test Title',
        content: 'Test Content',
        disclaimer: 'Test Disclaimer',
      );
      expect(letter.title, 'Test Title');
      expect(letter.content, 'Test Content');
      expect(letter.disclaimer, 'Test Disclaimer');
    });
  });
}
