# Phase 91 Plan 05 — Partial State (halted at Task 5.2 checkpoint)

**Halted:** 2026-05-09T20:05Z
**Reason:** Task 5.2 is a `checkpoint:human-verify` (blocking) per plan frontmatter `autonomous: false`. Julien on-brand sign-off required before continuation agent executes Tasks 5.3 + 5.4.

## Tasks completed (2/4)

| Task | Status | Commit | Output |
|------|--------|--------|--------|
| 5.1 — Run eval harness against Anthropic API for both models + generate comparison | DONE | `2822a87c` | `.planning/phases/91-mvp-extractor-v2/eval-evidence/{eval_haiku.json, eval_sonnet.json, eval_haiku.stdout.txt, eval_sonnet.stdout.txt, eval_comparison_raw.md, eval_comparison.md}` |
| 5.2 — Stage 3 narrator-model decision (D-01 + D-06) | **HALTED — checkpoint** | — | Awaiting Julien resume signal |
| 5.3 — Apply Stage 3 decision to config.py default + update test | NOT STARTED | — | Continuation agent |
| 5.4 — Maestro G1 strict 3-fact run on booted sim against staging | NOT STARTED | — | Continuation agent |

## Mechanical eval results

```
| Criterion             | Haiku | Sonnet | Ratio (H/S) |
|-----------------------|-------|--------|-------------|
| compliance            | 34/50 | 30/50  | 1.13        |
| doctrine              |  7/50 | 26/50  | 0.27        |
| banned_terms          | 43/50 | 44/50  | 0.98        |
| anti_extractor_leak   | 42/50 | 50/50  | 0.84        |
| calculator_grounded   | 44/50 | 47/50  | 0.94        |
| all_three_pass        |  5/50 | 21/50  | 0.24        |

STAGE_3_EVAL: FAIL  ratio=0.24  candidate_pass=5  baseline_pass=21
```

## Diagnostic summary

1. **Doctrine catastrophic** — Haiku 7/50, Sonnet 26/50 (ratio 0.27). Haiku ne route pas les chiffres vers `financial_core` (`numbers_traceable` + `tools_first` failures dominent).
2. **Anti-extractor leak structurel** — Haiku écrit `save_fact()` / `<function_calls>` dans la réponse user-facing 8 fois sur 13 fixtures `anti_extractor_leak` (Sonnet le fait 0/13). Le narrator-only prompt ne suffit pas à supprimer ce comportement chez Haiku 4.5.
3. **LSFin 0/12 chez Haiku** — chaque tentative de contre-argument cite le mot banni (« Non, X n'est pas garanti »), déclenchant la guard.

## Latency / cost shape (informational)

|   | Haiku | Sonnet | Ratio (S/H) |
|---|-------|--------|-------------|
| p50 latence (ms) | 3'887 | 9'425 | 2.42x |
| p95 latence (ms) | 6'526 | 14'841 | 2.27x |

Haiku est ~2.4x plus rapide. Mais avec un all_three_pass de 5/50 vs 21/50, le gain coût (-2.5%/turn) n'est pas exploitable. Per ADR-20260419-v2.8-kill-policy, fallback Sonnet = +54%/turn ceiling, Phase 91 ship anyway.

## Mechanical recommandation

`narrator=sonnet` per kill-policy fallback (ADR-20260419-v2.8). Mais D-06 mandate un 4e critère = jugement on-brand humain. Cette recommandation est mécanique uniquement.

## Awaiting Julien resume signal

Format attendu (un des deux):
- `narrator=haiku rationale="<2-3 sentences>"`
- `narrator=sonnet rationale="<2-3 sentences>"`

Le orchestrator passe ce signal au continuation agent qui exécute:
- **Task 5.3** — flip COACH_NARRATOR_MODEL default in config.py + update test_narrator_model_flag.py + Railway env update
- **Task 5.4** — Maestro G1 strict 3-fact on booted iPhone 17 Pro sim against staging Railway with COACH_DUAL_LLM_ENABLED=true + COACH_NARRATOR_MODEL=<winner>

## File pointers

- Polished comparison: `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_comparison.md`
- Raw harness compare: `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_comparison_raw.md`
- Per-model JSON: `eval_haiku.json` + `eval_sonnet.json` (50 records each, full per-fixture scoring)
- Stdout tee (HTTP 200 OK trail): `eval_haiku.stdout.txt` + `eval_sonnet.stdout.txt`

## Citation per CLAUDE.md §9.6

**Evidence:** commit `2822a87c` reachable from HEAD (`git log --oneline | head -3`); 6 files added under `.planning/phases/91-mvp-extractor-v2/eval-evidence/`; harness output `MODEL_EVAL: model=haiku all_three_pass=5/50` + `MODEL_EVAL: model=sonnet all_three_pass=21/50` printed to stdout (tee'd to `.stdout.txt` files); compare run output `STAGE_3_EVAL: FAIL ratio=0.24` printed to `eval_comparison_raw.md`.

**Caveat:** mechanical scoring only. D-06 4th criterion (Julien on-brand judgment on 10 spot-check fixtures) is the blocking gate. Tasks 5.3 + 5.4 not started. SUMMARY.md not written (per execute-plan protocol: SUMMARY only at full plan completion).
