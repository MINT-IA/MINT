import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production code no longer consumes legacy ProfileProvider', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final allowedFiles = <String>{
      'lib/providers/profile_provider.dart',
      'lib/models/profile.dart',
    };
    final forbidden = RegExp(
      r'context\.(read|watch)<ProfileProvider>|'
      r'Provider\.of<ProfileProvider>|'
      r'Consumer<ProfileProvider>|'
      r'ChangeNotifierProvider\([^)]*=>\s*ProfileProvider\(',
      multiLine: true,
    );

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceFirst('lib/', '');
      final normalized = 'lib/$relative';
      if (allowedFiles.contains(normalized)) continue;
      final source = entity.readAsStringSync();
      if (forbidden.hasMatch(source)) {
        violations.add(normalized);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Financial production surfaces must read CoachProfileProvider, '
          'not the legacy ProfileProvider spine.',
    );
  });
}
