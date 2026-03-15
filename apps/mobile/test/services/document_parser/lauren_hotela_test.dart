import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';

// ────────────────────────────────────────────────────────────
//  GOLDEN TEST: Lauren's HOTELA certificate (test/golden/Lauren/)
// ────────────────────────────────────────────────────────────

/// Simulated OCR text from Lauren's HOTELA certificate (JPEG photo).
const String laurenHotelaOcrText = """
HOTELA
Prévoyance professionnelle
Certificat d'assurance LPP au 01.01.2026

Unica LPP/LPP / 16842 / SIX SENSES CRANS-MONTANA / 3963 CRANS-MONTANA
SIERRE

Données personnelles
Nom BATTAGLIA Femme
Prénom LAUREN ELIZABETH Date d'affiliation 09.04.2023
Date de naissance 23.06.1982 No AVS 756.0578.6371.69

Salaires et cotisation projetés CHF
Salaire annuel brut AVS 67'000.00
Salaire coordonné Part de l'assuré Pour l'année
 2'842.20 9'684.40

Cotisation annuelle
Bonification de vieillesse annuelle 4'060.20

Capital de prévoyance
Capital total 19'620.30
dont prestations de libre passage apportées
dont rachat déjà effectués depuis l'affiliation 9'000.00

Minimum LPP 10'203.25
Prestation de sortie 19'620.30

Prestations à l'âge de la retraite
 60 61 62 63 64 65
Capital retraite 138'610.75 147'651.40 156'805.00 166'073.40 175'457.70 184'958.15
Rente annuelle vieillesse 8'059.28 8'860.80 8'721.80 10'926.40 11'310.00 12'571.50
Rente annuelle pour enfant 1'168.00 1'171.40 1'744.20 2'185.30 2'310.60 2'514.30

Les prestations de retraite anticipée sous forme de rentes sont améliorées.

Prestations en cas d'invalidité
Rente annuelle d'invalidité 10'240.20
Rente annuelle d'enfant d'invalide 2'048.00
Libération du paiement des cotisations après un délai d'incapacité de travail de 90 jours 4'060.20

Prestations en cas de décès Avant âge retraite Après âge retraite
Rente annuelle de partenaire 5'150.30
Rente annuelle de patrimoine 10'150.30 7'543.30
Rente annuelle d'orphelin 4'060.20
Capital 2'515.20

Encouragement à la propriété du logement
Versement anticipé pour logement effectué Non
Mise en gage Non
Avoir disponible pour EPL 0.00

Possibilités de rachat
Montant maximum 52'948.55

HOTELA Fonds de prévoyance
Montreux, le 19.01.2026
""";

void main() {
  late ExtractionResult result;

  setUpAll(() {
    result = LppCertificateParser.parseLppCertificate(laurenHotelaOcrText);
    print('\n=== LAUREN HOTELA — ${result.fieldCount} fields ===');
    for (final f in result.fields) {
      print('  ${f.fieldName}: ${f.value} (${f.confidence})');
    }
    print('===\n');
  });

  group('Lauren HOTELA certificate — golden test', () {
    test('extracts capital total = 19620.30', () {
      final field = _find(result, 'lpp_total');
      expect(field, isNotNull, reason: 'lpp_total not found');
      expect(field!.value, closeTo(19620.30, 1.0));
    });

    test('extracts minimum LPP (obligatoire) = 10203.25', () {
      final field = _find(result, 'lpp_obligatoire');
      expect(field, isNotNull, reason: 'lpp_obligatoire not found');
      expect(field!.value, closeTo(10203.25, 1.0));
    });

    test('infers surobligatoire = 9417.05', () {
      final field = _find(result, 'lpp_surobligatoire');
      expect(field, isNotNull, reason: 'lpp_surobligatoire not found');
      expect(field!.value, closeTo(9417.05, 1.0));
    });

    test('extracts salaire brut AVS = 67000', () {
      final field = _find(result, 'lpp_determining_salary');
      expect(field, isNotNull, reason: 'lpp_determining_salary not found');
      expect(field!.value, closeTo(67000.0, 1.0));
    });

    test('extracts rachat max = 52948.55', () {
      final field = _find(result, 'buyback_potential');
      expect(field, isNotNull, reason: 'buyback_potential not found');
      expect(field!.value, closeTo(52948.55, 1.0));
    });

    test('extracts rente invalidité = 10240.20', () {
      final field = _find(result, 'disability_coverage');
      expect(field, isNotNull, reason: 'disability_coverage not found');
      expect(field!.value, closeTo(10240.20, 1.0));
    });

    test('extracts rente partenaire = 5150.30', () {
      final field = _find(result, 'death_coverage');
      expect(field, isNotNull, reason: 'death_coverage not found');
      expect(field!.value, closeTo(5150.30, 1.0));
    });

    test('extracts capital projeté 65 = 184958.15', () {
      final field = _find(result, 'projected_capital_65');
      expect(field, isNotNull, reason: 'projected_capital_65 not found');
      expect(field!.value, closeTo(184958.15, 1.0));
    });

    test('extracts at least 7 fields', () {
      expect(result.fieldCount, greaterThanOrEqualTo(7));
    });
  });
}

ExtractedField? _find(ExtractionResult result, String name) {
  try {
    return result.fields.firstWhere((f) => f.fieldName == name);
  } catch (_) {
    return null;
  }
}
