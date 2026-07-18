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

const _recoveryBodyKeys = <String>[
  'retirementLppRegulationRecoveryLegacyBody',
  'retirementLppRegulationRecoveryBody',
  'retirementLppRegulationRecoveryMismatchBody',
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
  'retirementLppRegulationRecoveryTitle',
  'retirementLppRegulationRecoveryCta',
  ..._recoveryBodyKeys,
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

final _declarationPatterns = <String, RegExp>{
  'fr': RegExp(r'déclar', caseSensitive: false),
  'en': RegExp(r'declar', caseSensitive: false),
  'de': RegExp(r'angab|angeben|deklar', caseSensitive: false),
  'es': RegExp(r'declar', caseSensitive: false),
  'it': RegExp(r'dichiar', caseSensitive: false),
  'pt': RegExp(r'declara', caseSensitive: false),
};

const _unverifiedTokens = <String, String>{
  'fr': 'non vérifi',
  'en': 'unverified',
  'de': 'nicht verifiziert',
  'es': 'no verificada',
  'it': 'non verificata',
  'pt': 'não verificada',
};

final _confirmedObjectPatterns = <String, RegExp>{
  'fr': RegExp(
    r'^(?:Vérifier|Examiner|Revoir) (?:ce |le )?(?:règlement|document)\b|\b(?:règlement|document) (?:est|a été) (?:revu|confirmé|vérifié)\b|\b(?:examen|revue|vérification) (?:de|du) (?:ce |le )?(?:règlement|document) est confirmé|\breconfirmer (?:le règlement|le document)\b',
    caseSensitive: false,
  ),
  'en': RegExp(
    r'\b(?:rules|document) (?:are|is|were|was|have been|has been) (?:reviewed|confirmed|verified)\b|\breview of (?:these|the) rules is confirmed\b|\breconfirm (?:the rules|the document)\b',
    caseSensitive: false,
  ),
  'de': RegExp(
    r'\b(?:Reglement|Dokument) (?:ist|wurde|wird) (?:geprüft|bestätigt|verifiziert)\b|\bPrüfung dieses Reglements ist bestätigt\b|\b(?:Reglement|Dokument) erneut bestätigen\b',
    caseSensitive: false,
  ),
  'es': RegExp(
    r'\b(?:reglamento|documento) (?:está|fue|ha sido) (?:revisado|confirmado|verificado)\b|\brevisión de este reglamento está confirmada\b|\b(?:reconfirmar|volver a confirmar) (?:el reglamento|el documento)\b',
    caseSensitive: false,
  ),
  'it': RegExp(
    r'\b(?:regolamento|documento) (?:è|è stato|viene) (?:esaminato|confermato|verificato)\b|\bè confermato l’esame di questo regolamento\b|\briconferma(?:re)? (?:il regolamento|il documento)\b',
    caseSensitive: false,
  ),
  'pt': RegExp(
    r'\b(?:regulamento|documento) (?:é|foi|está) (?:revisto|confirmado|verificado)\b|\ba revisão deste regulamento está confirmada\b|\breconfirmar (?:o regulamento|o documento)\b',
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

const _approvedDocScanDescriptions = <String, String>{
  'fr':
      'Ajouter un règlement de prévoyance, sans en extraire de montant ni de droit.',
  'en':
      'Add pension fund rules without extracting any amounts or entitlements.',
  'de':
      'Füge ein Vorsorgereglement hinzu, ohne Beträge oder Ansprüche daraus zu übernehmen.',
  'es': 'Añade un reglamento de previsión sin extraer importes ni derechos.',
  'it':
      'Aggiungi un regolamento di previdenza senza estrarre importi né diritti.',
  'pt':
      'Adiciona um regulamento de previdência sem extrair montantes nem direitos.',
};

const _approvedPrivacyCopy = <String, String>{
  'fr':
      'Le document original n’est ni joint à cette préparation ni transmis depuis cet écran à une institution de prévoyance ou à un·e spécialiste.',
  'en':
      'The original document is neither attached to this preparation nor sent from this screen to any pension fund or specialist.',
  'de':
      'Das Originaldokument wird dieser Vorbereitung weder beigefügt noch von diesem Bildschirm aus an eine Vorsorgeeinrichtung oder eine Fachperson übermittelt.',
  'es':
      'El documento original no se adjunta a esta preparación ni se transmite desde esta pantalla a ninguna institución de previsión ni a una persona especialista.',
  'it':
      'Il documento originale non viene allegato a questa preparazione né trasmesso da questa schermata a un istituto di previdenza o a una persona specialista.',
  'pt':
      'O documento original não é anexado a esta preparação nem transmitido, a partir deste ecrã, a uma instituição de previdência ou a uma pessoa especialista.',
};

const _approvedReferenceBodies = <String, String>{
  'fr':
      'L’origine indiquée est une déclaration non vérifiée. Elle ne confirme ni l’institution concernée, ni l’application du règlement à ta situation, ni tes droits, ni aucun montant.',
  'en':
      'The stated origin is an unverified declaration. It does not confirm the relevant pension fund, that the rules apply to your situation, any entitlements, or any amounts.',
  'de':
      'Die angegebene Herkunft ist eine nicht verifizierte Angabe. Sie bestätigt weder die zuständige Vorsorgeeinrichtung noch die Anwendbarkeit des Reglements auf deine Situation, Ansprüche oder Beträge.',
  'es':
      'El origen indicado es una declaración no verificada. No confirma la institución de previsión correspondiente, que el reglamento se aplique a tu situación, ningún derecho ni ningún importe.',
  'it':
      'L’origine indicata è una dichiarazione non verificata. Non conferma l’istituto di previdenza interessato, l’applicabilità del regolamento alla tua situazione, né diritti o importi.',
  'pt':
      'A origem indicada é uma declaração não verificada. Não confirma a instituição de previdência em causa, a aplicação do regulamento à tua situação, quaisquer direitos ou montantes.',
};

const _approvedRecoveryTitles = <String, String>{
  'fr': 'Déclaration d’origine à reconfirmer',
  'en': 'Origin declaration needs reconfirmation',
  'de': 'Herkunftsangabe erneut bestätigen',
  'es': 'Declaración de origen por reconfirmar',
  'it': 'Dichiarazione d’origine da riconfermare',
  'pt': 'Declaração de origem a reconfirmar',
};

const _approvedRecoveryCtas = <String, String>{
  'fr': 'Reconfirmer la déclaration',
  'en': 'Reconfirm the declaration',
  'de': 'Angabe erneut bestätigen',
  'es': 'Volver a confirmar la declaración',
  'it': 'Riconfermare la dichiarazione',
  'pt': 'Reconfirmar a declaração',
};

const _approvedRecoveryBodies = <String, List<String>>{
  'fr': <String>[
    'Une déclaration non vérifiée ne précise pas l’origine de ce règlement. Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni l’institution concernée, ni l’application du règlement à ta situation, ni tes droits ni aucun montant.',
    'Une déclaration non vérifiée existe, mais sa référence locale manque. Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni l’institution concernée, ni l’application du règlement à ta situation, ni tes droits ni aucun montant.',
    'Une déclaration non vérifiée ne correspond pas à sa référence locale et est masquée. Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni l’institution concernée, ni l’application du règlement à ta situation, ni tes droits ni aucun montant.',
  ],
  'en': <String>[
    'An unverified declaration does not identify the origin of these rules. Reconfirm it from the document. MINT does not infer the origin, the relevant pension fund, that the rules apply to your situation, any entitlements, or any amounts.',
    'An unverified declaration exists, but its local reference is missing. Reconfirm it from the document. MINT does not infer the origin, the relevant pension fund, that the rules apply to your situation, any entitlements, or any amounts.',
    'An unverified declaration does not match its local reference and is hidden. Reconfirm it from the document. MINT does not infer the origin, the relevant pension fund, that the rules apply to your situation, any entitlements, or any amounts.',
  ],
  'de': <String>[
    'Eine nicht verifizierte Angabe nennt die Herkunft dieses Reglements nicht. Bestätige sie anhand des Dokuments erneut. MINT leitet daraus nichts über die Herkunft, die zuständige Vorsorgeeinrichtung, die Anwendbarkeit des Reglements auf deine Situation, Ansprüche oder Beträge ab.',
    'Eine nicht verifizierte Angabe besteht, aber ihre lokale Referenz fehlt. Bestätige sie anhand des Dokuments erneut. MINT leitet daraus nichts über die Herkunft, die zuständige Vorsorgeeinrichtung, die Anwendbarkeit des Reglements auf deine Situation, Ansprüche oder Beträge ab.',
    'Eine nicht verifizierte Angabe stimmt nicht mit ihrer lokalen Referenz überein und wird ausgeblendet. Bestätige sie anhand des Dokuments erneut. MINT leitet daraus nichts über die Herkunft, die zuständige Vorsorgeeinrichtung, die Anwendbarkeit des Reglements auf deine Situation, Ansprüche oder Beträge ab.',
  ],
  'es': <String>[
    'Una declaración no verificada no precisa el origen de este reglamento. Vuelve a confirmarla a partir del documento. MINT no deduce de ella ni el origen, ni la institución de previsión correspondiente, ni la aplicabilidad del reglamento a tu situación, ni derechos ni importes.',
    'Existe una declaración no verificada, pero falta su referencia local. Vuelve a confirmarla a partir del documento. MINT no deduce de ella ni el origen, ni la institución de previsión correspondiente, ni la aplicabilidad del reglamento a tu situación, ni derechos ni importes.',
    'Una declaración no verificada no coincide con su referencia local y queda oculta. Vuelve a confirmarla a partir del documento. MINT no deduce de ella ni el origen, ni la institución de previsión correspondiente, ni la aplicabilidad del reglamento a tu situación, ni derechos ni importes.',
  ],
  'it': <String>[
    'Una dichiarazione non verificata non precisa l’origine di questo regolamento. Riconfermala a partire dal documento. MINT non ne deduce nulla sull’origine, sull’istituto di previdenza interessato, sull’applicabilità del regolamento alla tua situazione, su diritti o importi.',
    'Esiste una dichiarazione non verificata, ma manca il riferimento locale. Riconfermala a partire dal documento. MINT non ne deduce nulla sull’origine, sull’istituto di previdenza interessato, sull’applicabilità del regolamento alla tua situazione, su diritti o importi.',
    'Una dichiarazione non verificata non corrisponde al riferimento locale e viene nascosta. Riconfermala a partire dal documento. MINT non ne deduce nulla sull’origine, sull’istituto di previdenza interessato, sull’applicabilità del regolamento alla tua situazione, su diritti o importi.',
  ],
  'pt': <String>[
    'Uma declaração não verificada não identifica a origem deste regulamento. Volta a confirmá-la a partir do documento. A MINT não deduz daí a origem, a instituição de previdência em causa, a aplicação do regulamento à tua situação, quaisquer direitos ou montantes.',
    'Existe uma declaração não verificada, mas falta a referência local. Volta a confirmá-la a partir do documento. A MINT não deduz daí a origem, a instituição de previdência em causa, a aplicação do regulamento à tua situação, quaisquer direitos ou montantes.',
    'Uma declaração não verificada não corresponde à referência local e fica oculta. Volta a confirmá-la a partir do documento. A MINT não deduz daí a origem, a instituição de previdência em causa, a aplicação do regulamento à tua situação, quaisquer direitos ou montantes.',
  ],
};

const _recoveryDeclarationTokens = <String, String>{
  'fr': 'déclaration',
  'en': 'declaration',
  'de': 'Angabe',
  'es': 'declaración',
  'it': 'dichiarazione',
  'pt': 'declaração',
};

const _recoveryUnverifiedTokens = <String, String>{
  'fr': 'non vérifiée',
  'en': 'unverified',
  'de': 'nicht verifizierte',
  'es': 'no verificada',
  'it': 'non verificata',
  'pt': 'não verificada',
};

const _reconfirmFromDocumentTokens = <String, String>{
  'fr': 'Reconfirme-la à partir du document.',
  'en': 'Reconfirm it from the document.',
  'de': 'Bestätige sie anhand des Dokuments erneut.',
  'es': 'Vuelve a confirmarla a partir del documento.',
  'it': 'Riconfermala a partire dal documento.',
  'pt': 'Volta a confirmá-la a partir do documento.',
};

const _recoveryNonInferenceTokens = <String, List<String>>{
  'fr': <String>[
    'ni l’origine',
    'ni l’institution concernée',
    'ni l’application du règlement',
    'ni tes droits',
    'ni aucun montant',
  ],
  'en': <String>[
    'does not infer the origin',
    'the relevant pension fund',
    'that the rules apply',
    'any entitlements',
    'any amounts',
  ],
  'de': <String>[
    'nichts über die Herkunft',
    'die zuständige Vorsorgeeinrichtung',
    'die Anwendbarkeit des Reglements',
    'Ansprüche',
    'Beträge',
  ],
  'es': <String>[
    'ni el origen',
    'ni la institución de previsión',
    'ni la aplicabilidad del reglamento',
    'ni derechos',
    'ni importes',
  ],
  'it': <String>[
    'nulla sull’origine',
    'sull’istituto di previdenza',
    'sull’applicabilità del regolamento',
    'su diritti',
    'o importi',
  ],
  'pt': <String>[
    'não deduz daí a origem',
    'a instituição de previdência',
    'a aplicação do regulamento',
    'quaisquer direitos',
    'montantes',
  ],
};

const _recoveryDiagnosticTokens = <String, List<List<String>>>{
  'fr': <List<String>>[
    <String>['ne précise pas l’origine'],
    <String>['référence locale manque'],
    <String>['ne correspond pas à sa référence locale', 'est masquée'],
  ],
  'en': <List<String>>[
    <String>['does not identify the origin'],
    <String>['local reference is missing'],
    <String>['does not match its local reference', 'is hidden'],
  ],
  'de': <List<String>>[
    <String>['nennt die Herkunft', 'Reglements nicht'],
    <String>['lokale Referenz fehlt'],
    <String>['stimmt nicht mit ihrer lokalen Referenz überein', 'ausgeblendet'],
  ],
  'es': <List<String>>[
    <String>['no precisa el origen'],
    <String>['falta su referencia local'],
    <String>['no coincide con su referencia local', 'queda oculta'],
  ],
  'it': <List<String>>[
    <String>['non precisa l’origine'],
    <String>['manca il riferimento locale'],
    <String>['non corrisponde al riferimento locale', 'viene nascosta'],
  ],
  'pt': <List<String>>[
    <String>['não identifica a origem'],
    <String>['falta a referência local'],
    <String>['não corresponde à referência local', 'fica oculta'],
  ],
};

const _forbiddenRecoveryCtaMutations = <String, List<String>>{
  'fr': <String>['Reconfirmer le règlement', 'Reconfirmer le document'],
  'en': <String>['Reconfirm the rules', 'Reconfirm the document'],
  'de': <String>['Reglement erneut bestätigen', 'Dokument erneut bestätigen'],
  'es': <String>[
    'Volver a confirmar el reglamento',
    'Volver a confirmar el documento',
  ],
  'it': <String>['Riconfermare il regolamento', 'Riconfermare il documento'],
  'pt': <String>['Reconfirmar o regulamento', 'Reconfirmar o documento'],
};

const _historicalDocScanDescriptions = <String, String>{
  'fr': 'Règlement de ta caisse, examiné sans extraire de montant ni de droit.',
  'en':
      'Your pension fund rules, reviewed without extracting amounts or entitlements.',
  'de':
      'Das Reglement deiner Pensionskasse wird geprüft, ohne Beträge oder Ansprüche zu extrahieren.',
  'es': 'El reglamento de tu caja se revisa sin extraer importes ni derechos.',
  'it':
      'Il regolamento della tua cassa viene esaminato senza estrarre importi né diritti.',
  'pt':
      'O regulamento da tua caixa é analisado sem extrair montantes nem direitos.',
};

const _historicalReviewBodies = <String, String>{
  'fr':
      'Vérifier le règlement. Enregistre une déclaration datée et non vérifiée sur son origine.',
  'en':
      'Confirm only the document date and its legal reference year. This step confirms neither that the rules apply to your situation nor any entitlements or amounts.',
  'de':
      'Bestätige nur das Dokumentdatum und das rechtliche Referenzjahr. Dieser Schritt bestätigt weder die Anwendbarkeit auf deine Situation noch Ansprüche oder Beträge.',
  'es':
      'Confirma únicamente la fecha del documento y su año de referencia legal. Este paso no confirma que se aplique a tu situación ni derechos o importes.',
  'it':
      'Conferma soltanto la data del documento e il suo anno di riferimento legale. Questo passaggio non conferma né l’applicabilità alla tua situazione né diritti o importi.',
  'pt':
      'Confirma apenas a data do documento e o respetivo ano de referência legal. Este passo não confirma a aplicabilidade à tua situação nem quaisquer direitos ou montantes.',
};

const _negativeReviewBodies = <String, String>{
  'fr':
      'Enregistre une déclaration datée et non vérifiée sur l’origine de ce règlement. Le règlement n’a pas été revu.',
  'en':
      'Save a dated, unverified declaration about the origin of these rules. These rules were not reviewed.',
  'de':
      'Speichere eine datierte, nicht verifizierte Angabe zur Herkunft dieses Reglements. Das Reglement wurde nicht geprüft.',
  'es':
      'Guarda una declaración fechada y no verificada sobre el origen de este reglamento. El reglamento no fue revisado.',
  'it':
      'Salva una dichiarazione datata e non verificata sull’origine di questo regolamento. Il regolamento non è stato esaminato.',
  'pt':
      'Guarda uma declaração datada e não verificada sobre a origem deste regulamento. O regulamento não foi revisto.',
};

const _positivePrivacyMutations = <String, String>{
  'fr':
      'Le document original est joint à cette préparation et transmis depuis cet écran à une institution de prévoyance ou à un·e spécialiste.',
  'en':
      'The original document is attached to this preparation and sent from this screen to a pension fund or specialist.',
  'de':
      'Das Originaldokument wird dieser Vorbereitung beigefügt und von diesem Bildschirm aus an eine Vorsorgeeinrichtung oder eine Fachperson übermittelt.',
  'es':
      'El documento original se adjunta a esta preparación y se transmite desde esta pantalla a una institución de previsión o a una persona especialista.',
  'it':
      'Il documento originale viene allegato a questa preparazione e trasmesso da questa schermata a un istituto di previdenza o a una persona specialista.',
  'pt':
      'O documento original é anexado a esta preparação e transmitido, a partir deste ecrã, a uma instituição de previdência ou a uma pessoa especialista.',
};

const _assertingReferenceBodyMutations = <String, String>{
  'fr':
      'L’origine indiquée est une déclaration non vérifiée. Elle confirme l’institution concernée, l’application du règlement à ta situation, tes droits et des montants.',
  'en':
      'The stated origin is an unverified declaration. It confirms the relevant pension fund, that the rules apply to your situation, entitlements, and amounts.',
  'de':
      'Die angegebene Herkunft ist eine nicht verifizierte Angabe. Sie bestätigt die zuständige Vorsorgeeinrichtung, die Anwendbarkeit des Reglements auf deine Situation, Ansprüche und Beträge.',
  'es':
      'El origen indicado es una declaración no verificada. Confirma la institución de previsión correspondiente, que el reglamento se aplica a tu situación, derechos e importes.',
  'it':
      'L’origine indicata è una dichiarazione non verificata. Conferma l’istituto di previdenza interessato, l’applicabilità del regolamento alla tua situazione, diritti e importi.',
  'pt':
      'A origem indicada é uma declaração não verificada. Confirma a instituição de previdência em causa, a aplicação do regulamento à tua situação, direitos e montantes.',
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

List<String> _validateArb(String locale, Map<String, String> arb) {
  final issues = <String>[];
  final possessivePattern = _possessiveFundPatterns[locale]!;
  final institutionPattern = _neutralInstitutionPatterns[locale]!;

  void reject(String key, RegExp pattern, String rule) {
    final value = arb[key];
    if (value == null || pattern.hasMatch(value)) {
      issues.add(
        'lang=$locale key=$key value=${value ?? '<missing>'} rule=$rule',
      );
    }
  }

  void requireContains(String key, String token, String rule) {
    final value = arb[key];
    if (value == null || !value.toLowerCase().contains(token.toLowerCase())) {
      issues.add(
        'lang=$locale key=$key value=${value ?? '<missing>'} rule=$rule',
      );
    }
  }

  void requirePattern(String key, RegExp pattern, String rule) {
    final value = arb[key];
    if (value == null || !pattern.hasMatch(value)) {
      issues.add(
        'lang=$locale key=$key value=${value ?? '<missing>'} rule=$rule',
      );
    }
  }

  void requireExact(String key, String expected, String rule) {
    final value = arb[key];
    if (value != expected) {
      issues.add(
        'lang=$locale key=$key value=${value ?? '<missing>'} rule=$rule',
      );
    }
  }

  for (final key in <String>[
    'docScanLppPlanDocumentDescription',
    ..._handoffKeys,
    ..._questionBodyKeys,
  ]) {
    reject(key, possessivePattern, 'possessive-fund');
  }

  for (final key in <String>[..._handoffKeys, ..._questionBodyKeys]) {
    requirePattern(key, institutionPattern, 'neutral-institution');
  }

  for (final key in _declarationKeys) {
    requirePattern(
      key,
      _declarationPatterns[locale]!,
      'declaration-semantics',
    );
  }
  for (final key in const <String>[
    'lppRegulationReviewBody',
    'retirementLppRegulationReferenceBody',
  ]) {
    requireContains(key, _unverifiedTokens[locale]!, 'unverified');
  }

  final objectPattern = _confirmedObjectPatterns[locale]!;
  for (final key in _declarationKeys) {
    reject(key, objectPattern, 'confirmed-object');
  }

  requireExact(
    'docScanLppPlanDocumentDescription',
    _approvedDocScanDescriptions[locale]!,
    'approved-doc-scan-copy',
  );
  requireExact(
    'retirementLppRegulationHandoffPrivacy',
    _approvedPrivacyCopy[locale]!,
    'approved-non-transmission-copy',
  );
  requireExact(
    'retirementLppRegulationReferenceBody',
    _approvedReferenceBodies[locale]!,
    'approved-negative-authority-copy',
  );
  requireExact(
    'retirementLppRegulationRecoveryTitle',
    _approvedRecoveryTitles[locale]!,
    'approved-recovery-title',
  );
  requireExact(
    'retirementLppRegulationRecoveryCta',
    _approvedRecoveryCtas[locale]!,
    'approved-recovery-cta',
  );
  final approvedRecoveryBodies = _approvedRecoveryBodies[locale]!;
  final diagnosticTokens = _recoveryDiagnosticTokens[locale]!;
  for (var index = 0; index < _recoveryBodyKeys.length; index += 1) {
    final key = _recoveryBodyKeys[index];
    requireExact(
      key,
      approvedRecoveryBodies[index],
      'approved-recovery-body',
    );
    requireContains(
      key,
      _recoveryUnverifiedTokens[locale]!,
      'recovery-unverified',
    );
    requireContains(
      key,
      _reconfirmFromDocumentTokens[locale]!,
      'recovery-reconfirm-from-document',
    );
    for (final token in _recoveryNonInferenceTokens[locale]!) {
      requireContains(key, token, 'recovery-five-non-inferences');
    }
    for (final token in diagnosticTokens[index]) {
      requireContains(key, token, 'recovery-state-diagnostic');
    }
  }

  requireContains(
    'retirementLppRegulationHandoffBoundary',
    _noAdviceTokens[locale]!,
    'no-advice',
  );
  requireContains(
    'retirementLppRegulationHandoffBoundary',
    _specialistTokens[locale]!,
    'specialist',
  );

  requireExact(
    'retirementLppRegulationQuestionConversion',
    _conversionLabels[locale]!,
    'conversion-label',
  );
  requireExact(
    'retirementLppRegulationLegalYearLabel',
    _declaredYearLabels[locale]!,
    'declared-year-label',
  );

  return issues;
}

void _expectRejected(
  String locale,
  Map<String, String> baseline,
  String key,
  String mutation,
) {
  final issues = _validateArb(locale, <String, String>{
    ...baseline,
    key: mutation,
  });
  expect(
    issues.any((issue) => issue.contains('lang=$locale key=$key ')),
    isTrue,
    reason: 'mutation escaped: lang=$locale key=$key value=$mutation '
        'issues=${issues.join(' | ')}',
  );
}

void main() {
  test('LPP regulation copy keeps declaration authority across all six ARBs',
      () {
    for (final locale in _locales) {
      final arb = _arb(locale);
      expect(
        _validateArb(locale, arb),
        isEmpty,
        reason: _validateArb(locale, arb).join('\n'),
      );
    }
  });

  test('historical reviewed document scan copy is rejected', () {
    for (final locale in _locales) {
      _expectRejected(
        locale,
        _arb(locale),
        'docScanLppPlanDocumentDescription',
        _historicalDocScanDescriptions[locale]!,
      );
    }
  });

  test('historical confirmation-only review bodies are rejected', () {
    for (final entry in _historicalReviewBodies.entries) {
      _expectRejected(
        entry.key,
        _arb(entry.key),
        'lppRegulationReviewBody',
        entry.value,
      );
    }
  });

  test('explicit not-reviewed wording remains valid', () {
    for (final locale in _locales) {
      final mutation = _negativeReviewBodies[locale]!;
      final issues = _validateArb(locale, <String, String>{
        ..._arb(locale),
        'lppRegulationReviewBody': mutation,
      });
      expect(
        issues,
        isEmpty,
        reason: 'lang=$locale key=lppRegulationReviewBody value=$mutation '
            'issues=${issues.join(' | ')}',
      );
    }
  });

  test('privacy copy cannot invert non-transmission into transmission', () {
    for (final locale in _locales) {
      _expectRejected(
        locale,
        _arb(locale),
        'retirementLppRegulationHandoffPrivacy',
        _positivePrivacyMutations[locale]!,
      );
    }
  });

  test(
      'unverified reference cannot assert fund applicability rights or amounts',
      () {
    for (final locale in _locales) {
      _expectRejected(
        locale,
        _arb(locale),
        'retirementLppRegulationReferenceBody',
        _assertingReferenceBodyMutations[locale]!,
      );
    }
  });

  test('every declaration surface must retain declaration semantics', () {
    for (final locale in _locales) {
      final baseline = _arb(locale);
      for (final key in _declarationKeys) {
        _expectRejected(
          locale,
          baseline,
          key,
          'Neutral authority copy without the required semantic marker.',
        );
      }
    }
  });

  test(
      'recovery bodies mutation-lock declaration, unverified status, document reconfirmation, five non-inferences, and diagnostics',
      () {
    for (final locale in _locales) {
      final baseline = _arb(locale);
      final approvedBodies = _approvedRecoveryBodies[locale]!;
      final diagnostics = _recoveryDiagnosticTokens[locale]!;
      for (var index = 0; index < _recoveryBodyKeys.length; index += 1) {
        final key = _recoveryBodyKeys[index];
        final approved = approvedBodies[index];
        final requiredTokens = <String>{
          _recoveryDeclarationTokens[locale]!,
          _recoveryUnverifiedTokens[locale]!,
          _reconfirmFromDocumentTokens[locale]!,
          ..._recoveryNonInferenceTokens[locale]!,
          ...diagnostics[index],
        };
        for (final token in requiredTokens) {
          expect(
            approved.toLowerCase(),
            contains(token.toLowerCase()),
            reason: 'invalid mutation fixture: lang=$locale key=$key '
                'token=$token',
          );
          _expectRejected(
            locale,
            baseline,
            key,
            approved.replaceFirst(token, '[authority removed]'),
          );
        }
      }
    }
  });

  test('recovery CTA can reconfirm only the declaration', () {
    for (final locale in _locales) {
      for (final mutation in _forbiddenRecoveryCtaMutations[locale]!) {
        _expectRejected(
          locale,
          _arb(locale),
          'retirementLppRegulationRecoveryCta',
          mutation,
        );
      }
    }
  });
}
