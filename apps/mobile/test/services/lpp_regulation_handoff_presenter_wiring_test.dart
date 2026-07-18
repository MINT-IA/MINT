import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one pure localized presenter is shared by sheet and dossier', () {
    final presenter = File(
      'lib/services/report/lpp_regulation_handoff_section_content.dart',
    );
    expect(presenter.existsSync(), isTrue);
    final presenterSource =
        presenter.existsSync() ? presenter.readAsStringSync() : '';
    expect(presenterSource, contains('LppRegulationHandoffSectionContent'));
    expect(presenterSource, contains('LppRegulationSpecialistHandoff'));
    expect(presenterSource, contains('retirementLppRegulationReferenceBody'));
    expect(
        presenterSource, contains('retirementLppRegulationFundRelationship'));

    for (final path in <String>[
      'lib/screens/coach/retirement_dashboard_screen.dart',
      'lib/screens/advisor/financial_report_screen_v2.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('LppRegulationHandoffSectionContent.fromHandoff'),
        reason: path,
      );
    }
  });
}
