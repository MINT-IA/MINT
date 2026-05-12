---
description: Julien-validated 5-tier sequenced plan for preventing « production-only » regressions (local-vs-prod environment divergence). L1 mechanical lints shipping NOW per incident ; L2 Postgres alembic dry-run lands in Phase 97.5 R2 ; L3 pytest matrix R4 or v2.10 ; L4+L5 deferred to Phase 98+.
type: decision
phase: 97-97.5
authority: julien-go-2026-05-12T19:50Z
status: Decided
created: 2026-05-12
---

# ADR — Regression-prevention L1-L5 sequencing (Julien 2026-05-12T19:50Z)

## Context

Two production-only regressions today :

1. **2026-05-12 morning** : iOS entitlement (`com.apple.developer.associated-domains`) added without matching provisioning profile update → TestFlight build failed at xcodebuild archive. Cost : 2 emergency PRs (#567 revert + #568 sync), ~30 min outage of the ship pipeline.
2. **2026-05-12 11:14Z** : alembic revision_id `p97_snapshots_fk_and_server_defaults` (36 chars) overflowed PostgreSQL `alembic_version.version_num` VARCHAR(32) → Railway staging container failed startup → 502 to all requests including `/api/v1/health` for ~35 min. Cost : 2 emergency PRs (#575 hotfix + #576 sync).

Common pattern : **local SQLite + flutter analyze tolerate what PostgreSQL + Apple Developer portal refuse**. The defect class is « local-vs-prod environment divergence ». Without a mechanical gate at PR time, these defects only surface in production.

## Decision

5-tier sequenced response, prioritised by leverage and coupled to the existing v2.9 ship gate timeline :

| Tier | Mechanism | Cost | When | Coverage |
|---|---|---|---|---|
| **L1** | Mechanical lints, one per incident class | ~1h per lint | **NOW** (continuing) | Very narrow, 100% blocking at PR-time for the covered class |
| **L2** | Single GitHub Actions job spinning up `postgres:15` container + `alembic upgrade head` against it on every PR | ~1 day to wire | **Phase 97.5 R2** | Covers ALL alembic-Postgres bug classes (truncation, FK ordering, types, syntax) with zero per-class maintenance |
| **L3** | pytest matrix `[sqlite, postgres]` across the backend test suite | 1-2 days | **R4 or v2.10** | Covers ALL PostgreSQL-specific behaviours (not just alembic) ; pylink for ORM-level discoveries |
| **L4** | Post-deploy smoke test on staging + auto-rollback on failure | 2-3 days | **Phase 98+ or v2.10** | Blast-radius mitigation ; doesn't prevent, but bounds |
| **L5** | Railway PR preview env per branch + soak before merge to dev | 3-5 days + Railway cost | **v2.10** | Comprehensive, expensive |

## What's shipped today (L1 anchor)

- **PR #569 — `ios_release_capability_drift.py`** : blocks any new `com.apple.developer.*` entitlement in `Runner.entitlements` unless commit message tagged `[ios-release]` AND the `_PROVISIONED_CAPABILITIES` allowlist is updated.
- **PR #577 — `alembic_revision_length.py`** : blocks any alembic migration whose `revision: str = "..."` identifier exceeds 32 chars (PostgreSQL `alembic_version.version_num` VARCHAR(32) limit). 25 existing migrations clean ; the 36-char offender that crashed staging today is caught.

Both lints wired into lefthook pre-commit, glob-filtered to the relevant file class. Bypass via `LEFTHOOK_BYPASS=1` per CLAUDE.md §5 dev-rules (grep-able).

## L2 specification (target : Phase 97.5 R2)

Single GitHub Actions job in the backend workflow :

```yaml
- name: Alembic dry-run on ephemeral PostgreSQL
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_USER: mint_dryrun
        POSTGRES_PASSWORD: dryrun_pass
        POSTGRES_DB: mint_dryrun
      ports: [5432:5432]
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with:
        python-version: "3.12"
    - run: pip install alembic psycopg2-binary sqlalchemy
    - name: Run alembic upgrade head
      env:
        DATABASE_URL: postgresql://mint_dryrun:dryrun_pass@localhost:5432/mint_dryrun
      run: |
        cd services/backend
        alembic upgrade head
    - name: Run alembic downgrade base + upgrade head (idempotency)
      env:
        DATABASE_URL: postgresql://mint_dryrun:dryrun_pass@localhost:5432/mint_dryrun
      run: |
        cd services/backend
        alembic downgrade base
        alembic upgrade head
```

The job fails the PR check if the migration chain breaks on a clean PostgreSQL DB. Today's alembic_version VARCHAR(32) truncation would have been caught here BEFORE the merge to dev.

**Exit gate for L2** : the job is wired into the existing `Backend tests` workflow (or a new sibling workflow) AND blocks `dev` branch merges. Verified by intentionally re-introducing a 36-char revision_id on a throwaway branch and confirming the gate fires.

## L3 specification (target : R4 or v2.10)

pytest matrix across `[sqlite, postgres]` for the full backend test suite. Same fixtures, two DB backends. Surfaces PostgreSQL-specific behaviour in ORM-level code (e.g. JSONB ops, array types, `now()` vs `CURRENT_TIMESTAMP`).

Cost : 1-2 days. Wired as a parallel GitHub Actions matrix job.

Why deferred : L2 covers the highest-frequency production failure class (alembic migrations on Postgres) at lower cost. L3 is the comprehensive follow-up after L2 has been in flight for ≥2 weeks and we have a per-incident track record.

## L4 + L5 — deferred to v2.10

- L4 (post-deploy smoke + auto-rollback) requires Railway-side blue-green deploy semantics. Today Railway already has healthcheck retry policy with `restartPolicyType: ON_FAILURE` ; L4 would extend with a post-healthcheck smoke probe + rollback trigger.
- L5 (preview env per PR) is the gold standard but cost-prohibitive until Railway pricing supports it for our PR volume.

Both filed as v2.10 candidates.

## Rationale for sequencing

- **L1 NOW** : already in flight, marginal cost per incident is ~1h. Each lint locks one class permanently.
- **L2 in R2** : 1 day, broad coverage. Today's alembic incident is fresh ; the cost-benefit is overwhelming.
- **L3 R4/v2.10** : heavier, needs L2 in flight first to gauge whether matrix testing surfaces additional classes beyond what L2 catches.
- **L4 + L5 v2.10** : blast-radius mitigation. Less urgent than prevention. Easier to scope when we have N deploys' worth of incident data.

## Counter-arguments and data gaps

**Counter-arguments :**

- *« One lint per incident is reactive, not proactive »* — true. The lint backlog grows with discovered incident classes. Counter : the leverage ratio is high (1h prevention vs N hours of outage + revert pipeline). Each lint stays forever ; cost amortises across years.
- *« L2 dry-run won't catch FK ordering issues against PROD-SHAPE data »* — true. The ephemeral Postgres has empty tables when alembic upgrade runs. Today's B023b migration includes an orphan-DELETE step that would no-op on empty tables. L3 + L4 + production-shape data fixtures address this. L2 catches the schema-level bugs (truncation, syntax, type mismatch) but not data-level race conditions.
- *« L3 pytest matrix doubles CI time »* — true. ~2 min today × 2 = ~4 min. Acceptable per memory `feedback_pre_push_checklist`. The matrix can shard if total wall-clock exceeds the team's pain threshold.

**Data gaps :**

- Number of alembic-Postgres-specific defects PER MONTH in MINT history : not measured. The 2 today were both real outages ; if the rate is 1/month L2 still pays off ; if 1/year L2 is overkill. Telemetry needed via Railway deploy-failure history.
- Cost of Railway PR-preview env at MINT's PR volume (~5-15 PR/day) : not benchmarked. L5 decision conditional on this.
- L4 rollback semantics on Railway : whether the platform supports atomic blue-green is unverified. Per Railway 2026 docs the answer is « partial » — rollback to previous deployment image works but in-flight requests may drop.

## Next action

Phase 97.5 RESEARCH.md (in-flight from `gsd-phase-researcher` agent) is being extended via SendMessage to add **L2 as a 6th perimeter** to R2 — sequenced parallel with ConsentService + SessionReport (no dependency overlap). PLAN.md (next GSD step) will lock the task breakdown.
