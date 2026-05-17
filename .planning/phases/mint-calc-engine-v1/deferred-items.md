- 2026-05-16 Plan 02 Task 2: pre-existing banned term `optimal` at `services/backend/app/api/v1/endpoints/mortgage.py:341` in `calculate_epl_combined` docstring (introduced sha 7daaa65c1, 2026-04-08). Out of Plan 02 scope (different endpoint). Fix in W1 Plan 03 or as separate cleanup PR.
- 2026-05-16 Plan 11 scope-correction: pre-existing banned-term meta-mentions in « Ethical requirements » docstring blocks of `services/backend/app/services/independant_service.py:34` and `services/backend/app/services/frontalier_service.py:46` (« NEVER use "garanti", "assure"... »). These are documentation of the rule, not usages — `banned_terms_python.py` cannot distinguish. They existed in HEAD before Plan 11 (Read-verified). Out of Plan 11 scope (docstring meta-references the rule it advertises). Fix path: either rephrase as « NEVER use the LSFin-forbidden surety verbs (see `swiss-brain.md §1`) » or whitelist this exact line in `banned_terms_python.py`. Same pattern already exists in `coach_tools.py` per Plan 09 STATE receipt deviation #2.

## S12-API-consolidation (deferred — surfaced by Plan 11 scope correction, 2026-05-16)

**Context** : Plan 11 W2 deprecation-shims was scoped against W0-AUDIT-MATRIX rows 32 + 35, which classified `services/backend/app/services/independant_service.py` and `services/backend/app/services/frontalier_service.py` as « deprecated shims routing to canonical sub-dirs (D-CE-10) ». Pre-flight grep + API surface audit (2026-05-16) proved this is a **misclassification** : the ROOT files are sister Sprint S12 services with monolithic APIs, the sub-dir « canonical » modules are Sprint S18/S23 with completely different surfaces. A `from <canonical> import *` shim would break `segments.py` either at import-time (independant) or at runtime via `AttributeError` (frontalier — homonymous `FrontalierService` class with different methods).

W0-AUDIT-MATRIX rows 32 + 35 reclassified 2026-05-16 (see audit-matrix lines 140 + 148). Both root files now bear S12-lineage module docstrings.

**The real consolidation question (deferred to a future plan)** :

1. **Which API surface should win for independants?**
   - S12 monolithic : `IndependantService.analyze(IndependantInput) -> IndependantResult` (single entry-point, all-in-one analysis with `lacunes` + `urgences` + `recommandations` + `checklist`)
   - S18 functional : `calculer_cotisation_avs`, `simuler_ijm`, `calculer_3a_independant`, `simuler_dividende_vs_salaire`, `simuler_lpp_volontaire` (5 independent calculators with per-result dataclasses)
   - **Open question** : do we collapse `analyze()` into a composition of `calculer_*` calls (the S18 surfaces become primitives) ? Or extract S18 functions as private helpers under the S12 facade (keep `.analyze()` as the only public seam) ?

2. **Which API surface should win for frontaliers?**
   - S12 monolithic : `FrontalierService.analyze(FrontalierInput) -> FrontalierResult` (country-rules dispatch, returns `regime_fiscal` + `droit_3a` + `alertes` + `recommandations` + `checklist`)
   - S23 granular : `calculate_source_tax`, `check_quasi_resident`, `simulate_90_day_rule`, `compare_social_charges`, `estimate_lamal_option` (5 narrower simulators with per-result dataclasses)
   - **Naming collision** : both modules expose `class FrontalierService` — keeping both forever guarantees a future bug when someone imports the wrong one.
   - **Open question** : rename one (e.g. `FrontalierSegmentService` for S12) to break the collision while preserving both APIs ? Or absorb one into the other ?

3. **Callers to migrate (5 sites)** :
   - `services/backend/app/api/v1/endpoints/segments.py:28-29` — consumes both `FrontalierService.analyze()` + `IndependantService.analyze()`
   - `services/backend/tests/test_segments.py:22-34` — consumes `FrontalierService`, `FrontalierInput`, `PAYS_FRONTALIERS`, `IndependantService`, `IndependantInput`, `AVS_FULL_RATE`, `AVS_MINIMUM_CONTRIBUTION`, `PLAFOND_3A_INDEPENDANT_MAX`, `PLAFOND_3A_SALARIE`
   - `services/backend/tests/test_independant_service.py:21-25` — consumes `IndependantInput`, `IndependantService`, `DISCLAIMER`
   - (no Flutter screens import these directly — Flutter consumes the `/api/v1/segments/*` HTTP endpoints)
   - (no `tools/` callers — grep `services/backend/ apps/ tools/` clean on 2026-05-16)

4. **Required design artifacts before a consolidation plan can be written** :
   - Panel synthesis (Karpathy architect + backend-architect + python-pro) on monolithic-vs-granular tradeoff for these two domains
   - Decision on whether the S12 `lacunes` / `urgences` / `checklist` semantic outputs are 1st-class concerns (keep monolithic) or composable side-products of granular calls (split into separate endpoints)
   - Migration plan for callers (5 sites listed above) — direct rewrite vs adapter layer
   - Naming collision resolution for `FrontalierService` (S12 vs S23)

5. **Why not in Plan 11** : Plan 11 was a mechanical-cleanup plan (~2h estimated). API consolidation is a design+migration plan (~2-3 plans estimated). Mixing them would have either (a) shipped broken code via the naive shim, or (b) bloated Plan 11 into an architectural rewrite. The scope correction is the correct outcome.

**Status** : OPEN — schedule after Wave 3 (composite index migration) and before any future « calc engine consolidation » milestone.


- 2026-05-17 Plan 18 D-CE-16(b) lint extension: 2 pre-existing « recommandé » occurrences in `services/backend/app/api/v1/endpoints/coach_chat.py:1180` and `:2814` flagged by the newly-extended `banned_terms_python.py` lint. These are NOT narrator output — they are (1) a PROVENANCE-block system-context string (`f"- {p.product_type}: recommandé par {p.recommended_by}{inst_str}"` — structural data field from FactBot Sprint), and (2) a tool-result confirmation (`f"Provenance notée : {product_type} recommandé par {recommended_by}."`). Pre-existed Plan 18 (`git blame` SHA pre-2026-05-16). Out of Plan 18 scope (Plan 18 ships the lint extension + runtime gate; `coach_chat.py` is NOT covered by the lefthook gate glob `services/backend/app/services/coach/bundles/*.py`). Fix path: either rephrase as « selon source: {p.recommended_by} » (preserves user-visible meaning, drops banned root) or whitelist the « provenance recommandé par » bigram in `banned_terms_python.py` as a structural-data exception. Tracked for a small follow-up PR in W4-close batch.
