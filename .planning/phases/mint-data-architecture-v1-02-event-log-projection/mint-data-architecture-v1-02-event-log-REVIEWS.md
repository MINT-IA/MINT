---
phase: mint-data-architecture-v1-02-event-log-projection
phase_number: 02
reviewers: [gemini-2.5-pro]
reviewers_skipped:
  - claude: current runtime (workflow §step1 — skipped for independence)
  - codex: usage limit hit at 2026-05-18T10:45Z, retry after 13:36 local
  - gemini: ran successfully via gemini-cli 0.42.0 with AI Studio API key
  - coderabbit: not installed
  - opencode: not installed
reviewed_at: 2026-05-18T10:55:00Z
plans_reviewed:
  - mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-PLAN.md
  - mint-data-architecture-v1-02-event-log-02-event-log-core-canary-PLAN.md
  - mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md
  - mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md
upstream_artifacts_reviewed:
  - mint-data-architecture-v1-02-event-log-CONTEXT.md (33 D-XX locked)
  - mint-data-architecture-v1-02-event-log-RESEARCH.md (implementation primitives, 1451 lines)
  - mint-data-architecture-v1-02-event-log-VALIDATION.md (Nyquist verify-command map)
description: Cross-AI peer review of Phase 02 (event-log + projection + DEK envelope) — 4 PLAN.md + CONTEXT + RESEARCH + VALIDATION reviewed by Gemini 2.5 Pro. Verdict: LOW overall risk, ready to execute. 1 MEDIUM + 3 LOW concerns; 3 actionable suggestions (zero-user prod gate, Docker dep docs, allowlist rationale).
---

# Cross-AI Plan Review — Phase 02 (event-log + projection)

> **Coverage caveat (0-trust §9.6)** : only 1 of 5 external CLIs delivered a review.
> - Gemini 2.5 Pro: ✓ complete review below.
> - Codex (gpt-5.3-codex): ✗ usage limit hit at 10:45Z, retry after 13:36 local. Prompt preserved at `/tmp/gsd-review-prompt-02.md` for an iter-2 re-run.
> - Claude: ⏭ skipped (current runtime, workflow §step1).
> - CodeRabbit / OpenCode: ✗ not installed.
>
> This file is iter-1. If Codex review is collected post-13:36, append it below and refresh the Consensus Summary.

---

## Gemini 2.5 Pro Review

### 1. Summary

The overall plan quality is exceptionally high, demonstrating a mature and rigorous approach to a complex, foundational data architecture migration. The four-wave structure (W0-W4) logically de-risks the project by front-loading prerequisites, proving the core path with a canary, choreographing the irreversible migration with explicit checkpoints, and ensuring a clean close-out. The plans are rooted in deep research that leverages existing, battle-tested primitives within the codebase, significantly reducing implementation risk. The validation strategy is comprehensive, mapping all 33 locked decisions to specific, automated tests. This phase is well-prepared and ready for execution with a very high degree of confidence.

### 2. Strengths

*   **Learning from Experience:** The plan explicitly incorporates lessons from past incidents, such as the Postgres-specific `BOOLEAN DEFAULT` bug (mitigated by D-20 lint and D-22 test harness) and issues with parallel execution (mitigated by D-18 sequential plan structure).
*   **Risk Mitigation Strategy:** The migration is handled with extreme care. The use of a 5-PR sequence, a feature-flagged dual-write period, a canary on a high-traffic fact (`monthly_gross_income`), and a dual-read window before cutover is a best-in-class approach to de-risking a "big-bang" cutover.
*   **Leveraging Existing Primitives:** The `RESEARCH.md` document correctly identifies that this is not a green-field crypto or schema build, but rather the wiring-together of existing, proven components like `key_vault.py`, `envelope.py`, and established Alembic migration patterns. This drastically reduces the surface area for new bugs.
*   **Comprehensive Validation:** The `VALIDATION.md` artifact is exemplary. Mapping every single one of the 33 design decisions (D-XX) to a concrete, automatable verification command provides an objective and complete definition of done.
*   **Clarity and Thoroughness:** The `CONTEXT.md`, `RESEARCH.md`, and `PLAN.md` files are meticulously detailed, locking down decisions, exploring trade-offs, and leaving very little ambiguity for the implementation phase. Counter-arguments are "steel-manned" and addressed, demonstrating a robust decision-making process.

### 3. Concerns

*   **MEDIUM: Contingency for "Zero Prod Data" Assumption.** The entire "big-bang" migration strategy (D-05) is predicated on executing before the first production user signs up. If there's any delay that results in even a small number of users on the old `SnapshotModel` schema, the backfill and cutover become significantly more dangerous. The plan lacks a clearly defined contingency or alternative strategy for this scenario.
*   **LOW: Migration Choreography Complexity.** With a 4-wave plan comprising multiple sub-plans and a 5-PR sequence, the operational complexity is high. While well-documented, it relies on perfect sequencing by the executing agent or developer. A misstep in the order of operations could lead to a broken state.
*   **LOW: Awkward Parity-Lint Allowlist (D-10/D-31).** The decision to promote the `profile_safe_fields_parity.py` lint to HARD mode in PR-3, *before* the 3 dead Flutter-only fields are removed in a later plan (PR-A3 in Plan 02-04), necessitates an allowlist. While a workable solution, it's a minor process smell to have a "hard" lint that contains known exceptions.
*   **LOW: Added Developer Friction.** The introduction of a mandatory real-Postgres test harness via `testcontainers-python` (D-22) is the correct technical choice for ensuring correctness, but it adds a Docker dependency to the development environment, which can introduce setup and maintenance friction.

### 4. Suggestions

*   **Add a "Zero User" Production Gate:** To mechanically enforce the critical "zero prod data" assumption, add a task to the beginning of Plan 02-03 (W2-W3 migration) to run a script that executes `SELECT COUNT(*) FROM users;` against the production database and fails the entire plan if the result is not `0`.
*   **Document Test Harness Dependency:** As part of Plan 02-01 (W0 prereqs), add a task to update the backend `README.md` or a `CONTRIBUTING.md` to clearly document the new requirement of having Docker installed to run the full backend test suite.
*   **Clarify Rationale for Lint Allowlist:** In the commit message and PR description for Plan 02-03 PR-3, explicitly state *why* the `--allowlist` is being introduced for the `profile_safe_fields_parity.py` lint, and reference the future plan/task (Plan 02-04 PR-A3) that will remove it. This will prevent future confusion.

### 5. Risk Assessment

**Overall Risk: LOW**

Justification: While a core data architecture migration is inherently a high-risk operation, the meticulous planning, risk mitigation, and validation strategies reduce the execution risk to LOW. The plan demonstrates a deep understanding of the problem domain and the existing codebase. Risks are not only identified but are proactively and robustly mitigated through technical controls (feature flags, canaries, lints, transactional writes) and process controls (sequential waves, checkpoints for irreversible actions). The primary remaining risk is not technical but operational: either a failure to adhere to the precise migration choreography or a change in the external environment that invalidates the "zero production data" assumption. Given the detailed nature of the plans, the risk of a technical failure during execution is minimal.

---

## Consensus Summary

> Only 1 reviewer to date (Gemini 2.5 Pro). « Consensus » re-computes once Codex review lands.

### Agreed Strengths (n=1)

- 4-wave structure with explicit checkpoints + canary on `monthly_gross_income` = best-in-class de-risking.
- VALIDATION.md mapping every D-XX → automated verify command rated « exemplary ».
- Reuse of `key_vault.py` / `envelope.py` / existing Alembic patterns minimises new-bug surface.
- Lessons-learned wiring (D-20 boolean lint, D-22 test harness, D-18 sequential structure) directly traces to prior incidents.

### Agreed Concerns (n=1)

- **MEDIUM** — « Zero prod data » assumption (D-05 big-bang strategy) has no documented contingency if a user signs up between W0 and W2-W3 cutover.
- **LOW** — Operational complexity of 4-wave × 5-PR choreography depends on perfect sequencing.
- **LOW** — `profile_safe_fields_parity.py` HARD-with-allowlist in PR-3 then allowlist-drop in Plan 02-04 PR-A3 is a process smell.
- **LOW** — `testcontainers-python` (D-22) adds Docker dependency to dev environment.

### Divergent Views

- N/A (single reviewer).

---

## Actionable Plan-Patch Candidates (planner consumption — `/gsd-plan-phase 02 --reviews`)

The following 3 suggestions are concrete enough to patch into the 4 PLAN.md files directly without further discussion:

1. **Plan 02-03 (W2-W3 migration) Task 0 — Zero-user prod gate.** Add a pre-flight task at the head of Plan 02-03 that runs `SELECT COUNT(*) FROM users` against Railway production and fails the entire plan if `> 0`. Mechanical defense for the D-05 big-bang precondition. → Wire as a new acceptance criterion in `mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md` PR-1 (FF infrastructure) `<verify>` block.
2. **Plan 02-01 (W0 prereqs) Task N — Docker dependency docs.** Add a sub-task to update `services/backend/README.md` (or `CONTRIBUTING.md`) documenting Docker as a new prereq for the full backend test suite (testcontainers-python harness, D-22). Closes the « new developer onboarding friction » LOW concern.
3. **Plan 02-03 PR-3 commit-message contract.** Add a hard requirement on the PR-3 commit message body + PR description to explicitly cite `profile_safe_fields_parity.py --allowlist` rationale + a link forward to Plan 02-04 PR-A3 (the allowlist-drop). Prevents post-merge confusion if Plan 02-04 is delayed.

None of the 3 suggestions challenge the foundational design (33 D-XX locked, ADR shipped). All 3 are surgical W0/W2-W3 plan amendments — none require a CONTEXT/RESEARCH/VALIDATION revision.

---

## Iter-2 Plan (when Codex review lands)

When Codex usage resets (≥ 13:36 local 2026-05-18) :

1. Re-run via the preserved prompt :

   ```bash
   cat /tmp/gsd-review-prompt-02.md | codex exec --skip-git-repo-check --sandbox read-only - > /tmp/gsd-review-codex-02.md 2> /tmp/gsd-review-codex-02.err
   ```

2. Append the Codex review as a new section below Gemini, then refresh « Consensus Summary » + « Actionable Plan-Patch Candidates » based on cross-reviewer agreement.

3. If Gemini's MEDIUM concern (zero-prod-data contingency) is echoed by Codex, escalate to HIGH and treat as a planning blocker before W2-W3 PR-3.

---

## 0-trust §9.6 Evidence + Caveat

**Evidence** :
- Gemini review raw output : `/tmp/gsd-review-gemini-02.md` (32 lines, full 5-section structure produced, exit code 0)
- Prompt fed : `/tmp/gsd-review-prompt-02.md` (4241 lines / 418 KB — PROJECT.md head + ROADMAP phase section + 4 PLAN.md + CONTEXT + RESEARCH + VALIDATION)
- Codex blocker : raw stderr at `/tmp/gsd-review-codex-02.err` ends with `ERROR: You've hit your usage limit. To get more access now, send a request to your admin or try again at 1:36 PM.`

**Caveat** :
- Only 1 reviewer of the 5 requested by `--all`. Independent-AI consensus pass for Phase 02 is INCOMPLETE pending Codex re-run.
- Gemini's MEDIUM concern is real and should be acted upon (zero-prod-data gate) regardless of whether Codex echoes it.
