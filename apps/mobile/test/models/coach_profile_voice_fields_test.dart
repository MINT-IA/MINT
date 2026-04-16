// Phase 02-03: CoachProfile voice cursor field tests.
//
// Covers:
//   - Defaults (direct / 0 / null)
//   - Round-trip serialization
//   - copyWith semantics
//   - Legacy payload (missing fields → defaults)
//   - Invalid enum string → fallback to direct
//   - Equality / hashCode include the new fields
//   - ARB grep gate: no "curseur" word in any user-facing ARB value
//     across all 6 supported locales (CLAUDE.md constraint —
//     "curseur" is internal terminology only).
//   - Absence gate: NO ARB keys for n5IssuedThisWeek or fragileModeEnteredAt.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;

CoachProfile _baseProfile({
  VoicePreference? voiceCursorPreference,
  int? n5IssuedThisWeek,
  DateTime? fragileModeEnteredAt,
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VS',
    salaireBrutMensuel: 8000,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'retraite',
    ),
    voiceCursorPreference:
        voiceCursorPreference ?? VoicePreference.direct,
    n5IssuedThisWeek: n5IssuedThisWeek ?? 0,
    fragileModeEnteredAt: fragileModeEnteredAt,
  );
}

void main() {
  group('CoachProfile voice cursor — defaults', () {
    test('default voiceCursorPreference is direct', () {
      final p = CoachProfile(
        birthYear: 1985,
        canton: 'VS',
        salaireBrutMensuel: 8000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'retraite',
        ),
      );
      expect(p.voiceCursorPreference, VoicePreference.direct);
      expect(p.n5IssuedThisWeek, 0);
      expect(p.fragileModeEnteredAt, isNull);
    });
  });

  group('CoachProfile voice cursor — round-trip', () {
    test('soft preference round-trips through JSON', () {
      final p = _baseProfile(voiceCursorPreference: VoicePreference.soft);
      final round = CoachProfile.fromJson(p.toJson());
      expect(round.voiceCursorPreference, VoicePreference.soft);
    });

    test('unfiltered preference round-trips through JSON', () {
      final p =
          _baseProfile(voiceCursorPreference: VoicePreference.unfiltered);
      final round = CoachProfile.fromJson(p.toJson());
      expect(round.voiceCursorPreference, VoicePreference.unfiltered);
    });

    test('n5IssuedThisWeek round-trips through JSON', () {
      final p = _baseProfile(n5IssuedThisWeek: 4);
      final round = CoachProfile.fromJson(p.toJson());
      expect(round.n5IssuedThisWeek, 4);
    });

    test('fragileModeEnteredAt round-trips through JSON', () {
      final ts = DateTime.utc(2026, 4, 7, 12, 0);
      final p = _baseProfile(fragileModeEnteredAt: ts);
      final round = CoachProfile.fromJson(p.toJson());
      expect(round.fragileModeEnteredAt, ts);
    });
  });

  group('CoachProfile voice cursor — copyWith', () {
    test('copyWith updates voiceCursorPreference', () {
      final p = _baseProfile();
      final copy = p.copyWith(voiceCursorPreference: VoicePreference.soft);
      expect(copy.voiceCursorPreference, VoicePreference.soft);
      expect(p.voiceCursorPreference, VoicePreference.direct);
    });

    test('copyWith updates n5IssuedThisWeek', () {
      final p = _baseProfile();
      final copy = p.copyWith(n5IssuedThisWeek: 1);
      expect(copy.n5IssuedThisWeek, 1);
      expect(p.n5IssuedThisWeek, 0);
    });

    test('copyWith updates fragileModeEnteredAt', () {
      final p = _baseProfile();
      final ts = DateTime.utc(2026, 4, 7);
      final copy = p.copyWith(fragileModeEnteredAt: ts);
      expect(copy.fragileModeEnteredAt, ts);
      expect(p.fragileModeEnteredAt, isNull);
    });
  });

  group('CoachProfile voice cursor — legacy / invalid payloads', () {
    test('legacy JSON without voice fields gets defaults', () {
      final legacy = {
        'birthYear': 1985,
        'canton': 'VS',
        'salaireBrutMensuel': 8000,
        'goalA': GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'retraite',
        ).toJson(),
      };
      final p = CoachProfile.fromJson(legacy);
      expect(p.voiceCursorPreference, VoicePreference.direct);
      expect(p.n5IssuedThisWeek, 0);
      expect(p.fragileModeEnteredAt, isNull);
    });

    test('invalid voiceCursorPreference string falls back to direct', () {
      final p = _baseProfile();
      final json = p.toJson();
      json['voiceCursorPreference'] = 'agressive';
      final round = CoachProfile.fromJson(json);
      expect(round.voiceCursorPreference, VoicePreference.direct);
    });
  });

  group('CoachProfile voice cursor — equality', () {
    test('equality differs when voice preference differs', () {
      final a = _baseProfile();
      final b = _baseProfile(voiceCursorPreference: VoicePreference.soft);
      expect(a == b, isFalse);
    });
  });

  group('ARB grep gate — voice cursor internal term must not leak', () {
    // Plan 02-03 §threat T-02-11: the term "voice cursor" / "curseur de
    // voix" is internal jargon. The user-facing "Ton" chooser must NEVER
    // surface it. We scope the grep to keys starting with "voiceCursor"
    // because pre-existing French strings legitimately use "curseur" for
    // unrelated UI sliders (e.g. genderGapIntro). The leak we guard
    // against is "voiceCursor*" labels accidentally exposing the term.
    final arbFiles = [
      'lib/l10n/app_fr.arb',
      'lib/l10n/app_en.arb',
      'lib/l10n/app_de.arb',
      'lib/l10n/app_es.arb',
      'lib/l10n/app_it.arb',
      'lib/l10n/app_pt.arb',
    ];

    for (final path in arbFiles) {
      test('$path voiceCursor* labels contain no "curseur" / "cursor"', () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path missing');
        final decoded =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.key.startsWith('@')) continue;
          if (!entry.key.startsWith('voiceCursor')) continue;
          final value = entry.value;
          if (value is String) {
            final lower = value.toLowerCase();
            expect(lower.contains('curseur'), isFalse,
                reason:
                    '$path key="${entry.key}" leaks "curseur": $value');
            expect(lower.contains('cursor'), isFalse,
                reason:
                    '$path key="${entry.key}" leaks "cursor": $value');
          }
        }
      });
    }
  });

  group('ARB absence gate — internal voice fields must NOT have ARB keys',
      () {
    test('no ARB key references n5IssuedThisWeek or fragileModeEnteredAt',
        () {
      final arbFiles = [
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_en.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pt.arb',
      ];
      for (final path in arbFiles) {
        final raw = File(path).readAsStringSync();
        expect(raw.contains('n5IssuedThisWeek'), isFalse,
            reason: '$path leaks n5IssuedThisWeek');
        expect(raw.contains('fragileModeEnteredAt'), isFalse,
            reason: '$path leaks fragileModeEnteredAt');
      }
    });

    // ── Phase 11 (VOICE-09/10): recentGravityEvents round-trip ───────────
    group('recentGravityEvents (Phase 11)', () {
      test('default is empty list', () {
        final p = _baseProfile();
        expect(p.recentGravityEvents, isEmpty);
      });

      test('round-trip preserves entries', () {
        final p = _baseProfile().copyWith(
          recentGravityEvents: [
            {'ts': '2026-04-01T10:00:00Z', 'gravity': 'G2'},
            {'ts': '2026-04-05T14:30:00Z', 'gravity': 'G3'},
          ],
        );
        final restored = CoachProfile.fromJson(jsonDecode(jsonEncode(p.toJson())));
        expect(restored.recentGravityEvents, hasLength(2));
        expect(restored.recentGravityEvents[0]['gravity'], 'G2');
        expect(restored.recentGravityEvents[1]['gravity'], 'G3');
        expect(restored.recentGravityEvents[1]['ts'], '2026-04-05T14:30:00Z');
      });

      test('legacy payload missing key → empty list', () {
        // Build payload then strip the field to simulate legacy persistence.
        final p = _baseProfile();
        final raw = p.toJson()..remove('recentGravityEvents');
        final restored = CoachProfile.fromJson(raw);
        expect(restored.recentGravityEvents, isEmpty);
      });

      test('equality includes recentGravityEvents', () {
        final a = _baseProfile().copyWith(recentGravityEvents: [
          {'ts': '2026-04-01T10:00:00Z', 'gravity': 'G2'},
        ]);
        final b = _baseProfile().copyWith(recentGravityEvents: [
          {'ts': '2026-04-01T10:00:00Z', 'gravity': 'G3'},
        ]);
        expect(a == b, isFalse);
      });

      test('copyWith preserves recentGravityEvents when not overridden', () {
        final original = _baseProfile().copyWith(recentGravityEvents: [
          {'ts': '2026-04-01T10:00:00Z', 'gravity': 'G2'},
        ]);
        final updated = original.copyWith(n5IssuedThisWeek: 1);
        expect(updated.recentGravityEvents, hasLength(1));
        expect(updated.recentGravityEvents[0]['gravity'], 'G2');
      });

      test('ARB files do NOT leak recentGravityEvents key', () {
        const arbFiles = [
          'lib/l10n/app_fr.arb',
          'lib/l10n/app_en.arb',
          'lib/l10n/app_de.arb',
          'lib/l10n/app_es.arb',
          'lib/l10n/app_it.arb',
          'lib/l10n/app_pt.arb',
        ];
        for (final path in arbFiles) {
          final raw = File(path).readAsStringSync();
          expect(raw.contains('recentGravityEvents'), isFalse,
              reason: '$path leaks recentGravityEvents');
        }
      });
    });

    test('all 6 locales have the 4 voice cursor preference labels', () {
      final arbFiles = {
        'fr': 'lib/l10n/app_fr.arb',
        'en': 'lib/l10n/app_en.arb',
        'de': 'lib/l10n/app_de.arb',
        'es': 'lib/l10n/app_es.arb',
        'it': 'lib/l10n/app_it.arb',
        'pt': 'lib/l10n/app_pt.arb',
      };
      const requiredKeys = [
        'voiceCursorPreferenceLabel',
        'voiceCursorPreferenceSoft',
        'voiceCursorPreferenceDirect',
        'voiceCursorPreferenceUnfiltered',
      ];
      for (final entry in arbFiles.entries) {
        final decoded =
            jsonDecode(File(entry.value).readAsStringSync()) as Map<String, dynamic>;
        for (final k in requiredKeys) {
          expect(decoded.containsKey(k), isTrue,
              reason: '${entry.key} missing $k');
          expect(decoded[k], isA<String>());
          expect((decoded[k] as String).isNotEmpty, isTrue);
        }
      }
    });
  });
}
