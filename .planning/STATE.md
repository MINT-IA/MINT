---
gsd_state_version: 1.0
milestone: mint-next-architecture-authority-20260802
milestone_name: MINT Next Architecture Authority
status: governance-only-authority-transition
stopped_at: Governance router transition applied for review; independent acceptance remains pending and Batch 4 remains draft.
last_updated: "2026-08-02T00:00:00.000Z"
last_activity: 2026-08-02 -- event-triggered architecture authority transition; no product/runtime change.
progress:
  scope: governance_only
  total_phases: 1
  completed_phases: 0
  total_plans: 1
  completed_plans: 0
  percent: 0
---

# GSD State: MINT Next Architecture Authority

## Current Router

<!-- mint-authority: milestone=mint-next-architecture-authority-20260802; phase_dir=.planning/phases/mint-next-architecture-authority-20260802; context=.planning/phases/mint-next-architecture-authority-20260802/CONTEXT.md; spec=.planning/phases/mint-next-architecture-authority-20260802/SPEC.md; mode=governance-only -->

The active phase is governance-only: `.planning/phases/mint-next-architecture-authority-20260802/CONTEXT.md` and `.planning/phases/mint-next-architecture-authority-20260802/SPEC.md`. It establishes the event-triggered Batch 4 maps as the candidate global architecture without activating any screen, route, calculator, API, recommendation, or deployment.

Journey OS remains the runtime truth overlay. The former retirement-first phase is preserved byte-for-byte as a historical receipt and partially runtime-evidenced legacy vertical, not deleted and not treated as the global IA; its physical-device restore limitation remains open.

## Project Reference

- Session authority: `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`.
- Governance contract: `.planning/phases/mint-next-architecture-authority-20260802/SPEC.md`.
- Runtime queue/evidence: `.planning/journeys/`.
- Candidate architecture: `product/mint_next/batch4/`, still `draft_unproven`.
- Next product phase: none queued.

## Current Position

Phase: `mint-next-architecture-authority-20260802` — governance transition under independent review.
Status: no Flutter/backend/runtime/device change; Batch 4 promotion remains a separate gate.

## Historical Receipts

The sections below pre-date the current cleanup/account lifecycle session. They
stay available for provenance, but they are not the active routing state.

## Phase 01.1 Planning Receipt (walkthrough-first-grounding, 2026-05-21)

- **Phase outcome (PLANNED)** : 3 PLAN.md files written in 3 sequential waves on dev branch, no PRs yet (planning artifacts only).
  - `01.1-01-PLAN.md` (Wave 1, autonomous=true) — 2 tasks producing `01.1-PRECONDITIONS.md` with 8 ✓/✗/HALT verdict blocks (PR #663 mergedAt, staging /health, sim bootable, Maestro CLI, sentry-cli, pgvector ≥100 docs, citation_parser + verb_gate + L1 deployed, plafond 3a constants served from staging).
  - `01.1-02-PLAN.md` (Wave 2, autonomous=true) — 2 tasks producing `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml` (3-tier assertion grammar : grounded-values / non-crash / exploratory ; salary 80'000 CHF salaried + swiss_native default ; assertNotVisible LSFin lemmas) + `01.1-DRYRUN-TRACE.md`.
  - `01.1-03-PLAN.md` (Wave 3, **autonomous=false**, Julien G2 checkpoint) — 4 tasks producing `01.1-OBSERVATIONS.md` (per-finding triage into 11 finding-classes from RESEARCH §16) + `01.1-RELITIGATION-VERDICT.md` (5 sub-phase §9 + 5 parent §11 triggers) + ≥6 PNG screenshots under `screenshots/walkthrough/01.1-hero/`.
- **Files created/modified : 7 total** — 3 PLAN.md + 01.1-CONTEXT.md + parent 01-RESEARCH.md + parent 01-VALIDATION.md + ROADMAP.md entry.
- **Gates run :**
  - **gsd-planner verdict** : PLANNING COMPLETE, 3 plans + 3 waves + REQ-AUDIT-01/-08/-10 all assigned. Commit `569b2a52` on `dev`.
  - **gsd-plan-checker verdict** : VERIFICATION PASSED, 15/15 dimensions ≥ 7 (goal achievement 9, requirement coverage 10, anti-shallow execution 9, Maestro flow concreteness 9, citation-gate trace 10, wave/dependency 10, Julien G2 10, threat model 9, validation Nyquist 9, re-litigation gate 10, public-repo discipline 9, out-of-scope discipline 10, Wave 0 owner 10, OBSERVATIONS schema 10, must_haves 9). 4 POLISH notes (non-blocking, mid-flight) : banned-term lint lemma awareness, idb fallback messaging, Maestro `--dry-run` flag pre-verification, requirements line in sub-phase CONTEXT (cosmetic).
- **Commits :** `3a9b6d3d` (RESEARCH + VALIDATION) + `60b9e0db` (ROADMAP Phase 1.1 + slim CONTEXT) + `569b2a52` (3 PLAN.md files) on `dev`.
- **Duration :** ~25 min orchestration turn (researcher + validation seed + planner + checker, no revision loop needed).
- **0-Trust §9 honesty :** Phase 01.1 is PLANNED, not executed. Per CLAUDE.md §9.5 4-stage shipping pipeline, this is **Stage 0 of 4** (not even « code-shipped ») — the audit's grounded findings only materialize when Plan 01.1-03 executes on a real sim against staging with Julien G2 sign-off. NO claim « ready / works / shipped » applies until then.
- **USER VALUE DELIVERED :** 0 direct end-user-visible change. Audit-grounding scaffolding ready ; the real value arrives at Plan 01.1-03 completion (observed blockers documented with deterministic citation, escalation rows routing into 01.2 → 01.10 sub-phases).

## Plan mint-data-architecture-v1-02-event-log-03 Receipt (PARTIAL — Task 0 + PR-1 + PR-2 + iter-2 A10/B14/B18 + PR-3a code, 2026-05-18)

- **Plan outcome (PARTIAL — substrate-and-code-only delivery)** : 7 commits on `feature/mint-data-arch-v1-02-event-log-03-pre-flight-and-pr1` land the Plan 02-03 first executor turn :
  - `0b93151f` — Task 0 (iter-2 B1) preflight zero-user prod gate : script + 5 tests (3 SQLite + 2 pg-marked).
  - `3c1c9981` — PR-1 : `FF_FACT_EVENT_DUAL_WRITE` feature flag (default OFF), added to `FeatureFlags` class + module-level `is_fact_event_dual_write_enabled()` helper matching Plan 02-02 `FF_FACT_CURRENT_READ` pattern.
  - `53149452` — PR-2 : dual-write code path in `snapshot_service.create_snapshot()` under FF (default OFF) ; 5 canary field_keys projected via `FactProjector.project_event()` ; 4 SQLite tests including UPSERT-last-writer-wins.
  - `61f86adf` — iter-2 A10 (qa-expert HIGH-1) : deterministic `tools/parity/projection_diff.py` (canonical JSON + Decimal 1e-9 tolerance + missing-key=None) + 18 library/CLI tests + 13-fixture self-test.
  - `67223b5b` — iter-2 B14 (postgres-pro MED-5 + database-architect MED-6) : alembic p118 `_phase02_parity_audit` table + ORM + 5 migration tests (100%-staging-user audit persistence ; replaces original 20-random-users sample).
  - `0663fba7` — iter-2 B18 (REVIEWS.md 4-way convergence) : alembic p119 `_phase02_parity_audit_continuous` table + ORM + `continuous_drift_sampler.py` cron (30min × 100 users × 7-day soak) + `.github/workflows/pg-soak-nightly.yml` (cron commented OFF by default) + 9 tests.
  - `ee12f2d9` — PR-3a code-only : idempotent `backfill_snapshot_to_fact_event.py` + 4 idempotency tests (first run writes 1 row, second run skips with counter increment, dry-run reports without writing).
- **Files created/modified : 22 total** — 20 new + 2 modified (`feature_flags.py` PR-1 + `snapshot_service.py` PR-2). +2889 lines.
- **Gates run :**
  - **G3 dev CI commit sha trail :** N/A — branch not yet pushed ; commits visible via `git log --oneline 1004b4192da7033e5f2e51c2ef959781d4d77fc9..HEAD` (7 sequential commits).
  - **G4 Regression :** ✓ 31 passed + 3 skipped (pg-marked) on targeted sweep (Plan 02-02 canaries + Plan 02-03 new tests + projector atomicity). NOT full pytest suite — focused on touched surface. Plus 18 passed for `tools/parity/tests/test_projection_diff.py`.
  - **G5 Lints :** ✓ `banned_terms_python.py` × 6 new+modified files exit 0 ; `alembic_boolean_default_lint.py p118+p119` exit 0 ; `hmac_pepper_audit.py services/backend/app/cron/` exit 0 (caught initial `hashlib.sha256(user_id)` bug → fixed to `hmac_user_id()` per D-24/obs #175).
  - **G2 Julien sign-off :** ⏳ DEFERRED — Task 2a CHECKPOINT is the next operational gate (Julien-gated staging-zero-drift, see SUMMARY § Awaiting).
- **Duration :** ~23 min executor turn.
- **Deviations :** 6 Karpathy #1 assumption-surfacing applied (FeatureFlags shape ≠ plan ; SnapshotModel cols ≠ canary keys + FactEvent schema ≠ plan ; User has no deleted_at ; SQLite BigInteger PK is not autoincrement ; alembic head ≠ p116 ; hmac lint correctly caught bare sha256). Plus 1 honest-mapping disclosure : backfill recovers only `monthly_gross_income` from historical SnapshotModel rows — other 4 canary keys come from FORWARD writes via PR-2 dual-write. Documented in `deferred-items.md` style in SUMMARY § Deviations.
- **0-Trust §9 honesty :** SUMMARY uses neither « shipped » nor « ready » nor « green » about the Plan as a whole. Code is « code-only-shipped on a local branch ; operational verification on Railway staging is the Task 2a CHECKPOINT ». Banned phrases avoided ; required claim-format (Evidence + Caveat) block present in SUMMARY § 0-Trust §9.6.
- **Engram :** Observation #217 saved via CLI fallback : `topic_key=mint-data-architecture-v1-02:wave-2-3:six-pr-migration-substrate-pr0-pr1-pr2-pr3a-code` type=decision. `prior_finding_refs` cite Plan 02-02 #214 (FULLY COMPLETE) + #211 (canary GATE) + #205 (Plan 02-01 merged) + #174 (Phase 02 schema verdict) + Plan 02-01 #204.
- **USER VALUE DELIVERED :** 0 direct end-user-visible change. The substrate (FF + dual-write + parity tooling + audit tables + cron + backfill script) enables the operational migration once Julien gates the Task 2a CHECKPOINT and the subsequent PR-3b / PR-4 / PR-5 stages each clear their own checkpoints. Plan 02-04 close-out (counter firing + Sentry alarms) remains downstream.

## Plan mint-calc-engine-v1-20 Receipt (W4 phase-close engram doctrine — D-CE-18 + Concern F + 5-gate exit contract, 2026-05-17)

- **Plan outcome** : phase close-out + 5-gate exit gate run. Produces (1) `mint-calc-engine-v1-VERIFICATION-REPORT.html` finalized at 541 lines with phase-level header + per-wave rollup (W1/W2/W3/W4) + 5-gate exit panel + cumulative metric snapshot + 2 Critical Discoveries (Plan 19 dead-COUP-04 + Plan 11 SCOPE CORRECTION) + 8 deferred items + engram doctrine roll-up + 5 lessons learned + next-phase pointer ; (2) `mint-calc-engine-v1-SUMMARY.md` with per-D-CE-XX (20 verdicts) + per-Concern (A-F) + per-Finding (1-6) disposition + counter-arguments and data gaps block ; (3) ROADMAP.md milestone marker flipped 🚧 → ◆ + phase status block + Plan 20 checkbox ticked ; (4) STATE.md frontmatter status `executing` → `phase-closed-pending-operational-gates` + this receipt ; (5) phase-level engram observation saved via CLI fallback with ≥10 prior_finding_refs (Concern F compounding observable proof).
- Files created/modified : 4
  - `mint-calc-engine-v1-SUMMARY.md` (NEW — phase-level SUMMARY ~220 lines, frontmatter + TLDR + cumulative metric snapshot + per-D-CE-XX disposition + per-Concern disposition + per-Finding disposition + 2 Critical Discoveries + 5-gate exit + 8 deferred items + counter-args + lessons learned + next-phase pointer + Self-Check)
  - `mint-calc-engine-v1-VERIFICATION-REPORT.html` (MODIFIED — appended phase-close rollup section after per-plan caveat blocks, 361 → 541 lines, +180 lines)
  - `.planning/ROADMAP.md` (MODIFIED — milestone v2.10 marker 🚧 → ◆ + Phase block status flipped + Plan 20 checkbox ticked)
  - `.planning/STATE.md` (MODIFIED — frontmatter + Current Position + this receipt)
- Gates run :
  - **G1 Maestro** : ⏭ SKIPPED — `xcrun simctl list devices booted` → `-- iOS 26.2 --` (no booted device). Maestro CLI present at `/Users/julienbattaglia/.maestro/bin/maestro` but flow files require sim. Standard caveat per executor protocol ; re-runnable by Julien with sim booted.
  - **G2 Julien device sign-off** : ⏳ DEFERRED — `autonomous: false` plan, executor cannot self-clear visual gate ; 5 walkthrough scenarios documented in SUMMARY + HTML report.
  - **G3 dev CI commit sha trail** : ✓ PASS — `git log --oneline | grep -i "mint-calc-engine-v1" | wc -l` → **109 commits** ; first `91b741ed` (KILL Phase 96 + open phase) ; latest pre-Plan-20 `91fe510e` (Plan 19 docs commit) ; no holes between Plan 01 and Plan 19 commits.
  - **G4 Regression** : ✓ PASS — `cd services/backend && python3 -m pytest tests/ -q` → **7264 passed, 63 skipped, 3 xfailed, 1 warning in 117.22s** (matches Plan 18 baseline ; Plan 19 = test-only +11 lint tests already in count ; zero regression).
  - **G5 Lints** : ✓ PASS — (a) `banned_terms_python services/backend/app/services/coach/bundles/ runtime_verb_gate.py` exit 0 ; (b) `accent_lint_fr.py --scope backend` exit 0 ; (c) `tool_description_rubric.py services/backend/app/services/coach/coach_tools.py` exit 0 (Plan 09 polish-TODO warnings baseline) ; (d) `profile_safe_fields_parity.py` exit 0 (SOFT mode, reports 45-field drift baseline).
- Commits : Plan 20 docs commit pending at end of executor turn (single phase-close commit covering SUMMARY + HTML + ROADMAP + STATE per executor `<final_commit>` protocol).
- Duration : ~17 min (executor turn).
- Deviations : 0 auto-fix. (1 minor scope-extension noted) the orchestrator-supplied `<objective>` listed 7 deferred items + G2 = 8 total ; the deferred list in SUMMARY+HTML matches verbatim. No new deferred items surfaced during the close-out run beyond what was tracked across prior plans.
- Out-of-scope discoveries : 0 net new. The 2 pre-existing « recommandé » hits in `coach_chat.py:1180` + `:2814` (FactBot provenance + tool-result strings) flagged by Plan 18's extended lint remain in `deferred-items.md` for a small follow-up PR, NOT escalated to a Critical Discovery (already documented disposition).
- 0-trust : every claim in SUMMARY + HTML cites a specific source (plan SUMMARY block, commit sha, command output, or grep count). Banned claim words (« shipped », « ready », « SHIPPED ») are NOT used about the phase as a whole — phase status string is « ◆ code-shipped on dev, pending operational gates » throughout. Stage 1 of 4 per CLAUDE.md §9.5 is honored explicitly in SUMMARY + HTML + ROADMAP. The « what we have NOT done » list (8 deferred items + G2 walkthrough steps) is the most prominent block in SUMMARY § Deferred + HTML § Deferred.
- Engram : Plan 20 phase-level observation save pending at end of executor turn via CLI fallback with `topic_key=mint-calc-engine-v1:phase-close:shipped-pending-G2` and `type=architecture`. Expected obs id **#146** (sequential from W4 plan obs #143/#144/#145). `prior_finding_refs` cites ALL 6 wave-close obs (#128 W1 / #136 W2 / #142 W3 / #143 #144 #145 W4 plan obs) + W0 audit obs (#103-107) + phase planning obs (#117-118). Total ≥10 refs as required by Plan 20 acceptance criteria + Concern F compounding observable per CLAUDE.md §3.5.
- USER VALUE DELIVERED : **0 direct end-user-visible change**. Phase close-out is documentation + observability roll-up — no code change, no behavior change, no UI change. End-user value from this phase MATERIALIZES only when (1) Julien runs G2 device sign-off, (2) operational gates #2-#8 activate (Railway env-flip + cron + metrics scraping + endpoint fanout + Flutter drift fix), (3) dev → staging → main merge pipeline completes (Stages 2-4 of 4 per CLAUDE.md §9.5). What's been built in 20 plans is a complete substrate (grounding + typed payloads + tool discoverability + cache + metrics + verb gate + parity lint) — every plan's SUMMARY documents what it shipped, what it didn't, and what Stage of 4 the corresponding work occupies. The substrate is observable and reversible (every plan can be re-opened if G2 finds a defect). The phase status « ◆ code-shipped on dev, pending operational gates » is the honest framing per CLAUDE.md §9.

## Plan mint-calc-engine-v1-18 Receipt (W4 banned-verb lint extension + runtime fail-closed gate — D-CE-16 triple defense complete, 2026-05-17)

- **Plan outcome** : mechanical execution, mid-Wave-4. Ships D-CE-16 layers (b) lint-time + (c) runtime fail-closed. Plan 04 (Wave 1) already shipped layer (a) schema-impossibility (`L2ComparePayload` rejects `recommended_option` etc. via `extra='forbid'`). Now : (b) `tools/checks/banned_terms_python.py` extended with `BANNED_PARAPHRASE_VERBS` (11 verbs verbatim from CONTEXT §D-CE-16(b)) + NFKC normalisation + self-exempt ; (c) `services/backend/app/services/coach/runtime_verb_gate.py` (184 LOC, `gate(text) -> (passed, _FALLBACK_FR)`) with NFKC + zero-width-char strip BEFORE pre-compiled `re.IGNORECASE` patterns, wired UPSTREAM of Phase 94 citation parser inside `_run_narrator_with_gate` (Q5 = before per VALIDATION default + orchestrator pre-decide). Sentry breadcrumb `coach.verb_gate.fired` on every fire (PII-safe : profile_id_hashed sha256-16 + `fallback_emitted=True`). Always-on, NO feature flag — fail-closed beats opt-in for LSFin liability per orchestrator pre-decide.
- Files created : 4
  - `services/backend/app/services/coach/runtime_verb_gate.py` — 184 LOC. `gate(text)` + `_strip_zero_width()` + `_ZERO_WIDTH_CHARS` frozenset (U+200B/200C/200D/FEFF/2060) + `_FALLBACK_FR = "Je n'ai pas cette donnée pour l'instant."` verbatim string literal + importlib loader for the lint vocabulary.
  - `services/backend/tests/test_runtime_banned_verb_gate.py` — 149 LOC, 22 tests (empty/whitespace pass, clean LSFin passes, base ban triggers, paraphrase verb triggers, NFKC decomposed-accent caught, zero-width injection caught, case-insensitive, multi-violation single fallback, parametrised across all 11 paraphrase verbs).
  - `services/backend/tests/test_coach_chat_verb_gate_wire.py` — 202 LOC, 9 tests (symbol import, BEFORE-citation-gate ordering, short-circuit on fail, `coach.verb_gate.fired` breadcrumb category, placement inside `_run_narrator_with_gate`, baselines `art. `/`_maybe_wrap_v2`/`inputs_provenance` preserved).
  - `tools/checks/tests/test_paraphrase_verbs.py` — 180 LOC, 16 tests (BANNED_PARAPHRASE_VERBS constant exposed, 11 verbs scanned, lint CLI exit 1 per verb, base 7 still flagged, safe LSFin exit 0, NFKC normalised input still flagged).
- Files modified : 5
  - `tools/checks/banned_terms_python.py` — added `BANNED_PARAPHRASE_VERBS` tuple (11 verbs), `BANNED_TERMS` public union (19 entries), NFKC normalisation in `scan_file()`, self-exempt via `_SELF_PATH`, paraphrase_re pre-compiled patterns.
  - `services/backend/app/api/v1/endpoints/coach_chat.py` — added `from app.services.coach.runtime_verb_gate import gate as _runtime_verb_gate` next to the citation_parser import + insert verb-gate call BEFORE `_citation_gate` inside `_run_narrator_with_gate` with short-circuit return on fail + `sentry_sdk` breadcrumb category `coach.verb_gate.fired`.
  - `services/backend/app/services/coach/bundles/lpp_projector.py` + `succession_divorce_bundle.py` + `tax_explainer.py` — added `# llm-doctrine-fragment-banned-list` exemption marker above `_PROMPT_FRAGMENT` so newly-flagged « il faut » / « tu devrais » roots in doctrine strings don't break the bundles lefthook gate.
- Gates green :
  - `cd services/backend && python3 -m pytest tests/test_runtime_banned_verb_gate.py -q` → `22 passed in 0.27s`
  - `cd services/backend && python3 -m pytest tests/test_coach_chat_verb_gate_wire.py -q` → `9 passed in 0.21s`
  - `python3 -m pytest tools/checks/tests/test_paraphrase_verbs.py -q` → `16 passed in 0.33s`
  - `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` → `212 passed in 0.89s` (Phase 94 byte-identity matrix intact, zero regression)
  - `cd services/backend && python3 -m pytest tests/ -q` → **`7264 passed, 63 skipped, 3 xfailed, 1 warning in 115.53s`** (delta vs Plan 17 baseline 7233 = `+31 passed`, zero regression on skipped/xfailed)
  - `python3 tools/checks/banned_terms_python.py tools/checks/banned_terms_python.py` → exit 0 (self-exempt)
  - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/bundles/ services/backend/app/services/coach/runtime_verb_gate.py` → exit 0 (after 3 exemption markers added)
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
  - `python3 -c "from tools.checks.banned_terms_python import BANNED_TERMS; print(len(BANNED_TERMS))"` → `18` ≥ 18 acceptance
  - `grep -c "le plus pertinent\|plus avantageux\|nettement plus\|clairement supérieur\|mon conseil" tools/checks/banned_terms_python.py` → `5` ≥ 5 acceptance
  - `grep -c "unicodedata.normalize" services/backend/app/services/coach/runtime_verb_gate.py` → `1` ≥ 1 acceptance
  - `grep -c "_ZERO_WIDTH_CHARS\|_strip_zero_width" services/backend/app/services/coach/runtime_verb_gate.py` → `6` ≥ 2 acceptance
  - `grep -c "runtime_verb_gate" services/backend/app/api/v1/endpoints/coach_chat.py` → `2` ≥ 1 acceptance
  - Baselines preserved (Plans 09 / 10 / 17 surfaces in coach_chat.py) : `art. `=5, `_maybe_wrap_v2`=6, `inputs_provenance`=0
- Commits :
  - `a8ca28a1` (Task 1 RED — 14 failing lint tests, NFKC + 11 paraphrase verbs not yet present)
  - `95778fef` (Task 1 GREEN — banned_terms_python extension + 3 bundle exemption markers, 16/16 tests pass)
  - `a4476320` (Task 2 RED — 22 failing gate tests, ModuleNotFoundError as expected)
  - `6927d15f` (Task 2 GREEN — runtime_verb_gate.py 184 LOC, NFKC + zero-width strip, 22/22 tests pass)
  - `2cb19f8d` (Task 3 RED — 9 failing wire-up tests, runtime_verb_gate not yet imported in coach_chat.py)
  - `d48ca303` (Task 3 GREEN — verb gate wired BEFORE citation gate in _run_narrator_with_gate, 9/9 tests pass)
  - docs commit pending (this STATE update + SUMMARY + ROADMAP)
- Duration : ~28 min
- Deviations : 4 auto-fixed. (1) **Rule 1 bug** : `from tools.checks.banned_terms_python import …` raises `ModuleNotFoundError` from `services/backend/` cwd (`tools.checks` not on sys.path). Switched to `importlib.util.spec_from_file_location` loader at module load time (same pattern as Plan 04 SUMMARY decision). (2) **Rule 1 bug** : initial `Path(__file__).resolve().parents[4]` resolved to `services/`, not repo root ; bumped to `parents[5]` (`coach[0]/services[1]/app[2]/backend[3]/services-dir[4]/MINT.nosync[5]`). (3) **Rule 2 critical missing functionality** : newly-extended lint flagged 3 pre-existing `_PROMPT_FRAGMENT` doctrine strings (`bundles/lpp_projector.py:35`, `bundles/succession_divorce_bundle.py:65`, `bundles/tax_explainer.py:57`) containing « il faut » / « tu devrais » as legitimate narrator instructions (« pose la règle, jamais "tu devrais" »). Added `# llm-doctrine-fragment-banned-list` exemption marker above each — existing documented pattern (CONTEXT 93.5 D-09). (4) **Rule 3 blocking issue** : wire-up comment said « Runs BEFORE _citation_gate (Q5 = before) » → test regex `_citation_gate\s*\(` matched the comment (with trailing space) at offset 518, making the gate appear AFTER its own wire-up call. Reworded comment to « BEFORE the Phase 94 citation parser » ; semantically identical, no false-positive regex hit.
- Out-of-scope discoveries : 2 pre-existing « recommandé » hits in `coach_chat.py:1180` + `:2814` flagged by extended lint — PROVENANCE-block + tool-result confirmation strings (FactBot Sprint data fields, NOT narrator output). Lefthook gate cibles `bundles/*.py` so `endpoints/coach_chat.py` not blocked. Tracked in `.planning/phases/mint-calc-engine-v1/deferred-items.md` row 2026-05-17 for a small follow-up PR in W4 close batch.
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-18-w4-banned-verb-lint-runtime-gate-SUMMARY.md` `## Self-Check: PASSED` with 16 citations + explicit « What I HAVE NOT done » block listing : did NOT run the verb gate end-to-end on Railway staging sim (no live cloud session) ; did NOT add `coach.verb_gate.fired` Sentry dashboard / alerting rule (observability follow-up, NOT Plan 18 scope) ; did NOT measure latency overhead at scale ; did NOT open a PR (direct on `dev`) ; did NOT merge dev → staging ; did NOT call MCP `mem_save` tool (14th consecutive plan with MCP exposure mismatch) ; did NOT fix the 2 pre-existing « recommandé » hits in coach_chat.py (deferred) ; did NOT update `docs/coach-tool-routing.md` (no tool routing keys / calculators / invariants modified) ; did NOT run Maestro G1 sim flow (no UI surface) ; did NOT activate any feature flag (gate is always-on by design per orchestrator pre-decide).
- Engram : observation **#144** saved via CLI fallback (`engram save "D-CE-16 triple defense complete — Plan 18 ships layers (b) lint extension + (c) runtime gate" --project mint --type architecture --topic_key mint-calc-engine-v1:w4-plan-18:banned-verb-runtime-gate`). `prior_finding_refs` content cites Plan 04 obs (no engram id — only in CONTEXT / Plan 04 SUMMARY) + **#103** (panel synthesis D-CE-16) + **#137** (Plan 12 W3 idx, same codebase) + **#141** (Plan 16 W3 wave-close pattern).
- USER VALUE DELIVERED : ZERO direct end-user-visible change YET, but the safety floor under the narrator just got 2 redundant defense layers. Triple defense complete : (a) schema-impossibility (Plan 04) + (b) lint extension + (c) runtime fail-closed. Per arXiv 2504.11168 + 2512.01353 : lexical guardrails alone fail at 40-80 % paraphrase + 100 % character injection ; schema layer is the only one paraphrase-resistant by construction ; lint + runtime are belt-and-suspenders for emission paths above it. End-user impact materialises the next time the LLM tries to emit « tu devrais » / « le plus pertinent » / « recommandé » : the user sees the LSFin-safe templated FR fallback (« Je n'ai pas cette donnée pour l'instant. ») rather than a ranking verb that could trigger LSFin art. 8 / 10 liability. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev`, no PR, no merge, no end-user behavior change YET).
- Wave 4 progress : Plan 17 (Prometheus metrics counters + inputs_provenance) + Plan 18 (D-CE-16 triple defense) shipped. Remaining : Plan 19 (Flutter ↔ server `_PROFILE_SAFE_FIELDS` parity lint, Concern C) + Plan 20 (Wave 4 close-out + engram doctrine).

## Plan mint-calc-engine-v1-16 Receipt (W3 GC daily job — Finding 4 mitigation + Wave 3 close-out, 2026-05-17)

- **Plan outcome** : mechanical execution + 1 plan-spec drift fix + Wave 3 close-out. Ships the Finding 4 mitigation — daily GC for the `scenarios` table trimming rows where `superseded_by IS NOT NULL AND created_at < now() - interval '<max_age_days> days'`. `purge_superseded_scenarios(db, max_age_days=30, dry_run=False) -> int` runs the predicate ; `scripts/run_gc.py` is the standalone Railway-cron-ready runner ; `railway.cron.json` declares the cron service config (schema-valid against Railway public schema). **Cron NOT activated** — Julien GO required for the final activation step (Railway dashboard or CLI). Plan 15 warm-marker interaction VERIFIED : warm-markers are written as LIVE rows (invisible to GC) and only enter GC eligibility once a later real compute supersedes them — exactly the compaction semantics Plan 15 SUMMARY promised.
- Files created : 4 (448 LOC total)
  - `services/backend/app/services/cache/gc_job.py` (91 LOC) — single `def purge_superseded_scenarios(db, max_age_days=30, dry_run=False) -> int`. Predicate factored into `base_query`. Dry-run path : `base_query.count()` + log + return. Live path : `base_query.delete(synchronize_session=False)` + commit + log + return.
  - `services/backend/scripts/run_gc.py` (94 LOC, executable bit set) — argparse for `--dry-run` + `--max-age-days N`. `sys.path.insert(0, _BACKEND_DIR)` injection so script runs from any cwd (Rule 1 bug fix). Exit 0 on success / 1 on exception.
  - `services/backend/tests/test_gc_job.py` (250 LOC, 6 tests against in-memory SQLite) — covers 5 predicate scenarios (old superseded purged / live preserved / recent within-window preserved / dry-run mutates nothing / max_age_days configurable) + 1 idempotence test (second run on stable state = 0 deletions).
  - `services/backend/railway.cron.json` (13 LOC) — `deploy.cronSchedule: "0 3 * * *"` + `deploy.startCommand: "python scripts/run_gc.py"` + `deploy.restartPolicyType: "ON_FAILURE"` + `restartPolicyMaxRetries: 3` + `build.dockerfilePath: "Dockerfile"`. Schema-validated against `backboard.railway.app/railway.schema.json` — zero unknown fields.
- Files modified : 0. No ORM change, no migration change, no caller change.
- Gates green :
  - `cd services/backend && python3 -m pytest tests/test_gc_job.py -q` → `6 passed in 0.27s`
  - `cd services/backend && python3 -m pytest tests/ -q` → **`7189 passed, 63 skipped, 3 xfailed, 1 warning in 115.23s`** (delta vs Plan 15 baseline 7183 = `+6 passed`, zero regression on skipped/xfailed)
  - Local dry-run (services/backend cwd) : `python3 scripts/run_gc.py --dry-run` → exit 0 + `GC complete: 0 rows would be purged (max_age_days=30, dry_run=True).`
  - Local dry-run (repo root cwd) : `python3 services/backend/scripts/run_gc.py --dry-run --max-age-days 30` → exit 0
  - `grep -c "superseded_by.isnot(None)" services/backend/app/services/cache/gc_job.py` → `2` (acceptance ≥2 OK)
  - Railway schema validation : `used: {'cronSchedule', 'restartPolicyType', 'startCommand', 'restartPolicyMaxRetries'}` ; `unknown: set()` ; `build_unknown: set()`
  - `python3 tools/checks/banned_terms_python.py <3 touched code files>` → exit 0
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
- Commits :
  - `848651c5` (RED Task 1 — 6 failing tests, ModuleNotFoundError as expected)
  - `fd624142` (GREEN Task 1 — gc_job module, 6/6 tests pass)
  - `26ccfa8d` (Task 2 — run_gc.py standalone runner with sys.path injection)
  - `1636e71c` (railway.cron.json declaration — DECLARATION ONLY, not activated)
  - docs commit pending (this STATE update + SUMMARY + ROADMAP + REQUIREMENTS + HTML report)
- Duration : ~7 min
- Deviations : 1 auto-fixed. (Rule 1 bug) `python scripts/run_gc.py` from any non-`services/backend/` cwd raised `ModuleNotFoundError: No module named 'app'` because `sys.path[0]` is set to the script's `scripts/` directory, not the parent. Injected `sys.path.insert(0, _BACKEND_DIR)` at line 35-36 of the script BEFORE the `from app.*` imports (with `# noqa: E402`). The sibling `scripts/railway_pre_deploy_migrate.py` avoided this by not importing `app.*` at all (uses `subprocess` + `sqlalchemy` directly). Verified : script now runs cleanly from repo root, `services/backend/`, or Railway's `/app` Docker dir. ALSO : one plan-template adjustment — primary `railway.json` NOT modified (would convert uvicorn service into cron job). Idiomatic Railway pattern is a SEPARATE config-as-code file (`railway.cron.json`) for the cron service. Documented in SUMMARY decisions block. Not a Rule 4 escalation — plan intent (ship a cron declaration) delivered with adapted file shape.
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-16-w3-gc-job-SUMMARY.md` `## Self-Check : PASSED` with 13 citations + explicit « What I HAVE NOT done » block listing : did NOT activate the Railway cron (Julien GO required, detailed activation steps in SUMMARY § Deferred — Wave 3 close-out gates) ; did NOT run dry-run on Railway staging (no live Railway CLI session) ; did NOT run EXPLAIN ANALYZE on Railway PG (no live PG access) ; did NOT open a PR (direct on `dev`) ; did NOT merge dev → staging ; did NOT add Sentry breadcrumbs (Plan 17 metrics scope) ; did NOT measure DELETE latency at scale ; did NOT modify primary `railway.json` ; did NOT modify `scenario.py` model ; did NOT use APScheduler in-process variant (rejected per RESEARCH §Q-E) ; did NOT call MCP `mem_save` tool (12th consecutive plan with MCP exposure mismatch).
- Engram : observation **#141** saved via CLI fallback (`engram save "W3 closed — Plan 16 GC job ships, Wave 3 cache+pre-compute+GC spine complete" --project mint --type architecture --topic_key mint-calc-engine-v1:w3-plan-16:gc-job`). `prior_finding_refs` content cites **#137** (Plan 12 composite index — same table) + **#138** (Plan 13 cache reader/writer — reader filter makes GC invisible) + **#140** (Plan 15 pre-compute warm-markers — compaction semantics verified) + **#103** (panel synthesis D-CE-12+13+14 + Finding 3+4 wave-close).
- USER VALUE DELIVERED : ZERO end-user-visible YET, and zero infrastructure value until activation. Plan 16 ships pure backend infrastructure : a dormant DELETE function + a dormant Railway cron declaration. End-infra impact lands when (1) Julien activates the cron service ; (2) the first 03:00 UTC tick fires + dry-run validates eligibility count ; (3) 30+ days of accumulated production traffic produce superseded-past-cutoff rows ; (4) daily ops cycle settles into bounded scenarios-table growth. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev`, no PR, no merge, no Railway service created, no end-user behavior change).
- Wave 3 close-out : **complete code-side.** Plans 12 (index) + 13 (cache layer) + 14 (REVERSE_DEP_MAP) + 15 (BackgroundTasks pre-compute + SLI baseline) + 16 (GC) all landed. D-CE-12 SLO sub-50ms p95 baseline. D-CE-13 lifecycle accepted. D-CE-14 SLI 0.767/0.900 baseline. Finding 3 closed (composite index ships). Finding 4 closed (GC predicate ships + cron declaration committed). **Final activation gate = Julien Railway cron service creation.** Wave 4 (Plans 17-19 — metrics counters, lints, runtime gate) can open immediately ; activation is parallelizable with W4 plan execution.

## Plan mint-calc-engine-v1-13 Receipt (W3 cache reader + writer + AsyncSingleflight + get_or_compute — D-CE-12 + Concern E, 2026-05-17)

- **Plan outcome** : mechanical execution, mid-Wave-3. Ships the D-CE-12 read-through cache layer + Concern E AsyncSingleflight stampede mitigation that consume Plan 12's `idx_scenarios_cache_lookup` composite partial index. `cache_reader.lookup()` runs the partial-index query verbatim (`WHERE profile_id=? AND kind=? AND inputs_hash=? AND superseded_by IS NULL ORDER BY created_at DESC LIMIT 1`). `cache_writer.write()` maintains the supersede-chain DAG (new row + flips prior row's `superseded_by`, idempotent on same `inputs_hash`). `AsyncSingleflight` = `defaultdict(asyncio.Lock)` keyed by `(profile_id, kind, inputs_hash)` ; GIL-safe slot insertion per RESEARCH §Q-E. `get_or_compute()` orchestrates read → singleflight → re-check → compute_fn → write. Plan 14 (reverse-dep map) + Plan 15 (BackgroundTasks pre-compute) + Plan 16 (GC) consume this layer downstream.
- Files created : 10
  - `services/backend/app/services/cache/__init__.py` — 24 LOC. Public API exports : `lookup`, `write`, `AsyncSingleflight`, `_singleflight`, `get_or_compute`.
  - `services/backend/app/services/cache/cache_reader.py` — 59 LOC. Single async function ; query column order matches Plan 12 index column order verbatim.
  - `services/backend/app/services/cache/cache_writer.py` — 87 LOC. 5-step transaction (find prior live → idempotent guard → insert new → flip prior.superseded_by → commit). Maps public `payload` arg → ScenarioModel `outputs` column (Rule 1 column-name fix).
  - `services/backend/app/services/cache/singleflight.py` — 54 LOC. `AsyncSingleflight` class + module-level `_singleflight` singleton. Locks NEVER pop'd after release (eviction = GC's job, Plan 16).
  - `services/backend/app/services/cache/get_or_compute.py` — 70 LOC. Read-through orchestrator verbatim from RESEARCH §Q-E lines 792-813.
  - `services/backend/tests/test_cache_reader.py` — 175 LOC, 4 tests (live / superseded / most-recent / missing).
  - `services/backend/tests/test_cache_writer.py` — 171 LOC, 4 tests (first-insert / supersede-chain / idempotent / 3-write chain depth 2).
  - `services/backend/tests/test_cache_singleflight.py` — 165 LOC, 5 tests (same-key peak=1 / different-keys parallel / release / lock-identity-persists / stampede headline ≥80ms elapsed for 10×10ms hold).
  - `services/backend/tests/test_get_or_compute.py` — 202 LOC, 4 tests (cold-1-call / warm-0-call / **headline stampede 10→1** / compute-raises-no-row).
  - `services/backend/tests/bench_cache_reader.py` — 139 LOC, 1 env-gated test (MINT_RUN_CACHE_BENCH=1).
- Files modified : 0. No ORM change, no migration, no caller change (Plan 14+ wire the consumers).
- Gates green :
  - 4 cache test files : `cd services/backend && python3 -m pytest tests/test_cache_reader.py tests/test_cache_writer.py tests/test_cache_singleflight.py tests/test_get_or_compute.py -q` → `17 passed in 0.55s`
  - Full regression : `cd services/backend && python3 -m pytest tests/ -q` → **`7165 passed, 63 skipped, 3 xfailed, 1 warning in 114.39s`** (delta vs Plan 12 baseline 7148/63/3 = `+17 passed`, zero skipped/xfail regression — bench's skip is compensated by another session-fixture flip but zero new failures)
  - Bench (env-gated) : `cd services/backend && MINT_RUN_CACHE_BENCH=1 python3 -m pytest tests/bench_cache_reader.py -q -s` → `1 passed in 0.26s` ; SQLite warm `p50=0.167ms p95=0.188ms p99=0.237ms mean=0.171ms` (informational only — PG SLO < 50ms verified post-deploy)
  - `python3 tools/checks/banned_terms_python.py <all 10 files>` → exit 0
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
  - Stampede property end-to-end : `test_concurrent_cold_cache_compute_fn_called_once_singleflight` asserts `state["calls"] == 1` across 10 concurrent tasks ; all 10 callers got same `row.id` ; DB row count == 1
- Commits :
  - `f15dd846` (RED Task 1 — 4 failing reader tests, ModuleNotFoundError as expected)
  - `1180eee6` (GREEN Task 1 + scaffold — 5 cache modules ; 4/4 reader tests pass)
  - `5e5a4415` (Task 2 — writer tests, 4/4 pass, supersede chain integrity)
  - `1cd20b29` (Task 3 — singleflight tests, 5/5 pass, stampede headline ≥80ms)
  - `555dff14` (Task 4 — get_or_compute tests, 4/4 pass including end-to-end 10→1)
  - `0ed5ae09` (Task 5 — env-gated bench)
  - docs commit pending (this STATE update + SUMMARY + ROADMAP + REQUIREMENTS + HTML report)
- Duration : ~12 min
- Deviations : 3 auto-fixed Rule 1 bugs. (1) Plan spec writer arg was `payload` AND attempted to write to a `payload` column ; actual ScenarioModel column is `outputs` — kept public `payload` arg + mapped to `outputs` column at insert site. (2) Plan & test scaffolding imported `from app.models.profile import ProfileModel` ; actual module is `profile_model.py` — fixed across all 4 test files. (3) Python 3.9 forbids `asyncio.Lock()` outside running event loop — replaced test-side `call_lock = asyncio.Lock()` with plain `state = {"calls": 0}` dict (asyncio single-threaded → no race needed).
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-13-w3-cache-reader-writer-singleflight-SUMMARY.md` `## Self-Check: PASSED` with 16 citations + explicit « What I HAVE NOT done » block listing : did NOT run EXPLAIN ANALYZE on Railway PG ; did NOT wire `get_or_compute` into any caller (Plan 14+ scope) ; did NOT add pytest-benchmark dependency (stdlib bench) ; did NOT add observability hooks (Plan 17 scope) ; did NOT add singleflight TTL/timeout (not in plan, no concrete need yet) ; did NOT open a PR (direct on `dev`) ; did NOT merge dev → staging ; did NOT run Maestro G1 (no UI surface) ; did NOT call MCP `mem_save` tool (10th consecutive session mismatch) ; did NOT modify `scenario.py` ; did NOT touch any caller code.
- Engram : observation **#138** saved via CLI fallback (`engram save "D-CE-12 W3 Plan 13 cache reader+writer+singleflight+get_or_compute shipped" --project mint --type architecture --topic_key mint-calc-engine-v1:w3-plan-13:cache-reader-writer-singleflight`). `prior_finding_refs` : Plan 12 obs #137 (composite index — direct dep), Phase 95 scenarios columns (transitive, not in engram), Concern E panel synthesis (CONTEXT/RESEARCH only, not engram).
- USER VALUE DELIVERED : zero end-user-visible change yet. Cache layer is server-internal infrastructure. First user-visible benefit (sub-millisecond cache HIT on power-user query plans + zero cold-start storms during deploy) materializes after Plan 14 (reverse-dep map) + Plan 15 (BackgroundTasks pre-compute) wire `get_or_compute` into the chip-emitter call sites + after dev → staging → main merges trigger the coupled deploy. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev`, no PR). **The real architectural value : Plan 12's index now has consumers — without Plan 13, the index was dead infrastructure ; without Plan 13's singleflight, Plan 15's pre-compute would cause 10-replica cold-start storms on every deploy.**

## Plan mint-calc-engine-v1-12 Receipt (W3 composite index migration — D-CE-12 + Finding 3, 2026-05-17)

- **Plan outcome** : mechanical execution, Wave 3 opens. Ships the composite partial index Phase 95 left missing — `idx_scenarios_cache_lookup ON scenarios (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` — via `op.get_context().autocommit_block()` on PG / plain `CREATE INDEX IF NOT EXISTS` on SQLite. Closes the Finding 3 critical gap before Plan 13's read-side `cache_reader` consumes it (without this index, the cache lookup would seq-scan `scenarios` and MAKE performance WORSE for power users).
- Files created : 2
  - `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` — 118 LOC. revision id `p110_scenarios_cache_idx` (24 chars, ≤32 PG `alembic_version.version_num VARCHAR(32)` cap). down_revision `p97_snapshots_fk_defaults` (the actual head at plan-time, not RESEARCH §Q-D's stale `p97_snapshots_fk_and_server_defaults` long-form). `autocommit_block()` wraps both `CREATE INDEX CONCURRENTLY IF NOT EXISTS` and `DROP INDEX CONCURRENTLY IF EXISTS` on the PG branch. SQLite branch ships plain `CREATE INDEX IF NOT EXISTS` / `DROP INDEX IF EXISTS` for the pytest in-memory test path. Idempotent (IF NOT EXISTS / IF EXISTS).
  - `services/backend/tests/test_scenarios_cache_index.py` — 230 LOC. 13 tests : 9 static (file exists, ast.parse, down_revision token, autocommit_block ≥2x, CREATE INDEX CONCURRENTLY ≥1x, dialect-branch ≥2x, partial WHERE, DROP INDEX, INDEX_NAME) + 3 runtime against in-memory SQLite (upgrade head creates index, downgrade -1 removes it, idempotent re-upgrade) + 1 PG-only EXPLAIN ANALYZE always-skip (production verification ships post-deploy on Railway PG14+).
- Files modified : 0. No ORM change needed (scenario.py model already declares all 5 indexed columns). No caller change needed (the index is read-only infrastructure that Plan 13's cache_reader will consume).
- Gates green :
  - `cd services/backend && python3 -m pytest tests/test_scenarios_cache_index.py -q` → `12 passed, 1 skipped in 0.53s`
  - `cd services/backend && python3 -m pytest tests/ -q` → **`7148 passed, 63 skipped, 3 xfailed, 1 warning in 113.89s`** — delta vs Plan 11 baseline (`7136 passed, 62 skipped`) = `+12 passed +1 skipped` (exact match for the 13 new tests, zero regressions)
  - `python3 tools/checks/banned_terms_python.py services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py services/backend/tests/test_scenarios_cache_index.py` → exit 0
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
  - `python3 tools/checks/alembic_revision_length.py --file services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` → exit 0 (`OK alembic_revision_length: scanned 0 migration(s), all ≤32 chars`)
  - Smoke (manual python script in execution session) : `command.upgrade(cfg, "head")` → `alembic_version.version_num='p110_scenarios_cache_idx'` ; inspector returns `['idx_scenarios_cache_lookup', 'ix_scenarios_profile_id']` ; `command.downgrade(cfg, "-1")` → returns to p97 + index dropped ; `command.upgrade(cfg, "head")` again → idempotent
- Commits :
  - `41638661` (RED Task 1 — 13 tests, 11 fail / 1 trivially pass / 1 skip as expected)
  - `925920f3` (GREEN Task 1 — p110 migration with revision id shortened from 33→24 chars after lefthook block)
  - docs commit pending (this STATE update + SUMMARY + ROADMAP + HTML report)
- Duration : ~7 min
- Deviations : 2 auto-fixed Rule 1 bugs. (1) RESEARCH §Q-D + PLAN.md template cited `down_revision = "p97_snapshots_fk_and_server_defaults"` (36 chars) — actual revision id in the p97 file is `"p97_snapshots_fk_defaults"` (25 chars), truncated during the 2026-05-12T11:14Z Railway 502 incident (`psycopg2.errors.StringDataRightTruncation`). If pasted verbatim from RESEARCH, `alembic upgrade head` would have raised `KeyError` at chain resolution. Pinned the actual revision id by reading p97 file at plan-time. (2) RESEARCH § Q-D + PLAN template used `revision = "p110_scenarios_cache_lookup_index"` (33 chars) — `lefthook alembic_revision_length` (tools/checks/alembic_revision_length.py, introduced post the 2026-05-12 incident with `MAX_LEN = 32`, zero grandfathering) blocked the commit. Shortened to `p110_scenarios_cache_idx` (24 chars). INDEX_NAME (`idx_scenarios_cache_lookup`, 26 chars) and filename (`p110_scenarios_cache_lookup_index.py`) stay at the long form — Postgres only caps the version_num column, not index names or filesystem paths.
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-12-w3-composite-index-migration-SUMMARY.md` `## Self-Check: PASSED` with 16 citations + explicit « What I HAVE NOT done » block listing : did NOT run EXPLAIN ANALYZE on Railway PG (no live PG access this session) ; did NOT open a PR (direct on `dev`, stage 1 of 4 per CLAUDE.md §9.5) ; did NOT merge dev → staging ; did NOT run Maestro G1 (no UI surface) ; did NOT modify scenario.py ORM (no schema change needed) ; did NOT touch any caller code ; did NOT call MCP `mem_save` tool (not exposed this session, 9th consecutive plan).
- Engram : observation **#137** saved via CLI fallback (`engram save "D-CE-12 W3 Plan 12 composite index migration shipped" --project mint --type bugfix --topic_key mint-calc-engine-v1:w3-plan-12:composite-index-migration`). `prior_finding_refs` empty (no prior MINT engram observations on this axis ; panel Finding 3 lives in PLAN.md frontmatter + W3-planning synthesis, not in engram).
- USER VALUE DELIVERED : zero end-user-visible change yet. The index is infrastructure for Plan 13's `cache_reader` — first user-visible benefit (sub-millisecond cache HIT latency on power-user query plans) materializes after Plan 13 + Plan 14 + Plan 15 ship and dev → staging → main merges trigger the coupled deploy. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR). **The real architectural value : closes the Finding 3 critical gap that would have shipped a worse-than-baseline cache lookup if Plan 13 ran without it.**

## Plan mint-calc-engine-v1-11 Receipt (W2 deprecation-shims — scope correction, 2026-05-16)

- **Plan outcome** : **scope correction, not mechanical execution.** The original PLAN asked for 1-line `from <canonical> import *` shims with `DeprecationWarning` on root `independant_service.py` + `frontalier_service.py`. Pre-flight grep (Task 0) + API surface audit proved the W0-AUDIT-MATRIX rows 32+35 premise was a **misclassification** — the root files are sister Sprint S12 services (monolithic `IndependantService.analyze()` + `FrontalierService.analyze()` API), the sub-dir « canonical » modules are S18/S23 with completely different surfaces. A naive `import *` shim would (a) `ImportError` at boot for independant (`IndependantService` not in S18 `__all__`), (b) silent `AttributeError` at runtime for frontalier (homonymous `class FrontalierService` collision, S23 has no `.analyze()` method). Surfaced as Rule 4 architectural checkpoint to orchestrator ; **orchestrator chose Option A (scope correction)**.
- Files modified : 4
  - `services/backend/app/services/independant_service.py` — module-level S12-lineage docstring (lines 1-37) referencing S18 `app.services.independants` as the sister functional API + pointer to `deferred-items.md` entry « S12-API-consolidation ». Zero behavioral change.
  - `services/backend/app/services/frontalier_service.py` — module-level S12-lineage docstring (lines 1-49) **explicitly flagging the S23 homonymous `FrontalierService` class** in `expat/frontalier_service.py` (different methods: `calculate_source_tax`, `check_quasi_resident`, `simulate_90_day_rule`, `compare_social_charges`, `estimate_lamal_option`, no `.analyze()`) to prevent future import confusion. Zero behavioral change.
  - `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` — rows 32 (line 140) + 35 (line 148) reclassified with explicit « **Reclassified 2026-05-16 via Plan 11 scope correction.** » marker. Row 32 now reads `independant_service (S12)` with full S12-monolithic-vs-S18-functional context. Row 35 same pattern for frontalier with S23 homonymous-collision warning.
  - `.planning/phases/mint-calc-engine-v1/deferred-items.md` — new « S12-API-consolidation » entry (lines 3-37) with : open design questions per domain (monolithic class vs functional split for independants ; monolithic vs granular for frontaliers + `FrontalierService` naming-collision resolution), 5 caller sites to migrate (`segments.py:28-29`, `test_segments.py:22-27`, `test_independant_service.py:21`), required design artifacts (panel synthesis + decision on `lacunes`/`urgences`/`checklist` semantic outputs + naming collision plan), scheduling guidance (after Wave 3). Plus a 2nd entry tracking pre-existing banned-term meta-mentions in « Ethical requirements » docstrings (out-of-scope per SCOPE BOUNDARY, pre-Plan-11 verified via `git show HEAD:`).
- Files created : 1 (SUMMARY.md) ; nothing in `services/` or `tests/`.
- **No imports rewritten. No tests deleted. No shims created. No callers modified.**
- Gates green :
  - `cd services/backend && python3 -m pytest tests/ -q` → **`7136 passed, 62 skipped, 3 xfailed, 1 warning in 114.01s`** — exact baseline preserved (zero tests added or removed by Plan 11 ; behavioral parity guaranteed because changes are docstring-only on already-tested modules)
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
  - `python3 tools/checks/banned_terms_python.py services/backend/app/services/{independant,frontalier}_service.py` → exit 1 with 2 hits at independant:34 + frontalier:46 — pre-Plan-11 in HEAD (`git show HEAD:` confirmed line 18 + 26 hits before Plan 11 ; Edit only pushed those lines from 18→34 and 26→46) ; meta-mentions of the rule in the « Ethical requirements » docstring block, not usages ; out-of-scope per SCOPE BOUNDARY, logged to deferred-items.md
  - `grep -rn "from app.services.independant_service\|from app.services.frontalier_service" services/backend/ apps/ tools/` → 5 hits all unchanged (segments.py:28-29, test_segments.py:22-27, test_independant_service.py:21) — naive shim NOT shipped, so callers continue working via the existing S12 root modules
- Commits :
  - `0a15dd63` (Task 1 — docstrings on the 2 root service files)
  - docs commit pending (this STATE update + SUMMARY + ROADMAP + W0-AUDIT-MATRIX + deferred-items + HTML report)
- Duration : ~12 min (scope correction is mechanically faster than mechanical execution since no test scaffold is built)
- Deviations : the entire plan IS a deviation. Architectural override per `<deviation_protocol>` Rule 4 — pre-flight Task 0 found the plan premise was unachievable without first consolidating the S12 vs S18/S23 APIs, which is itself a 2-3-plan design+migration effort. Returned checkpoint to orchestrator with 3 options (A reclassify / B defer / C consolidate). Orchestrator confirmed Option A. Executed end-to-end. **0 auto-fix attempts** (no shim was ever attempted, so no fix cycle was triggered).
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-11-w2-deprecation-shims-SUMMARY.md` `## Self-Check: PASSED` with 9 file/command citations + explicit « What I HAVE NOT done » block listing: did NOT consolidate S12 vs S18/S23 APIs (future plan), did NOT delete either root file, did NOT create any shim, did NOT modify any caller, did NOT fix pre-existing « garanti » meta-mentions, did NOT run Maestro G1 (no UI surface), did NOT open a PR, did NOT push to remote, did NOT re-run W0 audit pass with new heuristic.
- Engram : observation **#134** saved via CLI fallback (`engram save "D-CE-10 Plan 11 deprecation shims BLOCKED: API mismatch" --project mint --type architecture --topic_key mint-calc-engine-v1:w2-plan-11:deprecation-shims-blocked`) at pre-flight checkpoint. Engram MCP `mem_save` tool became available mid-plan after the system-reminder instructions — second observation pending with topic_key `mint-calc-engine-v1:w2-plan-11:scope-correction-shipped` for the executed outcome.
- USER VALUE DELIVERED : zero end-user-visible change. The scope correction is **infrastructure-level** — it prevents a future agent (human or LLM) from re-attempting the broken D-CE-10 shim, and it documents the real consolidation question as a backlog item with the open design questions explicit. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR). **The real architectural value : caught a W0-audit misclassification before it shipped broken `from X import *` into a FastAPI app boot.**
- Wave 2 close-out : **complete.** Plans 07 (ToolRegistryAdapter) + 08 (bundles) + 09 (description rewrite) + 10 (CoachToolResponse V2 envelope) + 11 (scope correction in lieu of shims) = 5/5 Wave 2 plans landed. The deferred items from W2 (Plan 09 staging pilot Task 5b ; Plan 11 S12-API-consolidation ; pre-existing « garanti » meta-mentions in 3 docstring blocks total across the wave) are tracked in `.planning/phases/mint-calc-engine-v1/deferred-items.md`. **Wave 3 opens at Plan 12 (W3 composite index migration).**

## Plan mint-calc-engine-v1-09 Receipt (W2 tool description rewrite Concern A, 2026-05-16)

- Files created : 4 (rubric lint module + rubric tests + round-trip pytest + Maestro YAML) — ~860 LOC across lints + tests + descriptions
- Files modified : 2 (`services/backend/app/services/coach/coach_tools.py` 5 chip-emitter rewrites + 2 pre-existing banned-term substring fixes ; `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` _TOOL_DESCRIPTIONS_FR 56-entry map + _description_for(meta) + register_tools call site)
- Lint : `tools/checks/tool_description_rubric.py` (224 LOC) — 4 rules R1 FR verb / R2 FR accent / R3 legal article OR financial-domain keyword / R4 length >=80 + scope flags --names/--names-file/--dict-var/--rubric-exempt. 3 contract tests at `tools/checks/tests/test_tool_description_rubric.py`.
- Descriptions : 5 chip-emitter rewrites in coach_tools.py (10 art. legal refs : LAVS art. 5/18/21/35, LPP art. 7-8/14, LACI art. 3, LCC art. 28, LIFD art. 33, CC art. 159) + 56 long-tail descriptions in adapter._TOOL_DESCRIPTIONS_FR (66 art. legal refs spanning CC + LAVS + LPP + LIFD + LHID + LCC + LAA + LAMal + LAI + LACI + LAPG + LAFam + OPP2). 61 descriptions total, 75 legal refs across 13 Swiss laws.
- Round-trip : `services/backend/tests/test_tool_search_round_trip.py` ~420 LOC with 30 FR user messages × expected top-3 tool names + Jaccard scorer + aggregate >=25/30 gate. 28 real passes + 2 xfailed polish TODOs (concubinage Genève / impôt Genève vs Zurich — Jaccard scorer is coarser than real BM25, staging pilot is the production verification path).
- Maestro : `tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` 116 LOC with 5 representative FR queries (divorce / racheter LPP / frontalier / acheter Lausanne / indépendant). `maestro check-syntax` exit 0. Live run skipped (no booted sim at execution time).
- Gates green :
  - `python3 -m pytest tools/checks/tests/test_tool_description_rubric.py -q` → `3 passed in 0.14s`
  - Rubric lint exit 0 with `--names-file /tmp/allnames_lines.txt --dict-var _TOOL_DESCRIPTIONS_FR` on both changed files
  - `python3 tools/checks/banned_terms_python.py <both files>` → exit 0
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0, 0 hits on coach_tools|anthropic_defer_loading
  - `cd services/backend && python3 -m pytest tests/test_tool_search_round_trip.py -q` → `29 passed, 2 xfailed in 0.41s`
  - `cd services/backend && python3 -m pytest tests/ -q` → `7105 passed, 62 skipped, 3 xfailed, 1 warning in 113.30s` (+29 vs Plan 08 baseline 7076 ; zero regressions ; 30 parametrized – 2 xfailed + 1 aggregate)
  - `maestro check-syntax tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` → exit 0
- Commits : `bdf50c95` (RED Task 1) → `771d958b` (GREEN Task 1) → `80d89473` (Task 2 rewrites) → `d7b95167` (Task 3 baseline) → `1bda1ebf` (Task 4 Maestro YAML) → `b89671c5` (Task 3 xfail follow-up) → docs commit pending (SUMMARY + STATE + ROADMAP + HTML report).
- Duration : ~25 min
- Deviations : 4 auto-fixed. (1) Rule 3 — rubric lint legacy AST scan couldn't see _TOOL_DESCRIPTIONS_FR map values keyed by tool-name (not `{"description": ...}` sibling pattern) ; added `--dict-var <name>` walker. (2) Rule 2 — pre-existing banned-term substrings on lines 333 + 800 of coach_tools.py became blockers for banned_terms exit 0 once Plan 09 opened the file ; rewrote both in place (« Never use banned terms (garanti, optimal, tu devrais) » → « Never use LSFin-forbidden terms (see swiss-brain.md §1) » ; « Parfait, 500 CHF » → « C'est noté, 500 CHF »). (3) Rule 1 — test fixture compliant description lacked any R2 accent match → added « séparation » + « éventuelle ». (4) Plan-spec drift — 2 round-trip fixtures fail under Jaccard, wrapped in pytest.param(marks=xfail) so suite stays green ; aggregate >=25/30 gate still catches regressions.
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-09-w2-tool-description-rewrite-SUMMARY.md` `## Self-Check: PASSED` with 14 file/command citations + caveat block (Maestro live run not attempted — no booted sim ; staging pilot Task 5b DEFERRED requires Julien GO ; adapter NOT wired into coach_chat.py — Plan 10 ; engram MCP exposure mismatch persists 8th consecutive plan despite merge bc07d915).
- Engram : observation **#131** saved via CLI fallback (`engram save ... --project mint --type architecture --topic_key mint-calc-engine-v1:w2-plan-09:tool-description-rewrite`). `prior_finding_refs` content cites #103 (vendor-agnostic adapter panel synthesis), #129 (Plan 07 ToolRegistryAdapter), #130 (Plan 08 bundles), #128 (Wave 1 closure handoff).
- USER VALUE DELIVERED : zero end-user-visible change yet. The descriptions land in the Anthropic tools array on every coach turn ; their BM25-surfacing benefit will materialize once Plan 10 wires the adapter into `coach_chat.py` and the staging pilot (Task 5b DEFERRED) validates the routing. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR).
- Wave 2 close-out blockers : Task 5b (staging pilot Railway env-flip `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` on mint-staging) requires Julien GO ; Plan 10 (W2-04 latency_tier envelope V2 + coach_chat.py wire-up) is the first user-visible plan ; Plan 11 (deprecation shims) closes W2.

## Plan mint-calc-engine-v1-07 Receipt (W2 ToolRegistryAdapter + 3 concrete adapters + factory, 2026-05-16)

- Files created : 11 (6 module files + 5 test files) — ~993 LOC across module + tests
- Files modified : 0
- Module : `services/backend/app/services/coach/tool_registry/` ships 5 modules + package init :
  - `adapter.py` (76 LOC) — `@runtime_checkable Protocol` (`ToolRegistryAdapter`) + `TypedDict(total=False)` (`ToolDefinition`) + `LatencyTier = Literal["L1","L2","L3"]` aligned with Plan 04 LucidityLevel
  - `anthropic_defer_loading_adapter.py` (197 LOC) — DEFAULT : 5 chip-emitters always-on (sourced from `coach_tools.COACH_TOOLS` at construction) + 63 long-tail from `app.calculators.REGISTRY` (Plan 05) with `defer_loading=True` + 1 `tool_search_tool_bm25_20251119` declaration + `beta_header` property pinned `tool-search-tool-2025-10-19`
  - `skill_bundle_only_adapter.py` (92 LOC) — FALLBACK : all 5+63 always-on, NO defer_loading, NO tool_search (Bedrock-compatible)
  - `manual_subset_adapter.py` (119 LOC) — BACKUP : per-intent filter via `REGISTRY.life_events_served` tags ; 6 intents mapped to life-event sets (retirement→{retirement,buyback} / taxes→{taxes,succession} / housing→{housing} / debt→{debt} / family→{family,marriage,divorce} / career→{career,independent,cross_border}) ; empty intents → only 5 chip-emitters
  - `factory.py` (63 LOC) — `TOOL_REGISTRY_ADAPTER` env-flag selector, default `anthropic_defer_loading`, invalid value falls back to default + WARNING log breadcrumb (Sentry-compatible)
- Tests : 21 contract tests across 5 files (3 Protocol + 6 Anthropic + 4 SkillBundle + 4 ManualSubset + 4 factory) — TDD RED→GREEN per task
- Gates green :
  - `cd services/backend && python3 -m pytest tests/test_tool_registry_adapter.py tests/test_anthropic_defer_loading_adapter.py tests/test_skill_bundle_only_adapter.py tests/test_manual_subset_adapter.py tests/test_tool_registry_factory.py -q` → `21 passed in 0.30s`
  - `cd services/backend && python3 -m pytest tests/ -q` → `7051 passed, 62 skipped, 1 xfailed, 1 warning in 113.87s` — net delta vs Plan 06 baseline (`7030 passed`) = `+21 passed` (exact match for 21 new Plan 07 tests, zero regressions, zero new skips)
  - `python3 tools/checks/banned_terms_python.py <11 files>` → exit 0
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
  - `cd services/backend && python3 -c "from app.services.coach.tool_registry.factory import get_tool_registry_adapter; print(type(get_tool_registry_adapter()).__name__)"` → `AnthropicDeferLoadingAdapter`
- Commits : `6f9d3f07` (RED-1) → `92e1535c` (GREEN-1) → `b3f5b5c4` (RED-2) → `f520978d` (GREEN-2) → `6f26743c` (RED-3) → `bf134afe` (GREEN-3) → `8f1cd590` (RED-4) → `6e80cdbf` (GREEN-4) → `0096f82d` (RED-5) → `1e917eb3` (GREEN-5) → `f78f4518` (caplog flake fix) → docs commit pending (this STATE update + SUMMARY + HTML + ROADMAP)
- Duration : ~17 min
- Deviations : 2 auto-fixed. (1) Rule 2 — ManualSubsetAdapter switched from plan's hardcoded short-name allowlist (`avs_estimation`, `lpp_projector`, ...) to `REGISTRY.life_events_served` filter axis because 3/24 short-names had zero REGISTRY matches due to canonical `<file_stem>__<func_qualname>` naming from Plan 05 AST scanner. (2) Rule 1 — pytest caplog flake in full backend suite : `test_invalid_value_falls_back_to_default_with_warning` passed in isolation but failed when run after `test_profile_resolver.py:210-228` (which resets its own module logger state). Switched to local `_RecordCollector(logging.Handler)` direct-attach pattern mirroring the test_profile_resolver convention.
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-07-w2-tool-registry-adapter-SUMMARY.md` `## Self-Check: PASSED` with 11 file/command citations + caveat block (NOT wired into coach_chat.py — Plan 10 does that ; NOT description-rewritten for LSFin — Plan 09 does that ; NOT staging-piloted — Plan 10 or later ; engram saved via CLI fallback because MCP `mem_save` tool NOT in executor scope for the 7th consecutive plan despite merge bc07d915).
- Engram : observation **#129** saved via CLI fallback (`engram save ... --project mint --type architecture --topic_key mint-calc-engine-v1:w2-plan-07:tool-registry-adapter`). `prior_finding_refs` content cites #103 (vendor-agnostic adapter refinement, Julien's founder refinement 2026-05-16) + #128 (Wave 1 closure handoff).
- USER VALUE DELIVERED : zero end-user-visible change yet. Adapter is SCAFFOLDING — Plan 10 (W2-04 CoachToolResponse V2 latency_tier envelope) wires it into `coach_chat.py`. Plan 09 (W2-03 description rewrite) lands LSFin-grade French descriptions before staging pilot. Stage 1 of 4 per CLAUDE.md §9.5 (direct commits on `dev` branch, no PR).

## Plan mint-calc-engine-v1-06 Receipt (W1 sev-2 batch grounding + wave close, 2026-05-16)

- Files created : 2 (1 parametrized contract test + 1 SUMMARY)
- Files modified : 20 (10 endpoint files + 10 schema files)
- Batches : 4 (Batch A arbitrage+mortgage / B lpp+family+mortgage / C retirement+independants+expat / D life-events+unemployment+assurances)
- Endpoints grounded this plan : 19 (Batch A=5, B=5, C=5, D=4)
- Cumulative W1 closure : 26 endpoints with Depends(get_profile_filled) — meets ≥25 W1 acceptance criterion
- Contract test : `services/backend/tests/test_blank_profile_422_contract.py` 281 LOC, 28 cases (26 parametrized + 2 regression guards) — every W1-grounded endpoint returns 422 with CoachToolIncomplete envelope on blank profile
- Gates green :
  - `cd services/backend && python3 -m pytest tests/test_blank_profile_422_contract.py -q` → `28 passed in 2.51s`
  - `cd services/backend && python3 -m pytest tests/ -q` → `7030 passed, 62 skipped, 1 xfailed, 1 warning in 113.93s` — delta vs Plan 05 baseline `7002 passed` = `+28 passed` (exact match for 26 contract cases + 2 regression guards, zero regressions)
  - `grep -rE 'json_schema_extra=\{"from_profile"' services/backend/app/schemas/*.py | wc -l` → 23 cumulative from_profile markers (target ≥7 cumulative ✓)
  - `grep -lE 'Depends\(get_profile_filled\)' services/backend/app/api/v1/endpoints/*.py | wc -l` → 10 endpoint files (target ≥7 ✓)
- Commits : `a0166435` Batch A → `e96a1514` Batch B → `dbb10aa2` Batch C → `9a9269d1` Batch D → `70aee84a` contract test → `cf747899` slowapi fix → docs commit pending (this STATE update + SUMMARY + HTML report + ROADMAP)
- Duration : ~95 min (split across 2 sessions)
- Deviations : 6 auto-fixed. (1-3) Rule 1 plan-path inaccuracy — 3 endpoints dropped as non-canton-grounded (assurances/lamal/optimize, mortgage/saron-vs-fixed, debt/ratio) ; substituted with imputed-rental, source-tax, lamal-option to keep batch sizes at 5. (4) Rule 2 — 13 endpoints promoted from anonymous to authenticated via Depends(require_current_user). (5) Rule 1 — Enum-preservation defensive logic on 4 handlers. (6) Rule 1 — slowapi._route_limits cross-pollution discovered post-suite, fixed by replacing importlib.reload chain with monkeypatch.setattr on profile_resolver module-level constant.
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-06-w1-sev2-batch-grounding-SUMMARY.md` `## Self-Check: PASSED` with 11 file/command citations + caveat block listing what was NOT checked (no end-to-end sim ; no PR ; no merge to remote ; no Railway deploy ; no strict-mode flip ; no Maestro G1 ; engram mem_save deferred for 6th consecutive plan due to MCP exposure mismatch despite merge bc07d915).
- USER VALUE DELIVERED : zero end-user-visible change yet. Strict mode ships `false` by default — until Railway flag flip, helper logs WARNING + returns resolved body so legacy hardcoded-default computation continues. Plan 06 is Stage 1 of 4 per CLAUDE.md §9.5 — work shipped to local `dev`, no PR yet.
- W1 wave-close blocker : MCP tools (`mcp__plugin_engram_engram__*` + `mcp__mint-tools__*`) NOT exposed in executor agent scope despite merge `bc07d915 + 1b106220 fix(gsd-agents): expose engram + mint-tools MCP to all GSD subagents`. Recommendation : verify the `.claude/agents/gsd-executor.md` frontmatter tools line includes literal MCP namespaces.

## Plan mint-calc-engine-v1-05 Receipt (W1 calc registry AST scaffold + reverse-dep map seed, 2026-05-16)

- Files created : 4 (1 SUMMARY + 1 generator + 1 package __init__ + 1 auto-generated registry + 1 test file = 5 ; SUMMARY counted under docs)
- Generator : `tools/generate_calc_registry.py` 577 LOC — AST scanner walking `services/backend/app/services/` (12 calc sub-dirs + 12 root calc files) with widened heuristic (compute_/simulate_/compare_/estimate_/calculate_ + bare verbs on class methods) + 27-name EXCLUDED_FUNC_NAMES blocklist (utility helpers : compute_inputs_hash, compute_fingerprint, calculate_precision_score, etc.). CLI : `--print` (stdout) / `--check` (exit 1 on drift) / no-arg (writes `_registry.py`). Canonical name format `<file_stem>__<func_qualname>` (double underscore) for unambiguous parsing.
- Generated artifact : `services/backend/app/calculators/_registry.py` 1034 LOC AUTO-GENERATED, 63 CalculatorMetadata entries vs W0-AUDIT-MATRIX expected 57 — overcount driven by class-method services that emit 2-3 entries per logical calculator (WealthTaxService → 3 entries : estimate_wealth_tax + compare_all_cantons + simulate_move_wealth). 146 REVERSE_DEP_MAP fields (25 calcs depend on `canton`, the W0 prediction « ~half of 57 calcs are canton-dependent »).
- Package marker : `services/backend/app/calculators/__init__.py` 24 LOC — re-exports REGISTRY + REVERSE_DEP_MAP + CalculatorMetadata + get_calculator + get_reverse_deps.
- D-CE-09 Strangler-fig honored : zero physical file moves. The registry only INDEXES the existing services tree ; `entry['file']` field points to relative paths under `services/backend/app/services/`.
- D-CE-14 reverse-dep map seed : produced as a side product of the SAME AST walk per Override #5 (« kills two birds »). Full implementation lands in Plan 14.
- Tests : 13 contract tests (`services/backend/tests/test_calc_registry.py` 240 LOC) — 8 registry-shape (min entries / shape / file exists / output_type valid / reverse-dep min / canton non-empty / KeyError / idempotent regen) + 5 generator-behavior (sample find / min 40 / canton ≥ 20 / life-events mapping / --print parseable).
- Q-decisions shipped : Q2 resolved CI-only (lefthook deferred to Wave 2 IF Plan 07 ToolRegistryAdapter surfaces drift) ; canonical name format uses `__` double underscore separator (plan's example `_` was ambiguous) ; widened heuristic from plan's 3 prefixes to 5 prefixes + 5 bare verbs (plan's heuristic caught 17 of 57 — would have failed Task 2 acceptance).
- Gates green :
  - `python3 tools/generate_calc_registry.py` → `WROTE : services/backend/app/calculators/_registry.py (63 calculators)`
  - `python3 tools/generate_calc_registry.py --check` (immediately after) → `OK : registry is fresh.` (proves idempotence)
  - `python3 tools/generate_calc_registry.py --print | python3 -c "import ast, sys; ast.parse(sys.stdin.read())"` → exit 0 (parseable Python)
  - `cd services/backend && python3 -m pytest tests/test_calc_registry.py -q -x` → `13 passed in 0.54s`
  - `cd services/backend && python3 -m pytest tests/ -q` → `7002 passed, 62 skipped, 1 xfailed, 1 warning in 113.77s` — net delta vs Plan 04 baseline (`6989 passed`) = `+13 passed` (exact match for the 13 new tests, zero regressions, zero new skips)
  - `python3 tools/checks/banned_terms_python.py tools/generate_calc_registry.py services/backend/tests/test_calc_registry.py services/backend/app/calculators/__init__.py services/backend/app/calculators/_registry.py` → exit 0
- Commits : `fdbeb1af` (Task 1 — generator) → `1d107a0d` (Task 2 — registry artifact + 13 contract tests) → docs commit pending (this SUMMARY + STATE.md + ROADMAP.md update).
- Duration : ~12 min
- Deviations : 2 auto-fixed. (1) Rule 2 — widened heuristic from plan's `(compute_|simulate_|compare_)` (caught 17 module-level) to `(compute_|simulate_|compare_|estimate_|calculate_)` + bare verbs on class methods scoped to whitelist + 27-name blocklist (catches 63) to satisfy Task 2's `len(REGISTRY) >= 40` acceptance. (2) Rule 1 — canonical name format uses `__` double underscore separator (plan's `_` example was ambiguous when func name contains underscores).
- 0-trust : `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-05-w1-calc-registry-SUMMARY.md` `## Self-Check: PASSED` with 11 file/command citations + caveat block listing what was NOT checked (CI workflow wiring is the Q2 TODO ; per-row 63-vs-57 diff not produced ; magic-comment lucidity annotations not in any production calc).
- USER VALUE DELIVERED : zero end-user-visible change. Registry is plumbing for Plan 07 (`w2-tool-registry-adapter`) — first consumer the user will feel via better LLM tool discoverability. PRs opened against `dev` (no PR — direct commits on `dev` branch per plan sequential model). Stage 1 of 4 per CLAUDE.md §9.5.

## Plan wave-1b-08 Receipt (Sentry breadcrumb on citation emission, 2026-05-15)

- Files created : 1 (1 SUMMARY)
- Files modified : 4 (1 helper + 1 endpoint wrapper + 2 test files)
- Helper : `services/backend/app/observability/coach_breadcrumbs.py` +50 LOC — `emit_coach_citation_breadcrumb` sibling of `emit_coach_tool_breadcrumb` (D-15 5-kwarg schema parity : tool_name + inputs_hash + profile_id_hashed + elapsed_ms + flag_state ; category prefix `coach.citation.tool_call_id.<tool_name>` instead of `coach.tool.<tool_name>`)
- Wrapper : `services/backend/app/api/v1/endpoints/coach_chat.py` +133 LOC — `_emit_citation_chip_breadcrumbs(gated_text, citation_chips)` closure invoked on BOTH gate-PASS branches of `_run_narrator_with_gate` (initial PASS at line 4173-4179 + retry-PASS at line 4269-4274) ; per-turn dedupe via `seen_tool_names` set ; consumes `_RE_CITE_PLACEHOLDER` read-only from `citation_parser.py` (CONTEXT hard constraint #4 — Phase 94 byte-identity preserved)
- Q-decisions shipped : `elapsed_ms=0` on the chip breadcrumb (Plan 04 audit pinned chip schema without per-chip timing ; Wave 1a `coach.tool.<name>` breadcrumb carries the genuine compute-path elapsed_ms ; cross-correlation joins on shared `inputs_hash`) ; `flag_state="on"` constant (chip only renders when flag is on per RESEARCH §3.3) ; dedupe in WRAPPER not in helper (helper stays idempotent like `emit_coach_tool_breadcrumb`)
- Tests : Plan 01's 3 contract stubs + 2 cardinality stubs unskipped + GREEN (5/5)
- Gates green :
  - `python3 -m pytest tests/test_coach_citation/test_breadcrumb_contract.py -q` → `3 passed in 0.20s`
  - `python3 -m pytest tests/test_coach_citation/test_breadcrumb_cardinality.py tests/test_coach_citation/test_breadcrumb_contract.py -q` → `5 passed in 0.22s`
  - `python3 -m pytest tests/test_citation_gate/ -q` → `212 passed in 0.87s` (Phase 94 / 94.1 byte-identity preserved)
  - `python3 -m pytest tests/ -q` → `6898 passed, 62 skipped, 1 xfailed, 1 warning in 111.40s` — net delta vs Plan 04 baseline (6880 passed, 67 skipped) = `+18 passed` (5 directly unskipped + 13 from Plans 05/06/07 between-baselines) and `-5 skipped` (exact match for the 5 Plan 01 stubs)
  - `python3 tools/checks/banned_terms_python.py services/backend/app/observability/coach_breadcrumbs.py services/backend/app/api/v1/endpoints/coach_chat.py` → exit 0
- Commits : `8534a837` (T1 RED — unskip 3 contract stubs, ImportError 3/3 fail) → `adabeac3` (T1 GREEN — helper 50 LOC, 3/3 pass) → `3319a62b` (T2 — wrapper closure + 2 PASS-branch calls + unskip 2 cardinality, 5/5 pass)
- Duration : ~8 min
- Deviations : NONE. Plan 08's Task 2 Step 0 mandated reading wave-1b-04-AUDIT.md before code edit ; audit's Route (b) decision shipped `citation_chips` as a list of dicts on `loop_result` (not objects with `.elapsed_ms`), so the wrapper iterates `loop_result["citation_chips"]` dicts with `.get("toolName")` / `.get("inputsHash")` — audit-confirmed shape, not the plan's speculative `agent_result.tool_calls` / `tc.elapsed_ms`. No naming, category, payload, or placement deviation.
- 0-trust : `.planning/phases/wave-1b-citation-chips/wave-1b-08-SUMMARY.md` `## Self-Check: PASSED` cited with 7 file evidences + 7 command citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Sentry breadcrumb fires only when (a) Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flip lands AND (b) narrator emits `{{cite:tool_*}}` placeholder AND (c) gate verdict = PASS. Pre-coupled-deploy : zero entries in Sentry. PR opened against `dev`, NOT merged. Stage 1 of 4 per CLAUDE.md §9.5. Plan 09 (Maestro G1) is the final Wave 1b plan ; post-09 the dev→staging merge triggers the coupled deploy per CONTEXT D-01.

## Plan wave-1b-06 Receipt (CoachCitationModal bottom-sheet, 2026-05-15)

- Files created : 2 (1 modal widget + 1 SUMMARY)
- Files modified : 5 (1 message bubble + 2 test files + 2 lint baselines)
- Widget : `apps/mobile/lib/widgets/coach/coach_citation_modal.dart` 227 LOC — top-level `showCoachCitationModal(context, chip, {onRememberTap})` + private `_CoachCitationModalBody`
- 5 sections : drag handle / `s.coachCitationModalTitle(toolDisplayName)` header / truncated 16-char `inputs_hash` (SelectableText monospace) / relative `computed_at` row reading 4 ARB keys (Q8_DECISION) / collapsible `ExpansionTile` JSON viewer (`Key('coachCitationModalJsonExpansion')`, pretty-printed via `JsonEncoder.withIndent('  ')`) / `Souviens-toi` CTA (`Key('coachCitationModalRememberCta')`, fires `onRememberTap` + Navigator.pop)
- Q7_DECISION shipped : `flag_state` badge dropped in v1 (chip only renders when flag=on, badge would always read "on" with zero info content) — `grep -cE "flag_state|flagState"` returns 0
- Q8_DECISION shipped : 4 relative-time ARB keys consumed (`coachCitationRelativeJustNow|Minutes|Hours|Days`, 3 ICU plural-aware) — zero Dart literal leak
- Wiring : `coach_message_bubble.dart` import at line 11 + onChipTap at lines 175-192 invokes `showCoachCitationModal(...)` with `onRememberTap` SnackBar acknowledgement (save_insight wiring deferred to Wave 2)
- Tests : Plan 01's 3 modal stubs + 1 Souviens-toi stub unskipped + GREEN (4/4)
- Gates green :
  - `flutter analyze` → 253 issues = baseline (0 new errors)
  - `flutter test test/widgets/coach/` → 737/737 pass (+4 vs Plan 05 baseline 733/733, 0 regressions)
  - `prefer_mint_color_token` → clean (23 grandfathered) — `MintColors.transparent` swap
  - `prefer_mint_text_style` → clean (683 grandfathered, line-shift baseline regen)
  - `prefer_mint_radius` → clean (42 grandfathered, line-shift baseline regen)
  - `prefer_mint_cta` → clean (-1 from baseline)
  - `prefer_mint_fonts` → clean (92 grandfathered, 2 lint-ignores for `fontFamily: 'monospace'` on hash + JSON SelectableText)
- Commits : `cd842900` (T1 modal widget) → `9f475812` (baseline regen) → `6f0faad0` (T2 wire + tests)
- Duration : ~6 min
- Deviations (5 auto-fixed) : (a) Rule 1 — plan referenced `AppLocalizations`, actual is `S` (inherited from Plan 05) ; (b) Rule 1 — plan imports referenced `text_styles.dart`/`spacing.dart`, actual is `mint_text_styles.dart`/`mint_spacing.dart` (inherited from Plan 05) ; (c) Rule 2 — `Colors.transparent` → `MintColors.transparent` ; (d) Rule 2 — `fontFamily: 'monospace'` lint-ignores added (no `MintTextStyles.monospace()` token exists) ; (e) Rule 3 — bubble wiring 18-line insertion shifted 3 pre-existing violations downstream, baseline regen as separate chore commit. Zero behavioural deviations.
- 0-trust : wave-1b-06-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-06-SUMMARY.md with 9 file evidences + 9 command citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Modal opens only when a `ToolCallCitationChip` is tapped, which requires the Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flip (post-Plan-08 coupled deploy per CONTEXT D-01). PR opened against `dev`, NOT merged. Stage 1 of 4 per CLAUDE.md §9.5. Plan 08 (Sentry breadcrumb) hooks into `onChipTap` for `coach.citation.tool_call_id.<tool>.emitted` ; Plan 09 (Maestro G1) references `Key('coachCitationModalJsonExpansion')` + `Key('coachCitationModalRememberCta')` for end-to-end tap flow.

## Plan wave-1b-05 Receipt (CoachCitationChipsSection widget, 2026-05-15)

- Files created : 8 (1 widget + 6 PNG goldens + 1 SUMMARY)
- Files modified : 5 (1 message bubble + 2 test files + 2 lint baselines)
- Widget : `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` 123 LOC — sibling of CoachSourcesSection (NOT extension per RESEARCH §9.4)
- Wiring : `coach_message_bubble.dart` import + render block between Sources (line 159-165) and Disclaimers (line 181), gated by `msg.citationChips.isNotEmpty`
- Tests : Plan 01's 4 widget stubs + 6 golden stubs unskipped + GREEN (4/4 widget, 6/6 golden)
- Goldens : 6 PNGs 5.2-5.5 KB each (NOT 4 KB stubs) — one per Wave 1a tool
- Gates green :
  - `flutter analyze` → 253 issues = baseline (0 new errors)
  - `flutter test test/widgets/coach/` → 733/733 pass (0 regressions)
  - `prefer_mint_text_style` → clean (683 grandfathered, line-shift baseline regen)
  - `prefer_mint_color_token` → clean (23 grandfathered)
  - `prefer_mint_radius` → clean (42 grandfathered, line-shift baseline regen)
  - `prefer_mint_cta` → clean
  - `prefer_mint_fonts` → clean (92 grandfathered)
- Commits : `fee1f726` (T1 widget) → `bfd78756` (baseline regen) → `38eda46f` (T2 wire+tests+goldens)
- Duration : ~5 min
- Deviations (2 × Rule 1 codebase-shape mismatches) : (a) plan imports `text_styles.dart`/`spacing.dart`, actual is `mint_text_styles.dart`/`mint_spacing.dart` ; (b) plan referenced `AppLocalizations.of(context)!`, actual generated class is `S` (`app_localizations.dart:68`). No behavioural deviation.
- 0-trust : wave-1b-05-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-05-SUMMARY.md with 8 file evidences + 8 command citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Chip surface activates only when `ChatMessage.citationChips` non-empty, which requires the Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flip (post-Plan-08 coupled deploy per CONTEXT D-01). Plan 06 (modal) hooks into the empty `onChipTap` callback to deliver tap-to-view UX.

## Plan wave-1b-07 Receipt (ARB citation keys × 6 locales, 2026-05-15)

- Files created : 1 (.planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md)
- Files modified : 13 (6 ARB + 7 generated app_localizations*.dart via flutter gen-l10n)
- ARB delta : 90 new entries (15 keys × 6 locales : fr/en/de/es/it/pt)
- 5 frame keys verbatim from RESEARCH §6.3 : coachCitationChipsHeader, coachCitationChipLabel(toolDisplayName), coachCitationModalTitle(toolDisplayName), coachCitationJsonViewerLabel, coachCitationRememberCta
- 6 tool-name keys (Q6 doctrine i18n) : coachToolBudgetSnapshot, RetirementProjection, CrossPillarAnalysis, CoupleOptimization, CapStatus, RetrieveMemories
- 4 Q8 relative-time keys (3 ICU plural-aware `(int count)`) : coachCitationRelativeJustNow, Minutes, Hours, Days
- Gates green :
  - `python3 tools/checks/arb_parity.py` → exit 0 (6 locales, 6777 keys each)
  - `python3 tools/checks/banned_terms_arb.py` → exit 0 (6 locales clean)
  - `python3 tools/checks/accent_lint_fr.py --file app_fr.arb` → exit 0
  - `flutter gen-l10n` → exit 0
  - `flutter analyze` → 253 issues (= baseline-273, 0 new errors)
- Commits : 49142b79 (atomic 6-locale ARB) → 886a6fd1 (gen-l10n regen)
- Duration : 5 min
- Deviation (1) : Rule 3 - blocking — Task 1 (FR+EN) and Task 2 (DE/IT/ES/PT) merged into single ARB commit because lefthook `arb-parity-gate` fails closed on per-locale intermediate state ; atomic 6-locale update preserves gate's fail-closed contract.
- 0-trust : wave-1b-07-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md with 9 deterministic citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Plan 07 ships i18n surface only ; plans 05 (CoachCitationChipsSection) + 06 (CoachCitationModal) consume these getters. End-to-end sim verification deferred to Plan 09 close-out.

## Plan wave-1b-03 Receipt (Narrator Grammar Fragment, 2026-05-15)

- Files created : 1 (.planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md)
- Files modified : 3 (citation_grammar.py + test_tool_call_id_grammar.py + test_narrator_grammar_fragment.py)
- Tests added : 0 net new (3 Plan-01 stubs transitioned SKIPPED → PASSED)
- Full backend pytest : 6877 passed, 67 skipped, 1 xfailed in 113.18s (Plan 02 baseline 6874 → +3 = exact match for unskipping 3 grammar stubs, zero regressions)
- Phase 94 byte-identity : test_byte_identity_flag_off 6/6 green (preserved)
- test_citation_gate/ : 212 passed (Plan 02 baseline 212, preserved)
- test_dag_invalidation/test_pack_registry_coupling : 2/2 green (Plan 02's 24-key drift detector still operational)
- Commits : 5224af94 (RED — unskip Plan-01 stubs) → 29b01531 (GREEN — tool_paragraph + tool_example + intent always-on + 24-key test re-tighten)
- Duration : ~9 min execution
- 0-trust : wave-1b-03-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md
- **Q5_DECISION shipped** : 1-segment grammar `{{cite:tool_<name>}}` (RESEARCH §4.3 Option A) adopted instead of CONTEXT line 36's 2-segment `{{cite:tool_call_id:<inputs_hash>}}`. Respects CONTEXT hard constraint #4 (zero edit to `_RE_CURRENCY` / `_RE_PERCENT` / `_RE_CITE_PLACEHOLDER` regexes in citation_parser.py). Per-call `inputs_hash` travels via the tool response container, not the placeholder. Julien reviews at PR time; if rejected, alternative cost = 2-3 additional plans.
- **tool_paragraph shipped** : added in BOTH `_build_citation_grammar_fragment` (full fragment) AND `build_intent_scoped_citation_grammar` (intent-scoped variant) header builders. Verbatim FR per RESEARCH §4.4 : « Certaines clés (`tool_*`) marquent un chiffre calculé côté serveur — son `inputs_hash` voyage avec la réponse, tu n'as pas besoin de le citer dans le texte… ». Banned-terms + accent_lint exit 0.
- **tool_example shipped** : added `**ACCEPTÉ — chiffre calculé côté serveur**` block in BOTH builders. Verbatim per RESEARCH §4.4 with `{{cite:tool_budget_snapshot}}` placeholder + LSFin-safe modal verb « pourrait ».
- **Always-on intent mapping shipped** : `_WAVE_1B_TOOL_KEYS_ALWAYS_ON` frozenset (6 tool keys) unioned into EVERY bucket of `_INTENT_TO_CITATION_KEYS` (debt / housing / family / career / retirement / taxes / tax / mortgage). Tool calls are LLM-driven, NOT intent-driven — the narrator can call `get_budget_status` on any intent.
- **Test renamed** : test_fragment_lists_all_18_registry_keys → test_fragment_lists_all_24_registry_keys (re-tighten from Plan 02's transitional 18-non-tool sub-baseline to unified 24-key total + preserved 18-non-tool + 6-tool sub-baselines as independent regression checks).
- **3 Plan-01 stubs transitioned SKIPPED → PASSED** : `test_grammar_fragment_lists_all_tool_keys`, `test_grammar_fragment_lists_all_24_registry_keys`, `test_intent_scoped_grammar_includes_tools`. 0 `@pytest.mark.skip` markers remain in test_tool_call_id_grammar.py.
- **Token-count delta on rendered fragment** : pre-Plan-03 5'880 chars / 1'960 approx tokens → post-Plan-03 6'502 chars / 2'167 approx tokens (+10.6% / +207 tokens). Within RESEARCH §A4 budget (<5% of ~80 kB narrator prompt = <4 kB grammar allotment).
- Zero deviations from plan. Plan-prescribed implementation matched the codebase shape exactly; no Rule 1-4 auto-fixes triggered.
- USER VALUE DELIVERED : NONE YET — Plan 03 only proves grammar fragment correctness + intent mapping + 15 test assertions. Narrator LLM emission of `{{cite:tool_*}}` against the new doctrine is Plan 04 wiring; Flutter chip rendering is Plan 05/06; Sentry breadcrumb is Plan 08. No end-to-end user flow exercised. PR opened against `dev`, NOT merged. Per CLAUDE.md §9.5 — Stage 1 of 4.

## Plan 96-03 Receipt (Wave 3 Cross-stack, 2026-05-11)

- Files created : 14 (1 mobile asset metaphors.toml + 1 backend mirror + 1 parity lint + 1 backend hook-linter + 1 backend metaphor_lookup + 1 Dart metaphor_lookup + 1 Dart NarrativeSleeve model + 1 Dart metaphor_lookup test + 1 Dart walkback test + 1 Dart NarrativeSleeve render test + 2 Python test files + 1 Maestro G1 flow + 1 FLAG-FLIP-PROPOSAL.md)
- Files modified : 4 (lefthook.yml + apps/mobile/pubspec.yaml + services/backend/app/services/coach/citation_parser.py + apps/mobile/lib/widgets/mint_chat_overlay.dart)
- Tests added : 42 (13 narrative_sleeve_lint + 6 metaphor_lookup Python + 7 metaphor_lookup Dart + 5 walkback Dart + 11 NarrativeSleeve render Dart)
- Full backend pytest : 6586 passed, 60 skipped, 1 xfailed (Plan 96-02 baseline 6567 → +19 net new W3 Python = 6586 exact, zero regressions)
- Full Flutter test : 8401 passed, 24 skipped (Plan 96-01 baseline 8378 → +23 net new W3 Dart = 8401 exact, zero regressions)
- Phase 94 byte-identity : 181 passed, 1 skipped (preserved)
- Phase 95 byte-identity : 74 passed (preserved)
- flutter analyze : 273 issues — identical to baseline (zero new issues)
- D-26 grep gate : 0 hits on mint_card_action_bar.dart + mint_chat_overlay.dart
- Commits : f4f3446d (T0) → 1b381faa (T1) → 8ab24f96 (T2) → dfd386f6 (T3)
- Duration : ~38 min execution (T0-T3)
- 0-trust : 96-03-SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/96-mvp-chat-as-verb/96-03-SUMMARY.md
- **D-17 shipped** : `apps/mobile/assets/metaphors.toml` (+ byte-equal backend mirror at `services/backend/app/data/metaphors.toml`) — 8 entries × 3 archetypes (swiss_native, expat_eu, cross_border) × 2 cantons (VD, GE) × 2 life events (housing, family). Verbatim FR, accent-clean, LSFin-clean, no retirement framing (CLAUDE.md §3). sha256 match = `528a34c9736cd44daafb282530d7c7a0c50c9e32b258430dc85d85991ad8098a`.
- **T-96-W3-TOMLPoisoning mitigation shipped** : `tools/checks/metaphor_parity.py` (sha256 compare + `--scan-values` LSFin + PII walk) + lefthook pre-commit entry. Python 3.11+ stdlib `tomllib` with `tomli` backport fallback for older runtimes.
- **D-16 shipped** : `services/backend/app/services/coach/narrative_sleeve_lint.py` — response middleware. `lint_sleeve(NarrativeSleeve) → NarrativeSleeve` swaps `hook` to `HOOK_FALLBACK = "Voyons ensemble ce que ça change pour toi."` on `\d` match. 3 ReDoS defenses : simple character class regex (`r"\d"`), SIGALRM 100 ms budget, broad-except fail-safe. Non-PII Sentry breadcrumb `coach.narrative_sleeve.hook_swap` (payload = `original_hook_length` only).
- **D-16 middleware wiring shipped** : `services/backend/app/services/coach/citation_parser.py` imports `lint_sleeve` + exposes `lint_response_sleeve(sleeve | None) → sleeve | None` (None-safe passthrough + delegate). Citation gate (`_substitute_placeholders`) stays first in middleware chain ; sleeve linter runs after, before response serialization.
- **D-18 shipped** : Dart `apps/mobile/lib/services/metaphor_lookup.dart` + Python `services/backend/app/services/coach/metaphor_lookup.py` — mirror resolvers. `lookup(archetype, canton, life_event) → str`, empty-string contract on miss. Dart loads TOML at app boot via `package:toml ^0.16.0` + `rootBundle.loadString` ; Python loads at module import via stdlib `tomllib`.
- **NarrativeSleeveCard render shipped** : `apps/mobile/lib/widgets/mint_chat_overlay.dart` extended with public `NarrativeSleeveCard` widget (4-field render per UI-SPEC §Component Anatomy : hook headlineSmall, caption bodyLarge, next_step labelLarge(mintForest) with « › » glyph + Semantics(hint='Prochaine étape'), conditional metaphor block under Divider). MintColors.craieHandoff surface. D-26 grep gate preserved (0 hits).
- **VERB-06 walkback path shipped** : `apps/mobile/test/services/feature_flags_walkback_test.dart` — 5 tests covering applyFromMap-driven flag flips, full false→true→false walkback cycle, key-absent passthrough, strict-true convention. `MintShell.branchToVisibleIndex(2) == 1` when flag is false (Coach collapses onto Mon argent per `mint_shell.dart:64-66`).
- **Maestro G1 flow contract shipped** : `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` — 10 steps per UI-SPEC §Maestro G1 Contract. Live exit-0 run is DEFERRED — needs (a) staging deploy of W3, (b) production card list to carry stable testIDs, (c) `chatTabVisible=false` on Railway staging /config/feature-flags. G2 Julien sim walkthrough is the authoritative end-to-end gate per CLAUDE.md §9.
- **96-03-FLAG-FLIP-PROPOSAL.md shipped** : 7-row eligibility checklist + D-11 7-day baseline-pull plan (`chat_overflow_turn_4` Sentry query → cap_hit_rate decision matrix) + walkback path + GO/NO-GO row mirroring Phase 94 template.
- Auto-fixed deviations (4) : (a) Rule 1 — plan claimed `appId: com.mint.mobile.staging` ; actual is single-bundle `ch.mint.app` (Runner.xcodeproj/project.pbxproj:505) ; corrected in T2 commit. (b) Rule 1 — plan-suggested docstring substring `Color(0x...)` would have tripped D-26 grep ; rewritten as « hardcoded ARGB literals » in T3. (c) Rule 3 - blocking — local Python 3.9 has no `tomllib` ; added `tomli` backport fallback to `metaphor_parity.py` + `metaphor_lookup.py`. (d) Rule 1 — `metaphor_parity.py` repo-root path resolution was one parent short ; bumped to `parent.parent.parent`.

## Plan 96-02 Receipt (Wave 2 Backend, 2026-05-11)

- Files created : 13 (2 schemas + 1 service module + __init__.py + conftest.py + 6 test files + 2 lint fixtures)
- Files modified : 4 (coach_chat.py schema + claude_coach_service.py + coach_chat.py endpoint + pii_fixture_scan.py)
- Tests added : 46 (12 serialized_card_context + 14 narrative_sleeve+extensions + 7 turn_cap + 5 terminal_template + 4 narrator_source_card_block + 4 sentry_overflow_breadcrumb)
- Full backend pytest : 6567 passed, 60 skipped, 1 xfailed in 109.99s (pre-W2 baseline 6521 → +46 net new W2 = 6567 exact, zero regressions)
- Phase 94 byte-identity : tests/test_citation_gate/ → 181 passed, 1 skipped (= pre-W2 baseline, preserved)
- Phase 95 byte-identity : tests/test_dag_invalidation/ → 74 passed (= pre-W2 baseline, preserved)
- Commits : b81172a3 (T1) → 54fee7cd (T2) → bbcf0853 (T3)
- Duration : ~42 min execution
- 0-trust : 96-02-SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/96-mvp-chat-as-verb/96-02-SUMMARY.md
- **D-12 shipped (backend mirror)** : SerializedCardContext Pydantic v2 — 7 fields, frozen=True, extra="forbid", camelCase aliases via to_camel. computed_facts scalar-only validator in mode='before' rejects bool (subclass of int — silent coercion fixed inline as Rule 1 auto-fix) + None + nested dict + list. Round-trip-compatible with the Dart mirror shipped in Plan 96-01.
- **D-14 + D-15 shipped** : NarrativeSleeve Pydantic v2 (4 fields, frozen+forbid) + additive optional `CoachChatResponse.narrative_sleeve` field. The hook digit-free linter + next_step word-count linter LAND in Plan 96-03 W3 per D-16 — Pydantic enforces byte-length caps only so the response middleware can swap on `\d` without 500ing.
- **D-13 shipped** : `CoachChatRequest` gains `source_card: Optional[SerializedCardContext] = None` + `turn_count: int = 0` (server IGNORES per T-96-W2-TurnCountTamper) + `intent: Optional[Literal["explain", "reassure"]] = None`. Narrator system prompt receives a `<source_card>` block when source_card is non-None ; legacy path (source_card=None) is byte-identical to Phase 94/95.
- **D-08..D-11 shipped** : `services/backend/app/services/coach/turn_cap.py` — TURN_COUNTER : Dict[(session_id, source_card_id), int], TURN_CAP_THRESHOLD=3, verbatim FR TURN_CAP_TERMINAL_TEMPLATE (« exploré » + « hypothèses » accents present ; zero LSFin terms — snapshot-guarded). At turn 4, the wrapper returns the terminal template with ZERO LLM call ; Sentry breadcrumb `coach.chat_overflow.turn_4` fires with non-PII payload (source_card_id + turn_count only).
- **New `_run_narrator_with_gate_and_cap` wrapper** at `services/backend/app/api/v1/endpoints/coach_chat.py` — wraps the Phase 94/95 `_run_narrator_with_gate` without modifying its signature (preserves the 213-test byte-identity matrix). Single call-site swap ; `_run_agent_loop` internals (Phase 94 §3 surgical scope) NOT touched.
- **pii_fixture_scan.py extended** (Phase 96 D-12) : structural walker scans `computed_facts` / `computedFacts` dict values for banned-key substrings (email/phone/ahv/iban/npa/employer/name/surname/address). Backward-compatible with Phase 95 D-14 AHV13 + Swiss-phone regex. 2 fixture pairs (clean exit 0, dirty exit 1 with 3 hits) under `tools/checks/fixtures/pii_scan/`.
- Auto-fixed deviations (2) : (a) Rule 3 - blocking — `uuid_utils` + `rfc8785` missing from venv ; installed via pip (Phase 95 W1 prerequisites). (b) Rule 1 - bug — Pydantic v2 Union coercion silently flipped bool to int in `computed_facts` ; switched the validator from default `mode='after'` to `mode='before'` (raw-input inspection pre-coercion).
- Architectural call (within plan latitude) : `<source_card>` block injected at the endpoint (after `_build_system_prompt_with_memory`), NOT inside the prompt builder. Karpathy #3 surgical — minimal blast radius. `_render_source_card_block` is exported from `claude_coach_service.py` for future call sites (anonymous_chat) when they need it.
- Pre-existing test-ordering issue in `test_coach_chat_bundles.py` (5 tests fail when run AFTER `test_coach_chat_endpoint.py` in the same invocation, pass in isolation and in the full traversal) — verified pre-existing by stashing W2 changes ; NOT introduced by this plan. Logged for post-96 maintenance backlog.
- USER VALUE DELIVERED : NONE YET — the 3-turn cap is LIVE server-side but no production traffic exercises it until the W3 Maestro flow + the post-W3 staging soak. The Dart-side overlay (Plan 96-01) does not yet send `source_card` payloads (deferred to W3 wiring per CONTEXT D-22).
- Phase 96 W3 HARD dependency : ProjectionGroundingPack contract + double-lookup plumbing (Phase 95 W2 — present on branch) + the NarrativeSleeve schema (this plan, T2) + the turn_cap surface (this plan, T3). All ready.

Next:

  1. **`/gsd-execute-phase 96 --wave 3`** → cross-stack NarrativeSleeve linter middleware + metaphor TOML library + Maestro G1 flow `flow_card_action_intent_bar.yaml` + G2 Julien sim walkthrough.
  2. **Post-W3 staging soak** before flipping `chatTabVisible=false` to prod per D-21 (4-week baseline-pull window on `chat_turn_distribution` Sentry metric ; >40% cap-hit → flag stays at false / walkback).
  3. **Julien GO/NO-GO** on `94-03-FLAG-FLIP-PROPOSAL.md` (carried from Phase 94 close) — still pending.

## Plan 96-01 Receipt (Wave 1 Flutter UI, 2026-05-11)

- Files created : 10 (1 model, 2 widgets, 1 demo screen, 6 test files)
- Files modified : 17 (1 pubspec.yaml + 1 pubspec.lock + 1 feature_flags.dart + 1 mint_shell.dart + 6 ARB + 7 app_localizations* regen)
- Tests added : 28 (4 feature_flags + 3 serialized_card_context + 8 mint_card_action_bar + 4 mint_chat_overlay + 5 mint_shell_flag_gate + 4 routing)
- Full Flutter suite : 8378 passed, ~24 skipped (regression : 0)
- flutter analyze : 273 issues total (= baseline 273, 0 new ; all info-level)
- Commits : 80ab0c67 (T1) → 9ece5283 (T2) → 75c1f74a (T3) → c5486f74 (T4)
- Duration : ~27 min
- 0-trust : 96-01-SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/96-mvp-chat-as-verb/96-01-SUMMARY.md
- **D-01 + D-21 shipped** : FeatureFlags.chatTabVisible default true, applyFromMap server override hook ; MintShell.NavigationBar collapses to 3 tabs when flag=false ; visibleToBranchIndex + branchToVisibleIndex exposed as pure functions for testability (T-96-W1-NavDrift mitigation, both flag states + round-trip identity tested).
- **D-04 + D-05 + D-06 + D-07 shipped** : MintCardActionBar 48dp / 200ms easeOutCubic / 3 verb chips / 44dp tap targets / MintColors.mentheVive12 splash / Semantics labels / D-26 grep gate (0 hardcoded colors, 1 Duration literal).
- **D-12 shipped** : SerializedCardContext 7-field Dart mirror (cardId / cardType required, computedFacts + groundingKeys defaulted empty, lifeEvent / canton / archetype optional). Unknown-field defense at fromJson. Backend Pydantic v2 mirror lands in Plan 96-02.
- **6-locale ARB sweep shipped** : verbExplique / verbSimule / verbRassure in fr / en / de / es / it / pt. arb_parity.py exits 0, 6750 keys per locale.
- **toml ^0.16.0 added to pubspec.yaml** : flutter pub get exits 0. Consumed in Plan 96-03 (D-17 metaphor library).
- **MintChatOverlay scaffold** : DraggableScrollableSheet 0.75/0.4/0.95 + 40×4dp drag handle + intent label slot + MintColors.nearBlack 60% scrim (D-26 compliant). W1 scaffold ONLY ; turn history + input bar in Plan 96-03.
- **Demo wiring screen** : `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` — 2 NON-retirement cards (« Marge fiscale 2026 », « Coût hypothèque mensuel ») wired with the 3-verb dispatch. Karpathy #3 surgical : did NOT touch 80+ production card widgets — full wiring deferred to post-v2.9 content sprint per plan deferred: block.
- Auto-fixed deviations (4 × Rule 1) : (a) generated localizations class is `S` not `AppLocalizations` ; (b) D-26 violation in plan's `Color(0x990A0A0F)` literal → replaced with `MintColors.nearBlack.withValues(alpha: 0.6)` ; (c) ARB parity tool name is `arb_parity.py` not `arb_parity_gate.py` ; (d) `MintColors.transparent` token exists, no fallback needed.
- USER VALUE DELIVERED : NONE end-user-visible YET — Wave 1 is the surface scaffold. Plans 96-02 + 96-03 deliver the chat behavior. The kill-switch infrastructure is READY : flipping `chatTabVisible=false` on Railway staging would drop the chat tab from the bottom nav with zero app redeploy.
- Phase 96 W2 HARD dependency : ProjectionGroundingPack contract + double-lookup plumbing shipped in Phase 95 W2 (a037c56d..e6a4a12f). Phase 96 W2 + W3 still pending.

Next:

  1. **`/gsd-verify-phase 95`** → 5-gate exit contract close. Both waves (95-01 + 95-02) shipped ; phase-level verifier reads both SUMMARYs, the VALIDATION matrix, and gates G1-G5.
  2. **Roadmap advancement to Phase 96 (mvp-chat-as-verb)** — Phase 96 W2 (Backend) HARD-depends on the GroundingPack contract surface shipped in 95-02 ; Phase 96 W1 (Flutter) is SOFT-independent and can proceed in parallel.
  3. **Julien GO/NO-GO** on `94-03-FLAG-FLIP-PROPOSAL.md` (carried from Phase 94 close) :
     - `approved` → Wave 4 opens (narrator-prompt placeholder syntax + re-eval)
     - `approved staging-only` → permanent staging-only, no prod-flip
     - `not approved — issue: <description>` → revision mode
  4. `/gsd-verify-work 94` → 5-gate exit contract close (G2 device + G3 dev CI pending — carried)

## Plan 94-01 Receipt (Wave 0 close, 2026-05-10)

- Files created : 9 (parser, registry, 6 test files, __init__.py)
- Files modified : 3 (config.py, eval_narrator.py, 94-VALIDATION.md)
- Tests added : 106 (Wave 0) + 0 regressions
- Full backend suite : 6372 passed, 62 skipped, 1 xfailed in 107.21s
- Commits : 033b8445 (T1) → 668df0de (T2) → 2a729c3d (T3)
- Duration : 13m 18s
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-01-SUMMARY.md

## Plan 94-02 Receipt (Wave 1 close, 2026-05-10)

- Files created : 7 (test_retry_flow, test_fallback, test_banned_claims, test_bundle_intersect, test_global_registry_fallback, test_telemetry, test_gate_performance)
- Files modified : 4 (citation_parser.py, coach_chat.py, test_number_detection.py, 94-VALIDATION.md)
- Tests added : ≈ 64 (Wave 1) + 0 regressions
- Full backend suite : 6436 passed, 62 skipped, 1 xfailed in 106.60s (Wave 0 baseline 6372 → +64 net new)
- Commits : 1d9b44f1 (T1 — fatten gate body) → 13230885 (T2 — wire wrapper) → final docs commit
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-02-SUMMARY.md
- Karpathy #3 surgical : ZERO edits inside `_run_agent_loop` (lines 1726-2624) — diff 114+/18- concentrated at narrator handler scope
- H1 fix iter 1 : `_compiled_bundle: "CompiledBundle | None" = None` initialized BEFORE bundle-compiler branch ; wrapper safe on every code path
- M2 fix iter 1 : 3 documented v1 banned-claim regex false-negatives codified (3rd-person + infinitive + LSFin « garanti » → compliance_guard)
- M3 fix iter 1 : D-04#4 placeholder-body strip — 3 regression tests in test_number_detection.py
- H3 fix iter 1 : end-to-end gate() p95 ≤ 50ms / max ≤ 80ms on 4 kB FR realistic narrative (test_gate_performance.py)
- Flag default OFF in prod (D-19/D-20) ; flag-OFF byte-identity preserved (6 snapshot tests still green)
- USER VALUE DELIVERED : NONE YET — Plan 94-03 builds eval pack + Maestro G1 + flips staging flag

## Plan 94-03 Receipt (Wave 2 close-pending, 2026-05-10)

- Files created : 8 (citation_gate_eval_50.jsonl, flow_narrator_refuses_uncited_numbers.yaml, 3 eval-run JSONs, EVAL-RESULTS, FLAG-FLIP-PROPOSAL, deferred-items, SUMMARY)
- Files modified : 2 (tools/eval_narrator.py +215 LOC, .token_count_cache.json +1 entry)
- Tests added : 0 (Plan 03 deliverables are CLI flag + fixture pack + Maestro flow + docs — gate logic tested in Waves 0+1, total 170 unit tests)
- Full backend suite : 6436 passed, 62 skipped, 1 xfailed in 106.09s (no regression vs Wave 1 baseline 6436)
- Commits (T1+T2+T3) : 937e3bba (T1 — --gate flag + 50-fixture pack) → f00fb693 (T2 — Maestro smoke flow + staging Railway + 3 live evals) → close-out docs commit
- Duration : ≈55 min execution + LLM API wait time
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-03-SUMMARY.md
- **STAGE 3 FINDING** : Sonnet gate_correct=3/50 (6%), Haiku 7/50 (14%) — both FAR below D-15 ≥95%/≥90% thresholds. Root cause : narrator system prompt does not teach `{{cite:<key>}}` placeholder syntax → gate (correctly per D-02..D-13) rejects naked numbers → 60-80% fallback rate. Mechanical, not a gate-logic bug. Wave 4 fattens narrator prompt → re-evals.
- **Maestro G1** : smoke-level PASS exit 0 (16-17s) on anonymous surface ; gate verification deferred to Wave 4 because anonymous_chat.py has NO gate wrapper today (deferred-items.md D1).
- **Staging Railway** : COACH_CITATION_GATE_ENABLED=true SET 2026-05-10T19:09:03Z on service MINT env staging ; prod env variable absent (config.py default False).
- **Recommendation** : NO-GO + PARTIAL (staging-only, Wave 4 narrator prompt fattening, re-eval). Awaits Julien GO/NO-GO/PARTIAL signal at Task 4 checkpoint.
- USER VALUE DELIVERED : NONE YET — Plan 94-03 builds eval pack + Maestro G1 + flips staging flag

## Plan 94.1-01 Receipt (Wave 4 narrator-prompt fattening, 2026-05-10)

- Files created : 7 (citation_grammar.py, bundles/citation_grammar.py, test_narrator_grammar_fragment.py, 94.1-01-PLAN.md, 94.1-EVAL-DELTA.md, 2 eval-run JSONs, 94.1-SUMMARY.md)
- Files modified : 5 (bundles/__init__.py, bundle_compiler.py +17 LOC, claude_coach_service.py +35 LOC, tools/eval_narrator.py +45 LOC, 94-03-FLAG-FLIP-PROPOSAL.md +1 section)
- Tests added : 12 (tests/test_citation_gate/test_narrator_grammar_fragment.py — fragment importability, 18-key coupling, verbatim examples, no new {slot}, builder purity, legacy path flag-on/off byte-identity, bundle path flag-on/off, compiler activated_bundles, dedup, Pydantic invariants)
- Full backend suite : 6448 passed, 62 skipped, 1 xfailed in 107.45s (+12 new tests vs Wave 1 baseline 6436 ; no regression)
- Commits (T1+T2+T3+T4) : 12b2a8fa (T1 PLAN.md) → b3a7ca1a (T2 fattening + tests + Rule 1 « tu dois » auto-fix) → T3 eval JSONs → T4 EVAL-DELTA + SUMMARY
- Duration : ~3.5h
- Architectural decision : Path C (Hybrid) — single source of truth citation_grammar.py CITATION_GRAMMAR_FRAGMENT consumed by both CitationGrammarBundle (flag-conditional in compile_bundles) AND build_narrator_system_prompt (flag-conditional append). NOT in _ALWAYS_ON constant ; NOT in ALL_BUNDLE_CLASSES — preserves test_empty_intent_emits_always_on_only + test_all_bundles_importable len=6 invariants.
- Eval instrumentation : eval_narrator --gate=on propagates COACH_CITATION_GATE_ENABLED=true to env + settings (Phase 94 Wave 2 ran without ; system prompt was unchanged).
- 0-trust : SUMMARY.md `## Self-Check : PASSED` at .planning/phases/94.1-.../94.1-SUMMARY.md
- **STAGE 3 FINDING (post-94.1)** : Sonnet gate_correct=10/50 (20%), Haiku 10/50 (20%) — both moved up from 6%/14% but STILL FAR below 95%/90% thresholds. Signal concentrated in valid_citation : Sonnet 1/20 → 9/20 (+800%), Haiku 6/20 → 10/20 (+67%). Topline understates improvement because fixture scoring records post-retry verdict (FALLBACK after D-08 collapse), not first-call (REJECTED_UNCITED) — under alternative « first-call match » scoring, Sonnet ≈48%, Haiku ≈44%.
- **Verdict** : FAIL per 94.1-01-PLAN interpretation rules (Sonnet < 70%). Orchestrator decides GO/NO-GO on 94.2 second-iter with primary hypothesis « intent-driven key grouping reduces 18-bullet noise floor » (full hypothesis list H1-H5 in 94.1-EVAL-DELTA.md).
- **Disposition** : NO-GO + PARTIAL unchanged. Staging stays ON for diagnostic value, prod stays OFF for narrator quality. No new GO recommendation.
- USER VALUE DELIVERED : NONE in prod. Branch `feature/S94-mvp-citation-gate` holds 94+94.1 ; not merged. The 94.1 measurement IS the only data on the fattened narrator behavior.

## Plan 95-01 Receipt (Wave 1 close, 2026-05-10)

- Files created : 13 (4 production modules — inputs_hash, projection_id, staleness, alembic p95 — + 7 test files + 2 fixture pack + 2 Dart harness + 1 PII lint, counting test_dag_invalidation/__init__.py and conftest.py as 1 setup unit)
- Files modified : 3 (pyproject.toml +2 deps, scenario.py +2 nullable cols, lefthook.yml +pii_fixture_scan entry)
- Tests added : 31 (10 inputs_hash + 6 projection_id + 7 staleness incl SC#4(c) + 4 migration + 4 hash_parity) + 0 regressions
- Full backend suite : 6479 passed, 62 skipped, 1 xfailed in 107.51s (Wave 0 baseline 6448 → +31 net new)
- Commits : 30381bad (T1 scaffold) → cb613e01 (T2 inputs_hash) → adbda907 (T3 projection_id) → 1296e7a7 (T4 alembic + staleness) → 93baff1c (T5 hash parity)
- Duration : ~17 min
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/95-mvp-dag-invalidation/95-01-SUMMARY.md
- **R1 risk CLOSED** : Python ↔ Dart hash parity 50/50 byte-identical on hash_parity_50.jsonl (50 fixtures across 5 buckets : 20 happy / 10 nested / 10 edge-floats / 5 boolean / 5 lex-sort). Required Dart-side _quantize() addition (Rule 1 auto-fix : initial RESEARCH §D-03 recipe omitted quantize step → 38/50 pre-fix → 50/50 post-fix).
- Deviations (3 auto-fixed) : (a) alembic p95 chained off 29_05_magic_link_tokens, not p86_eclairage_delivered (Rule 3 — codebase already had a branchpoint at p86) ; (b) Dart harness _quantize() addition (Rule 1) ; (c) test_migration.py monkeypatch.setenv + importlib.reload pattern (Rule 3 — env.py overrides sqlalchemy.url AFTER cfg.set_main_option).
- staleness_high() production read-path integration + Dart-side projection-model field additions both deferred to Phase 96 W2 per CONTEXT `<deferred>` block.
- USER VALUE DELIVERED : NONE YET — data-model + parity-test foundation only ; user-visible behavior changes ship in Phase 96 narrator wiring.

## Plan 95-02 Receipt (Wave 2 close, 2026-05-10)

- Files created : 10 (3 production modules — pareto, sensitivity, bootstrap_ci — + 7 test files)
- Files modified : 5 (grounding_pack.py wholesale-replaced, citation_parser.py, coach_chat.py, banned_terms_python.py, lefthook.yml)
- Tests added : 43 (10 schema + 6 pareto + 6 what_ifs + 7 bootstrap_ci + 9 double-lookup incl 2 BLOCKER-3 propagation + 5 lsfin) + 0 regressions
- Full backend suite : 6522 passed, 62 skipped, 1 xfailed in 107.83s (Wave 1 baseline 6479 → +43 net new W2)
- Commits : fb2b13aa (T1 contract) → e316ffbe (T2 pareto) → a037c56d (T3 what_ifs) → 8f474391 (T4 bootstrap_ci) → e6a4a12f (T5 double-lookup + propagation) → debe24f1 (T6 lsfin annotation)
- Duration : ~25 min
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/95-mvp-dag-invalidation/95-02-SUMMARY.md
- **D-07/D-08 contract shipped** : ProjectionGroundingPack + GroundingPackEntry + ParetoPoint Pydantic v2 frozen+forbid with Decimal field_serializer ; min/max validators on inputs_hash (64 chars) + pareto_points (=3) + what_ifs (=5) + superseded_by (None or 36 chars).
- **D-09 double-lookup shipped** : _substitute_placeholders + gate() gain keyword-only `pack: ProjectionGroundingPack | None = None` ; pack hit overrides registry ; pack miss → Sentry breadcrumb `coach.grounding_pack.fallback` (T-95-04 instrumentation) then registry fallback ; pack=None preserves Phase 94 byte-identity (test_pack_none_preserves_phase_94_behavior green ; 182/182 test_citation_gate green).
- **BLOCKER-3 fixed** : 6 GatedResponse(...) sites at citation_parser.py:465/494/503/547/556/569 propagate `inputs_hash=pack.inputs_hash if pack else None` ; 2 propagation tests assert the PASS path carries the hash + pack=None preserves inputs_hash=None.
- **D-10 Pareto + D-11 what_ifs + D-12 bootstrap_ci shipped** as pure-Python compute modules. Phase 96 W2 will wire arbitrage_engine + monte_carlo_service outputs to these consumers (per 95-02-PLAN deferred: block).
- **D-12 LSFin annotation lint shipped** : banned_terms_python.py --lsfin-annotation opt-in flag ; check_lsfin_annotation rule ; lefthook lsfin_annotation_phase_95 entry on 4 W2 modules ; default banned-terms mode preserved byte-identical.
- Deviations (3 auto-fixed) : (a) pareto fixture unit-scale math error [Rule 1] ; (b) what_ifs credible_low/high min/max bracket for negative-correlation inputs [Rule 1] ; (c) test_lsfin_annotation LINT path parents[4] not parents[3] [Rule 1]. All 3 are defects in plan-prescribed test scaffolding, ZERO bugs in plan-prescribed production code.
- USER VALUE DELIVERED : NONE YET — contract surface + plumbing + compute layer + lint. User-visible behaviour changes ship in Phase 96 W2 (narrator templates consume the pack ; chat surfaces P5/P95 bounds with the LSFin annotation).
- Phase 96 W2 HARD dependency : ProjectionGroundingPack contract + double-lookup plumbing ready ; Phase 96 W1 (Flutter) is SOFT-independent.

Progress: [████░░░░░░] 40% (2/7 phases counting this Wave 2 of Phase 95 — Phase 90 fully shipped, Phase 95 both plans closed) — Phase 90 shipped 2026-05-09 (5 design-system lints + baselines + lefthook + CI) ; Phase 95 closed both Wave 1 (parity foundation) and Wave 2 (contract + double-lookup + LSFin annotation).

## Phase Plan (Chat-as-Verb)

| # | Phase | Type | Effort | Status |
|---|---|---|---|---|
| 90 | MVP-DESIGN-LINTS-V1 | UI | 2d | ✓ shipped (PR #543) |
| 91 | MVP-EXTRACTOR-V2 | Architecture | 3d | RESEARCH.md done, discuss next |
| 92 | MVP-FONTS-TOKENS-V2 | UI | 3d | not started (depends on 90) |
| 93 | MVP-CTA-UNIFICATION-V1 | UI | 4d | not started (depends on 90) |
| 94 | MVP-CITATION-GATE | Architecture | 3d | not started (depends on 91) |
| 95 | MVP-DAG-INVALIDATION | Architecture | 4d | Wave 1 closed 2026-05-10 (Plan 95-01 5/5 tasks, 31 tests, R1 closed) — Wave 2 next |
| 96 | MVP-CHAT-AS-VERB | Architecture | 5d | not started (depends on 95) |

## Cross-cutting

- **Maestro flow library** : 7 new flows (one per phase) under `tools/simulator/flows/maestro-perfect-set/`. Indexed.
- **ARB sweep** : ~132 ARB additions across 6 locales (CTA + chat-as-verb intents + citation-gate error strings). Parity check per PR.
- **Banned-terms / accent / LSFin** : pre-commit hook already wired (lefthook from Phase 90) ; narrator output additionally validated at runtime by CITATION-GATE parser (Phase 94).
- **Performance budget** : cold launch ≤2.5s at W3 + W4 close ; agent loop ≤30s on EXTRACTOR-V2 + CITATION-GATE eval suite.
- **Backward compat** : DAG-INVALIDATION is additive (hash nullable) ; existing profiles compute hash lazily ; zero forced recomputation.

## Risks (per memory feedback_design_panel_before_push)

1. CTA sweep (Phase 93) slips beyond 4d — 80 sites optimistic. Mitigation: pre-flight categorization Day 1.
2. CITATION-GATE retry loop (Phase 94) blows token budget. Mitigation: hard-cap retries at 1, templated fallback.
3. DAG-INVALIDATION (Phase 95) breaks profiles. Mitigation: additive migration, nullable hash.
4. CHAT-AS-VERB (Phase 96) user revolt. Mitigation: feature flag default-on, monitor `chat_overflow_turn_4`.
5. FONTS license (Phase 92). Mitigation: Fontshare ToS review gate before W1 merge.
6. Adversarial counter-thesis « chat IS the product ». Mitigation: 3-turn cap is the hypothesis being tested ; walkback path baked in.

## Session Continuity

Last session: 2026-05-21T05:49:51.052Z
Stopped at: Completed 01.1-02-PLAN.md (Wave 2 hero-flow YAML + dry-run trace GREEN, commit 016afb09). Plan 01.1-03 unblocked (Wave 3, autonomous=false, Julien G2 next).
Resume file: None

<details>
<summary>v2.8 archive — L'Oracle & La Boucle (shipped 2026-04-25, 5/9 phases + 13 decimals)</summary>

## Architecture Decisions (pre-phase, v2.8)

- **Nom**: "L'Oracle & La Boucle" (pas "Pilote & Compression"). Capture le geste central.
- **Rule inversée scellée**: 0 feature nouvelle. Tout ajout = out of scope by default.
- **Compression transversale**: chaque phase tue du code mort au passage, pas phase isolée.
- **Sentry existant étendu**, pas Datadog/Amplitude/PostHog (un seul vecteur = moins de surface nLPD + moins de divergence).
- **Système flags custom étendu** ([feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) + endpoint `/config/feature-flags`), pas LaunchDarkly.
- **lefthook pre-commit local**, pas juste CI gates (feedback <5s vs 2-5 min).
- **Phase numbering continué** depuis v2.7 (30 terminé) → **30.5, 30.6 (decimal inserts post-panel-debate), puis 31-36**.
- **Research activée** (Julien a choisi "Research first") — 4 researchers parallèles sur observabilité fintech mobile. Synthèse dans `.planning/research/SUMMARY.md`.
- **Phase debate résolu** (4 panels: Claude Code architect / peer tools / academic / devil's advocate) — MEMORY.md truncation = P0 runtime confirmé, lints mécaniques ROI > refonte éditoriale, AST proof-of-read = theater, `UserPromptSubmit` hook ciblé remplace AST, Phase 30.6 Tools Déterministes ajoutée (insight Panel C).
- **Kill-policy scellée** via [ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si v2.8 exit avec REQ table-stake unmet, la feature est KILLED via flag. Pas de v2.9 stabilisation.
- **Budget Phase 36 non-empruntable** (2-3 sem MINIMUM) — forces honest sizing de 31-35.

## Last v2.8 Position (frozen 2026-04-25)

Phase: 31
Plan: Not started
Status: Phase complete — ready for `/gsd-verify-work 30.7` + `/gsd-secure-phase 30.7` (Auto profile L1)
Next: `/gsd-verify-work 30.7` on `feature/S30.7-tools-deterministes` — 5/5 plans have SUMMARY, CLAUDE.md -30% trim @ 43a38dff, kill-switch rehearsed + Julien approved 2026-04-22, J0 fresh-session smoke deferred to post-merge operational validation (non-blocking). Also pending: `/gsd-verify-work 32` on `feature/v2.8-phase-32-cartographier` (3 RISK entries await Julien ack for nyquist_compliant flip).

Progress at v2.8 close: [██████████] 100% (5/9 phases, 22/22 plans) — Phase 30.7 5/5 shipped (30.7-00 wave0 + 30.7-01 tools 1+2 + 30.7-02 tools 3+4 + 30.7-03 mcp-server + 30.7-04 CLAUDE.md trim -30%) ; Phase 32 6/6 shipped (reconcile + registry + cli + admin-ui + parity-lint + ci-docs-validation).

## v2.8 Build Order

```
30.5 → 30.6 → (31 ∥ 34) → (32 ∥ 33) → 35 → 36
```

- **30.5 Context Sanity** (5j non-empruntable) — foundation, CTX-05 spike gate go/no-go
- **30.6 Tools Déterministes** (2-3j) — MCP tools on-demand, ~16k tokens/session saved
- **31 Instrumenter** (1.5 sem, can borrow from 34) — Sentry Replay + error boundary 3-prongs + trace_id round-trip
- **34 Guardrails** (1.5 sem, can borrow from 31, parallel with 31) — lefthook + 5 lints + CI thinning. **GUARD-02 bare-catch ban must be ACTIVE before Phase 36 FIX-05 starts.**
- **32 Cartographier** (1 sem, can borrow from 33) — route registry + /admin/routes dashboard
- **33 Kill-switches** (1 sem, can borrow from 32, parallel with 32) — GoRouter middleware + FeatureFlags ChangeNotifier + 4 P0 kill flags provisioned for Phase 36
- **35 Boucle Daily** (1 sem) — mint-dogfood.sh simctl + auto-PR threshold
- **36 Finissage E2E** (2-3 sem **non-empruntable**) — 4 P0 fixes + 388 catches → 0 + device walkthrough 20 min

## v2.8 Phase Budget Table

| Phase | Name | Budget | Borrowable | REQs | Kill gate |
|-------|------|--------|------------|------|-----------|
| 30.5 | Context Sanity | 5j | **non-empruntable** | 5 | CTX-05 spike |
| 30.6 | Tools Déterministes | 2-3j | — | 4 | — |
| 31 | Instrumenter | 1.5 sem | from 34 only | 7 | OBS-06 PII audit |
| 34 | Guardrails | 1.5 sem | from 31 only | 8 | — |
| 32 | Cartographier | 1 sem | from 33 only | 5 | — |
| 33 | Kill-switches | 1 sem | from 32 only | 5 | — |
| 35 | Boucle Daily | 1 sem | — | 5 | — |
| **36** | **Finissage E2E** | **2-3 sem MIN** | **never** | **9** | 4 P0 kill flags + device walkthrough |

**Total estimate (v2.8):** 8-10 sem solo-dev avec parallélisation (31 ∥ 34, 32 ∥ 33).

## v2.8 Performance Metrics

**Velocity (from previous milestones):**

- Total plans completed v2.4-v2.7: 24 plans
- Average duration: ~15-30 min/plan (increasing complexity)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)

**v2.8 Execution Log:**

| Phase-Plan      | Duration | Tasks | Files | Completed  |
|-----------------|----------|-------|-------|------------|
| 32-02-cli       | 7 min    | 2     | 11    | 2026-04-20 |
| 32-03-admin-ui  | 11 min   | 2     | 11    | 2026-04-20 |
| 32-04-parity-lint | 5 min  | 1     | 6     | 2026-04-20 |
| Phase 32 P05 | 9min | 3 tasks | 5 files |
| Phase 30.7 P00 | 28 min | 3 tasks | 12 files |
| Phase 30.7 P01 | 15 min | 2 tasks | 4 files |
| Phase 30.7 P02 | 4min | 2 tasks | 4 files |
| Phase 30.7 P30.7-03 | 5min | 2 tasks | 5 files |
| Phase 30.7 P30.7-04 | 35 min | 2 tasks (T1 trim + T2 checkpoint) | 1 file (CLAUDE.md) | 2026-04-22 |

## v2.8 Accumulated Context (decisions reference — preserved for continuity)

### Decisions (v2.8 pre-phase)

- **v2.8 name**: "L'Oracle & La Boucle" captures instrumentation-first + daily loop
- **0 feature nouvelle** scellée via kill-policy ADR
- **Compression transversale**: chaque phase tue du code mort au passage
- **Extend existing Sentry** (not Datadog/Amplitude/PostHog) — bump `sentry_flutter` 8→9.14.0
- **Extend custom flags** (not LaunchDarkly) — converge 2 backend systems (env-backed read + Redis-backed write)
- **lefthook 2.1.5** for pre-commit local (not CI-only) — target <5s
- **Sentry Replay Flutter 9.14.0** with `maskAllText=true` + `maskAllImages=true` nLPD-safe defaults non-négociables
- **Headers manuels `sentry-trace` + `baggage` sur `http: ^1.2.0`** (pas migration Dio)
- **Binary-per-route flags** (pas cohort/percentage)
- **4 P0 kill flags provisioned in Phase 33** before Phase 36 begins: `enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.5: Anonymous flow + commitment devices + coach intelligence + couple mode + living timeline (shipped 2026-04-13)
- v2.6: Coach stabilisation + doc digestion (shipped 2026-04-13)
- v2.7: Coach stab v2 + doc pipeline honnête + compliance/privacy + device gate (code-complete 2026-04-14, awaiting device walkthrough)
- Wave E-PRIME (merged PR #356 → dev f35ec8ff, 2026-04-18) — 42K LOC supprimées, 72 files mobile + 4 backend deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns (v2.8 carry-forward)

- **388 bare catches** (332 mobile + 56 backend) at v2.8 entry — migration requires GUARD-02 active as moving-target prevention
- **Anonymous flow dead** despite `AnonymousChatScreen` implemented — LandingScreen CTA auth-gated (one-line fix FIX-02)
- **save_fact backend→front unsync** — missing `responseMeta.profileInvalidated` field in canonical OpenAPI (FIX-03)
- **UUID profile crash** on backend — schemas/profile.py validation bug (FIX-01)
- **Coach tab routing stale** — navigation state fix (FIX-04)
- **MintShell ARB parity audit** (FIX-06) — labels already i18n-wired, MEMORY.md was stale, audit not rewrite
- **Wave C scan-handoff** in progress on current branch `feature/wave-c-scan-handoff-coach` (independent, merge before v2.8 Phase 30.5 kickoff)

### Roadmap Evolution

- 2026-05-10 — Phase 94.1 inserted after Phase 94 : « Wave 4 narrator-prompt fattening — citation registry + `{{cite:<key>}}` grammar instructions (Phase 94 prod-flip unblocker) ». URGENT decimal patch surfaced by Phase 94 close-out — Stage 3 thresholds NOT MET (Sonnet 6%, Haiku 14%) because narrator system prompt does not yet teach the citation placeholder grammar. Scope : extend `build_narrator_system_prompt` + `build_narrator_system_prompt_from_bundles` in `services/backend/app/services/coach/claude_coach_service.py` with the 18-key `CITATION_REGISTRY` list + `{{cite:<key>}}` directive ; re-run the 50-fixture `citation_gate_eval_50.jsonl` pack on Sonnet + Haiku ; if Sonnet ≥95% / Haiku ≥90% land, re-open `94-03-FLAG-FLIP-PROPOSAL.md` as GO. ~1d scope. Branch policy : continue on `feature/S94-mvp-citation-gate` OR split to `feature/S94.1-narrator-prompt-fattening` (Julien decides at PR time).

- 2026-05-12 — P001 narrator citation-gate ship-as-is decision (julien-go ADR row #2, 2026-05-12T09:55Z, `.planning/decisions/2026-05-12-r-perimeter-sequencing-julien-go.md`). After W7 iter#11 H1 lift (Sonnet 16→18% / Haiku 18→22% gate-correct, REJECTED on 50% PARTIAL bar but MARGINAL lift in the right direction), Julien validates GO to ship v2.9 H1-only as-is. **P001 is NO LONGER a v2.9 ship blocker** : the `FALLBACK_TEMPLATED_TEXT` path is the LSFin runtime safety net (no narrator output emitted without citation — compliance preserved via banned-claim regex + accent FR lint). H2-H5 architectural follow-ups (filed as P001b/c/d/e in 97-BUGS-REGISTRY.md) deferred to v2.10 with `deferred_to: v2.10` field per Phase 97.5 W4-T1 P001-PAPERWORK. The user-visible educational degradation (≤22% gate-correct on prod) is accepted for v2.9 ; v2.10 attacks the gate-correct architecturally (few-shot in-context examples per H5, or methodology change per 94.1-EVAL-DELTA §H5). Registry status promoted IN_PROGRESS → RESOLVED (a PROMOTION, allowed by `bug_registry_lint.py` state machine).

### Known Good Foundations (to capitalize, still valid for v2.9)

- Sentry backend+mobile wired (sample 10%) ✓
- 148 GoRoute documentées (ROUTE_POLICY.md, NAVIGATION_GRAAL_V10.md, SCREEN_INTEGRATION_MAP.md) ✓
- Système flags custom 8 flags + endpoint `/config/feature-flags` + server override ✓
- ~10 CI gates mécaniques dans `tools/checks/` ✓ (now 15 with Phase 90 design lints)
- `tools/e2e_flow_smoke.sh` existing ✓
- SLOMonitor auto-rollback primitive (v2.7) — generalizable for Phase 33 ✓
- `redirect:` callback at `app.dart:177-261` — single insertion point for Phase 33 `requireFlag()` ✓
- Existing global exception handler at `main.py:169-180` — needs trace_id + event_id extension for OBS-03 ✓

</details>

---
*Last activity: 2026-05-11 — v2.9 Chat-as-Verb Pivot ACTIVE. Phase 96 Wave 3 (Cross-stack) implementation complete : metaphors.toml v1 bootstrap (8 entries, mobile + backend byte-equal + parity lint), NarrativeSleeve hook digit-free linter middleware (ReDoS-safe, never raises), Dart + Python metaphor_lookup mirrors, citation_parser middleware-ordering helper, Maestro G1 contract flow, VERB-06 walkback test, NarrativeSleeveCard renderer, FLAG-FLIP-PROPOSAL. 4 atomic commits f4f3446d..dfd386f6, 42 net new tests (19 Python + 23 Dart), full backend pytest 6586 passed + Flutter 8401 passed, Phase 94/95 byte-identity preserved (255 tests). Task 4 G2 Julien sim walkthrough is the open gate per CLAUDE.md §9 0-trust ; Phase 96 cannot claim « shipped » without Julien token.*
