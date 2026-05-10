# Phase 94: MVP-CITATION-GATE — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the auto-mode reasoning.

**Date:** 2026-05-10
**Phase:** 94-mvp-citation-gate
**Mode:** auto (Claude product-leader call per Julien's "tu es l'expert")
**Areas auto-decided:** A — Citation Format & Detection · B — Citation Source Registry · C — Retry-or-Fallback Flow · D — Banned-Claim List · E — Eval Pack + Maestro Flow · F — Performance & Wiring Budget · G — Migration & Feature Flag

---

## Gray Area A — Citation Format & Detection

| Option | Description | Selected |
|--------|-------------|----------|
| `{{cite:<key>}}` | Calc-first ADR §N1 wording — already used in Phase 93.5 bundle citation_allowlists | ✓ |
| `[citation:source_id]` | Legacy ROADMAP wording — not used elsewhere in the codebase | |
| Both formats accepted, parser normalizes | Half-measure that pays both costs (Karpathy #2 violation) | |

**Auto-choice rationale:** `{{cite:<key>}}` already lives in Phase 93.5 bundle citation_allowlist annotations. Aligning eliminates a translation layer. The legacy ROADMAP wording will be patched at Plan 94-01 time.

---

## Gray Area B — Citation Source Registry

| Option | Description | Selected |
|--------|-------------|----------|
| Pure-Python module `citation_registry.py` (Phase 95 replaces with `GroundingPack` JSON) | Karpathy #2 simplicity ; Phase 95 reshapes when DAG arrives | ✓ |
| YAML or JSON file as registry source-of-truth | Adds parse step ; less type-safe than Python `Mapping[str, CitationSource]` | |
| Database table | Premature — registry size ~50 keys ; pure code is faster + grep-able | |

**Auto-choice rationale:** Mirrors Phase 93.5 D-05/D-06 pure-Python frozen Pydantic pattern. Phase 95 (`GroundingPack`) replaces this module ; Phase 94 keeps it minimal.

---

## Gray Area C — Retry-or-Fallback Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Hard-cap retries=1 + templated fallback per ROADMAP success criterion #2 | Risk #2 mitigation ; deterministic budget cap | ✓ |
| Retries=2 with exponential reprompt | Doubles token cost ; ROADMAP flagged as risk | |
| No retries — fail-fast to fallback | Discards the productive 1-retry budget proven by Anthropic Citations API research | |

**Auto-choice rationale:** Locked by ROADMAP. Risk #2 (« retry loop blows token budget ») mitigation is hard-cap=1 ; not configurable.

---

## Gray Area D — Banned-Claim List

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse Phase 93.5 compliance-narrator banned-terms + ADD « affirmative claim with cited number » lint | DRY ; extends existing doctrine ; surgical | ✓ |
| Build new banned-claim file from scratch | Duplicates Phase 93.5 compliance bundle ; rot risk | |
| Outsource to LSFin compliance lawyer review | Out of scope for Phase 94 ; banned-list is iterative | |

**Auto-choice rationale:** CLAUDE.md §5 NEVER #5 + #8 already locked the no-promise doctrine. Phase 94 ADDS the "affirmative verb + cited number" red flag ("vous ferez 4%" rejected even with citation) per `_BANNED_TERMS_REMINDER` extension.

---

## Gray Area E — Eval Pack + Maestro Flow

| Option | Description | Selected |
|--------|-------------|----------|
| 50-fixture jsonl + `--gate={on,off}` flag in `eval_narrator.py` + Maestro flow | Mirrors Phase 91 + Phase 93.5-04 patterns ; already wired infrastructure | ✓ |
| Pytest-only eval (no Maestro) | Skips device-side citation rejection observation ; ROADMAP success criterion #4 explicitly requires Maestro | |
| LLM-as-judge eval | Anti-CLAUDE.md §9 (« using probabilistic tool to verify probabilistic output is the same as no verification ») | |

**Auto-choice rationale:** Mechanical jsonl + Maestro is the verified pattern. Adds `expected_gate_outcome` field per fixture (4 verdict types).

---

## Gray Area F — Performance & Wiring Budget

| Option | Description | Selected |
|--------|-------------|----------|
| Pure regex parser ≤50ms ; Sentry breadcrumb hygiene mirroring Phase 93.5 Wave 1 D-12 | Karpathy #2 ; total turn budget unchanged ; observability without PII leak | ✓ |
| Add NLP library (spaCy/regex+) for entity detection | Premature ; ~10MB import cost ; regex sufficient for CHF/%/legal articles | |
| Async/await citation lookup | Sync Python is fine ; registry is in-memory ; no I/O on hot path | |

**Auto-choice rationale:** Karpathy #2. Regex catches all 5 number families documented in D-02. No library needed.

---

## Gray Area G — Migration & Feature Flag

| Option | Description | Selected |
|--------|-------------|----------|
| `COACH_CITATION_GATE_ENABLED` env-gated flag, dual-path coexistence, 4-week soak before sunset | Mirrors Phase 91 + Phase 93.5 ; safe rollback ; soak metrics drive flip-on | ✓ |
| Big-bang merge, no flag | High risk ; no rollback path ; ROADMAP Risk #2 not mitigated | |
| Flag with no soak metric | Wastes the staging soak window opportunity ; can't measure fallback rate | |

**Auto-choice rationale:** Pattern locked by Phase 91 + 93.5. Sunset trigger: 4-week soak with `coach.citation_gate.fallback` rate ≤2% OR Phase 96 close, whichever later.

---

## Claude's Discretion (NOT locked)

- Exact `CITATION_REGISTRY` key list (will iterate during Stage 3 eval)
- Tokenizer choice for retry-budget check (recommend `count_tokens_cached` from 93.5-04)
- Wrapper vs middleware for gate insertion (recommend wrapper per Karpathy #3)
- Per-fixture test file structure under `tests/test_citation_gate/`
- Maestro flow exact assertion format

## Deferred Ideas

- Multi-turn citation continuity → Phase 96
- Per-user citation provenance dashboard → Phase 96+
- Cross-language citation keys (DE/EN/IT/ES/PT) → Phase 99+
- `GroundingPack` JSON contract → Phase 95
- Backend calc-parity port → backlog 999.4 (conditional)
- `mint-wiring-verifier` full agent → backlog 999.3 (conditional)
- Audit Proposal B (multi-agent runtime) → Phase 97-98 post-TestFlight
