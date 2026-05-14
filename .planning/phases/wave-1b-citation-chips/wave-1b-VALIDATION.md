---
phase: wave-1b
slug: citation-chips
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-14
---

# Phase wave-1b — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `wave-1b-RESEARCH.md` §10 (Validation Architecture, Nyquist gate D-08 mirror).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (backend)** | pytest 7.x |
| **Framework (mobile)** | flutter_test (Dart) |
| **Config file** | `services/backend/pyproject.toml` + `apps/mobile/test/` |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/test_coach_citation/ tests/test_coach_breadcrumbs.py -q` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q && cd ../../apps/mobile && flutter test` |
| **Estimated runtime** | ~120 s backend + ~180 s flutter |

---

## Sampling Rate

- **After every task commit:** Quick run (backend slice OR Flutter slice depending on layer touched).
- **After every plan wave:** Full suite must be green.
- **Before `/gsd-verify-work`:** Full suite green + `tools/checks/wave_1b_close.sh` exit 0 + `tools/checks/validate_arb_parity.py` exit 0 + `tools/checks/accent_lint_fr.py` exit 0 on Wave-1b-touched files + `tools/checks/banned_terms_python.py` exit 0.
- **Max feedback latency:** ≤ 30 s for backend quick run, ≤ 60 s for Flutter slice.

---

## Per-Task Verification Map

> Populated by `gsd-planner` per plan. Each plan's `must_haves.truths` maps 1:1 onto a row here.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD by planner | ... | ... | WAVE1B-01..10 | ... | ... | ... | ... | ... | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

> Test scaffolding to land BEFORE per-feature plans (mirrors Wave 1a Plan 00 pattern).

- [ ] `services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` — stubs for WAVE1B-01 (6 registry entries × ≥3 assertions each)
- [ ] `services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` — stubs for WAVE1B-02 (grammar instruction renders for each tool)
- [ ] `services/backend/tests/test_coach_breadcrumbs.py::test_coach_citation_tool_call_id_emitted_5kwarg` — stubs for WAVE1B-03 (Sentry breadcrumb contract)
- [ ] `apps/mobile/test/widgets/coach/coach_citation_chips_section_test.dart` — stubs for WAVE1B-04 (chip renderer recognizes tool_call_id)
- [ ] `apps/mobile/test/widgets/coach/coach_citation_modal_test.dart` — stubs for WAVE1B-05 (tap-to-modal flow)
- [ ] `apps/mobile/test/goldens/coach_citation_chip_*.png` — golden snapshots for chip rendering (6 tools × default state)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Citation chip footer renders on real device in chat overlay | WAVE1B-04 + WAVE1B-05 | iOS rendering subtleties (font weight, contrast, tap-target 44pt) only visible on sim | Run Maestro flow `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` against staging build with `COACH_TOOL_SERVER_SIDE_*=true`; verify chip appears in coach response message; tap chip → modal opens with inputs_hash + tool name; pass screenshot to Julien for G2 sign-off (per CONTEXT D-05, G2 is Claude-autonomous Maestro+sim, not Julien token). |
| Railway env vars flipped to `true` in staging environment | WAVE1B-10 | Operational gate (cannot be CI-tested) | After dev→staging merge lands, run `railway variables --service mint-backend-staging` and confirm 5 `COACH_TOOL_SERVER_SIDE_*` keys = `true`; capture output in VERIFICATION-REPORT.html. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30 s (backend) / 60 s (Flutter slice)
- [ ] `nyquist_compliant: true` set in frontmatter (flip after planner populates Per-Task table)

**Approval:** pending
