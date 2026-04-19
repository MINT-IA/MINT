---
phase: 30
plan: 02
subsystem: milestone-closeout
tags: [device-gate, bilingual-checklist, performance-report, legal-signoff, milestone-v2.7, closeout]
requirements: [GATE-01, GATE-02]
dependency_graph:
  requires: [30-01]
  provides:
    - docs/DEVICE_GATE_V27_CHECKLIST.md (bilingual FR/EN, 36 checkboxes, 258 lines)
    - docs/PERFORMANCE_REPORT_V27_TEMPLATE.md (cost/latency/adversarial/budget protocol)
    - docs/LEGAL_SIGNOFF_V27.md (Walder Wyss / MLL Legal template, 10-row decisions table)
    - docs/MILESTONE_V27_SUMMARY.md (v2.7 shipped report, v2.8 proposal)
    - .planning/MILESTONES.md v2.7 section (new entry, PENDING_DEVICE_GATE)
    - STATE.md awaiting_device_gate status
    - ROADMAP.md v2.7 amber + Phase 30 row 2/2 + v2.8 section
    - REQUIREMENTS.md GATE-01/02 'code ready, awaiting device walkthrough'
  affects:
    - Milestone v2.7 close — gated on Julien's creator-device walkthrough
    - Prod feature-flag flips (DOCUMENTS_V2_ENABLED, PRIVACY_V2_ENABLED) blocked until legal sign-off
    - Next milestone v2.8 "La Confiance" — scope trigger
tech-stack:
  added: []
  patterns:
    - Bilingual (FR first, EN italic) checkbox format — every check readable by 2 audiences
    - <PENDING_DEVICE_GATE> placeholder pattern — no YYYY-MM-DD stamped anywhere
    - Signed empty commits (git commit -s --allow-empty) as device-gate approval protocol (T-30-10)
    - Section-based REQ coverage map appendix (traces 25 REQs to checklist sections)
key-files:
  created:
    - docs/DEVICE_GATE_V27_CHECKLIST.md
    - docs/PERFORMANCE_REPORT_V27_TEMPLATE.md
    - docs/LEGAL_SIGNOFF_V27.md
    - docs/MILESTONE_V27_SUMMARY.md
    - .planning/phases/30-device-gate/30-02-SUMMARY.md
  modified:
    - .planning/ROADMAP.md (v2.7 amber, Phase 30 2/2 complete, v2.8 section)
    - .planning/STATE.md (milestone_status, progress 100%, P02 metrics, decisions)
    - .planning/REQUIREMENTS.md (STAB-* checked, GATE-01/02 awaiting, traceability)
    - .planning/MILESTONES.md (v2.7 section prepended)
decisions:
  - No YYYY-MM-DD stamped anywhere in v2.7 docs — <PENDING_DEVICE_GATE> placeholder until Julien signs iPhone + Android + legal commits
  - Checklist bilingual FR/EN: FR checkbox, EN italic line underneath — reduces visual noise vs parallel columns
  - iPhone section covers 18 items (> 12 required), Android 10 (= min), plus pre-flight (8), performance (1), legal (1), acceptance (1) = 36 total checkboxes > 25 min
  - Checklist appendix maps every v2.7 REQ-ID (25 of them) to the checklist section proving coverage
  - Milestone close deferred to a future /gsd-execute-plan 30-02 resume (Task 4) OR manual placeholder replacement by Julien
  - v2.8 working title "La Confiance" chosen for thematic continuity with v2.7's privacy work (Privacy Nutrition Label + Data Vault + Trust Mode + Graduation Protocol v1)
metrics:
  duration_minutes: 25
  completed_date: 2026-04-15
  task_count: 2
  file_count: 9
  tests_added: 0
---

# Phase 30 Plan 02: Device-gate closeout + milestone summary — Summary

Produces the human-facing artefacts that close milestone v2.7: bilingual device-gate
checklist (iPhone + Android + performance + legal + acceptance, 36 checkboxes in
258 lines), performance report template (cost/latency/adversarial/budget-tier protocol
on Railway staging), legal sign-off template (10-row decisions table for Walder Wyss /
MLL Legal), milestone summary (v2.7 shipped report aggregating 4 phases, 25 REQs,
~315 new tests, ~175 commits, v2.8 "La Confiance" proposal), and coordinated updates
to STATE / ROADMAP / REQUIREMENTS / MILESTONES — all with `<PENDING_DEVICE_GATE>`
placeholders until Julien signs the iPhone + Android walkthrough.

## Tasks delivered

| # | Task                                                                      | Commit     | Files |
|---|---------------------------------------------------------------------------|------------|-------|
| 1 | Device gate checklist + performance report template                       | `f7850dca` | 2     |
| 2 | Legal signoff + milestone summary + STATE/ROADMAP/REQ/MILESTONES updates  | `18b71085` | 6     |
| 3 | **BLOCKING human-verify checkpoint** — see "Awaiting" section below       | (pending)  | (pending) |
| 4 | Milestone close (stamp YYYY-MM-DD, final commit)                          | (pending — resumes after Task 3) | (pending) |

## What Was Built

### `docs/DEVICE_GATE_V27_CHECKLIST.md` (258 lines, 36 checkboxes)

Bilingual FR/EN walkthrough structured as:

- **Pre-flight (8)** — build freshness, staging health, feature flags, `ANTHROPIC_API_KEY`,
  iOS build protocol per `feedback_ios_build_macos_tahoe.md` (no `flutter clean`,
  no Podfile.lock delete), Sentry dashboard, iPhone connected, Android ready.
- **Section A — iPhone walkthrough, GATE-01 (18 checks)** across 6 sub-sections:
  - A.1 Sophie scenario: cold start auth, pavé intent → MSG1, MSG2 < 5s, MSG3 LPP upload via
    VisionKit streaming UX, MSG4 "demain" + J+1 memory restored.
  - A.2 Document pipeline: multi-page tax PDF + ExtractionReviewSheet snap, photo-repas
    local reject, cert Lauren third-party chip session-only, screenshot banking narrative.
  - A.3 Commitment: "Rappelle-moi en mai" → CMIT-01/02.
  - A.4 Privacy Center: revoke vision_extraction → crypto-shred readable check.
  - A.5 Stability: force 429 → Sonnet→Haiku + degraded chip; token budget hard-cap;
    SHA256 idempotency re-upload; quit app mid-stream.
  - A.6 Language swap fr → de on German insurance fixture.
- **Section B — Android walkthrough, GATE-02 (10 checks)** — ML Kit scanner + local reject
  + bottom-sheet snap + language swap + hard-cap + Privacy Center + J+1 memory + back button.
- **Section C — Performance (1 check)** — links to template.
- **Section D — Legal sign-off (1 check)** — links to signoff doc.
- **Section E — Acceptance** — three signed empty commits
  (`device-gate(v2.7): iPhone approved` / `Android approved` / `legal-signoff(v2.7)`).
- **Blockers table** — empty, filled inline during walkthrough.
- **Appendix** — REQ coverage map tracing each of the 25 v2.7 REQ-IDs to a checklist section.

Every checkbox: FR first, EN italic below — no parallel columns (visual noise), no
translated redundancy. Anti-shame doctrine preserved (degraded chip italic textSecondary,
never error red).

### `docs/PERFORMANCE_REPORT_V27_TEMPLATE.md`

Protocol for filling 7 days after device gate:
- **Cost** — Anthropic Console Usage CSV + Sonnet `$3/$15 per 1M` + Haiku `$1/$5 per 1M`
  math + per-idempotency-key aggregation; red flag if single doc > $0.15.
- **Latency** — Redis `coach:metrics:*` hash + nearest-rank p95 (same method as 30-01
  golden aggregator); first SSE event < 300 ms, done < 10 s.
- **Adversarial** — 7 injection fixtures + VisionGuard block assertion + Sentry leak check.
- **Budget tier distribution** — `normal > 90% / soft_cap < 8% / hard_cap < 2%`.
- **Report block** — fill-in form with PASS|FAIL thresholds for each metric.

### `docs/LEGAL_SIGNOFF_V27.md`

10-row decisions table:
1. DPA annex signing (Anthropic + Bedrock EU)
2. Privacy policy v2.3 wording
3. Anthropic sub-processor disclosure (US + EU via Bedrock)
4. Bedrock EU migration timeline
5. Consent receipt wording (4 ISO 29184 purposes)
6. Retention: profile_facts = account + 6 months post-deletion
7. Third-party document disclosure wording
8. Image masking pre-Vision policy (29-06 two-stage masker)
9. LSFin "éducatif pas décisionnel" wording
10. FINMA circular compatibility

Plus firm selector (Walder Wyss / MLL Legal / other), reviewer/bar-number fields,
blockers ledger (with fix owner + target date + resolution commit), Julien's
sign-off + signed-commit protocol.

### `docs/MILESTONE_V27_SUMMARY.md`

Comprehensive shipped report:
- Phase-by-phase breakdown (27 Stabilisation, 28 Pipeline, 29 Privacy, 30 Device Gate)
  mapping all 25 REQs to implementation.
- Metrics aggregate: ~32 tasks, ~260 files, ~315 new tests, ~175 commits since v2.6.
- **10 deferred follow-ups** for v2.8: TokenBudget.kind tagging, RAG → LLMRouter, JSONB
  GIN index, Presidio NER, default scanner flip, encrypted-PDF VisionGuard one-liner,
  BEDROCK_EU flip, MASK_PII_BEFORE_VISION enable, DPA lawyer review, real-Vision
  cassette recorder.
- Known carve-outs (test_agent_loop/test_docling pre-existing, encrypted PDF quirk).
- **v2.8 "La Confiance" proposal** — 4 themes (Privacy Nutrition Label + Data Vault +
  Trust Mode + Graduation Protocol v1), scope TBD via `/gsd-start-milestone v2.8`.

### Planning file updates

- **STATE.md**: `milestone_status: awaiting_device_gate`, `progress.percent: 100`,
  `completed_plans: 13`, Phase 30 P02 metrics row, Phase 30-02 decisions, session
  `stopped_at` updated, resume file pointer → checklist.
- **ROADMAP.md**: v2.7 bullet 🚧 → 🟡 (amber, `<PENDING_DEVICE_GATE>`); Phase 30 row
  `1/2 In Progress` → `2/2 Complete (code) — awaiting device walkthrough`; new
  v2.8 section at tail.
- **REQUIREMENTS.md**: STAB-01..05 checkboxes ticked; GATE-01/02 marked
  `[~] code ready, awaiting device walkthrough`; traceability table fully expanded
  (each v2.7 REQ mapped to delivering plan); coverage footnote updated to
  "25/25 code-complete".
- **MILESTONES.md**: v2.7 section prepended with full phase summary, known carryover,
  v2.8 pointer; shipped date = `<PENDING_DEVICE_GATE>`.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written, with one scope interpretation:

**Scope clarification (not a deviation):** Plan Task 3 is a **blocking** human-verify
checkpoint and Task 4 (stamp shipped date) executes only AFTER Julien returns `approved`.
Per the plan's own instructions (`checkpoint-human-verify (90%)` pattern), the executor
stopped after Task 2 and emitted the checkpoint message. Task 4 will be executed by a
future resume agent once Julien has signed the three approval commits (iPhone, Android,
legal). This is the designed flow, not a deviation — see `<sequential_execution>` and
plan's own Task 3 `resume-signal` specification.

### Rule-3 Automation before verification

Plan checkpoint protocol required verification environment readiness. Checklist
pre-flight section embeds the automation prerequisites (build protocol, flag endpoints,
Sentry open, `curl /healthz`) so the human walkthrough starts from a known-good state.
No additional server-startup automation was needed because staging is already
continuously running.

### CLAUDE.md compliance

- No banned terms introduced ("garanti", "optimal", "conseiller", "parfait" as absolutes) —
  verified by source scan.
- Anti-shame doctrine preserved in checklist A.5: "degraded chip `textSecondary` italic,
  never error red".
- French accents respected throughout (é, è, ê, à, ç).
- Non-breaking space `\u00a0` not inserted into checklists since they're dev docs, not
  user-facing copy (per CLAUDE.md §7 "user-facing text" scope).
- Bilingual format serves the actual audience: Julien (FR) executes, any future auditor
  (EN) can read — matches "Inclusivité + Swiss context" doctrine.

## Authentication gates

None for the code half. Ahead (in Task 3 checkpoint resume):
- `ANTHROPIC_API_KEY` access on Railway staging — checklist pre-flight item, not blocking
  this plan.
- Legal session requires Julien to book Walder Wyss / MLL Legal externally — out-of-code
  scope per plan's `user_setup` frontmatter.

## Known follow-ups (handed to v2.8)

All 10 follow-ups documented in `docs/MILESTONE_V27_SUMMARY.md` §3. Highlights:

1. **DPA lawyer review completion** — session booking, fill `docs/LEGAL_SIGNOFF_V27.md`.
2. **Encrypted-PDF VisionGuard overwrite one-liner** (30-01 carryover).
3. **Real-Vision cassette recorder** before 30-01 CI graduation (2026-04-28).
4. **BEDROCK_EU_PRIMARY_ENABLED flip** after 2 weeks of shadow parity metrics.
5. **MASK_PII_BEFORE_VISION enable** after fixture-corpus validation.

## Self-Check

Verified files exist:
- FOUND: docs/DEVICE_GATE_V27_CHECKLIST.md
- FOUND: docs/PERFORMANCE_REPORT_V27_TEMPLATE.md
- FOUND: docs/LEGAL_SIGNOFF_V27.md
- FOUND: docs/MILESTONE_V27_SUMMARY.md
- FOUND: .planning/phases/30-device-gate/30-02-SUMMARY.md
- MODIFIED: .planning/ROADMAP.md
- MODIFIED: .planning/STATE.md
- MODIFIED: .planning/REQUIREMENTS.md
- MODIFIED: .planning/MILESTONES.md

Verified commits exist:
- FOUND: f7850dca (Task 1 — checklist + perf template, 2 files + 377 ins)
- FOUND: 18b71085 (Task 2 — legal + summary + 4 planning updates, 6 files + 392 ins)

Verified checklist meets plan thresholds:
- 258 lines ≥ 180 required
- 36 top-level `- [ ]` checkboxes ≥ 25 required
- 18 iPhone checks ≥ 12 required
- 10 Android checks = 10 minimum
- 25 REQ-IDs mapped in appendix coverage table

Verified plan-defined `<automated>` invariants:
- `test -f docs/DEVICE_GATE_V27_CHECKLIST.md` → yes
- `test -f docs/PERFORMANCE_REPORT_V27_TEMPLATE.md` → yes
- `test -f docs/LEGAL_SIGNOFF_V27.md` → yes
- `test -f docs/MILESTONE_V27_SUMMARY.md` → yes
- `grep -c "GATE-0" .planning/REQUIREMENTS.md` ≥ 4 → yes (GATE-01, GATE-02, GATE-03, GATE-04 appear multiple times)
- `grep -q "v2.7.*Shipped\|v2.7.*shipped\|🟡 \*\*v2.7" .planning/ROADMAP.md` → yes (`🟡 **v2.7` matches)

## Self-Check: PASSED

## Known Stubs

Two intentional stubs — both documented, both gated on human action:

1. **`<PENDING_DEVICE_GATE>` placeholder** in ROADMAP.md / STATE.md / MILESTONES.md /
   MILESTONE_V27_SUMMARY.md for the shipped date. **Intentional** — replaced by real date
   only after Julien signs iPhone + Android + legal commits. Future plan: Task 4 of this
   plan (runs after checkpoint resume) OR manual find-replace.

2. **Empty Blockers table** in `docs/DEVICE_GATE_V27_CHECKLIST.md`. **Intentional** —
   filled inline by Julien during walkthrough. If any P0 finding appears, a gap-closure
   plan (e.g., 30-03) must precede milestone close.

## Threat Flags

None. All new docs are human-facing markdown in `docs/` and planning metadata updates.
No new endpoints, auth paths, file-access patterns, or schema changes introduced.

Existing threat dispositions (from plan's `<threat_model>`) are honoured:
- **T-30-10 (Repudiation)** — mitigated by signed empty commits protocol documented
  in checklist Section E.
- **T-30-12 (Tampering — milestone close without walkthrough)** — mitigated by
  `<PENDING_DEVICE_GATE>` placeholder; Task 4 (stamp) gated on Task 3 (checkpoint);
  checkpoint blocking.
- **T-30-13 (EoP — premature prod flag flip)** — ROADMAP now explicitly shows v2.7 as
  amber 🟡 awaiting gate; legal signoff template lists prod-rollout blockers.

---

## CHECKPOINT REACHED — awaiting Julien's device walkthrough

**Type:** `human-verify` (blocking)
**Plan:** 30-02
**Progress:** 2/4 tasks complete (code half done)

### Completed Tasks

| Task | Name                                                   | Commit     | Files                                                                                 |
| ---- | ------------------------------------------------------ | ---------- | ------------------------------------------------------------------------------------- |
| 1    | Device-gate checklist + performance report template    | `f7850dca` | docs/DEVICE_GATE_V27_CHECKLIST.md, docs/PERFORMANCE_REPORT_V27_TEMPLATE.md            |
| 2    | Legal signoff + milestone summary + planning updates   | `18b71085` | docs/LEGAL_SIGNOFF_V27.md, docs/MILESTONE_V27_SUMMARY.md, ROADMAP.md, STATE.md, REQUIREMENTS.md, MILESTONES.md |

### Current Task

**Task 3:** Blocking human-verify checkpoint — Julien walks iPhone + Android + books legal session.
**Status:** Awaiting verification.

### How to verify

1. **iPhone walkthrough** (GATE-01):
   - Build per `feedback_ios_build_macos_tahoe.md` — **NEVER** `flutter clean`, **NEVER**
     delete `Podfile.lock`. Use the 3-step no-codesign → xcodebuild → devicectl protocol.
   - `flutter run --release -d <iphone_device_id>` OR install from DerivedData
   - Work through every iPhone checkbox (18) in `docs/DEVICE_GATE_V27_CHECKLIST.md` section A
   - Fill Blockers table inline with severity + fix plan per finding
   - **≥ 1 P0 finding → STOP, do NOT commit approval, open 30-03 gap-closure plan**

2. **Android walkthrough** (GATE-02):
   - Pixel 7 Pro emulator API 34+ OR physical Android device
   - Work through Android section (10 checkboxes)
   - Same P0 rule applies

3. **Performance measurement** (7 days after staging traffic):
   - Fill `docs/PERFORMANCE_REPORT_V27_TEMPLATE.md` per its protocol
   - Avg cost < $0.05/doc, p95 < 10s, 0 injection leaks, budget tiers healthy

4. **Legal sign-off** (external session):
   - Book Walder Wyss / MLL Legal session
   - Review DPA annex + privacy policy v2.3 + consent receipts + Bedrock EU disclosure
   - Fill `docs/LEGAL_SIGNOFF_V27.md` decisions table (10 rows)
   - Resolve every blocker before flipping prod flags

5. **Approval commits:**
   ```bash
   git commit --allow-empty -s -m "device-gate(v2.7): iPhone approved — all GATE-01 checks green"
   git commit --allow-empty -s -m "device-gate(v2.7): Android approved — all GATE-02 checks green"
   git commit --allow-empty -s -m "legal-signoff(v2.7): avocat review complete, no blockers"
   ```

6. Then resume Task 4 (stamp YYYY-MM-DD + final commit) by running:
   ```
   /gsd-execute-plan 30-02
   ```
   OR manually find-replace `<PENDING_DEVICE_GATE>` → today's date in:
   - `docs/MILESTONE_V27_SUMMARY.md`
   - `.planning/ROADMAP.md`
   - `.planning/STATE.md`
   - `.planning/MILESTONES.md`

   Then commit with Co-Authored-By trailer per CLAUDE.md.

### Awaiting

- `approved` — all checks green, legal cleared, performance within budget → Task 4 executes
- Bullet list of findings (P0/P1/P2) — each P0 or P1 triggers a gap-closure plan before resume
