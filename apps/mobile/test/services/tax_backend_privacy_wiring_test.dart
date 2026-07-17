import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CoachProfileProvider has no ongoing outbound profile claim', () {
    final source =
        File('lib/providers/coach_profile_provider.dart').readAsStringSync();

    expect(source, isNot(contains('ApiService.claimLocalData(')));
    expect(source, isNot(contains('_syncToBackend')));
    expect(source, isNot(contains('triggerBackendSync')));
    expect(source, isNot(contains('syncToBackend')));
    expect(source, contains('Future<void> syncFromBackend() async'));
  });

  test('AuthProvider anonymous migration uses the shared privacy helper', () {
    final source = File('lib/providers/auth_provider.dart').readAsStringSync();
    final body = _between(
      source,
      'Future<void> _migrateLocalDataIfNeeded(SessionEpochGuard guard) async',
      'Future<void> _hydrateProfileFromBackend(SessionEpochGuard guard) async',
    );

    expect(_safeHelperFeedsWizardPayload(body), isTrue);
  });
}

String _between(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $startMarker');
  expect(end, greaterThan(start), reason: 'missing $endMarker');
  return source.substring(start, end);
}

bool _safeHelperFeedsWizardPayload(String methodBody) {
  final inline = RegExp(
    r'wizardAnswers\s*:\s*ReportPersistenceService\.backendSafeAnswers\s*\(',
  );
  if (inline.hasMatch(methodBody)) return true;

  final assignment = RegExp(
    r'(?:final|var)\s+(\w+)\s*=\s*'
    r'ReportPersistenceService\.backendSafeAnswers\s*\(',
  ).firstMatch(methodBody);
  if (assignment == null) return false;
  final safeVariable = RegExp.escape(assignment.group(1)!);
  return RegExp('wizardAnswers\\s*:\\s*$safeVariable\\b').hasMatch(methodBody);
}
