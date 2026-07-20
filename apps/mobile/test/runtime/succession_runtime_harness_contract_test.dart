import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('civil-guard seed persists ambiguous legacy status without onboarding',
      () {
    const target =
        'integration_test/g1_succession_civil_guard_seed_patrol_test.dart';
    const wrapper =
        'test/patrol/g1_succession_civil_guard_seed_runtime_test.dart';
    expect(File(target).existsSync(), isTrue, reason: target);
    expect(File(wrapper).existsSync(), isTrue, reason: wrapper);

    final source = _read(target);
    expect(source, contains('ReportPersistenceService.clearDiagnostic()'));
    expect(source, contains("'q_civil_status': 'partenariat'"));
    expect(source, contains('ReportPersistenceService.saveAnswers'));
    expect(source, contains('CoachProfileProvider()'));
    expect(source, contains('loadFromWizard()'));
    expect(source, contains('civilStatusNeedsConfirmation'));
    expect(source, contains('isMiniOnboardingCompleted()'));
    expect(source, isNot(contains('setMiniOnboardingCompleted')));
    expect(_read(wrapper), contains(target.split('/').last));
  });

  test('Patrol harness separates native, writer, and cold-reader processes',
      () {
    const nativePath =
        'integration_test/g1_succession_native_present_patrol_test.dart';
    const writerPath =
        'integration_test/g1_succession_absent_write_patrol_test.dart';
    const readerPath =
        'integration_test/g1_succession_cold_read_patrol_test.dart';
    for (final path in const [nativePath, writerPath, readerPath]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }

    final native = _read(nativePath);
    expect(native, contains('succession_instrument_will_source_date'));
    expect(native, contains('succession_instrument_will_legal_year'));
    expect(native, contains('ReportPersistenceService.loadAnswers()'));
    expect(native, contains('EstateInstrumentSlotState.confirmedPresent'));

    final writer = _read(writerPath);
    for (final selector in const <String>[
      'succession_arrangement_enum',
      'succession_arrangement_save',
      'succession_instrument_will_absent',
      'succession_answer_saved',
      'succession_next_question',
    ]) {
      expect(writer, contains(selector), reason: selector);
    }
    expect(writer, contains('successionWriterPid'));
    expect(writer, contains('successionWriterStateWitness'));
    expect(writer, contains('pid'));

    final reader = _read(readerPath);
    expect(reader, contains('pid, isNot(writerPid)'));
    expect(reader, contains('successionWriterStateWitness'));
    expect(reader, contains('writerState'));
    expect(reader, isNot(contains('saveAnswers(')));
    expect(reader, isNot(contains('clearDiagnostic(')));
    expect(reader, contains('succession_instrument_inheritancePact_question'));

    final support =
        _read('integration_test/support/g1_succession_runtime_contract.dart');
    expect(
      support,
      contains('tools/simulator/patrol_succession_evidence_process_death.sh'),
    );
  });

  test('all three tracked Patrol wrappers delegate to distinct stages', () {
    for (final entry in const <String, String>{
      'test/patrol/g1_succession_native_present_runtime_test.dart':
          'g1_succession_native_present_patrol_test.dart',
      'test/patrol/g1_succession_absent_write_runtime_test.dart':
          'g1_succession_absent_write_patrol_test.dart',
      'test/patrol/g1_succession_cold_read_runtime_test.dart':
          'g1_succession_cold_read_patrol_test.dart',
    }.entries) {
      expect(_read(entry.key), contains(entry.value), reason: entry.key);
    }
  });

  test('flag-on Maestro proves civil collector return using native IDs', () {
    final source = _read('.maestro/g1_succession_progressive.yaml');
    for (final selector in const <String>[
      'property_market_value_input',
      'patrimoine_save_cta',
      'succession_civil_status_guard',
      'succession_civil_status_confirm',
      'civil_status_single_choice',
      'household_save_cta',
      'succession_instrument_will_question',
    ]) {
      expect(source, contains('id: "$selector"'), reason: selector);
    }
    expect(source, isNot(contains('tapOn: "Confirmer"')));
  });

  test('production-default Maestro proves the quest is flag-off', () {
    final source = _read('.maestro/g1_succession_flag_off.yaml');
    expect(source, contains('id: "property_market_value_input"'));
    expect(source, isNot(contains('clearState: true')));
    expect(source, isNot(contains('openLink:')));

    final save = source.indexOf('id: "patrimoine_save_cta"');
    final scroll = source.indexOf('- scrollUntilVisible:', save);
    final marker = source.indexOf(
      'id: "succession_reference_quest_flag_off"',
      scroll,
    );
    final assertion = source.indexOf('- assertVisible:', marker);
    expect(save, greaterThanOrEqualTo(0));
    expect(scroll, greaterThan(save));
    expect(marker, greaterThan(scroll));
    expect(assertion, greaterThan(marker));
    expect(
      source.indexOf('id: "succession_reference_quest_flag_off"', assertion),
      greaterThan(assertion),
    );
  });
}
