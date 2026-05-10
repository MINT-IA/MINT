---
name: MVP-FATCA-CALCULATOR-GATE — perimeter STUB
description: Audit findings 2026-05-08 (PR #533 P0#4) — (a) `simulator_3a_screen.dart:171` has no FATCA gate so US persons see a fully functional 3a contribution simulator that is not actionable for them ; (b) `rachat_echelonne_screen.dart:191` has a no-op `replaceAll('_', '_').toLowerCase()` that silently downgrades every archetype to swiss_native at the backend, masking FATCA / cross-border / OPP2 art. 60b expat caps. Effort ~0.5 j.
type: decision
date: 2026-05-09
status: STUB → IN_FLIGHT (this PR opens with the fix)
related:
  - .planning/decisions/2026-05-09-perimeter-archetype-input-normalization/STUB.md
  - .planning/decisions/2026-05-08-perimeter-b8-doctrine-runtime-wire/STUB.md (B8 backend wire)
sources:
  - PR #533 audit synthesis P0 #4 line item
  - Code trace `apps/mobile/lib/screens/simulator_3a_screen.dart:171` (independent gate present, FATCA absent)
  - Code trace `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:191` (`replaceAll('_','_')` no-op bug)
  - Code trace `apps/mobile/lib/models/coach_profile.dart:1823` (canContribute3a getter ALREADY exists — just unused at the simulator)
---

# MVP-FATCA-CALCULATOR-GATE — STUB

## Goal

**Two surgical fixes that close two silent failure modes in the calculator surface:**

1. Add a FATCA gate panel to the 3a simulator so US-affected users see a calm explainer + alternatives CTA instead of a simulator they can't act on.
2. Fix the buggy archetype string conversion in `rachat_echelonne_screen.dart` that was silently downgrading every archetype to the swiss_native default at the backend.

Both fixes share the same root concern: archetype-aware logic that exists (`canContribute3a` getter, `_archetypeToBackendName` mapping) but is bypassed at the call site.

## Truth-in-claim

- The `canContribute3a` getter at `coach_profile.dart:1823` was added in an earlier sprint to reflect FATCA / cross-border eligibility — but only `prevoyance_screen.dart` and `wealth_summary_screen.dart` actually consume it. The 3a simulator never read it. So users could fill in 25 000 CHF/year of 3a contributions in the simulator, get a fancy projection, and only later discover their bank refuses them.
- The `replaceAll('_', '_')` at `rachat_echelonne_screen.dart:191` is a typo bug (intent unclear — possibly meant `replaceAllMapped(camelCase regex)` or simply removing a redundant operation). Net effect: `'crossBorder'.toLowerCase()` = `'crossborder'`, which doesn't match the backend's `'cross_border'`. So `RachatEchelonneSimulator` always received the wrong archetype string, masking the OPP2 art. 60b expat-cap (20% of insured salary if < 5 years CH contribution).

## Fix

Three surgical changes in this PR :

1. **`coach_profile.dart` — promote `_archetypeToBackendName` from a private method on coach_chat_screen to a top-level extension `FinancialArchetypeBackendName.backendName`** so all callers reuse the canonical mapping. CLAUDE.md NEVER #3 (single source of truth).

2. **`rachat_echelonne_screen.dart:191` — replace `name.replaceAll('_','_').toLowerCase()` with `profile.archetype.backendName`** (uses the new extension). Preserves the original intent (snake_case for the backend) without the silent downgrade bug.

3. **`simulator_3a_screen.dart` — gate the simulator body on `coachProfile.canContribute3a`** : when false (US person / FATCA), render a calm explainer panel with FATCA-aware copy + a CTA that routes to the coach with `intent=fatca_3a_alternatives`. The coach already has the alternative-levers playbook (libre passage, mortgage optimization, free investment) and respects archetype-aware doctrine in its system prompt.

## ARB delta

3 new keys (added to all 6 locales: fr, en, de, es, it, pt) :
- `sim3aFatcaGateTitle` — panel title.
- `sim3aFatcaGateBody` — explainer + alternative levers.
- `sim3aFatcaGateAction` — CTA label.

LSFin-compliant copy. No banned terms. No promise.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — set archetype=expatUs in seed, open `/simulator/3a`, assert FATCA panel appears (no input fields visible) | walker logs from a fresh expat_us seed |
| G2 | device by Julien — flip his profile to US nationality temporarily, open the 3a simulator on TestFlight v2.12.2+5, confirm gate panel | TestFlight |
| G3 | dev CI green — flutter analyze + flutter test (incl. new archetype tests) | run green |
| G4 | regression tests — `test_archetype_backend_name.dart` covers all 8 archetypes ; the rachat bug pre-fix path is asserted-different in a regression guard | new test exit 0 |
| G5 | LSFin/accent/ARB lint + ARB parity — 6-locale parity on the 3 new keys | ARB validation green |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| 1 | Add `extension FinancialArchetypeBackendName on FinancialArchetype { String get backendName }` at top of `coach_profile.dart` (after enum) | 0.05 j | None |
| 2 | Replace `_archetype = profile.archetype.name.replaceAll('_','_').toLowerCase();` at `rachat_echelonne_screen.dart:191` with `profile.archetype.backendName` | 0.02 j | 1 |
| 3 | In `simulator_3a_screen.dart` build method, read `coachProfile.canContribute3a` ; if false, render `_buildFatcaGateBody()` instead of the simulator inputs | 0.1 j | None |
| 4 | Implement `_buildFatcaGateBody()` — title + body + CTA routing to `/coach?intent=fatca_3a_alternatives` | 0.1 j | None |
| 5 | Add ARB keys `sim3aFatcaGateTitle` / `sim3aFatcaGateBody` / `sim3aFatcaGateAction` to all 6 ARBs ; run `flutter gen-l10n` | 0.1 j | None |
| 6 | Unit test `test/models/coach_profile_archetype_backend_name_test.dart` — exhaustive map + regression guard against pre-fix `.name.toLowerCase()` | 0.1 j | 1 |
| 7 | flutter analyze + flutter test (touched test/models green) | 0.05 j | All |

**Total estimé** : ~0.5 j.

## Counter-arguments and data gaps

- **Risk 1** : The CTA `/coach?intent=fatca_3a_alternatives` deep link is referenced but the coach side may not yet have a tailored intent handler for `fatca_3a_alternatives`. Worst case : the coach just opens with a default greeting. Acceptable v1 — the user can ask « quelles sont les alternatives au 3a en tant que US person » manually. Future perimeter : pre-fill the message with an intent-tagged opener.
- **Risk 2** : The FATCA gate is binary (canContribute3a true / false). Some FATCA-affected users with quasi-resident frontalier status (≥90% Swiss income) CAN contribute via Raiffeisen. The current `canContribute3a` getter handles this case (returns true for cross-border with revenue). So the gate fires only on actual blocked users. Verified at `coach_profile.dart:1823-1830`.
- **Risk 3** : Removing the buggy `replaceAll('_','_').toLowerCase()` at rachat_echelonne_screen.dart may surface latent issues in `RachatEchelonneSimulator` if it had grown to depend on the buggy values. Mitigation : grep `RachatEchelonneSimulator` for archetype string usage and read the test fixtures to confirm none rely on the wrong values.
- **Risk 4** : The new extension `backendName` introduces a parallel API to `_archetypeToBackendName` in coach_chat_screen.dart. Future cleanup : delete the private method from coach_chat_screen.dart and have it call the extension. Out of scope for this perimeter (CLAUDE.md NEVER #6 — surgical changes ; touch only what the audit found).
- **Data gap** : No telemetry on how many production users are actually FATCA-affected (we don't track nationality at scale). Mitigation : log archetype distribution once per session for 1 week post-deploy ; size impact based on actual `expat_us` ratio.

## Approval gate

**This PR opens immediately**. The fixes are mobile-side, surgical, fully unit-tested, and reverse cleanly if needed. G2 device verify is encouraged post-merge but does NOT block PR open.

## Order of fixes (within this perimeter)

1. Task 1 (extension) — single commit.
2. Task 2 (rachat_echelonne fix) — single commit.
3. Tasks 3 + 4 + 5 (FATCA gate body + ARB keys) — single commit.
4. Tasks 6 + 7 (tests + CI gates).

Each commit atomic + traceable.
