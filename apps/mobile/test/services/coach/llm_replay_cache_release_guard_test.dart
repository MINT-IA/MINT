/// Phase A5 (v2.13) — release-mode safety guard for LlmReplayCache.
///
/// Defence-in-depth contract :
///   - `mode` getter returns `'live'` under kReleaseMode regardless of
///     the dart-define value (production users never read fixtures).
///   - `lookup` throws `StateError` if reached under kReleaseMode (a
///     hypothetical caller that bypasses the `mode` check still trips).
///   - `isReplayActive` is false under kReleaseMode.
///
/// `flutter test` runs in debug mode by default, so we cannot directly
/// invoke kReleaseMode=true here. Instead this suite documents the
/// invariants on the debug-mode side and asserts that the « live by
/// default » contract holds when no dart-define is set — equivalent to
/// the production runtime path.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/llm_replay_cache.dart';

void main() {
  group('LlmReplayCache — release-mode safety contract', () {
    test('default mode is live when no dart-define is set', () {
      // `flutter test` does not pass --dart-define, so _modeDefine
      // resolves to its `defaultValue: 'live'`. This is the same
      // condition production users hit (they also have no override),
      // PLUS production has the kReleaseMode short-circuit.
      expect(LlmReplayCache.mode, equals('live'));
      expect(LlmReplayCache.isReplayActive, isFalse);
    });

    test('lookup returns null when mode is live', () async {
      // When mode is live, lookup MUST return null so callers fall
      // through to the real HTTP path. No fixture data leaks out.
      final result = await LlmReplayCache.lookup(
        turn: 1,
        prompt: 'test',
        locale: 'fr',
      );
      expect(result, isNull);
    });

    test('kReleaseMode constant is wired', () {
      // Sanity : the import compiles and the constant is reachable.
      // In `flutter test` this is false ; in TestFlight/App Store
      // builds it is true and the safety guards engage.
      expect(kReleaseMode, isA<bool>());
    });
  });
}
