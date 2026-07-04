import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw reference stores do not write financial ledger keys', () {
    final checkedFiles = <String>[
      'lib/providers/document_provider.dart',
      'lib/providers/timeline_provider.dart',
      'lib/providers/scan_session_provider.dart',
    ];
    final forbidden = RegExp(
      r'wizard_answers_v2|'
      r'ReportPersistenceService|'
      r'CoachProfileProvider|'
      r'\bmergeAnswers\b|'
      r'\bapplySaveFact\b|'
      r'\bupdateProfile\b|'
      r'''set(?:String|Double|Int|Bool|StringList)\(\s*['"](?:q_|_coach_|fp:)''',
      multiLine: true,
    );

    final violations = <String>[];
    for (final path in checkedFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');
      final source = file.readAsStringSync();
      if (forbidden.hasMatch(source)) {
        violations.add(path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Document, timeline, and scan-session stores may keep ids, raw '
          'results, and activity references only. Confirmed financial facts '
          'must enter the ledger through CoachProfileProvider at scan/coach '
          'confirmation time.',
    );
  });

  test('scan confirmation writes confirmed facts through CoachProfileProvider', () {
    final source = File(
      'lib/screens/document_scan/extraction_review_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('Provider.of<CoachProfileProvider>'),
      reason: 'Scan confirmation must obtain the canonical ledger provider.',
    );

    for (final call in <String>[
      'updateFromLppExtraction',
      'updateFromPartnerLppExtraction',
      'updateFromAvsExtraction',
      'updateFromTaxExtraction',
      'updateFromSalaryExtraction',
    ]) {
      expect(
        source,
        contains('coachProvider.$call'),
        reason: '$call must remain on the CoachProfileProvider write path.',
      );
    }
  });
}
