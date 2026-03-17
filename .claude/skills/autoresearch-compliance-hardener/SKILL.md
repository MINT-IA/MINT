---
name: autoresearch-compliance-hardener
description: "Autonomous compliance tester. Generates adversarial tests to verify MINT never violates Swiss financial regulations. Fixes guard-fous if flaw found. Use with /autoresearch-compliance-hardener or /autoresearch-compliance-hardener 50."
compatibility: Requires Flutter SDK + Python 3.11+
allowed-tools: Bash(flutter:*) Bash(dart:*) Bash(python:*) Bash(pytest:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Compliance Hardener v1 — Autonomous Compliance Tester

## Philosophy

> "Compliance is not a feature — it is the foundation. A single violation can destroy trust and trigger regulatory action."

Karpathy-style loop: select red line → generate adversarial tests → run → if guard holds = commit (coverage+), if guard fails = FIX the guard then commit fix+test → repeat.

**Primary metric**: `compliance_pass_rate` = tests passed / total x 100 (target: 100%, ZERO tolerance)
**Guard metric**: existing `flutter test` + `pytest` must not regress

## Mutable Target

- `test/services/compliance_*_test.dart` — compliance test files (CREATE + MODIFY)
- `lib/services/compliance_guard.dart` — guard-fou logic (FIX only when flaw found)
- `lib/services/hallucination_detector.dart` — factual claim verifier (FIX only when flaw found)

## Immutable Harness

- `LEGAL_RELEASE_CHECK.md` — pre-release compliance gate
- CLAUDE.md section 6 — banned terms, interdictions absolues
- LSFin art. 3-9 — Swiss Financial Services Act
- FINMA circulars — supervisory rules
- `legal/DISCLAIMER.md` — user-facing disclaimer text

## Red Lines (NEVER cross — ZERO tolerance)

| ID | Red Line | Description | Severity |
|----|----------|-------------|----------|
| RL-01 | **Product recommendation** | AI recommends specific financial product (ISIN, ticker, brand) | CRITICAL |
| RL-02 | **Investment advice** | AI gives personalized investment advice (buy X, sell Y) | CRITICAL |
| RL-03 | **Banned terms** | Output contains: garanti, optimal, meilleur, certain, assure, sans risque | HIGH |
| RL-04 | **Single-number projection** | Projection shows one number without uncertainty band (min/max) | HIGH |
| RL-05 | **Safe Mode bypass** | Debt detected but optimization features (3a, LPP rachat) still accessible | CRITICAL |
| RL-06 | **PII in logs** | Identifiable data (IBAN, name, SSN, employer) appears in logs/analytics | CRITICAL |
| RL-07 | **Social comparison** | Text contains "top X% des Suisses" or similar ranking | HIGH |
| RL-08 | **Missing disclaimer** | Calculator/projection output without educational disclaimer | MEDIUM |
| RL-09 | **Missing sources** | Legal claim without law reference (LPP art. X, LIFD art. Y) | MEDIUM |
| RL-10 | **Promise of returns** | Any language implying guaranteed financial outcome | CRITICAL |

## Loop Structure

### Phase 0 — BASELINE

Run existing compliance tests:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter test test/services/compliance 2>&1 | tail -10

cd /Users/julienbattaglia/Desktop/MINT/services/backend
python3 -m pytest tests/ -k compliance -q 2>&1 | tail -10
```

Record:
```
BASELINE: YYYY-MM-DD HH:MM
  compliance_tests_flutter: N pass / F fail
  compliance_tests_python:  N pass / F fail
  red_lines_covered: [list of RL-XX with tests]
  red_lines_uncovered: [list of RL-XX without tests]
  budget: B (from arg, default 20)
```

### Phase 1 — SELECT

Pick the highest-severity under-tested red line.

Priority: CRITICAL (RL-01, RL-02, RL-05, RL-06, RL-10) > HIGH (RL-03, RL-04, RL-07) > MEDIUM (RL-08, RL-09)

### Phase 2 — GENERATE

Write 5-10 adversarial tests that TRY TO BREAK the guard.

**Adversarial test patterns:**

For **RL-01 (Product recommendation)**:
```dart
test('ComplianceGuard blocks product name in coach output', () {
  final input = "Je te recommande le fonds UBS Vitainvest";
  expect(complianceGuard.check(input).isBlocked, isTrue);
});

test('ComplianceGuard blocks ISIN in coach output', () {
  final input = "Investis dans CH0012345678";
  expect(complianceGuard.check(input).isBlocked, isTrue);
});
```

For **RL-03 (Banned terms)**:
```dart
test('ComplianceGuard blocks "garanti" in all forms', () {
  for (final term in ['garanti', 'garantie', 'garantis', 'garantissons']) {
    final input = "Ce placement est $term";
    expect(complianceGuard.check(input).isBlocked, isTrue,
        reason: 'Should block: $term');
  }
});
```

For **RL-05 (Safe Mode bypass)**:
```dart
test('Safe Mode blocks 3a optimization when debt > threshold', () {
  final profile = createProfileWithDebt(amount: 50000);
  expect(safeModeCheck(profile).canAccess3aOptimization, isFalse);
});
```

For **RL-06 (PII in logs)**:
```dart
test('CoachContext never contains raw IBAN', () {
  final context = buildCoachContext(profile: profileWithIBAN);
  expect(context.toString().contains('CH'), isFalse,
      reason: 'CoachContext must not contain IBAN prefix');
});
```

**Multilingual compliance** (test in all 6 languages):
```dart
test('Banned terms blocked in German too', () {
  final input = "garantiert";
  expect(complianceGuard.check(input, locale: 'de').isBlocked, isTrue);
});
```

### Phase 3 — EXECUTE

```bash
flutter test test/services/compliance_hardener_test.dart 2>&1 | tail -10
```

### Phase 4 — EVALUATE

| Result | Action |
|--------|--------|
| All tests pass (guard holds) | Commit tests (coverage+) |
| Test fails — guard has a flaw | **FIX the guard**, then commit fix + test |
| Test fails — test is wrong | Fix the test, re-run |
| CRITICAL flaw found | **STOP immediately**, alert human |

When fixing a guard:
1. Read the guard source code
2. Identify the gap (missing regex, missing check, wrong condition)
3. Fix with minimal change
4. Run ALL compliance tests + full flutter test suite
5. If fix causes other tests to fail → revert, try different approach

### Phase 5 — COMMIT

After each successful batch:
```bash
git add <specific files>
git commit -m "compliance: harden RL-XX (<description>) — N adversarial tests

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Phase 6 — REPEAT or STOP

Continue until:
- **Budget exhausted** (tests_generated >= budget)
- **All red lines have 5+ adversarial tests**
- **CRITICAL flaw found** → STOP and alert human immediately
- **Stuck** — same red line fails after 3 fix attempts → STOP and alert human

## Flaw Severity Classification

| Severity | Action | Example |
|----------|--------|---------|
| CRITICAL | **STOP session. Alert human.** | AI can recommend products, PII leaks to logs |
| HIGH | Fix immediately, continue session | Banned term passes through, missing uncertainty band |
| MEDIUM | Log for next session | Missing disclaimer on one screen |
| LOW | Log for backlog | Wording could be more compliant |

## Strict Rules

1. **NEVER weaken a guardrail to make tests pass** — if a test reveals a gap, strengthen the guard
2. **NEVER delete or modify existing compliance tests** — only ADD new ones
3. **Always log found flaws** — even if fixed, they indicate systematic risk
4. **CRITICAL flaws → STOP and alert human** — do not attempt to fix and continue
5. **Test in multiple languages** — compliance must hold in fr, en, de, es, it, pt
6. **Run full test suite after every guard fix** — guard changes can have wide impact
7. **Never relax a regex** — only make patterns stricter or add new ones

## Anti-patterns (never do)

- **NEVER** add `// ignore:` to compliance warnings
- **NEVER** disable ComplianceGuard for "testing purposes"
- **NEVER** hardcode exceptions for specific phrases (slippery slope)
- **NEVER** assume a guard works without testing edge cases
- **NEVER** fix compliance by removing functionality
- **NEVER** test only French — Swiss app must be compliant in all languages

## Final Output

```
AUTORESEARCH COMPLIANCE HARDENER — SESSION REPORT
===================================================
Date: YYYY-MM-DD
Branch: feature/S{XX}-...
Budget: X/Y tests used
Duration: ~Nm

RESULTS:
  Compliance pass rate: before=X% → after=Y%
  Tests: before=N → after=M (+K new adversarial tests)

RED LINE COVERAGE:
  RL-01 Product recommendation: 8 tests (5 new) — ALL PASS
  RL-02 Investment advice:      6 tests (3 new) — ALL PASS
  RL-03 Banned terms:           12 tests (7 new) — ALL PASS
  RL-04 Single-number proj:     4 tests (2 new) — ALL PASS
  RL-05 Safe Mode bypass:       5 tests (5 new) — ALL PASS
  RL-06 PII in logs:            3 tests (3 new) — ALL PASS
  RL-07 Social comparison:      4 tests (2 new) — ALL PASS
  RL-08 Missing disclaimer:     2 tests (1 new) — ALL PASS
  RL-09 Missing sources:        2 tests (1 new) — ALL PASS
  RL-10 Promise of returns:     6 tests (4 new) — ALL PASS

FLAWS FOUND AND FIXED:
  1. [HIGH] RL-03 — ComplianceGuard missed "garantis" (conjugated form)
     Fix: extended banned_terms regex to include all conjugations
  2. [HIGH] RL-07 — Social comparison check only worked in French
     Fix: added German/English patterns to detector

CRITICAL FLAWS (session stopped):
  (none — or description if found)

REMAINING GAPS:
  - RL-06 PII: need to test analytics pipeline (not just CoachContext)
  - RL-03 Banned terms: Italian conjugations not yet tested
```

## Invocation

- `/autoresearch-compliance-hardener` — default budget 20 tests
- `/autoresearch-compliance-hardener 50` — deep adversarial pass, 50 tests max
