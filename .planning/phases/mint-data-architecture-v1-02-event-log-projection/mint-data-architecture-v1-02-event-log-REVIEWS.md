---
phase: mint-data-architecture-v1-02-event-log-projection
phase_number: 02
reviewers:
  - gemini-2.5-pro (external, cross-vendor independence)
  - claude-mint-panel (5 specialists: architect-review + security-auditor + database-architect + postgres-pro + qa-expert)
  - claude-opus-4-7 (post-iter-2 fresh-session via `claude -p`, same model family — independence sacrificed for iter-2 absorption validation)
reviewers_skipped:
  - codex (gpt-5.3-codex): usage limit hit 2026-05-18T10:45Z, retry after 13:36 local
  - coderabbit: not installed
  - opencode: not installed
reviewed_at: 2026-05-18T13:00:00Z (iter-2 post-revision Claude-Opus session)
plans_reviewed:
  - mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-PLAN.md
  - mint-data-architecture-v1-02-event-log-02-event-log-core-canary-PLAN.md
  - mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md
  - mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md
upstream_artifacts_reviewed:
  - mint-data-architecture-v1-02-event-log-CONTEXT.md (33 D-XX locked)
  - mint-data-architecture-v1-02-event-log-RESEARCH.md (implementation primitives, 1451 lines)
  - mint-data-architecture-v1-02-event-log-VALIDATION.md (Nyquist verify-command map)
panel_obs_ids:
  architect-review: 195
  security-auditor: see body (saved to engram, no obs id surfaced inline)
  database-architect: 196
  postgres-pro: 197
  qa-expert: 198
description: Cross-AI peer review of Phase 02 (event-log + projection + DEK envelope). Gemini 2.5 Pro (external) rated LOW. Claude MINT specialist panel (architect-review + security-auditor + database-architect + postgres-pro + qa-expert) escalated to MEDIUM with 8 HIGH + 12 MEDIUM findings Gemini missed. Iter-2 plan revision absorbed 41/44 patches (93.2%). Post-iter-2 Claude-Opus fresh-session review (commit `35eb5eee` baseline) validates absorption AND surfaces 3 new HIGH (SQLite test-path divergence, handshake replay ordering, secret handoff hygiene) + 1 finding ALL prior reviewers missed (session-start audit-pollution attack). Final verdict: MEDIUM, close to LOW. Execution-ready conditioned on 4 acceptance items.
---

# Cross-AI Plan Review — Phase 02 (event-log + projection)

> **Coverage** :
> - **iter-1** (external) : Gemini 2.5 Pro ✓ complete review.
> - **iter-1b** (internal panel) : 5 MINT-tuned Claude specialists ✓ complete reviews.
> - **iter-2** (external, pending) : Codex hit usage limit at 10:45Z, retry available after 13:36 local. Prompt preserved at `/tmp/gsd-review-prompt-02.md` for re-run.
>
> **Risk verdict consensus (5 of 6 reviewers)** : MEDIUM, **not** LOW. The Gemini LOW verdict was breadth-over-depth — it correctly assessed migration choreography but did not model the cryptographic, schema-level, Postgres-specific, or Nyquist-coverage surfaces that the specialist panel exposed.

---

## 1. Gemini 2.5 Pro Review (iter-1, external, cross-vendor)

### Summary

The overall plan quality is exceptionally high, demonstrating a mature and rigorous approach to a complex, foundational data architecture migration. The four-wave structure (W0-W4) logically de-risks the project by front-loading prerequisites, proving the core path with a canary, choreographing the irreversible migration with explicit checkpoints, and ensuring a clean close-out. The plans are rooted in deep research that leverages existing, battle-tested primitives within the codebase, significantly reducing implementation risk. The validation strategy is comprehensive, mapping all 33 locked decisions to specific, automated tests. This phase is well-prepared and ready for execution with a very high degree of confidence.

### Strengths

- **Learning from Experience:** Postgres `BOOLEAN DEFAULT` bug mitigation (D-20 lint + D-22 testcontainers harness) explicitly addresses Hotfix B.
- **Risk Mitigation Strategy:** 5-PR sequence + feature-flagged dual-write + canary on `monthly_gross_income` + dual-read window = best-in-class de-risking.
- **Leveraging Existing Primitives:** Reuses `key_vault.py` + `envelope.py` + established Alembic patterns ; minimal new-bug surface.
- **Comprehensive Validation:** VALIDATION.md mapping every D-XX → automated verify command rated « exemplary ».
- **Clarity and Thoroughness:** CONTEXT + RESEARCH + PLAN files steel-man counter-arguments.

### Concerns

- **MEDIUM** — D-05 « zero prod data » big-bang strategy has no documented contingency if a user signs up between W0 and W2-W3 cutover.
- **LOW** — 4-wave × 5-PR choreography depends on perfect sequencing.
- **LOW** — `profile_safe_fields_parity` HARD-with-allowlist in PR-3 then allowlist-drop in PR-A3 = process smell.
- **LOW** — `testcontainers-python` adds Docker dep to dev environment.

### Suggestions

1. Add `SELECT COUNT(*) FROM users` zero-user prod gate at head of Plan 02-03.
2. Document Docker dep in `services/backend/README.md` or CONTRIBUTING.md.
3. PR-3 commit message + PR description: cite allowlist rationale + forward-link to Plan 02-04 PR-A3.

### Risk Assessment

**LOW** — Meticulous planning, risk mitigation, and validation strategies reduce execution risk. Primary remaining risk is operational : adherence to migration choreography or invalidation of zero-prod-data assumption.

---

## 2. Claude MINT-tuned Specialist Panel (iter-1b, internal, 5 agents in parallel)

Each agent ran with full MINT context (CLAUDE.md, ADR `2026-05-17-data-architecture-event-log-vs-bitemporal.md`, engram memory from Phase 01 + Phase 02 panels, 191 prior obs). Adversarial mode — instructed to find what Gemini missed.

---

### 2.1. architect-review (obs #195) — **MEDIUM**, 5 plan-patches

Reviewing : L1/L2 boundary integrity, service-boundary discipline, strangler-fig migration, cross-phase invariants.

**Strengths NOT covered by Gemini** :
1. RESEARCH §1 classifies `fact_event` writers as L0 data persistence (NOT lucidity) — prevents future contributors treating `fact_current` as L1 calc-engine input.
2. D-26 `EncryptedValue` Pydantic model mirrors Phase 01 D-02 `lucidity._payload.py` discriminator pattern.
3. D-19 transactional projector (`session.begin()` vs PL/pgSQL trigger) preserves Python observability counters.
4. D-13 clean separation (Mobile L1 audit ≠ fact_event dual-write) prevents 10y retention forcing onto DEK-shreddable user-facts.

**NEW concerns** :
- **MEDIUM** — `fact_current(subject_type='regulatory')` read-path UNDEFINED. CONTEXT line 250 + VALIDATION 02-02-09 say regulatory codegen writes these rows, but no plan specifies WHO reads them. If mobile ever reads them to bypass codegen-baked constants, L1 offline-canonical breaks silently.
- **MEDIUM** — PR-3 atomic trio **backfill-rollback NOT documented**. If staging-zero-drift gate fails on read-cutover, the already-backfilled `fact_event` rows in staging Postgres are NOT rolled back by reverting the PR code. « Fix-up commit on same branch » (Plan 02-03 Task 2:290) only patches read-side.
- **MEDIUM** — **D-12 label collision** in Plan 02-03 `requirements_addressed`. Phase 02 D-12 = « D-MOB-03 Mobile L1 audit POST » (CONTEXT:127) but Plan 02-03:36 reads « D-12 parity-lint SOFT→HARD » meaning *Phase 01* D-12. Executor running `/gsd-execute-phase` may mis-route. Same defect at Plan 02-03:38 + 87.
- **MEDIUM** — **S12 alias window (D-09)** creates 2-week dual-API surface with no lint enforcement. Plan 02-01 ships `FrontalierService = FrontalierSegmentService` alias W0 ; Plan 02-04 removes W4. Between them, new code lands without restriction.
- **LOW** — **D-19 projector transaction-pattern inconsistency**. Plan 02-02 Task 3 step 6 uses `with session.begin():`. Plan 02-03 PR-2:214 uses `db.begin_nested()` (SAVEPOINT). Different semantics — must pick one + docstring.
- **LOW** — 33 D-XX over-decomposed (D-08/09, D-12/13, D-14/15 each = one decision split). Merge to ~26.
- **LOW** — Phase 01 D-05 audit-trail closure narrower than CONTEXT claims. D-30 logs session lifecycle but NOT individual L1 projection computations.

**5 plan-patches** :
1. Plan 02-02 Task 3 — `tools/checks/no_mobile_fact_current_regulatory_read.py` HARD lefthook on `apps/mobile/**/*.dart`.
2. Plan 02-03 — rename `D-12` → `Phase-01 D-12` in every `requirements_addressed` + `<verify>` block. Use `D-MOB-03` when meaning Mobile L1 audit.
3. Plan 02-03 Task 2 `<how-to-verify>` — add 7th gate : pre-HARD-flip `pg_dump` snapshot ; restore both tables on read-cutover-diff > 0.
4. Plan 02-01 — `tools/checks/s23_class_name_lint.py` HARD lefthook forbidding literal `FrontalierService` outside the S12 façade allowlist on new files since W0.
5. Plan 02-02 Task 3 — pick one projector transaction pattern + ADR-docstring it. Recommend `session.begin()` everywhere ; update Plan 02-03 PR-2:214 to match.

---

### 2.2. security-auditor — **MEDIUM**, 5 plan-patches

Reviewing : KMS / DEK envelope, HMAC-pepper, banned-terms JSONB, STRIDE, LSFin, Mobile L1 audit endpoint security.

**STRIDE quick-pass (table — abbreviated)** :

| ID | Category | Component | Severity | Mitigated? |
|---|---|---|---|---|
| T-S01 | Spoofing | `/v1/audit/mobile-session-link` — any client can inject rows | **HIGH** | ✗ |
| T-S05 | Info Disclosure | in-process plaintext DEK cache (process singleton) | **HIGH** | ✗ |
| T-S09 | Elevation | `_select_backend()` silent KMS→Fernet fallback | **HIGH** | ✗ |
| T-S03 | Tampering | fact_current can diverge from fact_event without detection | MED | ⚠ |
| T-S07 | Info Disclosure | HMAC-pepper window (pre-p114 bare-SHA256 rows) | MED | ⚠ |
| T-S11 | Info Disclosure | banned-terms in fact_event JSONB — write-time gap (lint-time only) | MED | ⚠ |
| T-S12 | Info Disclosure | `EncryptedValue.tag` empty string ambiguity | MED | ⚠ |
| T-S08 | DoS | No JSONB payload size cap on `fact_event.value_enc` | LOW | ✗ |
| T-S10 | Elevation | STAGING-DOWN-OVERRIDE label not a required status check | LOW | ⚠ |

**HIGH concerns (load-bearing)** :
1. **T-S09 — KMS silent fallback to Fernet** (`key_vault.py:134-141`). `_select_backend()` catches `KeyVaultServiceError` and silently falls through to `_FernetBackend`. Split-brain key wrapping ; if Fernet key later rotates, those DEKs become permanently irrecoverable. No counter, no alert, no log entry. **Single highest-severity finding in the phase.**
2. **T-S05 — Plaintext DEK cache as process singleton** (`key_vault.py:158-159, 227`). `_dek_cache: dict[str, bytes]` accumulates plaintext DEKs unboundedly. OOM core dump or `/proc/[pid]/mem` exposes every cached DEK. `Sentry.before_send` strips `value_enc` but not the cache object.
3. **T-S01 — Anonymous-session-link spoofing** (`audit_mobile.py`, D-30). « OR anonymous-tagged » branch is unspecified ; any HTTP client can POST audit rows with any `anonymous_session_id`. At link time the server permanently attributes spoofed sessions to real users. LSFin audit-integrity issue.

**MED concerns** :
- HMAC-pepper migration window : PR ordering for code-update vs p114 backfill is unspecified ; risk of silent 0-row audit queries during the window.
- Banned-terms at write time vs lint time : D-32 G5 is lint-time fixture scan only ; runtime coach output containing `« rendement garanti »` lands undetected. Unicode bypass : `garanti<U+200B>` (zero-width space inserted between letters defeats a naive substring regex — sanitiser must NFKC-normalise + strip ZW/format chars before scanning).
- `EncryptedValue.tag = ""` empty string — Pydantic v2 model lies about authentication tag presence ; future engineers extending decrypt path will be misled.

**5 plan-patches** :
1. Plan 02-02 — `KeyVaultService._dek_cache_ttl` 5-min eviction + `mint_dek_cache_size_total` gauge (add to D-33).
2. Plan 02-02 — Replace `key_vault._select_backend()` silent fallback with unconditional `raise` + `mint_kms_backend_failure_total` counter.
3. Plan 02-02 — `audit_mobile.py` link endpoint : require proof-of-session-start (at least one prior row with submitted `anonymous_session_id` and `source='mobile_session_start'`) before accepting batch link POST.
4. Plan 02-02 — `encrypt_value()` calls `check_banned_terms(plaintext_str)` inside before `json.dumps()` when `source_type ∈ {'coach_inference', 'user_input'}`. Raises `BannedTermsError`.
5. Plan 02-04 — `audit-pepper-rotation.md` runbook : freeze audit_event writes during migration ; PR-ordering rule (p114 BEFORE any query-layer code change).

**Security risk verdict** : **MEDIUM**. Three unmitigated HIGH findings prevent LOW. None requires redesigning Phase 02 — all three are surgical fixes. **Plan 02-02 should not execute without patching T-S01 (link spoofing) and T-S09 (KMS fallback) first** ; T-S05 (DEK cache) can ship as a same-plan patch.

---

### 2.3. database-architect (obs #196) — **MEDIUM**, 10 plan-patches

Reviewing : schema design, partitioning, indexes, JSONB cost, FK integrity, migration ordering.

**HIGH/MED concerns** (schema-level, missed by Gemini) :

- **HIGH-1** — **`dek_vault` ON DELETE CASCADE bug** (`services/backend/app/models/dek_vault.py:32-37`). CASCADE evaporates DEK metadata while fact_event rows persist 10y (REVOKE UPDATE/DELETE). **Crypto-shred-as-tombstone broken.** Fix : `ON DELETE RESTRICT` + add `tombstone_at` column.
- **HIGH-2** — **`fact_event` PK ordering wrong** (`RESEARCH.md:457`). `PRIMARY KEY (event_id, subject_id)` forces heap fetch on dominant « all events for subject » query. Fix : `PK (subject_id, event_id)` + secondary `(subject_type, subject_id, recorded_at DESC) INCLUDE (event_id, fact_type)` for index-only scans.
- **HIGH-3** — **`fact_current` covering index omits leading PK column** (`RESEARCH.md:532`). D-01 « 20-50 facts for one user » needs `(subject_id, fact_type) INCLUDE` for index-only scans. obs #174 flagged this ; **iter-1 plan did not apply the fix → RECURRENCE.**
- **MED-1** — UPSERT path 2 roundtrips per event (SELECT-then-UPDATE pattern). Fix : `INSERT ... ON CONFLICT ... DO UPDATE WHERE latest_event_id < EXCLUDED` single roundtrip.
- **MED-2** — HOT update killer : `fillfactor=100` default → bloat on every event UPSERT. Fix : `fillfactor=70` + aggressive autovacuum.
- **MED-3** — JSONB TOAST threshold : `confidence.enrichmentPrompts` can push row >2KB. Fix : cap enrichmentPrompts at 5×200 chars in D-29 contract.
- **MED-4** — Partition count wrong : `MODULUS 1` start requires DETACH/ATTACH for every split. Fix : `MODULUS 8` from day one (pre-launch zero-data window).
- **MED-5** — No FK `fact_current.latest_event_id → fact_event.event_id`. Provenance by-convention only. Fix : `FOREIGN KEY (subject_id, latest_event_id) REFERENCES fact_event(subject_id, event_id) NOT VALID`.
- **MED-6** — **PR-3 atomic trio legally inconsistent**. Backfill interruption mid-run leaves `fact_current` half-populated AND reads cut over. Fix : **split PR-3 → PR-3a (backfill-only, gated row-count-delta=0) + PR-3b (read-cutover + HARD parity-lint flip atomic)**.
- **LOW** × 4 — `event_id VARCHAR(36)` → native UUID ; `TIMESTAMP` → `TIMESTAMPTZ` ; no `dek_vault_history` for rotation audit ; `archetype_tags` JSONB no GIN.

**Strengths confirmed** : UUIDv7 over BIGSERIAL ; PARTITION BY HASH declared day one ; `projection_audit_record` extension preserves 10y retention boundary ; transactional projector (D-19).

---

### 2.4. postgres-pro (obs #197) — **MEDIUM**, 6 plan-patches

Reviewing : alembic lint robustness, testcontainers harness, projector concurrency, PgBouncer compat, pool sizing, parity gate.

**HIGH concerns** :

1. **HIGH-1 — D-20 lint has 5 bypass shapes** (`tools/checks/alembic_boolean_default_lint.py`, Plan 01 Task 2 step 1:281-306). Current spec only catches `sa.text("0")` with `sa.Boolean()`. Bypasses :
   - `server_default="0"` plain string
   - `server_default=sa.literal_column("0")`
   - `sa.text("FALSE"|"TRUE"|"'0'::int")`
   - `sa.BOOLEAN()` uppercase (spec mentions but example only checks `sa.Boolean`)
   - `type_=sa.Boolean()` as kwarg
   - **Self-test fixture path isn't scanned in real runs** (default scope = `alembic/versions/*.py` only).
2. **HIGH-2 — Projector lost-update under Read Committed** (D-19, RESEARCH Pattern 2:376-397). Two concurrent writers for same `(subject_type, subject_id, fact_type)` both run `SELECT ... one_or_none()` → both see `existing.latest_event_id < event.event_id` → both UPDATE. Second silently overwrites by commit order, NOT event_id monotonicity. D-27 UNIQUE protects fact_event but NOT fact_current projection. Drift detector only fires on **dual-read** mismatch, NOT on internal projector race. Fix : **`INSERT ... ON CONFLICT ... DO UPDATE SET ... WHERE fact_current.latest_event_id < EXCLUDED.latest_event_id`** atomic UPSERT.

**MED concerns** :
- PgBouncer compat (transaction-pool kills prepared-statement cache + advisory_lock). Add `prepare_threshold=None` to engine URL guard before Railway flips to PgBouncer.
- Pool sizing : `pool_size=20, max_overflow=20` = 40 vs Railway ~100 cap ; backfill + normal traffic = pool exhaustion. Add `pool_timeout=10` + script-level override.
- D-31 zero-drift gate sample-size : 20 random users + Julien = statistically insufficient for 6777-key ARB × 43-field profile. Fix : 100% of staging users SHA-256 canonical-JSON, persist to `_phase02_parity_audit`, HARD-fail on any mismatch.
- testcontainers pinned `postgres:15.5` w/o Railway-prod-version probe. Add `tools/db/probe_railway_pg_version.sh`.

**LOW** : `CREATE INDEX` non-CONCURRENTLY in p98 (OK pre-launch, bake into template Phase 03+) ; `TRUNCATE CASCADE` on partitioned fact_event ; D-25 canary scalar-only.

---

### 2.5. qa-expert (obs #198) — **MEDIUM**, 8 plan-patches

Reviewing : D-XX Nyquist coverage, parity-lint promotion criteria, offline-buffer race surface.

**HIGH concerns** :

1. **HIGH — D-31 « zero drift » undefined** (Plan 02-03:282-283). « `diff /tmp/proj_new.json /tmp/proj_legacy.json` → empty diff (zero drift) ». **No JSON canonicalisation** (Python dict order vs Postgres JSONB key order → false diffs), **no float tolerance** (`Decimal('200.00')` vs `200.0`), **no NULL-vs-missing rule**, **no decimal-precision policy**. Plan's own resume signal at :292 admits this : « 3 users out of 20 have diff in monthly_gross_income decimal precision ». Sample = 20 random users one-shot. **Promotion to HARD parity-lint with an undefined gate is the « process smell » Gemini flagged at LOW — it's HIGH.**
2. **HIGH — D-25 canary fits one shape only**. `monthly_gross_income` is scalar float. PR-3 cuts ALL fact_types at once but **ZERO pre-cutover parity test** for : decimal-precision facts (`pillar_3a_balance`), nested JSONB (`confidence` 4-axis, `archetype_tags`), nullable optionals, large TOAST-eligible blobs.

**MED concerns** :
- D-30 offline-buffer race surface **empty**. RESEARCH Pitfall 3 (out-of-order event_id) + Pitfall 5 (reinstall orphan chain) + Pitfall 6 (battery drain) all flagged, NONE wired in `<verify>` blocks. **Zero tests for** : 2-device same-user offline→online conflict, client clock skew → UUIDv7 ordering inversion, SQLite buffer full on low-storage iOS, reinstall reconciliation.
- D-32 G3 representative-scenario tautology : `declared_counters_must_fire.py` reads `test_phase02_counters.py` written by same author. Self-fulfilling.
- D-31 soak duration mismatch : REVIEWS « 14-day » vs CONTEXT « 1-week » vs Plan 02-03 « ≥7 days ». Never reconciled.
- Phase 01 SnapshotModel-referencing tests deletion lifecycle untracked. `tests/integration/test_snapshot_cache_invalidation.py` invalidated by PR-5.

**8 plan-patches** :
1. `tools/parity/projection_diff.py` with `json.dumps(..., sort_keys=True, default=str)` canonicalisation + `Decimal` tolerance `1e-9` + missing-key==NULL rule.
2. Multi-shape canary (scalar + nested JSONB + nullable + multi-KB blob) in Plan 02-02 Task 3 BEFORE PR-3.
3. Wire Pitfall-3 + Pitfall-5 tests : `test_projector_out_of_order_event_id.py` + `test_anonymous_session_reinstall_orphan.py`.
4. Continuous drift sampler : Railway cron 30min × 100 users × 7-day soak.
5. `declared_counters_must_fire.py` grep that each counter has ≥1 increment site in `app/` source (not tests).
6. Plan 02-03 PR-5 task : `grep -rln "SnapshotModel" services/backend/tests/` enumerate + decide per-test.
7. D-30 two-device + clock-skew tests.
8. `.github/workflows/pg-soak-nightly.yml` against `$STAGING_DATABASE_URL`.

---

## 3. Consensus Summary (across all 7 reviewers — pre-iter-2 + Claude-Opus post-iter-2)

### Risk verdict consensus

| Reviewer | Verdict | Stage |
|---|---|---|
| Gemini 2.5 Pro | LOW | iter-1 (pre-revision) |
| architect-review | **MEDIUM** | iter-1b (pre-revision) |
| security-auditor | **MEDIUM** | iter-1b (pre-revision) |
| database-architect | **MEDIUM** | iter-1b (pre-revision) |
| postgres-pro | **MEDIUM** | iter-1b (pre-revision) |
| qa-expert | **MEDIUM** | iter-1b (pre-revision) |
| Claude Opus 4.7 (`claude -p`) | **MEDIUM, close to LOW** | iter-2 (post-revision, commit `35eb5eee` baseline) |

**6 of 7 → MEDIUM. Phase risk verdict for execution purposes : MEDIUM.** Claude-Opus iter-2 review additionally confirms 41/44 absorption (93.2%) and surfaces 3 NEW HIGH + 1 universal-miss not in prior reviews — see Section 7.

### Convergent findings (≥ 2 reviewers)

1. **PR-3 atomic trio is unsafe as currently choreographed** (architect-review MED + database-architect MED-6 + postgres-pro MED-5 + qa-expert HIGH × 2) — 4-way convergence. Backfill is operationally separable from cutover ; PR-3 must split into PR-3a (backfill-only, idempotent, gated row-count-delta=0) and PR-3b (read-cutover + HARD parity-lint flip atomic).
2. **« Zero drift » gate is undefined** (postgres-pro MED-5 + qa-expert HIGH-1) — no canonicalisation, no tolerance, sample size statistically insufficient. Must define `projection_diff.py` with explicit canonicalisation + tolerance + 100% staging users before HARD flip.
3. **D-25 canary insufficient** (postgres-pro LOW-iii + qa-expert HIGH-2) — single scalar shape doesn't cover decimal / JSONB / nullable / TOAST. Multi-shape canary required pre-PR-3.
4. **fact_current covering index missing leading column** (database-architect HIGH-3, RECURRENCE of obs #174 which planner did not apply) — single reviewer but high-confidence because it's the second time it's flagged.
5. **Projector concurrency race** (database-architect MED-1 + postgres-pro HIGH-2) — UPSERT pattern needed at DB layer ; current SELECT-then-UPDATE has lost-update under Read Committed.

### Findings count

- **8 HIGH** : 3 security (KMS fallback, DEK cache, link spoofing), 3 schema (dek_vault CASCADE, fact_event PK, fact_current covering index), 2 Postgres (lint bypass, projector race), 2 QA (zero-drift undefined, canary single-shape)
- **12 MEDIUM** : split across all 5 specialists ; convergent on PR-3 split, drift gate definition, HMAC pepper window, banned-terms write-time
- **9 LOW** : transaction-pattern inconsistency, over-decomposition, audit closure narrower than claimed, etc.

### Divergent views

- Gemini said `testcontainers Docker dep friction = LOW concern (operational)` ; postgres-pro flagged the **same harness as MED concern (version-pin drift)**. Different angle, both right.
- Gemini called VALIDATION.md « exemplary ». qa-expert disagreed : breadth-over-depth — 33/33 mapping is real but 3 verify-commands hide non-determinism.

---

## 4. Actionable Plan-Patch Candidates (planner consumption — `/gsd-plan-phase 02 --reviews`)

The planner must address these in iter-2 plan revision. Tiered by execution-blocking status :

### Tier A — BLOCKING for /gsd-execute-phase (HIGH-severity, must patch before W0)

| # | Patch | Reviewer | Where |
|---|---|---|---|
| A1 | `dek_vault.py` : `ON DELETE CASCADE` → `ON DELETE RESTRICT` + add `tombstone_at` column | database-architect HIGH-1 | `services/backend/app/models/dek_vault.py:32-37` |
| A2 | `fact_event` PK : `(event_id, subject_id)` → `(subject_id, event_id)` | database-architect HIGH-2 | RESEARCH.md:457 + Plan 02-02 DDL |
| A3 | `fact_current` covering index : add leading column `(subject_id, fact_type) INCLUDE (latest_event_id, value_enc)` | database-architect HIGH-3 | RESEARCH.md:532 + Plan 02-02 DDL |
| A4 | `key_vault._select_backend()` : remove silent KMS→Fernet fallback, raise + counter | security-auditor T-S09 | `services/backend/app/services/key_vault.py:134-141` |
| A5 | `KeyVaultService._dek_cache` : add 5-min TTL eviction + size gauge | security-auditor T-S05 | `key_vault.py:158-159, 227` |
| A6 | `/v1/audit/mobile-session-link` : require proof-of-session-start handshake | security-auditor T-S01 | Plan 02-02 D-30 audit_mobile.py |
| A7 | D-20 lint : expand to 5 bypass shapes + scan fixture in self-test | postgres-pro HIGH-1 | `tools/checks/alembic_boolean_default_lint.py` + Plan 01 Task 2 |
| A8 | Projector : SELECT-then-UPDATE → `INSERT ... ON CONFLICT ... DO UPDATE WHERE latest_event_id < EXCLUDED` | postgres-pro HIGH-2 + database-architect MED-1 | RESEARCH Pattern 2:376-397 + Plan 02-02 Task 3 |
| A9 | PR-3 split : PR-3a (backfill-only, idempotent, row-count-delta=0 gate) + PR-3b (read-cutover + HARD-flip atomic) | architect-review MED + database-architect MED-6 + qa-expert HIGH-1 | Plan 02-03 |
| A10 | `tools/parity/projection_diff.py` : define drift deterministically (canonical JSON + Decimal tolerance + NULL-vs-missing) | qa-expert HIGH-1 + postgres-pro MED-5 | new tool + Plan 02-03 PR-3 verify block |
| A11 | Multi-shape canary (scalar + JSONB + nullable + TOAST blob) before PR-3 ships | qa-expert HIGH-2 + postgres-pro LOW-iii | Plan 02-02 Task 3 |

### Tier B — STRONGLY RECOMMENDED (MEDIUM-severity, patch in W0 if possible, else W1)

| # | Patch | Reviewer |
|---|---|---|
| B1 | Pre-flight zero-user prod gate `SELECT COUNT(*) FROM users` at head of Plan 02-03 | Gemini |
| B2 | `no_mobile_fact_current_regulatory_read.py` HARD lefthook on Dart | architect-review |
| B3 | Plan 02-03 — D-12 label rename : `Phase-01 D-12` (parity-lint) vs `D-MOB-03` (Mobile L1 audit) | architect-review |
| B4 | `s23_class_name_lint.py` HARD lefthook forbidding `FrontalierService` on new backend files since W0 | architect-review |
| B5 | Plan 02-03 Task 2 — 7th gate : pre-HARD-flip pg_dump snapshot + restore-on-diff path | architect-review |
| B6 | `encrypt_value()` : call `check_banned_terms(plaintext)` inside before `json.dumps()` for coach_inference/user_input | security-auditor |
| B7 | `audit-pepper-rotation.md` runbook : explicit PR ordering rule (p114 BEFORE query-layer code change) | security-auditor |
| B8 | `MODULUS 1` → `MODULUS 8` for fact_event partitioning from day one | database-architect MED-4 |
| B9 | Add FK `fact_current.latest_event_id → fact_event.event_id NOT VALID` | database-architect MED-5 |
| B10 | `fillfactor=70` on fact_current + aggressive autovacuum | database-architect MED-2 |
| B11 | Cap `confidence.enrichmentPrompts` at 5×200 chars in D-29 contract | database-architect MED-3 |
| B12 | Engine URL : add `prepare_threshold=None` guard before Railway PgBouncer flip | postgres-pro MED |
| B13 | `tools/db/probe_railway_pg_version.sh` + dynamic testcontainers PG pin | postgres-pro MED |
| B14 | 100% staging users SHA-256 canonical-JSON parity audit, persist to `_phase02_parity_audit` | postgres-pro MED-5 |
| B15 | Pool sizing : `pool_timeout=10` + backfill script `pool_size=2, max_overflow=0` override | postgres-pro MED |
| B16 | `declared_counters_must_fire.py` : grep each counter has ≥1 increment site in `app/` source (not tests) | qa-expert |
| B17 | D-30 two-device + clock-skew + reinstall + low-storage tests | qa-expert |
| B18 | Continuous drift sampler : Railway cron 30min × 100 users × 7-day soak | qa-expert |
| B19 | Plan 02-03 PR-5 : enumerate Phase 01 SnapshotModel-referencing tests + decide per-test | qa-expert |
| B20 | Reconcile D-31 soak duration (CONTEXT « 1-week » vs Plan « ≥7 days » vs REVIEWS « 14-day ») | qa-expert |

### Tier C — OPTIONAL polish (LOW-severity, defer post-execution if time-boxed)

| # | Patch | Reviewer |
|---|---|---|
| C1 | Document Docker dep in `services/backend/README.md` | Gemini |
| C2 | PR-3 commit-message contract citing allowlist rationale | Gemini |
| C3 | Pick one projector transaction pattern + docstring it | architect-review |
| C4 | Merge over-decomposed D-XX (33 → ~26) | architect-review |
| C5 | `EncryptedValue.tag` field : split tag from ct OR enforce `Literal[""]` + docstring | security-auditor |
| C6 | `event_id VARCHAR(36)` → native UUID + `TIMESTAMP` → `TIMESTAMPTZ` | database-architect |
| C7 | JSONB payload size cap on `fact_event.value_enc` (CHECK `pg_column_size < 65536`) | security-auditor |
| C8 | STAGING-DOWN-OVERRIDE workflow as required status check | security-auditor |

---

## 5. Iter-2 Plan (when Codex review lands)

When Codex usage resets (≥ 13:36 local 2026-05-18) :

1. Re-run via preserved prompt :
   ```bash
   cat /tmp/gsd-review-prompt-02.md | codex exec --skip-git-repo-check --sandbox read-only - > /tmp/gsd-review-codex-02.md 2> /tmp/gsd-review-codex-02.err
   ```
2. Append Codex section below + refresh Consensus Summary if Codex surfaces new findings.
3. If Codex echoes any Tier-A patch → confirms BLOCKING status (already at maximal).
4. If Codex surfaces an 8+ HIGH that none of the 5 specialists caught → escalate Phase 02 to **HIGH** overall.

---

## 6. 0-trust §9.6 Evidence + Caveat

**Evidence** :
- Gemini review raw output : `/tmp/gsd-review-gemini-02.md` (32 lines, full 5-section structure, exit code 0)
- Panel obs in engram (live db `~/.engram/engram.db`) :
  - obs #195 architect-review (full content via `mem_get_observation 195`)
  - obs #196 database-architect (full content via `mem_get_observation 196`)
  - obs #197 postgres-pro (full content via `mem_get_observation 197`)
  - obs #198 qa-expert (full content via `mem_get_observation 198`)
  - security-auditor : full content inline above (engram save side-channel)
- Prompt fed (Gemini) : `/tmp/gsd-review-prompt-02.md` (4241 lines / 418 KB)
- Panel agents read live files at MINT.nosync working tree (commit `15d8d6a3` baseline)
- Codex blocker : `/tmp/gsd-review-codex-02.err` ends with `ERROR: You've hit your usage limit. To get more access now, send a request to your admin or try again at 1:36 PM.`

**Caveat** :
- 6 of 7 requested reviewers delivered (5 panel + Gemini ; Codex pending). Independent-AI consensus pass is INCOMPLETE pending Codex re-run, but the 5-of-5 panel agreement on MEDIUM risk is strong enough to gate `/gsd-execute-phase` on Tier-A patches landing first.
- The 3 security HIGH findings are vendor-single (security-auditor agent only) but high-confidence because they cite specific file:line in existing code (`key_vault.py:134-141`, `key_vault.py:158-159`) that any reader can verify.
- Convergent findings (PR-3 split, zero-drift gate, projector race) are 2-4-way and constitute the highest-confidence patch set.
- All 5 panel agents persisted findings to engram with `prior_finding_refs` to obs #163-#193 — the panel built on Phase 01 close + Phase 02 brainstorm + ADR + hotfix lineage rather than rediscovering them.
- Post-iter-2 Claude-Opus review (Section 7) ran via `claude -p` on commit `35eb5eee` baseline — same-model-family independence (caveat noted) but value-add via absorption audit + 3 new HIGH findings + 1 universal-miss. Raw output: `/tmp/gsd-review-claude-02.md` (279 lines, exit 0).

---

## 7. Post-Iter-2 Review — Claude Opus 4.7 (`claude -p` fresh session, commit `35eb5eee` baseline)

> **Independence caveat** : same model family as orchestrator. Fresh session via `claude -p --model opus`. Value-add comes from iter-2 absorption audit + finding what BOTH Gemini AND the 5-panel missed, not from cross-vendor diversity.

### 7.1. Independent verdict (fresh-eyes, adversarial)

**Risk: MEDIUM, leaning close to LOW post-iter-2 absorption.**

Iter-2 is « substantially stronger than iter-1 ». The 6-PR migration (A9), deterministic drift gate (A10), DEK fail-closed (A4/D-35), multi-shape canary (A11/D-34) all close the load-bearing HIGH findings from iter-1b. Reuse discipline rated « Karpathy #2 done right » — `encrypt_value` wraps existing `envelope.py` ; p98 alembic copies p111 REVOKE verbatim. Plan growth +1808 lines / +85% is structural patching, not narrative bloat.

**Why not LOW** : 3 residual HIGH + 7 MEDIUM concerns iter-2 absorption did not fully resolve. These don't break the migration choreography but create « false-confidence surfaces ». For a phase touching canonical user-facts + crypto envelope + audit chain, the bar is « no surprises ».

### 7.2. Iter-2 absorption audit

| Tier | Score | Status |
|---|---|---|
| Tier A (11 blockers) | **11/11 (100%)** | APPLIED at file:line with landing site identified per patch |
| Tier B (20 recommended) | **20/20 (100%)** | APPLIED |
| Tier C (8 polish) | **5/8 (62.5%) APPLIED** + 3/8 DEFERRED with documented rationale (C4 D-XX merge, C6 native UUID/TIMESTAMPTZ, C7 JSONB CHECK) |
| Convergent findings (5) | **5/5 (100%)** | All applied — PR-3 split (A9), zero-drift gate (A10), multi-shape canary (A11), covering index (A3), projector UPSERT (A8) |

**Overall absorption score: 41/44 (93.2%) APPLIED + 3 explicitly DEFERRED with technical justification.** Verdict: « exemplary iter-2 plan revision discipline ».

### 7.3. 3 NEW HIGH concerns iter-2 absorption did not fully resolve

**HIGH-A1 — Projector atomic UPSERT SQLite-path divergence (false-green trap)**
Plan 02-02 Task 3B uses Postgres `INSERT ... ON CONFLICT ... DO UPDATE WHERE` (correct). SQLite test path falls back to SELECT-then-UPDATE under SAVEPOINT (the iter-1 vulnerable pattern). The 100-iteration race test uses `pg_session` — only exercises Postgres. **Developers running `pytest -q -k "not pg"` locally see ALL projector tests pass on the SQLite path, even though that path will not ship.** A regression dropping `WHERE latest_event_id < EXCLUDED.latest_event_id` only surfaces at CI `pg-integration` stage. Creates « tests green ≠ feature working » risk per CLAUDE.md §9.
**Fix:** add `pytest.mark.requires_pg` marker to projector tests ; CI must run pg-integration on EVERY PR touching `app/services/projector/` (not just alembic migrations).

**HIGH-A2 — Handshake replay ordering not integration-tested**
A6 mandates `/v1/audit/mobile-session-link` reject batches where any `anonymous_session_id` lacks a prior `mobile_session_start`. The Flutter test covers the simple case (« first-ever-replay »). **No integration test asserts end-to-end ordering across mobile + backend** — e.g., user offline 3 days with 5 session-starts + 5 warm-resumes + login event interleaved. Backend must accept all 11 events without 403 errors when the buffer replays.
**Fix:** add `tests/integration/test_audit_mobile_link_handshake_replay_ordering.py` POSTing an interleaved batch + asserting 200 for all sids.

**HIGH-A3 — Secret handoff hygiene in Plan 02-02 Task 1**
Plan 02-02 Task 1 generates pepper locally via `secrets.token_urlsafe(48)`, writes to `/tmp/mint_audit_pepper_for_julien.txt`, Julien copies to Railway dashboard, then `rm`. Risks:
- macOS `/tmp` = `/private/tmp` (disk-backed) → recoverable via filesystem tools post-rm
- Julien terminal scrollback captures pepper on `cat`
- Pepper sits in Claude tool output → conversation context → `~/.claude/projects/.../*.jsonl` session logs

**Fix:** Replace `/tmp` flow with Railway CLI one-liner :
```bash
railway variables set MINT_AUDIT_HASH_PEPPER --environment production \
  --value "$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
```
Pepper generated → set → never persisted to disk or stdout. Update Plan 02-02 Task 1 step 1 + step 6.

### 7.4. 7 NEW MEDIUM concerns

- **MEDIUM-A4** — D-04 constants-PIT verify fuzzy. « no retroactive flag » observed via what? Need explicit assertion: `SELECT constants_version_hash FROM fact_event WHERE event_id=$T1_event` returns `H1` after bumping active to `H2`.
- **MEDIUM-A5** — Statistical sample weakness at "100% staging users". Pre-launch staging has ~5 test accounts → 100% × 5 = 5 audits. Cannot statistically validate 8-archetype population MINT will see post-launch. Need `tools/db/seed_staging_archetype_distribution.py` seeding ≥1000 synthetic users.
- **MEDIUM-A6** — Clock-skew silent drop in B17 test. `mint_projector_idempotency_skip_total` doesn't distinguish replay vs clock-skew vs monotonicity violation. LSFin auditor sees gap in user's L1 audit chain with no observability signal. Add `reason` label.
- **MEDIUM-A7** — B7 pepper rotation runbook tx-too-large risk. Single `UPDATE audit_events SET user_id_hash_v2 = ...` on 10y-retained table → WAL bloat + replica lag + autovacuum delays. Need batched updates (1000 rows/tx) + pepper-immutability check.
- **MEDIUM-A8** — Self-test bootstrapping fragility in `hmac_pepper_audit.py`. Self-exempts `services/backend/app/services/audit/hmac_pepper.py` (file created in Plan 02-02). Plan 02-01 needs TODO stub + sentinel comment + stability regression test.
- **MEDIUM-A9** — B4 s23 lint is regex, not AST. `r"\bclass\s+FrontalierService\b"` bypassable via `_cls_name = "FrontalierService"; class_for_name(_cls_name, ...)`. Rewrite as `ast.parse` + walk for `ast.ClassDef.name == "FrontalierService"`.
- **MEDIUM-A10** — Continuous drift sampler (B18) overload risk. 33,600 audit rows + 67,200 read requests / 7 days on staging concurrent with Maestro sim + Julien testing → false drift positives from cache pressure. Add rate-limit + degradation-aware skip + weekly vacuum.

### 7.5. 5 LOW polish

- **LOW-A11** — VERIFICATION-REPORT.html `grep -c "G1 Maestro\|G2 Julien..."` ≥ 5 gameable ; assert per-gate evidence.
- **LOW-A12** — Sentry quota budget for Phase 02 unspecified. Add per-counter quota table to Plan 02-04 SUMMARY.
- **LOW-A13** — PR-5 reverse-projector pseudocode « outline only ». Ship 40-LOC Python skeleton.
- **LOW-A14** — Iter-2 commits 4-part on Plan 02-03 but task mapping implicit. Add commit-to-task table per iter-2_revision block.
- **LOW-A15** — Pepper-missing migration deploy-time fail-closed correct but undocumented in `audit-pepper-rotation.md`. Add prerequisite checklist.

### 7.6. THE finding ALL prior reviewers missed

**Session-start audit-pollution attack (NEW universal miss)**

Per Plan 02-02 Task 3 step 7: `Depends(get_current_user_optional)` on `/v1/audit/mobile-session-start` accepts anonymous payload. With A6 handshake mitigation, link-spoofing IS closed — but **session-start spoofing is wide open**.

Any HTTP client can POST a fake `anonymous_session_id` with any `app_version` claim ; server INSERTs without validation. The UNIQUE constraint on `(anonymous_session_id, observed_at)` blocks only exact duplicates — adversary just varies `observed_at`. Result : **audit trail polluted with synthetic rows** that look legitimate (correct shape, server timestamps).

**Fix:** Rate-limit `/v1/audit/mobile-session-start` per source IP + add lightweight proof-of-mobile (signed Apple App Attestation token from `DeviceCheck` / Android Play Integrity for production builds). **Defer to Plan 02-04 close-out as forward-looking item OR Phase 04 hardening.**

### 7.7. 5-panel findings Claude-Opus DISAGREES with (downgrade severity)

- postgres-pro MED « testcontainers Docker overhead » → actually LOW (30-60s per pg-integration job is acceptable amortized).
- qa-expert MED « D-32 G3 representative-scenario tautology » → mitigated by B16 grep-in-app/ check ; severity overstated.
- database-architect MED-2 « fillfactor=70 HOT update killer » → actually LOW (pre-launch zero data = theoretical issue).

### 7.8. Claude-Opus recommendation for `/gsd-execute-phase` readiness

**Execution-ready conditioned on 4 acceptance items:**

1. **3 residual HIGHs (HIGH-A1, HIGH-A2, HIGH-A3)** ACCEPTED as known limitations + documented in Plan 02-02 SUMMARY before PR-1 opens, OR shipped in iter-3 micro-revision (estimated 2-4h Claude work).
2. Julien gates each `checkpoint:human-verify` per 0-trust §9 (no exception).
3. **4 MEDIUMs (A4, A5, A6, A7)** tracked as backlog items for iter-3 OR fix-up commits during execution.
4. **Session-start audit-pollution finding** surfaced in Plan 02-04 SUMMARY as deferred Phase 04 hardening item.

If iter-3 micro-revision is in budget (2-4h) : recommended. Otherwise proceed with documented residual risk.

### 7.9. New Tier-A (iter-3) candidates (if iter-3 micro-revision authorised)

| # | Patch | Source | Effort |
|---|---|---|---|
| iA1 | `pytest.mark.requires_pg` on projector tests + CI workflow update | Claude-Opus HIGH-A1 | 30 min |
| iA2 | `tests/integration/test_audit_mobile_link_handshake_replay_ordering.py` + interleaved-batch case | Claude-Opus HIGH-A2 | 1-2 h |
| iA3 | Replace `/tmp` pepper file with `railway variables set` one-liner in Plan 02-02 Task 1 step 1 + step 6 | Claude-Opus HIGH-A3 | 15 min |
| iA4 | (Optional, deferable) Plan 02-04 SUMMARY entry: session-start audit-pollution → Phase 04 hardening (App Attestation + IP rate-limit) | Claude-Opus universal-miss | 30 min |

Total iter-3 effort if all 4 ship: ~3-4 hours Claude work. None require CONTEXT.md changes.
