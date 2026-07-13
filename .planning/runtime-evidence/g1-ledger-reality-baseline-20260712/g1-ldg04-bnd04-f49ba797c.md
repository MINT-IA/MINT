# G1-LDG-04 / G1-BND-04 — bounded quality evidence

Date: 2026-07-13
Role: `mint-quality-gate`
Implementation commit: `f49ba797c678067e3b5bd210586172bd0fd8a7e4`
Canton-domain closure: `62e8ca7d536baa30e226543b2c385abbe661c257`
RED base: `cdd6e6a6346c3ae5bb3d9626562f1f53f0bf93c9`

## Verdict

- **G1-LDG-04: GREEN for the registered nominal predicate.** Display fallbacks
  for canton, housing/LAMal expenses and conversion rate are not completion
  facts without the canonical marker and exact field timestamp(s). Invalid
  numeric persistence (`abc`, negative values, `NaN`, `+/-Infinity`) cannot
  authenticate those fallbacks. Commit `62e8ca7d5` also closes the previously
  recorded canton-domain weakness: invalid/blank codes cannot keep evidence or
  unlock readiness, and valid canton input is normalized. Explicit zero housing
  plus zero LAMal remains a known monthly-expenses fact.
- **G1-BND-04: GREEN.** The real `MintApp`
  `ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>` is
  eager, has computed state before any MintState UI consumer materialises it,
  and emits exactly one observed MintState notification for the salary mutation
  and one for the provenance-only mutation.
- **G1 remains REOPENED / NO-GO at 8.2/10. G2/G3 remain forbidden.** These two
  ticket greens do not waive any other hard floor or change the phase score.

## Diff audit

`git show --stat --summary f49ba797c` reports 10 files: the four production
files, five targeted test files, and one generated interaction-coverage file.
The latter contains only two line-number shifts caused by the one-line
`app.dart` insertion. `git show --check --oneline f49ba797c` is clean, and the
commit is an ancestor of
`origin/codex/mint-product-usability-plan-20260712`.

Relevant production boundaries reviewed:

- `apps/mobile/lib/models/coach_profile.dart` validates persisted housing and
  LAMal as finite and non-negative, conversion rate as finite and positive,
  and applies the same predicate to value markers and restored timestamps.
- `apps/mobile/lib/services/navigation/readiness_gate.dart` requires value,
  canonical `userProvidedFields` marker, and exact timestamp paths for canton,
  housing cost, conversion rate, and monthly expenses.
- `apps/mobile/lib/services/navigation/screen_registry.dart` recognizes
  explicit zero monthly expenses through the marker plus both timestamps,
  rather than through `totalMensuel > 0`.
- `apps/mobile/lib/app.dart` sets the production MintState proxy to
  `lazy: false`.

The follow-up `git show --check --oneline 62e8ca7d5` is clean and the pushed
commit routes `q_canton` through the existing 26-canton `resolveCanton()`
boundary. The same resolved predicate now governs the stored value,
`userProvidedFields`, initial/restored timestamps, and readiness (including a
forged-evidence profile).

## RED proof reconstructed against the parent

The two committed ticket tests were overlaid, unchanged, onto an isolated
clone at `cdd6e6a63`; no implementation file from `f49ba797c` was present.

```bash
git checkout --detach cdd6e6a6346c3ae5bb3d9626562f1f53f0bf93c9
git checkout f49ba797c -- \
  apps/mobile/test/models/default_is_not_known_test.dart \
  apps/mobile/test/providers/mint_state_proxy_recompute_test.dart
cd apps/mobile
flutter test test/models/default_is_not_known_test.dart --reporter expanded
flutter test test/providers/mint_state_proxy_recompute_test.dart --reporter expanded
```

Observed results:

- LDG-04: **exit 1, `+6 -19`, `Some tests failed`.** Representative failures:
  default canton expected `askFirst` but got `openScreen`; default housing
  expected `openWithWarning` but got `openScreen`; explicit conversion rate
  expected `openScreen` but got `openWithWarning`; invalid values retained
  markers/fallback-authenticating timestamps.
- BND-04: **exit 1, `+0 -1`, `Some tests failed`.** The real-app test expected
  `MintStateProvider.hasState == true` before a MintState UI consumer read, but
  observed `false` at test line 54.

The canton follow-up was independently reconstructed against parent
`66c96bcb0` by overlaying only the committed test from `62e8ca7d5`:

```bash
git checkout --detach 62e8ca7d5^
git checkout 62e8ca7d5 -- \
  apps/mobile/test/models/default_is_not_known_test.dart
cd apps/mobile
flutter test test/models/default_is_not_known_test.dart --reporter expanded
```

Observed: **exit 1, `+25 -5`, `Some tests failed`.** The five failures proved
that `XX`, empty and blank canton inputs retained non-canonical values, forged
evidence opened the route, and whitespace/lowercase `" vd "` was not normalized.

## GREEN proof on the exact pushed commit

All commands below ran in an isolated detached clone whose
`git rev-parse HEAD` was exactly
`f49ba797c678067e3b5bd210586172bd0fd8a7e4`.

```bash
cd apps/mobile
flutter test test/models/default_is_not_known_test.dart --reporter expanded
flutter test test/providers/mint_state_proxy_recompute_test.dart --reporter expanded
flutter test \
  test/models/default_is_not_known_test.dart \
  test/providers/mint_state_proxy_recompute_test.dart \
  test/services/navigation/readiness_gate_custom_gates_test.dart \
  test/services/navigation/readiness_gate_test.dart \
  test/services/navigation/route_planner_test.dart \
  --reporter compact
flutter analyze \
  lib/app.dart \
  lib/models/coach_profile.dart \
  lib/services/navigation/readiness_gate.dart \
  lib/services/navigation/screen_registry.dart \
  test/models/default_is_not_known_test.dart \
  test/providers/mint_state_proxy_recompute_test.dart \
  test/services/navigation/readiness_gate_custom_gates_test.dart \
  test/services/navigation/readiness_gate_test.dart \
  test/services/navigation/route_planner_test.dart
```

Observed results:

| command | result |
|---|---|
| LDG-04 ticket test | PASS, 25/25 |
| BND-04 real-app proxy test | PASS, 1/1 |
| Five-file readiness/proxy matrix | PASS, 164/164 |
| Scoped analyzer | PASS, 9 items, 0 issues |
| `python3 tools/checks/mint_os_doctor.py --repo-only` | PASS, 7/7 repo contracts |

Follow-up proof rerun on pushed HEAD `62e8ca7d5`:

| command | result |
|---|---|
| `flutter test test/models/default_is_not_known_test.dart --reporter expanded` | PASS, 30/30 |
| `flutter test test/models/ test/services/navigation/ test/routes/ --reporter compact` | PASS, 494/494 |
| `flutter analyze lib/models/coach_profile.dart lib/services/navigation/readiness_gate.dart test/models/default_is_not_known_test.dart` | PASS, 3 items, 0 issues |

## Predicate coverage

| predicate | evidence |
|---|---|
| Empty profile's display canton `ZH` is not known | `askFirst`, missing `canton` |
| Display housing and conversion fallbacks are not known | `openWithWarning`, exact missing field retained |
| Known facts need marker plus exact timestamp path(s) | Readiness checks `canton`, `depenses.loyer`, `depenses.assuranceMaladie`, `prevoyance.tauxConversion` |
| Invalid numeric persistence does not authenticate a fallback | `abc`, negative, `NaN`, and both infinities lose marker/timestamp and remain partial |
| Invalid or blank canton does not authenticate the `ZH` display fallback | `XX`, empty, and whitespace input lose marker/timestamp and route to `askFirst` |
| Canton validation cannot be bypassed with forged evidence | Readiness independently requires `resolveCanton(profile.canton).isResolved` |
| Valid canton input is canonicalized | `" vd "` becomes `VD` and keeps its exact evidence |
| Orphaned persisted timestamps do not authenticate an invalid value | Restored timestamp is filtered by the same value-validity predicate |
| Explicit zero expenses are valid facts | Housing `0` plus LAMal `0` is ready with marker and both timestamps |
| Production proxy is not a direct-provider test double | Test pumps `MintApp`, obtains both production providers from `MaterialApp` context |
| Recompute observes value and provenance-only mutations | One listener notification after salary; a second after provenance-only update; state holds the exact new profile object |

## Canton-domain follow-up

The previously recorded `q_canton = "XX"` weakness is **closed** by
`62e8ca7d5`: model reconstruction, marker/timestamp restoration and readiness
all fail closed on non-canonical codes. The RED five-failure proof and GREEN
30/30 plus 494/494 regression matrix are recorded above.

No Maestro or Patrol claim is made: neither ticket names a changed visible
mobile flow, process-death contract, or real input surface. G1 runtime gates
remain tracked independently.

## Artifacts and score

- This report is the bounded artifact for these two tickets.
- Exact implementations: `f49ba797c678067e3b5bd210586172bd0fd8a7e4`
  and canton closure `62e8ca7d536baa30e226543b2c385abbe661c257`.
- Subgate result: **2/2 registered predicates GREEN** with the canton-domain
  weakness closed.
- G1 fixed-rubric score: **8.2/10, unchanged; NO-GO**.
