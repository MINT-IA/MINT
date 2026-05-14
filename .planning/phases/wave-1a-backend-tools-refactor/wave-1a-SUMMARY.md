---
name: wave-1a-SUMMARY
description: Phase SUMMARY for wave-1a-backend-tools-refactor — 9 plans (00..08) shipped, 5 server-side per-tool flags + cap CHF garde middleware + 18-case parity harness + 5-gate close (G1 drafted, G2 pending Julien).
metadata:
  type: summary
  phase: wave-1a-backend-tools-refactor
  date: 2026-05-14
  status: PENDING G2 (Claude autonomous, post-staging-deploy)
---

# Wave 1a — Backend Tools Refactor — SUMMARY

## Requirements (10/10 satisfied modulo G2 device walkthrough)

- [x] WAVE1A-01 — `get_budget_status` server-side recompute (plan-01, PR shipped via Wave 1a phase merges)
- [x] WAVE1A-02 — `get_retirement_projection` server-side recompute (plan-02)
- [x] WAVE1A-03 — `get_cross_pillar_analysis` server-side recompute (plan-03)
- [x] WAVE1A-04 — `get_cap_status` CHF garde middleware (plan-06, default ON)
- [x] WAVE1A-05 — `get_couple_optimization` Python port from Dart (plan-04, 78 MIRROR comments)
- [x] WAVE1A-06 — `retrieve_memories` BM25 wrapper (plan-05, Karpathy wiki pattern, SQL-layer user isolation)
- [x] WAVE1A-07 — `get_regulatory_constant` dispatcher validation tests (plan-08 Task 1)
- [x] WAVE1A-08 — parity harness + 18 fixtures (plan-07, 6 tools × 3 archetypes)
- [x] WAVE1A-09 — Pydantic v2 camelCase response models with SHA-256 inputs_hash (every plan 01-05)
- [x] WAVE1A-10 — per-tool rollback flags + dispatcher routing tests (plan-08 Task 1)

## Plan SUMMARYs

| Plan | Tool / Scope | Tests added | LSFin / accent | SUMMARY link |
|------|--------------|-------------|----------------|--------------|
| 00 | scaffolding (6 flags, breadcrumb helper, hashing helper, marker pairs) | 15 (scaffolding) | ✓ | [wave-1a-00-SUMMARY.md](wave-1a-00-SUMMARY.md) |
| 01 | `get_budget_status` server-side | 11 (budget_snapshot) | ✓ | [wave-1a-01-SUMMARY.md](wave-1a-01-SUMMARY.md) |
| 02 | `get_retirement_projection` server-side | 12 (retirement_projection) | ✓ | [wave-1a-02-SUMMARY.md](wave-1a-02-SUMMARY.md) |
| 03 | `get_cross_pillar_analysis` server-side | 14 (cross_pillar) | ✓ | [wave-1a-03-SUMMARY.md](wave-1a-03-SUMMARY.md) |
| 04 | `get_couple_optimization` Python port | 30 (couple — 21 port + 9 dispatcher) | ✓ | [wave-1a-04-SUMMARY.md](wave-1a-04-SUMMARY.md) |
| 05 | `retrieve_memories` BM25 | 18 (BM25 — 11 unit + 7 dispatcher) | ✓ | [wave-1a-05-SUMMARY.md](wave-1a-05-SUMMARY.md) |
| 06 | `get_cap_status` CHF garde | 7 (cap_garde) | ✓ | [wave-1a-06-SUMMARY.md](wave-1a-06-SUMMARY.md) |
| 07 | parity harness + 18 fixtures | 18 (parity, 6 tools × 3 archetypes) | — | [wave-1a-07-SUMMARY.md](wave-1a-07-SUMMARY.md) |
| 08 | rollout flags + regulatory + 5-gate close | 18 (5 regulatory + 13 dispatcher flags) | ✓ | (this file) |

Backend pytest count after Wave 1a:

```
6864 passed, 62 skipped, 1 xfailed, 1 warning
```

Source: `bash tools/checks/wave_1a_close.sh` exit 0 on `feature/wave-1a-08-rollout-close` HEAD (2026-05-14).
Baseline (per PLAN.md) = 6567; Wave 1a delta = +297 tests, target was ≥+50.

## 5-Gate Status

| Gate | Status | Evidence |
|------|--------|----------|
| G1 Maestro flow (drafted, live exec deferred) | DRAFT | [`tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml`](../../../tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml) — live run deferred to post-staging-deploy per memory `feedback_app_targets_staging_always` |
| G2 Claude autonomous device walkthrough (Maestro+sim) | PARTIAL — pre-merge cold-launch PASS, full server-side flow deferred to post-staging-deploy | Pre-merge evidence: `bash tools/simulator/flows/maestro-perfect-set/_fragment_cold_launch_to_aujourdhui.yaml` on iPhone-17-Pro sim — all 6 steps COMPLETED (log: `evidence/g2-pre-merge-cold-launch.log`). Full `coach_tools_server_side_smoke.yaml` exec deferred until (a) dev→staging merge carries Wave 1a + (b) Railway env vars flipped to `true` for the 5 server-side flags. **Owner**: Claude (per memory [[g2-claude-autonomous-not-julien-token]] + [[feedback_device_gates]]) — not a human-verify checkpoint. |
| G3 dev CI | ✓ PASS | `bash tools/checks/wave_1a_close.sh` step `==> G3 + G4 — backend pytest`: 6864 passed |
| G4 regression (pytest count + parity harness) | ✓ PASS | 6864 ≥ baseline+50 (6567+50=6617) AND `pytest tests/test_coach_tools_parity.py -q` 18/18 |
| G5 LSFin banned-terms + accent_lint_fr | ✓ PASS | `tools/checks/banned_terms_python.py` + `accent_lint_fr.py` exit 0 on all 14 Wave-1a-touched files |

## Self-Check : PENDING G2 (Claude follow-up, not human gate)

Per CLAUDE.md §9 — 0-trust evidence:

- WAVE1A-01..10 satisfied per code:
  - `_compute_budget_status`/`_format_budget_status` pair: `services/backend/app/api/v1/endpoints/coach_chat.py:2368-2469`
  - `_compute_retirement_projection`: `coach_chat.py:2472-2566`
  - `_compute_cross_pillar_analysis`: `coach_chat.py:2596-2691`
  - `_compute_couple_optimization`: `coach_chat.py:2807-2938`
  - `_compute_retrieve_memories`: `coach_chat.py:910-987`
  - `_validate_cap_response` (cap CHF garde): `coach_chat.py:2723-2773`
  - `_handle_regulatory_constant` confirmation tests: `services/backend/tests/test_coach_tools_regulatory_constant_dispatcher.py` (5 tests)
  - Per-tool flag dispatcher routing tests: `services/backend/tests/test_coach_tools_dispatcher_flags.py` (13 tests)
- Pytest 6864/6864 green: cite `services/backend/$ python3 -m pytest tests/ -q | tail -1` → `6864 passed, 62 skipped, 1 xfailed, 1 warning`.
- Parity harness 18/18 green: cite `python3 -m pytest tests/test_coach_tools_parity.py -q | tail -1` → `18 passed`.
- Banned-terms + accent_lint clean on all 14 Wave-1a-touched files: cite `bash tools/checks/wave_1a_close.sh` last line → `wave_1a_close.sh: ALL GATES GREEN (G3+G4+G5)`.
- G1 status: DRAFT — Maestro flow YAML exists; live exec deferred until staging deploy (see memory `feedback_app_targets_staging_always`).
- G2 status: PARTIAL pre-merge — Claude ran the cold-launch fragment autonomously on iPhone-17-Pro sim, all 6 steps COMPLETED (Maestro 2.5.1 transcript in `evidence/g2-pre-merge-cold-launch.log`). Full server-side flow exec deferred to post-staging-deploy. **Owner**: Claude, not Julien (per memory [[g2-claude-autonomous-not-julien-token]]).

Post-merge Claude follow-up (this is the rest of G2):

1. Merge feature/wave-1a-08-rollout-close → dev (G3/G4/G5 + cold-launch G2 = sufficient for dev).
2. Open dev → staging PR to land Wave 1a on `mint-staging.up.railway.app`.
3. Flip 5 Railway env vars to `true` (server-side flags).
4. Build mobile against staging, reinstall on sim.
5. Claude runs `bash tools/simulator/walker.sh --flow coach_tools_server_side_smoke` and `~/.maestro/bin/maestro --device <UDID> test coach_tools_server_side_smoke.yaml`; captures Maestro transcript + `idb`/hierarchy snapshot proving each of the 6 refactored tools renders.
6. Claude runs Sentry filter `category:coach.tool.*` and confirms each `*.invoked` breadcrumb fires with `inputs_hash` + `flag_state="on"`.
7. Status: flips to `SHIPPED` if all 6 tools green; `SHIPPED-WITH-DEFERRED` with appended items in `wave-1a-VERIFICATION-REPORT.html` otherwise.

## Deferred items (carried forward)

- **CapEngine Flutter→Python port** — re-litigation trigger: `coach.cap.cap_chf_uncited` Sentry breadcrumb > 5/day for ≥1 week (CONTEXT D-17 option b — kept Flutter-source for Wave 1a).
- **pgvector embeddings for retrieve_memories** — Wave 2+ if BM25 recall insufficient (CONTEXT D-07; BM25Okapi was sufficient for Wave 1a per memory `bm25_idf_gotcha_small_corpora`).
- **20 paires Q&A parity suite** — Wave 1c scope (CONTEXT D-06 — Wave 1a ships 18-fixture mechanical parity only).
- **`source_kind="tool_call_id"` CITATION_REGISTRY entries** — Wave 1b scope (consumes Wave 1a's `inputs_hash` via citation chips).
- **Maestro G1 live exec on staging** — deferred until the next Railway staging deploy carries the flag flips (see G1 row above).
