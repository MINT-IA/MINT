import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile code does not use legacy regulatory registry keys', () {
    final bannedKeys = <String, String>{
      'ac.employee_rate': 'ac.contribution_rate_employee',
      'ac.salary_ceiling': 'ac.max_insured_salary',
      'ac.solidarity_rate': 'ac.solidarity_rate_employee',
      'avs.employee_rate': 'avs.contribution_rate_employee',
      'avs.min_self_employed_contribution': 'avs.min_contribution_independent',
      'avs.voluntary_min': 'avs.voluntary_contribution_min',
      'avs.voluntary_max': 'avs.voluntary_contribution_max',
    };

    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final entry in bannedKeys.entries) {
        if (source.contains("'${entry.key}'") ||
            source.contains('"${entry.key}"')) {
          offenders.add('${file.path}: ${entry.key} -> ${entry.value}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Legacy regulatory keys silently fall back and bypass live registry overrides.',
    );
  });
}
