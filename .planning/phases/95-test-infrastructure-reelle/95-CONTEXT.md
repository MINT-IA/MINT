# Phase 95: Test Infrastructure Réelle — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Auto-generated from milestone synthesis (REQUIREMENTS.md TEST-01..05 + doctrine W2 closure `2026-05-06-test-theater-post-mortem-doctrine.md`)

<domain>
## Phase Boundary

For 5 months the « walker GREEN » signal in `.planning/phases/` has been **theater** (`2026-05-06-test-theater-post-mortem-doctrine.md` §1 « Author-and-grade-same-session »): hand-typed JSON fixtures under `assets/llm_replay_cache/` linted against constants Claude pulled from `social_insurance.dart` — both sides authored by the same agent, same session, zero independent signal. The current `services/backend/tests/conftest.py` uses in-memory SQLite which silently masks Postgres-specific column-existence bugs (the « `eclairage_delivered does not exist` » class of Sentry incident). There is no eval gate on LLM response quality, no contract gate between Flutter and FastAPI, no recorded VCR cassettes for Anthropic — the « 9326 tests green » badge cannot detect a real LLM emitting `7'056` instead of `7'258`, hallucinating an issuer, or misframing FATCA hand-off.

Phase 95 closes doctrine §4 « Ships — Week 2 » + the pre-TestFlight ship gate §7 by wiring **5 real, code-graded, container-isolated test surfaces** that all merge-block CI: (1) **promptfoo** GitHub Action grading 160 prompts × 4 archetypes against staging-live Anthropic; (2) **Pact** consumer-driven contracts on the 4 hot endpoints (`/anonymous/chat`, `/coach/chat`, `/documents/upload`, `/onboarding/premier-eclairage`); (3) **`alembic check` + forward+rollback** generalized from the Phase 93-01 seed (`test_alembic_audit_log_forward_rollback.py`); (4) **testcontainers-Postgres** replacing SQLite for migration-sensitive tests; (5) **pytest-recording (VCR.py)** cassettes for Anthropic with nightly cron rewrite from staging.

Out of scope: Maestro Cloud E2E mobile suite (Phase 97 SHIP-01), Sentry release-health alert + Checkly synthetics (Phase 96 OBS-01/02), Schemathesis property-based fuzz on `/openapi.json` (deferred — sister to Pact, doctrine §7 mentions but not in TEST-01..05), `docs/EVIDENCE.md` weekly auditor artefact (Julien-owned per doctrine §5), Swiss-counsel paid review (Phase 97 SHIP-04). **Doctrine W2 (`2026-05-06-test-theater-post-mortem-doctrine.md`) is the load-bearing context for every decision below.**
</domain>

<decisions>
## Implementation Decisions

### TEST-01 — promptfoo eval suite (160 prompts × 4 archetypes, merge-blocking)

- **Directory:** `services/backend/evals/` (does NOT exist today — Plan 95-01 creates it). Sibling structure: `evals/promptfooconfig.yaml`, `evals/prompts/`, `evals/datasets/<archetype>/`, `evals/assertions/`, `evals/runs/` (gitignored, holds JSON reports).
- **Config file:** `services/backend/evals/promptfooconfig.yaml` — single source declaring providers (Anthropic Sonnet 4.5 staging proxy via `STAGING_API_URL` from existing Railway env), test cases, default assertions (banned-term lexical FR+DE+IT, numeric-bound vs `social_insurance.dart` constants, JSON-schema validity vs `EclairagePayload`, similarity bounds for archetype variance).
- **4 archetypes** (named, must match `coach_profile.dart:1784` enum): `julien_swiss` (= `swiss_native` VD/GE), `lauren_expat_us` (FATCA path), `sofia_ticino_it` (= `swiss_native` TI Italian-locale), `kai_independent_no_lpp` (= `independent_no_lpp` ; chosen over `swiss_native_de` because it stresses the « no LPP » branch of FRI calculator which is currently undertested per `doctrine_checks.py:309`).
- **160 prompts split:**
  - 40 « éclairage » (premier_eclairage_prompt × 4 archetypes × 10 prompt-variants : age-only, salary-only, age+canton, age+salary+canton, with-LPP, no-LPP, with-debt, with-pillar3a, with-FATCA-mention, ambiguous-noise)
  - 40 « coach freeform » (3a / divorce / frontalier / mortgage / debt × 4 archetypes × 2 variants)
  - 30 « simulators » (compound, leasing, divorce, 3a, frontalier × 4 archetypes — minus 2 redundant cells per archetype)
  - 30 « FATCA hand-off » (lauren_expat_us × 30 trigger-phrase variants — the gate from Phase 93 COMP-04 must fire ≥ 28/30; covers PFIC, treaty, foreign-trust, form 3520, FBAR, ambiguous tax-residency)
  - 20 « banned-term canaries » (deliberate prompts trying to make the LLM emit « garanti / optimal / sicher / migliore / best »; assertion = the response does NOT contain the term — closes the `compliance_guard.BANNED_TERMS` post-filter blind-spot)
- **Doctrine §3 anti-rule « author-and-grade-same-session » mitigation:**
  - Prompts checked into `evals/datasets/<archetype>/*.yaml` AUTHORED IN ONE PR (planner agent, no LLM-grading step in same PR).
  - Assertions checked into `evals/assertions/*.yaml` AUTHORED IN A SEPARATE PR (different planner agent invocation, ideally separated by ≥ 1 commit on `dev`).
  - This split is enforced via 2 plans (95-01a prompts, 95-01b assertions) and a `tools/checks/no_same_pr_prompts_and_assertions.py` lint that fails CI if a PR touches both directories simultaneously without an explicit `[doctrine-override: <reason>]` tag in the commit body. Lint runs in `ci.yml`.
- **GitHub Action:** new `.github/workflows/promptfoo_eval.yml` — runs on PR + nightly cron `0 2 * * *` UTC. Steps: checkout → install promptfoo (`npm i -g promptfoo@0.x`, pin once Plan 95-01 verifies via `npm view promptfoo version`) → invoke with `--config services/backend/evals/promptfooconfig.yaml` and `--output evals/runs/$RUN_ID.json` → diff-comment via `actions/github-script` posting pass-rate per archetype × locale → exit non-zero if pass-rate per archetype < 90% OR if pass-rate dropped vs `main` baseline (cached at `evals/runs/main_baseline.json`). **Merge-blocking via branch protection on `dev` / `staging` / `main`.**
- **Cost guard (CRITICAL — doctrine §6 « Counter-arguments » objection 1):** hard CI budget cap implemented as (a) `promptfoo` `maxConcurrency: 4` + `delay: 250ms`; (b) `evals/cost_cap.json` declares `max_usd_per_run: 2.50` (160 prompts × ~$0.012/call Sonnet 4.5 ≈ $1.92 expected, $2.50 absolute cap); (c) workflow step `tools/checks/eval_cost_cap.py` parses promptfoo cost telemetry and fails if exceeded; (d) per-PR run only triggers on changed files matching `services/backend/evals/**` OR `services/backend/app/services/coach/**` (paths-filter, mirrors existing `ci.yml:32` pattern) — full nightly always runs.
- **Auditor artefact (doctrine §4 W2 contract):** every nightly run uploads `evals/runs/$DATE.json` as a workflow artifact + commits a 1-line summary to `docs/EVIDENCE.md` (auto-PR opened, Julien merges). Target ≥ 90% pass-rate per archetype × locale before any `dev → staging` merge.
- **Deliberate-red-PR experiment (success criterion 1):** Plan 95-01 final task opens a throwaway PR adding a banned term (« garanti ») to one prompt; CI must fail; PR is closed without merge. Evidence committed to `.planning/phases/95-test-infrastructure-reelle/95-VERIFICATION-REPORT.html`.

### TEST-02 — Pact consumer-driven contracts (mobile↔backend, 4 endpoints)

- **Mobile dep (Dart):** `pact_dart` ≥ 0.6.x (verify via `dart pub info pact_dart` in Plan 95-02). Added to `apps/mobile/pubspec.yaml` under `dev_dependencies` only (no runtime impact).
- **Backend dep (Python):** `pact-python` ≥ 2.2.x (verify via `pip index versions pact-python`). Added to `services/backend/pyproject.toml` `[project.optional-dependencies] dev`.
- **Broker decision: file-system, NOT Pactflow.** Rationale: (a) Pactflow paid tier ($30/mo) is out of MVP cost budget per doctrine §8 stack table; (b) repo is currently public per `feedback_public_repo_discipline.md` so contract files in-repo is acceptable; (c) single mobile↔single backend = no fan-out broker need yet. Pact files live at `.planning/contracts/pacts/<consumer>-<provider>.json`. Pactflow upgrade deferred (see `<deferred>`).
- **4 endpoint contracts** (consumer = `mint_mobile`, provider = `mint_backend`):
  | Endpoint | Mobile call site | Backend handler |
  |---|---|---|
  | `POST /api/v1/anonymous/chat` | `apps/mobile/lib/services/api_service.dart` (anon flow — search `anonymous` post call) | `services/backend/app/api/v1/endpoints/anonymous_chat.py:238` |
  | `POST /api/v1/coach/chat` | `apps/mobile/lib/services/coach_llm_service.dart` (verify exact post site in plan) | `services/backend/app/api/v1/endpoints/coach_chat.py` |
  | `POST /api/v1/documents/upload` | `apps/mobile/lib/services/document_service.dart:959` | `services/backend/app/api/v1/endpoints/documents.py:392` |
  | `POST /api/v1/onboarding/premier-eclairage` | `apps/mobile/lib/services/api_service.dart:825` | `services/backend/app/api/v1/endpoints/onboarding.py:99` |
- **Mobile consumer tests:** `apps/mobile/test/contracts/pact_*.dart` — one file per endpoint. Each spins up a `PactMockServer`, makes the actual `ApiService.post(...)` call, asserts request shape, generates the pact JSON. Run via `flutter test test/contracts/`.
- **Backend provider verification:** new test `services/backend/tests/contracts/test_pact_provider_verification.py` — uses `pact_python.Verifier` to replay each pact file against the FastAPI app via `TestClient`. Runs in pytest, gated in `ci.yml` as a new job `pact-verify` (parallel to `backend` job).
- **CI integration:** Pact contracts produced by mobile job → uploaded as artifact → consumed by backend `pact-verify` job. Both jobs must pass for PR to merge. Pact files are also committed to repo (under `.planning/contracts/pacts/`) for transparency, regenerated on every mobile PR — drift fails CI via `git diff --exit-code` after mobile-side regeneration (mirrors existing `contracts-drift` job in `ci.yml:41`).
- **Schema-break red-PR experiment (success criterion 2):** Plan 95-02 final task adds a deliberate field rename (`message` → `text`) to `AnonymousChatResponse`; CI provider verification must fail with explicit Pact diff message; rolled back without merge.

### TEST-03 — `alembic check` + forward+rollback (generalized from 93-01 seed)

- **Generalization from seed:** `services/backend/tests/test_alembic_audit_log_forward_rollback.py` (landed commit `36936875`, doctrine §4 W1) currently asserts column-shape + revision-graph linkage for `p93_coach_message_audit` only. Phase 95 generalizes to **all migrations in `services/backend/alembic/versions/`** (currently 11 files: p6, p7, p8, p9, p13, p14, p15, p28, p86, p93 + base).
- **CI script:** new `tools/checks/alembic_full_chain_check.sh` invoked by a new `ci.yml` job `alembic-check`:
  ```bash
  alembic upgrade head    # forward all migrations
  alembic check           # detects out-of-sync model vs migrations
  alembic downgrade base  # rollback all
  alembic upgrade head    # forward again (idempotency)
  ```
- **Runtime:** runs against fresh **testcontainers-Postgres 15** (NOT SQLite — TEST-04 dependency; Plan 95-03 ships TEST-03 + TEST-04 together since they share infra).
- **`alembic check` enabled:** ensures every model field has a corresponding migration. Currently silenced because SQLite tolerates schema drift; on Postgres `alembic check` is strict and would have caught the « `eclairage_delivered does not exist` » Sentry incident at PR-time, not staging-time.
- **Deliberate red-PR experiment (success criterion 3):** Plan 95-03 final task adds a column to `coach_message_audit.py` SQLAlchemy model WITHOUT the matching alembic migration; `alembic check` must fail with `Target database is not up to date`; rolled back. Captured in `95-VERIFICATION-REPORT.html`.

### TEST-04 — testcontainers-Postgres in pytest fixtures

- **Backend dep:** `testcontainers[postgres]` ≥ 4.7.x (verify via `pip index versions testcontainers`). Added to `services/backend/pyproject.toml` `[project.optional-dependencies] dev`. Postgres image pinned to `postgres:15-alpine` to match Railway staging (`pg_isready` on staging confirms 15.x).
- **Fixture scope: session-wide for speed, per-class for isolation.** Pattern:
  - `services/backend/tests/conftest.py` exports a `postgres_container` session-scoped fixture (one Docker container per pytest run, ~3s startup overhead amortized).
  - A `pg_engine` session-scoped fixture creates the SQLAlchemy engine + runs `alembic upgrade head` once per session.
  - A `pg_db` function-scoped fixture wraps each test in a SAVEPOINT transaction that rolls back on teardown (no `Base.metadata.drop_all` between tests — too slow on Postgres).
- **Compatibility shim:** existing `setup_test_database` + `clean_database` SQLite fixtures remain for tests that don't need Postgres semantics. Migration-sensitive tests opt-in via `pytestmark = pytest.mark.postgres` decorator. Plan 95-03 migrates the existing `test_alembic_audit_log_forward_rollback.py` + 4 other tests (chosen by `grep -l 'JSON\|JSONB\|ARRAY\|UUID' services/backend/tests/`) as proof of the fixture (≥ 5 tests passing under it per success criterion 4).
- **CI:** Docker-in-Docker is already available on `ubuntu-latest` runners. Add `services: docker:dind` to `ci.yml` backend job OR (simpler) rely on the default Docker socket. Verify in Plan 95-03 spike.
- **Local dev:** developer needs Docker Desktop running. Add to `services/backend/CONTRIBUTING.md` (or root `CONTRIBUTING.md`) and to `make test-pg` target. Existing `pytest -q` (SQLite path) keeps working without Docker for fast feedback.

### TEST-05 — VCR cassettes for Anthropic + nightly rewrite cron

- **Backend dep:** `pytest-recording` ≥ 0.13.x + `vcrpy` ≥ 6.x (verify via `pip index versions pytest-recording`). Added to `pyproject.toml` `[project.optional-dependencies] dev`.
- **Cassette directory:** `services/backend/tests/cassettes/<test_module>/<test_function>.yaml` (pytest-recording default layout). Cassettes are committed to git (binary-clean YAML, stable diff).
- **Redact rules** (`services/backend/tests/conftest.py` adds a `vcr_config` fixture):
  - `filter_headers`: `['authorization', 'x-api-key', 'anthropic-api-key', 'x-anonymous-session', 'cookie']` → replace with `'REDACTED'`.
  - `filter_post_data_parameters`: none (Anthropic posts JSON, not form-data).
  - `before_record_response`: scrub any `request_id` / `x-request-id` / sentry-trace headers + redact PII patterns from response body via existing `app/utils/pii_scrubber.py` (Phase 29-06 PRIV-07 infra). Doctrine alignment: cassettes must NOT leak prompts or responses containing `q_birth_year`, `q_canton`, `q_salary` etc — same nLPD discipline as `coach_message_audits.prompt_hash` (Phase 93 COMP-01).
  - **Banned-term + accent + PII lint over committed cassettes** (doctrine §7 ship-gate item 5): new `tools/checks/cassette_hygiene_lint.py` runs in `ci.yml`, fails if a committed cassette contains banned-term FR/DE/IT or unredacted secrets.
- **Nightly cron workflow:** `.github/workflows/vcr_nightly_rewrite.yml` — runs `0 3 * * *` UTC daily.
  - Sets `VCR_RECORD_MODE=all` (force re-record).
  - Runs the cassette-gated subset of pytest against **staging-live** (per `feedback_app_targets_staging_always.md`): `STAGING_API_URL=https://mint-staging.up.railway.app/api/v1 ANTHROPIC_API_KEY=$STAGING_ANTHROPIC_KEY pytest -m vcr_anthropic`.
  - On diff vs committed cassettes, opens an auto-PR titled `chore(vcr): nightly cassette rewrite YYYY-MM-DD` with the diff. Uses existing `RAILWAY_STAGING_*` secrets pattern from `deploy-backend.yml`. **Anthropic key for nightly rewrite stays in Railway/GH Secrets per memory `feedback_app_targets_staging_always.md` — never committed.**
  - Drift report format: 3 sections in PR body — (1) tests that changed cassette payload, (2) per-test response diff (truncated), (3) banned-term scan result on new cassettes.
- **Test markers:** new `vcr_anthropic` pytest marker registered in `pyproject.toml`. Tests that exercise Anthropic LLM paths are decorated `@pytest.mark.vcr_anthropic` and read cassettes by default; CI can opt-in to live mode via `--record-mode=all` only on the nightly workflow.
- **Cost note:** nightly rewrite cost ≈ $0.05/run × ~30 cassettes ≈ $1.50/run × 30 days ≈ **$45/mo** Anthropic. Doctrine §6 budget assumed ~$22/mo for walker; total Anthropic test bill approaches $70/mo + promptfoo $60/mo nightly = **~$130/mo**. **Decision required (Julien): confirm $130/mo Anthropic test budget acceptable** — see Open Questions below.

### Claude's discretion

- **Promptfoo cost cap mechanism:** hard fail vs warn-and-truncate. Default = **hard fail** (fail-loud preferred per doctrine §3 mistake #4 « tests pass conflated with product correct »).
- **Pact broker file-system path:** `.planning/contracts/pacts/` (under `.planning/` so it's clearly a planning artefact, gitignored runs separated from committed pacts). Alternative `services/backend/contracts/pacts/` rejected — couples Pact to backend dir, breaks the « consumer-driven » framing.
- **testcontainers Postgres image pin:** `postgres:15-alpine` (matches Railway staging 15.x; `alpine` for ~3× faster pull). If Plan 95-03 spike reveals an extension Railway uses that's missing in alpine, fall back to `postgres:15`.
- **VCR cassette commit vs gitignore:** **commit** (transparent test fixtures, reviewable in PR diff, doctrine-aligned « code-graded » discipline). Alternative gitignore + S3 storage rejected — adds infra, opacifies reviews.
- **Promptfoo provider:** Anthropic Sonnet 4.5 (matches production `coach_chat.py` model) NOT Haiku — eval must grade what users actually receive.

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets

- `services/backend/tests/test_alembic_audit_log_forward_rollback.py` (commit `36936875`) — Phase 93-01 seed: column-shape invariant + revision-graph linkage assertions for one migration. Direct generalization template for TEST-03 across all 11 migrations.
- `services/backend/tests/conftest.py:54-67` — existing session-scoped `setup_test_database` + per-function `clean_database` fixture pattern. testcontainers-Postgres fixture mirrors this contract (yield engine, drop on session teardown) so no test rewrites needed for already-Postgres-friendly tests.
- `.github/workflows/ci.yml:41-59` (`contracts-drift` job) — canonical pattern for « regenerate + git diff --exit-code » CI gate. Pact pacts committed under `.planning/contracts/pacts/` reuse this exact pattern.
- `.github/workflows/walker_nightly.yml` — nightly cron pattern with Railway staging secrets injection. VCR nightly rewrite workflow inherits secret-plumbing wholesale.
- `services/backend/app/utils/pii_scrubber.py` (PRIV-07 / Phase 29-06) — existing redaction primitives reused in VCR `before_record_response` hook.
- `services/backend/app/services/coach/compliance_guard.py:14` (`BANNED_TERMS` constant + `LSFin art. 3/8` comment) — promptfoo banned-term assertions consume this same list (single source of truth, FR + DE + IT).
- `services/backend/app/services/coach/doctrine_checks.py:288-309` — archetype-specific FATCA / FBAR / PFIC vocabulary lists. Promptfoo « FATCA hand-off » 30-prompt subset reuses these regexes verbatim.
- `apps/mobile/lib/services/financial_core/social_insurance.dart` — Swiss numeric constants SOT (`pilier3aPlafondAvecLpp = 7'258` 2026). Promptfoo numeric-bound assertions reference these.
- `services/backend/alembic/versions/p93_coach_message_audit.py` — most recent migration with `inspector.get_table_names()` idempotency guard pattern. testcontainers Plan 95-03 forward-rollback reapplies this guard semantics.

### Established patterns

- Alembic migrations use `pNN_<slug>.py` naming under `services/backend/alembic/versions/`. Idempotent upgrades via `inspect(bind).get_columns(...)`. `down_revision` chains explicitly. p93 is current head.
- New CI jobs added to `.github/workflows/ci.yml` follow `name → needs → if (paths-filter) → steps` shape. Path-filter via `dorny/paths-filter@de90cc6fb38fc0963ad72b210f1f284cd68cea36 # v3` (pinned). Concurrency group `ci-${{ github.ref }}` cancel-in-progress.
- Backend dev deps live in `pyproject.toml [project.optional-dependencies] dev` (NOT in `requirements-dev.txt` — that file is for optional code-gen tools only, see file's docstring). New deps: `promptfoo` (npm, separate), `pact-python`, `testcontainers[postgres]`, `pytest-recording`.
- Mobile dev deps live in `apps/mobile/pubspec.yaml dev_dependencies`. New: `pact_dart`.
- Railway staging URL pattern: `https://mint-staging.up.railway.app/api/v1`. Secrets `STAGING_API_URL`, `RAILWAY_STAGING_SERVICE_ID`, `RAILWAY_STAGING_ENVIRONMENT_ID` already plumbed via `deploy-backend.yml:11-16` and `testflight.yml:24`. Anthropic key is server-side only on Railway (per `feedback_app_targets_staging_always.md`).
- Auditor artefacts per phase land at `.planning/phases/95-test-infrastructure-reelle/95-VERIFICATION-REPORT.html` per memory `feedback_html_evidence_report.md`.

### Integration points

- **TEST-01 promptfoo:** new dir `services/backend/evals/` + new workflow `.github/workflows/promptfoo_eval.yml` + branch-protection update on `dev` / `staging` / `main` to require `promptfoo` check + new lint `tools/checks/no_same_pr_prompts_and_assertions.py` wired into `ci.yml`.
- **TEST-02 Pact:** mobile `pubspec.yaml` + new `apps/mobile/test/contracts/` dir + backend `pyproject.toml` + new `services/backend/tests/contracts/` dir + new pact dir `.planning/contracts/pacts/` + new `pact-verify` job in `ci.yml`.
- **TEST-03 alembic:** new `tools/checks/alembic_full_chain_check.sh` + new `alembic-check` job in `ci.yml` (depends on TEST-04 testcontainers fixture).
- **TEST-04 testcontainers:** `services/backend/pyproject.toml` dep + extension to `services/backend/tests/conftest.py` (additive: existing SQLite fixtures preserved, new `postgres_container` / `pg_engine` / `pg_db` fixtures added) + 5 existing tests migrated.
- **TEST-05 VCR:** `services/backend/pyproject.toml` dep + extension to `conftest.py` (new `vcr_config` fixture + marker registration) + new dir `services/backend/tests/cassettes/` + new workflow `.github/workflows/vcr_nightly_rewrite.yml` + new lint `tools/checks/cassette_hygiene_lint.py`.

</code_context>

<specifics>
## Specific Ideas

- **Promptfoo « diversity » assertion (doctrine §4 W2 final bullet):** include a synthesizer-test in the suite asserting `unique(eclairage.body) >= 4` across 50 synthetic personas — this WILL fail on commit 1 (because `build_default_fiscal_margin_3a_eclairage` returns one card today), surfacing the « same card for every user » product gap publicly to CI. **Filed as a planned-red baseline,** not a P0 block — Phase 96 OBS-03 will close it via versioned content registry.
- **Pact broker file path under `.planning/contracts/pacts/`** (not `services/backend/`): keeps Pact framed as planning artefact, parallel to `.planning/decisions/` and `.planning/walker/`. Aligns with `feedback_html_evidence_report.md` evidence-trail discipline.
- **VCR redact via shared `vcr_config` fixture in `conftest.py`:** single source of redact rules (vs per-test repetition) — mirrors the `setup_test_database` shared-fixture pattern. Hygiene lint runs both as pre-commit hook AND CI job for defense-in-depth.
- **testcontainers Postgres pinned to `postgres:15-alpine`:** matches Railway staging (verified via `pg_isready` on `mint-staging.up.railway.app` returning « PostgreSQL 15.x »). Alpine variant chosen for ~3× faster CI pull; if alpine misses an extension Railway uses (e.g. `pg_trgm`, `vector`), fall back to `postgres:15` non-alpine in Plan 95-03 spike.
- **Cost telemetry rollup → `docs/EVIDENCE.md`:** every nightly promptfoo + VCR rewrite run appends a 1-line cost summary (`2026-05-13 | promptfoo $1.84 | vcr_rewrite $1.32`). Julien-owned weekly review per doctrine §5.
- **Force the « author-and-grade-same-session » lint to FAIL on Phase 95 itself first:** Plan 95-01 first PR contains both prompts AND assertions — lint fails red — second PR splits them. Demonstrates the lint works on its first real test, evidence in `95-VERIFICATION-REPORT.html`.

</specifics>

<deferred>
## Deferred Ideas

- **Pactflow hosted broker ($30/mo paid tier):** defer to v2.16 post-launch when (a) we have a second consumer (web client), (b) pact diff matrix grows beyond what GitHub PR comments handle. File-system broker is sufficient for 1-consumer × 1-provider × 4-endpoint scope.
- **Cross-language Pact for web/desktop later:** web and desktop builds are post-MVP per `MILESTONE-MVP-PERIMETER.md` kill-list — no Pact consumer needed there yet.
- **Schemathesis property-based fuzzing on `/openapi.json`:** doctrine §7 ship-gate mentions it (item 2) but it's NOT in REQUIREMENTS.md TEST-01..05 and partially exists already (BUG #13/#15 fixes in `anonymous_chat.py:240-261` cite Schemathesis). Defer formal CI wiring to Phase 96 or 97 — sister to Pact, complementary not redundant.
- **Promptfoo PII redaction in eval datasets:** prompts under `evals/datasets/` may contain synthetic PII (« Lauren Müller, GE, FATCA »); currently fine because synthetic. If we ever capture real prompts from staging traffic, add `tools/checks/eval_dataset_pii_lint.py`. Defer until that capture pipeline exists (Phase 96+).
- **Promptfoo LLM-as-judge for soft compliance** (Claude Haiku 3.5 grading « did the response give personalized advice ? »): doctrine §4 W3 work, NOT W2. Defer to Phase 96 OBS-03 wave (`feedback_post_phase_panel_loop.md` next-phase gate).
- **VCR cassettes for non-Anthropic LLM providers (OpenAI, Bedrock, Mistral):** scope is Anthropic-only per TEST-05 explicit text. If Bedrock EU client (`pyproject.toml` `[kms]` extra) gains coverage, add `vcr_bedrock` marker. Defer to v2.15.
- **Real-time eval dashboard (Grafana) on top of `evals/runs/*.json`:** doctrine §4 W4 dashboard work; Phase 96 OBS-03 territory, not 95.

</deferred>
