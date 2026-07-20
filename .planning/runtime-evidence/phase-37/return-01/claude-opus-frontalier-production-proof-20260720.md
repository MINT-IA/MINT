I have enough evidence to render a verdict. Let me summarize my audit.

## Audit: `codex/g1-capital-native-proof-20260718` — Frontalier native proof

The diff converts the `frontalier_inline` black-box proof from a **Patrol-seeded** flow into a **self-owning** Maestro flow: it creates FR/CH/GE through the production dropdowns on a fresh install (`clearState: true`), then does a real `stopApp` + state-preserving relaunch (`clearState: false`) and asserts cold readback. Test scaffolding in three files (runtime Dart, Python orchestrator, shell runner) is updated in lockstep.

### Wiring verification (facade-without-wiring check) — PASS
- **Fields are real and interactive.** `frontalier_screen.dart:99-166` renders live `DropdownButton<String>` widgets keyed `frontier_residence_country_field` / `frontier_work_country_field` / `frontier_work_canton_field`, each with an `onChanged` that calls `_persistLedgerAnswers → mergeAnswers`.
- **Persistence is durable across cold restart.** `mergeAnswers` → `mergeAnswersWithProvenance` persists to SharedPreferences (`coach_profile_provider.dart:4034,4546` — "persist to SharedPreferences"). This backs the cold-readback assertions; the provider "publishes only after persistence succeeds" (`frontalier_screen.dart:204-205`), so the value is on disk before `stopApp`.
- **Selector text matches rendered labels in the app's default locale.** App defaults to `const Locale('fr')` (`locale_provider.dart:12`); French labels are `"France (FR)"` and `"Suisse (CH)"` (`app_fr.arb:3119-3120`), which satisfy the Maestro regexes `France.*FR` and `Suisse.*CH`. Canton items render bare codes (`frontalier_screen.dart:154`), so `text: "GE"` matches.
- **Fresh-install deep-link reachability is already proven** for sibling reset-case flows (`disability`/`succession` deep-link to `mint:///hypotheque`, `mint:///patrimoine` on the same uninstall+install path). `frontalier_inline` now joins that same `disability_validation_cancel | succession_save | frontalier_inline)` reset case (`patrol_return01_six_origin.sh:430`), and the in-process `g1_front01_frontier_jurisdiction_patrol_test.dart` independently exercises the same collector, so the collector renders and persists.

### Consistency of the 3-file update — PASS
`_maestroSeedStages` reduced to `{'housing_cancel'}` (patrol test), shell case moved frontalier from the seed-preserve branch to the reset branch (`patrol_return01_six_origin.sh:430-436`), and both the Dart runtime test and Python orchestrator test (`seeded_label = "housing_cancel)"`, `reset_label = "...| frontalier_inline)"`) are updated to match. No dangling reference to the old seeded classification remains. Removing frontalier from the seed set correctly means the Patrol teardown now clears its diagnostic — consistent, since Maestro no longer consumes that seed.

### Findings

**P0:** None.

**P1:** None.

**P2 (non-blocking):**
- The updated unit tests (`g1_return01_six_origin_runtime_test.dart:452-556`, `test_g1_return01_six_origin_orchestrator.py` new cases) are **structural `str.index` assertions over the YAML/shell source**, not behavioral. The actual behavioral guarantee comes only from the Maestro run in CI. This is fail-closed (a broken flow fails the run, not a false green), and mirrors the repo's established pattern, but note the green unit tests alone do not prove the flow executes.
- The `Suisse.*CH` selector depends implicitly on the French default locale; there is no `Switzerland (CH)` fallback and no locale pin in the runner. Sound today (`locale_provider.dart:12` + fresh install has no persisted override), but it would silently start failing if the default locale ever changed. Fail-closed, so not a correctness risk.

### To fully prove behavior (not in scope of static audit)
Run the flow end-to-end: `bash tools/simulator/patrol_return01_six_origin.sh` for `MINT_G1_RETURN01_STAGE=frontalier_inline` and confirm the sanitized JUnit is a clean pass and the cold-readback `assertVisible` steps succeed.

## Verdict: **PASS**

The change is genuinely wired to production dropdowns and durable persistence, the reset-case classification is coherent across all three harness files, and the strengthened cold-readback proof cannot produce a false green. The two P2 notes are quality observations, not blockers.
