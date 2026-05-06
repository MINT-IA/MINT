// Phase 91 Plan 91-01 (VIVANT-04) — round-trip + default-fallback tests
// for [CoachTonePreferenceStore].

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/preferences/coach_tone_preference.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CoachTonePreference', () {
    test('default = calm when key is missing', () async {
      const store = CoachTonePreferenceStore();
      final value = await store.load();
      expect(value, CoachTonePreference.calm);
    });

    test('save then load round-trips for every enum value', () async {
      const store = CoachTonePreferenceStore();
      for (final pref in CoachTonePreference.values) {
        SharedPreferences.setMockInitialValues({});
        final ok = await store.save(pref);
        expect(ok, isTrue, reason: 'save() returned false for ${pref.name}');
        final loaded = await store.load();
        expect(loaded, pref, reason: 'round-trip mismatch for ${pref.name}');
      }
    });

    test('unknown stored string falls back to calm (forward-compat)',
        () async {
      // Simulate a future enum value that the current binary does not
      // know about. The store MUST NOT crash — it returns the safe
      // default so the user can still chat.
      SharedPreferences.setMockInitialValues({
        'coach_tone_preference': 'futureMode',
      });
      const store = CoachTonePreferenceStore();
      final value = await store.load();
      expect(value, CoachTonePreference.calm);
    });

    test('decodeCoachTone helper is exhaustive on enum values', () {
      expect(decodeCoachTone('calm'), CoachTonePreference.calm);
      expect(decodeCoachTone('direct'), CoachTonePreference.direct);
      expect(decodeCoachTone('sansFilter'), CoachTonePreference.sansFilter);
    });

    test('decodeCoachTone returns calm for null and empty', () {
      expect(decodeCoachTone(null), CoachTonePreference.calm);
      expect(decodeCoachTone(''), CoachTonePreference.calm);
    });

    test('wireName matches enum.name', () {
      expect(CoachTonePreference.calm.wireName, 'calm');
      expect(CoachTonePreference.direct.wireName, 'direct');
      expect(CoachTonePreference.sansFilter.wireName, 'sansFilter');
    });

    test('SharedPreferences key is the contract value', () {
      // Locking this constant — the Maestro flow + any external migration
      // tool reads this key directly.
      expect(coachTonePreferenceKey, 'coach_tone_preference');
    });

    test('save persists to the contract key as a String', () async {
      const store = CoachTonePreferenceStore();
      await store.save(CoachTonePreference.direct);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(coachTonePreferenceKey), 'direct');
    });
  });
}
