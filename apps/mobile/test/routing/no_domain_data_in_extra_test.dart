import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan and report routes do not pass domain payloads through state.extra',
      () {
    final files = <String, List<RegExp>>{
      'lib/app.dart': [
        RegExp(r'state\.extra\s+as\s+ExtractionResult'),
        RegExp(r'''extra\[['"]result['"]\]\s+is!?\s+ExtractionResult'''),
        RegExp(r'FinancialReportScreenV2\(wizardAnswers:\s*extra'),
      ],
      'lib/screens/document_scan/document_scan_screen.dart': [
        RegExp(
            r'''context\.push\(\s*['"]/scan/review['"],\s*extra:\s*[^,)]+'''),
      ],
      'lib/screens/document_scan/avs_guide_screen.dart': [
        RegExp(
            r'''context\.push\(\s*['"]/scan/review['"],\s*extra:\s*[^,)]+'''),
      ],
      'lib/screens/document_scan/extraction_review_screen.dart': [
        RegExp(r'''context\.push\(\s*['"]/scan/impact['"],\s*extra:\s*\{'''),
      ],
    };

    final violations = <String>[];
    for (final entry in files.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} must exist');
      final source = file.readAsStringSync();
      for (final pattern in entry.value) {
        if (pattern.hasMatch(source)) {
          violations.add('${entry.key}: ${pattern.pattern}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Routes may pass ids/enums in state.extra, but not extracted '
          'financial documents, wizard answers, or report domain payloads.',
    );
  });

  test('scan session id helper accepts only query or string extra fallback',
      () {
    final source = File('lib/app.dart').readAsStringSync();
    // Structural lock only: _scanSessionIdFrom is private to app.dart, so this
    // audit test pins the route contract without exposing test-only API.
    final helperMatch = RegExp(
      r'String\?\s+_scanSessionIdFrom\(GoRouterState state\)\s*=>\s*(.*?);',
      dotAll: true,
    ).firstMatch(source);

    expect(
      helperMatch,
      isNotNull,
      reason: '_scanSessionIdFrom must remain a single audited helper.',
    );

    final helper = helperMatch!.group(1)!;
    expect(
      helper,
      contains("state.uri.queryParameters['scanSessionId']"),
      reason: 'Query scanSessionId is the preferred durable route contract.',
    );
    expect(
      helper,
      contains('extra is String'),
      reason: 'A string extra is the only allowed ephemeral fallback; '
          'ExtractionResult/wizardAnswers/domain payloads remain forbidden.',
    );
  });

  test('missing scan sessions render a localized recoverable state', () {
    final source = File('lib/app.dart').readAsStringSync();
    final unavailableClass = RegExp(
      r'class _ScanSessionUnavailable extends StatelessWidget \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(source);

    expect(
      source,
      isNot(contains('Document non disponible')),
      reason: 'The historical scan dead-end literal must not return.',
    );
    expect(
      unavailableClass,
      isNotNull,
      reason: '_ScanSessionUnavailable is the reviewed recovery state.',
    );

    final body = unavailableClass!.group(1)!;
    expect(body, contains('S.of(context)!'));
    expect(body, contains('appBar: AppBar'));
    expect(body, contains('l10n.documentsEmpty'));
    expect(body, contains('l10n.documentsEmptyVoice'));
    expect(body, contains('l10n.enrichmentCtaScan'));
    expect(body, contains("context.go('/scan')"));
  });

  test('scan impact does not synthesize a confidence baseline', () {
    final appSource = File('lib/app.dart').readAsStringSync();
    final impactSource =
        File('lib/screens/document_scan/document_impact_screen.dart')
            .readAsStringSync();

    expect(
      appSource,
      isNot(contains('previousConfidence: session.previousConfidence ??')),
      reason: 'A missing prior confidence score must stay missing.',
    );
    expect(impactSource, contains('final int? previousConfidence'));
    expect(impactSource, contains('scanImpactComparisonUnavailable'));
    expect(impactSource, contains('scanImpactComparisonUnavailableBody'));
  });
}
