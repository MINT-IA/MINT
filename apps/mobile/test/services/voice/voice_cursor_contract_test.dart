// Tests for VoiceCursorContract.resolveLevel — precedence cascade.
//
// Coverage target: ≥ 80 tests across the 6 cascade stages + edge cases.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';

VoiceLevel _resolve({
  Gravity gravity = Gravity.g1,
  Relation relation = Relation.relNew,
  VoicePreference preference = VoicePreference.direct,
  bool sensitiveFlag = false,
  bool fragileFlag = false,
  int n5Budget = 1,
}) {
  return resolveLevel(
    gravity: gravity,
    relation: relation,
    preference: preference,
    sensitiveFlag: sensitiveFlag,
    fragileFlag: fragileFlag,
    n5Budget: n5Budget,
  );
}

void main() {
  group('contract metadata', () {
    test('version is 0.5.0', () {
      expect(voiceCursorContractVersion, '0.5.0');
    });
    test('matrix has 3 gravities × 3 relations × 3 preferences = 27 cells', () {
      var count = 0;
      for (final g in voiceCursorMatrix.values) {
        for (final r in g.values) {
          count += r.length;
        }
      }
      expect(count, 27);
    });
    test('precedence cascade has 6 stages in canonical order', () {
      expect(voiceCursorPrecedenceCascade, [
        'sensitivityGuard',
        'fragilityCap',
        'n5WeeklyBudget',
        'gravityFloor',
        'preferenceCap',
        'matrixDefault',
      ]);
    });
    test('sensitive topics include the 4 doctrinal anchors', () {
      expect(sensitiveTopics, containsAll(<String>['deuil', 'divorce', 'perteEmploi', 'maladieGrave']));
    });
    test('caps are frozen at expected values', () {
      expect(n5PerWeekMax, 1);
      expect(fragileModeDurationDays, 30);
      expect(fragileModeCapLevel, VoiceLevel.n3);
      expect(sensitiveTopicCapLevel, VoiceLevel.n3);
      expect(g3FloorLevel, VoiceLevel.n2);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Stage 6: matrixDefault — every cell is reachable when no other rule fires.
  // ───────────────────────────────────────────────────────────────────────
  group('matrixDefault — 27 cells', () {
    final expected = <String, VoiceLevel>{
      'g1.relNew.soft':        VoiceLevel.n1,
      'g1.relNew.direct':      VoiceLevel.n1,
      'g1.relNew.unfiltered':  VoiceLevel.n2,
      'g1.established.soft':   VoiceLevel.n2,
      'g1.established.direct': VoiceLevel.n2,
      'g1.established.unfiltered': VoiceLevel.n2,
      'g1.intimate.soft':      VoiceLevel.n2,
      'g1.intimate.direct':    VoiceLevel.n3,
      'g1.intimate.unfiltered': VoiceLevel.n3,
      'g2.relNew.soft':        VoiceLevel.n2,
      'g2.relNew.direct':      VoiceLevel.n2,
      'g2.relNew.unfiltered':  VoiceLevel.n2,
      'g2.established.soft':   VoiceLevel.n3,
      'g2.established.direct': VoiceLevel.n4,
      'g2.established.unfiltered': VoiceLevel.n4,
      'g2.intimate.soft':      VoiceLevel.n3,
      'g2.intimate.direct':    VoiceLevel.n4,
      'g2.intimate.unfiltered': VoiceLevel.n4,
      // G3 + soft: matrix N4 capped to N3 by preferenceCap
      'g3.relNew.soft':        VoiceLevel.n3,
      'g3.relNew.direct':      VoiceLevel.n4,
      'g3.relNew.unfiltered':  VoiceLevel.n4,
      'g3.established.soft':   VoiceLevel.n3,
      'g3.established.direct': VoiceLevel.n5,
      'g3.established.unfiltered': VoiceLevel.n5,
      'g3.intimate.soft':      VoiceLevel.n3,
      'g3.intimate.direct':    VoiceLevel.n5,
      'g3.intimate.unfiltered': VoiceLevel.n5,
    };

    for (final g in Gravity.values) {
      for (final r in Relation.values) {
        for (final p in VoicePreference.values) {
          final key = '${g.name}.${r.name}.${p.name}';
          test('cell $key', () {
            expect(_resolve(gravity: g, relation: r, preference: p), expected[key]);
          });
        }
      }
    }
  });

  // ───────────────────────────────────────────────────────────────────────
  // Stage 5: preferenceCap — soft caps at N3.
  // ───────────────────────────────────────────────────────────────────────
  group('preferenceCap — soft never exceeds N3', () {
    for (final g in Gravity.values) {
      for (final r in Relation.values) {
        test('soft cap on ${g.name}/${r.name}', () {
          final lvl = _resolve(gravity: g, relation: r, preference: VoicePreference.soft);
          expect(lvl.index <= VoiceLevel.n3.index || (g == Gravity.g3 && lvl == VoiceLevel.n4), isTrue,
              reason: 'soft preference must cap at N3, except G3 floor handling');
          // soft is never N5
          expect(lvl, isNot(VoiceLevel.n5));
        });
      }
    }
    test('unfiltered allows N5 on G3/established', () {
      expect(
          _resolve(gravity: Gravity.g3, relation: Relation.established, preference: VoicePreference.unfiltered),
          VoiceLevel.n5);
    });
    test('direct allows N5 on G3/intimate', () {
      expect(
          _resolve(gravity: Gravity.g3, relation: Relation.intimate, preference: VoicePreference.direct),
          VoiceLevel.n5);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Stage 4: gravityFloor — G3 never below N2.
  // ───────────────────────────────────────────────────────────────────────
  group('gravityFloor — G3 floor at N2', () {
    for (final r in Relation.values) {
      test('G3/${r.name}/soft never below N2', () {
        final lvl = _resolve(gravity: Gravity.g3, relation: r, preference: VoicePreference.soft);
        expect(lvl.index >= VoiceLevel.n2.index, isTrue);
      });
    }
    test('G3 + soft + sensitive + fragile + budget=0 still ≥ N2', () {
      final lvl = _resolve(
        gravity: Gravity.g3,
        relation: Relation.relNew,
        preference: VoicePreference.soft,
        sensitiveFlag: true,
        fragileFlag: true,
        n5Budget: 0,
      );
      expect(lvl.index >= VoiceLevel.n2.index, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Stage 3: n5WeeklyBudget — exhausted budget downgrades N5 → N4.
  // ───────────────────────────────────────────────────────────────────────
  group('n5WeeklyBudget — downgrade when exhausted', () {
    final n5Cells = <List<dynamic>>[
      [Gravity.g3, Relation.established, VoicePreference.direct],
      [Gravity.g3, Relation.established, VoicePreference.unfiltered],
      [Gravity.g3, Relation.intimate, VoicePreference.direct],
      [Gravity.g3, Relation.intimate, VoicePreference.unfiltered],
    ];

    for (final cell in n5Cells) {
      test('${cell[0]}/${cell[1]}/${cell[2]} → N5 with budget=1', () {
        expect(
            _resolve(
              gravity: cell[0] as Gravity,
              relation: cell[1] as Relation,
              preference: cell[2] as VoicePreference,
              n5Budget: 1,
            ),
            VoiceLevel.n5);
      });
      test('${cell[0]}/${cell[1]}/${cell[2]} downgrades to N4 with budget=0', () {
        expect(
            _resolve(
              gravity: cell[0] as Gravity,
              relation: cell[1] as Relation,
              preference: cell[2] as VoicePreference,
              n5Budget: 0,
            ),
            VoiceLevel.n4);
      });
      test('${cell[0]}/${cell[1]}/${cell[2]} downgrades to N4 with budget=-3', () {
        expect(
            _resolve(
              gravity: cell[0] as Gravity,
              relation: cell[1] as Relation,
              preference: cell[2] as VoicePreference,
              n5Budget: -3,
            ),
            VoiceLevel.n4);
      });
    }

    test('N4 cells unaffected by n5Budget exhaustion', () {
      expect(
          _resolve(
            gravity: Gravity.g2,
            relation: Relation.established,
            preference: VoicePreference.direct,
            n5Budget: 0,
          ),
          VoiceLevel.n4);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Stage 2: fragilityCap — fragile flag caps at N3.
  // ───────────────────────────────────────────────────────────────────────
  group('fragilityCap — fragile mode caps at N3', () {
    for (final g in Gravity.values) {
      for (final r in Relation.values) {
        test('fragile on ${g.name}/${r.name}/direct never above N3 (modulo G3 floor)', () {
          final lvl = _resolve(
            gravity: g,
            relation: r,
            preference: VoicePreference.direct,
            fragileFlag: true,
          );
          // fragile cap = N3; G3 floor = N2; so result ∈ {N2, N3} for low matrix, N3 for high
          expect(lvl.index <= VoiceLevel.n3.index, isTrue);
          if (g == Gravity.g3) {
            expect(lvl.index >= VoiceLevel.n2.index, isTrue);
          }
        });
      }
    }
    test('fragile + unfiltered + G3/established → N3 (not N5)', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.established,
            preference: VoicePreference.unfiltered,
            fragileFlag: true,
          ),
          VoiceLevel.n3);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Stage 1: sensitivityGuard — sensitive topics cap at N3.
  // ───────────────────────────────────────────────────────────────────────
  group('sensitivityGuard — sensitive topics cap at N3', () {
    for (final g in Gravity.values) {
      for (final r in Relation.values) {
        test('sensitive on ${g.name}/${r.name}/direct never above N3', () {
          final lvl = _resolve(
            gravity: g,
            relation: r,
            preference: VoicePreference.direct,
            sensitiveFlag: true,
          );
          expect(lvl.index <= VoiceLevel.n3.index, isTrue);
          if (g == Gravity.g3) {
            expect(lvl.index >= VoiceLevel.n2.index, isTrue, reason: 'G3 floor still applies');
          }
        });
      }
    }
    test('sensitive + unfiltered + G3/intimate → N3 (anti-shame doctrine)', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.intimate,
            preference: VoicePreference.unfiltered,
            sensitiveFlag: true,
          ),
          VoiceLevel.n3);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Precedence ordering — combined-flag edge cases.
  // ───────────────────────────────────────────────────────────────────────
  group('precedence ordering — combined edges', () {
    test('sensitive + fragile + budget=0 + unfiltered + G3/intimate → N3', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.intimate,
            preference: VoicePreference.unfiltered,
            sensitiveFlag: true,
            fragileFlag: true,
            n5Budget: 0,
          ),
          VoiceLevel.n3);
    });
    test('fragile alone on G3/direct → N3', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.intimate,
            preference: VoicePreference.direct,
            fragileFlag: true,
          ),
          VoiceLevel.n3);
    });
    test('sensitive alone on G3/established → N3', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.established,
            preference: VoicePreference.direct,
            sensitiveFlag: true,
          ),
          VoiceLevel.n3);
    });
    test('budget=0 alone on G3/established/direct → N4', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.established,
            preference: VoicePreference.direct,
            n5Budget: 0,
          ),
          VoiceLevel.n4);
    });
    test('soft + G3/relNew → at least N2 (G3 floor wins over soft cap downward)', () {
      final lvl = _resolve(
        gravity: Gravity.g3,
        relation: Relation.relNew,
        preference: VoicePreference.soft,
      );
      expect(lvl.index >= VoiceLevel.n2.index, isTrue);
    });
    test('soft + G1/relNew → N1 (no floor for G1)', () {
      expect(_resolve(gravity: Gravity.g1, relation: Relation.relNew, preference: VoicePreference.soft),
          VoiceLevel.n1);
    });
    test('soft + G2/established → N3 (matrix already at cap)', () {
      expect(_resolve(gravity: Gravity.g2, relation: Relation.established, preference: VoicePreference.soft),
          VoiceLevel.n3);
    });
    test('unfiltered + G2/established → N4 (no upgrade past matrix)', () {
      expect(
          _resolve(gravity: Gravity.g2, relation: Relation.established, preference: VoicePreference.unfiltered),
          VoiceLevel.n4);
    });
    test('fragile + G1/relNew/soft → N1 (cap doesn\'t lift floor)', () {
      expect(
          _resolve(
            gravity: Gravity.g1,
            relation: Relation.relNew,
            preference: VoicePreference.soft,
            fragileFlag: true,
          ),
          VoiceLevel.n1);
    });
    test('sensitive + G1/relNew/soft → N1 (cap doesn\'t lift floor)', () {
      expect(
          _resolve(
            gravity: Gravity.g1,
            relation: Relation.relNew,
            preference: VoicePreference.soft,
            sensitiveFlag: true,
          ),
          VoiceLevel.n1);
    });
    test('sensitive overrides budget (even if budget>0, sensitive wins)', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.intimate,
            preference: VoicePreference.unfiltered,
            sensitiveFlag: true,
            n5Budget: 99,
          ),
          VoiceLevel.n3);
    });
    test('fragile overrides budget', () {
      expect(
          _resolve(
            gravity: Gravity.g3,
            relation: Relation.intimate,
            preference: VoicePreference.unfiltered,
            fragileFlag: true,
            n5Budget: 99,
          ),
          VoiceLevel.n3);
    });
    test('sensitive + fragile (no other flags) on G2/intimate/direct → N3', () {
      expect(
          _resolve(
            gravity: Gravity.g2,
            relation: Relation.intimate,
            preference: VoicePreference.direct,
            sensitiveFlag: true,
            fragileFlag: true,
          ),
          VoiceLevel.n3);
    });
    test('budget exhaustion alone on N4-cell is no-op (G2/established/direct)', () {
      expect(
          _resolve(
            gravity: Gravity.g2,
            relation: Relation.established,
            preference: VoicePreference.direct,
            n5Budget: 0,
          ),
          VoiceLevel.n4);
    });
    test('budget exhaustion alone on N1-cell is no-op (G1/relNew/soft)', () {
      expect(
          _resolve(
            gravity: Gravity.g1,
            relation: Relation.relNew,
            preference: VoicePreference.soft,
            n5Budget: 0,
          ),
          VoiceLevel.n1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Purity smoke — same inputs → same output, repeatedly.
  // ───────────────────────────────────────────────────────────────────────
  group('purity', () {
    test('resolveLevel is deterministic', () {
      final args = <Map<String, dynamic>>[
        {'gravity': Gravity.g1, 'relation': Relation.relNew, 'preference': VoicePreference.direct},
        {'gravity': Gravity.g3, 'relation': Relation.intimate, 'preference': VoicePreference.unfiltered},
      ];
      for (final a in args) {
        final first = resolveLevel(
          gravity: a['gravity'] as Gravity,
          relation: a['relation'] as Relation,
          preference: a['preference'] as VoicePreference,
          sensitiveFlag: false,
          fragileFlag: false,
          n5Budget: 1,
        );
        for (var i = 0; i < 5; i++) {
          expect(
              resolveLevel(
                gravity: a['gravity'] as Gravity,
                relation: a['relation'] as Relation,
                preference: a['preference'] as VoicePreference,
                sensitiveFlag: false,
                fragileFlag: false,
                n5Budget: 1,
              ),
              first);
        }
      }
    });
  });
}
