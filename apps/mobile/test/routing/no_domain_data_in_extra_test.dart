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
}
