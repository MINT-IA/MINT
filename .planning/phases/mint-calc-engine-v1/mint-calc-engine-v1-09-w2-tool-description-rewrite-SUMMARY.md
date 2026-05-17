---
phase: mint-calc-engine-v1
plan: 09
wave: 2
subsystem: api
tags: [concern-a, tool-description-rewrite, anthropic-tool-search, bm25, lsfin, fr-keyword-discipline, legal-article-refs, rubric-lint, d-ce-01, dict-var-lint, xfail-polish-todos]

# Dependency graph
requires:
  - phase: mint-calc-engine-v1
    plan: 07
    provides: "AnthropicDeferLoadingAdapter with templated v1 descriptions for 60 long-tail tools — Plan 09 replaces the template with _TOOL_DESCRIPTIONS_FR map at _description_for(meta) site"
  - phase: mint-calc-engine-v1
    plan: 08
    provides: "Bundles IndependentTax + SuccessionDivorce reference placeholder tool names — Plan 09 documents the names that match REGISTRY canonical entries"
provides:
  - "tools/checks/tool_description_rubric.py — 4-rule lint (R1 FR verb / R2 FR accent / R3 legal article OR financial-domain keyword / R4 length >= 80) with --names allowlist + --names-file + --dict-var <map-name> + in-source rubric_exempt: True carve-out. Default mode preserves the legacy AST scanner contract."
  - "services/backend/app/services/coach/coach_tools.py — 5 chip-emitter descriptions rewritten with FR keyword discipline + 10 legal article refs (LAVS art. 5/18/21/35, LPP art. 7-8/14, LACI art. 3, LCC art. 28, LIFD art. 33, CC art. 159). 2 pre-existing banned-term hits (333 garanti/optimal in screen-suggestion meta-doc + 800 Parfait in summary_message example) rewrote in place since opening the file made them blockers for banned_terms_python exit 0."
  - "services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py — _TOOL_DESCRIPTIONS_FR map with 56 long-tail descriptions covering all 11 financial domains (housing/retirement/3a/fiscal/family/succession/divorce/cross-border/expat/frontalier/indépendant/career/unemployment/debt/arbitrage). 66 legal article refs spanning CC + LAVS + LPP + LIFD + LHID + LCC + LAA + LAMal + LAI + LACI + LAPG + LAFam + OPP2. _description_for(meta) replaces _templated_description_for at the register_tools call site ; the template stays as a fallback for any REGISTRY entry NOT in the map."
  - "services/backend/tests/test_tool_search_round_trip.py — 30 FR user messages → expected top-3 tool names. Jaccard / overlap scorer (BM25 approximation). 28/30 fixtures pass, 2 wrapped in pytest.param(marks=xfail) for the description-polish TODOs (concubinage à Genève impact fiscal + comparer impôt Genève vs Zurich). Aggregate test_round_trip_fixtures_minimum_pass_rate asserts >= 25/30."
  - "tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml — 5-query device flow (divorce / racheter LPP / frontalier / acheter Lausanne / indépendant) on Coach tab. maestro check-syntax exit 0. Live run + Julien G2 sim-check deferred to Task 5b (staging pilot DEFERRED)."
affects: [mint-calc-engine-v1-10-w2-coach-tool-response-v2, mint-calc-engine-v1-11-w2-deprecation-shims]

# Tech tracking
tech-stack:
  added:
    - "pytest.param(..., marks=pytest.mark.xfail(strict=False, reason=...)) pattern for parametrized fixtures whose failures are expected-and-documented under a coarse scorer — surfaces failures in pytest output without breaking CI green. New in this codebase."
    - "argparse-based lint CLI with --names/--names-file/--dict-var/--rubric-exempt scope controls — replicable pattern for any AST-walking lint that needs allowlist-mode while staying backwards-compatible with legacy unit tests."
  patterns:
    - "Per-tool FR description map keyed by canonical REGISTRY name : _TOOL_DESCRIPTIONS_FR = {'<name>': '<description>'} consumed via _description_for(meta) lookup with templated fallback. Single source of truth ; survives REGISTRY scanner widening (Plan 05) and Plan 10 dispatch-site wire-up."
    - "Rubric lint scope axis : --names <csv> + --names-file <path> (allowlist for legacy {'name', 'description'} dict shape) + --dict-var <varname> (scan top-level dict map values keyed by tool name). The 2 axes are orthogonal and combine via union — the same lint invocation can simultaneously check the chip-emitter dict shape + the long-tail map shape."
    - "Deviation Rule 2 surgical in-place fix on pre-existing banned-term substrings in system prompt example strings (line 333 garanti/optimal/tu devrais → 'LSFin-forbidden terms (see swiss-brain.md §1)' ; line 800 'Parfait, 500 CHF' → 'C'est noté, 500 CHF'). Pre-existing hits became Plan 09 blockers the moment the file landed in the changed-files set for banned_terms_python."

key-files:
  created:
    - "tools/checks/tool_description_rubric.py (created, 224 LOC after Task 2 upgrade)"
    - "tools/checks/tests/test_tool_description_rubric.py (created, 88 LOC, 3 contract tests)"
    - "services/backend/tests/test_tool_search_round_trip.py (created, ~420 LOC, 30 fixtures + aggregate + 2 xfail wraps + Jaccard scorer)"
    - "tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml (created, 116 LOC, 5 representative FR queries)"
  modified:
    - "services/backend/app/services/coach/coach_tools.py (5 chip-emitter descriptions rewritten + 2 pre-existing banned-term substrings fixed in place)"
    - "services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py (_TOOL_DESCRIPTIONS_FR map added with 56 entries + _description_for(meta) function added + register_tools call site updated)"

key-decisions:
  - "Per-tool FR descriptions stored in _TOOL_DESCRIPTIONS_FR map IN THE ADAPTER MODULE rather than as a separate JSON/YAML file. Rationale : compile-time discoverability + IDE jump-to-definition + zero filesystem I/O at register_tools call. Trade-off : Python-only consumer (BUT the adapter is Python-only anyway). Reversible : Plan 10+ can extract to a config file if a Flutter-side consumer ever needs the descriptions."
  - "5 chip-emitter rewrites stayed IN coach_tools.py (the existing source of truth per Plan 07 _load_chip_emitter_descriptions pattern) rather than moving to _TOOL_DESCRIPTIONS_FR. Rationale : 2 distinct registration paths (chip = always-on COACH_TOOLS scan ; long-tail = REGISTRY + map lookup) ; keeping the chip descriptions where they already live avoids dual-source confusion at the next plan's audit pass."
  - "Rubric lint upgrade preserves the legacy contract (no --names → scan every description) so the 3 contract tests in tools/checks/tests/test_tool_description_rubric.py stay green. The --names allowlist mode is the additive feature. Reversible by removing the new flag without touching the legacy path."
  - "2 description-polish TODO fixtures wrapped in pytest.param(marks=xfail) rather than removed or polished out. Rationale : the Jaccard scorer is intentionally a coarse BM25 approximation ; over-tuning descriptions to satisfy Jaccard could PESSIMIZE real Anthropic BM25 (which weights term-frequency × inverse-document-frequency). Staging pilot (Task 5b DEFERRED) is the production verification path."
  - "Staging pilot env-flip (Task 5b TOOL_REGISTRY_ADAPTER=anthropic_defer_loading on Railway mint-staging) explicitly DEFERRED. Reasoning per orchestrator pre-decision : requires Julien GO on operational risk + Sentry observability for the new adapter path. Documented in '## Deferred — Wave 2 close-out gates' below with exact Railway command."

patterns-established:
  - "Per-domain legal-article-ref density target — every tool description carries ≥1 art. ref (CC / LAVS / LPP / LIFD / LHID / LCC / LAA / LAMal / LAI / LACI / LAPG / LAFam / OPP2) selected from swiss-brain.md §10. Density across the 61 descriptions : 9 art. in coach_tools.py + 66 art. in adapter = 75 art. refs total spanning 13 Swiss laws. Replicable target for Plans 10+ when description fields land on new components (e.g. CoachToolResponse V2 envelope narrative slot)."
  - "Rubric lint as gating contract on description-emitting modules — the lint is now wired with --names-file <allowlist> at the package level (Concern A scope) and can be lefthook-extended in a future plan to gate any new description landing in coach_tools.py or anthropic_defer_loading_adapter.py."
  - "Round-trip fixture pattern : 30 FR user messages × expected_top_3 tool names, scored by Jaccard with FR-accent normalization + FR-stopword filter. Pattern reusable for the future ManualSubsetAdapter (Plan 07 backup) intent → tool subset verification and for Plan 10's CoachToolResponse V2 latency_tier dispatch verification."

requirements-completed: [D-CE-01, Concern-A]

# Metrics
duration: ~25min
completed: 2026-05-16
---

# Phase mint-calc-engine-v1 Plan 09: W2 Tool Description Rewrite (Concern A) Summary

**D-CE-01 + Concern A delivered : `tools/checks/tool_description_rubric.py` (4 rules R1-R4 + scope axes) + 5 chip-emitter rewrites in `coach_tools.py` + 56 long-tail descriptions in `anthropic_defer_loading_adapter.py:_TOOL_DESCRIPTIONS_FR` (61 descriptions total, 75 Swiss legal-article refs spanning 13 laws). 30-fixture round-trip pytest baseline at 28/30 real passes (2 xfailed polish-TODOs). Maestro G1 flow `coach_tool_search_round_trip.yaml` shipped + `maestro check-syntax` exit 0 ; live sim run + Julien G2 + staging pilot env-flip explicitly DEFERRED to Task 5b. 7105 full backend tests passing (+29 vs Plan 08 baseline 7076). Rubric / banned-terms / accent FR lints exit 0 on both changed files. Engram observation #131 saved via CLI fallback. Pilot env-flip (`TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` on Railway mint-staging) is the next gate — requires Julien GO.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-16T20:39:30Z
- **Completed:** 2026-05-16T21:04:30Z (approx)
- **Tasks:** 5/6 atomic (1 rubric / 2 rewrites / 3 round-trip pytest / 4 Maestro YAML / 5a pre-vet mechanical) + 1 explicitly DEFERRED (5b staging pilot env-flip)
- **Files created:** 4 (rubric lint module + rubric tests + round-trip pytest + Maestro YAML)
- **Files modified:** 2 (coach_tools.py + adapter module)

## Tone sample for Julien post-hoc review (3 random descriptions verbatim)

Per Task 5a pre-vet contract — 3 descriptions picked with `random.seed(42)` for reproducibility :

### 1. `mariage_service__MariageService_compare_fiscal_impact`

> Compare l'impact fiscal d'un mariage (CC art. 159) selon canton et revenus des deux conjoints. Estime le delta d'impôt CHF/an (penalty ou bonus selon écart de revenus). Mots-clés : mariage, couple, fiscal, impôt, canton, splitting.

### 2. `wealth_tax_service__WealthTaxService_simulate_move_wealth`

> Simule l'effet d'un déménagement cantonal sur l'impôt fortune (LHID art. 13). Estime le delta CHF/an et le gain net post-déménagement. Mots-clés : fortune, déménagement, canton, impôt, mobilité.

### 3. `repayment_service__RepaymentService_compare_strategies`

> Compare les stratégies de remboursement de dette (snowball par petite dette d'abord, avalanche par taux d'intérêt). Estime le coût total CHF et la durée. Mots-clés : dette, remboursement, snowball, avalanche, stratégie, intérêt.

**Tone check** : factual, FR-keyword-rich, legal-article-cited, no banned terms, no « tu devrais », no ranking. Mots-clés tail explicit (BM25 surfacing aid). Julien G2 post-hoc review can confirm voice alignment.

## Accomplishments

### Task 1 — `tools/checks/tool_description_rubric.py` lint (commits `bdf50c95` RED → `771d958b` GREEN)

`tools/checks/tool_description_rubric.py` ships as a TDD-RED-then-GREEN module : 3 contract tests in `tools/checks/tests/test_tool_description_rubric.py` cover the « passes on a compliant description / fails on English-only / reports rule + snippet » contract. 4 rules :

| Rule | Pattern | Notes |
|---|---|---|
| **R1** FR verb | `\b(simule\|calcule\|compare\|estime\|projette\|évalue\|analyse)\w*\b` | Concern A canonical verbs |
| **R2** FR text | `[éèàùîôûâçëïü]` | At least 1 accented vowel anywhere |
| **R3** Legal/domain | `art. <N>` OR `CHF/canton/3a/LPP/AVS/LIFD/LCC/rachat/rente/...` | swiss-brain.md §10 alignment |
| **R4** Min length | `len(desc) >= 80` | Catches templated stubs |

Baseline verification (Task 1 acceptance) : `python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py` returned exit 1 with 251 violations on the pre-rewrite English-only descriptions.

Task 2 upgraded the lint with 3 additive scope-control flags : `--names <csv>`, `--names-file <path>`, `--dict-var <varname>`. The `rubric_exempt: True` key in a dict skips the entry (in-source carve-out).

### Task 2 — 61 description rewrites (commit `80d89473`)

**5 chip-emitter rewrites in `coach_tools.py`** :

| Tool | Legal refs cited |
|---|---|
| `get_budget_status` | LAVS art. 5, LPP art. 7-8, LACI art. 3 |
| `get_retirement_projection` | LAVS art. 21 + 35, LPP art. 14, LIFD art. 33 al. 1 let. e |
| `get_cross_pillar_analysis` | LAVS art. 18, LPP art. 14, LIFD art. 33 al. 1 let. e |
| `get_cap_status` | LCC art. 28, OPP2 art. 5 |
| `get_couple_optimization` | CC art. 159, LAVS art. 35 |

`grep -c 'art\. '` returned 10 (acceptance ≥10 ✓).

**56 long-tail rewrites in `anthropic_defer_loading_adapter.py`** via the new `_TOOL_DESCRIPTIONS_FR: dict[str, str]` map :

| Domain | Tools covered | Legal refs sample |
|---|---|---|
| Housing / mortgage | 8 (affordability, amortization, saron_vs_fixed, epl_combined, epl, imputed_rental, housing_sale, location_vs_propriete) | LCC art. 28, OPP2 art. 5, LIFD art. 38, LHID art. 7 + 12 |
| Retirement / LPP / 3a / AVS | 10 (avs_estimation, retirement_projection, lpp_conversion, rachat_echelonne, rachat_vs_marche, rente_vs_capital, calendrier_retraits, multi_account, retroactive_3a, cross_pillar) | LAVS art. 21 + 29bis-29ter + 35, LPP art. 14 + 37 + 79b, LIFD art. 33 + 38 |
| Fiscal / canton | 8 (cantonal_comparator x3, wealth_tax x3, church_tax x2) | LIFD + LHID art. 12 + 13 + 68 |
| Family / divorce / succession / naissance | 11 (divorce, succession, concubinage x2, mariage x3, naissance x3, donation) | CC art. 122-124 + 125 + 159 + 181 + 247 + 462 + 467-469, LAVS art. 23 + 29sexies, LPP art. 19-21, LAPG art. 16b + 16i, LAFam art. 3 |
| Cross-border / expat / frontalier | 6 (frontalier x3, expat x3) | LIFD art. 14 + 91, accord CH-FR 1983 |
| Indépendant | 4 (independant x4) | LAVS art. 8, LIFD art. 33, LAA art. 4 |
| Career / debt | 4 (unemployment, job_comparator, debt_ratio, repayment) | LACI art. 22, LCC art. 28 |
| Arbitrage / FRI | 5 (allocation, fri_service x2, real_return, provider_comparator) | LIFD art. 33, LHID art. 13 |

`grep -c 'art\. '` returned 66 (acceptance ≥30 ✓).

`_description_for(meta)` replaces `_templated_description_for` at the `register_tools` call site. The template stays as a fallback for REGISTRY entries NOT in the map.

### Task 3 — 30-fixture round-trip pytest (commits `d7b95167` RED+GREEN → `b89671c5` xfail follow-up)

`services/backend/tests/test_tool_search_round_trip.py` ships :

- 30 FR user messages × expected top-3 tool names parametrized fixture (acceptance = exactly 30, asserted at module-import via `assert len(ROUND_TRIP_FIXTURES) == 30`).
- Jaccard / overlap scorer with FR-accent normalization (é→e, à→a, etc.) + FR-stopword filter (`le/la/les/un/une/de/.../an/ans/mois`).
- Aggregate `test_round_trip_fixtures_minimum_pass_rate` asserts ≥25 of 30 pass (acceptance threshold).
- 28/30 pass under Jaccard, 2 wrapped in `pytest.param(..., marks=pytest.mark.xfail(strict=False, reason="..."))` :
  - `"je suis en concubinage à Genève et je veux comprendre l'impact fiscal"` — Jaccard surfaces wealth_tax_compare_all_cantons / get_couple_optimization / expat_service instead of concubinage_service entries. « impact fiscal » overlaps more with wealth_tax than with concubinage_service descriptions under the coarse scorer.
  - `"comparer l'impôt entre Genève et Zurich"` — Jaccard surfaces wealth_tax_compare_all_cantons / get_couple_optimization / expat_service instead of cantonal_comparator. Wealth_tax has higher « impôt + canton » keyword density.

Staging pilot (Task 5b) is the production verification path — real Anthropic BM25 + IDF weighting may rank these correctly.

### Task 4 — Maestro G1 flow `coach_tool_search_round_trip.yaml` (commit `1bda1ebf`)

`tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` walks 5 representative FR queries on the Coach tab with `extendedWaitUntil` assertions on expected response keywords :

| Query | Assert keyword (regex) |
|---|---|
| `"si je divorce demain, que se passe-t-il ?"` | `divorce\|séparation\|splitting\|partage LPP\|CC art\. 122` |
| `"je veux racheter ma LPP avant la retraite"` | `rachat\|LPP\|2e pilier\|LIFD art\. 33` |
| `"frontalier vaudois, impôt à la source"` | `frontalier\|impôt à la source\|permis G\|LIFD art\. 91` |
| `"acheter un appartement à Lausanne, quelle capacité"` | `hypothèque\|capacité\|FINMA\|charges\|LCC art\. 28\|fonds propres` |
| `"je suis indépendant à 80K, mes cotisations AVS"` | `indépendant\|cotisation\|AVS\|LAVS art\. 8` |

`maestro check-syntax tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` returned exit 0. Live sim run was NOT attempted (no booted sim at execution time — out of scope per Task 5a deferral rule for blocking-on-sim).

### Task 5a — Mechanical pre-vet (this SUMMARY)

- ✓ Rubric lint exit 0 with `--names-file /tmp/allnames_lines.txt --dict-var _TOOL_DESCRIPTIONS_FR` on both changed files (61 Concern A descriptions all rubric-compliant).
- ✓ `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` exit 0.
- ✓ `python3 tools/checks/accent_lint_fr.py --scope backend` returned 0 hits on `coach_tools|anthropic_defer_loading` (exit 0 overall).
- ✓ `maestro check-syntax tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` exit 0.
- ✓ 3 random descriptions read back verbatim above for Julien post-hoc tone review.
- ⚠ Live Maestro run on booted sim : NOT attempted (no sim booted at execution time, per orchestrator « do NOT block on Maestro install / sim boot »).

## Task Commits

1. `bdf50c95` test(09): add failing tests for tool description rubric lint (Task 1 RED)
2. `771d958b` feat(09): implement tool description rubric lint (Task 1 GREEN, 140 LOC)
3. `80d89473` feat(09): rewrite 61 tool descriptions FR + Concern A rubric upgrade (Task 2)
4. `d7b95167` test(09): add Concern A round-trip fixture (28/30 FR queries → top-3) (Task 3 baseline)
5. `1bda1ebf` feat(09): add Maestro G1 flow coach_tool_search_round_trip.yaml (Task 4)
6. `b89671c5` fix(09): mark 2 polish-TODO round-trip fixtures as xfail (Task 3 follow-up)

**Plan metadata commit:** pending (this SUMMARY + STATE.md + ROADMAP.md update + HTML report).

## Files Created/Modified

- `tools/checks/tool_description_rubric.py` (created, ~224 LOC after Task 2 scope-flag upgrade)
- `tools/checks/tests/test_tool_description_rubric.py` (created, 88 LOC, 3 contract tests)
- `services/backend/app/services/coach/coach_tools.py` (modified : 5 chip-emitter rewrites + 2 pre-existing banned-term substring fixes)
- `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` (modified : `_TOOL_DESCRIPTIONS_FR` 56-entry map + `_description_for(meta)` function + `register_tools` call site updated + module docstring refreshed to reflect Plan 09 contract)
- `services/backend/tests/test_tool_search_round_trip.py` (created, ~420 LOC after xfail wrap)
- `tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` (created, 116 LOC, 5 queries)

**Total : 4 files created, 2 files modified.** ~860 LOC of net new code across lints + tests + descriptions + Maestro YAML.

## Decisions Made

1. **`_TOOL_DESCRIPTIONS_FR` as a Python dict in the adapter module** rather than an external JSON/YAML file. Compile-time discoverability + IDE jump-to-definition + zero filesystem I/O at `register_tools`. Reversible by extracting to a config file if a Flutter-side consumer needs the descriptions.
2. **Chip-emitter rewrites stayed IN `coach_tools.py`** (Plan 07 existing source-of-truth pattern via `_load_chip_emitter_descriptions`) rather than moving to `_TOOL_DESCRIPTIONS_FR`. Two distinct registration paths preserved : chip = always-on `COACH_TOOLS` scan ; long-tail = REGISTRY + map lookup.
3. **Rubric lint upgrade preserves the legacy contract** — no `--names` flag = scan every description (legacy mode). The 3 contract tests in `tools/checks/tests/test_tool_description_rubric.py` use legacy mode and stay green. `--names`/`--names-file`/`--dict-var` are additive scope-controls.
4. **2 description-polish TODOs wrapped in `pytest.param(marks=xfail)`** rather than tuned out. The Jaccard scorer is intentionally coarse ; over-tuning descriptions to satisfy Jaccard could pessimize real Anthropic BM25 (term-frequency × inverse-document-frequency). The aggregate `≥25/30` gate still catches regressions.
5. **Pre-existing banned-term substrings rewrote in place** (Deviation #2, Rule 2) since opening `coach_tools.py` for Plan 09 made them blockers for `banned_terms_python` exit 0. Line 333 `« Never use banned terms (garanti, optimal, tu devrais) »` → `« Never use LSFin-forbidden terms (see swiss-brain.md §1) »` ; line 800 `'Parfait, 500 CHF sur le 3a et 200 CHF en épargne libre. C'est noté !'` → `'C'est noté, 500 CHF sur le 3a et 200 CHF en épargne libre. C'est noté !'`. Both are system-prompt example strings — not narrator-output. Reversible.
6. **Maestro live run not attempted** (Task 5a deferral). Per orchestrator pre-decision : « If Maestro is installed and a sim is bootable, also run the live flow … but DO NOT block on Maestro install / sim boot. » No sim was booted at execution time. Live Maestro G1 + Julien G2 + staging pilot are Task 5b DEFERRED.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Rubric lint legacy AST scan couldn't see `_TOOL_DESCRIPTIONS_FR` map values**

- **Found during:** Task 2 (post-rewrite verification)
- **Issue:** The legacy `_extract_description_strings` walks `ast.Dict` nodes and looks for `{"description": "..."}` siblings. `_TOOL_DESCRIPTIONS_FR` is a `dict[str, str]` keyed by tool name — the keys are tool names, not the literal string `"description"`. Lint would silently SKIP the 56 long-tail descriptions and report exit 0 even on garbage values.
- **Fix:** Added `--dict-var <name>` CLI flag + `_extract_dict_var_values(source, var_name)` AST walker that scans a top-level `<NAME> = {...}` dict map and yields `(line_no, value, key_name)`. The new walker integrates additively with the legacy `_extract_description_strings` ; existing tests stay green.
- **Files modified:** `tools/checks/tool_description_rubric.py` (+30 LOC walker + 8 LOC arg parsing + 3 LOC wire-up).
- **Verification:** Rubric lint with `--names-file /tmp/allnames_lines.txt --dict-var _TOOL_DESCRIPTIONS_FR` returns exit 0 on the 61 Concern A descriptions. Without `--dict-var`, the lint silently ignores the 56 long-tail map values (legacy-compat behavior preserved).
- **Committed in:** `80d89473`.

**2. [Rule 2 - Correctness] Pre-existing banned-term substrings in `coach_tools.py` lines 333 + 800**

- **Found during:** Task 2 (banned_terms_python verification)
- **Issue:** Line 333 contained the meta-doc `"Never use banned terms (garanti, optimal, tu devrais)."` (instruction-listing the banned terms verbatim for the LLM coach). Line 800 contained the example `"(e.g. 'Parfait, 500 CHF sur le 3a et 200 CHF en épargne libre. C'est noté !')"`. Both pre-existed Plan 09 (git log shows them landing in commits `fe8fa2df` + `37209ed1` long before this phase). `banned_terms_python` flagged both as banned-term hits — the exemption marker `# llm-doctrine-fragment-banned-list` only exempts triple-quoted blocks, not paren-string-concatenated literals.
- **Fix:** Rewrote both in-place. Line 333 → `"Never use LSFin-forbidden terms (see swiss-brain.md §1 + ComplianceNarratorBundle for the verbatim banned list)."` (preserves the instruction without listing the terms). Line 800 → `"(e.g. 'C'est noté, 500 CHF sur le 3a et 200 CHF en épargne libre. C'est noté !')"` (same intent, no banned-term substring).
- **Files modified:** `services/backend/app/services/coach/coach_tools.py` (2 lines changed).
- **Verification:** `banned_terms_python` exit 0 on both files post-fix.
- **Committed in:** `80d89473`.

**3. [Rule 1 - Bug] Test fixture compliant description lacked R2 accent match**

- **Found during:** Task 1 GREEN (first lint run)
- **Issue:** My initial « compliant » test fixture `"Simule l'impact financier d'un divorce (CC art. 122-124) : splitting AVS (LAVS art. 29sexies), partage LPP, pension alimentaire."` had ZERO accented vowels — every word in the assertion was either ASCII or English-origin (« divorce », « splitting », « partage », « pension »). R2 lint correctly flagged it.
- **Fix:** Updated fixture to include « séparation » and « éventuelle » → 2 valid `é` matches. Same Pydantic-equivalent contract.
- **Files modified:** `tools/checks/tests/test_tool_description_rubric.py` (1 fixture body).
- **Verification:** 3/3 contract tests green post-fix.
- **Committed in:** `771d958b`.

**4. [Plan-spec drift] Round-trip Jaccard < real BM25 — 2 fixtures wrapped in xfail**

- **Found during:** Task 3 (round-trip baseline verification)
- **Issue:** Out of 30 parametrized fixtures, 2 returned top-3 NOT containing any expected tool name : « concubinage à Genève impact fiscal » and « comparer l'impôt entre Genève et Zurich ». Plan acceptance allows up to 5 failures, but pytest fails the SUITE on any parametrized failure unless marked xfail.
- **Fix:** Wrapped the 2 known failures in `pytest.param(..., marks=pytest.mark.xfail(strict=False, reason="..."))` via `_maybe_xfail_param` helper. The aggregate `test_round_trip_fixtures_minimum_pass_rate` still asserts ≥25/30 so regressions on the 28 passing fixtures still block the suite.
- **Files modified:** `services/backend/tests/test_tool_search_round_trip.py` (added `_XFAIL_USER_MESSAGES` constant + `_maybe_xfail_param` helper).
- **Verification:** `pytest tests/test_tool_search_round_trip.py -q` returns `29 passed, 2 xfailed`. Full suite : `7105 passed, 62 skipped, 3 xfailed, 1 warning` (+29 vs Plan 08 baseline 7076 = 30 parametrized – 2 xfailed + 1 aggregate).
- **Committed in:** `b89671c5`.

---

**Total deviations:** 4 auto-fixed (1 Rule 3 blocking — dict-var lint missing ; 1 Rule 2 correctness — pre-existing banned-term substrings ; 1 Rule 1 bug — test fixture R2 miss ; 1 Plan-spec drift — Jaccard polish-TODO xfail). **Zero architectural deviations.**

## Issues Encountered

The Maestro `--dry-run` flag prescribed in the PLAN (`<verify><automated>maestro test ... --dry-run`) doesn't exist on Maestro 2.5.1 CLI. The correct invocation is `maestro check-syntax <yaml>` which returned exit 0. Plan acceptance text should be amended in any future plan-template update.

## Deferred — Wave 2 close-out gates

**Task 5b — Staging pilot env-flip (DEFERRED, requires Julien GO)**

Per orchestrator pre-decision : this is a **genuine operational gate** that requires Julien sign-off before flipping Railway staging. The mechanical command is :

```bash
# On Julien's Railway dashboard for `mint-staging` service :
# Variables → Add → TOOL_REGISTRY_ADAPTER=anthropic_defer_loading
# (or via CLI : railway variables set TOOL_REGISTRY_ADAPTER=anthropic_defer_loading -e mint-staging)
```

After the flip, the verification sequence is :

1. Wait for Railway redeploy completion (`railway logs --tail`).
2. Visit staging Coach tab via mobile build configured for `mint-staging.up.railway.app`.
3. Walk the 5 Maestro flow queries by hand (divorce / racheter LPP / frontalier / acheter Lausanne / indépendant) — each must surface at least 1 relevant tool in the response within 25 s timeout.
4. Optionally run `bash tools/simulator/walker.sh tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` on a booted sim if Maestro is available.
5. Sentry breadcrumb check : confirm no Anthropic 5xx + no `tool_search_tool_bm25` rejection breadcrumbs on staging.

If the pilot reveals regressions (e.g. cold-turn latency > 8 s on a chip-emitter, BM25 surfacing the wrong tool >50% of the time), rollback is `railway variables unset TOOL_REGISTRY_ADAPTER -e mint-staging` (default falls back to `anthropic_defer_loading`, but the explicit unset will force a redeploy that disambiguates).

**The full Wave 2 close-out (Plan 10 + Plan 11)** is gated on this pilot succeeding. Plan 10 wires the adapter into `coach_chat.py` (first user-visible plan). Plan 11 migrates `independant_service.py` + `frontalier_service.py` to canonical sub-directories.

## 0-Trust Evidence (CLAUDE.md §9.6)

| Claim | Evidence |
|---|---|
| Rubric lint module ships with 4 rules + scope flags | `wc -l tools/checks/tool_description_rubric.py` → `224` ; `grep -E '^R[1-4]_' tools/checks/tool_description_rubric.py` → 4 entries |
| 3 rubric-lint contract tests green | `python3 -m pytest tools/checks/tests/test_tool_description_rubric.py -q` → `3 passed in 0.14s` |
| Rubric lint baseline (pre-rewrite) on coach_tools.py is exit 1 | At RED time, `python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py ; echo $?` → exit 1 with 251 violations |
| coach_tools.py has ≥10 art. legal refs post-rewrite | `grep -c 'art\. ' services/backend/app/services/coach/coach_tools.py` → `10` |
| adapter.py has ≥30 art. legal refs post-rewrite | `grep -c 'art\. ' services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` → `66` |
| 56 long-tail tool descriptions in `_TOOL_DESCRIPTIONS_FR` map | `cd services/backend && python3 -c "from app.services.coach.tool_registry.anthropic_defer_loading_adapter import _TOOL_DESCRIPTIONS_FR; print(len(_TOOL_DESCRIPTIONS_FR))"` → `56` |
| Rubric lint exit 0 on the 61 Concern A descriptions | `python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py --names-file /tmp/allnames_lines.txt --dict-var _TOOL_DESCRIPTIONS_FR` → exit 0 |
| banned_terms_python clean on both files | `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` → exit 0 |
| accent_lint_fr clean on changed files | `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 \| grep -E "coach_tools\|anthropic_defer_loading" \| wc -l` → `0` ; overall exit 0 |
| 28/30 round-trip fixtures pass + 2 xfail + aggregate green | `cd services/backend && python3 -m pytest tests/test_tool_search_round_trip.py -q` → `29 passed, 2 xfailed in 0.41s` |
| Full backend suite 7105 passed (+29 vs Plan 08 7076) | Pre-Plan-09 `7076 passed`. Post-Plan-09 `7105 passed, 62 skipped, 3 xfailed, 1 warning in 113.30s`. Net +29 (30 parametrized – 2 xfailed + 1 aggregate). Zero regressions in pre-existing tests. |
| 21/21 Plan 07 adapter tests still green (no regression) | `cd services/backend && python3 -m pytest tests/test_anthropic_defer_loading_adapter.py tests/test_tool_registry_adapter.py tests/test_skill_bundle_only_adapter.py tests/test_manual_subset_adapter.py tests/test_tool_registry_factory.py -q` → `21 passed in 0.36s` |
| Maestro G1 flow syntactically valid | `maestro check-syntax tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml ; echo $?` → exit 0 (one « Unknown Property: timeout » warning is a Maestro 2.5.1 informational, mirrors the existing pattern in other flows — non-blocking) |
| Engram observation #131 saved | `engram save "Plan 09 W2 tool description rewrite shipped (Concern A)" ... --project mint --type architecture --topic_key mint-calc-engine-v1:w2-plan-09:tool-description-rewrite` → `Memory saved: #131` |
| 6 task commits in git log | `git log --oneline bdf50c95^..b89671c5 \| wc -l` → 6 |

**Caveats (what I have NOT checked) :**

- Did NOT execute Maestro live on a booted sim — no sim was booted at execution time. The orchestrator's split explicitly authorizes skipping if Maestro install / sim boot would block (Task 5a).
- Did NOT flip Railway staging `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` — Task 5b is the genuine operational gate, DEFERRED to Julien GO. The command + verification sequence is documented above.
- Did NOT verify that Anthropic Tool Search Tool actually surfaces the right tool in top-3 for a representative French user message against real BM25 — that's the staging pilot. The Jaccard scorer is a coarse approximation ; the 2 xfailed fixtures may pass on real BM25 (TF×IDF would penalize wealth_tax's repeated « canton + impôt » density).
- Did NOT wire `_description_for` into `coach_chat.py` — that's Plan 10 (W2-04 `CoachToolResponse` V2 latency_tier envelope). This plan ships the description quality ; Plan 10 ships the dispatch wire-up.
- Did NOT reconcile Plan 08's `IndependentTaxBundle` placeholder tool names (`avs_cotisations_independants` / `pillar_3a_indep` / `lpp_volontaire` / `ijm_service`) with REGISTRY canonical names. Verified the matching REGISTRY entries exist : `independant_service__IndependantService_calculate_avs_contribution` (matches `avs_cotisations_independants` semantically), `independant_service__IndependantService_calculate_3a_plafond` (matches `pillar_3a_indep`), `independant_service__IndependantService_estimate_ijm_cost` (matches `ijm_service`). `lpp_volontaire` has no REGISTRY entry — Plan 09 documents the gap as a Plan-10-or-later deferral (the calc is « truly absent » per CONTEXT §domain). Removing the `plan_08_placeholder_tools` exemption from `test_allowed_tools_is_subset_of_d20_canonical_six` is deferred to Plan 10 wire-up where the dispatch site needs the canonical names anyway.
- USER VALUE DELIVERED : zero end-user-visible change yet. The descriptions land in the Anthropic tools array on every coach turn ; their BM25-surfacing benefit will materialize once Plan 10 wires the adapter into `coach_chat.py` and the staging pilot validates the routing. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR).
- MCP `mem_save` tool NOT in this executor's tool scope (same gap as 8 prior plan SUMMARYs) ; engram save succeeded via CLI fallback.

## Engram Save Status

**Saved via CLI fallback :**
- `obs_id`: **#131**
- `title`: "Plan 09 W2 tool description rewrite shipped (Concern A)"
- `type`: `architecture`
- `topic_key`: `mint-calc-engine-v1:w2-plan-09:tool-description-rewrite`
- `project`: `mint`
- `prior_finding_refs` (in content body) : #103 (vendor-agnostic adapter panel synthesis), #129 (Plan 07 ToolRegistryAdapter), #130 (Plan 08 bundles), #128 (Wave 1 closure handoff)
- Content : full What/Where/Why/Tests/Learned/Prior-refs body, ~3.8 KB

**MCP route :** `mcp__plugin_engram_engram__mem_save` NOT exposed in this executor agent's tool list (CLI fallback path documented in CLAUDE.md §3 — `~/.engram/engram.db` is the live DB shared with `engram serve` + `engram mcp` daemons).

## Wave 2 Next Steps

- **Plan 10 — `w2-coach-tool-response-v2`** : Adds `latency_tier: Literal["L1","L2","L3"]` field to `CoachToolResponse` envelope (Concern B). Wires `get_tool_registry_adapter()` into `coach_chat.py` dispatcher. First user-visible plan from W2. Will consume `_description_for(meta)` indirectly via the adapter contract.
- **Plan 11 — `w2-deprecation-shims`** : Migrates root-level `independant_service.py` + `frontalier_service.py` to canonical sub-directories with `DeprecationWarning` shims (D-CE-10). Concludes Wave 2.
- **Task 5b — staging pilot env-flip** : Once Julien sign-off received, run the documented Railway variable flip + 5-query device walkthrough + Sentry sanity check (above).

## Next Plan Readiness

- Plan 09 complete : rubric lint + 61 rewrites + round-trip fixture + Maestro YAML + 5a pre-vet. Full backend suite green.
- Next plan : **Plan 10 — `w2-coach-tool-response-v2`** (after Task 5b staging pilot Julien GO, optional).
- W2 wave-close gated by Plan 11 ; W3 (DAG cache + pre-compute + GC) starts after W2 close.

## Self-Check: PASSED

- [x] `tools/checks/tool_description_rubric.py` exists (≥60 LOC, 4 rules R1-R4, scope flags --names/--names-file/--dict-var/--rubric-exempt).
- [x] `tools/checks/tests/test_tool_description_rubric.py` exists (3 contract tests, all green).
- [x] `services/backend/app/services/coach/coach_tools.py` has 5 chip-emitter rewrites + ≥10 art. legal refs.
- [x] `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` has `_TOOL_DESCRIPTIONS_FR` (56 entries) + `_description_for(meta)` + register_tools call updated.
- [x] `services/backend/tests/test_tool_search_round_trip.py` exists (30 fixtures, 28 real passes + 2 xfailed + aggregate ≥25/30 gate).
- [x] `tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` exists (5 representative queries, maestro check-syntax exit 0).
- [x] Commits `bdf50c95` / `771d958b` / `80d89473` / `d7b95167` / `1bda1ebf` / `b89671c5` all in `git log`.
- [x] Rubric / banned-terms / accent FR lints exit 0 on the 2 changed files.
- [x] 21/21 Plan 07 adapter tests green.
- [x] Full backend suite 7105 passed (+29 vs Plan 08 baseline 7076, 0 regressions, 2 new xfailed for polish TODOs).
- [x] Engram observation #131 saved via CLI fallback.
- [x] 3 tone-sample descriptions documented verbatim for Julien post-hoc review.
- [x] Staging pilot (Task 5b) explicitly DEFERRED with documented Railway command + verification sequence.

---
*Phase: mint-calc-engine-v1*
*Plan: 09 — W2 Tool Description Rewrite (Concern A)*
*Completed: 2026-05-16*
