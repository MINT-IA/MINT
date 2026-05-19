# Phase mint-data-architecture-v1-02-event-log-projection — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-18
**Phase:** mint-data-architecture-v1-02-event-log-projection
**Mode:** discuss (interactive, single-round bundle-confirm)
**Areas discussed:** Plan/wave granularity · `fact_event` schema concretes · D-MOB-03 buffer-and-link mechanics · D-12 SOFT→HARD promotion + Phase 02 G-gates

---

## Pre-discussion state

23 carry-forward decisions already locked in upstream ADR `2026-05-18-phase02-event-log-projection-panel-synthesis.md` (7-specialist panel + 3 Julien-locked calls, status `Decided`). Discussion scoped only to the 4 residual planner-relevant gray areas the ADR did not lock.

| Carry-forward source | Decisions absorbed |
|---|---|
| ADR Q1-Q7 | D-01 latency · D-02 KMS · D-03 DEK granularity · D-04 constants PIT · D-05 5-PR migration · D-06 Q6 CI · D-07 retention |
| ADR S12 design | D-08 composition pattern · D-09 2-PR sequence |
| ADR D-MOB-01..04 | D-10 drift fix · D-11 dead-COUP-04 close · D-12 audit extension · D-13 clean separation |
| ADR 4 carry-overs | D-14 user_id_hash plaintext drop · D-15 PII column hash · D-16 /privacy/delete count · D-17 cache invalidation |
| ADR W0 prereqs | D-18 4-plan structure · D-19 app-side projector · D-20 alembic_boolean_lint · D-21 codegen ts · D-22 pg fixture · D-23 pg_dump baseline · D-24 HMAC-pepper sweep |

---

## Area 1 — Plan/wave granularity

**Gray area:** ADR scoped W0 / W1 / W2-W4 by week buckets but did not lock plan count, PR count per plan, or dependency sequencing.

**Options considered:**

| Option | Description | Selected |
|---|---|---|
| 3 plans (W0 / W1 / W2-W4 collapsed) | Minimum granularity, broader PR scope per plan | |
| **4 plans (W0 / W1 / W2-W3 / W4)** | Matches Phase 01 4-wave shape, 5-PR migration as 1 plan | ✓ |
| 5 plans (W0 / W1 / W2 / W3 / W4) | Splits 5-PR migration sequence into 2 plans | |

**User's choice:** 4 plans, sequential, no parallelization (Phase 01 lesson per memory `feedback_no_nuke_worktree_with_running_agent` and `feedback_no_micro_pauses`).

**Notes:** S12 PR-1 lands within Plan 02-01 (W0) as separate PR ; S12 PR-2 lands in Plan 02-04 (W4 close-out). 5-PR migration in Plan 02-03 sequenced internally PR-1 → PR-5.

---

## Area 2 — `fact_event` schema concretes (p98 alembic)

**Gray area:** ADR locked PK composite + covering index + partition-ready 1-partition but did not lock `value_enc` JSONB shape, idempotency mechanism, or `confidence` JSONB granularity.

**Options considered:**

### `value_enc` shape
| Option | Description | Selected |
|---|---|---|
| Separate columns (`ct VARCHAR`, `iv VARCHAR`, `tag VARCHAR`, `algorithm VARCHAR`, `dek_id VARCHAR`) | Explicit, indexable | |
| **JSONB typed object via Pydantic v2 `EncryptedValue`** | Compact, future DEK rotation supported, indexable on dek_id | ✓ |
| Single bytea raw ciphertext + separate IV column | Database-native, smallest storage | |

### Idempotency
| Option | Description | Selected |
|---|---|---|
| **UNIQUE `(subject_type, subject_id, fact_type, source_id, recorded_at)` + projector sequence check** | DB-enforced, projector reads `latest_event_id` to skip duplicates | ✓ |
| App-level dedup via Redis SET | Fast but adds new dependency | |
| Upsert pattern (ON CONFLICT DO NOTHING) | Less explicit about retry semantics | |

### Partition declaration
| Option | Description | Selected |
|---|---|---|
| **Ship in p98 with `PARTITION BY HASH (subject_id) PARTITIONS 1`** | Zero perf cost on 1 partition, future split = no migration | ✓ |
| Ship un-partitioned, add partition migration later | Simpler p98, costlier future split | |
| Ship 16 partitions from day one | Premature optimization | |

### `confidence` JSONB
| Option | Description | Selected |
|---|---|---|
| **Full `EnhancedConfidence` 4-axis (`{c, a, f, u, score, enrichmentPrompts}`)** | Matches `swiss-brain.md` mandate | ✓ |
| Normalized subset (just `score`) | Smaller payload, loses 4-axis breakdown | |

**User's choice:** Confirmed all 4 recommendations as a bundle. D-26 / D-27 / D-28 / D-29 locked.

---

## Area 3 — D-MOB-03 anonymous-session buffer-and-link mechanics

**Gray area:** ADR said « anonymous sessions = buffer-and-link after first login » (Julien call) but did not lock buffer storage location, TTL, anonymous-session-ID generation strategy, or server-side correlation column.

**Options considered:**

### Buffer storage
| Option | Description | Selected |
|---|---|---|
| **Mobile SQLite (offline-capable, no backend ephemeral PII)** | DSAR-clean, privacy-preserving | ✓ |
| Backend ephemeral table (e.g., `anonymous_audit_buffer`) | Cheaper mobile bundle | |
| In-memory only (cleared on app kill) | Loses session across kills | |

### TTL
| Option | Description | Selected |
|---|---|---|
| 24h | Too aggressive for vacation users | |
| 7d | Matches Phase 01 D-07 soft-warn | |
| **30d** | Matches Phase 01 D-07 hard-refuse staleness ceiling | ✓ |
| Infinite | Storage growth risk | |

### Anonymous session ID
| Option | Description | Selected |
|---|---|---|
| Device fingerprint hash | Privacy-hostile (user can't escape) | |
| **UUID v7 per app install, persisted in SQLite** | Privacy-preserving (user can wipe to reset) | ✓ |
| New UUID per session | No continuity across sessions | |

### Link mechanism
| Option | Description | Selected |
|---|---|---|
| **Batch POST `/v1/audit/mobile-session-link` on first login** | Atomic, retry-safe via UNIQUE constraint | ✓ |
| Streaming per-row POST | More network round-trips | |
| Lazy server-side reconciliation | Loses control of write timing | |

**User's choice:** Confirmed all 4 recommendations as a bundle. D-30 locked.

---

## Area 4 — D-12 SOFT→HARD promotion + Phase 02 G-gates

**Gray area:** ADR said parity-lint promotion is « atomic with first migration » but did not lock which PR « first migration » means, nor did it enumerate the Phase 02 mechanical exit gates.

**Options considered:**

### D-12 SOFT→HARD timing
| Option | Description | Selected |
|---|---|---|
| Atomic with PR-1 schema introduction | Earliest signal, blocks Phase 02 itself | |
| Atomic with PR-2 dual-write FF-OFF | Premature (dual-write not validated yet) | |
| **Atomic with PR-3 read cut-over** | Latest safe window, parity provably tight | ✓ |
| Atomic with PR-5 legacy drop | Too late, drift sneaks past | |

### Phase 02 G3 dev CI mechanical-gate list
| Option | Description | Selected |
|---|---|---|
| **`alembic_boolean_default_lint` HARD + `declared_counters_must_fire` HARD + REVOKE UPDATE/DELETE assertion + Postgres-real migration test on every alembic touch** | Complete coverage | ✓ |
| Alembic boolean lint only | Misses counter + REVOKE coverage | |
| Postgres-real migration test only | Misses lint + REVOKE | |

### Phase 02 G2 device sign-off shape
| Option | Description | Selected |
|---|---|---|
| **Anonymous → cold-start → warm-resume → first login → buffered rows linked → continuous chain visible in admin** | Full D-MOB-03 path | ✓ |
| Just the canary fact end-to-end | Misses D-MOB-03 path | |

### G4 / G5 composition
| Option | Description | Selected |
|---|---|---|
| **G4 = pytest + 2 new test classes (projector idempotency + DEK shred opacity) ; G5 = LSFin + accent + ARB + constants drift HARD + HMAC-pepper site lint** | Complete | ✓ |
| Reuse Phase 01 G4/G5 verbatim | Misses Phase 02-specific tests | |

**User's choice:** Confirmed all 4 recommendations as a bundle. D-31 / D-32 / D-33 locked.

---

## Claude's Discretion

Captured in CONTEXT.md `<decisions>` `Claude's Discretion` subsection. Planner picks :
- pytest fixture scaffold (testcontainers-python vs Railway-staging-replica)
- `EncryptedValue` Pydantic model location (`models/` vs `schemas/`)
- Offline SQLite queue retry / backoff policy
- STAGING-DOWN-OVERRIDE label workflow gate mechanism (CODEOWNERS vs ruleset)
- `fact_current` covering index field order (re-validate via EXPLAIN)
- Feature-flag namespace for PR-2 dual-write toggle
- Mobile SQLite migration strategy (raw sqlite3 vs sqflite vs drift)

## Deferred Ideas

Captured in CONTEXT.md `<deferred>` section. Highlights :
- Phase 03 coach-extractor LLM gated on Phase 02 ship
- Phase 04 per-category sub-DEKs gated on EDÖB/granular-deletion trigger
- AWS KMS migration gated on > 10k users / first regulator inquiry / Railway FIPS attestation
- 8 planner deliverables (latency, bundle-size, battery-cost, fixture scaffold, etc.)
- 7 backlog items with explicit re-litigation triggers
