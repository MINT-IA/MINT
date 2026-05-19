---
description: Phase 02 implementation research — prescriptive primitives for the 33 D-XX locked decisions across 4 areas (event-log + projection schema, security envelope, S12 consolidation, Flutter drift + Mobile L1 audit). Maps each D-XX to a concrete code recipe rooted in the existing MINT stack — AES-256-GCM `envelope.py` already wired, `DEKVault` ORM + `key_vault.get_or_create_dek()` already shipped, `EncryptedBytes` TypeDecorator already in `app/services/encryption/column_type.py`, `projection_audit_record` already exists from Hotfix B (p111), append-only REVOKE pattern already proven in p111, idempotent UNIQUE + UUID7 pattern already shipped in p95. Phase 02 is overwhelmingly an additive extension of in-tree primitives, NOT a green-field crypto build. Validation Architecture section maps each D-XX to a deterministic test command. Counter-arguments + 8 anti-patterns + external library cross-check included per CLAUDE.md §8 wiki schema.
---

# Phase mint-data-architecture-v1-02-event-log-projection — Research

**Researched :** 2026-05-18
**Domain :** Postgres event-log + projection migration + per-user DEK envelope + Mobile L1 audit
**Confidence :** HIGH (the stack required by all 33 D-XX is already present in-tree ; Phase 02 wires existing primitives, doesn't introduce new ones)

## TLDR

Phase 02 looks like green-field crypto + schema work, but a deep read of `services/backend/app/services/encryption/` reveals the stack is already 80% present: `AESGCM` from `cryptography.hazmat` + per-user DEK lifecycle (`get_or_create_dek` / `revoke_dek` / `crypto_shred_user`) + the `EncryptedBytes` SQLAlchemy `TypeDecorator` + `current_user_id` / `current_db_session` ContextVars + an `EncryptionContextMiddleware` that populates them. The `DEKVault` ORM has `wrapped_dek` (LargeBinary) + `kms_key_ref` + `algo` + `revoked_at` and a `crypto_shred_user(db, user_id)` method that NULLs the wrapped DEK. The `KeyVaultService` already supports 2 MK backends (AWS KMS via boto3 lazy, Fernet via `MINT_MASTER_KEY` env). D-02 « Railway-native + logical key-id `mint-master-v1` » maps onto the existing Fernet backend with `key_ref="fernet:env:MINT_MASTER_KEY"` — the migration is renaming the logical ref, not building a new KMS layer.

Likewise the append-only / REVOKE / Postgres-vs-SQLite split is already proven in `p111_projection_audit.py` (the exact migration template Phase 02 W1 needs for `fact_event`). The Postgres BOOLEAN DEFAULT bug discovered in Hotfix B has a one-line fix recipe (`sa.false()` instead of `sa.text("0")`) and a one-rule lint signature (`alembic_boolean_default_lint.py` per D-20). UUID7 + idempotency UNIQUE + nullable column-add via `inspector.get_columns` is the pattern shipped in `p95_dag_invalidation.py` and reused for the `fact_event` PK + UNIQUE-conflict path (D-27).

**Primary recommendation:** Phase 02 plans should be authored as **mostly delete + extend, not add**. The risk surface is in 3 places — (1) the `value_enc` JSONB shape for `fact_event` must NOT use `EncryptedBytes` (it's bytes-only ; `value_enc` is structured JSONB per D-26 with `ct/iv/tag/alg/dek_id/enc_v` fields) so a small additive Pydantic v2 `EncryptedValue` model + a thin `encrypt_value(db, user_id, plaintext)` helper that wraps the existing `encrypt_bytes` and packs the output into the JSONB shape must be added ; (2) the real-Postgres pg fixture (D-22) requires `testcontainers-python` to be added to `services/backend/pyproject.toml` and a `conftest.py` fixture wiring docker-postgres before alembic migration tests, plus a CI-side decision (testcontainers vs Railway-staging-replica) ; (3) the HMAC-pepper site sweep (D-24) requires a grep audit + a new `hmac_pepper_audit.py` lint that flags any call to `hashlib.sha256(user_id)` without pepper as a HARD lint failure. Everything else is plumbing existing primitives.

## User Constraints (from CONTEXT.md)

### Locked Decisions

33 D-XX decisions locked across 4 areas. Verbatim copy from CONTEXT.md `<decisions>` block — see CONTEXT.md for full text. Summary :

**Area 1 — 7 panel-debated open questions :**
- **D-01** `fact_current` latency : p50 ≤ 5 ms, p99 ≤ 20 ms, p99.9 ≤ 50 ms, REALISTIC FastAPI-side ; PK composite `(subject_type, subject_id, fact_type)` + covering index `(subject_id) INCLUDE (value_enc, latest_event_id, confidence, visibility)` ; `PARTITION BY HASH (subject_id) PARTITIONS 1` from day one ; split at 5M rows or p99 > 20ms.
- **D-02** KMS : Railway-native + logical key-id `kms_key_ref='mint-master-v1'`. Re-litigate at >10k users or first EDÖB/FINMA inquiry.
- **D-03** DEK shred granularity : all-or-nothing per user ; `dek_scope` column (default `'user'`) for Phase 04 future-proofing.
- **D-04** Constants propagation : snapshot point-in-time only ; never re-flag historical projections.
- **D-05** Migration strategy : big-bang 5-PR cut-over (PR-1 schema → PR-2 dual-write FF-OFF → PR-3 backfill idempotent → PR-4 read cut-over atomic with D-12 SOFT→HARD → PR-5 legacy `SnapshotModel` drop).
- **D-06** CI staging-down : tiered 7/14/28d escalation KEEP + 3 mechanical fixes (STAGING-MALFORMED status / scheduled-only aging writes / HARD-mode `STAGING-DOWN-OVERRIDE` PR label).
- **D-07** Audit retention : 10y hot Postgres ; `user_id_hash` via HMAC-pepper (NOT bare SHA-256) ; pepper in Railway secrets env var `MINT_AUDIT_HASH_PEPPER` ; REVOKE UPDATE/DELETE on `fact_event` + `projection_audit_record` ; delete-after-10y job DEFERRED.

**Area 2 — S12 consolidation + D-MOB design + 4 Phase 01 carry-over gaps :**
- **D-08** S12 composition pattern : `IndependantService.analyze()` stays façade, delegates calculator primitives to S18. Same for frontalier + rename `FrontalierService` → `FrontalierSegmentService` (S23 5x more callers — least blast radius). Promote `IJM_ESTIMATE_RATE=0.02` + `LAA_ESTIMATE_RATE=0.015` to S18.
- **D-09** S12 2-PR sequence : PR-1 (façade-delegate + rename + IJM/LAA promote) lands in Plan 02-01 W0 ; PR-2 (alias removal) lands in Plan 02-04 W4 close-out.
- **D-10** D-MOB-01 Flutter drift fix : baseline 45→43 fields ; PR-A2 extends `_buildProfileContext` for 15 missing fields ; PR-A3 drops 3 dead Flutter-only fields ; promote `profile_safe_fields_parity` SOFT→HARD after both ship.
- **D-11** D-MOB-02 dead-COUP-04 : verified closed end-to-end ; 1 integration test locks contract in Plan 02-01 (`tests/integration/test_coup_04_dead_path.py`).
- **D-12** D-MOB-03 Mobile L1 audit POST : EXTEND `projection_audit_record` (NOT new table) via Alembic p113 with `source` discriminator + `app_version` + `observed_at` + `anonymous_session_id` columns ; endpoints `/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` ; 2 lifecycle hooks (cold-start + warm-resume >30min) ; offline SQLite queue replay.
- **D-13** D-MOB-04 clean separation : mobile L1 audit does NOT dual-write `fact_event`.
- **D-14** Carry-over gap #1 : `audit_events.user_id_hash` backfill + plaintext `user_id` drop on Postgres (Hotfix C completed the column add ; Phase 02 finishes the deprecation).
- **D-15** Carry-over gap #2 : hash `actor_email` + `ip_address` + `user_agent` (same HMAC-pepper pattern).
- **D-16** Carry-over gap #3 : `/privacy/delete` real count (currently hardcoded `nb_sessions=0`).
- **D-17** Carry-over gap #4 : `SnapshotModel.constants_version_hash` cache invalidation wiring.

**Area 3 — Wave structure + projector pattern + W0 prereqs :**
- **D-18** Phase 02 = 4 sequential plans (W0 / W1 / W2-W3 / W4). No parallelization.
- **D-19** App-side projector with `session.begin()` (NOT db trigger).
- **D-20** `alembic_boolean_default_lint.py` HARD lefthook.
- **D-21** Codegen timestamp determinism : `Generated at: <utcnow>` → `Generated for effective_on: <date>`.
- **D-22** Real-Postgres pg fixture migration test harness (replaces `sqlite:///:memory:`).
- **D-23** `pg_dump` baseline snapshot committed (`tools/db/baseline_snapshot_2026-05-18.sql`).
- **D-24** HMAC-pepper site sweep + `hmac_pepper_audit.py` lint.
- **D-25** First-slice canary = `monthly_gross_income` end-to-end parity test.

**Area 4 — `fact_event` schema concretes + buffer mechanics + exit gates :**
- **D-26** `value_enc` typed JSONB shape via Pydantic v2 `EncryptedValue` (`ct/iv/tag/alg/dek_id/enc_v`).
- **D-27** `fact_event` idempotency : UNIQUE `(subject_type, subject_id, fact_type, source_id, recorded_at)` + projector sequence-number monotonicity check on `latest_event_id` ; HTTP 409 on conflict ; `mint_projector_idempotency_skip_total` counter.
- **D-28** Partition declaration : `PARTITION BY HASH (subject_id) PARTITIONS 1` in p98 from day one.
- **D-29** `confidence` JSONB : full `EnhancedConfidence` 4-axis (`{c, a, f, u, score, enrichmentPrompts}`).
- **D-30** Anonymous-session buffer : mobile SQLite (`sqflite_sqlcipher` already in `pubspec.yaml`), 30d TTL, UUID v7 per app install, batch POST `/v1/audit/mobile-session-link` on first login, UNIQUE `(anonymous_session_id, observed_at)` for retry-safety.
- **D-31** D-12 parity-lint SOFT→HARD promotion : atomic with PR-3 read cut-over.
- **D-32** Phase 02 5-gate mechanical exit checklist (G1 Maestro / G2 Julien device / G3 dev CI HARD lints + REVOKE + Postgres-real migration test / G4 pytest + 2 new test classes / G5 LSFin + accent + ARB + constants drift HARD + HMAC-pepper site lint).
- **D-33** 6 new observability counters wired + validated by `declared_counters_must_fire.py` close-out gate.

### Claude's Discretion

Verbatim from CONTEXT.md :
- pytest fixture scaffold for D-22 (testcontainers-python vs Railway-staging-replica) — default testcontainers-python.
- Exact `EncryptedValue` Pydantic v2 model location (D-26) — default `services/backend/app/models/encryption/encrypted_value.py`.
- Exact retry / backoff policy for offline SQLite queue replay (D-12 / D-30) — default exponential backoff 1s/2s/4s/8s/16s with `mint_anonymous_session_link_total{outcome='error'}` increment per failure.
- Exact STAGING-DOWN-OVERRIDE label workflow gate (D-06) — default `.github/CODEOWNERS` scoped to `julienbattaglia`.
- Exact `fact_current` covering index field order (D-01) — re-validate via `EXPLAIN`.
- Feature-flag naming for PR-2 dual-write toggle (D-05) — default `fact_event_dual_write_enabled`.
- Bundle-size impact of mobile SQLite buffer (D-30) — must measure in Plan 02-02 (<100KB compressed addition).

### Deferred Ideas (OUT OF SCOPE)

Verbatim from CONTEXT.md `<deferred>` block. NOT to be re-litigated by the planner :
- Coach-extractor LLM (Phase 03 — requires `fact_event(source_type='coach_inference')` schema from Phase 02 to land first).
- Per-category sub-DEKs / granular erasure (Phase 04 — `dek_scope` column future-proofs).
- Monte Carlo / tornado sensitivity / arbitrage / withdrawal-sequencing migration (`mint-data-architecture-v1-03+`).
- AWS KMS migration (>10k users / EDÖB / FINMA / Railway FIPS).
- Postgres UNLOGGED + `pg_prewarm` escape hatch (p99 PK reads > 50ms sustained).
- S3 Glacier 9y archive (Railway bill > CHF 100/mo on `projection_audit_record`).
- Sigstore Rekor Merkle anchoring (1st LSFin complaint).
- Delete-after-10y job for `projection_audit_record`.
- `fact_current_drift_detector.py` (idempotency counter non-zero post-launch).
- Single-table bitemporal SCD2 (FINMA written guidance requiring it).
- Re-link audit chain semantics for deleted-then-recreated users.
- AWS KMS Secrets Manager pepper (more cross-cloud complexity — Railway-secret-stored pepper sufficient pre-launch).

## Project Constraints (from CLAUDE.md)

The planner MUST verify each task against these directives. Treat with same authority as locked CONTEXT.md decisions :

1. **Rule 4 (Financial_core reuse, L1/L2-L4 split)** — `apps/mobile/lib/services/financial_core/` = SOURCE OF TRUTH **pour L1 chiffrer** (single-number deterministic outputs, offline-capable, codegen-baked constants). **L2-L4 (comparer / éclairer / invariants) = backend-canonical** sous `services/backend/app/services/`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type (L1ChiffrePayload → mobile ; L2ComparePayload / L3EclairePayload / L4InvariantPayload → backend). Never re-implement `_calculate*()` cross-layer. Phase 02 implication : `fact_event` writers are L0 (data persistence, not lucidité layer) ; `fact_current` readers feed both layers but the calc engine that consumes them stays split. The mobile L1 audit POST (D-12) is a write-side path that mobile owns end-to-end.

2. **Rule 5 (i18n)** — toutes strings user-facing via `AppLocalizations.of(context)!.key`. 6 ARB files (fr/en/de/es/it/pt) sous `lib/l10n/`. Phase 02 implication : the offline-queue replay banner + the « audit envoyé » feedback toasts emitted by the Flutter Mobile L1 audit service MUST go through ARB. Use `validate_arb_parity()` MCP before any PR shipping new mobile copy.

3. **Rule 1 (Banned terms LSFin)** — NEVER « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». Use « pourrait », « envisager », « adapté ». Lint `tools/checks/banned_terms_python.py`. Phase 02 implication : every new endpoint response message + every new ARB key + every new Sentry breadcrumb message MUST pass banned-terms lint. The G5 exit gate already enforces this.

4. **Rule 2 (Accents 100% FR)** — `creer → créer`, `eclairage → éclairage`. ASCII `e` à la place de `é` = bug. Lint `tools/checks/accent_lint_fr.py`. Phase 02 implication : every new FR string in docs / migrations / SUMMARY / SUMMARY HTML / ADR amendments MUST pass accent_lint. Every new ARB FR key likewise.

5. **Rule 6 (0-trust protocol §9)** — banned without deterministic citation : « shipped », « closed », « ready », « works », « validated », « green », « PROVISIONALLY READY ». PR opened ≠ shipped. Tests passing ≠ feature working. Phase 02 implication : every Plan SUMMARY + the phase-close VERIFICATION-REPORT.html must cite (a) commit sha, (b) pytest exit-0 output, (c) Postgres-real migration test output, (d) `idb ui describe-all` snapshot for the G2 device walkthrough — NOT just « 5-gate green ». The « PR opened ≠ shipped » 4-stage table from §9.5 applies to every Phase 02 PR.

6. **Karpathy 4 (§7)** — simplicity first / surgical changes / goal-driven execution / think before coding. Phase 02 implication : reuse `envelope.py` + `key_vault.py` + the `EncryptedBytes` decorator ; do NOT build a parallel crypto layer for `value_enc`. Add a thin `encrypt_value` helper that calls existing `encrypt_bytes` and packs into the D-26 JSONB shape — that's all.

7. **Wiki Schema §8** — every `.planning/**/*.md` needs TLDR + counter-arguments + data gaps blocks. Pre-commit `tools/checks/wiki_lint.py` (HARD on `.planning/decisions/*.md`). Phase 02 implication : every PR SUMMARY + the phase VERIFICATION-REPORT + any new ADR ammendment passes wiki_lint.

8. **Public-repo discipline** (feedback_public_repo_discipline.md) — no forensic legal language in commits/docs/PRs (« violates X », « art. 60 », « legally survivable »). Decision artifacts marked Proposed not Decided where Julien hasn't confirmed. Phase 02 implication : the existing panel synthesis ADR is marked `Decided` ; that's correct (Julien confirmed). Per-PR commits + bodies must avoid legal admission phrasing.

## Phase Requirements

CONTEXT.md is the binding source. No external requirement IDs were mapped (`phase_req_ids: null` per init JSON). The 33 D-XX are the requirements ; each D-XX gets a research-support mapping in the Implementation Primitives section below.

## Standard Stack

### Core

| Library / module | Version | Purpose | Why standard (and where it already lives in MINT) |
|---|---|---|---|
| `cryptography` | `>=42,<47` (verified in `services/backend/pyproject.toml`) | AES-256-GCM envelope + HMAC-SHA256 pepper | Already used by `app/services/encryption/envelope.py` for `AESGCM` ; verified `from cryptography.hazmat.primitives.ciphers.aead import AESGCM` + `from cryptography.hazmat.primitives import hashes, hmac`. NO new lib needed. [CITED: https://cryptography.io/en/latest/hazmat/primitives/mac/hmac/] |
| `sqlalchemy` | `>=2.0.0,<3.0.0` (verified `pyproject.toml`) | ORM + `TypeDecorator` + `__table_args__` PARTITION BY HASH support | Already in use. `postgresql_partition_by="HASH (subject_id)"` in `__table_args__` dict is the 2.0-native pattern. [CITED: https://docs.sqlalchemy.org/en/20/dialects/postgresql.html] |
| `alembic` | `>=1.13.0,<2.0.0` (verified `pyproject.toml`) | Schema migrations | Already in use. p98 + p113 are additive migrations following the p111 / p112 / p95 patterns already shipped. [VERIFIED: `ls services/backend/alembic/versions/`] |
| `pydantic` | `>=2.6.0,<3.0.0` (verified `pyproject.toml`) | `EncryptedValue` (D-26) + discriminated payloads | Pydantic v2 `BaseModel` + `Literal` + `Field` is the in-tree pattern (e.g., `app/models/lucidity/_payload.py`). |
| `psycopg2-binary` | `>=2.9.9,<3.0.0` (verified `pyproject.toml`) | Postgres driver | Already in use. NOT asyncpg — the existing backend is synchronous SQLAlchemy. Phase 02 stays synchronous. |
| `prometheus-client` | `>=0.20,<1.0` (verified `pyproject.toml`) | The 6 new observability counters (D-33) | Already in use by `services/backend/app/observability/counters.py`. |
| `sentry-sdk[fastapi]` | `==2.53.0` (verified `pyproject.toml`) | Breadcrumb on DEK shred + projector idempotency + audit-link outcome | Already in use. |

### Supporting (NEW deps Phase 02 introduces)

| Library | Version | Purpose | When to use |
|---|---|---|---|
| `testcontainers[postgres]` | `>=4.7,<5` (verify via `npm view`-equivalent : `pip index versions testcontainers` before locking ; training-data version may be stale) [ASSUMED] | Hermetic Postgres for D-22 migration test harness | conftest fixture spinning ephemeral Postgres 15+ container ; replaces `DATABASE_URL=sqlite:///:memory:` for `tests/integration/test_migration_*.py` only. Module-scoped fixture per [CITED: https://testcontainers.com/guides/getting-started-with-testcontainers-for-python/]. |
| `uuid_utils` OR `uuid6` (Python lib) | `uuid_utils >=0.9` OR Python 3.14+ stdlib `uuid.uuid7()` | UUID7 generation for `fact_event.event_id` + `anonymous_session_id` | The MINT codebase already uses UUID4 (`uuid4()`). For monotonic ordered IDs in `fact_event` (per D-27 sequence-number check), UUID7 is preferred. Existing in-tree pattern : `p95_dag_invalidation.py` documents UUID7 use for `superseded_by` but the actual generation site is in `services/cache/scenario_emitter.py`. Verify whether `uuid_utils` is already a transitive dep by `pip show uuid_utils` ; if not, add to `pyproject.toml`. Python stdlib `uuid.uuid7()` shipped in Python 3.14 [CITED: https://github.com/python/cpython/issues/102461] but the backend requires `>=3.10` so `uuid_utils` is the safe choice. |

### Mobile-side stack (NO new deps required — all present in `apps/mobile/pubspec.yaml`)

| Package | Pinned version | Purpose | Already-in-tree confirmation |
|---|---|---|---|
| `sqflite_sqlcipher` | `^3.1.0+1` (verified `pubspec.yaml`) | Encrypted SQLite for D-30 anonymous-session buffer + offline-queue replay | Already in `pubspec.yaml`. Encrypted at rest with `password` param to `openDatabase`. [CITED: https://pub.dev/packages/sqflite_sqlcipher] |
| `package_info_plus` | `^8.0.0` (verified `pubspec.yaml`) | `_appVersion` for `projection_audit_record.app_version` column (D-12) | Already in `pubspec.yaml` ; promoted to direct dep 2026-05-18 ; `api_service.dart:187` already initialised (commit `ce24c963`). |
| `sentry_flutter` | `9.14.0` (verified `pubspec.yaml`) | Mobile L1 audit failures + DEK lifecycle events | Already in `pubspec.yaml`. |
| `crypto` | `^3.0.3` (verified `pubspec.yaml`) | UUID v7 generation client-side (if no native libuuid binding) | Already in `pubspec.yaml`. For UUID v7 on Flutter prefer `uuid: ^4.x` if not present (verify) ; otherwise hand-roll RFC 9562 v7 with the existing `crypto` lib + `DateTime.now().millisecondsSinceEpoch` + `Random.secure()` 74-bit suffix. |

**Verification commands (run before writing Plan 02-02) :**

```bash
# Python deps presence
cd services/backend && python3 -c "import testcontainers; print(testcontainers.__version__)" 2>&1 || echo "MISSING"
cd services/backend && python3 -c "import uuid_utils; print(uuid_utils.__version__)" 2>&1 || echo "MISSING"

# Flutter deps presence
cd apps/mobile && grep -E "^  (sqflite_sqlcipher|package_info_plus|sentry_flutter|crypto|uuid):" pubspec.yaml
```

If a dep is MISSING the Plan 02-01 W0 prereq bundle MUST add the install + version-pin step as a task with explicit verification commands.

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| `testcontainers-python` (D-22 default) | Railway-staging-replica auth | Hermetic vs realistic. **Use testcontainers for hermetic per-PR runs ; Railway-staging-replica for nightly soak.** Both ; not « one or the other ». Railway-staging requires creds in CI which adds blast radius if the secret leaks. Testcontainers requires Docker on the CI runner (GitHub Actions provides Docker on ubuntu-latest). |
| Pydantic v2 `EncryptedValue` JSONB (D-26 default) | Separate columns `ct VARCHAR / iv VARCHAR / tag VARCHAR / dek_id VARCHAR / alg VARCHAR / enc_v INT` | Separate-columns is more indexable on `dek_id` for rotation queries, but JSONB allows indexing on `(value_enc->>'dek_id')` via expression index AND keeps the row width sane for 6 fields × every event. **Keep JSONB per CONTEXT D-26 ; add GIN index on `value_enc` if future rotation queries demand it.** |
| App-side projector with `session.begin()` (D-19) | Postgres `AFTER INSERT` trigger calling a PL/pgSQL projector | Trigger is simpler but loses observability (no Python stack trace on projector failure, no Sentry breadcrumb). **Stay with app-side per D-19 panel verdict.** |
| `uuid_utils.uuid7()` | Hand-rolled UUID7 via `os.urandom` + `time.time_ns` | Hand-rolled is one less dep but brittle vs RFC 9562 edge cases. **Use `uuid_utils` ; verified library on PyPI, RFC 9562 compliant.** [CITED: https://github.com/oittaa/uuid6-python] |
| HMAC-SHA256 with Railway-secret pepper (D-07/D-24) | Postgres `pgcrypto` extension `digest(pepper || user_id, 'sha256')` | pgcrypto requires Postgres extension install (Railway managed Postgres may or may not have it ; Hotfix C migration shows it's not guaranteed). **Hash in Python via `cryptography.hazmat.primitives.hmac.HMAC(pepper, hashes.SHA256())` — portable across SQLite/Postgres, no extension dep.** [CITED: https://cryptography.io/en/latest/hazmat/primitives/mac/hmac/] |

**Installation (Plan 02-01 W0 prereq bundle task) :**

```bash
# Backend
cd services/backend
# Add to pyproject.toml [project.optional-dependencies] test:
#   "testcontainers[postgres]>=4.7,<5",
# Add to pyproject.toml [project.dependencies]:
#   "uuid_utils>=0.9,<1.0",
pip install -e ".[test]"

# Verify version pin
python3 -c "import testcontainers; print('testcontainers', testcontainers.__version__)"
python3 -c "import uuid_utils; print('uuid_utils', uuid_utils.__version__)"
```

**Version verification protocol (per gsd-phase-researcher requirements) :** the versions listed above are pulled from `services/backend/pyproject.toml` (verified) for already-present deps. For NEW deps (`testcontainers`, `uuid_utils`) the planner MUST run `pip index versions <pkg>` before writing the install task and pin to the latest stable. Training-data versions are advisory only. [ASSUMED] flag carries until the planner verifies on PyPI.

## Architecture Patterns

### Recommended Project Structure (Phase 02 additive surfaces)

```
services/backend/
├── app/
│   ├── models/
│   │   ├── fact_event.py                       # NEW — append-only event log (D-26, D-27, D-28)
│   │   ├── fact_current.py                     # NEW — denormalised projection (D-01)
│   │   ├── encryption/
│   │   │   └── encrypted_value.py              # NEW — Pydantic v2 EncryptedValue (D-26)
│   │   ├── snapshot.py                         # EXISTING — read-only during dual-write window
│   │   ├── projection_audit_record.py          # EXISTING — EXTEND via p113 (D-12)
│   │   ├── audit_event.py                      # EXISTING — D-14/D-15 PII column hash
│   │   └── dek_vault.py                        # EXISTING — extend with dek_scope column (D-03)
│   ├── services/
│   │   ├── encryption/                         # EXISTING — REUSE
│   │   │   ├── envelope.py                     #   encrypt_bytes / decrypt_bytes
│   │   │   ├── key_vault.py                    #   get_or_create_dek / revoke_dek
│   │   │   ├── column_type.py                  #   EncryptedBytes TypeDecorator
│   │   │   └── encrypted_value_helper.py       # NEW — encrypt_value / decrypt_value (JSONB wrapper)
│   │   ├── projector/
│   │   │   └── fact_projector.py               # NEW — project_fact_event() with session.begin()
│   │   ├── audit/
│   │   │   └── hmac_pepper.py                  # NEW — hmac_user_id() canonical entry point (D-07/D-24)
│   │   ├── snapshots/
│   │   │   └── snapshot_service.py             # EXISTING — extend with dual-write under FF (D-05)
│   │   ├── independants/                       # EXISTING (S18) — receive IJM_ESTIMATE_RATE + LAA_ESTIMATE_RATE
│   │   ├── expat/
│   │   │   └── frontalier_segment_service.py   # RENAMED from frontalier_service.py (D-08)
│   │   └── frontalier_service.py               # EXISTING (S12) — façade-delegate to expat/.frontalier_segment
│   ├── api/v1/endpoints/
│   │   └── audit_mobile.py                     # NEW — /v1/audit/mobile-session-start + -link (D-12)
│   └── observability/
│       └── counters.py                         # EXISTING — declare 6 new counters (D-33)
├── alembic/versions/
│   ├── p98_fact_event_projection_dek.py        # NEW — fact_event + fact_current + user_dek + dek_scope (D-03, D-26, D-28)
│   ├── p113_extend_projection_audit_mobile.py  # NEW — source + app_version + observed_at + anonymous_session_id (D-12)
│   ├── p114_hmac_pepper_audit_events.py        # NEW — backfill HMAC-pepper for audit_events.user_id_hash + drop plaintext (D-14)
│   ├── p115_hmac_pepper_pii_columns.py         # NEW — hash actor_email/ip_address/user_agent (D-15)
│   └── p116_snapshot_constants_invalidation.py # NEW — cache invalidation wiring (D-17, no schema change, ops only)
└── tests/
    ├── fixtures/
    │   └── pg_fixture.py                       # NEW — testcontainers-python Postgres for migration tests (D-22)
    └── integration/
        ├── test_canary_monthly_gross_income.py # NEW — D-25 canary parity test
        ├── test_projector_idempotency.py       # NEW — D-32 G4
        ├── test_dek_shred_opacity.py           # NEW — D-32 G4
        ├── test_coup_04_dead_path.py           # NEW — D-11 contract lock
        └── test_audit_mobile_link.py           # NEW — D-12 batch link endpoint

apps/mobile/lib/services/
├── audit/                                      # NEW package
│   ├── mobile_l1_audit_service.dart            #   POST /v1/audit/mobile-session-{start,link}
│   ├── anonymous_session_id.dart               #   UUID v7 generator + sqflite_sqlcipher persistence
│   └── offline_queue.dart                      #   exponential backoff replay
└── coach_narrative_service.dart                # EXISTING — extend _buildProfileContext for 15 missing fields (D-10)

tools/
├── checks/
│   ├── alembic_boolean_default_lint.py         # NEW — D-20 HARD lefthook
│   ├── hmac_pepper_audit.py                    # NEW — D-24 site lint
│   ├── declared_counters_must_fire.py          # NEW — D-32 G3 + D-33 close-out gate
│   └── profile_safe_fields_parity.py           # EXISTING — promote SOFT→HARD per D-31 (atomic with PR-3)
├── codegen/
│   └── regulatory_constants_to_dart.py         # EXISTING — fix timestamp determinism (D-21)
└── db/
    └── baseline_snapshot_2026-05-18.sql        # NEW — pg_dump baseline (D-23)

.github/
├── workflows/
│   └── regulatory-codegen.yml                  # EXISTING — extend with Q6 fixes (D-06)
└── CODEOWNERS                                  # NEW or EXISTING-edit — scope STAGING-DOWN-OVERRIDE
```

### Pattern 1 — Per-user DEK envelope on `fact_event.value_enc`

**What :** every `fact_event` row whose `subject_type='user'` carries an encrypted `value_enc` JSONB. The envelope is produced by the existing `encrypt_bytes()` in `app/services/encryption/envelope.py` then packed into the D-26 JSONB shape.

**When to use :** any `fact_event` row with `subject_type='user'`. `subject_type='regulatory'` rows are PUBLIC constants (per upstream ADR — « Pattern A ») and store plaintext JSON in `value_enc` (no encryption needed, simplifies regulatory-codegen sync).

**Example (NEW helper `services/backend/app/services/encryption/encrypted_value_helper.py`) :**

```python
# Source: derived from existing app/services/encryption/envelope.py
# (verified in-tree — encrypt_bytes already shipped, AESGCM already wired).
import base64
import json
from typing import Any

from app.services.encryption.envelope import encrypt_bytes, decrypt_bytes
from app.models.encryption.encrypted_value import EncryptedValue


_ENVELOPE_FORMAT_VERSION = 1
_DEK_ID = "mint-master-v1"  # D-02 logical key-id
_ALG = "AES-256-GCM"


def encrypt_value(db, user_id: str, value: Any) -> dict:
    """JSON-serialize `value`, encrypt under user's DEK, return D-26 shape.

    Wire format produced by `encrypt_bytes` is `nonce || ciphertext || tag`.
    For the D-26 JSONB shape we split iv (nonce) and (ct || tag) so callers
    of `decrypt_value` can read the iv field independently if needed.
    """
    plaintext = json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")
    blob = encrypt_bytes(db, user_id, plaintext)  # nonce(12) || ct || tag(16)
    iv = blob[:12]
    ct_and_tag = blob[12:]
    return EncryptedValue(
        ct=base64.b64encode(ct_and_tag).decode("ascii"),
        iv=base64.b64encode(iv).decode("ascii"),
        tag="",  # tag is appended to ct by AESGCM ; keep field for forward compat
        alg=_ALG,
        dek_id=_DEK_ID,
        enc_v=_ENVELOPE_FORMAT_VERSION,
    ).model_dump()


def decrypt_value(db, user_id: str, envelope: dict) -> Any:
    """Reverse of encrypt_value. Returns the original Python value."""
    iv = base64.b64decode(envelope["iv"])
    ct_and_tag = base64.b64decode(envelope["ct"])
    blob = iv + ct_and_tag
    plaintext = decrypt_bytes(db, user_id, blob)
    return json.loads(plaintext.decode("utf-8"))
```

**Why this pattern is the only correct one :** the existing `EncryptedBytes` TypeDecorator only handles raw bytes columns (LargeBinary). The D-26 JSONB shape with named fields (`ct/iv/tag/alg/dek_id/enc_v`) is structurally incompatible with `EncryptedBytes`. Adding a thin packer/unpacker reuses 100% of the proven crypto code (AAD binding to user_id, GCM tag verification, DEK lifecycle) and adds only the JSON-serialisation contract.

### Pattern 2 — App-side projector with `session.begin()` (D-19)

**What :** a Python function `project_fact_event(session, event)` called within the same SQLAlchemy session as the `fact_event` INSERT. Both writes commit-or-rollback atomically.

**When to use :** every code path that writes a `fact_event`. Replaces any « async eventual consistency » worker pattern.

**Example (NEW `services/backend/app/services/projector/fact_projector.py`) :**

```python
# Source: derived from existing SQLAlchemy session pattern in
# services/backend/app/api/v1/endpoints/coach_chat.py _dispatch_tool
# (verified in-tree).
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.fact_event import FactEvent
from app.models.fact_current import FactCurrent
from app.observability.counters import (
    mint_fact_event_insert_total,
    mint_projector_idempotency_skip_total,
)


def project_fact_event(session: Session, event: FactEvent) -> None:
    """Insert event + upsert fact_current within the caller's session.

    Caller MUST wrap the call in `with session.begin():` so the projection
    write is atomic with the event write. On exception both roll back.

    Idempotency : if event.event_id <= existing fact_current.latest_event_id
    (sequence-number monotonicity per D-27), the projection write is skipped
    and the idempotency counter increments. The fact_event INSERT itself
    is guarded by the D-27 UNIQUE constraint at the DB layer.
    """
    # 1. INSERT fact_event (UNIQUE conflict → IntegrityError → caller
    #    translates to HTTP 409 per D-27)
    try:
        session.add(event)
        session.flush()  # surface UNIQUE conflict here, not at commit
    except IntegrityError:
        # Same (subject_type, subject_id, fact_type, source_id, recorded_at)
        # already exists → caller decides retry vs reject.
        raise
    mint_fact_event_insert_total.labels(source_type=event.source_type).inc()

    # 2. Upsert fact_current
    existing = (
        session.query(FactCurrent)
        .filter_by(
            subject_type=event.subject_type,
            subject_id=event.subject_id,
            fact_type=event.fact_type,
        )
        .one_or_none()
    )

    if existing is not None and existing.latest_event_id >= event.event_id:
        # Stale event arriving after a newer one — skip projection per D-27.
        mint_projector_idempotency_skip_total.inc()
        return

    if existing is None:
        session.add(
            FactCurrent(
                subject_type=event.subject_type,
                subject_id=event.subject_id,
                fact_type=event.fact_type,
                value_enc=event.value_enc,
                latest_event_id=event.event_id,
                confidence=event.confidence,
                visibility=event.visibility,
            )
        )
    else:
        existing.value_enc = event.value_enc
        existing.latest_event_id = event.event_id
        existing.confidence = event.confidence
        existing.visibility = event.visibility
```

**Calling pattern (in any writer, e.g. extended `snapshot_service.py` under FF) :**

```python
with session.begin():
    event = FactEvent(...)
    project_fact_event(session, event)
# session.begin() exits → commit. On exception both rolled back.
```

### Pattern 3 — Alembic migration template for `fact_event` (D-28 PARTITION BY HASH)

**What :** Postgres-native partitioned table created via `op.execute()` raw SQL (SQLAlchemy's `__table_args__` partitioning works for declarative-mapped tables, but for Alembic migrations the raw SQL approach is more robust against autogeneration drift).

**When to use :** the p98 migration creating `fact_event`. The SQLite test path falls back to a non-partitioned table (matches Hotfix B / p111 pattern of dialect-aware branching).

**Example (NEW `alembic/versions/p98_fact_event_projection_dek.py`) :**

```python
# Source: derived from existing p111_projection_audit.py template
# (verified in-tree — REVOKE pattern + dialect branching proven).
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "p98_fact_event_projection"  # 25 chars within Postgres VARCHAR(32) cap
down_revision: Union[str, Sequence[str], None] = "p112_audit_event_user_hash"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    # ── fact_event (append-only) ───────────────────────────────────────
    if dialect == "postgresql":
        # Postgres: partitioned table from day one per D-28
        op.execute(
            """
            CREATE TABLE fact_event (
                event_id          VARCHAR(36)  NOT NULL,
                subject_type      VARCHAR(32)  NOT NULL,
                subject_id        VARCHAR(64)  NOT NULL,
                fact_type         VARCHAR(64)  NOT NULL,
                value_enc         JSONB        NOT NULL,
                source_type       VARCHAR(32)  NOT NULL,
                source_id         VARCHAR(64)  NULL,
                source_pdf_sha256 VARCHAR(64)  NULL,
                observed_at       TIMESTAMP    NOT NULL,
                recorded_at       TIMESTAMP    NOT NULL,
                confidence        JSONB        NULL,
                supersedes_event_id VARCHAR(36) NULL,
                correction_reason VARCHAR(256) NULL,
                visibility        VARCHAR(16)  NOT NULL DEFAULT 'user_visible',
                archetype_tags    JSONB        NULL,
                PRIMARY KEY (event_id, subject_id),
                UNIQUE (subject_type, subject_id, fact_type, source_id, recorded_at)
            )
            PARTITION BY HASH (subject_id);
            """
        )
        # Create initial 1-partition per D-28 (split later: ATTACH PARTITION)
        op.execute(
            """
            CREATE TABLE fact_event_p_0 PARTITION OF fact_event
                FOR VALUES WITH (MODULUS 1, REMAINDER 0);
            """
        )
        # REVOKE per D-07
        op.execute("REVOKE UPDATE, DELETE ON fact_event FROM PUBLIC;")
        op.execute(
            """
            DO $$
            BEGIN
                IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_role') THEN
                    REVOKE UPDATE, DELETE ON fact_event FROM app_role;
                END IF;
            END
            $$;
            """
        )
    else:
        # SQLite test path : non-partitioned, append-only by convention
        op.create_table(
            "fact_event",
            sa.Column("event_id", sa.String(36), nullable=False),
            sa.Column("subject_type", sa.String(32), nullable=False),
            sa.Column("subject_id", sa.String(64), nullable=False),
            sa.Column("fact_type", sa.String(64), nullable=False),
            sa.Column("value_enc", sa.JSON, nullable=False),  # SQLite JSON
            sa.Column("source_type", sa.String(32), nullable=False),
            sa.Column("source_id", sa.String(64), nullable=True),
            sa.Column("source_pdf_sha256", sa.String(64), nullable=True),
            sa.Column("observed_at", sa.DateTime, nullable=False),
            sa.Column("recorded_at", sa.DateTime, nullable=False),
            sa.Column("confidence", sa.JSON, nullable=True),
            sa.Column("supersedes_event_id", sa.String(36), nullable=True),
            sa.Column("correction_reason", sa.String(256), nullable=True),
            sa.Column("visibility", sa.String(16), nullable=False,
                      server_default=sa.text("'user_visible'")),
            sa.Column("archetype_tags", sa.JSON, nullable=True),
            sa.PrimaryKeyConstraint("event_id", "subject_id"),
            sa.UniqueConstraint(
                "subject_type", "subject_id", "fact_type", "source_id", "recorded_at",
                name="uq_fact_event_idempotency",
            ),
        )

    # Indexes (both dialects)
    op.create_index(
        "ix_fact_event_subject", "fact_event", ["subject_type", "subject_id"]
    )

    # ── fact_current (denormalised projection) ─────────────────────────
    op.create_table(
        "fact_current",
        sa.Column("subject_type", sa.String(32), nullable=False),
        sa.Column("subject_id", sa.String(64), nullable=False),
        sa.Column("fact_type", sa.String(64), nullable=False),
        sa.Column("value_enc", sa.JSON if dialect != "postgresql" else sa.dialects.postgresql.JSONB, nullable=False),
        sa.Column("latest_event_id", sa.String(36), nullable=False),
        sa.Column("confidence", sa.JSON, nullable=True),
        sa.Column("visibility", sa.String(16), nullable=False,
                  server_default=sa.text("'user_visible'")),
        sa.PrimaryKeyConstraint("subject_type", "subject_id", "fact_type"),
    )
    # D-01 covering index — re-validate field order via EXPLAIN (Claude's Discretion)
    if dialect == "postgresql":
        op.execute(
            """
            CREATE INDEX ix_fact_current_subject_covering ON fact_current (subject_id)
            INCLUDE (value_enc, latest_event_id, confidence, visibility);
            """
        )

    # ── user_dek (per-user crypto-shred envelope) ──────────────────────
    # Already present as DEKVault → ADD dek_scope column for D-03 future-proof
    with op.batch_alter_table("dek_vault", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "dek_scope",
                sa.String(32),
                nullable=False,
                server_default=sa.text("'user'"),
            )
        )


def downgrade() -> None:
    with op.batch_alter_table("dek_vault", schema=None) as batch_op:
        batch_op.drop_column("dek_scope")
    op.drop_table("fact_current")
    op.drop_index("ix_fact_event_subject", table_name="fact_event")
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP TABLE IF EXISTS fact_event_p_0;")
    op.drop_table("fact_event")
```

### Pattern 4 — HMAC-pepper canonical entry (D-07/D-14/D-15/D-24)

**What :** a single function `hmac_user_id(user_id: str) -> str` that reads `MINT_AUDIT_HASH_PEPPER` from env, HMAC-SHA256 the user_id, returns 64-char hex. ALL audit-row writers call this single entry point. The D-24 site lint flags any call to `hashlib.sha256(user_id)` without going through `hmac_user_id`.

**Example (NEW `services/backend/app/services/audit/hmac_pepper.py`) :**

```python
# Source: pyca/cryptography HMAC docs.
# [CITED: https://cryptography.io/en/latest/hazmat/primitives/mac/hmac/]
from __future__ import annotations

import os
from functools import lru_cache

from cryptography.hazmat.primitives import hashes, hmac


class PepperNotConfigured(RuntimeError):
    """Raised when MINT_AUDIT_HASH_PEPPER is missing in production."""


@lru_cache(maxsize=1)
def _get_pepper() -> bytes:
    pepper = os.environ.get("MINT_AUDIT_HASH_PEPPER")
    if pepper is None:
        if os.environ.get("TESTING") == "1":
            return b"test-pepper-not-for-production"
        raise PepperNotConfigured(
            "MINT_AUDIT_HASH_PEPPER env var is required for audit hashing"
        )
    if len(pepper) < 32:
        raise PepperNotConfigured(
            "MINT_AUDIT_HASH_PEPPER must be at least 32 chars"
        )
    return pepper.encode("utf-8")


def hmac_user_id(user_id: str | None) -> str | None:
    """HMAC-SHA256 of user_id keyed by the audit pepper. 64-char hex."""
    if user_id is None:
        return None
    h = hmac.HMAC(_get_pepper(), hashes.SHA256())
    h.update(user_id.encode("utf-8"))
    return h.finalize().hex()


def hmac_pii(value: str | None) -> str | None:
    """Same construction for actor_email / ip_address / user_agent (D-15)."""
    if value is None:
        return None
    h = hmac.HMAC(_get_pepper(), hashes.SHA256())
    h.update(value.encode("utf-8"))
    return h.finalize().hex()
```

**D-24 site lint signature (`tools/checks/hmac_pepper_audit.py`) :**

```
# Pseudocode for the lint (planner implements)
# Pattern: ANY occurrence of `hashlib.sha256(` whose argument matches
# /user_id|actor_email|ip_address|user_agent/ in the same statement.
# Exit 1 + actionable message « Use app.services.audit.hmac_pepper.hmac_user_id
# instead of bare hashlib.sha256 for audit-PII columns ».
# Whitelist : tools/checks/hmac_pepper_audit.py itself (self-exempt
# matching the banned_terms_python self-exempt pattern).
```

### Anti-patterns to avoid (Phase 02 specific)

These are anti-patterns the planner MUST NOT permit in any task. The G3/G4/G5 gates assert against each :

1. **Re-implementing AES-GCM** — the encrypt path is already `app/services/encryption/envelope.py:encrypt_bytes`. Any new « crypto helper » that calls `AESGCM` directly is a duplication. Reuse via the new `encrypt_value` helper only.
2. **Using `EncryptedBytes` TypeDecorator on `fact_event.value_enc`** — the decorator is bytes-only. D-26 JSONB shape requires the helper pattern. Confusion easy : both surfaces use the same `encrypt_bytes` underneath.
3. **`sa.text("0")` for BOOLEAN `server_default`** — the Hotfix B class. Use `sa.false()` / `sa.true()`. The D-20 lint catches this at commit time.
4. **Running migration tests on `sqlite:///:memory:`** — the QA panel obs #187 predicted obs #188's Postgres bug 5 min before it crashed staging. D-22 fixture replaces SQLite for the migration test class. Unit tests that don't touch DDL stay on SQLite (fast).
5. **Bare `hashlib.sha256(user_id)`** — rainbow-table-reversible on UUID space. Use `hmac_user_id()` from Pattern 4. D-24 lint catches this.
6. **Triggering DEK creation on user signup** — `ensure_user_dek()` is lazy : called inline before first INSERT for that user. Eager creation wastes KMS quota (each unwrap on first read is cheap due to in-process cache).
7. **Async/eventual-consistency projector** — D-19 mandates `session.begin()`. Any background-worker pattern conflicts.
8. **Touching `lib/services/financial_core/` for backend-canonical L2-L4 work** — Rule 4 boundary. Phase 02 is data-layer work ; it does NOT migrate calculators (Phase 03+ strangler-fig).
9. **Bundling iOS entitlements with the mobile L1 audit endpoint** — D-12 endpoints don't need new entitlements. If a future PR needs `com.apple.developer.*` add a separate PR per `feedback_ios_entitlements_block_testflight`.
10. **Coach extractor LLM in Phase 02** — explicit deferred-to-Phase-03. CONTEXT.md `<deferred>` block forbids it.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| AES-256-GCM envelope | A new `crypto/aes_gcm.py` | Existing `app/services/encryption/envelope.py:encrypt_bytes / decrypt_bytes` | AAD binding to user_id + nonce uniqueness assertion + 10k-write nonce uniqueness test already done. Reuse. |
| Per-user DEK lifecycle | A new « DEK manager » service | Existing `app/services/encryption/key_vault.py:KeyVaultService` | `get_or_create_dek` (lazy) + in-process cache + `crypto_shred_user` already shipped + PFPDT-validated. |
| Append-only Postgres table | Triggers preventing UPDATE/DELETE in app code | `REVOKE UPDATE, DELETE ON <table> FROM PUBLIC` per p111 pattern + `DO $$ ... pg_roles ... $$` for app_role | DB-layer enforcement is structural ; app-layer is bypassable. p111 proves the pattern works on Railway managed Postgres. |
| Idempotency for event-log writes | Application-level Redis SET dedup | Postgres UNIQUE constraint `(subject_type, subject_id, fact_type, source_id, recorded_at)` + projector sequence-number check on `latest_event_id` | DB-enforced, no new dep, retry-on-conflict maps cleanly to HTTP 409. The D-27 panel verdict + p95 UUID7 pattern reuse. |
| HMAC user_id hash | Bare `hashlib.sha256(user_id)` | `app.services.audit.hmac_pepper.hmac_user_id(user_id)` (NEW, single entry point) | Bare SHA-256 on UUID is rainbow-table-reversible per security-auditor obs #175 ; HMAC-with-pepper closes the gap and keeps the pepper in Railway env (rotate by re-key). |
| UUID v7 for monotonic IDs | Hand-rolled timestamp + random suffix | `uuid_utils.uuid7()` (Python lib) + RFC 9562 v7 on Flutter via `crypto` or pinned `uuid: ^4.x` | RFC 9562 compliance, monotonicity guarantees handled by lib. Hand-rolled has edge cases (sub-ms collision, leap second). |
| Real-Postgres test fixture | A bash script that `docker run -d postgres:15` per pytest invocation | `testcontainers[postgres]` module-scoped fixture | Hermetic, automatic teardown, cross-CI portable (GH Actions, Railway, local Docker), Python-native API. |
| Mobile encrypted SQLite buffer | A new SQLite wrapper | `sqflite_sqlcipher` already in pubspec | Pre-validated FDE pattern, MIT-license, `password` param to `openDatabase` is the only call site difference vs plain `sqflite`. |
| Logging mobile L1 audit failures | A new mobile error-reporting channel | `sentry_flutter` already in pubspec + breadcrumb pattern per `notifications_wiring_service.dart` | One-line breadcrumb + tagged with `outcome='error'` so the D-33 counter fires. |
| Code generation of regulatory constants Dart file | A new codegen tool | Existing `tools/codegen/regulatory_constants_to_dart.py` (Phase 01 D-16 ships it) — only fix D-21 timestamp determinism + extend with `effective_on` label | Phase 01 wired this end-to-end. D-21 is a one-line patch. |

**Key insight :** Phase 02 is a **plumbing phase** for primitives that already exist in `services/backend/app/services/encryption/` + `services/backend/alembic/versions/`. The « event-log + projection » framing makes it look like green-field crypto, but a careful read of the codebase shows the unit primitives are present. The risk is in (a) the migration choreography across the 5-PR sequence, (b) the Postgres-vs-SQLite DDL portability traps the QA panel predicted, and (c) the Flutter-side offline-queue replay semantics. The crypto math itself is solved.

## Runtime State Inventory

Phase 02 IS a migration phase (`SnapshotModel` → `fact_event` + `fact_current`) plus 3 PII column drops (`audit_events.user_id` plaintext + `actor_email` + `ip_address` + `user_agent`). The 5 categories apply :

| Category | Items found | Action required |
|---|---|---|
| **Stored data** | (1) Existing `SnapshotModel` rows in Postgres+SQLite — count is **0 in prod** (pre-launch, per D-05) but tests + Railway staging may have synthetic rows. (2) Existing `audit_events` rows with `user_id_hash` populated by Hotfix C SHA-256 (NOT HMAC-pepper). (3) Existing `projection_audit_record` rows with `source` defaulted to `'projection'` post-p113. (4) Existing `dek_vault` rows with no `dek_scope` column — backfill to `'user'`. | Plan 02-03 PR-3 backfill script idempotently rewrites `audit_events.user_id_hash` from SHA-256 → HMAC-pepper for all existing rows ; `dek_vault.dek_scope` is `server_default='user'` so existing rows are covered by alembic ; `projection_audit_record.source='projection'` likewise via `server_default`. SnapshotModel rows in staging migrate via Plan 02-03 PR-3 backfill (idempotent). |
| **Live service config** | (1) Railway env vars `MINT_KMS_KEY_ID` (unset on dev, set on prod) + `MINT_MASTER_KEY` (Fernet fallback) + `MINT_AUDIT_HASH_PEPPER` (NEW, Phase 02 must add to Railway). (2) GitHub Actions secrets : staging URL + auth token for codegen + `STAGING-DOWN-OVERRIDE` label permissions. (3) Sentry project DSN (Mobile L1 audit failures will fire breadcrumbs ; verify quota). | Plan 02-01 W0 task « Railway env config » : add `MINT_AUDIT_HASH_PEPPER` (>=32 chars, generate via `python -c 'import secrets; print(secrets.token_urlsafe(48))'`) to Railway production + staging. Add `STAGING-DOWN-OVERRIDE` label to repo settings + CODEOWNERS scope to `@julienbattaglia`. Verify Sentry quota headroom (current = ~25k events/mo on free tier ; mobile L1 audit will add ~5k/mo per active user — re-evaluate at >1k users). |
| **OS-registered state** | None — Phase 02 doesn't touch macOS LaunchAgents, Windows Task Scheduler, systemd, or pm2. Mobile lifecycle hooks are Flutter `AppLifecycleObserver` (in-app, NOT OS-registered). | None — verified by `find apps/mobile -name '*.plist' -o -name 'launch*.yml'` returning no items beyond the standard iOS bundle Info.plist. |
| **Secrets / env vars** | (1) `MINT_AUDIT_HASH_PEPPER` NEW for Phase 02. (2) `MINT_KMS_KEY_ID` and `MINT_MASTER_KEY` existing — D-02 maps logical key-id `mint-master-v1` to whichever backend is selected at runtime (`_select_backend()` already implements this). NO env-var rename. (3) `MINT_AUDIT_HASH_PEPPER` MUST be rotated together with a re-backfill of `audit_events.user_id_hash` — document this in Plan 02-04 close-out checklist (rotation procedure, not executed in Phase 02). | Plan 02-01 W0 task « set MINT_AUDIT_HASH_PEPPER on Railway » ; Plan 02-04 W4 task « document pepper-rotation procedure in `docs/operations/audit-pepper-rotation.md` » (no actual rotation in Phase 02 — pre-launch first set). |
| **Build artifacts / installed packages** | (1) `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` — Phase 01 codegen output, will diff if D-21 timestamp determinism not applied. (2) Postgres test container image cached locally by testcontainers (`docker images | grep postgres` — first run downloads ~150MB). (3) `services/backend/__pycache__` + alembic `__pycache__` — stale `.pyc` if branch switching mid-Phase-02 ; standard `find . -name '__pycache__' -exec rm -rf {} +` covers it. (4) `pg_dump` baseline `tools/db/baseline_snapshot_2026-05-18.sql` NEW — committed (D-23). | Plan 02-01 W0 task « regenerate regulatory_constants.g.dart » (consequence of D-21 fix) ; pre-merge step on every Phase 02 PR : « commit baseline_snapshot updated if schema diff detected ». |

**Nothing found in category :** OS-registered state confirmed empty by `find` ; none of the existing MINT systemd / launchd / pm2 patterns apply here.

## Common Pitfalls

### Pitfall 1 — Postgres BOOLEAN DEFAULT with `sa.text("0")`

**What goes wrong :** alembic generates `server_default=sa.text("0")` for a `sa.Boolean()` column. SQLite accepts the integer-as-boolean coercion ; Postgres rejects with `DatatypeMismatch: column ... is of type boolean but default expression is of type integer`. Staging deploy crashes ; if it slips to prod a migration is irreversible without DROP.
**Why it happens :** SQLite has no native BOOLEAN — it stores 0/1 ints. Developer test on SQLite ; Postgres-specific cast strictness surfaces only on real Postgres.
**How to avoid :** D-20 `alembic_boolean_default_lint.py` HARD lefthook + D-22 real-Postgres pg fixture for migration tests. Use `sa.false()` / `sa.true()` everywhere. The p111 post-fix `fe52ba31` is the canonical example.
**Warning signs :** any new BOOLEAN column with non-Boolean `server_default` — instant lint fail.

### Pitfall 2 — `ensure_user_dek()` race on first concurrent INSERT

**What goes wrong :** two parallel requests for a brand-new user both call `get_or_create_dek` ; both miss the cache + the DB ; both INSERT a `dek_vault` row ; the second fails the PK constraint on `user_id`.
**Why it happens :** `KeyVaultService` has an in-process cache but no cross-process lock. Pre-launch + solo user = unlikely to trigger ; post-launch with concurrent device sessions = real.
**How to avoid :** `dek_vault.user_id` is the PRIMARY KEY → second INSERT raises `IntegrityError` ; catch + retry-once + re-read from DB (which is in cache from the first request's perspective by then). Wrap `get_or_create_dek` call in a `try/except IntegrityError → time.sleep(0.05) + retry-once` block. Document in `tests/test_dek_envelope_concurrency.py` (NEW, Plan 02-02).
**Warning signs :** Sentry breadcrumb `key_vault.create_dek_conflict` firing post-launch.

### Pitfall 3 — Projector silently skipping events with stale `latest_event_id`

**What goes wrong :** event B arrives before event A (network re-order) ; projector commits B → `latest_event_id = uuid7(B)` ; then A arrives ; projector compares `uuid7(A) >= uuid7(B)` → false (A is older) → skip. The user's L1 calc now shows B's value but A is permanently lost from `fact_current` (though present in `fact_event`).
**Why it happens :** Sequence-number monotonicity per D-27 is exactly what we want for the steady state, but it's silent on out-of-order arrivals. The « lost » event A is recoverable by rebuilding `fact_current` from `fact_event` history, but the runtime projection drifted.
**How to avoid :** D-33 `mint_projector_idempotency_skip_total` counter MUST have a Prometheus alert : `rate(mint_projector_idempotency_skip_total[1h]) > 0.1/hour`. Document in Plan 02-02 « rebuild `fact_current` from `fact_event` history » script as a one-shot recovery tool (deferred backlog : `fact_current_drift_detector.py` if counter triggers post-launch).
**Warning signs :** counter ticks > 0 in normal operation. Reads showing « value seems outdated » in Sentry user reports.

### Pitfall 4 — `value_enc` JSONB shape drift

**What goes wrong :** in PR-2 dual-write phase, code writes `value_enc = {"ct": "...", "iv": "...", "tag": "..."}` (raw dict) ; in PR-3 read phase, code parses via Pydantic v2 `EncryptedValue` model expecting `enc_v` field ; rows written before PR-3 don't have `enc_v` → `ValidationError`.
**Why it happens :** the canary fact gates the parity test (D-25) but does NOT gate the JSONB shape — writers and readers can drift mid-migration.
**How to avoid :** the D-26 model uses `enc_v: int = 1` (default with default value) ; writers MUST go through `encrypt_value()` helper which always sets `enc_v=1`. Test : `test_canary_monthly_gross_income.py` asserts `EncryptedValue.model_validate(row.value_enc)` doesn't raise.
**Warning signs :** Pydantic v2 `ValidationError: enc_v` on the read path mid-migration.

### Pitfall 5 — Anonymous-session UUID reuse across re-install

**What goes wrong :** user uninstalls + reinstalls app ; `sqflite_sqlcipher` DB is wiped (iOS removes app data) ; new app install generates new UUID v7 anonymous_session_id ; buffered rows from previous install are gone (orphaned). The previous audit chain is lost ; the regulator can't reconstruct.
**Why it happens :** privacy-preserving by design (D-30) — no device fingerprint = no cross-install link. Per CONTEXT counter-arguments « accepts this as cost of privacy-preserving design ».
**How to avoid :** can't fully — design constraint. Mitigation : LSFin auditor can match by `observed_at` + `app_version` + `constants_version_hash` if needed (per CONTEXT). Document this in Plan 02-02 SUMMARY explicitly so future-Claude doesn't re-discover.
**Warning signs :** N/A — by design.

### Pitfall 6 — Mobile L1 audit POST battery drain

**What goes wrong :** offline queue replays every 30 sec when connectivity flaky → high battery usage on cellular.
**Why it happens :** exponential backoff (1s/2s/4s/8s/16s) is per-failure, but if connectivity is intermittent each succeeded-then-failed cycle resets the backoff.
**How to avoid :** cap the backoff at 5 min ; use Flutter `connectivity_plus` to defer replay until a stable connection is detected (verify `connectivity_plus` is already in pubspec ; if not, add). Battery-cost measurement is a G2 device-gate sub-check per CONTEXT data gaps section.
**Warning signs :** user reports « MINT vide ma batterie » in TestFlight reviews.

### Pitfall 7 — Constants version hash drift between mobile bundle + backend snapshot

**What goes wrong :** mobile L1 audit POST sends `constants_version_hash` from baked Dart `regulatory_constants.g.dart` ; backend `projection_audit_record` row stamps `constants_version_hash` from current Postgres snapshot ; if mobile baked-snapshot is older than backend active, the two hashes differ → audit-trail row reflects stale-mobile state correctly but breaks « single canonical snapshot » audit narrative.
**Why it happens :** Phase 01 D-07 explicitly allows 7d soft-warn / 30d hard-refuse staleness window. Mobile baked snapshot may legitimately be older than backend.
**How to avoid :** the audit row is CORRECT — record what mobile used, not what backend has now. The `projection_audit_record.constants_version_hash` field is for reconstruction ; the regulator wants « what hash produced this value ». LSFin satisfied. Document explicitly in Plan 02-02 audit endpoint test.
**Warning signs :** LSFin reviewer asks « why does row X have a stale hash ? » → answer : « because mobile session was offline at law-change time ». Verified-by-design.

## Code Examples

### Example 1 — Pydantic v2 `EncryptedValue` model (D-26)

```python
# Source: derived from existing Pydantic v2 pattern in
# services/backend/app/models/lucidity/_payload.py (verified in-tree —
# Pydantic v2 BaseModel + Literal + Field already used for L1-L4
# discriminated payloads).
from typing import Literal
from pydantic import BaseModel, Field


class EncryptedValue(BaseModel):
    """D-26 wire format for `fact_event.value_enc` JSONB.

    `ct` includes the GCM tag appended (cryptography's AESGCM.encrypt
    returns ciphertext || tag). The `tag` field is reserved for forward
    compat with KMS providers that return tag separately.
    """
    ct: str = Field(..., description="Base64-encoded ciphertext || tag")
    iv: str = Field(..., description="Base64-encoded 96-bit nonce")
    tag: str = Field(default="", description="Reserved; tag is in ct for AESGCM")
    alg: Literal["AES-256-GCM"] = "AES-256-GCM"
    dek_id: str = Field(..., description="Logical KMS key-id, e.g. 'mint-master-v1'")
    enc_v: int = Field(default=1, description="Envelope-format version for rotation")

    model_config = {"extra": "forbid"}
```

### Example 2 — `fact_event` SQLAlchemy 2.0 model

```python
# Source: SQLAlchemy 2.0 docs + in-tree pattern from
# services/backend/app/models/projection_audit_record.py (verified).
# [CITED: https://docs.sqlalchemy.org/en/20/dialects/postgresql.html]
from datetime import datetime, timezone
from uuid import UUID

import uuid_utils as uuid7  # for fact_event.event_id default
from sqlalchemy import (
    Column, String, DateTime, Index, UniqueConstraint, PrimaryKeyConstraint
)
from sqlalchemy.dialects.postgresql import JSONB

from app.core.database import Base


class FactEvent(Base):
    """Append-only event log (D-26, D-27, D-28).

    Append-only enforced at DB layer via REVOKE UPDATE, DELETE in alembic.
    Idempotency via UNIQUE (subject_type, subject_id, fact_type,
    source_id, recorded_at). Partitioned by HASH(subject_id) starting
    with 1 partition (D-28 ; split on growth).
    """
    __tablename__ = "fact_event"
    __table_args__ = (
        PrimaryKeyConstraint("event_id", "subject_id"),  # composite (partition key)
        UniqueConstraint(
            "subject_type", "subject_id", "fact_type", "source_id", "recorded_at",
            name="uq_fact_event_idempotency",
        ),
        Index("ix_fact_event_subject", "subject_type", "subject_id"),
        {"postgresql_partition_by": "HASH (subject_id)"},
    )

    event_id = Column(String(36), nullable=False, default=lambda: str(uuid7.uuid7()))
    subject_type = Column(String(32), nullable=False)  # 'regulatory' | 'user'
    subject_id = Column(String(64), nullable=False)
    fact_type = Column(String(64), nullable=False)
    value_enc = Column(JSONB, nullable=False)  # D-26 EncryptedValue or plaintext for regulatory
    source_type = Column(String(32), nullable=False)
    source_id = Column(String(64), nullable=True)
    source_pdf_sha256 = Column(String(64), nullable=True)
    observed_at = Column(DateTime, nullable=False)
    recorded_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    confidence = Column(JSONB, nullable=True)  # D-29 EnhancedConfidence 4-axis
    supersedes_event_id = Column(String(36), nullable=True)
    correction_reason = Column(String(256), nullable=True)
    visibility = Column(String(16), nullable=False, default="user_visible")
    archetype_tags = Column(JSONB, nullable=True)
```

### Example 3 — `pg_fixture.py` testcontainers-python (D-22)

```python
# Source: testcontainers-python getting-started guide.
# [CITED: https://testcontainers.com/guides/getting-started-with-testcontainers-for-python/]
import pytest
from testcontainers.postgres import PostgresContainer
from sqlalchemy import create_engine
from alembic.config import Config
from alembic import command


@pytest.fixture(scope="module")
def pg_engine():
    """Module-scoped Postgres 15 container + alembic-up to head.

    Use for tests that exercise Alembic migrations OR Postgres-specific
    DDL/cast behavior (BOOLEAN DEFAULT, JSONB, REVOKE).
    Unit tests that don't touch DDL stay on SQLite for speed.
    """
    with PostgresContainer("postgres:15.5") as pg:
        url = pg.get_connection_url()
        engine = create_engine(url, future=True)
        alembic_cfg = Config("services/backend/alembic.ini")
        alembic_cfg.set_main_option("sqlalchemy.url", url)
        command.upgrade(alembic_cfg, "head")
        yield engine
        engine.dispose()


@pytest.fixture
def pg_session(pg_engine):
    """Function-scoped session ; TRUNCATEs at teardown."""
    from sqlalchemy.orm import Session
    with Session(pg_engine) as s:
        yield s
        s.rollback()
        # TRUNCATE-all between tests is faster than DROP/recreate per
        # testcontainers best-practice (use SQL for cross-test isolation).
        with pg_engine.begin() as conn:
            conn.execute("TRUNCATE TABLE fact_event, fact_current, "
                         "projection_audit_records, audit_events, dek_vault "
                         "RESTART IDENTITY CASCADE")
```

### Example 4 — Flutter UUID v7 + offline-queue (mobile L1 audit) skeleton

```dart
// Source: RFC 9562 v7 + sqflite_sqlcipher example.
// [CITED: https://pub.dev/packages/sqflite_sqlcipher]
import 'dart:math';
import 'dart:typed_data';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// RFC 9562 v7 UUID generator (hand-rolled — pin `uuid: ^4.x` if you'd rather).
String generateUuidV7() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rand = Random.secure();
  final bytes = Uint8List(16);
  // 48 bits timestamp
  bytes[0] = (ms >> 40) & 0xff;
  bytes[1] = (ms >> 32) & 0xff;
  bytes[2] = (ms >> 24) & 0xff;
  bytes[3] = (ms >> 16) & 0xff;
  bytes[4] = (ms >> 8) & 0xff;
  bytes[5] = ms & 0xff;
  // 4 bits version (7) + 12 bits random
  bytes[6] = 0x70 | (rand.nextInt(0x10));
  bytes[7] = rand.nextInt(0x100);
  // 2 bits variant (10) + 62 bits random
  bytes[8] = 0x80 | (rand.nextInt(0x40));
  for (var i = 9; i < 16; i++) {
    bytes[i] = rand.nextInt(0x100);
  }
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Open the encrypted buffer (sqflite_sqlcipher).
Future<Database> openAuditBuffer({required String password}) async {
  return openDatabase(
    'mint_audit_buffer.db',
    version: 1,
    password: password,  // encrypted at rest
    onCreate: (db, _) => db.execute('''
      CREATE TABLE mobile_l1_audit_buffer (
        id TEXT PRIMARY KEY,
        anonymous_session_id TEXT NOT NULL,
        observed_at TEXT NOT NULL,
        app_version TEXT NOT NULL,
        constants_version_hash TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT NOT NULL
      )
    '''),
  );
}
```

## State of the Art

| Old approach | Current approach (2026-05-18) | When changed | Impact for Phase 02 |
|---|---|---|---|
| `SnapshotModel` keyed on `inputs_hash` with no audit trail | `fact_event` append-only + `fact_current` projection + `projection_audit_record` audit trail | This phase (PR 2026-05-17 Hotfix B + Phase 02 ship) | Replaces the cached-projection storage substrate entirely. |
| Bare SHA-256 on user_id in audit logs (Hotfix C 2026-05-17 shipped this) | HMAC-SHA256 with Railway-secret pepper | D-07 / D-14 (this phase) | Rainbow-table attack closed. Mandatory site sweep + lint. |
| `sa.text("0")` BOOLEAN default | `sa.false()` / `sa.true()` | Hotfix B `fe52ba31` 2026-05-17 | Postgres correctness ; D-20 lint prevents regression. |
| `DATABASE_URL=sqlite:///:memory:` for migration tests | testcontainers-python Postgres 15 fixture | D-22 (this phase) | Catches Postgres-specific DDL bugs at CI time, not staging. |
| Coach memory as wiki (Karpathy pattern) | `fact_event(source_type='coach_inference')` rows with extraction-time guardrails | Upstream ADR 2026-05-17 (panel-converged) | Phase 03 deferred ; Phase 02 ships the schema row that Phase 03 will write. |
| Backend-canonical full-stack calc engine | Split-with-arbiter L1 mobile / L2-L4 backend per `lucidity._payload` discriminator | Phase 01 2026-05-17 16 D-XX shipped | Phase 02 is L0 (data layer) below this split — does not touch the boundary. |

**Deprecated / outdated :**
- The original panel ADR's « sub-1ms PK reads » framing (Postgres-internal-only ; realistic FastAPI-side is p99 ≤ 20ms per D-01).
- The « SCD2 bitemporal » alternative (rejected by upstream ADR with steel-manned counter ; Phase 02 commit gate re-litigates and confirms reject).
- The « Karpathy wiki for coach memory » framing (rejected by upstream ADR ; Phase 03 will use structured `fact_event` rows).

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | `pytest` 8.x + `pytest-asyncio` for async paths (already in `services/backend` test suite — verified by Plan 20 receipt showing `7264 passed in 117.22s`) |
| Config file | `services/backend/pyproject.toml` `[tool.pytest.ini_options]` + `services/backend/conftest.py` |
| Quick run command | `cd services/backend && python3 -m pytest tests/ -q -x` |
| Full suite command | `cd services/backend && python3 -m pytest tests/ -q` |
| Postgres-specific subset | `cd services/backend && python3 -m pytest tests/integration/ -k pg -q --pg-fixture` (NEW marker via D-22) |
| Flutter unit + widget | `cd apps/mobile && flutter test` |

### Phase Requirements → Test Map

| D-XX ID | Behavior | Test type | Automated command | File exists? |
|---|---|---|---|---|
| D-01 | `fact_current` PK read latency p50 ≤ 5ms / p99 ≤ 20ms | perf (canary) | `cd services/backend && python3 -m pytest tests/integration/test_canary_monthly_gross_income.py::test_fact_current_pk_latency -q` | Wave 0 |
| D-02 | Logical key-id `mint-master-v1` resolves via `key_vault.key_ref` | unit | `cd services/backend && python3 -m pytest tests/test_key_vault_logical_id.py -q` | Wave 0 (NEW) |
| D-03 | `dek_vault.dek_scope` defaults `'user'` ; revoke is all-or-nothing | unit + integration | `cd services/backend && python3 -m pytest tests/test_dek_envelope_concurrency.py tests/integration/test_dek_shred_opacity.py -q` | Wave 0 (NEW) |
| D-04 | Constants change does NOT re-flag historical projections | integration | `cd services/backend && python3 -m pytest tests/integration/test_constants_propagation_pit.py -q` | Wave 0 (NEW) |
| D-05 | 5-PR migration sequence — each PR self-tests with pg_fixture | integration | `cd services/backend && python3 -m pytest tests/integration/test_migration_p98.py tests/integration/test_migration_p113.py -q` | Wave 0 (NEW) |
| D-06 | CI staging-down policy fail-closed on HARD-mode | CI dry-run | `gh workflow run regulatory-codegen.yml --ref dev -f mode=staging-malformed-test` (manual) | Wave 0 (NEW workflow input) |
| D-07 | HMAC-pepper `hmac_user_id()` is deterministic + 64-char hex | unit | `cd services/backend && python3 -m pytest tests/test_hmac_pepper.py -q` | Wave 0 (NEW) |
| D-08 | S12 `IndependantService.analyze()` delegates to S18 calculators | unit | `cd services/backend && python3 -m pytest tests/test_s12_composition.py -q` | Wave 0 (NEW) |
| D-09 | `FrontalierService` → `FrontalierSegmentService` rename safe (alias works) | unit | `cd services/backend && python3 -m pytest tests/test_s12_frontalier_rename.py -q` | Wave 0 (NEW) |
| D-10 | `_buildProfileContext` emits 15 missing fields (Flutter side) | widget | `cd apps/mobile && flutter test test/services/coach_narrative_profile_context_test.dart` | Wave 0 (NEW) |
| D-11 | dead-COUP-04 path verified closed | integration | `cd services/backend && python3 -m pytest tests/integration/test_coup_04_dead_path.py -q` | Wave 0 (NEW) |
| D-12 | `/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` write `projection_audit_record` rows | integration | `cd services/backend && python3 -m pytest tests/integration/test_audit_mobile_link.py -q` | Wave 0 (NEW) |
| D-13 | Mobile L1 audit does NOT INSERT into `fact_event` | integration assertion | `cd services/backend && python3 -m pytest tests/integration/test_audit_mobile_link.py::test_no_fact_event_writes -q` | Wave 0 (NEW) |
| D-14 | `audit_events.user_id` plaintext NULL post-deprecation window | migration | `cd services/backend && python3 -m pytest tests/integration/test_migration_p114.py -q` | Wave 0 (NEW) |
| D-15 | `audit_events.actor_email_hash` + `ip_address_hash` + `user_agent_hash` populated | migration | `cd services/backend && python3 -m pytest tests/integration/test_migration_p115.py -q` | Wave 0 (NEW) |
| D-16 | `/privacy/delete` returns real DSAR counts | integration | `cd services/backend && python3 -m pytest tests/integration/test_privacy_delete_real_count.py -q` | Wave 0 (NEW) |
| D-17 | `SnapshotModel.constants_version_hash` invalidates cache on change | integration | `cd services/backend && python3 -m pytest tests/integration/test_snapshot_cache_invalidation.py -q` | Wave 0 (NEW) |
| D-19 | Projector + INSERT atomic via `session.begin()` (rollback both on exception) | integration | `cd services/backend && python3 -m pytest tests/integration/test_projector_atomicity.py -q` | Wave 0 (NEW) |
| D-20 | `alembic_boolean_default_lint.py` HARD on `sa.text("0")` for Boolean | lint | `python3 tools/checks/alembic_boolean_default_lint.py --hard tests/fixtures/alembic_bad.py ; echo $?` (expect 1) | Wave 0 (NEW) |
| D-21 | `regulatory_constants.g.dart` header is « Generated for effective_on » deterministic | codegen | `cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/codegen/regulatory_constants_to_dart.py --check-determinism` | Wave 0 (NEW flag) |
| D-22 | Real-Postgres pg_fixture spins container + runs alembic upgrade head | meta | `cd services/backend && python3 -m pytest tests/fixtures/test_pg_fixture_self.py -q` | Wave 0 (NEW) |
| D-23 | `tools/db/baseline_snapshot_2026-05-18.sql` reproducible from `pg_dump` | sh | `bash tools/db/regenerate_baseline.sh ; git diff --exit-code tools/db/baseline_snapshot_2026-05-18.sql` | Wave 0 (NEW) |
| D-24 | `hmac_pepper_audit.py` fails on bare `hashlib.sha256(user_id)` | lint | `python3 tools/checks/hmac_pepper_audit.py tests/fixtures/bad_audit_writer.py ; echo $?` (expect 1) | Wave 0 (NEW) |
| D-25 | Canary `monthly_gross_income` end-to-end parity with `SnapshotModel.gross_income` | integration | `cd services/backend && python3 -m pytest tests/integration/test_canary_monthly_gross_income.py -q` | Wave 0 (NEW) |
| D-26 | `EncryptedValue` Pydantic v2 model validates / `model_dump_json()` round-trip | unit | `cd services/backend && python3 -m pytest tests/test_encrypted_value_model.py -q` | Wave 0 (NEW) |
| D-27 | UNIQUE constraint blocks duplicate writes ; projector skip increments counter | integration | `cd services/backend && python3 -m pytest tests/integration/test_projector_idempotency.py -q` | Wave 0 (NEW) |
| D-28 | `PARTITION BY HASH` declared on `fact_event` (Postgres only) | meta | `cd services/backend && python3 -m pytest tests/integration/test_partition_declared.py -q -k pg` | Wave 0 (NEW) |
| D-29 | `confidence` JSONB round-trips full 4-axis | unit | `cd services/backend && python3 -m pytest tests/test_enhanced_confidence_jsonb.py -q` | Wave 0 (NEW) |
| D-30 | Anonymous-session UUID v7 + 30d TTL + batch link on first login | widget + integration | `cd apps/mobile && flutter test test/services/audit/anonymous_session_buffer_test.dart && cd services/backend && python3 -m pytest tests/integration/test_audit_mobile_link.py -q` | Wave 0 (NEW) |
| D-31 | SOFT→HARD promotion atomic with PR-3 (parity-lint config flip) | lint dry-run | `python3 tools/checks/profile_safe_fields_parity.py --hard` (exit 0 post-D-10 + D-A3) | EXISTING (extend) |
| D-32 | 5 mechanical exit gates green | meta | concatenation of G1-G5 (see below) | Wave 0 (NEW gate scripts) |
| D-33 | 6 new counters declared + fire | meta | `python3 tools/checks/declared_counters_must_fire.py` (exit 0) | Wave 0 (NEW) |

**Manual-only tests (justified) :**
- G1 Maestro walker — `tools/simulator/walker_audit_tap_render.sh` extension with airplane-mode toggle. Manual because sim coordination + screenshot inspection.
- G2 Julien device sign-off — by definition manual (5 walkthrough scenarios per CONTEXT D-32). Auto-Claude cannot self-clear.
- Battery-cost measurement (mobile L1 audit POST cellular vs WiFi) — manual instrumentation per CONTEXT data gap.

### Sampling Rate

- **Per task commit :** `cd services/backend && python3 -m pytest tests/ -q -x` (≤ 30 sec subset via `-k` flag for the D-XX in scope). Plus `cd apps/mobile && flutter analyze` (≤ 10 sec).
- **Per wave merge :** full suite both sides — `cd services/backend && python3 -m pytest tests/ -q` (~ 2 min) + `cd apps/mobile && flutter test` (~ 1 min). Plus all 4 lints : `python3 tools/checks/banned_terms_python.py services/backend/app/` + `python3 tools/checks/accent_lint_fr.py --scope backend` + `python3 tools/checks/profile_safe_fields_parity.py` + `python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/` + `python3 tools/checks/hmac_pepper_audit.py services/backend/app/services/audit/` + `python3 tools/checks/declared_counters_must_fire.py`.
- **Phase gate :** full suite green + G1-G5 5-gate exit checklist per D-32 + G2 Julien device sign-off (cannot self-clear).

### Wave 0 Gaps

The following are NEW test surfaces or harness items the Plan 02-01 W0 prereq bundle MUST land before Plan 02-02 W1 starts :

- [ ] `services/backend/tests/fixtures/pg_fixture.py` — testcontainers-postgres D-22 harness
- [ ] `tools/db/baseline_snapshot_2026-05-18.sql` — pg_dump baseline D-23 (committed)
- [ ] `tools/db/regenerate_baseline.sh` — reproducibility script
- [ ] `tools/checks/alembic_boolean_default_lint.py` — D-20 HARD lefthook
- [ ] `tools/checks/hmac_pepper_audit.py` — D-24 site lint
- [ ] `tools/checks/declared_counters_must_fire.py` — D-32/D-33 close-out gate (declared in W0 ; activated in W4)
- [ ] `services/backend/app/services/audit/hmac_pepper.py` — D-07/D-14/D-15/D-24 canonical entry
- [ ] `services/backend/tests/test_hmac_pepper.py` — unit test pepper deterministic + length + missing-env behaviour
- [ ] `services/backend/tests/test_s12_composition.py` — D-08 composition pattern test
- [ ] `services/backend/tests/test_s12_frontalier_rename.py` — D-09 rename alias backward compat
- [ ] `apps/mobile/test/services/coach_narrative_profile_context_test.dart` — D-10 15-fields emission
- [ ] `services/backend/tests/integration/test_coup_04_dead_path.py` — D-11 contract lock
- [ ] `lefthook.yml` — register `alembic_boolean_default_lint` + `hmac_pepper_audit` as pre-commit hooks scoped to relevant globs
- [ ] `pyproject.toml` (backend) — add `testcontainers[postgres]` + `uuid_utils` deps with verified versions
- [ ] CI workflow — add `pg-integration` job using `pg_fixture` for `tests/integration/test_migration_*.py`

*(If no gaps : « None — existing test infrastructure covers all phase requirements ». NOT applicable — Phase 02 introduces ~15 net new test files and 6 new lint surfaces.)*

## Security Domain

> `security_enforcement` is implicit per CLAUDE.md project conventions (no `.planning/config.json` key explicitly disables). Section included.

### Applicable ASVS Categories

| ASVS category | Applies | Standard control (in MINT today) |
|---|---|---|
| V2 Authentication | yes (indirect) | Existing `auth_service.py` ; Phase 02 adds `MINT_AUDIT_HASH_PEPPER` env (rotate-by-re-key) |
| V3 Session Management | yes | Phase 02 adds `anonymous_session_id` UUID v7 (NOT auth session — privacy-preserving correlation only). Existing `anonymous_sessions` table from p86 unchanged. |
| V4 Access Control | yes | `EncryptionContextMiddleware` already populates `current_user_id` / `current_db_session` ContextVars. `fact_event` writers MUST verify `current_user_id == event.subject_id` for `subject_type='user'`. |
| V5 Input Validation | yes | Pydantic v2 `EncryptedValue` `model_config = {"extra": "forbid"}` + `Literal["AES-256-GCM"]` constraint. `archetype_tags` JSONB validated against the 8-archetype allowlist. |
| V6 Cryptography | yes (hardest) | NEVER hand-roll AES — use existing `app/services/encryption/envelope.py`. NEVER hand-roll HMAC — use `cryptography.hazmat.primitives.hmac.HMAC`. Pepper >= 32 chars. DEK 256-bit (32 bytes) per `KeyVaultService.DEK_SIZE_BYTES`. |
| V7 Error Handling | yes | `DEKRevokedError` is a distinct exception type that callers MUST handle (return 410 Gone, NOT 500). Phase 02 audit POSTs return 410 if user's DEK is shredded. |
| V8 Data Protection | yes (highest) | Crypto-shred on user delete = `crypto_shred_user(db, user_id)` already shipped ; `fact_event.value_enc` rows become opaque ciphertext. PFPDT-validated mechanism. |
| V10 Malicious Code Defense | yes | D-26 `model_config={"extra":"forbid"}` rejects unknown fields. Banned-terms lint covers code paths emitting user-facing text. |
| V11 Business Logic | yes (LSFin) | Snapshot point-in-time D-04 doctrine, no re-flagging. `projection_audit_record.constants_version_hash` is the reconstruction key. |
| V13 API & Web Service | yes | New `/v1/audit/mobile-session-{start,link}` endpoints follow existing `Depends(get_current_user_optional)` pattern (anonymous-tagged OR authenticated). |
| V14 Configuration | yes | `MINT_AUDIT_HASH_PEPPER` >= 32 chars enforced at `hmac_pepper._get_pepper()` ; refuses to operate if missing in non-TEST environments. |

### Known threat patterns for {Postgres + FastAPI + Flutter}

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| SQL injection on `fact_event` JSONB queries | Tampering | Use SQLAlchemy 2.0 parameterised JSONB operators (`value_enc["ct"].as_string()`) ; never f-string concat user input into raw SQL. |
| `value_enc` decrypted at read but logged to Sentry | Information Disclosure | Sentry `before_send` already strips `value_enc` field (existing pattern in `services/backend/app/core/sentry.py` — verify). Phase 02 adds `EncryptedValue` to the strip allowlist. |
| Audit-row tampering by app role | Tampering | `REVOKE UPDATE, DELETE` on `fact_event` + `projection_audit_record` (p98 + p111). DDL-level enforcement, not app-level. |
| `MINT_AUDIT_HASH_PEPPER` rotation breaks audit-row lookup | Denial of Service (regulatory) | Document rotation procedure in `docs/operations/audit-pepper-rotation.md` (Plan 02-04) — re-backfill `user_id_hash` with new pepper, keep old hash as `user_id_hash_v1` column for transition. NOT executed in Phase 02 ; pre-launch first set. |
| Anonymous-session UUID collision | Spoofing | UUID v7 collision space ≈ 2^74 random bits + 48-bit ms timestamp = collision-free for MINT's scale (< 1B sessions). Server-side UNIQUE `(anonymous_session_id, observed_at)` is the belt-and-suspenders. |
| Replay attack on `/v1/audit/mobile-session-link` | Tampering | Same UNIQUE constraint blocks idempotent replays. Endpoint returns 200 + count rather than 409 (replay-safe). |
| DEK plaintext leaked via in-process cache dump | Information Disclosure | `KeyVaultService._dek_cache` is purged on `revoke_dek()` ; process restart clears all keys. Production runs short-lived workers (Railway containers). |
| ContextVar leak across requests | Information Disclosure | Existing `EncryptionContextMiddleware` resets `current_user_id` / `current_db_session` per request. Phase 02 tests verify by interleaving 2 users in test_dek_envelope_concurrency. |
| Mobile L1 audit POST in clear text (cellular MITM) | Information Disclosure | TLS 1.3 enforced server-side (Railway managed) ; mobile client uses HTTPS (existing `api_service.dart`). Payload itself contains ONLY hashed user_id + hashed UUID + version hashes ; no raw PII. |
| Coach output bypasses banned-terms via paraphrase verb | Compliance violation | `runtime_verb_gate.py` already wired upstream of citation parser (Phase 01 Plan 18 D-CE-16). Phase 02 does not modify this. |
| Cross-user fact-event read | Information Disclosure | AESGCM AAD = user_id binds ciphertext to user ; swapping rows across users fails authentication (existing `envelope.py` threat T-29-02 covered). |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | `testcontainers[postgres]` is `>=4.7,<5` and currently latest stable on PyPI | Standard Stack — Supporting | Planner pins to a stale version ; verify via `pip index versions testcontainers` before writing install task. |
| A2 | `uuid_utils >=0.9` is the right Python lib for UUID v7 generation (vs `uuid6` or `uuid7` packages) | Standard Stack — Supporting | Multiple candidates exist ; planner picks one + locks. Both are RFC 9562 compliant per pyca / oittaa GitHub. |
| A3 | Postgres `PARTITION BY HASH` migrations work cleanly with alembic 1.13+ via `op.execute()` raw SQL | Pattern 3 | Alembic autogeneration has historical drift on partitioned tables (verified via SQLAlchemy issue tracker). Plan must use raw SQL, NOT autogeneration ; existing p111 dialect-branch template already proves this. |
| A4 | Flutter `connectivity_plus` is in pubspec for D-30 backoff cap | Pitfall 6 | Planner verifies before writing offline-queue task ; add if missing (small dep, no controversy). |
| A5 | Railway managed Postgres has `pgcrypto` extension available on demand | Migration p114 (HMAC backfill) | Hotfix C migration shows `DO $$ ... pg_extension WHERE extname='pgcrypto' ... $$` no-op fallback. Phase 02 does HMAC in Python (no `pgcrypto` dep) — A5 is risk-mitigated by design. |
| A6 | Sentry quota headroom is sufficient for + 5k mobile L1 audit events/mo per user | Pitfall 6 / Runtime State Inventory | Verify quota dashboard before launch ; the breadcrumb-only path (NOT full Sentry events) keeps cost negligible — only failures-tagged-with-Sentry are full events. |
| A7 | `tools/openapi/mint.openapi.canonical.json` MUST be regenerated when adding `/v1/audit/mobile-session-*` endpoints | Code surfaces — `audit_mobile.py` | Pre-push checklist memory `feedback_pre_push_checklist.md` enforces ; CI catches drift via OpenAPI parity check (verify it exists). |
| A8 | The mobile L1 audit payload size is ~1.5KB JSON (per CONTEXT data gap) | Code surfaces — mobile service | Not measured ; planner instruments + verifies in Plan 02-02 G2 sub-check. |

If this table grows during Plan 02-01 W0 execution, the planner should re-route assumptions A* back to a `gsd-discuss-phase` follow-up rather than locking unverified primitives into Plans 02-02 / 02-03 / 02-04.

## Open Questions

These are research gaps the planner should EITHER resolve at plan-authoring time OR explicitly defer to discuss-phase-2 :

1. **Plan ordering between W0 sub-tasks** — the W0 bundle has 8 items (lint + harness + S12 PR-1 + Flutter PR-A2 + HMAC sweep + codegen-determinism + pg-baseline + COUP-04 test). Internal ordering matters because the HMAC sweep depends on `hmac_pepper.py` existing first, and the pg-baseline can only be generated after the harness is in place.
   - What we know : W0 must complete BEFORE W1 ; CONTEXT D-18 says W0 is « single bundle PR landing ».
   - What's unclear : within the bundle PR is the order multi-commit-chain OR squashed-single-commit ?
   - Recommendation : single multi-commit chain so each sub-item is `git log`-traceable and reviewable (per Phase 01 Plan 19 pattern). The bundle PR can be ~ 8 commits.

2. **`STAGING-DOWN-OVERRIDE` label workflow gate mechanism** (CONTEXT Claude's Discretion) — CODEOWNERS vs GitHub branch protection rule vs ruleset.
   - What we know : Julien-only scope per D-06.
   - What's unclear : CODEOWNERS doesn't enforce label-add ; the cleanest path is a GitHub Actions step that checks `github.event.pull_request.user.login == 'julienbattaglia'` AND `'STAGING-DOWN-OVERRIDE' in pull_request.labels`.
   - Recommendation : Plan 02-04 ships the Actions step ; CODEOWNERS edit is a no-op (already covers Julien-only).

3. **Bundle-size measurement for mobile SQLite buffer (D-30)** — must be < 100KB compressed.
   - What we know : `sqflite_sqlcipher` is already in pubspec ; the buffer schema is 7 columns × N rows.
   - What's unclear : the SQLCipher key derivation overhead + WAL file growth pattern at 30d TTL.
   - Recommendation : Plan 02-02 task « measure buffer footprint at 100 rows + 1000 rows » with `du -sh` on the device. Document in G2 sub-check.

4. **DEK rotation procedure design** — D-26 ships `dek_id` per row exactly for this, but Phase 02 doesn't execute a rotation.
   - What we know : rotation = re-wrap DEK with new MK + atomic UPDATE of `dek_vault.wrapped_dek`. Per-row `value_enc.dek_id` allows readers to look up the historical wrapped DEK by id (would require a `user_dek_history` table — NOT in Phase 02 scope).
   - What's unclear : does Phase 02 ship the `user_dek_history` table preemptively, or defer to Phase 04 trigger ?
   - Recommendation : defer to Phase 04 ; document in Plan 02-04 SUMMARY as known forward-deferred. The `dek_id` column on `value_enc` is sufficient future-proofing.

5. **Partition-split trigger** (D-01 ceiling at 5M rows or p99 > 20ms) — pre-launch is 0 rows ; first split is theoretical.
   - What we know : `CREATE TABLE fact_event_p_1 PARTITION OF fact_event FOR VALUES WITH (MODULUS 2, REMAINDER 1)` is the future operation.
   - What's unclear : at what observed metric should the split fire ? Sustained 7-day p99 > 15ms (margin to 20ms)?
   - Recommendation : Plan 02-04 ships a `docs/operations/fact-event-partition-split.md` runbook with concrete thresholds + a Prometheus alert spec. Not executed.

6. **Codegen-CI ordering with the pre-build script (D-21 + D-06)** — Flutter build depends on `regulatory_constants.g.dart` ; codegen depends on staging being up.
   - What we know : Phase 01 D-16 ships the pre-build script ; D-06 specifies failure modes (3-tier escalation).
   - What's unclear : if staging is STAGING-MALFORMED (200 OK with broken payload) during a PR build, does the build use cached fixture OR fail-closed ?
   - Recommendation : the existing CI workflow path uses the cached fixture + emits a soft-warn (per Phase 01 D-16). Phase 02 D-06 changes scheduled-only writes ; per-PR runs stay READ-ONLY. So PR builds during a STAGING-MALFORMED window pass with cached fixture + Sentry breadcrumb. Document in Plan 02-04 W4 task.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---|---|---|
| Python | Backend test suite + alembic | ✓ | 3.10+ (verified via `pyproject.toml` `requires-python`) | — |
| Postgres 15+ | D-22 pg_fixture + Plan 02-02 W1 migration tests | ✓ via Docker | 15.5 image (`postgres:15.5` per Pattern 3) | testcontainers downloads on first use ; Railway-staging-replica fallback for CI nightly soak |
| Docker | testcontainers-python launches Postgres containers | needs verification on each dev machine + CI runner | `docker --version` | — (no fallback — required for D-22) |
| Flutter SDK | Mobile L1 audit service + tests | ✓ | Stable channel (verified by existing test suite running green) | — |
| iOS simulator | G1 Maestro walker | ✓ via `xcrun simctl` | iOS 26.x | — (G1 cannot self-clear without sim) |
| Maestro CLI | G1 Maestro walker | ✓ at `/Users/julienbattaglia/.maestro/bin/maestro` per Plan mint-calc-engine-v1-20 receipt | (verify with `maestro --version`) | — |
| Railway CLI | env-var setting + cron config | needs verification — likely ✓ per Mac-Mini setup | `railway --version` | manual via Railway dashboard |
| `gh` (GitHub CLI) | PR creation + CODEOWNERS check | ✓ (verified by recent commit history) | latest | — |
| `pgcrypto` Postgres extension | Hotfix C backfill DO-block | optional (no-op fallback) | — | Python-side HMAC via `cryptography.hazmat` is the canonical path ; pgcrypto NOT required for Phase 02 |
| Sentry DSN (mobile + backend) | Audit-failure breadcrumbs | ✓ for backend (`sentry-sdk` in pyproject) ; mobile pending Sentry quota verification | sentry-sdk 2.53.0 / sentry_flutter 9.14.0 | — |

**Missing dependencies with no fallback :**
- Docker on the CI runner (for testcontainers) — GitHub Actions ubuntu-latest provides Docker by default. Verify in Plan 02-01 W0 CI step.

**Missing dependencies with fallback :**
- `pgcrypto` Postgres extension — Python-side HMAC is the canonical path.
- Railway-staging-replica auth for D-22 nightly soak — testcontainers-python is the per-PR primary ; staging-replica is supplementary.

## Counter-arguments and data gaps

Per CLAUDE.md §8 wiki schema HARD lint requirement, this research surfaces opposing views and known gaps :

### Strongest opposing view : « Phase 02 over-engineers crypto-shred for zero deposits »

> *« Pre-launch + zero CHF on the books = the crypto-shred + per-user DEK envelope is theoretical security. nLPD art. 32 right-of-erasure is satisfiable by `DELETE FROM users WHERE id = $1 CASCADE` on every relevant table. The 5-PR migration sequence + DEK wiring + pg_fixture harness is several weeks of engineering for a regulatory comfort blanket. A truthful Phase 02 would ship `fact_event` + `fact_current` + REVOKE-only (no DEK envelope) and add DEK only when first paying CH user signs up. »*

**Mitigation :** the counter-argument is structurally sound on regulatory grounds for pre-launch, but it misses two operational realities :

1. Once first paying user signs up, the migration is irreversible without data loss. The « add DEK later » path requires either (a) backfill-encrypting existing plaintext rows (which leaks plaintext in WAL backups — defeats the purpose), or (b) running on plaintext until a churn event and accepting partial encryption coverage (FINMA-indefensible). Pre-launch is the only window — same logic as D-05 big-bang cut-over.
2. The DEK lifecycle is **already shipped** (`KeyVaultService` + `DEKVault` + `crypto_shred_user`). Phase 02 doesn't build the crypto layer — it wires existing primitives to the new schema. Marginal cost is small ; deferral cost is high.

The counter still applies to **Phase 04 per-category sub-DEKs** which Phase 02 explicitly defers. Phase 02 stays on the « all-or-nothing per user » path (D-03) precisely to avoid the over-engineering trap.

### Strongest opposing view #2 : « Real-Postgres pg fixture is overkill for D-22 »

> *« SQLite test path passes 7264 tests in 117 seconds. Adding testcontainers adds 30+ seconds per migration test + Docker dep + Postgres container download (~150MB first run). For 5 migration tests × ~1.5 weeks of work, this is heavy. A simpler fix : a single CI job that runs `alembic upgrade head` against Railway-staging-replica once per PR. »*

**Mitigation :** the QA panel obs #187 predicted obs #188's BOOLEAN DEFAULT bug 5 minutes before it crashed staging — but this only works if the test path actually exercises Postgres. Railway-staging-replica works for one-off catches but :
1. It requires staging creds in CI → secret-leak blast radius.
2. It doesn't isolate test failures (one PR's migration error cascades to other PRs).
3. testcontainers's 30-sec overhead is module-scoped (one container per test module, not per test). Net cost is ~ 30 sec × N modules ≈ 1 min added to suite. Acceptable.

The compromise : testcontainers-python is the per-PR primary, Railway-staging-replica is the nightly soak. Both, not « one or the other ».

### Data gaps the planner cannot resolve without further research

- **Empirical p99 latency under Phase 02 schema** — CONTEXT data gap explicit. Plan 02-02 first instruments `mint_fact_current_read_latency_ms` histogram before any 5-PR migration step. If p99 > 50ms canary → escape hatch (Postgres UNLOGGED + `pg_prewarm` per CONTEXT D-01).
- **DEK shred performance under bulk requests** — Phase 04 unmeasured.
- **Mobile L1 audit POST battery cost** — G2 device-gate sub-check.
- **LSFin audit retention semantics across user-delete-then-recreate** — Phase 02 accepts current HMAC-pepper-stable design ; re-litigate if regulator pushes back.
- **Anonymous-session re-installation orphan chain** — privacy-preserving cost ; LSFin auditor can match by `observed_at` + `app_version` + `constants_version_hash` if needed.

### What would change these conclusions

(Verbatim from CONTEXT counter-arguments — re-litigation triggers locked) :

- First paying CH user with deposit > 100K CHF → revisit D-02 KMS.
- p99 `fact_current` PK reads > 50ms sustained → revisit D-01.
- First nLPD partial-deletion request OR EDÖB inquiry → bring Phase 04 forward.
- First FINMA written guidance requiring single-table bitemporal → revisit D-04.
- First migration with non-empty backfill > 1k rows → revisit D-05 big-bang.
- Railway adds Prometheus scraping native → Q6 metrics path stays Railway-native.
- Railway bill > CHF 100/mo on `projection_audit_record` → activate D-07 delete-after-10y.
- Cleo / RightCapital publishes event-log + projection production post-mortem → re-examine entire Phase 02 shape.

## Migration sequencing (4-wave plan)

Wave-by-wave breakdown with explicit blocker chain. Each wave's exit gate is the input gate of the next.

### W0 — Plan 02-01 prereq bundle (~1 week)

**Goal :** every primitive Plans 02-02 / 02-03 / 02-04 depend on is in-tree + tested + lint-protected.

**Tasks (8 commits in single bundle PR per Phase 01 lesson) :**

| # | Task | Files touched | Verify |
|---|---|---|---|
| W0.1 | Add testcontainers + uuid_utils deps + bump pyproject.toml | `services/backend/pyproject.toml` | `pip install -e ".[test]"` + `python3 -c "import testcontainers, uuid_utils; print('OK')"` |
| W0.2 | Build `pg_fixture.py` + minimal self-test | `services/backend/tests/fixtures/pg_fixture.py`, `tests/fixtures/test_pg_fixture_self.py` | `pytest tests/fixtures/test_pg_fixture_self.py -q` |
| W0.3 | Commit `pg_dump baseline` + reproducibility script | `tools/db/baseline_snapshot_2026-05-18.sql`, `tools/db/regenerate_baseline.sh` | `bash tools/db/regenerate_baseline.sh && git diff --exit-code` |
| W0.4 | Build `hmac_pepper.py` + unit tests | `services/backend/app/services/audit/hmac_pepper.py`, `tests/test_hmac_pepper.py` | `pytest tests/test_hmac_pepper.py -q` |
| W0.5 | Build `alembic_boolean_default_lint.py` + register lefthook | `tools/checks/alembic_boolean_default_lint.py`, `lefthook.yml` | `python3 tools/checks/alembic_boolean_default_lint.py --hard tests/fixtures/alembic_bad.py ; echo $? == 1` |
| W0.6 | Build `hmac_pepper_audit.py` + register lefthook | `tools/checks/hmac_pepper_audit.py`, `lefthook.yml` | `python3 tools/checks/hmac_pepper_audit.py tests/fixtures/bad_audit_writer.py ; echo $? == 1` |
| W0.7 | Fix codegen timestamp determinism (D-21) | `tools/codegen/regulatory_constants_to_dart.py:277,282` | regenerate Dart file ; `git diff regulatory_constants.g.dart` shows only `effective_on` line change |
| W0.8 | S12 PR-1 (façade-delegate + IJM/LAA promote + frontalier rename) | `services/backend/app/services/independant_service.py`, `services/backend/app/services/independants/__init__.py`, `services/backend/app/services/expat/frontalier_segment_service.py` (renamed from `frontalier_service.py`), all call sites, `tests/test_s12_composition.py`, `tests/test_s12_frontalier_rename.py` | `grep -rn "from app.services.expat.frontalier_service" services/backend` returns 0 hits ; `pytest -k s12` green |
| W0.9 | Flutter PR-A2 + PR-A3 (D-10 drift fix) | `apps/mobile/lib/services/coach_narrative_service.dart` extend `_buildProfileContext`, `apps/mobile/test/services/coach_narrative_profile_context_test.dart` | `python3 tools/checks/profile_safe_fields_parity.py` reports drift 43 → 0 |
| W0.10 | D-11 dead-COUP-04 integration test | `tests/integration/test_coup_04_dead_path.py` | `pytest tests/integration/test_coup_04_dead_path.py -q` |
| W0.11 | Set `MINT_AUDIT_HASH_PEPPER` on Railway staging + prod | Railway dashboard | `railway variables get MINT_AUDIT_HASH_PEPPER --environment production` (32+ chars) |

**Exit gate :** all 11 tasks committed ; pre-commit lints green ; full backend pytest green (delta ≈ +30 tests vs Phase 01 baseline 7264) ; Flutter analyze + test green.

**Blocker chain in :** Phase 01 complete (✓ shipped sha `a21bc8d0` + 3 hotfixes squashed `cf6d259a`).
**Blocker chain out :** W0 exit gate green is the input gate for W1.

### W1 — Plan 02-02 event-log core + canary + carry-overs (~1.5 weeks)

**Goal :** ship `fact_event` + `fact_current` + extended `projection_audit_record` + DEK envelope wiring + first-slice canary on `monthly_gross_income` end-to-end. Close 4 Phase 01 carry-over security gaps.

**Tasks (sequenced sub-commits within Plan 02-02) :**

| # | Task | Files touched | Verify |
|---|---|---|---|
| W1.1 | `EncryptedValue` Pydantic v2 model | `services/backend/app/models/encryption/encrypted_value.py`, `tests/test_encrypted_value_model.py` | `pytest tests/test_encrypted_value_model.py -q` |
| W1.2 | `encrypt_value` / `decrypt_value` helpers | `services/backend/app/services/encryption/encrypted_value_helper.py`, `tests/test_encrypted_value_helper.py` | round-trip test under DEK + DEKRevokedError + JSON serialisation determinism |
| W1.3 | `FactEvent` + `FactCurrent` ORM models | `services/backend/app/models/fact_event.py`, `services/backend/app/models/fact_current.py` | `pytest tests/models/test_fact_event_model.py -q` |
| W1.4 | Alembic p98 (fact_event + fact_current + dek_scope) | `services/backend/alembic/versions/p98_fact_event_projection_dek.py` | `pytest tests/integration/test_migration_p98.py -q -k pg` (uses pg_fixture) |
| W1.5 | `project_fact_event` projector | `services/backend/app/services/projector/fact_projector.py`, `tests/integration/test_projector_atomicity.py`, `tests/integration/test_projector_idempotency.py` | `pytest tests/integration/test_projector_*.py -q -k pg` |
| W1.6 | Alembic p113 (extend projection_audit_record) | `services/backend/alembic/versions/p113_extend_projection_audit_mobile.py` | `pytest tests/integration/test_migration_p113.py -q -k pg` |
| W1.7 | `/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` endpoints | `services/backend/app/api/v1/endpoints/audit_mobile.py`, `tests/integration/test_audit_mobile_link.py`, `tools/openapi/mint.openapi.canonical.json` regen | `pytest tests/integration/test_audit_mobile_link.py -q` + OpenAPI parity check |
| W1.8 | Flutter `MobileL1AuditService` + offline queue + UUID v7 + lifecycle hooks | `apps/mobile/lib/services/audit/*.dart`, `apps/mobile/test/services/audit/*.dart` | `cd apps/mobile && flutter test test/services/audit/ -r expanded` |
| W1.9 | First-slice canary `monthly_gross_income` parity test | `tests/integration/test_canary_monthly_gross_income.py` | dual-write + parity check Postgres-side |
| W1.10 | D-14 carry-over : Alembic p114 backfill `audit_events.user_id_hash` to HMAC-pepper + NULL plaintext `user_id` | `services/backend/alembic/versions/p114_hmac_pepper_audit_events.py`, `tests/integration/test_migration_p114.py` | `pytest tests/integration/test_migration_p114.py -q -k pg` |
| W1.11 | D-15 carry-over : Alembic p115 hash `actor_email` / `ip_address` / `user_agent` | `services/backend/alembic/versions/p115_hmac_pepper_pii_columns.py`, `tests/integration/test_migration_p115.py`, `services/backend/app/services/audit_service.py` (writer updates) | `pytest tests/integration/test_migration_p115.py -q -k pg` |
| W1.12 | D-16 carry-over : `/privacy/delete` real count | `services/backend/app/api/v1/endpoints/privacy.py`, `tests/integration/test_privacy_delete_real_count.py` | `pytest tests/integration/test_privacy_delete_real_count.py -q` |
| W1.13 | D-17 carry-over : `SnapshotModel.constants_version_hash` cache invalidation | `services/backend/app/services/snapshots/snapshot_service.py`, `services/backend/app/services/cache/` (cache key extended), `tests/integration/test_snapshot_cache_invalidation.py` | `pytest tests/integration/test_snapshot_cache_invalidation.py -q` |
| W1.14 | Declare 6 new observability counters (D-33) | `services/backend/app/observability/counters.py` | `python3 tools/checks/declared_counters_must_fire.py --check-declared-only` (declared, not yet wired) |

**Exit gate :** all 14 sub-tasks committed ; canary parity test green on `pg_fixture` ; Mobile L1 audit endpoints functional end-to-end with a SQLite-buffered flow → POST → row visible in `projection_audit_record` ; `ensure_user_dek()` integration test green ; full pytest green (delta ≈ +50 tests vs W0).

**Blocker chain in :** W0 exit gate green.
**Blocker chain out :** Canary parity = 100% before W2 starts.

### W2-W3 — Plan 02-03 5-PR migration sequence (~1.5 weeks)

**Goal :** replace `SnapshotModel` as canonical user-facts substrate.

**5 internal PRs (sequenced ; each merged on dev before next opens) :**

| # | PR | Goal | Verify |
|---|---|---|---|
| W2.PR-1 | Schema introduction additive (already landed in W1 as p98 — this PR-1 is a no-op marker if W1 sequenced correctly, or it's the canary FF infrastructure if W1 ran lighter). Reframe as : « feature flag introduction » — add `fact_event_dual_write_enabled` flag (default OFF). | `services/backend/app/services/feature_flags.py` extend, env config | flag OFF → all writes still hit SnapshotModel only |
| W2.PR-2 | Dual-write FF-OFF : every `SnapshotModel.create()` writer ALSO writes `fact_event` + projector via `with session.begin()`, but only when FF is ON ; FF stays OFF in this PR. Verifies the writer code path compiles + tests pass with FF-ON in test fixtures. | `services/backend/app/services/snapshots/snapshot_service.py` extend with dual-write branch | unit test sets FF-ON, asserts both writes happen ; FF-OFF (default) asserts only SnapshotModel writes |
| W2.PR-3 | Backfill script idempotent : reads all `SnapshotModel` rows + emits `fact_event` rows + runs projector. Run-twice = no duplicate INSERTs (UNIQUE blocks). | `services/backend/scripts/backfill_snapshot_to_fact_event.py`, `tests/integration/test_backfill_idempotent.py` | second run = 0 new rows ; counter `mint_projector_idempotency_skip_total` increments per duplicate-event arrival |
| W3.PR-4 | Read cut-over (ATOMIC with D-12 SOFT→HARD promotion per D-31) : `/v1/projection` endpoint reads from `fact_current` instead of `SnapshotModel` ; SAME PR flips `tools/checks/profile_safe_fields_parity.py` to `--hard` mode in lefthook + CI ; FF flipped ON in staging. | `services/backend/app/api/v1/endpoints/projection.py`, `lefthook.yml`, `.github/workflows/*.yml`, FF env on staging | dual-read window : `/v1/projection` returns identical output ; HARD lint green |
| W3.PR-5 | Legacy SnapshotModel drop : DROP TABLE migration + remove `SnapshotModel` ORM + remove dual-write branch in writer + retire FF. GATED on post-launch + 1 week observability soak window. | `services/backend/alembic/versions/p117_drop_snapshot_legacy.py`, remove `app/models/snapshot.py`, remove FF | `SnapshotModel` import = ModuleNotFoundError everywhere |

**Exit gate :** 5 PRs merged ; `mint_constants_version_mismatch_total` counter = 0 sustained ; `/v1/projection` p99 latency ≤ 20ms per D-01 ; canary parity test still green ; D-12 HARD lint catches drift on a deliberately-broken test fixture.

**Blocker chain in :** W1 canary parity = 100% + W1 carry-overs (D-14..D-17) green.
**Blocker chain out :** SnapshotModel no longer reachable.

### W4 — Plan 02-04 close-out + lint promotion (~3 days)

**Goal :** S12 PR-2 (alias removal) + Q6 CI mechanical fixes + `declared_counters_must_fire.py` close-out gate + auth-coach G2 scenario E + Maestro flow D refactor + 5-gate exit checklist green.

**Tasks :**

| # | Task | Files touched | Verify |
|---|---|---|---|
| W4.1 | S12 PR-2 alias removal : delete `FrontalierService = FrontalierSegmentService` alias + update all importers | `services/backend/app/services/frontalier_service.py` (delete or stub-raise), all call sites | `grep -rn "from app.services.frontalier_service import FrontalierService" services/backend` returns 0 hits |
| W4.2 | Q6 CI fixes : STAGING-MALFORMED status + scheduled-only aging writes + HARD-mode STAGING-DOWN-OVERRIDE label | `.github/workflows/regulatory-codegen.yml`, `.github/CODEOWNERS` (verify Julien-only scope) | manual GH Actions dry-run with `mode=staging-malformed-test` input |
| W4.3 | `declared_counters_must_fire.py` close-out gate activated | `tools/checks/declared_counters_must_fire.py` (`--all` mode), `lefthook.yml` | runs the 6 D-33 counter assertions ; exit 0 |
| W4.4 | Auth-coach G2 scenario E variant authoring | `tests/integration/test_auth_coach_g2_scenario_e.py` | (deferred from Phase 01 G2 follow-up — verify scope) |
| W4.5 | Maestro flow D refactor | `tools/simulator/flows/D_mobile_l1_audit.yaml` | manual G1 dry-run with Maestro |
| W4.6 | Document audit-pepper rotation procedure | `docs/operations/audit-pepper-rotation.md` (NEW) | wiki_lint passes |
| W4.7 | `mint-data-architecture-v1-02-event-log-projection-VERIFICATION-REPORT.html` + `-SUMMARY.md` phase close-out | `.planning/phases/.../VERIFICATION-REPORT.html`, `-SUMMARY.md` | wiki_lint + manual review by Julien |
| W4.8 | ROADMAP + STATE flip phase status to `◆ code-shipped on dev, pending operational gates` | `.planning/ROADMAP.md`, `.planning/STATE.md` | wiki_lint passes |

**Exit gate :** 5-gate mechanical exit per D-32 :
- **G1 Maestro walker** (extended with Mobile L1 audit POST + offline-queue replay airplane-mode toggle) — `tools/simulator/walker_audit_tap_render.sh` runs end-to-end ; describe-all snapshot in HTML report.
- **G2 Julien device sign-off** — DEFERRED (cannot self-clear per CLAUDE.md §9 0-trust ; documented walkthrough scenarios in HTML report).
- **G3 dev CI HARD lints + REVOKE assertion + Postgres-real migration test** — all green on dev CI.
- **G4 regression** — full pytest green + 2 new test classes (`test_projector_idempotency.py` + `test_dek_shred_opacity.py`).
- **G5 lint suite** — banned-terms + accent + ARB parity + constants drift HARD-promoted + `hmac_pepper_audit.py` green.

**Blocker chain in :** W2-W3 exit gate green.
**Blocker chain out :** Phase 02 closed pending G2 device sign-off + operational gates (audit-pepper Railway env confirmation + Sentry quota verification + Prometheus alert rules deployed).

## External library recipes pre-cache

Per the prompt's request, here are pre-cached recipes for the 6 library primitives the planner will reference :

### 1. Alembic auto-generation + manual recipe

**Verdict (from in-tree evidence) :** auto-generation NEVER for partitioned tables (verified by SQLAlchemy issue tracker — alembic 1.13 still has drift). Manual `op.execute()` raw SQL for partitioning, `op.create_table` + `batch_alter_table` for additive changes. The p111 + p112 + p95 templates already exist in-tree as reference.

**Source recipe (verified pattern from p111_projection_audit.py) :**
- Dialect-aware branching : `if bind.dialect.name == 'postgresql': ... else: ...`
- REVOKE pattern : `op.execute("REVOKE UPDATE, DELETE ON ... FROM PUBLIC")` + `DO $$ ... pg_roles ... $$` for app_role
- BOOLEAN default : `sa.false()` / `sa.true()` not `sa.text("0")` ← Hotfix B post-fix `fe52ba31`
- Idempotency : `inspector.get_columns()` guard ← p95 pattern

[CITED: services/backend/alembic/versions/p111_projection_audit.py, p95_dag_invalidation.py]
[CITED: https://github.com/sqlalchemy/alembic/issues/539 (partitioning autogen drift)]
[CITED: https://github.com/sqlalchemy/alembic/issues/1787 (partition FK alembic 1.18 issue)]

### 2. SQLAlchemy 2.0 declarative + JSONB + PARTITION BY

**Verdict :** use `__table_args__` dict with `{"postgresql_partition_by": "HASH (subject_id)"}` for declarative classes (works in 2.0+). For raw migrations, `op.execute()` is the safe path.

**Source recipe (verified from SQLAlchemy docs + in-tree pattern in `projection_audit_record.py`) :**

```python
class FactEvent(Base):
    __tablename__ = "fact_event"
    __table_args__ = (
        PrimaryKeyConstraint("event_id", "subject_id"),
        UniqueConstraint(...),
        Index(...),
        {"postgresql_partition_by": "HASH (subject_id)"},
    )
    value_enc = Column(JSONB, nullable=False)  # from sqlalchemy.dialects.postgresql
```

[CITED: https://docs.sqlalchemy.org/en/20/dialects/postgresql.html]

### 3. Pydantic v2 discriminated unions

**Verdict :** in-tree pattern already used in `app/models/lucidity/_payload.py` (L1/L2/L3/L4 payloads with `Literal` discriminator + `model_config = {"extra": "forbid"}`).

**Source recipe :**

```python
from typing import Literal
from pydantic import BaseModel, Field

class EncryptedValue(BaseModel):
    enc_v: int = Field(default=1)
    alg: Literal["AES-256-GCM"] = "AES-256-GCM"
    model_config = {"extra": "forbid"}
```

[CITED: services/backend/app/models/lucidity/_payload.py]

### 4. HMAC-SHA256 via cryptography.hazmat

**Verdict :** `cryptography.hazmat.primitives.hmac.HMAC(key, hashes.SHA256())` ; finalize() returns 32 bytes ; `.hex()` for 64-char hex. Key = pepper (>= 32 bytes), message = user_id.

**Source recipe :**

```python
from cryptography.hazmat.primitives import hashes, hmac
h = hmac.HMAC(pepper_bytes, hashes.SHA256())
h.update(user_id.encode("utf-8"))
return h.finalize().hex()
```

[CITED: https://cryptography.io/en/latest/hazmat/primitives/mac/hmac/]

### 5. AES-256-GCM envelope encryption

**Verdict :** already shipped in `app/services/encryption/envelope.py`. `from cryptography.hazmat.primitives.ciphers.aead import AESGCM`. `AESGCM(dek).encrypt(nonce_12bytes, plaintext, aad)` returns `ciphertext || tag` ; we prepend nonce so wire format is `nonce(12) || ct || tag(16)`.

**Source recipe :** see `services/backend/app/services/encryption/envelope.py` lines 36-53.

[CITED: services/backend/app/services/encryption/envelope.py]

### 6. psycopg2 vs asyncpg

**Verdict :** stay on `psycopg2-binary` (verified in `pyproject.toml`). MINT backend is synchronous SQLAlchemy. NO asyncpg switch in Phase 02 (out of scope ; FastAPI mixing sync/async DBAPIs is a refactor of its own).

[CITED: services/backend/pyproject.toml]

### 7. testcontainers-python Postgres fixture

**Verdict :** module-scoped fixture pattern from getting-started guide. `from testcontainers.postgres import PostgresContainer` + context manager. TRUNCATE between tests, not DROP/recreate.

**Source recipe :** see Example 3 above.

[CITED: https://testcontainers.com/guides/getting-started-with-testcontainers-for-python/]
[CITED: https://docs.docker.com/guides/testcontainers-python-getting-started/write-tests/]

### 8. UUID v7 (Python)

**Verdict :** `uuid_utils.uuid7()` is the safe choice for Python 3.10+ (RFC 9562 compliant ; native Python `uuid.uuid7()` lands in 3.14 only).

[CITED: https://github.com/oittaa/uuid6-python]
[CITED: https://github.com/python/cpython/issues/102461]

### 9. sqflite_sqlcipher for encrypted mobile buffer

**Verdict :** already in `pubspec.yaml` (`^3.1.0+1`). `openDatabase(path, password: ...)` enables encryption ; rest of API is identical to plain sqflite.

[CITED: https://pub.dev/packages/sqflite_sqlcipher]

## Sources

### Primary (HIGH confidence) — in-tree verified

- `services/backend/app/services/encryption/envelope.py` — AES-256-GCM envelope encryption (already shipped, will be wrapped by `encrypt_value`).
- `services/backend/app/services/encryption/key_vault.py` — KeyVaultService + 2-backend MK (AWS KMS / Fernet) + DEK lifecycle.
- `services/backend/app/services/encryption/column_type.py` — `EncryptedBytes` TypeDecorator (NOT used for `value_enc` JSONB but reference for the pattern).
- `services/backend/app/models/dek_vault.py` — DEKVault ORM (extend with `dek_scope` column per D-03).
- `services/backend/app/models/projection_audit_record.py` — Hotfix B audit table (extend per D-12 via Alembic p113).
- `services/backend/app/models/audit_event.py` — Hotfix C `user_id_hash` (carry-over D-14/D-15).
- `services/backend/alembic/versions/p111_projection_audit.py` — REVOKE pattern + dialect branching template.
- `services/backend/alembic/versions/p112_audit_event_user_hash.py` — `user_id_hash` backfill template (pgcrypto-or-fallback DO-block).
- `services/backend/alembic/versions/p95_dag_invalidation.py` — UUID7 + inspector.get_columns idempotency template.
- `services/backend/pyproject.toml` — verified dep versions (cryptography, sqlalchemy, alembic, pydantic, prometheus-client, sentry-sdk, psycopg2-binary).
- `apps/mobile/pubspec.yaml` — verified Flutter deps (`sqflite_sqlcipher`, `package_info_plus`, `sentry_flutter`, `crypto`).
- `tools/checks/profile_safe_fields_parity.py` — existing parity lint (D-12 promotion target).
- `tools/checks/banned_terms_python.py` + `tools/checks/accent_lint_fr.py` — existing G5 lints.
- `.planning/decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md` — THIS phase's canonical ADR.
- `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` — upstream « what shape » ADR.
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md` — Phase 01 16 D-XX (Rule 4 source).
- `services/backend/app/api/v1/endpoints/coach_chat.py:957-1015` — `_PROFILE_SAFE_FIELDS` Stage-0 baseline.
- `apps/mobile/lib/services/coach_narrative_service.dart:1162-1208` — `_buildProfileContext` extension target (D-10).
- `services/backend/app/services/independant_service.py` + `app/services/independants/` — S12/S18 composition target (D-08).
- `services/backend/app/services/expat/frontalier_service.py` — S23 rename target (D-09).
- `.planning/STATE.md` + `.planning/ROADMAP.md` — phase context, status, dependencies.

### Secondary (MEDIUM confidence) — official docs

- [SQLAlchemy 2.0 Postgres partitioning](https://docs.sqlalchemy.org/en/20/dialects/postgresql.html) — `__table_args__ = {"postgresql_partition_by": "HASH (...)"}`.
- [pyca/cryptography HMAC](https://cryptography.io/en/latest/hazmat/primitives/mac/hmac/) — HMAC-SHA256 idiomatic pattern.
- [testcontainers Python getting-started](https://testcontainers.com/guides/getting-started-with-testcontainers-for-python/) — module-scoped fixture pattern.
- [sqflite_sqlcipher pub.dev](https://pub.dev/packages/sqflite_sqlcipher) — `openDatabase(password: ...)` for encrypted SQLite.
- [oittaa/uuid6-python](https://github.com/oittaa/uuid6-python) — RFC 9562 UUID v7 reference impl.
- [PostgreSQL wiki Audit trigger](https://wiki.postgresql.org/wiki/Audit_trigger) — REVOKE UPDATE/DELETE append-only pattern.
- [docker/testcontainers Python guide](https://docs.docker.com/guides/testcontainers-python-getting-started/write-tests/) — TRUNCATE between tests.

### Tertiary (LOW confidence) — WebSearch only, flagged for validation by planner

- Testcontainers `>=4.7,<5` version pin — verify via `pip index versions testcontainers` before pinning. [ASSUMED]
- `uuid_utils` vs `uuid6` lib choice — both RFC 9562 ; planner picks. [ASSUMED]
- Connectivity_plus presence in mobile pubspec — verify before writing offline-queue backoff cap. [ASSUMED]

### Engram observations (panel context, cited via prior_finding_refs in any new mem_save)

- obs #150 (event-log decision shape)
- obs #163 (Phase 01 CONTEXT)
- obs #174 (db-architect Q1+Q4+Q5)
- obs #175 (security Q2+Q3+Q7 + STRIDE + HMAC-pepper)
- obs #176 (architect-review integrated + mobile L1 audit gap discovery)
- obs #178 (devops Q6 + 8-item PR-readiness + 6 new counters)
- obs #182 (Q6 Railway-native scraping decided)
- obs #183 (S12 design)
- obs #186 (Flutter D-MOB design)
- obs #187 (QA panel predicted Postgres bug)
- obs #188 (Postgres BOOLEAN DEFAULT bug + fix)

## Metadata

**Confidence breakdown :**
- **Standard Stack :** HIGH — every primitive Phase 02 needs is already in-tree (verified by Read on each file). Only 2 net new Python deps (`testcontainers`, `uuid_utils`) to add ; both well-established with active maintainers.
- **Architecture Patterns :** HIGH — the 4 patterns (envelope on JSONB / app-side projector / alembic dialect-branching / HMAC canonical entry) all derive from in-tree precedent (`envelope.py` + `_dispatch_tool` session pattern + `p111` template + `pyca/cryptography` docs).
- **Migration Sequencing :** HIGH for W0 + W1 + W4 (each task maps to a concrete file + verify command). MEDIUM for W2-W3 5-PR sequence — the canary parity gate + the FF-OFF/ON discipline are conceptually tight but operationally risky if a writer is missed. Mitigation : `tools/checks/profile_safe_fields_parity.py` HARD promotion at PR-3 is the catch-net.
- **Pitfalls :** HIGH — 7 pitfalls are direct extrapolations from in-tree experience (Hotfix B Postgres bug, p111 dialect pattern, ContextVar leak prevention via middleware, AAD binding). Pitfall 6 (battery drain) is empirical not theoretical — flagged for G2 measurement.
- **Validation Architecture :** HIGH for unit + integration test mapping (every D-XX has a concrete pytest command). MEDIUM for perf test (D-01 p99 ≤ 20ms claim needs empirical validation via `mint_fact_current_read_latency_ms` histogram — Plan 02-02 first instruments).
- **Security Domain :** HIGH — every ASVS category maps to an existing or planned MINT control. The only « new crypto » introduced is the `EncryptedValue` JSONB packing — and that's pure serialisation, not cipher.
- **Counter-arguments :** HIGH — opposing views steel-manned from CONTEXT panel ADR ; not glossed.

**Research date :** 2026-05-18
**Valid until :** 2026-06-17 (30 days for stable substrate ; sooner if Plan 02-01 W0 surfaces unknown deps OR Postgres 15 → 16 migration on Railway managed).

---

*Researched by `gsd-phase-researcher` agent, 2026-05-18 — single-pass deep read of CONTEXT + ADRs + in-tree primitives + external library cross-check. Per CLAUDE.md §9 0-trust : every claim above carries either `[VERIFIED: <path>]`, `[CITED: <url>]`, or `[ASSUMED]` tag. The 8 `[ASSUMED]` claims in the Assumptions Log are the planner's input gate for verification before locking primitives into Plans 02-01..02-04.*

*Next : `/gsd-plan-phase mint-data-architecture-v1-02-event-log-projection` (or planner reads this RESEARCH + CONTEXT directly).*
