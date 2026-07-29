---
phase: 01
slug: mint-production-readiness-audit-identify-top-blockers-to-fir
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-20
---

# Phase 01 — Validation Strategy

> Phase 01's output is a PLAN of audits (mapper docs + ROADMAP addendum + PROD-READINESS-V1.md), not shipped code. « Validation » here = how each audit finding is confirmed reproducible. Detailed finding-class verification matrix lives in `01-RESEARCH.md` §16. The planner MUST populate the per-task table below using that matrix as the source-of-truth.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | mixed — `pytest 7.x` (backend) + `flutter test` (mobile) + Maestro (sim) + `tools/checks/*.py` (lints) + `sentry-cli 3.3.5` (remainder triage) |
| **Config file** | `services/backend/pytest.ini` · `apps/mobile/analysis_options.yaml` + `pubspec.yaml` · `tools/simulator/walker.sh` · `~/.sentryclirc` |
| **Quick run command** | grep + targeted `--file` lint runs (< 5 s per finding) |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q` (~115s, **7264 passed** baseline) · `cd apps/mobile && flutter analyze && flutter test` · targeted Maestro flows |
| **Estimated runtime** | per finding ≤ 5s ; per sub-phase merge ≤ 180s ; phase close ≤ 600s |

---

## Sampling Rate

- **After every task commit:** Run the finding-class command cited inline in the per-task verify row (below). For audit tasks, that's typically a grep + a single lint or a Maestro flow.
- **After every plan wave:** Run the sub-phase's `/gsd-verify-work` — relevant finding-class commands + full pytest for backend touches + `flutter analyze && flutter test` for mobile touches.
- **Before `/gsd-verify-work` (phase gate):** All 6 mapper docs landed in `.planning/codebase/` + sub-phase entries written to ROADMAP + `.planning/backlog/PROD-READINESS-V1.md` committed.
- **Max feedback latency:** 5 seconds per finding ; 600 seconds for phase close.

---

## Per-Task Verification Map

> **Planner**: populate this table during plan creation. Each task in each PLAN.md must map to one finding class from `01-RESEARCH.md` §16 « Validation per finding-class » (boundary-integrity / coach-runtime / Sentry / i18n / archetype-gate / TestFlight / Maestro / banned-term / DSAR / trust-monitor / replay) AND cite the exact grep/cli/pytest command. Reference rows use the format below.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _TBD by planner_ | — | — | REQ-AUDIT-* | — | — | — | _see RESEARCH §16 for finding-class command_ | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Source-of-truth for commands:** `01-RESEARCH.md` §16 finding-class table. Copy the row's `Verification command` into the task's `Automated Command` cell; do NOT invent new commands.

---

## Wave 0 Requirements

Per `01-RESEARCH.md` §16 « Wave 0 Gaps » — the Phase 01 audit infra needs ZERO new test files at the phase level (every recipe re-uses existing tooling). Wave 0 gaps materialize **per sub-phase** in the ROADMAP addendum :

- [ ] `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml` — sub-phase 01.1 (hero-flow walkthrough), template in RESEARCH §1.3
- [ ] `services/backend/tests/coach_replay_corpus/v1/` — sub-phase 01.4 (40 fixtures, schema in RESEARCH §4.6)
- [ ] `tools/eval_narrator.py` extension to consume the replay corpus — sub-phase 01.4
- [ ] `tools/checks/banned_terms_arb.py` `LOCALE_RULES` extension (4 new lemma families × 6 locales) — sub-phase 01.6, hot item P0-2
- [ ] `services/backend/tests/test_privacy_dsar.py` `FactEventModel.query` assertion — sub-phase 01.7, hot item P0-3
- [ ] 4 adversarial Maestro flows under `tools/simulator/flows/maestro-perfect-set/` (refusal-bait, banned-term-bait, citation-missing, context-bloat regression) — sub-phase 01.10, templates in RESEARCH §6.2

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| G2 Julien device sign-off on hero flow (marge fiscale 3a annuelle) | REQ-AUDIT-01 « Hero flow works end-to-end on Julien's iPhone » | Sim ≠ device — the bar requires physical-device confirmation per CLAUDE.md §9 0-Trust 4-stage shipping pipeline | Julien runs the hero flow on his physical iPhone, confirms the cited number appears within 3 turns, says « ok » in chat. Citation: screenshot or chat-confirmation. |
| G2 Julien design sign-off on Gambarino italic Fontshare licensing for App Store | REQ-AUDIT-09 (DESIGN/VOICE compliance, P1-5 from RESEARCH §7.3) | License review is human-judgement | Julien reads Fontshare 400i license terms, confirms App Store republication permitted. |
| Re-litigation trigger verdict at end of sub-phase 01.10 | RESEARCH Open Question #4 | « did any of the 5 CONTEXT §11 re-litigation triggers fire during the audit » is a synthesis call | Sub-phase 01.10's `/gsd-verify-work` produces a single section in the close-out doc enumerating the 5 triggers + verdict (fired / not-fired / partial). |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s per finding ; < 600s for phase close
- [ ] `nyquist_compliant: true` set in frontmatter
- [ ] Per-task verification map populated from RESEARCH §16 finding-class matrix
- [ ] All 6 mapper docs (tech / arch / quality / boundary-integrity / coach-runtime / synthesis) landed in `.planning/codebase/`
- [ ] ROADMAP addendum entries written for each sub-phase
- [ ] `.planning/backlog/PROD-READINESS-V1.md` committed

**Approval:** pending
