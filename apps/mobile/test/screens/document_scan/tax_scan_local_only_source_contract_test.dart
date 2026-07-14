import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/tax_declaration_parser.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';

class _MemoryTaxPersistence implements TaxProfilePersistence {
  _MemoryTaxPersistence([Map<String, dynamic> initial = const {}])
      : answers = _copy(initial);

  Map<String, dynamic> answers;
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    answers = _copy(next);
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

class _CountingClock {
  _CountingClock(this.value);

  final DateTime value;
  int calls = 0;

  DateTime call() {
    calls += 1;
    return value;
  }
}

Map<String, dynamic> _decodeStrictTaxRoot(Map<String, dynamic> answers) {
  final stored = answers['_coach_tax_snapshots_v1'];
  if (stored is String) {
    final decoded = jsonDecode(stored);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } else if (stored is Map) {
    return Map<String, dynamic>.from(stored);
  }
  throw StateError('missing strict-secure tax root');
}

Map<String, dynamic> _strictRootAnswers(List<TaxSnapshot> snapshots) {
  final provenance = <String, dynamic>{};
  for (final snapshot in snapshots) {
    final prefix = 'fiscal.snapshots.${snapshot.snapshotId}.';
    for (final leafPath in TaxSnapshot.provenanceLeafPaths) {
      if (leafPath != 'sourceDate' &&
          snapshot.provenanceValue(leafPath) == null) {
        continue;
      }
      provenance['$prefix$leafPath'] = {
        'source': _strictRootSourceFor(snapshot, leafPath).name,
        'updatedAt': snapshot.updatedAt.toIso8601String(),
        'sourceDate': snapshot.sourceDate?.toIso8601String(),
      };
    }
  }
  return {
    '_coach_tax_snapshots_v1': jsonEncode({
      'schemaVersion': 1,
      'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
      'legacyQuarantine': null,
    }),
    '__provenance': provenance,
  };
}

ProfileDataSource _strictRootSourceFor(
  TaxSnapshot snapshot,
  String leafPath,
) {
  if (leafPath == 'inForceAttested') {
    return ProfileDataSource.userInput;
  }
  if (leafPath == 'assessmentStatus' &&
      snapshot.assessmentStatus == TaxAssessmentStatus.inForce) {
    return ProfileDataSource.userInput;
  }
  return switch (snapshot.documentKind) {
    TaxDocumentKind.assessmentNotice => ProfileDataSource.certificate,
    TaxDocumentKind.taxpayerReturn => ProfileDataSource.userInput,
    TaxDocumentKind.provisionalBill ||
    TaxDocumentKind.finalTaxBill ||
    TaxDocumentKind.unknown =>
      ProfileDataSource.estimated,
  };
}

TaxExtractionCandidate _candidate({
  String snapshotId = _snapshotId,
}) =>
    TaxExtractionCandidate.fromExtractionResult(
      const ExtractionResult(
        documentType: DocumentType.taxDeclaration,
        fields: [],
        overallConfidence: 0.8,
        confidenceDelta: 0,
        warnings: [],
        disclaimer: '',
        sources: [],
      ),
      snapshotIdFactory: () => snapshotId,
    );

TaxReviewConfirmation _confirmation({
  TaxExtractionCandidate? candidate,
  int? taxYear = 2025,
  double? cantonalIncome,
  double? federalIncome,
  AssessedTaxAmount? cantonalTax,
  AssessedTaxAmount? federalTax,
  DateTime? sourceDate,
  TaxAssessmentStatus assessmentStatus = TaxAssessmentStatus.assessedAppealable,
}) =>
    TaxReviewConfirmation(
      candidate: candidate ?? _candidate(),
      taxYear: taxYear,
      basedOnTaxYear: null,
      sourceDate: sourceDate ?? DateTime.utc(2026, 6, 20),
      documentKind: TaxDocumentKind.assessmentNotice,
      assessmentStatus: assessmentStatus,
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
      municipalityId: '5586',
      municipalityLabel: 'Lausanne',
      cantonalCommunalTaxableIncomeChf: cantonalIncome,
      federalTaxableIncomeChf: federalIncome,
      cantonalCommunalTaxableWealthChf: null,
      cantonalCommunalAssessedTax: cantonalTax,
      federalDirectAssessedTax: federalTax,
      explicitMarginalIncomeTaxRate: null,
      explicitAverageIncomeTaxRate: null,
    );

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n\r]*'), '');

({String body, int start, int end}) _blockAt(String source, int openBrace) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = openBrace; index < source.length; index += 1) {
    final char = source[index];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '{') depth += 1;
    if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return (
          body: source.substring(openBrace + 1, index),
          start: openBrace,
          end: index + 1,
        );
      }
    }
  }
  fail('unclosed Dart block at $openBrace');
}

int _closingParen(String source, int openParen) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var index = openParen; index < source.length; index += 1) {
    final char = source[index];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == '(') depth += 1;
    if (char == ')') {
      depth -= 1;
      if (depth == 0) return index;
    }
  }
  fail('unclosed method parameters at $openParen');
}

String _methodBody(String source, String name) {
  final clean = _withoutComments(source);
  final declaration = RegExp(
    '^[ \\t]*(?:static[ \\t]+)?[^\\n;{}=]+[ \\t]${RegExp.escape(name)}\\s*\\(',
    multiLine: true,
  ).firstMatch(clean);
  expect(declaration, isNotNull, reason: 'missing method declaration $name');
  final closeParen = _closingParen(clean, declaration!.end - 1);
  final openBrace = clean.indexOf('{', closeParen + 1);
  expect(openBrace, greaterThan(closeParen), reason: 'missing body $name');
  return _blockAt(clean, openBrace).body;
}

String _callContaining(String source, String callee, String marker) {
  final clean = _withoutComments(source);
  for (final match in RegExp(
    '\\b${RegExp.escape(callee)}\\s*\\(',
  ).allMatches(clean)) {
    final openParen = clean.indexOf('(', match.start);
    final call =
        clean.substring(openParen, _closingParen(clean, openParen) + 1);
    if (call.contains(marker)) return call;
  }
  fail('missing $callee call containing $marker');
}

String _caseBranch(String source, String methodName, String caseLabel) {
  final body = _methodBody(source, methodName);
  final startMatch = RegExp(
    'case\\s+${RegExp.escape(caseLabel)}\\s*:',
  ).firstMatch(body);
  expect(startMatch, isNotNull, reason: 'missing case $caseLabel');
  final nextMatches = RegExp(r'\n\s*(?:case\s+[^:]+|default)\s*:')
      .allMatches(body, startMatch!.end);
  final next = nextMatches.isEmpty ? null : nextMatches.first;
  return body.substring(startMatch.end, next?.start ?? body.length);
}

({String body, int start, int end}) _exactTaxGuard(
  String methodBody, {
  required String discriminant,
}) {
  final exactTokens =
      discriminant.trim().split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s*');
  final guard = RegExp(
    'if\\s*\\(\\s*$exactTokens\\s*\\)\\s*\\{',
  ).firstMatch(methodBody);
  expect(
    guard,
    isNotNull,
    reason: 'missing exact tax guard: $discriminant',
  );
  final openBrace = methodBody.indexOf('{', guard!.start);
  final block = _blockAt(methodBody, openBrace);
  return (body: block.body, start: guard.start, end: block.end);
}

void _expectDominantCallerTaxReturn(
  String source,
  String methodName,
  List<String> forbiddenCalls,
) {
  final body = _methodBody(source, methodName);
  final guard = _exactTaxGuard(
    body,
    discriminant: '_selectedType == DocumentType.taxDeclaration',
  );
  expect(
    RegExp(r'\breturn(?:\s+[^;]+)?;\s*$').hasMatch(guard.body.trim()),
    isTrue,
    reason: '$methodName tax guard must terminate every tax execution',
  );
  for (final call in forbiddenCalls) {
    final callIndex = body.indexOf(call);
    expect(callIndex, greaterThanOrEqualTo(0), reason: 'missing $call');
    expect(
      guard.end,
      lessThan(callIndex),
      reason: '$methodName must reject tax before $call',
    );
  }
}

void _expectServiceTaxRejection(
  String source,
  String methodName,
) {
  final body = _methodBody(source, methodName);
  final guard = _exactTaxGuard(
    body,
    discriminant: "documentType == 'tax_declaration'",
  );
  expect(
    RegExp(r'\bthrow\s+[^;]+;\s*$').hasMatch(guard.body.trim()),
    isTrue,
    reason: '$methodName must synchronously refuse tax_declaration',
  );
  final httpIndex = body.indexOf('http.post(');
  expect(httpIndex, greaterThanOrEqualTo(0), reason: 'missing HTTP boundary');
  expect(
    guard.end,
    lessThan(httpIndex),
    reason: '$methodName must refuse tax before HTTP',
  );
  final tryIndex = body.indexOf('try {');
  if (tryIndex >= 0) {
    expect(
      guard.end,
      lessThan(tryIndex),
      reason: '$methodName rejection must not be swallowed by its fallback',
    );
  }
}

void main() {
  late String scanSource;
  late String reviewSource;
  late String impactSource;
  late String appSource;
  late String providerSource;
  late String documentServiceSource;
  late String ragServiceSource;
  late String parserSource;

  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
    FeatureFlags.documentTaxAssessmentEnabled = false;
  });

  setUpAll(() {
    scanSource = File(
      'lib/screens/document_scan/document_scan_screen.dart',
    ).readAsStringSync();
    reviewSource = File(
      'lib/screens/document_scan/extraction_review_screen.dart',
    ).readAsStringSync();
    impactSource = File(
      'lib/screens/document_scan/document_impact_screen.dart',
    ).readAsStringSync();
    appSource = File('lib/app.dart').readAsStringSync();
    providerSource = File(
      'lib/providers/coach_profile_provider.dart',
    ).readAsStringSync();
    documentServiceSource =
        File('lib/services/document_service.dart').readAsStringSync();
    ragServiceSource = File('lib/services/rag_service.dart').readAsStringSync();
    parserSource = File(
      'lib/services/document_parser/tax_declaration_parser.dart',
    ).readAsStringSync();
  });

  test('the structural /scan/review route forwards its retained candidate', () {
    final route = _callContaining(
      appSource,
      'ScopedGoRoute',
      "path: '/scan/review'",
    );
    expect(route, contains('context.watch<ScanSessionProvider>()'));
    expect(route, contains('ExtractionReviewScreen('));
    expect(route, contains('taxCandidate: session.taxCandidate'));
  });

  test('tax parser branch returns an explicit typed extraction bundle only',
      () {
    final branch = _caseBranch(
      scanSource,
      '_parseByDocumentType',
      'DocumentType.taxDeclaration',
    );
    expect(branch, contains('TaxDeclarationParser.parseTaxDocument('));
    expect(branch, isNot(contains('parseTaxDeclaration(text)')));
    expect(
      RegExp(r'\breturn\s*\(\s*extraction\s*:').hasMatch(branch),
      isTrue,
    );
    expect(RegExp(r'\btaxCandidate\s*:').hasMatch(branch), isTrue);
    for (final hiddenSideEffect in [
      'retainExtraction(',
      'context.',
      'Provider.of',
      'context.read',
      '.go(',
      '.push(',
    ]) {
      expect(branch, isNot(contains(hiddenSideEffect)));
    }
  });

  test('typed parser sample exposes useful review metadata without writes', () {
    final parsed = TaxDeclarationParser.parseTaxDocument(
      '''AVIS DE TAXATION
Période fiscale: 2025
Émis le: 20.06.2026
Taxation individuelle
Canton: VD
Commune: Lausanne
Revenu imposable IFD: CHF 96'200''',
      snapshotIdFactory: () => _snapshotId,
    );

    expect(parsed.documentKind, TaxDocumentKind.assessmentNotice);
    expect(parsed.assessmentStatus, TaxAssessmentStatus.assessedAppealable);
    expect(parsed.taxYear, 2025);
    expect(parsed.sourceDate, DateTime.utc(2026, 6, 20));
    expect(parsed.subjectScope, TaxSubjectScope.individual);
    expect(parsed.cantonCode, 'VD');
    expect(parsed.municipalityLabel, 'Lausanne');
    expect(parsed.federalTaxableIncomeChf, 96200);
  });

  test('legacy tax writer API is absent from provider and review', () {
    final provider = _withoutComments(providerSource);
    final review = _withoutComments(reviewSource);
    expect(
      RegExp(r'\bupdateFromTaxExtraction\s*\(').hasMatch(provider),
      isFalse,
      reason: 'the parallel answer-map tax writer API must be deleted',
    );
    expect(
      RegExp(r'\bupdateFromTaxExtraction\s*\(').hasMatch(review),
      isFalse,
    );
  });

  test('tax review dominates Biography and generic backend sync', () {
    final body = _methodBody(reviewSource, '_onConfirmAll');
    final guard = _exactTaxGuard(
      body,
      discriminant: 'widget.result.documentType == DocumentType.taxDeclaration',
    );
    expect(guard.body.contains('acceptTaxReview('), isTrue);
    expect(
      RegExp(r'\breturn(?:\s+[^;]+)?;\s*$').hasMatch(guard.body.trim()),
      isTrue,
    );
    for (final forbidden in ['biographyProvider.addFact(', '_sendWithRetry(']) {
      final boundary = body.indexOf(forbidden);
      expect(boundary, greaterThanOrEqualTo(0), reason: 'missing $forbidden');
      expect(guard.end, lessThan(boundary));
    }
  });

  test(
      'tax confidence uses injected scorer fallback and score-save-score delta',
      () {
    final scorer = _methodBody(reviewSource, '_scoreProfile');
    expect(scorer, contains('widget.confidenceScorer'));
    expect(
      RegExp(
        r'ConfidenceScorer\s*\.\s*score\s*\(\s*profile\s*\)\s*\.\s*score\s*\.\s*round\s*\(\s*\)',
      ).hasMatch(scorer),
      isTrue,
    );

    final body = _methodBody(reviewSource, '_onConfirmAll');
    final guard = _exactTaxGuard(
      body,
      discriminant: 'widget.result.documentType == DocumentType.taxDeclaration',
    ).body;
    final before = guard.indexOf('_scoreProfile(');
    final save = guard.indexOf('await coachProvider.acceptTaxReview(');
    final after = guard.indexOf('_scoreProfile(', before + 1);
    final delta = guard.indexOf('afterConfidence - previousConfidence');
    final impact = guard.indexOf('retainImpact(');
    expect(before, greaterThanOrEqualTo(0));
    expect(save, greaterThan(before));
    expect(after, greaterThan(save));
    expect(delta, greaterThan(after));
    expect(impact, greaterThan(delta));
    expect(guard, contains('previousConfidence: previousConfidence'));
    expect(
      guard,
      contains('confidenceDelta: afterConfidence - previousConfidence'),
    );
  });

  test('camera tax branch dominates backend Vision', () {
    _expectDominantCallerTaxReturn(
      scanSource,
      '_processImageFile',
      ['_tryVisionExtraction('],
    );
  });

  test(
      'tax camera and gallery return before consent, picker or temporary file creation',
      () {
    _expectDominantCallerTaxReturn(
      scanSource,
      '_onCameraPressed',
      [
        'ConsentService().requireGrantedOrPrompt(',
        '_materializeBytesAsXFile(',
      ],
    );
    _expectDominantCallerTaxReturn(
      scanSource,
      '_onGalleryPressed',
      [
        'ConsentService().requireGrantedOrPrompt(',
        'FilePicker.platform.pickFiles(',
        '_resolveLocalPath(',
      ],
    );
  });

  test('tax document taxonomy delegates description copy to l10n', () {
    expect(DocumentType.taxDeclaration.label, 'Document fiscal');
    expect(
      DocumentType.taxDeclaration.description,
      isNull,
      reason: 'tax UI copy belongs to the existing AppLocalizations key',
    );
    expect(
      scanSource,
      contains('S.of(context)!.docScanTaxDocumentDescription'),
    );
  });

  test(
      'tax has no advertised or parser-estimated points before post-save score',
      () {
    expect(DocumentType.taxDeclaration.confidenceImpact, 0);
    final deltaBody = _methodBody(scanSource, '_confidenceDeltaForType');
    expect(
      RegExp(r'DocumentType\.taxDeclaration\s*=>\s*0(?:\.0)?')
          .hasMatch(deltaBody),
      isTrue,
    );
    final candidate = TaxDeclarationParser.parseTaxDocument(
      "Revenu imposable IFD: CHF 96'200",
      snapshotIdFactory: () => _snapshotId,
    );
    expect(
      candidate.extraction.confidenceDelta,
      0,
      reason: 'tax impact is computed only by the scorer after the save',
    );
  });

  test('PDF tax branch dominates both Docling and Vision fallback', () {
    _expectDominantCallerTaxReturn(
      scanSource,
      '_handlePdfImport',
      ['_processPdfViaBackend(', '_tryVisionExtractionFromPdf('],
    );
  });

  test('BYOK tax branch dominates RAG or LLM extraction', () {
    _expectDominantCallerTaxReturn(
      scanSource,
      '_processImageViaVision',
      ['ragService.extractFromImage('],
    );
  });

  for (final method in const [
    'extractWithVision',
    'sendScanConfirmation',
    'fetchPremierEclairage',
  ]) {
    test('DocumentService.$method rejects tax_declaration before HTTP', () {
      _expectServiceTaxRejection(documentServiceSource, method);
    });
  }

  test('RagService.extractFromImage rejects tax_declaration before HTTP', () {
    _expectServiceTaxRejection(ragServiceSource, 'extractFromImage');
  });

  final persistedPartialScopes = <({
    String name,
    bool federal,
    TaxAuthorityScope authority,
    TaxBaseScope base,
  })>[
    (
      name: 'ICC unknown authority',
      federal: false,
      authority: TaxAuthorityScope.unknown,
      base: TaxBaseScope.incomeAndWealth,
    ),
    (
      name: 'ICC unknown base',
      federal: false,
      authority: TaxAuthorityScope.cantonalCommunalCombined,
      base: TaxBaseScope.unknown,
    ),
    (
      name: 'ICC total invoice',
      federal: false,
      authority: TaxAuthorityScope.cantonalCommunalCombined,
      base: TaxBaseScope.totalInvoice,
    ),
    (
      name: 'IFD unknown base',
      federal: true,
      authority: TaxAuthorityScope.federalDirect,
      base: TaxBaseScope.unknown,
    ),
  ];

  for (final scope in persistedPartialScopes) {
    test('${scope.name} round-trips but selector remains partialAsk', () async {
      FeatureFlags.typedTaxProfile = true;
      final persistence = _MemoryTaxPersistence();
      final provider = CoachProfileProvider(taxProfilePersistence: persistence);
      final amount = AssessedTaxAmount(
        amountChf: 1234,
        authorityScope: scope.authority,
        baseScope: scope.base,
      );
      await provider.acceptTaxReview(
        _confirmation(
          cantonalTax: scope.federal ? null : amount,
          federalTax: scope.federal ? amount : null,
        ),
      );
      final cold = CoachProfileProvider(taxProfilePersistence: persistence);
      await cold.loadFromWizard();

      final snapshot = cold.profile!.fiscal.snapshots.single;
      expect(
        cold.profile!.fiscal.provenanceValidatedSnapshotIds,
        contains(snapshot.snapshotId),
      );
      final stored = scope.federal
          ? snapshot.federalDirectAssessedTax
          : snapshot.cantonalCommunalAssessedTax;
      expect(stored?.amountChf, 1234);
      expect(stored?.authorityScope, scope.authority);
      expect(stored?.baseScope, scope.base);
      final selection = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        FiscalSnapshotQuery.precise(
          requestedField: scope.federal
              ? TaxSnapshotField.federalDirectAssessedTax
              : TaxSnapshotField.cantonalCommunalAssessedTax,
          taxYear: 2025,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
          authorityScope: scope.federal
              ? TaxAuthorityScope.federalDirect
              : TaxAuthorityScope.cantonalCommunalCombined,
          baseScope: scope.federal
              ? TaxBaseScope.incomeOnly
              : TaxBaseScope.incomeAndWealth,
        ),
      );
      expect(selection.status, FiscalSelectionStatus.partialAsk);
      expect(selection.snapshot, isNull);
    });
  }

  for (final invalidBase in const [
    TaxBaseScope.wealthOnly,
    TaxBaseScope.incomeAndWealth,
  ]) {
    test(
        'IFD ${invalidBase.name} may exist in OCR candidate but admission rejects it with zero save',
        () async {
      FeatureFlags.typedTaxProfile = true;
      final persistence = _MemoryTaxPersistence();
      final provider = CoachProfileProvider(taxProfilePersistence: persistence);
      final ephemeralCandidate = TaxExtractionCandidate.fromExtractionResult(
        _candidate().extraction,
        snapshotIdFactory: () => invalidBase == TaxBaseScope.wealthOnly
            ? '22222222-2222-4222-8222-222222222222'
            : '33333333-3333-4333-8333-333333333333',
        documentKind: TaxDocumentKind.assessmentNotice,
        assessmentStatus: TaxAssessmentStatus.assessedAppealable,
        taxYear: 2025,
        sourceDate: DateTime.utc(2026, 6, 20),
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
        federalDirectAssessedTax: AssessedTaxAmount(
          amountChf: 1234,
          authorityScope: TaxAuthorityScope.federalDirect,
          baseScope: invalidBase,
        ),
      );

      Object? admissionError;
      try {
        await provider.acceptTaxReview(
          _confirmation(
            candidate: ephemeralCandidate,
            federalTax: ephemeralCandidate.federalDirectAssessedTax,
          ),
        );
      } catch (error) {
        admissionError = error;
      }

      expect(
        [admissionError is ArgumentError, persistence.saveCalls],
        [true, 0],
      );
      expect(persistence.answers, isEmpty);
      expect(provider.profile, isNull);
    });
  }

  for (final incomeScope in const [
    (
      name: 'ICC',
      field: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
    ),
    (
      name: 'IFD',
      field: TaxSnapshotField.federalTaxableIncomeChf,
    ),
  ]) {
    test(
        'negative taxable income ${incomeScope.name} cold-round-trips but remains partialAsk',
        () async {
      FeatureFlags.typedTaxProfile = true;
      FeatureFlags.documentTaxAssessmentEnabled = true;
      final persistence = _MemoryTaxPersistence();
      final provider = CoachProfileProvider(taxProfilePersistence: persistence);
      await provider.acceptTaxReview(
        _confirmation(
          cantonalIncome: incomeScope.field ==
                  TaxSnapshotField.cantonalCommunalTaxableIncomeChf
              ? -1
              : null,
          federalIncome:
              incomeScope.field == TaxSnapshotField.federalTaxableIncomeChf
                  ? -1
                  : null,
        ),
      );
      final cold = CoachProfileProvider(taxProfilePersistence: persistence);
      await cold.loadFromWizard();

      final snapshot = cold.profile!.fiscal.snapshots.single;
      final fieldPath = incomeScope.field.name;
      expect(snapshot.provenanceValue(fieldPath), -1);
      expect(
        cold.profile!.fiscal.provenanceValidatedSnapshotIds,
        contains(snapshot.snapshotId),
      );
      expect(
        cold.profile!
            .dataSources['fiscal.snapshots.${snapshot.snapshotId}.$fieldPath'],
        ProfileDataSource.certificate,
      );
      final strictSnapshot = Map<String, dynamic>.from(
        (_decodeStrictTaxRoot(persistence.answers)['snapshots'] as List).single
            as Map,
      );
      expect(strictSnapshot[fieldPath], -1);

      final preciseQuery = FiscalSnapshotQuery.precise(
        requestedField: incomeScope.field,
        taxYear: 2025,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
      );
      final preciseNegative = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        preciseQuery,
      );
      final latestNegative = FiscalSnapshotSelector.selectAssessedBaseline(
        cold.profile!.fiscal,
        FiscalSnapshotQuery.latestCompleteness(
          requestedField: incomeScope.field,
        ),
      );
      for (final selection in [preciseNegative, latestNegative]) {
        expect(selection.status, FiscalSelectionStatus.partialAsk);
        expect(selection.snapshot, isNull);
      }

      final positiveSnapshot = switch (incomeScope.field) {
        TaxSnapshotField.cantonalCommunalTaxableIncomeChf => snapshot.copyWith(
            cantonalCommunalTaxableIncomeChf: 1.0,
          ),
        TaxSnapshotField.federalTaxableIncomeChf => snapshot.copyWith(
            federalTaxableIncomeChf: 1.0,
          ),
        _ => throw StateError('unsupported income field'),
      };
      final positiveProfile = cold.profile!.copyWith(
        fiscal: cold.profile!.fiscal.copyWith(snapshots: [positiveSnapshot]),
      );
      final precisePositive = FiscalSnapshotSelector.selectAssessedBaseline(
        positiveProfile.fiscal,
        preciseQuery,
      );
      final latestPositive = FiscalSnapshotSelector.selectAssessedBaseline(
        positiveProfile.fiscal,
        FiscalSnapshotQuery.latestCompleteness(
          requestedField: incomeScope.field,
        ),
      );
      expect(precisePositive.status, FiscalSelectionStatus.available);
      expect(precisePositive.snapshot?.provenanceValue(fieldPath), 1.0);
      expect(latestPositive.status, FiscalSelectionStatus.available);

      if (incomeScope.field ==
          TaxSnapshotField.cantonalCommunalTaxableIncomeChf) {
        final negativeFiscal =
            ConfidenceScorer.scoreAsBlocs(cold.profile!)['fiscalite']!;
        final positiveFiscal =
            ConfidenceScorer.scoreAsBlocs(positiveProfile)['fiscalite']!;
        final negativePrompts = ConfidenceScorer.score(cold.profile!).prompts;
        final positivePrompts = ConfidenceScorer.score(positiveProfile).prompts;
        expect(negativeFiscal.score, 0);
        expect(positiveFiscal.score, 4);
        expect(
          negativePrompts.where(
            (prompt) => prompt.fieldPath == 'fiscal.assessedBaseline',
          ),
          hasLength(1),
        );
        expect(
          positivePrompts.where(
            (prompt) => prompt.fieldPath == 'fiscal.assessedBaseline',
          ),
          isEmpty,
        );
      }
    });
  }

  test(
      'typed parser prefills finite negative incomes but rejects negative wealth and tax amounts',
      () {
    final parsed = TaxDeclarationParser.parseTaxDocument(
      '''AVIS DE TAXATION
Période fiscale: 2025
Émis le: 20.06.2026
Taxation individuelle
Canton: VD
Revenu imposable ICC: CHF -4'200.00
Revenu imposable IFD: CHF -3'900.00
Fortune imposable ICC: CHF -25'000.00
Impôt cantonal et communal sur le revenu: CHF -100.00
Impôt fédéral direct sur le revenu: CHF -50.00''',
      snapshotIdFactory: () => _snapshotId,
    );

    expect(
      [
        parsed.cantonalCommunalTaxableIncomeChf,
        parsed.federalTaxableIncomeChf,
        parsed.cantonalCommunalTaxableWealthChf,
        parsed.cantonalCommunalAssessedTax,
        parsed.federalDirectAssessedTax,
      ],
      [-4200, -3900, null, null, null],
    );
  });

  test('parser classification can never manufacture inForce', () {
    for (final text in [
      'AVIS DE TAXATION — décision définitive et exécutoire',
      'BORDEREAU FINAL — entrée en force',
      'VERANLAGUNGSVERFÜGUNG — rechtskräftig',
    ]) {
      final parsed = TaxDeclarationParser.parseTaxDocument(
        text,
        snapshotIdFactory: () => _snapshotId,
      );
      expect(parsed.assessmentStatus, isNot(TaxAssessmentStatus.inForce));
    }
    expect(parserSource, isNot(contains('TaxAssessmentStatus.inForce')));
  });

  test(
      'inactive false attestation serializes as schema state without active provenance',
      () async {
    FeatureFlags.typedTaxProfile = true;
    const snapshotId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    TaxSnapshot? snapshot;
    Object? constructorError;
    try {
      snapshot = TaxSnapshot(
        snapshotId: snapshotId,
        profileOwnerId: 'owner-inactive-attestation',
        taxYear: 2023,
        basedOnTaxYear: null,
        sourceDate: DateTime.utc(2024, 7, 14),
        documentKind: TaxDocumentKind.assessmentNotice,
        assessmentStatus: TaxAssessmentStatus.assessedAppealable,
        inForceAttested: false,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
        municipalityId: '5586',
        municipalityLabel: 'Lausanne',
        cantonalCommunalTaxableIncomeChf: 98000.0,
        federalTaxableIncomeChf: 96000.0,
        cantonalCommunalTaxableWealthChf: 245000.0,
        cantonalCommunalAssessedTax: null,
        federalDirectAssessedTax: null,
        explicitMarginalIncomeTaxRate: null,
        explicitAverageIncomeTaxRate: null,
        updatedAt: DateTime.utc(2024, 7, 14, 11),
      );
    } catch (error) {
      constructorError = error;
    }
    expect(
      constructorError,
      isNull,
      reason: 'TaxSnapshot must expose the inactive attestation schema state',
    );

    final serialized = snapshot!.toJson();
    expect(serialized.containsKey('inForceAttested'), isTrue);
    expect(serialized['inForceAttested'], isFalse);
    expect(snapshot.provenanceValue('inForceAttested'), isNull);

    final seed = _strictRootAnswers([snapshot]);
    final strictRoot = _decodeStrictTaxRoot(seed);
    final strictSnapshot = Map<String, dynamic>.from(
      (strictRoot['snapshots'] as List).single as Map,
    );
    expect(strictSnapshot.containsKey('inForceAttested'), isTrue);
    expect(strictSnapshot['inForceAttested'], isFalse);
    const prefix = 'fiscal.snapshots.$snapshotId.';
    final provenance = Map<String, dynamic>.from(seed['__provenance'] as Map);
    expect(provenance.containsKey('${prefix}inForceAttested'), isFalse);
    expect(
      Map<String, dynamic>.from(
        provenance['${prefix}assessmentStatus'] as Map,
      )['source'],
      ProfileDataSource.certificate.name,
    );

    final persistence = _MemoryTaxPersistence(seed);
    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    final retained = cold.profile!.fiscal.snapshots.single;
    expect(retained.inForceAttested, isFalse);
    expect(retained.provenanceValue('inForceAttested'), isNull);
    expect(
      cold.profile!.fiscal.provenanceValidatedSnapshotIds,
      contains(snapshotId),
      reason: 'inactive false attestation requires no provenance envelope',
    );
    expect(persistence.saveCalls, 0);
  });

  test('inForce without explicit secondary attestation is rejected before save',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    Object? admissionError;
    try {
      await provider.acceptTaxReview(
        _confirmation(assessmentStatus: TaxAssessmentStatus.inForce),
      );
    } catch (error) {
      admissionError = error;
    }

    expect(
      [admissionError is ArgumentError, persistence.saveCalls],
      [true, 0],
    );
    expect(persistence.answers, isEmpty);
  });

  test('inForce with explicit secondary attestation is admitted once',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final persistence = _MemoryTaxPersistence();
    final provider = CoachProfileProvider(taxProfilePersistence: persistence);
    final candidate = _candidate(
      snapshotId: '44444444-4444-4444-8444-444444444444',
    );
    TaxReviewConfirmation? confirmation;
    Object? constructorError;
    try {
      confirmation = TaxReviewConfirmation(
        candidate: candidate,
        taxYear: 2025,
        basedOnTaxYear: null,
        sourceDate: DateTime.utc(2026, 6, 20),
        documentKind: TaxDocumentKind.assessmentNotice,
        assessmentStatus: TaxAssessmentStatus.inForce,
        inForceAttested: true,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
        municipalityId: '5586',
        municipalityLabel: 'Lausanne',
        cantonalCommunalTaxableIncomeChf: 98000.0,
        federalTaxableIncomeChf: 96000.0,
        cantonalCommunalTaxableWealthChf: 245000.0,
        cantonalCommunalAssessedTax: null,
        federalDirectAssessedTax: null,
        explicitMarginalIncomeTaxRate: null,
        explicitAverageIncomeTaxRate: null,
      );
    } catch (error) {
      constructorError = error;
    }
    expect(
      constructorError,
      isNull,
      reason: 'TaxReviewConfirmation must accept inForceAttested',
    );

    await provider.acceptTaxReview(confirmation!);
    final strictRoot = _decodeStrictTaxRoot(persistence.answers);
    final persistedSnapshots = (strictRoot['snapshots'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final persistedSnapshot = persistedSnapshots.singleWhere(
      (value) => value['snapshotId'] == candidate.snapshotId,
    );
    expect(persistedSnapshot.containsKey('inForceAttested'), isTrue);
    expect(persistedSnapshot['inForceAttested'], isTrue);

    final cold = CoachProfileProvider(taxProfilePersistence: persistence);
    await cold.loadFromWizard();

    expect(persistence.saveCalls, 1);
    final snapshot = cold.profile!.fiscal.snapshots.single;
    expect(snapshot.snapshotId, candidate.snapshotId);
    expect(snapshot.assessmentStatus, TaxAssessmentStatus.inForce);
    expect(snapshot.inForceAttested, isTrue);
    expect(snapshot.provenanceValue('inForceAttested'), isTrue);
    expect(
      cold.profile!.fiscal.provenanceValidatedSnapshotIds,
      contains(snapshot.snapshotId),
    );
    expect(TaxSnapshot.provenanceLeafPaths, contains('inForceAttested'));

    final prefix = 'fiscal.snapshots.${snapshot.snapshotId}.';
    final persistedProvenance = Map<String, dynamic>.from(
      persistence.answers['__provenance'] as Map,
    );
    final expectedLeafPaths = {
      for (final leafPath in TaxSnapshot.provenanceLeafPaths)
        if (leafPath == 'sourceDate' ||
            snapshot.provenanceValue(leafPath) != null)
          leafPath,
    };
    final expectedExactPaths = {
      for (final leafPath in expectedLeafPaths) '$prefix$leafPath',
    };
    final persistedExactPaths = persistedProvenance.keys
        .where((path) => path.startsWith(prefix))
        .toSet();
    expect(persistedExactPaths, expectedExactPaths);

    for (final leafPath in expectedLeafPaths) {
      final exactPath = '$prefix$leafPath';
      final envelope = Map<String, dynamic>.from(
        persistedProvenance[exactPath] as Map,
      );
      final expectedSource = switch (leafPath) {
        'assessmentStatus' || 'inForceAttested' => ProfileDataSource.userInput,
        _ => ProfileDataSource.certificate,
      };
      expect(envelope.keys.toSet(), {'source', 'updatedAt', 'sourceDate'});
      expect(envelope['source'], expectedSource.name);
      expect(envelope['sourceDate'], '2026-06-20T00:00:00.000Z');
      expect(cold.profile!.dataSources[exactPath], expectedSource);
      expect(cold.profile!.dataTimestamps[exactPath], isNotNull);
      expect(
        envelope['updatedAt'],
        cold.profile!.dataTimestamps[exactPath]!.toIso8601String(),
      );
      expect(
        cold.profile!.dataSourceDates[exactPath],
        DateTime.utc(2026, 6, 20),
      );
    }
  });

  test('writer clock accepts today then rejects tomorrow with no second save',
      () async {
    FeatureFlags.typedTaxProfile = true;
    final clock = _CountingClock(DateTime.utc(2024, 7, 14, 12));
    final persistence = _MemoryTaxPersistence();
    CoachProfileProvider? provider;
    Object? providerConstructorError;
    try {
      provider = CoachProfileProvider(
        taxProfilePersistence: persistence,
        now: clock.call,
      );
    } catch (error) {
      providerConstructorError = error;
    }
    expect(
      providerConstructorError,
      isNull,
      reason: 'the tax writer must consume its injected civil clock',
    );

    await provider!.acceptTaxReview(
      _confirmation(
        candidate: _candidate(
          snapshotId: '55555555-5555-4555-8555-555555555555',
        ),
        taxYear: 2023,
        sourceDate: DateTime.utc(2024, 7, 14),
      ),
    );
    Object? futureError;
    try {
      await provider.acceptTaxReview(
        _confirmation(
          candidate: _candidate(
            snapshotId: '66666666-6666-4666-8666-666666666666',
          ),
          taxYear: 2023,
          sourceDate: DateTime.utc(2024, 7, 15),
        ),
      );
    } catch (error) {
      futureError = error;
    }

    expect(
      [futureError is ArgumentError, persistence.saveCalls, clock.calls > 0],
      [true, 1, true],
    );
  });

  test('future sourceDate is excluded by the cold selector', () {
    FeatureFlags.typedTaxProfile = true;
    final clock = _CountingClock(DateTime.utc(2024, 7, 14, 12));
    const validId = '77777777-7777-4777-8777-777777777777';
    const futureId = '88888888-8888-4888-8888-888888888888';
    TaxSnapshot snapshot(String id, DateTime sourceDate, double income) =>
        TaxSnapshot(
          snapshotId: id,
          profileOwnerId: 'owner-1',
          taxYear: 2023,
          basedOnTaxYear: null,
          sourceDate: sourceDate,
          documentKind: TaxDocumentKind.assessmentNotice,
          assessmentStatus: TaxAssessmentStatus.assessedAppealable,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
          municipalityId: '5586',
          municipalityLabel: 'Lausanne',
          cantonalCommunalTaxableIncomeChf: income,
          federalTaxableIncomeChf: null,
          cantonalCommunalTaxableWealthChf: null,
          cantonalCommunalAssessedTax: null,
          federalDirectAssessedTax: null,
          explicitMarginalIncomeTaxRate: null,
          explicitAverageIncomeTaxRate: null,
          updatedAt: DateTime.utc(2024, 7, 14, 12),
        );
    final warm = FiscalProfile(
      snapshots: [
        snapshot(validId, DateTime.utc(2024, 7, 14), 98000),
        snapshot(futureId, DateTime.utc(2024, 7, 15), 999999),
      ],
    );
    final coldJson = jsonDecode(jsonEncode(warm.toJson())) as Map;
    final cold = FiscalProfile.fromJson(
      Map<String, dynamic>.from(coldJson),
    ).copyWith(
      provenanceValidatedSnapshotIds: const {validId, futureId},
    );

    final query = FiscalSnapshotQuery.precise(
      requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      taxYear: 2023,
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
    );
    FiscalSelectionResult? selection;
    Object? selectorInvocationError;
    try {
      selection = FiscalSnapshotSelector.selectAssessedBaseline(
        cold,
        query,
        now: clock.call,
      );
    } catch (error) {
      selectorInvocationError = error;
    }
    expect(
      selectorInvocationError,
      isNull,
      reason: 'the cold selector must consume its injected civil clock',
    );

    expect(clock.calls, greaterThan(0));
    expect(selection!.status, FiscalSelectionStatus.available);
    expect(selection.snapshot?.snapshotId, validId);
    expect(selection.snapshot?.cantonalCommunalTaxableIncomeChf, 98000);
  });

  test(
      'cold load retains future history but quarantines it from validation and selection without rewrite',
      () async {
    FeatureFlags.typedTaxProfile = true;
    const validId = '99999999-9999-4999-8999-999999999999';
    const futureId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    TaxSnapshot snapshot(String id, DateTime sourceDate, double income) =>
        TaxSnapshot(
          snapshotId: id,
          profileOwnerId: 'owner-cold-clock',
          taxYear: 2023,
          basedOnTaxYear: null,
          sourceDate: sourceDate,
          documentKind: TaxDocumentKind.assessmentNotice,
          assessmentStatus: TaxAssessmentStatus.assessedAppealable,
          subjectScope: TaxSubjectScope.individual,
          cantonCode: 'VD',
          municipalityId: '5586',
          municipalityLabel: 'Lausanne',
          cantonalCommunalTaxableIncomeChf: income,
          federalTaxableIncomeChf: null,
          cantonalCommunalTaxableWealthChf: null,
          cantonalCommunalAssessedTax: null,
          federalDirectAssessedTax: null,
          explicitMarginalIncomeTaxRate: null,
          explicitAverageIncomeTaxRate: null,
          updatedAt: DateTime.utc(2024, 7, 14, 11),
        );
    final seed = _strictRootAnswers([
      snapshot(validId, DateTime.utc(2024, 7, 14), 98000),
      snapshot(futureId, DateTime.utc(2024, 7, 15), 999999),
    ]);
    final persistence = _MemoryTaxPersistence(seed);
    final rawBefore = _MemoryTaxPersistence._copy(persistence.answers);
    final strictRootBefore = persistence.answers['_coach_tax_snapshots_v1'];
    final loadClock = _CountingClock(DateTime.utc(2024, 7, 14, 12));
    CoachProfileProvider? provider;
    Object? providerConstructorError;
    try {
      provider = CoachProfileProvider(
        taxProfilePersistence: persistence,
        now: loadClock.call,
      );
    } catch (error) {
      providerConstructorError = error;
    }
    expect(
      providerConstructorError,
      isNull,
      reason: 'cold validation must consume the injected historical clock',
    );

    await provider!.loadFromWizard();

    expect(loadClock.calls, greaterThan(0));
    final fiscal = provider.profile!.fiscal;
    expect(
      fiscal.snapshots.map((snapshot) => snapshot.snapshotId).toSet(),
      {validId, futureId},
      reason: 'future history is retained, never clamped or silently deleted',
    );
    expect(fiscal.provenanceValidatedSnapshotIds, {validId});

    final selectorClock = _CountingClock(DateTime.utc(2024, 7, 14, 18));
    final query = FiscalSnapshotQuery.precise(
      requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
      taxYear: 2023,
      subjectScope: TaxSubjectScope.individual,
      cantonCode: 'VD',
    );
    FiscalSelectionResult? selection;
    Object? selectorInvocationError;
    try {
      selection = FiscalSnapshotSelector.selectAssessedBaseline(
        fiscal,
        query,
        now: selectorClock.call,
      );
    } catch (error) {
      selectorInvocationError = error;
    }
    expect(selectorInvocationError, isNull);
    expect(selectorClock.calls, greaterThan(0));
    expect(selection!.status, FiscalSelectionStatus.available);
    expect(selection.snapshot?.snapshotId, validId);

    expect(persistence.saveCalls, 0);
    expect(persistence.answers, rawBefore);
    expect(persistence.answers['_coach_tax_snapshots_v1'], strictRootBefore);
  });

  for (final attestationCase in const [
    (
      name: 'absent',
      snapshotId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      persistFalse: false,
    ),
    (
      name: 'false',
      snapshotId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      persistFalse: true,
    ),
  ]) {
    test(
        'cold inForce with ${attestationCase.name} attestation stays historical but is quarantined without rewrite',
        () async {
      FeatureFlags.typedTaxProfile = true;
      final baseSnapshot = TaxSnapshot(
        snapshotId: attestationCase.snapshotId,
        profileOwnerId: 'owner-cold-in-force',
        taxYear: 2023,
        basedOnTaxYear: null,
        sourceDate: DateTime.utc(2024, 7, 14),
        documentKind: TaxDocumentKind.assessmentNotice,
        assessmentStatus: TaxAssessmentStatus.assessedAppealable,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
        municipalityId: '5586',
        municipalityLabel: 'Lausanne',
        cantonalCommunalTaxableIncomeChf: 98000,
        federalTaxableIncomeChf: null,
        cantonalCommunalTaxableWealthChf: null,
        cantonalCommunalAssessedTax: null,
        federalDirectAssessedTax: null,
        explicitMarginalIncomeTaxRate: null,
        explicitAverageIncomeTaxRate: null,
        updatedAt: DateTime.utc(2024, 7, 14, 11),
      );
      final seed = _strictRootAnswers([baseSnapshot]);
      final strictRoot = _decodeStrictTaxRoot(seed);
      final rawSnapshot = Map<String, dynamic>.from(
        (strictRoot['snapshots'] as List).single as Map,
      )..['assessmentStatus'] = TaxAssessmentStatus.inForce.name;
      if (attestationCase.persistFalse) {
        rawSnapshot['inForceAttested'] = false;
      } else {
        rawSnapshot.remove('inForceAttested');
      }
      strictRoot['snapshots'] = [rawSnapshot];
      seed['_coach_tax_snapshots_v1'] = jsonEncode(strictRoot);

      final prefix = 'fiscal.snapshots.${attestationCase.snapshotId}.';
      final provenance = Map<String, dynamic>.from(
        seed['__provenance'] as Map,
      );
      final statusPath = '${prefix}assessmentStatus';
      provenance[statusPath] = Map<String, dynamic>.from(
        provenance[statusPath] as Map,
      )..['source'] = ProfileDataSource.userInput.name;
      final attestationPath = '${prefix}inForceAttested';
      provenance.remove(attestationPath);
      seed['__provenance'] = provenance;
      expect(
        Map<String, dynamic>.from(seed['__provenance'] as Map)
            .containsKey(attestationPath),
        isFalse,
        reason: 'absent and inactive false attestations are not active leaves',
      );

      final persistence = _MemoryTaxPersistence(seed);
      final rawBefore = _MemoryTaxPersistence._copy(persistence.answers);
      final strictRootBefore = persistence.answers['_coach_tax_snapshots_v1'];
      final loadClock = _CountingClock(DateTime.utc(2024, 7, 14, 12));
      CoachProfileProvider? provider;
      Object? providerConstructorError;
      try {
        provider = CoachProfileProvider(
          taxProfilePersistence: persistence,
          now: loadClock.call,
        );
      } catch (error) {
        providerConstructorError = error;
      }
      expect(
        providerConstructorError,
        isNull,
        reason: 'cold inForce validation must consume the injected clock',
      );

      await provider!.loadFromWizard();

      expect(loadClock.calls, greaterThan(0));
      final fiscal = provider.profile!.fiscal;
      final retained = fiscal.snapshots.single;
      expect(retained.snapshotId, attestationCase.snapshotId);
      expect(retained.assessmentStatus, TaxAssessmentStatus.inForce);
      expect(retained.inForceAttested, isFalse);
      expect(retained.provenanceValue('inForceAttested'), isNull);
      expect(
        fiscal.provenanceValidatedSnapshotIds,
        isNot(contains(attestationCase.snapshotId)),
      );

      final forgedFiscal = fiscal.copyWith(
        provenanceValidatedSnapshotIds: {attestationCase.snapshotId},
      );
      expect(
        forgedFiscal.provenanceValidatedSnapshotIds,
        contains(attestationCase.snapshotId),
        reason: 'selector defense is isolated from provider unvalidation',
      );

      final selectorClock = _CountingClock(DateTime.utc(2024, 7, 14, 18));
      final query = FiscalSnapshotQuery.precise(
        requestedField: TaxSnapshotField.cantonalCommunalTaxableIncomeChf,
        taxYear: 2023,
        subjectScope: TaxSubjectScope.individual,
        cantonCode: 'VD',
      );
      FiscalSelectionResult? selection;
      Object? selectorInvocationError;
      try {
        selection = FiscalSnapshotSelector.selectAssessedBaseline(
          forgedFiscal,
          query,
          now: selectorClock.call,
        );
      } catch (error) {
        selectorInvocationError = error;
      }
      expect(selectorInvocationError, isNull);
      expect(selectorClock.calls, greaterThan(0));
      expect(selection!.status, FiscalSelectionStatus.partialAsk);
      expect(selection.snapshot, isNull);

      expect(persistence.saveCalls, 0);
      expect(persistence.answers, rawBefore);
      expect(persistence.answers['_coach_tax_snapshots_v1'], strictRootBefore);
    });
  }

  test('tax impact guard dominates sourceText insight and memory paths', () {
    final fetch = _methodBody(impactSource, '_fetchPremierEclairage');
    final fetchGuard = _exactTaxGuard(
      fetch,
      discriminant: 'widget.result.documentType == DocumentType.taxDeclaration',
    );
    expect(
      RegExp(r'\breturn(?:\s+[^;]+)?;\s*$').hasMatch(fetchGuard.body.trim()),
      isTrue,
    );
    final sourceText = fetch.indexOf("'sourceText'");
    expect(sourceText, greaterThanOrEqualTo(0));
    expect(fetchGuard.end, lessThan(sourceText));

    final persist = _methodBody(impactSource, '_persistScanEvent');
    final persistGuard = _exactTaxGuard(
      persist,
      discriminant: 'widget.result.documentType == DocumentType.taxDeclaration',
    );
    expect(
      RegExp(r'\breturn(?:\s+[^;]+)?;\s*$').hasMatch(persistGuard.body.trim()),
      isTrue,
    );
    final memory = persist.indexOf('saveScanEvent(');
    expect(memory, greaterThanOrEqualTo(0));
    expect(persistGuard.end, lessThan(memory));
  });

  test('PDF uploadDocument remains caller-guarded, not globally tax-aware', () {
    final clean = _withoutComments(documentServiceSource);
    final vaultEnum = clean.substring(
      clean.indexOf('enum VaultDocumentType'),
      clean.indexOf('extension VaultDocumentTypeX'),
    );
    expect(vaultEnum.contains('taxDeclaration'), isFalse);
    expect(
      RegExp(
        r'uploadDocument\s*\([^)]*VaultDocumentType\s+type',
        multiLine: true,
      ).hasMatch(clean),
      isTrue,
      reason: 'uploadDocument cannot receive tax_declaration semantics',
    );
  });
}
