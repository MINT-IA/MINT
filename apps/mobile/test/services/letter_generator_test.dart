import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/factory/letter_generator_service.dart';

void main() {
  group('LetterGeneratorService', () {
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

    test('Template includes disclaimer footer', () {
      final letter = LetterGeneratorService.generateTaxCertificateRequest(
        userName: 'Jean',
        year: 2024,
      );
      expect(letter.disclaimer, isNotEmpty);
      expect(letter.disclaimer, contains('responsabilité'));
    });
  });
}
