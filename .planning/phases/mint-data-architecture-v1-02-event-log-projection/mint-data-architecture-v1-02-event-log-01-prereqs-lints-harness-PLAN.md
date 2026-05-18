---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - services/backend/pyproject.toml
  - services/backend/tests/conftest.py
  - services/backend/tests/fixtures/pg_fixture.py
  - services/backend/tests/fixtures/test_pg_fixture_self.py
  - services/backend/tests/fixtures/alembic_bad.py
  - services/backend/tests/fixtures/bad_audit_writer.py
  - services/backend/tests/test_s12_composition.py
  - services/backend/tests/test_s12_frontalier_rename.py
  - services/backend/tests/integration/test_coup_04_dead_path.py
  - services/backend/app/services/independant_service.py
  - services/backend/app/services/independants/__init__.py
  - services/backend/app/services/independants/indemnity_rates.py
  - services/backend/app/services/expat/frontalier_service.py
  - services/backend/app/services/expat/frontalier_segment_service.py
  - services/backend/app/services/expat/__init__.py
  - services/backend/app/services/frontalier_service.py
  - services/backend/app/api/v1/endpoints/expat.py
  - services/backend/app/api/v1/endpoints/segments.py
  - services/backend/tests/test_expat.py
  - services/backend/tests/test_segments.py
  - apps/mobile/lib/services/coach_narrative_service.dart
  - apps/mobile/test/services/coach_narrative_profile_context_test.dart
  - tools/checks/alembic_boolean_default_lint.py
  - tools/checks/hmac_pepper_audit.py
  - tools/checks/tests/test_alembic_boolean_default_lint.py
  - tools/checks/tests/test_hmac_pepper_audit.py
  - tools/codegen/regulatory_constants_to_dart.py
  - apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart
  - tools/db/baseline_snapshot_2026-05-18.sql
  - tools/db/regenerate_baseline.sh
  - lefthook.yml
  - .github/workflows/backend-ci.yml
autonomous: true
decisions: [D-08, D-09, D-10, D-11, D-18, D-20, D-21, D-22, D-23, D-24]
requirements_addressed:
  - CONTEXT.md#D-08 S12 composition pattern (façade-delegate to S18)
  - CONTEXT.md#D-09 S12 PR-1 in W0 (façade + rename + IJM/LAA promote)
  - CONTEXT.md#D-10 D-MOB-01 Flutter drift PR-A2 (15 missing fields)
  - CONTEXT.md#D-11 D-MOB-02 dead-COUP-04 contract lock
  - CONTEXT.md#D-18 Phase 02 sequential 4-plan structure (this plan = W0)
  - CONTEXT.md#D-20 alembic_boolean_default_lint HARD lefthook
  - CONTEXT.md#D-21 Codegen timestamp determinism
  - CONTEXT.md#D-22 Real-Postgres pg_fixture harness (testcontainers)
  - CONTEXT.md#D-23 pg_dump baseline snapshot committed
  - CONTEXT.md#D-24 HMAC-pepper site sweep + audit lint
threat_model_summary:
  - T-02-08 Lint bypass via tag-typed migration (mitigated: alembic_boolean_default_lint scans both `sa.Boolean()` and `sa.BOOLEAN()`)
  - T-02-09 testcontainers Docker dependency missing on CI runner (mitigated: GH Actions ubuntu-latest ships Docker; explicit job-level verify step)
  - T-02-10 Self-test fixture exposes pepper logic (mitigated: TESTING=1 pepper-bypass branch tested explicitly, refuses prod without env)
must_haves:
  truths:
    - "Lefthook pre-commit rejects any alembic migration adding `sa.Boolean(...)` with `server_default=sa.text(...)` argument (D-20 HARD)."
    - "Lefthook pre-commit rejects any backend code calling `hashlib.sha256(user_id|actor_email|ip_address|user_agent)` without routing through `app/services/audit/hmac_pepper.py` (D-24 HARD)."
    - "`pytest tests/fixtures/test_pg_fixture_self.py` spins a Postgres 15 testcontainer, runs `alembic upgrade head` against it, then `alembic downgrade base`, and exits 0 within 60s (D-22)."
    - "`tools/db/regenerate_baseline.sh` reproducibly emits `tools/db/baseline_snapshot_2026-05-18.sql`; running twice yields `git diff --exit-code` exit 0 (D-23)."
    - "`tools/codegen/regulatory_constants_to_dart.py` emits a deterministic header `Generated for effective_on: <date>` (no `utcnow`); regenerating without RegulatoryParameter change yields identical file (D-21)."
    - "S12 `IndependantService.analyze()` continues to expose the same public signature, with calculator primitives delegated to `app/services/independants/` (D-08)."
    - "`IJM_ESTIMATE_RATE = 0.02` + `LAA_ESTIMATE_RATE = 0.015` removed from `services/backend/app/services/independant_service.py:60-64` and live in `services/backend/app/services/independants/indemnity_rates.py` (D-08)."
    - "`FrontalierService` renamed to `FrontalierSegmentService` in `app/services/expat/`; old symbol re-exported as deprecated alias `FrontalierService = FrontalierSegmentService` (alias removal deferred to Plan 02-04 per D-09)."
    - "Flutter `coach_narrative_service.dart::_buildProfileContext` emits the 15 fields previously missing relative to backend `_PROFILE_SAFE_FIELDS` (D-10 PR-A2). `python3 tools/checks/profile_safe_fields_parity.py` still in SOFT mode but drift count reduced; HARD mode flip deferred to Plan 02-03 PR-3 per D-31."
    - "`tests/integration/test_coup_04_dead_path.py` exercises the dead-COUP-04 path end-to-end and asserts the contract is closed (D-11)."
  artifacts:
    - path: "services/backend/tests/fixtures/pg_fixture.py"
      provides: "Module-scoped Postgres 15.5 fixture via testcontainers; runs alembic upgrade head"
      contains: "PostgresContainer"
    - path: "tools/checks/alembic_boolean_default_lint.py"
      provides: "HARD lint: refuses sa.Boolean+sa.text server_default combos"
      exports: ["main", "scan_file"]
    - path: "tools/checks/hmac_pepper_audit.py"
      provides: "HARD lint: refuses bare hashlib.sha256 on audit-PII columns"
      exports: ["main", "scan_file"]
    - path: "services/backend/app/services/independants/indemnity_rates.py"
      provides: "S18 single source of truth for IJM/LAA estimate rates"
      contains: "IJM_ESTIMATE_RATE"
    - path: "services/backend/app/services/expat/frontalier_segment_service.py"
      provides: "Renamed FrontalierService class"
      contains: "class FrontalierSegmentService"
    - path: "tools/db/baseline_snapshot_2026-05-18.sql"
      provides: "pg_dump baseline reference (head=p112_audit_event_user_hash)"
      min_lines: 50
    - path: "apps/mobile/test/services/coach_narrative_profile_context_test.dart"
      provides: "Asserts 15 missing fields emitted by _buildProfileContext"
      min_lines: 40
  key_links:
    - from: "lefthook.yml"
      to: "tools/checks/alembic_boolean_default_lint.py"
      via: "pre-commit command on glob services/backend/alembic/versions/*.py"
      pattern: "alembic_boolean_default_lint"
    - from: "lefthook.yml"
      to: "tools/checks/hmac_pepper_audit.py"
      via: "pre-commit command on glob services/backend/**/*.py"
      pattern: "hmac_pepper_audit"
    - from: "services/backend/app/services/independant_service.py"
      to: "services/backend/app/services/independants/indemnity_rates.py"
      via: "from .independants.indemnity_rates import IJM_ESTIMATE_RATE, LAA_ESTIMATE_RATE"
      pattern: "from .independants.indemnity_rates"
    - from: ".github/workflows/backend-ci.yml"
      to: "services/backend/tests/fixtures/pg_fixture.py"
      via: "CI job runs pytest -k pg with testcontainers"
      pattern: "testcontainers"
---

<objective>
Wave 0 prereqs bundle for Phase 02. Establishes every primitive Plans 02-02 / 02-03 / 02-04 depend on: testcontainers Postgres harness (D-22), two new HARD lefthook lints (D-20, D-24), pg_dump baseline (D-23), codegen-timestamp-determinism fix (D-21), S12 façade-delegate refactor with IJM/LAA promotion to S18 + frontalier rename (D-08/D-09 PR-1 half), Flutter drift PR-A2 closing the 15-field gap in `_buildProfileContext` (D-10), and the dead-COUP-04 integration test contract lock (D-11).

Purpose: every downstream Phase 02 plan inherits a Postgres-real test harness, lint protection against the Hotfix B / Hotfix C regression classes, and a clean S12 service boundary so W1 writer code (`fact_event` INSERT call sites) doesn't slip the indemnity-rate duplication or the frontalier rename mid-migration.

Output: 1 bundled PR (multi-commit chain, 11 atomic commits per RESEARCH § Migration sequencing W0) landing on `dev`. No production behavior change.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VALIDATION.md
@.planning/decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md
@services/backend/alembic/versions/p111_projection_audit.py
@services/backend/alembic/versions/p112_audit_event_user_hash.py
@services/backend/app/services/independant_service.py
@services/backend/app/services/expat/frontalier_service.py
@services/backend/app/services/frontalier_service.py
@apps/mobile/lib/services/coach_narrative_service.dart
@services/backend/app/api/v1/endpoints/coach_chat.py
@tools/checks/profile_safe_fields_parity.py
@lefthook.yml

<interfaces>
<!-- Key contracts the executor needs verbatim — extracted from in-tree. -->
<!-- DO NOT re-explore; use these directly. -->

From `services/backend/app/services/independant_service.py:55-70` (current source of indemnity constants — MUST be relocated):
```python
# Public estimate rates — Phase 02 D-08 moves these to app/services/independants/indemnity_rates.py
IJM_ESTIMATE_RATE = 0.02  # 2% as middle estimate
LAA_ESTIMATE_RATE = 0.015  # 1.5% estimate

def estimate_ijm(self, revenu_net: float) -> float:
    return round(revenu_net * IJM_ESTIMATE_RATE, 2)
def estimate_laa(self, revenu_net: float) -> float:
    return round(revenu_net * LAA_ESTIMATE_RATE, 2)
```

From `services/backend/app/services/expat/frontalier_service.py:378` (rename target — D-09):
```python
class FrontalierService:  # → rename class def to FrontalierSegmentService
    # ... 700+ LOC of segment logic
```
Callers: `services/backend/app/api/v1/endpoints/expat.py:54-55`, `app/services/expat/__init__.py:27`, `tests/test_expat.py:19`.

From `services/backend/app/services/frontalier_service.py:291` (S12 façade — DO NOT touch the class; it stays a façade per D-08):
```python
class FrontalierService:  # different class — S12 segments façade
    # ... delegates to expat/.frontalier_segment_service (will be the rename target)
```
NB: this S12 façade and the S23 segment class share a name; the rename targets ONLY `app/services/expat/frontalier_service.py`. The S12 façade in `app/services/frontalier_service.py` keeps its name + imports the renamed S23 class.

From `services/backend/app/api/v1/endpoints/coach_chat.py:957-1015` (`_PROFILE_SAFE_FIELDS` Stage-0 baseline — parity source for D-10):
```python
_PROFILE_SAFE_FIELDS = {  # 43 keys post-Phase 01 W4 Plan 19
    # ... 43 server-canonical field names
}
```
Flutter target: `apps/mobile/lib/services/coach_narrative_service.dart:1161-1208` `_buildProfileContext`.

From `services/backend/alembic/versions/p111_projection_audit.py:65-72` (REVOKE template — re-used in Plan 02-02):
```python
if bind.dialect.name == "postgresql":
    op.execute("REVOKE UPDATE, DELETE ON projection_audit_records FROM PUBLIC")
    op.execute("""DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_role')
                  THEN REVOKE UPDATE, DELETE ON projection_audit_records FROM app_role; END IF; END $$;""")
```

From `services/backend/alembic/versions/p111_projection_audit.py:55` (BOOLEAN DEFAULT correct pattern — `sa.false()` not `sa.text("0")`):
```python
sa.Column("lsfin_disclaimer_shown", sa.Boolean(), nullable=False, server_default=sa.false())
```

From `lefthook.yml:31-60` (existing pre-commit structure — extend with two new commands `alembic-boolean-default-lint` + `hmac-pepper-audit`):
```yaml
pre-commit:
  parallel: false
  commands:
    memory-retention-gate: ...
    wiki-lint:
      run: python3 tools/checks/wiki_lint.py
      glob: ".planning/**/*.md"
    banned-terms-arb-gate: ...
    # New commands inserted here, same shape (run / glob / tags / fail_text).
```

Alembic head (verified via `python3 -c "import alembic..."`): `p112_audit_event_user_hash`. Phase 02 migrations chain off this head.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Install testcontainers + uuid_utils, build pg_fixture harness, commit pg_dump baseline + regen script</name>
  <files>
    services/backend/pyproject.toml,
    services/backend/tests/conftest.py,
    services/backend/tests/fixtures/__init__.py,
    services/backend/tests/fixtures/pg_fixture.py,
    services/backend/tests/fixtures/test_pg_fixture_self.py,
    tools/db/baseline_snapshot_2026-05-18.sql,
    tools/db/regenerate_baseline.sh
  </files>
  <read_first>
    services/backend/pyproject.toml (current deps),
    services/backend/tests/conftest.py (existing fixture patterns),
    services/backend/alembic/versions/p111_projection_audit.py (REVOKE pattern reference for fixture self-test),
    services/backend/alembic.ini (sqlalchemy.url config injection),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md (Example 3 pg_fixture code at lines 812-855)
  </read_first>
  <action>
1. **pyproject.toml**: under `[project.optional-dependencies] test` add `"testcontainers[postgres]>=4.7,<5"` and `"uuid_utils>=0.9,<1.0"`. Before locking versions, run `pip index versions testcontainers` and `pip index versions uuid_utils` to confirm `>=4.7` and `>=0.9` are still latest stable; pin to the latest stable minor if newer. Run `pip install -e ".[test]"` from `services/backend/` to install.
2. **services/backend/tests/fixtures/pg_fixture.py** (NEW): create module-scoped fixture per RESEARCH Example 3. Import `PostgresContainer` from `testcontainers.postgres`, image `postgres:15.5`. Inside the `with PostgresContainer(...) as pg` block, call `pg.get_connection_url()`, build a SQLAlchemy engine, programmatically build an alembic `Config` pointing at `services/backend/alembic.ini` with `sqlalchemy.url` overridden to the container URL, then `command.upgrade(alembic_cfg, "head")`. `yield engine`. Add a `pg_session` function-scoped fixture that opens a Session, yields, then `TRUNCATE TABLE projection_audit_records, audit_events, dek_vault, snapshots RESTART IDENTITY CASCADE` between tests (for now — `fact_event/fact_current` lists added in Plan 02-02 after p98 ships).
3. **services/backend/tests/fixtures/__init__.py** (NEW empty): so pytest discovers the package.
4. **services/backend/tests/conftest.py**: add `from tests.fixtures.pg_fixture import pg_engine, pg_session` and a `pytest.mark.pg` marker registration in `pytest_configure`. Existing fixtures untouched.
5. **services/backend/tests/fixtures/test_pg_fixture_self.py** (NEW): one test `test_pg_fixture_spins_postgres_and_alembic_upgrade_head_idempotent(pg_engine)` that (a) runs `SELECT version();` returning a string containing `"PostgreSQL 15"`, (b) inspects current alembic head equals `p112_audit_event_user_hash` (head as of this plan), (c) runs `command.downgrade(cfg, "base")` then `command.upgrade(cfg, "head")` again, asserting both complete without raising. Skip with `pytest.skip("Docker unavailable")` if `docker info` fails.
6. **tools/db/regenerate_baseline.sh** (NEW, +x): bash script that (a) checks `docker` is available, (b) spins a one-shot `postgres:15.5` container, (c) `pip install -e services/backend && cd services/backend && alembic upgrade head`, (d) runs `pg_dump --schema-only --no-owner --no-privileges $URL > tools/db/baseline_snapshot_2026-05-18.sql`, (e) tears down container. Use `set -euo pipefail`. Print the alembic head SHA at the end.
7. **tools/db/baseline_snapshot_2026-05-18.sql** (NEW): generated output of step 6 (commit the file). Contains DDL for the head as of 2026-05-18 = `p112_audit_event_user_hash`. NOTE: this file is REGENERATED by Plan 02-02 once p98 lands — the 2026-05-18 stamp is the baseline-before-Phase-02-schema; do NOT rename across regenerations.
8. **CRITICAL POSTGRES BOOLEAN CHECK**: while building the fixture, run the existing test suite via `cd services/backend && python3 -m pytest tests/fixtures/test_pg_fixture_self.py -q` to confirm zero `sa.Boolean+sa.text` regressions slip in. If any alembic test fails with `DatatypeMismatch`, do NOT proceed — fix the offending migration first.

Per CONTEXT D-22 + RESEARCH § Standard Stack: testcontainers-python is the per-PR primary; Railway-staging-replica is supplementary nightly soak (NOT in this task).
  </action>
  <verify>
    <automated>cd services/backend && python3 -c "import testcontainers, uuid_utils; print('deps OK', testcontainers.__version__, uuid_utils.__version__)" && python3 -m pytest tests/fixtures/test_pg_fixture_self.py -q 2>&1 | tee /tmp/pg_fixture.log && grep -q "1 passed" /tmp/pg_fixture.log && bash tools/db/regenerate_baseline.sh && git diff --exit-code tools/db/baseline_snapshot_2026-05-18.sql && ls tools/db/regenerate_baseline.sh | xargs -I{} test -x {}</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "import testcontainers, uuid_utils"` exits 0 (both deps installed).
    - `cd services/backend && python3 -m pytest tests/fixtures/test_pg_fixture_self.py -q` exits 0 within 90s.
    - Output of self-test contains a `PostgreSQL 15` string match.
    - `bash tools/db/regenerate_baseline.sh && git diff --exit-code tools/db/baseline_snapshot_2026-05-18.sql` exits 0 (reproducibility).
    - `tools/db/baseline_snapshot_2026-05-18.sql` is at least 50 lines, contains `CREATE TABLE projection_audit_records`, `CREATE TABLE audit_events`, `CREATE TABLE dek_vault`.
    - `[ -x tools/db/regenerate_baseline.sh ]` exits 0.
    - No pre-existing pytest tests regress: `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/fixtures/test_pg_fixture_self.py -x` exits 0 (baseline 7264+ passed maintained).
  </acceptance_criteria>
  <done>
    pg_fixture spins real Postgres 15.5 via testcontainers, runs alembic upgrade head + downgrade base + re-upgrade head idempotently within 90s. Baseline SQL committed, reproducible. testcontainers + uuid_utils pinned and installed. Phase 02 has a Postgres-real test harness; the Hotfix B class is now catchable at PR time on dev CI (D-22 met).
  </done>
</task>

<task type="auto">
  <name>Task 2: Ship D-20 alembic_boolean_default_lint + D-24 hmac_pepper_audit + register HARD lefthook + CI wiring</name>
  <files>
    tools/checks/alembic_boolean_default_lint.py,
    tools/checks/hmac_pepper_audit.py,
    tools/checks/tests/test_alembic_boolean_default_lint.py,
    tools/checks/tests/test_hmac_pepper_audit.py,
    services/backend/tests/fixtures/alembic_bad.py,
    services/backend/tests/fixtures/bad_audit_writer.py,
    lefthook.yml,
    .github/workflows/backend-ci.yml
  </files>
  <read_first>
    tools/checks/banned_terms_python.py (existing lint structure — self-exempt pattern, NFKC normalization, CLI exit code 1 on findings),
    tools/checks/accent_lint_fr.py (path-glob + scan_file signature reference),
    services/backend/alembic/versions/p111_projection_audit.py (lines 50-65 — correct sa.false() pattern is the OK case),
    services/backend/alembic/versions/p112_audit_event_user_hash.py (HMAC pattern via pgcrypto fallback — this lint is for the PYTHON side, NOT SQL DO-blocks),
    lefthook.yml (existing pre-commit shape, commands list — append AFTER wiki-lint, BEFORE banned-terms-arb-gate),
    .github/workflows/backend-ci.yml (existing CI structure — append a `pg-integration` job)
  </read_first>
  <action>
1. **tools/checks/alembic_boolean_default_lint.py** (NEW): Python script with CLI `python3 tools/checks/alembic_boolean_default_lint.py [paths...]`. Default scan path: `services/backend/alembic/versions/*.py`. Logic: parse each file with `ast.parse`; walk for `ast.Call` whose `.func` resolves to `sa.Column` (or imported `Column`); inspect each call's keyword args; flag if a kwarg `server_default` is `ast.Call` whose `.func` is `sa.text` AND the same column call passes `sa.Boolean()` (or `Boolean()`) as the type positional arg. Exit 1 with file:line + `« BOOLEAN columns must use sa.false() / sa.true() — sa.text() server_default crashes Postgres DatatypeMismatch (Hotfix B regression class, see services/backend/alembic/versions/p111_projection_audit.py:55) »`. Self-exempt the script itself + test fixtures path. Support `--self-test` flag that runs against `services/backend/tests/fixtures/alembic_bad.py` and asserts exit code 1; against the existing `alembic/versions/` tree it MUST exit 0 (regression sentinel).
2. **services/backend/tests/fixtures/alembic_bad.py** (NEW): contains the exact forbidden pattern verbatim so the lint has a deterministic positive test: `sa.Column("flag", sa.Boolean(), nullable=False, server_default=sa.text("0"))`. NEVER imported by production; it's a lint fixture.
3. **tools/checks/hmac_pepper_audit.py** (NEW): Python script with CLI `python3 tools/checks/hmac_pepper_audit.py [paths...]`. Default scan: `services/backend/app/**/*.py`. Logic: regex pattern `hashlib\.sha256\s*\(\s*(?:user_id|actor_email|ip_address|user_agent)\b` (with `re.IGNORECASE`). Self-exempt this script + tests fixtures + `services/backend/app/services/audit/hmac_pepper.py` (added in Plan 02-02 W1 — pre-create with a TODO stub here to seed the self-exempt path). Exit 1 with file:line + `« Use app.services.audit.hmac_pepper.hmac_user_id() instead of bare hashlib.sha256 — D-07/D-24 HMAC-pepper canonical entry »`. NFKC normalization on input. Self-test mode same shape as Task 2.1.
4. **services/backend/tests/fixtures/bad_audit_writer.py** (NEW): contains `import hashlib; def bad(user_id): return hashlib.sha256(user_id.encode()).hexdigest()` to seed positive test.
5. **tools/checks/tests/test_alembic_boolean_default_lint.py** + **test_hmac_pepper_audit.py** (NEW each): pytest unit tests asserting (a) exit 1 on bad fixture, (b) exit 0 on clean tree, (c) NFKC normalization works, (d) self-exempt is respected.
6. **lefthook.yml**: append two commands to `pre-commit:commands` AFTER `wiki-lint`, BEFORE `banned-terms-arb-gate`:
   ```yaml
   alembic-boolean-default-lint:
     run: python3 tools/checks/alembic_boolean_default_lint.py {staged_files}
     glob: "services/backend/alembic/versions/*.py"
     tags: [migration, postgres, phase-02-d-20]
     fail_text: "Postgres BOOLEAN DEFAULT bug — use sa.false()/sa.true() not sa.text(\"0\"/\"1\"). CLAUDE.md Hotfix B regression class."
   hmac-pepper-audit:
     run: python3 tools/checks/hmac_pepper_audit.py {staged_files}
     glob: "services/backend/app/**/*.py"
     tags: [security, audit, phase-02-d-24]
     fail_text: "Audit-PII hash must route through app.services.audit.hmac_pepper.hmac_user_id() — bare hashlib.sha256(user_id) is rainbow-table-reversible (security-auditor obs #175)."
   ```
7. **.github/workflows/backend-ci.yml**: under existing jobs, add a `pg-integration` job using `ubuntu-latest` (Docker pre-installed). Steps: checkout, set up Python 3.11, `pip install -e "services/backend[test]"`, `cd services/backend && python3 -m pytest tests/fixtures/test_pg_fixture_self.py tests/integration_pg -q -k pg --tb=short`. Run on PRs touching `services/backend/alembic/**` or `services/backend/app/models/**` or `services/backend/tests/fixtures/**`. ALSO add steps in existing backend-lint job to run `python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/` + `python3 tools/checks/hmac_pepper_audit.py services/backend/app/` as HARD gates.

Per CONTEXT D-20 + D-24: HARD lints, no warning mode, no LEFTHOOK_BYPASS exception for these two (Hotfix B class is non-negotiable; HMAC-pepper is security-auditor obs #175 non-negotiable).
  </action>
  <verify>
    <automated>python3 tools/checks/alembic_boolean_default_lint.py --self-test && echo "lint self-test: $?" && python3 tools/checks/hmac_pepper_audit.py --self-test && echo "audit self-test: $?" && python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/ && python3 tools/checks/hmac_pepper_audit.py services/backend/app/ && grep -A2 "alembic-boolean-default-lint:" lefthook.yml && grep -A2 "hmac-pepper-audit:" lefthook.yml && python3 -m pytest tools/checks/tests/test_alembic_boolean_default_lint.py tools/checks/tests/test_hmac_pepper_audit.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `python3 tools/checks/alembic_boolean_default_lint.py services/backend/tests/fixtures/alembic_bad.py; [ $? -eq 1 ]` (exit 1 on bad fixture).
    - `python3 tools/checks/alembic_boolean_default_lint.py services/backend/alembic/versions/` exits 0 (existing tree is clean per Hotfix B fix `fe52ba31`).
    - `python3 tools/checks/hmac_pepper_audit.py services/backend/tests/fixtures/bad_audit_writer.py; [ $? -eq 1 ]` (exit 1 on bad fixture).
    - `python3 tools/checks/hmac_pepper_audit.py services/backend/app/` exits 0 OR exit 1 with a SHORT, REVIEW-ABLE list (the Hotfix C sites that need migrating — those become Plan 02-02 W1 D-14/D-15 work, NOT a blocker here; in this case we tee output to a known-baseline file `tools/checks/_baseline_hmac_sites_at_p112.txt` and the CI uses `--baseline` flag to silence pre-existing sites until Plan 02-02 migrates them). If chosen route is baseline-mode, the lint MUST be HARD on new occurrences in any file touched by the PR.
    - `grep -c "alembic-boolean-default-lint\|hmac-pepper-audit" lefthook.yml` returns 2.
    - `python3 -m pytest tools/checks/tests/test_alembic_boolean_default_lint.py tools/checks/tests/test_hmac_pepper_audit.py -q` exits 0.
    - `git grep -n "sa.text(\"0\")" services/backend/alembic/versions/` returns 0 results.
  </acceptance_criteria>
  <done>
    Two new HARD pre-commit lints wired. The Hotfix B class can no longer ship; bare `hashlib.sha256(user_id)` can no longer ship outside the canonical hmac_pepper entry. CI `pg-integration` job catches Postgres-DDL drift on every PR touching alembic.
  </done>
</task>

<task type="auto">
  <name>Task 3: D-21 codegen-determinism fix + D-08/D-09 S12 PR-1 (façade-delegate + IJM/LAA promote + frontalier rename) + D-10 Flutter PR-A2 + D-11 dead-COUP-04 integration test</name>
  <files>
    tools/codegen/regulatory_constants_to_dart.py,
    apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart,
    services/backend/app/services/independants/__init__.py,
    services/backend/app/services/independants/indemnity_rates.py,
    services/backend/app/services/independant_service.py,
    services/backend/app/services/expat/frontalier_service.py,
    services/backend/app/services/expat/frontalier_segment_service.py,
    services/backend/app/services/expat/__init__.py,
    services/backend/app/api/v1/endpoints/expat.py,
    services/backend/tests/test_expat.py,
    services/backend/tests/test_s12_composition.py,
    services/backend/tests/test_s12_frontalier_rename.py,
    services/backend/tests/integration/test_coup_04_dead_path.py,
    apps/mobile/lib/services/coach_narrative_service.dart,
    apps/mobile/test/services/coach_narrative_profile_context_test.dart
  </files>
  <read_first>
    tools/codegen/regulatory_constants_to_dart.py (lines 270-290 — current `Generated at: <utcnow>` header to replace),
    services/backend/app/services/independant_service.py (lines 55-210 — current IJM/LAA constants + estimate methods),
    services/backend/app/services/expat/frontalier_service.py (lines 1-50 + 378-500 — current FrontalierService class to rename),
    services/backend/app/api/v1/endpoints/expat.py (lines 50-80 — import sites),
    services/backend/app/api/v1/endpoints/segments.py (lines 25-40 — S12 façade import sites; do NOT modify since the S12 façade keeps its name),
    services/backend/app/services/expat/__init__.py (re-export surface),
    services/backend/app/services/frontalier_service.py (lines 285-300 — S12 façade — DO NOT MODIFY the class name; only its import of the S23 class at the top),
    apps/mobile/lib/services/coach_narrative_service.dart (lines 1161-1208 — `_buildProfileContext` extension target),
    services/backend/app/api/v1/endpoints/coach_chat.py (lines 957-1015 — `_PROFILE_SAFE_FIELDS` set; the 15 missing fields are computed by diffing this set against current `_buildProfileContext` emission)
  </read_first>
  <action>
1. **D-21 codegen determinism (tools/codegen/regulatory_constants_to_dart.py)**: at lines ~270-290 the current header writer emits `f"// Generated at: {datetime.utcnow().isoformat()}Z"`. Replace with `f"// Generated for effective_on: {effective_on}"` where `effective_on` is the `effective_on` field of the most recent `RegulatoryParameter` snapshot used for codegen. NO `utcnow()` call in the file output. Add a `--check-determinism` flag that runs the generator twice in-process, compares the two outputs, and exits 1 if they differ. Regenerate `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`; commit the single-line diff (the new header). Verify D-12 phase-01 parity-lint signal is preserved (no noise diffs going forward).
2. **D-08 S18 IJM/LAA promotion**:
   - **services/backend/app/services/independants/indemnity_rates.py** (NEW): `IJM_ESTIMATE_RATE = 0.02` and `LAA_ESTIMATE_RATE = 0.015` as module-level constants. Add module docstring: « S18 single source of truth for IJM/LAA indemnity estimate rates. Promoted from S12 `independant_service.py:60-64` per Phase 02 D-08. Used by both S12 IndependantService and S18 ijm_service. »
   - **services/backend/app/services/independants/__init__.py**: re-export `from .indemnity_rates import IJM_ESTIMATE_RATE, LAA_ESTIMATE_RATE`.
   - **services/backend/app/services/independant_service.py**: at top of file, replace `IJM_ESTIMATE_RATE = 0.02` / `LAA_ESTIMATE_RATE = 0.015` with `from app.services.independants.indemnity_rates import IJM_ESTIMATE_RATE, LAA_ESTIMATE_RATE`. Methods `estimate_ijm` + `estimate_laa` keep their bodies (D-08 composition pattern: S12 stays a façade, S18 owns the data). Add module docstring: « S12 IndependantService — façade per Phase 02 D-08; calculator primitives delegate to `app.services.independants.*`. Indemnity rate constants live in `app.services.independants.indemnity_rates`. »
   - **services/backend/tests/test_s12_composition.py** (NEW): assert `IndependantService.estimate_ijm(10000) == 200.0` (i.e., 10000 × IJM_ESTIMATE_RATE rounded). Import `IJM_ESTIMATE_RATE` from BOTH `app.services.independants.indemnity_rates` AND `app.services.independant_service`, assert they are the same object (identity, not equality — proves the relocation didn't create a duplicate).
3. **D-09 frontalier rename PR-1 (alias-preserving)**:
   - **services/backend/app/services/expat/frontalier_segment_service.py** (NEW): `from app.services.expat.frontalier_service import FrontalierService as FrontalierSegmentService`. Module docstring: « D-09 PR-1 transitional alias — `FrontalierSegmentService` is the new canonical name; `FrontalierService` (in this module's underscored counterpart) remains as deprecated alias until Plan 02-04 PR-2 alias removal. ». BUT this is a temporary shim shape — preferred form per CONTEXT: rename the class **inside** `frontalier_service.py` to `FrontalierSegmentService`, then leave a single-line alias `FrontalierService = FrontalierSegmentService` at the bottom of `frontalier_service.py` for backward compat. Pick this preferred form.
   - **services/backend/app/services/expat/frontalier_service.py**: rename `class FrontalierService:` → `class FrontalierSegmentService:`. At end of file: `FrontalierService = FrontalierSegmentService  # deprecated alias, removed in Plan 02-04 PR-2 per D-09`.
   - **services/backend/app/services/expat/__init__.py**: add `from app.services.expat.frontalier_service import FrontalierSegmentService` (keep existing `FrontalierService` re-export untouched — alias still works).
   - **services/backend/app/api/v1/endpoints/expat.py**: at line 54, update `from app.services.expat.frontalier_service import FrontalierService` → `from app.services.expat.frontalier_service import FrontalierSegmentService as FrontalierService` (callers in this file keep using the old name; only the IMPORT renames; the rename surfaces to callers in Plan 02-04 PR-2).
   - **services/backend/tests/test_expat.py**: same import rewrite.
   - DO NOT modify `services/backend/app/services/frontalier_service.py` (S12 façade keeps its `FrontalierService` name — different class — per CONTEXT D-08).
   - DO NOT modify `services/backend/app/api/v1/endpoints/segments.py` (uses the S12 façade `app.services.frontalier_service.FrontalierService`, NOT the S23 segment class).
   - **services/backend/tests/test_s12_frontalier_rename.py** (NEW): assert `from app.services.expat.frontalier_service import FrontalierSegmentService` works; assert `FrontalierService is FrontalierSegmentService` (alias identity); assert the S12 façade `from app.services.frontalier_service import FrontalierService as S12Frontalier` is a DIFFERENT class (`S12Frontalier is not FrontalierSegmentService`).
4. **D-10 Flutter PR-A2 — extend `_buildProfileContext` (`apps/mobile/lib/services/coach_narrative_service.dart`)**: list the 15 fields by diffing `_PROFILE_SAFE_FIELDS` (43 server keys) against current `_buildProfileContext` emission. For each missing field (e.g., `monthly_gross_income`, `pillar_3a_balance`, `lpp_avoirs_vieillesse`, etc. — exact list derived during execution), add a `result['<key>'] = profile.<getter>;` line WITHOUT a `> 0` guard (emit-pattern, not handle-pattern, per RESEARCH § D-10). Update the test file:
   - **apps/mobile/test/services/coach_narrative_profile_context_test.dart** (NEW): widget test that builds a `CoachProfile` with the 15 new field setters, calls `CoachNarrativeService._buildProfileContext(profile)`, and asserts each of the 15 keys is present in the output map (using `expect(result.containsKey('<key>'), isTrue)`).
   - Run `python3 tools/checks/profile_safe_fields_parity.py` (existing Phase 01 W4 lint, SOFT mode). Verify the drift count drops from current `~15` to `~3` (3 Flutter-only fields stay; they're dropped in Plan 02-04 PR-A3 per D-10).
5. **D-11 dead-COUP-04 integration test**:
   - **services/backend/tests/integration/test_coup_04_dead_path.py** (NEW): integration test exercising the dead-COUP-04 path end-to-end. Build the test scenario: trigger a coach request that historically routed through COUP-04, assert it now follows the closed path (no COUP-04 invocation in trace). Use existing test fixtures from `tests/integration/test_coach_chat_*.py` as pattern. The exact assertion shape depends on COUP-04 closure mechanism shipped in Phase 01 — reference Phase 01 W4 SUMMARY (closed end-to-end per D-11). The test locks the contract: if a future PR re-introduces COUP-04 routing, this test fires.

Per Karpathy #3 surgical-changes: this task does NOT modify the S12 façade class name (`services/backend/app/services/frontalier_service.py`), the segments.py endpoint, or any unrelated code. Only the listed files.
  </action>
  <verify>
    <automated>python3 tools/codegen/regulatory_constants_to_dart.py --check-determinism && cd services/backend && python3 -m pytest tests/test_s12_composition.py tests/test_s12_frontalier_rename.py tests/integration/test_coup_04_dead_path.py tests/test_expat.py tests/test_segments.py -q && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/profile_safe_fields_parity.py 2>&1 | tee /tmp/parity.log && grep -E "drift|missing|diff" /tmp/parity.log && cd apps/mobile && flutter test test/services/coach_narrative_profile_context_test.dart 2>&1 | tail -5 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/accent_lint_fr.py --scope backend && python3 tools/checks/banned_terms_python.py services/backend/app/</automated>
  </verify>
  <acceptance_criteria>
    - `git grep -n "Generated at:" tools/codegen/regulatory_constants_to_dart.py apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` returns 0 hits.
    - `git grep -n "Generated for effective_on" apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` returns ≥1 hit.
    - `python3 tools/codegen/regulatory_constants_to_dart.py --check-determinism` exits 0 (two runs produce identical output).
    - `git grep -n "IJM_ESTIMATE_RATE = 0.02" services/backend/app/services/` returns exactly 1 hit, in `independants/indemnity_rates.py`.
    - `git grep -n "LAA_ESTIMATE_RATE = 0.015" services/backend/app/services/` returns exactly 1 hit, in `independants/indemnity_rates.py`.
    - `cd services/backend && python3 -c "from app.services.independants.indemnity_rates import IJM_ESTIMATE_RATE; from app.services.independant_service import IJM_ESTIMATE_RATE as A; assert A is IJM_ESTIMATE_RATE"` exits 0.
    - `cd services/backend && python3 -c "from app.services.expat.frontalier_service import FrontalierSegmentService, FrontalierService; assert FrontalierService is FrontalierSegmentService"` exits 0.
    - `git grep -n "class FrontalierService" services/backend/app/services/expat/frontalier_service.py` returns 0 hits (class renamed; only the bottom-line alias remains).
    - `git grep -n "class FrontalierService" services/backend/app/services/frontalier_service.py` returns 1 hit (S12 façade preserved at line 291).
    - `cd services/backend && python3 -m pytest tests/test_s12_composition.py tests/test_s12_frontalier_rename.py tests/integration/test_coup_04_dead_path.py tests/test_expat.py tests/test_segments.py -q` exits 0.
    - `python3 tools/checks/profile_safe_fields_parity.py` SOFT mode reports drift count ≤ 3 (15 server-canonical fields now emitted; 3 Flutter-only fields await Plan 02-04 PR-A3).
    - `cd apps/mobile && flutter test test/services/coach_narrative_profile_context_test.dart` exits 0.
    - `cd apps/mobile && flutter analyze` exits 0.
    - `python3 tools/checks/accent_lint_fr.py --scope backend` exits 0.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/` exits 0.
    - Full pytest regression: `cd services/backend && python3 -m pytest tests/ -q` exits 0 (≥ 7264 + new tests; no regression).
  </acceptance_criteria>
  <done>
    Codegen header is now `Generated for effective_on: <date>` (deterministic). IJM/LAA constants live in S18 (`independants/indemnity_rates.py`); S12 IndependantService delegates. Frontalier S23 class renamed to `FrontalierSegmentService` with alias preserved (PR-2 alias removal scheduled in Plan 02-04). Flutter `_buildProfileContext` emits 15 previously-missing fields; parity-lint drift count ≤ 3 (PR-A3 dead-fields drop scheduled in Plan 02-04). Dead-COUP-04 path contract locked in integration test.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Lefthook pre-commit → dev branch | All Phase 02 alembic + audit-PII code must clear new HARD lints before commit |
| Test fixtures → production code | `tests/fixtures/alembic_bad.py` + `bad_audit_writer.py` contain intentionally bad patterns; must NEVER be imported by app code |
| GitHub Actions runner → Docker daemon | testcontainers requires Docker; runner with no Docker breaks pg_fixture (ubuntu-latest has Docker pre-installed; verify in job step) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-08 | Tampering | `tools/checks/alembic_boolean_default_lint.py` AST traversal | mitigate | Match both `sa.Boolean()` and bare `Boolean()`; match both `sa.text(...)` and `text(...)` for server_default; whitelist `sa.false()` and `sa.true()`. Unit test asserts both bad-fixture exit 1 and existing tree exit 0. |
| T-02-09 | Denial of Service (CI) | testcontainers Docker dep | mitigate | `pg-integration` CI job first runs `docker info`; if Docker unavailable, skip with explicit error message (not silent pass). GH Actions ubuntu-latest has Docker built-in. Pin `postgres:15.5` to avoid latest-tag pulls. |
| T-02-10 | Information Disclosure | `hmac_pepper.py` stub created in this plan (real implementation in Plan 02-02) | accept | Stub raises `NotImplementedError` if invoked; only the self-exempt path matters here. Pepper bytes never present in this plan (Plan 02-02 introduces). |
| T-02-11 | Spoofing | Alias `FrontalierService = FrontalierSegmentService` | mitigate | Alias is read-only at import time; both names resolve to the same class object (identity check in test). Plan 02-04 PR-2 removes the alias atomically. |
| T-02-12 | Repudiation | Codegen timestamp removal (D-21) | accept | `effective_on` from RegulatoryParameter is a stable audit anchor; `utcnow()` removed because it was noise. Git log + commit sha provide regeneration provenance. |
</threat_model>

<verification>
**Phase-level checks for this plan:**
1. **Wave 0 self-contained**: this plan has zero dependencies on Plan 02-02/03/04. It runs as a single multi-commit bundle PR on `dev`.
2. **No production behavior change**: this plan ships lint protection + test harness + refactors that preserve all public signatures. Smoke test: `cd services/backend && python3 -m pytest tests/ -q` returns the Phase 01 baseline 7264+ tests still passing (delta only NEW tests added by tasks 2 + 3).
3. **`autonomous: true`**: every task can be executed by Claude without Julien intervention. Final commit is a single multi-commit chain merged to `dev` via PR. No staging deploy, no Railway env-var changes in this plan.
4. **Karpathy 4 self-audit**:
   - #1 Think Before Coding: assumptions (testcontainers version, uuid_utils choice, 15 fields list) are surfaced in `<read_first>` blocks.
   - #2 Simplicity First: no abstractions beyond what each D-XX requires.
   - #3 Surgical Changes: 30 files touched, all listed in `files_modified`. No adjacent "improvements".
   - #4 Goal-Driven: every task has a `<verify>` automated command + concrete acceptance_criteria.
5. **0-trust §9**: Plan SUMMARY at close-out MUST cite (a) pytest exit-0 SHA, (b) lint self-test SHA, (c) pg_fixture self-test output snippet, (d) `git diff --stat` for the bundle PR, (e) `gh pr view <N> --json mergedAt` once merged. Plan status word during execution stays `IN_FLIGHT` until merge confirmed.
</verification>

<success_criteria>
- [ ] Lefthook reports 2 new HARD pre-commit lints active (`alembic-boolean-default-lint` + `hmac-pepper-audit`); both pass on existing tree.
- [ ] `pg_fixture.py` spins Postgres 15.5 testcontainer within 90s; alembic upgrade head + downgrade base + re-upgrade head idempotent.
- [ ] `tools/db/baseline_snapshot_2026-05-18.sql` committed and reproducible.
- [ ] Codegen header reads `Generated for effective_on: <date>` (no `utcnow`); `--check-determinism` exits 0.
- [ ] IJM/LAA constants imported from `app.services.independants.indemnity_rates`; S12 `IndependantService` keeps signature.
- [ ] `FrontalierService` aliased to `FrontalierSegmentService` in `app/services/expat/frontalier_service.py`; both names resolve to same class.
- [ ] Flutter `_buildProfileContext` emits 15 new fields; parity-lint drift ≤ 3.
- [ ] `test_coup_04_dead_path.py` locks the contract closed in Phase 01.
- [ ] `cd services/backend && python3 -m pytest tests/ -q` exits 0 (≥ 7264 tests + new ones from this plan).
- [ ] `cd apps/mobile && flutter analyze && flutter test` exits 0.
- [ ] `python3 tools/checks/banned_terms_python.py services/backend/app/` + `accent_lint_fr.py --scope backend` exit 0.
- [ ] `git log --oneline | head -11` shows 11 atomic commits on the bundle PR branch (per RESEARCH W0 sequencing).
- [ ] Plan SUMMARY commits cite all `<verify>` outputs verbatim (0-trust §9.6).
</success_criteria>

<output>
After completion, create `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-SUMMARY.md` covering:
- Per-task verify output (pytest stdout, lint exit codes, parity-lint drift count, flutter test output).
- All 11 commit SHAs in order.
- PR URL once opened.
- 10 D-XX dispositions (D-08, D-09, D-10, D-11, D-18, D-20, D-21, D-22, D-23, D-24) with file:line references for each.
- 0-trust §9.6 evidence/caveat for any "ready" / "works" claim.
- Engram `mem_save` with `topic_key: mint-data-architecture-v1-02:wave-0:prereqs` and `prior_finding_refs` to obs #163 (Phase 01 CONTEXT) + #174 (db-architect) + #183 (S12) + #186 (Flutter D-MOB) + #187 (QA Postgres) + #188 (Postgres BOOLEAN bug root cause — this plan ships the lint that prevents recurrence).
</output>
