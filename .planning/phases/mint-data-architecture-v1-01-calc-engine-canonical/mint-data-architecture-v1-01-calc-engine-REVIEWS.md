---
phase: mint-data-architecture-v1-01-calc-engine-canonical
reviewers: [codex]
reviewed_at: 2026-05-17T14:48:39Z
plans_reviewed: [01-01-PLAN.md, 01-02-PLAN.md, 01-03-PLAN.md, 01-04-PLAN.md, 01-05-PLAN.md]
reviewer_runtimes_available_but_skipped: [claude]
reviewer_runtimes_not_installed: [gemini, coderabbit, opencode]
note: |
  Only codex was eligible per the workflow independence rule (claude is the current runtime
  driving this orchestration ; gemini/coderabbit/opencode were not installed on the host).
  Single-reviewer mode — no consensus synthesis across multiple AIs ; treat codex's review
  as one expert second opinion, not a multi-AI consensus.
---

# Cross-AI Plan Review — Phase mint-data-architecture-v1-01-calc-engine-canonical

## Codex Review (gpt-5.3-codex, OpenAI Codex v0.125.0)

## 01-01-PLAN.md (Wave 1)

### 1) Summary
Strong foundational plan for D-14/D-13 telemetry implications: it is test-first, concrete, and scoped to measurement + metric declarations. It gives Phase 02 evidence anchors. Main risk is coupling tests to live mutable registry data and brittle assumptions about active parameter counts/coverage semantics.

### 2) Strengths
- Clear phase-fit scope: measurement + telemetry scaffolding only (`tools/measurement/regulatory_snapshot_bundle_size.py`, `services/backend/app/core/metrics.py`).
- Good TDD sequencing with explicit RED→GREEN steps.
- D-14 threshold encoded explicitly (`threshold_bytes = 102_400`).
- Explicit report artifact for doctrine citation (`01-01-BUNDLE-SIZE-REPORT.md`).
- Threat model correctly avoids PII labels in metrics.

### 3) Concerns
- **MEDIUM:** Test brittleness on data assumptions: `param_count >= 100` and exact canton set from runtime registry may fail if regulatory seed data changes (test file: `services/backend/tests/test_regulatory_snapshot_bundle_size_measurement.py`).
- **MEDIUM:** Script filters `is_active(today)` while `RegulatoryRegistry.get_all()` may include historicals; if `version_hash()` semantics differ from filtered payload, drift between measurement and endpoint plan can appear later.
- **LOW:** Counters are declared server-side for mobile/offline concepts (`mint_offline_session_total`, `mint_l1_only_session_total`) without clear ingestion path yet; acceptable but should be documented as backend exposition only.
- **LOW:** Full-suite pass-count assertions (e.g., `>=7268`) are fragile in active repos.

### 4) Suggestions
- Replace hard `param_count >= 100` with invariant tests: non-empty + contains mandatory jurisdiction set.
- Add one test asserting measurement hash consistency rule with planned `/constants/snapshot` payload schema to prevent future divergence.
- In `metrics.py`, add a short comment that firing is expected from Phase 02 ingestion/client telemetry bridge.

### 5) Risk Assessment
**Overall risk: MEDIUM-LOW.** Well-designed and phase-appropriate; main risk is fragile tests against mutable registry content.

---

## 01-02-PLAN.md (Wave 2)

### 1) Summary
This is the most critical plan and generally well-crafted: it enforces D-04 atomic doctrine realignment across `CLAUDE.md`, `docs/AGENTS/*`, skills, and ADR status flip. Biggest risk is execution fragmentation: “same PR” is declared but not mechanically enforced across contributors.

### 2) Strengths
- Correctly targets the core blocker: doctrine conflict (`CLAUDE.md` vs `docs/AGENTS/backend.md:39`).
- Explicitly encodes D-01..D-04, D-05..D-07, D-09..D-11, D-13 in text-level artifacts.
- Includes anti-drift updates to skill indexes (`.claude/skills/mint-flutter-dev/SKILL.md`, `.claude/skills/mint-backend-dev/SKILL.md`).
- Keeps Phase 02/03 statuses intentionally pending in ADR (`.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md`).

### 3) Concerns
- **HIGH:** D-04 “same PR” atomicity is not enforced by tooling; plan relies on reviewer discipline only.
- **MEDIUM:** Task 3 aborts if skill dirs exist; this can block execution in real repo states where placeholders already exist.
- **MEDIUM:** Extensive verbatim rewrites in `CLAUDE.md`/docs risk merge conflicts and accidental collateral edits.
- **LOW:** Dependency on Plan 01 output for doctrine citation may create unnecessary coupling if only wording references are needed.

### 4) Suggestions
- Add a hard CI/check script for D-04: fail unless all 6 target files are changed in the same branch/PR.
- For skills creation, switch from “abort if exists” to “update in place with idempotent markers.”
- Add a minimal “doctrine consistency check” script grepping for forbidden legacy strings across all doctrine files.

### 5) Risk Assessment
**Overall risk: MEDIUM.** Architecturally correct but operationally sensitive; atomicity should be mechanized.

---

## 01-03-PLAN.md (Wave 3)

### 1) Summary
Good additive API scaffolding plan for D-15 endpoints and OpenAPI sync. It’s strong on test coverage and route-collision awareness. Main risk is route-order ambiguity in instructions and weakly defined snapshot serialization parity contract.

### 2) Strengths
- Clear API contract split: lightweight `/constants/version` + full `/constants/snapshot`.
- Explicit route-shadowing awareness around `@router.get("/constants/{key:path}")` in `services/backend/app/api/v1/endpoints/regulatory.py`.
- Strong endpoint tests (shape, hash parity, gzip guard, ETag).
- OpenAPI canonical regen included (`tools/openapi/mint.openapi.canonical.json`).

### 3) Concerns
- **HIGH:** Conflicting guidance in `<interfaces>` text about insertion location (“between line 91 and 94” vs “before line 61”). This can cause wrong route registration.
- **MEDIUM:** `effective_from` derivation logic may fail if any active param lacks `effective_from` (min over empty filtered list edge case).
- **MEDIUM:** Test asserting response `<500 bytes` may become brittle if date formatting or key names evolve.
- **MEDIUM:** Serialization parity test acknowledges FastAPI encoder differences but leaves ambiguity: byte-stability may not hold unless explicit response serialization is enforced.
- **LOW:** `Cache-Control: public` is fine for public constants, but no mention of ETag conditional GET behavior (`If-None-Match`) yet.

### 4) Suggestions
- Resolve route-order instruction to one canonical rule: define `/constants/version` and `/constants/snapshot` **before** `/constants/{key:path}`.
- Add null-safe handling for `effective_from` and `reviewed_at` extraction.
- Prefer semantic size guard (e.g., under 1KB) over exact 500-byte hard target, or keep 500 but document strictness rationale.
- Consider explicit JSONResponse with canonical serialization only if byte-level reproducibility is truly required downstream.

### 5) Risk Assessment
**Overall risk: MEDIUM.** Good plan with one critical doc ambiguity and a few edge-case fragilities.

---

## 01-04-PLAN.md (Wave 4)

### 1) Summary
Comprehensive D-08/D-13/D-16 implementation plan with clear generated artifacts and CI/lefthook integration. It is the highest execution-risk plan due to external staging dependency, generated Dart complexity, and potential overreach for a doctrine/scaffolding phase.

### 2) Strengths
- Strong separation of regulatory vs doctrinal constants (`regulatory_constants.g.dart` vs `doctrinal_constants_version.g.dart`), aligned to D-13.
- Good `--check` mode semantics and explicit staging-down soft-warn path.
- Includes both local deterministic source and staging source in codegen.
- Adds validation via Python tests and Dart analyze/test.

### 3) Concerns
- **HIGH:** Uses live staging in CI and hooks; even with soft-warn, drift can silently accumulate if staging is frequently down (`.github/workflows/regulatory-codegen.yml`).
- **HIGH:** Potential over-engineering for Phase 01: two codegen scripts + workflow + hooks + tests + generated artifacts may exceed “doctrine + scaffolding” minimum.
- **MEDIUM:** Dart rendering of arbitrary JSON values risks invalid Dart literals (strings with quotes, nested structures), especially in `render_dart()` logic.
- **MEDIUM:** `--check` compares only baked hash, not full payload integrity; hash-line manual tampering is mitigated but not fully.
- **MEDIUM:** Mobile generated map type `Map<String, Map<String, Object>>` may be too narrow for nullable/complex values.
- **LOW:** No explicit tie-in yet to runtime delta-check consumer path in `apps/mobile/lib/services/regulatory_sync_service.dart`.

### 4) Suggestions
- Add a deterministic fixture mode (checked-in snapshot fixture) for CI hard validation; keep staging check as advisory.
- Reduce scope if needed: ship regulatory codegen first, doctrinal generator in follow-up if timeline tight.
- Harden Dart literal escaping and add golden test comparing generated file parseability.
- Add a checksum over full normalized snapshot body in generated header, not just version hash.
- Add a small integration note/test for runtime consumer import path.

### 5) Risk Assessment
**Overall risk: MEDIUM-HIGH.** Valuable but operationally heavy; strongest risk is silent softness from staging-down plus generator complexity.

---

## 01-05-PLAN.md (Wave 3, parallel)

### 1) Summary
Useful parity-lint extension aligned with D-12 soft-warn intent and Phase 02 hardening path. Parallelization with 01-03 is sensible. Main risk is coupling to Plan 04 artifacts before they exist and mixing concerns in an already central lint script.

### 2) Strengths
- Preserves existing Concern C behavior while adding constants drift mode (`tools/checks/profile_safe_fields_parity.py`).
- Explicit soft→hard promotion path (`--hard`) for Phase 02.
- Good missing-file graceful handling for pre-Plan-04 timing.
- Lefthook trigger scope is narrow and relevant.

### 3) Concerns
- **MEDIUM:** Plan 05 depends on generated file path from Plan 04 but is wave 3; although handled by soft-warn, signal quality may be noisy until wave 4 lands.
- **MEDIUM:** Script import path hacks (`sys.path.insert`) can mask environment issues and produce false “warn-only” outcomes.
- **LOW:** Running both Concern C and constants check in one command may complicate triage if outputs interleave.
- **LOW:** Additional soft-warn hooks can desensitize developers to warnings.

### 4) Suggestions
- Add explicit status codes/messages differentiating “missing generated file” vs “import failure” vs “true drift.”
- Print machine-readable JSON line for CI parsing of drift status.
- After Phase 04 merge, add a one-time gating check in CI (not just hook) to establish baseline integrity.

### 5) Risk Assessment
**Overall risk: MEDIUM-LOW.** Good additive guardrail with manageable sequencing caveats.

---

## Cross-Plan Assessment

### Summary
The 5-plan package is coherent and largely aligned with `CONTEXT.md` domain/decisions: doctrine conflict resolution (D-04), endpoint scaffolding (D-15), codegen sync mechanics (D-08/D-16), and parity observability (D-12). The biggest risks are operational rather than conceptual: atomicity enforcement for the doctrine PR, route-order ambiguity in Plan 03 instructions, and reliance on soft-warn pathways that could mask drift.

### Key Cross-Plan Risks
- **HIGH:** D-04 same-PR atomicity is stated but not enforced automatically.
- **HIGH:** Plan 03 route-order instruction inconsistency can break `/constants/version` and `/constants/snapshot`.
- **MEDIUM:** Too many soft-warn paths (Plan 04 + Plan 05) may allow prolonged undetected drift.
- **MEDIUM:** Phase 01 may be approaching scope creep with full codegen + CI workflow + doctrinal hash generator, though still defensible as scaffolding.

### Overall Risk Level
**MEDIUM.** Strategy is strong and consistent with D-CE-06/09/10/15/16 constraints, but execution needs tighter mechanical gates for atomicity and drift visibility to avoid “green but stale” outcomes.

---

## Triage of codex findings (single-reviewer mode)

Codex flagged **4 unique HIGH-severity** + **~10 MEDIUM-severity** + **~6 LOW-severity** issues across 5 plans + cross-plan rollup. The two HIGH entries in the cross-plan section restate per-plan HIGH findings (D-04 atomicity, Plan 03 route-order) — not new findings.

### HIGH-severity findings (recommend replan via `/gsd-plan-phase ... --reviews`)

| # | Plan | Finding | Affected plan section |
|---|---|---|---|
| 1 | 01-02 | D-04 « same PR » atomicity is process-only ; no mechanical gate enforces the 6-file doctrine set co-modification. Risk : partial merge drops doctrine consistency. | Plan 02 verification block + add new CI gate task |
| 2 | 01-03 | Route-placement instructions are internally contradictory ("between line 91 and 94" vs "must be before line 61"). Risk : wrong placement → `/constants/version` and `/constants/snapshot` get shadowed by `/constants/{key:path}`. | Plan 03 `<interfaces>` Task 1 |
| 3 | 01-04 | Uses live staging in CI and hooks ; even with soft-warn, drift can silently accumulate if staging is frequently down. | Plan 04 `.github/workflows/regulatory-codegen.yml` |
| 4 | 01-04 | Scope creep for a doctrine/scaffolding phase : two codegen scripts + CI workflow + hook families + tests + generated artifacts may exceed « doctrine + scaffolding » minimum. | Plan 04 overall scope |

### MEDIUM-severity findings (apply during execution, not full replan)

- 01-01 : test brittleness on `param_count >= 100` + exact canton set against runtime registry data ; mutable registry can flake tests.
- 01-01 : script filters `is_active(today)` while `RegulatoryRegistry.get_all()` may include historicals ; `version_hash()` semantic mismatch risk vs endpoint Plan 03 payload.
- 01-02 : Task 3 aborts if skill dirs already exist (real repo states with placeholders deadlock).
- 01-02 : extensive verbatim rewrites in `CLAUDE.md`/docs risk merge conflicts and accidental collateral edits.
- 01-03 : `effective_from` derivation may fail on empty filtered list (min over empty seq).
- 01-03 : response `<500 bytes` test brittle if date format / key names evolve.
- 01-03 : serialization parity test acknowledges FastAPI encoder differences but leaves byte-stability ambiguous (Plan 04 codegen depends on this contract).
- 01-04 : `render_dart()` literal escaping risks (strings with quotes, nested structures, numeric format).
- 01-04 : `--check` compares only baked hash, not full payload integrity.
- 01-04 : Dart generated map type `Map<String, Map<String, Object>>` may be too narrow for nullable/complex values.
- 01-05 : import path hacks (`sys.path.insert`) can mask env issues → false « warn-only » outcomes.
- 01-05 : Plan 05 depends on Plan 04 artifact path before wave 4 lands — handled by soft-warn but signal quality noisy.

### LOW-severity findings (defer or accept)

- 01-01 : counters declared backend-side for mobile/offline concepts — clear documentation that emission is Phase 02.
- 01-01 : full-suite `>=7268` pass-count assertion brittle in active repos.
- 01-02 : dependency on Plan 01 BUNDLE-SIZE-REPORT.md citation is light coupling.
- 01-03 : `Cache-Control: public` set without `If-None-Match` roadmap note.
- 01-04 : no explicit tie-in to runtime delta-check consumer path (`apps/mobile/lib/services/regulatory_sync_service.dart`).
- 01-05 : interleaved Concern C + constants output complicates triage.

### Phase-level systemic concerns (codex's cross-plan synthesis)

1. **D-04 atomicity is social, not technical** → add a Plan 02 task that writes a pre-commit/CI gate failing unless the 6-file doctrine set is co-modified in one PR.
2. **Plan 03 route-order ambiguity** → fix `<interfaces>` to one canonical rule : literal `/constants/version` + `/constants/snapshot` declared BEFORE `/constants/{key:path}`.
3. **Plan 04 staging-soft drift masking** → add aging/escalation policy ; long staging outages should raise a repo-level warning issue.
4. **Plan 04 scope creep** → trim to MVP scaffold (generator + committed file + local check) ; defer staging-source mode + dual codegen system to Phase 02.

### Codex's overall risk verdict

**MEDIUM** — plans are decision-traceable and constraint-respecting (D-CE-06/09/10/15/16) but four HIGH-severity execution risks need addressing before `/gsd-execute-phase`.

---

## Recommendation

1. **Replan via `/gsd-plan-phase mint-data-architecture-v1-01-calc-engine-canonical --reviews`** to apply the 4 HIGH-severity fixes :
   - Plan 02 : add D-04 atomicity CI gate task.
   - Plan 03 : resolve `<interfaces>` route-order contradiction to single canonical rule.
   - Plan 04 : add staging-outage aging/escalation policy ; trim scope to MVP (single codegen + committed file + local check) ; defer dual codegen + staging-source mode to Phase 02 with explicit handoff note.
2. **Brief executor on MEDIUM findings via plan inline notes** during execution — surgical adjustments at task level, not full replans.
3. **Accept LOW findings** as execution discretion or capture as Phase 02 deferred items.

> Note : codex is one expert second opinion, not a multi-AI consensus (claude is the orchestrator runtime ; gemini/coderabbit/opencode not installed). The independent claude orchestrator + gsd-plan-checker (sonnet) iteration 2 already validated 16/16 D-XX coverage + 0 D-CE-XX reopened + 0-trust §9 protocol respected. Codex's findings are complementary risk surfaces, not contradictions to that core verdict.
