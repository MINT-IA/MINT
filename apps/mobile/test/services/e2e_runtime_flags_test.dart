import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';

void main() {
  tearDown(E2eRuntimeFlags.resetForTest);

  test('runtime E2E flags stay off by default in tests', () {
    E2eRuntimeFlags.resetForTest();

    expect(E2eRuntimeFlags.proofAnchors, isFalse);
    expect(E2eRuntimeFlags.mint2FirstExperienceEntry, isFalse);
  });

  test('runtime E2E flags can be overridden by focused tests', () {
    E2eRuntimeFlags.proofAnchorsOverride = true;
    E2eRuntimeFlags.mint2FirstExperienceEntryOverride = true;

    expect(E2eRuntimeFlags.proofAnchors, isTrue);
    expect(E2eRuntimeFlags.mint2FirstExperienceEntry, isTrue);
  });
}
