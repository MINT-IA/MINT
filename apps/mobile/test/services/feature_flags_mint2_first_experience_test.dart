import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/e2e_runtime_flags.dart';
import 'package:mint_mobile/services/feature_flags.dart';

void main() {
  setUp(() {
    E2eRuntimeFlags.resetForTest();
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  tearDown(() {
    E2eRuntimeFlags.resetForTest();
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  test('Mint 2 first experience flag is default-off and server-wired', () {
    final source = File('lib/services/feature_flags.dart').readAsStringSync();

    expect(
      source,
      contains('static bool enableMint2FirstExperienceEntry = false'),
      reason: 'Mint 2 first-entry UI must stay behind a default-off flag.',
    );
    expect(
      source,
      contains("data.containsKey('enableMint2FirstExperienceEntry')"),
      reason: 'The flag must be overridable through applyFromMap.',
    );
  });

  test('Mint 2 first experience flag uses strict bool server overrides', () {
    expect(FeatureFlags.enableMint2FirstExperienceEntry, isFalse);

    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': true},
    );
    expect(FeatureFlags.enableMint2FirstExperienceEntry, isTrue);

    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': 'true'},
    );
    expect(
      FeatureFlags.enableMint2FirstExperienceEntry,
      isFalse,
      reason: 'Only the literal bool true may enable the Slice 2B/2C UI.',
    );

    FeatureFlags.enableMint2FirstExperienceEntry = true;
    FeatureFlags.applyFromMap(const <String, dynamic>{});
    expect(
      FeatureFlags.enableMint2FirstExperienceEntry,
      isTrue,
      reason: 'Unrelated config refreshes must not kill an already-set flag.',
    );
  });

  test('Mint 2 E2E runtime override survives a server false flag in debug', () {
    E2eRuntimeFlags.mint2FirstExperienceEntryOverride = true;

    FeatureFlags.applyFromMap(
      const <String, dynamic>{'enableMint2FirstExperienceEntry': false},
    );

    expect(
      FeatureFlags.enableMint2FirstExperienceEntry,
      isTrue,
      reason:
          'The iPhone 13 mini runtime proof must not depend on staging flag rollout.',
    );
  });
}
