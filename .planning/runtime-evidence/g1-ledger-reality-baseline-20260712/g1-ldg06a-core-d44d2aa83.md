# G1-LDG-06A — certificate-only gap evidence and person-owned fitness core

- Date: 2026-07-13
- Quality owner: `mint-quality-gate`
- RED review boundary: `1f87a79b448327217f15cd1e89ec282a23fe63bc`
- GREEN correction: `d44d2aa83` (`fix(g1): keep AVS fitness person-owned`)

## Bounded verdict

**GO for this core sub-lot only.** The two quality P1 findings raised against
`1f87a79b4` are closed at `d44d2aa83`:

1. the Financial Fitness AVS criterion is person-owned and is invariant across
   civil status, spouse presence, spouse provenance, and spouse value; and
2. certificate-backed self and spouse gap years are ready only inside the
   inclusive domain `0..44`.

This evidence does **not** close `G1-LDG-06A` globally. It does not accept the
remaining Bayesian, Circle, ResponseCard, drawer/widget, narrative, projection,
provenance-restart, authorized partner-writer, grant/revocation, or runtime
work. G1 remains **8.2/10 — NO-GO** and G2/G3 remain forbidden.

## Scope

Exact implementation and test files:

- `apps/mobile/lib/models/coach_profile.dart`
- `apps/mobile/lib/services/financial_fitness_service.dart`
- `apps/mobile/test/models/avs_gap_evidence_test.dart`
- `apps/mobile/test/services/financial_fitness_service_test.dart`

The quality review used the exact committed diff:

```bash
git diff 1f87a79b4..d44d2aa83 -- \
  apps/mobile/lib/models/coach_profile.dart \
  apps/mobile/lib/services/financial_fitness_service.dart \
  apps/mobile/test/models/avs_gap_evidence_test.dart \
  apps/mobile/test/services/financial_fitness_service_test.dart
```

## RED — semantic quality gate at `1f87a79b4`

The first implementation was nominally green but failed independent quality
review. This was a semantic RED, not a claim that the original automated suite
was failing.

### P1-1 — optional partner evidence changed the owner's score

`FinancialFitnessService` used `maritalCapApplicable` and `maritalCapReady` to
gate the main profile owner's AVS-gap criterion. Its checked-in tests explicitly
expected:

- married or registered, self certificate `lacunesAVS=0`, no spouse object:
  `0/25`; and
- cohabiting, the same self certificate and no spouse evidence: `25/25`.

That converted optional non-sharing into a civil-status penalty and reconflated
the otherwise separate self, household-total, and marital-cap gap-evidence
axes. The known person's individual view was not stable.

### P1-2 — invalid certificate values could score favorably

`CoachProfile.avsGapEvidence` accepted every non-null integer carrying the
`certificate` source. A behavioral quality repro established that
`lacunesAVS=-1` became `selfReady=true`, after which
`pointsForAvsGaps(-1)` returned `20/25`. The AVS extraction writer also did not
clamp the raw extracted gap count, so this was not limited to an impossible
constructor shape.

Initial quality verdict: **NO-GO for the core sub-lot**, with two P1 findings.

## GREEN — correction at `d44d2aa83`

The correction makes the contract explicit and behavioral:

- the Financial Fitness AVS criterion reads only
  `evidence.selfCertifiedYears` after `selfReady`;
- every `CoachCivilStatus` produces the same owner score for the same certified
  self years;
- absent, raw, certified-zero, and certified-44 spouse variants do not alter
  the owner's score;
- self and spouse evidence accept `0` and `44`;
- self and spouse evidence reject `-1` and `45` as missing;
- rejected spouse values keep `householdTotalReady=false` and
  `maritalCapReady=false` while preserving the self state.

Independent rerun verdict: **GO for this core sub-lot**, with no residual
P0/P1/P2 inside the bounded diff.

## Exact verification commands and results

### Repository operating contract

```bash
python3 tools/checks/mint_os_doctor.py --repo-only
```

Result: **PASS 7/7**.

### Static G1 AVS certified-null contract

```bash
python3 -m pytest tools/checks/tests/test_g1_avs_certified_null_contract.py -q
```

Result: **PASS 8/8**.

### Core model and Financial Fitness behavior

```bash
cd apps/mobile
flutter test \
  test/models/avs_gap_evidence_test.dart \
  test/services/financial_fitness_service_test.dart \
  --reporter expanded
```

Result: **PASS 54/54**.

### Wider model regression matrix

```bash
cd apps/mobile
flutter test \
  test/models/ \
  test/services/financial_fitness_service_test.dart \
  --reporter compact
```

Result: **PASS 321/321**.

### Targeted analyzer

```bash
cd apps/mobile
flutter analyze \
  lib/models/coach_profile.dart \
  lib/services/financial_fitness_service.dart \
  test/models/avs_gap_evidence_test.dart \
  test/services/financial_fitness_service_test.dart
```

Result: **PASS — 0 issues**.

### Exact correction diff hygiene

```bash
git diff --check 1f87a79b4..d44d2aa83
```

Result: **PASS — no whitespace error**.

## Release boundary

- Core `AvsGapEvidence` + Financial Fitness sub-lot: **GO**.
- Global `G1-LDG-06A`: **OPEN / NO-GO**.
- G1 global score: **unchanged at 8.2/10 — NO-GO**.
- G2 allowed: **NO**.
- G3 allowed: **NO**.
