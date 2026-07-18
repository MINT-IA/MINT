import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = <String>['fr', 'en', 'de', 'es', 'it', 'pt'];

const _handoffKeys = <String>[
  'retirementLppRegulationHandoffTitle',
  'retirementLppRegulationHandoffBoundary',
  'retirementLppRegulationHandoffPrivacy',
];

const _questionBodyKeys = <String>[
  'retirementLppRegulationQuestionBuybackBody',
  'retirementLppRegulationQuestionConversionBody',
  'retirementLppRegulationQuestionFlexibleRetirementBody',
  'retirementLppRegulationQuestionDisabilityBody',
  'retirementLppRegulationQuestionSurvivorsBody',
  'retirementLppRegulationQuestionDivorceBody',
];

const _declarationKeys = <String>[
  'lppRegulationReviewRecoveryBody',
  'lppRegulationReviewTitle',
  'lppRegulationReviewBody',
  'lppRegulationReviewAcceptError',
  'lppRegulationReviewRecordError',
  'retirementLppRegulationReferenceTitle',
  'retirementLppRegulationReferenceBody',
  'retirementLppRegulationConfirmedAtLabel',
  'retirementLppRegulationRecoveryCta',
];

final _possessiveFundPatterns = <String, RegExp>{
  'fr': RegExp(
    r"\b(?:ta|ton|tes|ma|mon|mes|notre|votre)\s+(?:caisse|institution de prévoyance)|\bmon dossier actuel\b",
    caseSensitive: false,
  ),
  'en': RegExp(
    r'\b(?:your|my|our)\s+pension fund\b|\bmy current file\b',
    caseSensitive: false,
  ),
  'de': RegExp(
    r'\b(?:dein|mein|unser)(?:e|er|en|em|es)?\s+(?:Pensionskasse|Vorsorgeeinrichtung)\b|\bmeines aktuellen Dossiers\b',
    caseSensitive: false,
  ),
  'es': RegExp(
    r'\b(?:tu|tus|mi|mis|nuestra|nuestro)\s+(?:caja de pensiones|institución de previsión)\b|\bmi expediente actual\b',
    caseSensitive: false,
  ),
  'it': RegExp(
    r'\b(?:tua|tue|mia|mie|nostra|nostro)\s+cassa(?: pension[ei])?\b|\bmio dossier attuale\b',
    caseSensitive: false,
  ),
  'pt': RegExp(
    r'\b(?:tua|tuas|minha|minhas|nossa|nosso)\s+caixa de pensões\b|\bmeu processo atual\b',
    caseSensitive: false,
  ),
};

final _neutralInstitutionPatterns = <String, RegExp>{
  'fr': RegExp(
    r"(?:l’|une )institution de prévoyance(?: concernée| compétente)?|l’institution (?:concernée|compétente)",
    caseSensitive: false,
  ),
  'en': RegExp(
    r'\b(?:relevant|responsible|any) pension fund\b',
    caseSensitive: false,
  ),
  'de': RegExp(
    r'\b(?:zuständig\w*|eine) Vorsorgeeinrichtung\b',
    caseSensitive: false,
  ),
  'es': RegExp(
    r'\b(?:la|ninguna|una) institución de previsión(?: correspondiente| competente)?\b',
    caseSensitive: false,
  ),
  'it': RegExp(
    r"(?:l’|un )istituto di previdenza(?: interessato| competente)?",
    caseSensitive: false,
  ),
  'pt': RegExp(
    r'\b(?:a|uma) instituição de previdência(?: em causa| competente)?\b',
    caseSensitive: false,
  ),
};

const _declarationTokens = <String, String>{
  'fr': 'déclar',
  'en': 'declar',
  'de': 'angabe',
  'es': 'declar',
  'it': 'dichiar',
  'pt': 'declara',
};

const _unverifiedTokens = <String, String>{
  'fr': 'non vérifi',
  'en': 'unverified',
  'de': 'nicht verifiziert',
  'es': 'no verificada',
  'it': 'non verificata',
  'pt': 'não verificada',
};

final _objectConfirmedPatterns = <String, RegExp>{
  'fr': RegExp(
    r'\brevue?\b|\bvérification\b|règlement[^.]{0,80}\b(?:revu|confirmé|vérifié)\b|\breconfirmer le règlement\b',
    caseSensitive: false,
  ),
  'en': RegExp(
    r'\breview(?:ed)?\b|rules[^.]{0,80}\b(?:reviewed|confirmed|verified)\b|\breconfirm the rules\b',
    caseSensitive: false,
  ),
  'de': RegExp(
    r'\bPrüfung\b|\bprüfen\b|Vorsorgereglement[^.]{0,80}\b(?:geprüft|bestätigt|verifiziert)\b|\bReglement erneut bestätigen\b',
    caseSensitive: false,
  ),
  'es': RegExp(
    r'\brevisi[oó]n\b|\brevisar\b|reglamento[^.]{0,80}\b(?:revisado|confirmado|verificado)\b|\breconfirmar el reglamento\b',
    caseSensitive: false,
  ),
  'it': RegExp(
    r'\besame\b|\besamin\w*\b|\brevisione\b|regolamento[^.]{0,80}\b(?:esaminato|confermato|verificato)\b|\briconferma(?:re)? il regolamento\b',
    caseSensitive: false,
  ),
  'pt': RegExp(
    r'\brevis[aã]o\b|\brevisto\b|\banalis\w*\b|regulamento[^.]{0,80}\b(?:revisto|confirmado|verificado)\b|\breconfirmar o regulamento\b',
    caseSensitive: false,
  ),
};

const _noAdviceTokens = <String, String>{
  'fr': 'MINT ne recommande aucune option',
  'en': 'MINT does not recommend any option',
  'de': 'MINT empfiehlt keine Option',
  'es': 'MINT no recomienda ninguna opción',
  'it': 'MINT non raccomanda alcuna opzione',
  'pt': 'A MINT não recomenda nenhuma opção',
};

const _specialistTokens = <String, String>{
  'fr': 'un·e spécialiste',
  'en': 'specialist',
  'de': 'Fachperson',
  'es': 'persona especialista',
  'it': 'persona specialista',
  'pt': 'pessoa especialista',
};

const _conversionLabels = <String, String>{
  'fr': 'Taux de conversion et formes de prestation',
  'en': 'Conversion rates and benefit forms',
  'de': 'Umwandlungssätze und Leistungsformen',
  'es': 'Tipos de conversión y formas de prestación',
  'it': 'Aliquote di conversione e forme di prestazione',
  'pt': 'Taxas de conversão e formas de prestação',
};

const _declaredYearLabels = <String, String>{
  'fr': 'Année de référence déclarée',
  'en': 'Declared reference year',
  'de': 'Angegebenes Referenzjahr',
  'es': 'Año de referencia declarado',
  'it': 'Anno di riferimento dichiarato',
  'pt': 'Ano de referência declarado',
};

Map<String, String> _arb(String locale) {
  final decoded = jsonDecode(
    File('lib/l10n/app_$locale.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return <String, String>{
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

String _copy(Map<String, String> arb, String locale, String key) {
  final value = arb[key];
  expect(value, isNotNull, reason: 'lang=$locale key=$key value=<missing>');
  return value!;
}

void main() {
  test('LPP regulation copy keeps declaration authority across all six ARBs',
      () {
    for (final locale in _locales) {
      final arb = _arb(locale);
      final possessivePattern = _possessiveFundPatterns[locale]!;
      final institutionPattern = _neutralInstitutionPatterns[locale]!;

      for (final key in <String>[
        'docScanLppPlanDocumentDescription',
        ..._handoffKeys,
        ..._questionBodyKeys,
      ]) {
        final value = _copy(arb, locale, key);
        expect(
          possessivePattern.hasMatch(value),
          isFalse,
          reason: 'lang=$locale key=$key value=$value',
        );
      }

      for (final key in <String>[..._handoffKeys, ..._questionBodyKeys]) {
        final value = _copy(arb, locale, key);
        expect(
          institutionPattern.hasMatch(value),
          isTrue,
          reason: 'lang=$locale key=$key value=$value',
        );
      }

      final declarationCopy = _copy(
        arb,
        locale,
        'retirementLppRegulationReferenceBody',
      ).toLowerCase();
      expect(
        declarationCopy,
        contains(_declarationTokens[locale]!),
        reason: 'lang=$locale declarationCopy=$declarationCopy',
      );
      expect(
        declarationCopy,
        contains(_unverifiedTokens[locale]!),
        reason: 'lang=$locale declarationCopy=$declarationCopy',
      );

      final objectPattern = _objectConfirmedPatterns[locale]!;
      for (final key in _declarationKeys) {
        final value = _copy(arb, locale, key);
        expect(
          objectPattern.hasMatch(value),
          isFalse,
          reason: 'lang=$locale key=$key value=$value',
        );
      }

      final boundary = _copy(
        arb,
        locale,
        'retirementLppRegulationHandoffBoundary',
      );
      expect(
        boundary,
        contains(_noAdviceTokens[locale]!),
        reason:
            'lang=$locale key=retirementLppRegulationHandoffBoundary value=$boundary',
      );
      expect(
        boundary,
        contains(_specialistTokens[locale]!),
        reason:
            'lang=$locale key=retirementLppRegulationHandoffBoundary value=$boundary',
      );

      expect(
        _copy(arb, locale, 'retirementLppRegulationQuestionConversion'),
        _conversionLabels[locale],
        reason:
            'lang=$locale key=retirementLppRegulationQuestionConversion value=${arb['retirementLppRegulationQuestionConversion']}',
      );
      expect(
        _copy(arb, locale, 'retirementLppRegulationLegalYearLabel'),
        _declaredYearLabels[locale],
        reason:
            'lang=$locale key=retirementLppRegulationLegalYearLabel value=${arb['retirementLppRegulationLegalYearLabel']}',
      );
    }
  });
}
