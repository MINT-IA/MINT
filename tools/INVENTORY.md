# Tool Inventory — MINT (Phase 56 PR-3a, classification only)

> **Status :** Draft 2026-05-04 — classification proposed by Claude (Product Leader). All `RETIRE` and `PROMOTE` rows require Julien's review before any destructive action lands. PR-3b applies the validated decisions.

## Methodology

129 tools enumerated by `bin/tool-census.sh` against day-1 census state (4 active, 125 never; see [`56-VERIFICATION-REPORT.html`](../.planning/phases/56-tool-utilization-audit/56-VERIFICATION-REPORT.html)). Each classified into one of 4 actions:

| Action | Meaning | PR-3b consequence |
|---|---|---|
| `KEEP-active` | Used in current MINT workflow OR foundational | No-op |
| `KEEP-emergency` | Not invoked recently, but valuable when needed (debug, audit, autonomous loops) | No-op — surfaces via `bin/tool-census.sh --suggest "<task>"` |
| `PROMOTE` | Frequent multi-tool pattern → bundle into a MINT specialist (cap 3 max per Manus discipline) | Create new `mint-*` skill in PR-3b |
| `RETIRE` | No foreseen value or duplicate / canton-irrelevant | `git mv` to `.archive/skills/` with `RETIRED-2026-05-XX.md` justification in PR-3b |

Heuristic: when in doubt, classify `KEEP-emergency` rather than `RETIRE`. Cemeteries are worse than no skill, but premature retire is worse than dormant.

## Summary

| Category | Total | KEEP-active | KEEP-emergency | PROMOTE | RETIRE |
|---|---:|---:|---:|---:|---:|
| skills:mint | 10 | 10 | 0 | 0 | 0 |
| skills:gsd | 60 | 14 | 41 | 0 | 5 |
| skills:autoresearch | 11 | 0 | 10 | 1 | 0 |
| skills:superpowers (obra) | 14 | 14 | 0 | 0 | 0 |
| skills:kit | 1 | 1 | 0 | 0 | 0 |
| lints (tools/checks/) | 27 | 3 | 24 | 0 | 0 |
| scripts (scripts/) | 3 | 2 | 1 | 0 | 0 |
| bin (bin/) | 2 | 2 | 0 | 0 | 0 |
| mcp (.mcp.json) | 1 | 1 | 0 | 0 | 0 |
| **Total** | **129** | **47** | **76** | **1** | **5** |

Net effect of PR-3b: 5 retires + 1 new specialist → tool count goes 129 → **125** (the PROMOTE wraps existing tools without removing them). Visible *active* surface goes from 129 (or 4 in baseline) to **47 KEEP-active + 1 new specialist = 48 (37%)**; emergency tools remain reachable via `/census <task>`.

## skills:mint (10) — all KEEP-active

| Tool | Description (excerpt) | Action | Rationale |
|---|---|---|---|
| mint-flutter-dev | Flutter/Dart development for MINT mobile app | KEEP-active | Mandatory entry-point for `apps/mobile/` work |
| mint-backend-dev | Python/FastAPI backend development for MINT | KEEP-active | Mandatory entry-point for `services/backend/` work |
| mint-swiss-compliance | Swiss finance compliance and legal rules | KEEP-active | LSFin/LPP/LIFD source-of-truth — invoked any compliance question |
| mint-test-suite | Run + fix the MINT test suite | KEEP-active | Pytest + flutter test wrapper |
| mint-commit | Standardized git commit workflow | KEEP-active | Branch flow + Conventional Commits + Co-Authored-By |
| mint-review-pr | Staff engineer review of a diff | KEEP-active | Pre-merge review with Fix-First pattern |
| mint-office-hours | 8 questions de cadrage pre-feature | KEEP-active | HARD GATE pre-feature, anti-sycophancy |
| mint-retro | Retrospective quantifiée — git log analysis | KEEP-active | Weekly cadence, persists learnings |
| mint-phase-audit | Audit P8 Digital Twin phase post-coding | KEEP-active | Mechanical gate checks on completed phases |
| mint-audit-complet | Multi-team parallel audit (5 specialists) | KEEP-active | Cross-functional audit, runs periodically |

## skills:gsd (60)

GSD is the planning backbone (PROJECT.md → ROADMAP → milestones → phases). Most stay KEEP-active or KEEP-emergency. Five candidates retired below.

### KEEP-active (14) — daily workflow

| Tool | Action |
|---|---|
| gsd-plan-phase | KEEP-active — primary phase planning entry |
| gsd-execute-phase | KEEP-active — primary execution entry |
| gsd-discuss-phase | KEEP-active — adaptive Q&A pre-plan |
| gsd-progress | KEEP-active — frequent navigation |
| gsd-next | KEEP-active — auto-advance workflow |
| gsd-do | KEEP-active — freeform routing |
| gsd-fast | KEEP-active — trivial inline task |
| gsd-quick | KEEP-active — atomic-commit + skip optional |
| gsd-ship | KEEP-active — PR creation + review |
| gsd-pr-branch | KEEP-active — clean PR branch from .planning noise |
| gsd-add-todo | KEEP-active — capture from current context |
| gsd-check-todos | KEEP-active — list + select pending todos |
| gsd-note | KEEP-active — zero-friction idea capture |
| gsd-help | KEEP-active — workflow reference |

### KEEP-emergency (41) — valuable but not daily

| Tool | Action | Why emergency |
|---|---|---|
| gsd-debug | KEEP-emergency | 4-phase systematic debugging — invoked on incident |
| gsd-forensics | KEEP-emergency | Post-mortem for failed GSD workflows |
| gsd-resume-work | KEEP-emergency | Resume across context resets |
| gsd-pause-work | KEEP-emergency | Context handoff |
| gsd-thread | KEEP-emergency | Cross-session thread mgmt |
| gsd-health | KEEP-emergency | Diagnose + repair planning dir |
| gsd-update | KEEP-emergency | GSD framework updates |
| gsd-reapply-patches | KEEP-emergency | After GSD update |
| gsd-set-profile | KEEP-emergency | Switch model profile |
| gsd-settings | KEEP-emergency | Toggle workflow knobs |
| gsd-stats | KEEP-emergency | Project metrics dashboard |
| gsd-session-report | KEEP-emergency | Token usage + work summary |
| gsd-add-phase | KEEP-emergency | Add phase to milestone |
| gsd-insert-phase | KEEP-emergency | Decimal-numbered urgent phase |
| gsd-remove-phase | KEEP-emergency | Renumber subsequent phases |
| gsd-add-tests | KEEP-emergency | Generate tests from UAT |
| gsd-add-backlog | KEEP-emergency | Parking lot 999.x |
| gsd-review-backlog | KEEP-emergency | Promote backlog items |
| gsd-list-phase-assumptions | KEEP-emergency | Surface assumptions pre-plan |
| gsd-analyze-dependencies | KEEP-emergency | ROADMAP "Depends on" suggestions |
| gsd-research-phase | KEEP-emergency | Standalone phase research |
| gsd-validate-phase | KEEP-emergency | Retroactive Nyquist gaps fill |
| gsd-verify-work | KEEP-emergency | Conversational UAT |
| gsd-secure-phase | KEEP-emergency | Retroactive threat mitigation verification |
| gsd-ui-phase | KEEP-emergency | UI design contract |
| gsd-ui-review | KEEP-emergency | 6-pillar visual audit |
| gsd-audit-uat | KEEP-emergency | Cross-phase UAT outstanding |
| gsd-audit-milestone | KEEP-emergency | Milestone completion audit |
| gsd-complete-milestone | KEEP-emergency | Archive milestone |
| gsd-new-milestone | KEEP-emergency | Start new cycle |
| gsd-milestone-summary | KEEP-emergency | Onboarding summary |
| gsd-plan-milestone-gaps | KEEP-emergency | Close audit gaps |
| gsd-cleanup | KEEP-emergency | Archive completed phases |
| gsd-plant-seed | KEEP-emergency | Forward-looking trigger ideas |
| gsd-map-codebase | KEEP-emergency | Parallel mapper agents |
| gsd-docs-update | KEEP-emergency | Verified-against-code docs |
| gsd-review | KEEP-emergency | Cross-AI peer review |
| gsd-profile-user | KEEP-emergency | Behavioral developer profile |
| gsd-list-workspaces | KEEP-emergency | Active workspace status |
| gsd-new-workspace | KEEP-emergency | Isolated workspace creation |
| gsd-remove-workspace | KEEP-emergency | Cleanup |

### RETIRE (5) — duplicates or zero-value

| Tool | Action | Justification |
|---|---|---|
| gsd-join-discord | RETIRE | Marketing meta-skill, irrelevant to MINT execution. Discord onboarding belongs in Julien's bookmark, not in skill discovery surface. |
| gsd-new-project | RETIRE | MINT is a single project; new-project bootstrap is one-time and already executed. Zero foreseeable use. |
| gsd-manager | RETIRE | "Interactive command center" — duplicates `gsd-progress` + `gsd-next` workflow. Adds command surface without distinct value. |
| gsd-workstreams | RETIRE | Parallel workstream mgmt — superseded by git worktrees pattern Julien adopted (see worktree session 2026-05-04). Latent skill that creates ambiguity over which abstraction owns parallelism. |
| gsd-autonomous | RETIRE | "Run all remaining phases autonomously discuss→plan→execute" — too coarse for MINT's discipline-13 manual-decision-gates approach (CLAUDE.md). Risk of stamping decisions Julien expects to make. |

## skills:autoresearch (11)

Autonomous fix-loop skills (Karpathy-style: detect → fix → verify → repeat). Powerful but rarely fired in normal flow. Mostly emergency.

| Tool | Action | Rationale |
|---|---|---|
| autoresearch-i18n | **PROMOTE** | Hand-off identified this as the i18n-debt unblocker for Phase 55. Promote into a MINT specialist `mint-pre-flutter-push` (see PROMOTE proposals below) and keep the standalone for batch ratchets. |
| autoresearch-ux-polish | KEEP-emergency | Hardcoded colors / Navigator.push fixer — fires on UX-debt sweeps |
| autoresearch-quality | KEEP-emergency | Bug hunter via `flutter test` — gate for chat-AI release |
| autoresearch-test-generation | KEEP-emergency | Test factory for untested code |
| autoresearch-test-coverage | KEEP-emergency | Coverage auditor → feeds test-generation |
| autoresearch-prompt-lab | KEEP-emergency | Coach prompt optimizer (mechanical scoring) |
| autoresearch-privacy-guard | KEEP-emergency | PII scanner for logs/analytics/LLM prompts |
| autoresearch-navigation | KEEP-emergency | Orphan screens, navigator violations |
| autoresearch-coach-evolution | KEEP-emergency | Coach text optimizer |
| autoresearch-compliance-hardener | KEEP-emergency | Adversarial guardrail tests |
| autoresearch-calculator-forge | KEEP-emergency | Edge-case calculator scenarios |

## skills:superpowers (14, obra/superpowers) — all KEEP-active

These are foundational AI-collaboration skills (using-superpowers loads at session start). All stay.

| Tool | Action |
|---|---|
| using-superpowers | KEEP-active — auto-load at session start |
| brainstorming | KEEP-active — pre-feature exploration |
| writing-plans | KEEP-active — multi-step task planning |
| executing-plans | KEEP-active — separate-session execution |
| writing-skills | KEEP-active — skill authoring |
| dispatching-parallel-agents | KEEP-active — 2+ independent tasks |
| subagent-driven-development | KEEP-active — single-session subagent exec |
| using-git-worktrees | KEEP-active — isolation pattern (used today!) |
| systematic-debugging | KEEP-active — bug/test failure protocol |
| test-driven-development | KEEP-active — feature/bugfix pre-impl |
| verification-before-completion | KEEP-active — evidence before assertion |
| requesting-code-review | KEEP-active — pre-merge review |
| receiving-code-review | KEEP-active — feedback handling |
| finishing-a-development-branch | KEEP-active — branch completion routing |

## skills:kit (1)

| Tool | Action | Rationale |
|---|---|---|
| claude-code-discipline | KEEP-active | Loads the 14 disciplines (just installed PR-1) |

## lints (27, tools/checks/)

3 currently wired in `lefthook.yml`: `memory_retention.py`, `map_freshness_hint.py`, `lint_status_audit.py` (in `lefthook.discipline.yml`). The other 24 are intentionally dormant — Phase 34 GUARD-01 was to wire them; Phase 55 PR-1 will pick that up.

### KEEP-active (3) — currently wired

| Tool | Action |
|---|---|
| memory_retention.py | KEEP-active — pre-commit memory gate |
| map_freshness_hint.py | KEEP-active — pre-commit map hint |
| lint_status_audit.py | KEEP-active — pre-commit (kit overlay) |

### KEEP-emergency (24) — wired in Phase 55, dormant today

All other lints are 100% KEEP-emergency: they exist for activation in Phase 55 GUARD-01. Listing per spec:

| Tool | Action |
|---|---|
| accent_lint_fr.py | KEEP-emergency — Phase 55 wire |
| audit_artefact_shape.py | KEEP-emergency |
| claude_md_bracket.py | KEEP-emergency |
| claude_md_triplets.py | KEEP-emergency |
| flesch_kincaid_fr.dart | KEEP-emergency |
| landing_no_financial_core.py | KEEP-emergency |
| landing_no_numbers.py | KEEP-emergency |
| lefthook_self_test.sh | KEEP-emergency — meta-test |
| no_chiffre_choc.py | KEEP-emergency |
| no_e2ee_overclaim.py | KEEP-emergency |
| no_hardcoded_fr.py | KEEP-emergency |
| no_implicit_bloom_strategy.py | KEEP-emergency |
| no_legacy_confidence_render.py | KEEP-emergency |
| no_legal_admission_in_public_docs.py | KEEP-emergency |
| no_llm_alert.py | KEEP-emergency |
| regional_microcopy_drift.py | KEEP-emergency |
| route_registry_parity.py | KEEP-emergency |
| s0_s5_aaa_only.py | KEEP-emergency |
| screen_registry_parity.py | KEEP-emergency |
| screen_registry_three_way_parity.py | KEEP-emergency |
| sentence_subject_arb_lint.py | KEEP-emergency |
| sentry_capture_single_source.py | KEEP-emergency |
| verify_sentry_init.py | KEEP-emergency |
| wcag_aa_all_touched.py | KEEP-emergency |

## scripts (3, scripts/)

| Tool | Action | Rationale |
|---|---|---|
| smoke_staging_api.sh | KEEP-active | Smoke tests against Railway staging — runs frequently |
| check_pii_in_logs.py | KEEP-active | PII guard, also referenced by autoresearch-privacy-guard |
| setup-branch-protection.sh | KEEP-emergency | One-time setup, kept for re-runs after permissions changes |

## bin (2, bin/)

| Tool | Action |
|---|---|
| tool-census.sh | KEEP-active — Discipline 14 surface, just shipped |
| doctor.sh | KEEP-active — diagnostic for kit state |

## mcp (1, .mcp.json)

| Tool | Action |
|---|---|
| mint-tools | KEEP-active — `get_swiss_constants` / `check_banned_terms` / `validate_arb_parity` / `check_accent_patterns` |

## PROMOTE proposals (1 specialist, cap 3)

Only one new specialist proposed — others either over-bundled or duplicate existing workflow.

### `mint-pre-flutter-push` (proposed for PR-3b)

**Pattern detected :** Julien (and Claude) repeatedly invoke the same 3-tool sequence before pushing Flutter changes:

1. `python3 tools/checks/accent_lint_fr.py`
2. MCP `mint-tools` :: `check_banned_terms(text)` — LSFin scan over modified strings
3. `flutter analyze && flutter test` (via `mint-test-suite` or directly)

**Specialist would :** auto-detect changed files in `apps/mobile/lib/`, run all three in sequence, fail-fast on first violation, and emit a single PR-ready summary. Wraps `autoresearch-i18n` for any new hardcoded FR strings detected.

**Why not 2 more :**

- `mint-pre-backend-push` — tempting (pytest + check_pii_in_logs + ruff), but `mint-test-suite` already covers ~80% of this. Keep tools individual until pattern repeats more.
- `mint-discipline-doctor` (wraps `bin/doctor.sh + tool-census --underused + lint_status_audit.py`) — promotion deferred until Discipline 14 has been live long enough (1+ month) to validate the bundle. Premature.

## RETIRE proposals (5 skills) — all in `skills:gsd`

See gsd RETIRE table above. Each retiree gets a `RETIRED-2026-05-XX.md` justification in `.archive/skills/<name>/` in PR-3b. Reversal is `git mv` back.

Reasons summary:
1. `gsd-join-discord` — marketing meta, irrelevant to execution
2. `gsd-new-project` — single-project context, one-time use already exhausted
3. `gsd-manager` — duplicates `gsd-progress` + `gsd-next`
4. `gsd-workstreams` — superseded by git worktrees pattern (today's lesson)
5. `gsd-autonomous` — too coarse, conflicts with discipline-13 manual decision gates

## What this PR does NOT do

PR-3a is **classification-only**. PR-3b applies decisions:

- [ ] `git mv .claude/skills/gsd-{join-discord,new-project,manager,workstreams,autonomous} .archive/skills/`
- [ ] Add `.archive/skills/<name>/RETIRED-2026-05-XX.md` per retiree
- [ ] Create `.claude/skills/mint-pre-flutter-push/SKILL.md` with composition logic
- [ ] Re-run `bin/tool-census.sh` post-action — expected counts: Total 125, Active grows when specialist exercised
- [ ] Update `56-VERIFICATION-REPORT.html` with before/after numbers

## Quarterly re-census (Phase 56.1 follow-up)

Phase 56 deliverable list includes « Phase 56.1 créé pour follow-up trimestriel (re-census + retire dormant) ». Suggested cadence: every 3 months, run `/census` against active workstream, mark new entries as `KEEP-active`, demote unused `KEEP-active` to `KEEP-emergency`, retire skills dormant over 2 consecutive quarters.

## Sources

- `bin/tool-census.sh --json` (2026-05-04T15:22:11Z snapshot)
- `.claude/skills/*/SKILL.md` frontmatter descriptions
- `lefthook.yml` + `lefthook.discipline.yml` (lint wiring state)
- `.planning/phases/56-tool-utilization-audit/PLAN.md` (PR-3 spec)
- Memory `feedback_post_phase_panel_loop`, `MINT Product Mission` (decisive autonomous classification)
