# G1-LDG-04 / G1-BND-04 — bounded quality evidence

Date: 2026-07-13
Role: `mint-quality-gate`
Implementation commit: `f49ba797c678067e3b5bd210586172bd0fd8a7e4`
RED base: `cdd6e6a6346c3ae5bb3d9626562f1f53f0bf93c9`

## Verdict

- **G1-LDG-04: GREEN for the registered nominal predicate.** Display fallbacks
  for canton, housing/LAMal expenses and conversion rate are not completion
  facts without the canonical marker and exact field timestamp(s). Invalid
  numeric persistence (`abc`, negative values, `NaN`, `+/-Infinity`) cannot
  authenticate those fallbacks. Explicit zero housing plus zero LAMal remains
  a known monthly-expenses fact.
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

## Predicate coverage

| predicate | evidence |
|---|---|
| Empty profile's display canton `ZH` is not known | `askFirst`, missing `canton` |
| Display housing and conversion fallbacks are not known | `openWithWarning`, exact missing field retained |
| Known facts need marker plus exact timestamp path(s) | Readiness checks `canton`, `depenses.loyer`, `depenses.assuranceMaladie`, `prevoyance.tauxConversion` |
| Invalid numeric persistence does not authenticate a fallback | `abc`, negative, `NaN`, and both infinities lose marker/timestamp and remain partial |
| Orphaned persisted timestamps do not authenticate an invalid value | Restored timestamp is filtered by the same value-validity predicate |
| Explicit zero expenses are valid facts | Housing `0` plus LAMal `0` is ready with marker and both timestamps |
| Production proxy is not a direct-provider test double | Test pumps `MintApp`, obtains both production providers from `MaterialApp` context |
| Recompute observes value and provenance-only mutations | One listener notification after salary; a second after provenance-only update; state holds the exact new profile object |

## Remaining weakness

`G1-LDG-04` is green only for its registered default-sensitive predicate and
the numeric corruption matrix above. A non-canonical explicit canton such as
`q_canton = "XX"` is still accepted by `CoachProfile.fromWizardAnswers()` as a
non-empty user-provided canton with a timestamp; the model boundary does not
route it through the existing 26-canton `resolveCanton()` validator. This is a
separate fail-closed micro-slice and must not be hidden by this nominal green.

No Maestro or Patrol claim is made: neither ticket names a changed visible
mobile flow, process-death contract, or real input surface. G1 runtime gates
remain tracked independently.

## Artifacts and score

- This report is the bounded artifact for these two tickets.
- Exact implementation: `f49ba797c678067e3b5bd210586172bd0fd8a7e4`.
- Subgate result: **2/2 registered predicates GREEN** with the canton-domain
  weakness above explicitly open.
- G1 fixed-rubric score: **8.2/10, unchanged; NO-GO**.
