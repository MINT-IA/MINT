---
phase: 32
plan: 5
plan_number: 05
slug: ci-docs-validation
type: execute
wave: 4
status: pending
depends_on: [reconcile, registry, cli, admin-ui, parity-lint]
files_modified:
  - .github/workflows/ci.yml
  - docs/SETUP-MINT-ROUTES.md
  - README.md
  - tools/simulator/walker.sh
  - .planning/phases/32-cartographier/32-VALIDATION.md
requirements:
  - MAP-02a
  - MAP-02b
  - MAP-04
threats:
  - T-32-02
  - T-32-03
  - T-32-04
  - T-32-05
autonomous: true
must_haves:
  truths:
    - "CI workflow has 4 new jobs: route-registry-parity, mint-routes-tests, admin-build-sanity, cache-gitignore-check"
    - "`docs/SETUP-MINT-ROUTES.md` documents Keychain setup + Sentry token scope lock + troubleshooting"
    - "README.md links to SETUP-MINT-ROUTES.md"
    - "walker.sh has new `--scenario=admin-routes` branch that boots iPhone 17 Pro sim with ENABLE_ADMIN=1 and captures screenshots at `.planning/phases/32-cartographier/screenshots/walker-YYYY-MM-DD/`"
    - "J0 Task 1 tree-shake verification executed: `strings Runner | grep -c kRouteRegistry == 0`"
    - "J0 Task 2 SentryNavigatorObserver smoke documented with explicit PASS / FAIL / BLOCKED outcome per M-4 3-branch hierarchy (no 'soft defer')"
    - "J0 Task 3 batch OR-query limit empirically determined (target ≥30, or document actual)"
    - "J0 Task 4 parity lint clean on HEAD (Plan 04 output)"
    - "J0 Task 5 CLI DRY_RUN pytest green (Plan 02 output)"
    - "J0 Task 6 walker.sh admin-routes smoke — ≥5 screenshots captured OR explicit gate fail reported"
    - "`32-VALIDATION.md` frontmatter flipped to `nyquist_compliant: true` once all 6 J0 pass; stays `false` with explicit §Risks entry if J0 Task 2 is FAIL or BLOCKED"
    - "`admin-build-sanity` CI job fails on a test PR that adds `--dart-define=ENABLE_ADMIN=1` to testflight.yml"
  artifacts:
    - path: ".github/workflows/ci.yml (APPEND)"
      provides: "4 new CI jobs"
    - path: "docs/SETUP-MINT-ROUTES.md"
      provides: "Keychain + scope + troubleshooting playbook"
    - path: "README.md (APPEND link)"
      provides: "Index entry"
    - path: "tools/simulator/walker.sh (MODIFIED)"
      provides: "admin-routes scenario"
    - path: ".planning/phases/32-cartographier/32-VALIDATION.md (FLIP frontmatter)"
      provides: "nyquist_compliant: true after 6 J0 green (or false + §Risks entry if Task 2 fails/blocked)"
  key_links:
    - from: ".github/workflows/ci.yml"
      to: "tools/checks/route_registry_parity.py (Plan 04)"
      via: "route-registry-parity job"
      pattern: "run: python3 tools/checks/route_registry_parity.py"
    - from: ".github/workflows/ci.yml"
      to: "tests/tools/test_mint_routes.py (Plan 02)"
      via: "mint-routes-tests job"
      pattern: "MINT_ROUTES_DRY_RUN: \"1\""
    - from: ".github/workflows/ci.yml"
      to: ".github/workflows/testflight.yml + play-store.yml"
      via: "admin-build-sanity grep scan"
      pattern: "dart-define=ENABLE_ADMIN=1 NOT present"
---

<objective>
Wave 4 closing plan — wire CI jobs (D-12 §1-3 + §5), ship operator docs, add walker.sh admin-routes scenario, execute the 6 D-11 J0 empirical gates, and flip `32-VALIDATION.md` frontmatter `nyquist_compliant: true` once green.

Maps to ROADMAP Success Criterion 5 (CI fail on drift), the nLPD D-09 §3 cache-gitignore control, the D-11 J0 gates, and the D-12 §3 admin-build-sanity defensive scan.

Last plan in the phase. After this lands green, `/gsd-verify-work` runs Phase 32 final audit.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/32-cartographier/32-CONTEXT.md
@.planning/phases/32-cartographier/32-RESEARCH.md
@.planning/phases/32-cartographier/32-VALIDATION.md
@.github/workflows/ci.yml
@.github/workflows/testflight.yml
@.github/workflows/play-store.yml
@tools/simulator/walker.sh
@tools/simulator/sentry_quota_smoke.sh
@README.md
@CLAUDE.md

<interfaces>
<!-- CI job YAML shapes (D-12 §1-3 + §5, RESEARCH §7 lines 739-775) -->

route-registry-parity:
  name: Route registry parity
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with: { python-version: "3.11" }
    - run: python3 tools/checks/route_registry_parity.py

mint-routes-tests:
  name: mint-routes pytest (DRY_RUN)
  runs-on: ubuntu-latest
  env: { MINT_ROUTES_DRY_RUN: "1" }
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with: { python-version: "3.11" }
    - run: pip install pytest
    - run: pytest tests/tools/test_mint_routes.py tests/checks/test_route_registry_parity.py -q --tb=short

admin-build-sanity:
  name: Admin build sanity (ENABLE_ADMIN not in prod)
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Scan prod workflows for ENABLE_ADMIN=1
      run: |
        if grep -nE "dart-define=ENABLE_ADMIN=1" .github/workflows/testflight.yml .github/workflows/play-store.yml; then
          echo "::error::ENABLE_ADMIN=1 detected in prod build workflow — D-03 tree-shake violated"
          exit 1
        fi
        echo "OK: no ENABLE_ADMIN=1 in prod build workflows"

cache-gitignore-check:
  name: .cache/ in .gitignore
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: grep -qE "^\.cache/" .gitignore || (echo "::error::.cache/ must be gitignored per D-09 §3"; exit 1)

<!-- walker.sh admin-routes scenario pattern (mirror sentry_quota_smoke.sh style) -->
# New branch in --scenario dispatcher
# - install sim build with --dart-define=ENABLE_ADMIN=1
# - xcrun simctl launch <bundle>
# - navigate to /admin/routes via simctl openurl
# - capture 5 screenshots with simctl io
</interfaces>
</context>

<threat_model>
[ASVS L1+ — this plan defends against prod-build misconfiguration]
| ID | Threat | Likelihood | Impact | Mitigation | Test |
|----|--------|-----------|--------|-----------|------|
| T-32-05 | `--dart-define=ENABLE_ADMIN=1` accidentally committed to testflight.yml or play-store.yml — admin UI + registry ships to TestFlight/Play review | LOW (requires reviewer miss) | HIGH (D-03 tree-shake contract broken — 147 internal routes + dev descriptions exposed) | CI job `admin-build-sanity` runs `grep -nE "dart-define=ENABLE_ADMIN=1"` on testflight.yml + play-store.yml. Fails PR if matched. Runtime ≤5s. | J0 Task 6 (out of band — manual test PR demonstrating the gate fires) |
| T-32-02 (residual) | `.cache/route-health.json` leaks into git via missing .gitignore | LOW (Plan 02 added entry; this job is double-check) | MEDIUM | `cache-gitignore-check` CI job greps `.gitignore` for `^\.cache/`. Fails PR if removed. | CI job run on PR |
| T-32-03 (residual) | SENTRY_AUTH_TOKEN setup drift — new dev accidentally creates token with write scope | LOW | MEDIUM | `docs/SETUP-MINT-ROUTES.md` prescribes scope = `project:read + event:read + org:read`; `./tools/mint-routes --verify-token` sub-command (Plan 02) fails with exit 78 if scope exceeds. | Manual walkthrough via docs |
| T-32-04 (residual) | Tree-shake regression — future dev import of `kRouteRegistry` from a non-admin file leaks it to prod bundle | MEDIUM (refactor error) | HIGH | D-11 Task 1 empirical `strings Runner | grep -c kRouteRegistry == 0`. Executed this plan. If drift detected later, `admin-build-sanity` does not catch this — Phase 34 may add lints. | J0 Task 1 (this plan) |
</threat_model>

<tasks>

<task type="auto">
  <name>Task 1: Append 4 CI jobs to .github/workflows/ci.yml</name>
  <files>.github/workflows/ci.yml</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.github/workflows/ci.yml (current state — check for existing jobs pattern, `needs:`, `changes` job output, triggers)
    - /Users/julienbattaglia/Desktop/MINT/.github/workflows/testflight.yml (verify current ENABLE_ADMIN absence baseline)
    - /Users/julienbattaglia/Desktop/MINT/.github/workflows/play-store.yml (same)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §7 CI D-12 jobs (lines 739-775)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-12 (CI spec)
  </read_first>
  <action>
    Open `.github/workflows/ci.yml` and append 4 jobs at the top-level `jobs:` dictionary. Match existing indentation (2 spaces per level is common GitHub Actions style; follow whatever style the file already uses).

    **Job 1 — `route-registry-parity`:**
    ```yaml
      route-registry-parity:
        name: Route registry parity
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: actions/setup-python@v5
            with:
              python-version: "3.11"
          - name: Run parity lint
            run: python3 tools/checks/route_registry_parity.py
    ```

    **Job 2 — `mint-routes-tests`:**
    ```yaml
      mint-routes-tests:
        name: mint-routes pytest (DRY_RUN)
        runs-on: ubuntu-latest
        env:
          MINT_ROUTES_DRY_RUN: "1"
        steps:
          - uses: actions/checkout@v4
          - uses: actions/setup-python@v5
            with:
              python-version: "3.11"
          - name: Install pytest
            run: pip install pytest
          - name: Run CLI + parity tests
            run: pytest tests/tools/test_mint_routes.py tests/checks/test_route_registry_parity.py -q --tb=short
    ```

    **Job 3 — `admin-build-sanity`:**
    ```yaml
      admin-build-sanity:
        name: Admin build sanity (ENABLE_ADMIN not in prod)
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - name: Scan prod workflows for ENABLE_ADMIN=1
            run: |
              set -euo pipefail
              FOUND=0
              for wf in .github/workflows/testflight.yml .github/workflows/play-store.yml; do
                if [ ! -f "$wf" ]; then
                  echo "[info] $wf not present — skipping"
                  continue
                fi
                if grep -nE "dart-define=ENABLE_ADMIN=1" "$wf"; then
                  echo "::error file=$wf::ENABLE_ADMIN=1 detected in prod build workflow — D-03 tree-shake violated"
                  FOUND=1
                fi
              done
              if [ "$FOUND" -ne 0 ]; then exit 1; fi
              echo "[OK] no ENABLE_ADMIN=1 in prod build workflows"
    ```

    **Job 4 — `cache-gitignore-check`:**
    ```yaml
      cache-gitignore-check:
        name: .cache/ in .gitignore (D-09 §3)
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - name: Verify .cache/ entry
            run: |
              if ! grep -qE "^\.cache/" .gitignore; then
                echo "::error::.cache/ must be gitignored per nLPD D-09 §3 (7-day retention artifact)"
                exit 1
              fi
              echo "[OK] .cache/ is gitignored"
    ```

    **Post-append validation:**
    ```bash
    # Syntax check: install actionlint locally if available, else minimal YAML lint.
    if command -v actionlint >/dev/null 2>&1; then
      actionlint .github/workflows/ci.yml
    else
      python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
    fi
    ```

    **Defensive check that baseline holds BEFORE push:**
    ```bash
    grep -nE "dart-define=ENABLE_ADMIN=1" .github/workflows/testflight.yml .github/workflows/play-store.yml || echo "baseline clean"
    ```
    If the grep finds occurrences, STOP — ENABLE_ADMIN=1 is already in prod, the CI job will fail the first push. That means a pre-existing leak — escalate to Julien before fixing.

    Commit: `ci(32-05): add route-registry-parity + mint-routes-tests + admin-build-sanity + cache-gitignore-check jobs`.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/ci.yml')); jobs=set(d.get('jobs',{}).keys()); required={'route-registry-parity','mint-routes-tests','admin-build-sanity','cache-gitignore-check'}; missing=required-jobs; assert not missing, f'missing jobs: {missing}'; print('OK 4 jobs added')"</automated>
  </verify>
  <acceptance_criteria>
    - `.github/workflows/ci.yml` is valid YAML (parses with `yaml.safe_load`)
    - `ci.yml` jobs dictionary contains all 4 job keys: route-registry-parity, mint-routes-tests, admin-build-sanity, cache-gitignore-check
    - `grep -c "python3 tools/checks/route_registry_parity.py" .github/workflows/ci.yml` returns ≥1
    - `grep -c "MINT_ROUTES_DRY_RUN" .github/workflows/ci.yml` returns ≥1
    - `grep -c "dart-define=ENABLE_ADMIN=1" .github/workflows/ci.yml` returns ≥1 (the defensive scan uses this literal)
    - Baseline clean: `grep -E "dart-define=ENABLE_ADMIN=1" .github/workflows/testflight.yml .github/workflows/play-store.yml` returns nothing
  </acceptance_criteria>
  <done>4 CI jobs wired. They will run on next push of the feature branch PR.</done>
</task>

<task type="auto">
  <name>Task 2: Ship docs/SETUP-MINT-ROUTES.md + README link + walker.sh admin-routes scenario</name>
  <files>docs/SETUP-MINT-ROUTES.md, README.md, tools/simulator/walker.sh</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-09 (nLPD controls — scope + Keychain hardening)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §6 nLPD controls + §Environment Availability (lines 718-740, 1036-1052)
    - /Users/julienbattaglia/Desktop/MINT/tools/simulator/walker.sh (current --scenario dispatcher)
    - /Users/julienbattaglia/Desktop/MINT/tools/simulator/sentry_quota_smoke.sh (Keychain pattern docs reference)
    - /Users/julienbattaglia/Desktop/MINT/README.md (structure + existing doc links)
  </read_first>
  <action>
    **File 1 — `docs/SETUP-MINT-ROUTES.md`:**
    ```markdown
    # mint-routes — Operator Setup Guide

    > Phase 32 MAP-02a deliverable. One-time setup for new developers before
    > running `./tools/mint-routes health`. Reused by Phase 35 dogfood loop.

    ## Prerequisites

    - macOS (for Keychain) OR Linux/CI (env var only).
    - Python 3.9+ (3.10+ preferred; CI runs 3.11; dev machine 3.9.6 supported).
    - `sentry-cli` installed (`brew install sentry-cli`) — optional, not required for live queries (CLI uses urllib).

    ## Step 1 — Create a Sentry Auth Token

    1. Open Sentry Web UI → **User Settings** → **Auth Tokens** → **Create New Token**.
    2. Set scopes to **EXACTLY THREE** (nLPD D-09 §1 minimization):
       - `project:read`
       - `event:read`
       - `org:read`  *(optional — needed for `--verify-token` endpoint)*
    3. **DO NOT** grant: `project:write`, `project:admin`, `org:write`, `member:*`.
    4. Copy the token (shown once — Sentry never displays it again).

    ### Why scope minimization matters

    The CLI only reads events. A broader scope would let a stolen token
    delete projects, modify DSNs, or remove members. nLPD Art. 6
    (minimization) + Art. 7 (security) require this discipline.

    ## Step 2 — Store the Token

    ### macOS (recommended)

    Use the Keychain with access-control hardening (`-U` update-or-add, `-A` allow apps):

    ```bash
    security add-generic-password \
      -a "$USER" \
      -s "SENTRY_AUTH_TOKEN" \
      -w "<paste-token-here>" \
      -U -A
    ```

    The CLI reads via `security find-generic-password -s SENTRY_AUTH_TOKEN -w`.
    Phase 31 `sentry_quota_smoke.sh` uses the same service name — no dual setup.

    ### Linux / CI

    Export as an environment variable:

    ```bash
    export SENTRY_AUTH_TOKEN="<paste-token-here>"
    ```

    Do NOT commit the token. Never pass it via argv (CLI uses urllib
    `Authorization` header to avoid `ps auxf` leak).

    ## Step 3 — Verify

    ```bash
    ./tools/mint-routes --verify-token
    ```

    Expected output:
    ```
    [OK] token scopes are within allowed set: ['event:read', 'org:read', 'project:read']
    ```

    If you see a `[FAIL] token has extra scopes` message, recreate the
    token with fewer scopes. Exit code 78 = `EX_CONFIG`.

    If you see `[FAIL] SENTRY_AUTH_TOKEN missing` (exit 71), the env var
    or Keychain entry is not readable — re-run Step 2.

    ## Step 4 — Run a health scan

    ```bash
    ./tools/mint-routes health --json | head
    ```

    Expected: newline-delimited JSON per route, matching
    `apps/mobile/lib/routes/route_health_schema.dart` contract
    (`kRouteHealthSchemaVersion = 1`).

    ## Commands

    | Command | Purpose |
    |---------|---------|
    | `./tools/mint-routes health` | Per-route status (green/yellow/red/dead). |
    | `./tools/mint-routes health --json` | Newline-delimited JSON (Phase 35 dogfood input). |
    | `./tools/mint-routes health --owner=coach` | Filter by RouteOwner enum value. |
    | `./tools/mint-routes redirects` | Aggregate 43 legacy redirect breadcrumb hits over 30 days. |
    | `./tools/mint-routes reconcile` | Run `tools/checks/route_registry_parity.py`. |
    | `./tools/mint-routes purge-cache` | Wipe `.cache/route-health.json` (D-09 §3 emergency). |
    | `./tools/mint-routes --verify-token` | Validate token scope (nLPD D-09 §1). |

    ## Environment Variables

    | Variable | Purpose |
    |----------|---------|
    | `SENTRY_AUTH_TOKEN` | Wins over Keychain; required on CI / non-macOS. |
    | `MINT_ROUTES_DRY_RUN=1` | Read `tests/tools/fixtures/sentry_health_response.json` (no network). |
    | `NO_COLOR=1` | Suppress ANSI codes (no-color.org). |
    | `SENTRY_ORG` | Override organization slug (default `mint`). |
    | `MINT_ROUTES_CACHE_DIR` | Override `.cache/` location (default `~/.cache/mint/`). |

    ## nLPD / Swiss Data Protection

    - **Token scope locked** (D-09 §1): read-only.
    - **PII redaction layer** (D-09 §2): CLI strips IBAN, CHF>100, email,
      AVS, user.{id,email,ip_address,username} from Sentry responses
      BEFORE any display or JSON emission. Metadata fields
      `_redaction_applied: true, _redaction_version: 1` on every JSON line.
    - **Cache retention 7 days** (D-09 §3): `.cache/route-health.json`
      auto-deletes on CLI startup when older than 7 days. `.gitignore`
      includes `.cache/` (CI `cache-gitignore-check` job enforces).
      Emergency wipe: `./tools/mint-routes purge-cache`.
    - **Admin access log** (D-09 §4): `/admin/routes` screen mount emits
      `mint.admin.routes.viewed` breadcrumb with aggregates only
      (route_count, feature_flags_enabled_count). Zero PII.
    - **Keychain hardening** (D-09 §5): Store with `-U -A` flags.

    ## Troubleshooting

    | Symptom | Fix |
    |---------|-----|
    | `[FAIL] SENTRY_AUTH_TOKEN missing` (exit 71) | Re-run Step 2; or `export SENTRY_AUTH_TOKEN=…` for non-macOS. |
    | `[FAIL] token has extra scopes` (exit 78) | Recreate token with fewer scopes per Step 1. |
    | `[FAIL] Sentry auth error 401/403` (exit 78) | Token expired or scope missing `event:read`. |
    | `[FAIL] network error` (exit 75) | Temporary network blip — retry. |
    | 0 routes in output with `health --owner=X` | Owner enum value typo; check `apps/mobile/lib/routes/route_owner.dart`. |
    | CLI exits instantly with 2 | `argparse` usage error — re-run with `--help`. |

    ## Integration Points

    - **Phase 35 dogfood** consumes `./tools/mint-routes health --json`
      per `route_health_schema.dart` contract. Schema bumps break
      Phase 35 — check `kRouteHealthSchemaVersion`.
    - **Phase 36 FIX prioritization** reads `health` terminal output to
      rank P0 fixes.
    - **CI job** `mint-routes-tests` runs `pytest tests/tools/test_mint_routes.py -q`
      in DRY_RUN mode (no token required).

    ## Further Reading

    - `.planning/phases/32-cartographier/32-CONTEXT.md` — 12 locked decisions.
    - `.planning/phases/32-cartographier/32-RESEARCH.md` — implementation findings.
    - `tools/checks/route_registry_parity-KNOWN-MISSES.md` — regex-unparsable route patterns.
    ```

    Accent + banned-terms discipline: docs are in technical English; no banned LSFin terms. The phrase "recommended" is acceptable (not in the banned list). Avoid any FR user-facing prose — this is developer documentation.

    **File 2 — Append to `README.md`:**

    Locate the existing documentation links section (likely a `## Documentation` or `## Links` heading). If such a section exists, append:
    ```markdown
    - [mint-routes CLI setup](docs/SETUP-MINT-ROUTES.md) — Keychain + Sentry token scope for Phase 32 route registry tool
    ```

    If no such section exists, add one under `## Developer Tools` at the file's logical tools index position. Minimal addition:
    ```markdown

    ## Developer Tools

    - **mint-routes** — route registry health CLI. See [docs/SETUP-MINT-ROUTES.md](docs/SETUP-MINT-ROUTES.md).
    ```

    **File 3 — Add `admin-routes` scenario to `tools/simulator/walker.sh`:**

    Read the current walker.sh to find the `--scenario=` dispatcher. Add a new branch. Example skeleton (adapt to the existing case/if structure):
    ```bash
    # Phase 32 MAP-02b — admin-routes smoke scenario
    scenario_admin_routes() {
      local OUT_DIR=".planning/phases/32-cartographier/screenshots/walker-$(date +%Y-%m-%d)"
      mkdir -p "$OUT_DIR"

      log "[admin-routes] building sim with --dart-define=ENABLE_ADMIN=1"
      (cd apps/mobile && to 180s flutter build ios --simulator --debug \
        --dart-define=ENABLE_ADMIN=1 \
        --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1) \
        || { log "[FAIL] build failed"; return 1; }

      log "[admin-routes] installing on booted sim"
      to 60s xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app \
        || { log "[FAIL] install failed"; return 1; }

      log "[admin-routes] launching app"
      to 30s xcrun simctl launch --console-pty booted ch.mint.mobile &
      local PID=$!
      sleep 8

      log "[admin-routes] opening /admin/routes deep link"
      to 15s xcrun simctl openurl booted "mint://admin/routes" \
        || log "[WARN] deep link failed; trying navigation fallback"

      for i in 1 2 3 4 5; do
        sleep 2
        local SHOT="$OUT_DIR/admin-routes-$i.png"
        xcrun simctl io booted screenshot "$SHOT" || log "[WARN] screenshot $i failed"
        log "[admin-routes] captured $SHOT"
      done

      # Cleanup
      kill $PID 2>/dev/null || true

      log "[admin-routes] done. screenshots at $OUT_DIR"
      ls -la "$OUT_DIR"
    }
    ```

    Wire into dispatcher (existing pattern — add `"admin-routes") scenario_admin_routes ;;` branch in the case statement).

    **Do NOT run the scenario here** — execution is part of Task 3 J0 Task 6. This task only ships the script.

    Commit: `feat(32-05): SETUP-MINT-ROUTES.md + README link + walker.sh admin-routes scenario`.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && test -f docs/SETUP-MINT-ROUTES.md && grep -qc "SENTRY_AUTH_TOKEN" docs/SETUP-MINT-ROUTES.md && grep -qc "nLPD" docs/SETUP-MINT-ROUTES.md && grep -qc "SETUP-MINT-ROUTES" README.md && grep -qc "admin-routes" tools/simulator/walker.sh && echo OK</automated>
  </verify>
  <acceptance_criteria>
    - `docs/SETUP-MINT-ROUTES.md` exists AND mentions `SENTRY_AUTH_TOKEN`, `nLPD`, `security add-generic-password`, `kRouteHealthSchemaVersion`, `--verify-token`, `purge-cache`
    - `README.md` contains a link to `docs/SETUP-MINT-ROUTES.md`
    - `tools/simulator/walker.sh` contains the literal `admin-routes` (scenario added)
    - `tools/simulator/walker.sh` is still executable (`test -x`) and passes shellcheck if shellcheck available
    - No banned LSFin terms in SETUP-MINT-ROUTES.md (`grep -iE "garanti|optimal|meilleur|certain|sans risque|parfait" docs/SETUP-MINT-ROUTES.md` returns nothing)
  </acceptance_criteria>
  <done>Docs + README + walker scenario ready. Task 3 executes J0 gates.</done>
</task>

<task type="auto">
  <name>Task 3: Execute 6 J0 empirical gates + flip 32-VALIDATION.md nyquist_compliant: true</name>
  <files>.planning/phases/32-cartographier/32-VALIDATION.md</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-VALIDATION.md (J0 tasks + frontmatter to flip)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-11 (6 J0 gates)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/routes/route_metadata.dart (Plan 01 output — tree-shake target)
    - /Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity.py (Plan 04 output — J0 Task 4)
    - /Users/julienbattaglia/Desktop/MINT/tools/mint-routes (Plan 02 output — J0 Tasks 3 + 5)
    - /Users/julienbattaglia/Desktop/MINT/tools/simulator/walker.sh (Task 2 output — J0 Task 6)
  </read_first>
  <action>
    Run the 6 J0 gates. Each has a specific command + pass criterion. Capture output, then update `32-VALIDATION.md` with per-task status.

    ### J0 Task 1 — Tree-shake verification

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
    flutter clean  # clean prior builds to avoid stale
    flutter build ios --simulator --release --no-codesign \
      --dart-define=ENABLE_ADMIN=0 \
      --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 2>&1 | tail -20

    # Primary check: symbol name absent
    GREP_SYMBOL=$(strings build/ios/iphonesimulator/Runner.app/Runner 2>/dev/null | grep -c "kRouteRegistry" || true)
    echo "kRouteRegistry occurrences: $GREP_SYMBOL"

    # Dual check (A6/A7 mitigation): a unique route description string from registry
    GREP_UNIQUE=$(strings build/ios/iphonesimulator/Runner.app/Runner 2>/dev/null | grep -c "Retirement scenarios hub" || true)
    echo "unique description occurrences: $GREP_UNIQUE"
    ```

    Pass criterion: `GREP_SYMBOL == 0` AND `GREP_UNIQUE == 0`.
    Fail action: tree-shake broken → escalate to user with the build log (likely cause: a non-admin consumer imports `kRouteRegistry`; grep `apps/mobile/lib/` for `kRouteRegistry` references outside `screens/admin/`).

    **If Flutter build fails due to CocoaPods or codesign issues on the operator's machine, skip this gate and record "MANUAL — operator must run on build machine". Do NOT skip silently — document the skip in 32-VALIDATION.md with operator name + date.**

    ### J0 Task 2 — SentryNavigatorObserver smoke (M-4 strict 3-branch fail hierarchy)

    This requires staging DSN + a real simulator launch + 60s ingest wait. Steps:

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
    flutter build ios --simulator --release --no-codesign \
      --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
      --dart-define=SENTRY_DSN=$SENTRY_DSN_MOBILE_STAGING
    xcrun simctl install booted build/ios/iphonesimulator/Runner.app

    # Manually trigger navigation (simctl openurl) on 3 routes and force error injection.
    # For now, use existing walker.sh --smoke-test-inject-error which fires errors on landing/auth routes.
    cd /Users/julienbattaglia/Desktop/MINT
    bash tools/simulator/walker.sh --smoke-test-inject-error 2>&1 | tail -10

    sleep 60  # ingest wait
    # Query the 3 routes via CLI (live mode — requires SENTRY_AUTH_TOKEN available)
    ./tools/mint-routes health --json | python3 -c "
    import sys, json
    found = {'/coach': 0, '/budget': 0, '/scan': 0}  # NOTE: walker fires on / + /auth/*; adapt expected paths
    # TODO: align expected paths with walker's actual error-injection targets
    for line in sys.stdin:
        row = json.loads(line)
        if row['sentry_count_24h'] > 0 and row['path'] in found:
            found[row['path']] += 1
    print('Found routes with events:', found)
    "
    ```

    **M-4 fix — 3-branch fail hierarchy (PASS / FAIL / BLOCKED). NO "soft defer". D-11 §Task 2 is a real gate; the previous "defer to operator walkthrough. Do not block the entire phase." wording is removed.**

    The D-09 §Task 2 strictness + VALIDATION.md "Failure → explicit P0, not 'acceptable'" doctrine produces three and only three outcomes for J0 Task 2. Choose exactly ONE at execution time and record it in VALIDATION.md.

    #### Outcome A — PASS
    **Criterion:** At least one route shows `sentry_count_24h > 0` AND the raw Sentry Issues API response's `transaction.name` field matches the route path (e.g., `/coach`, `/budget`).

    **Action:**
    1. Flip `32-VALIDATION.md` frontmatter `nyquist_compliant: true` (assuming the other 5 gates are also PASS or BLOCKED-acceptable per their own rules).
    2. Update §J0 Empirical Results table row 2 to `PASS` with raw response snippet as evidence.
    3. Green-light Phase 32 ship.

    #### Outcome B — FAIL (empirical)
    **Criterion:** Build + simctl install + walker error injection all succeeded, 60s ingest elapsed, Sentry returned a response, BUT `transaction.name` is `null` / internal span name / anything other than the route path.

    **Action:**
    1. **STOP Phase 32 ship.** Do NOT flip `nyquist_compliant: true`.
    2. Escalate to Julien verbatim: "SentryNavigatorObserver D-07 contract unverified. Phase 31 retroactive `scope.setTag('route', ...)` patch required (2-4h scope). Proceed with patch OR ship Phase 32 without CLI live health (Phase 32 degrades to registry + schema viewer only, defer CLI live health to a follow-up phase)."
    3. In `32-VALIDATION.md` §J0 Empirical Results row 2: `FAIL`. Append §Risks entry:
       ```markdown
       ### RISK — SentryNavigatorObserver transaction.name not auto-set [P0 BLOCKER for ship]
       - J0 Task 2 FAIL: {date}. Evidence: {raw Sentry response snippet showing transaction.name=null}.
       - Remediation options:
         A) Phase 31 retroactive patch: wire `scope.setTag('route', …)` in GoRouter redirect observer (2-4h). Blocks Phase 32 ship until landed.
         B) Ship Phase 32 degraded: registry + schema viewer only. CLI `./tools/mint-routes health` disabled. Re-enable in a follow-up phase after Phase 31 patch.
       - Awaiting Julien decision.
       ```
    4. Record `nyquist_compliant: false` until user picks A or B AND the selected path is executed.

    #### Outcome C — BLOCKED (environmental)
    **Criterion:** Cannot execute the empirical test on the current operator machine — specifically:
    - `SENTRY_AUTH_TOKEN` unavailable (no staging token on operator machine), OR
    - `SENTRY_DSN_MOBILE_STAGING` env var unset, OR
    - Simulator build failed for infra reasons (CocoaPods, codesign, Xcode version), OR
    - walker.sh `--smoke-test-inject-error` scenario missing / broken on operator machine.

    **Action (stricter than previous "acceptable" phrasing):**
    1. Do NOT flip `nyquist_compliant: true`. It STAYS `false`.
    2. Update `32-VALIDATION.md` §J0 Empirical Results row 2 to `BLOCKED — {specific reason}` with operator name + date.
    3. Append §Risks entry:
       ```markdown
       ### RISK — J0 Task 2 BLOCKED (D-11 contract unverified) [requires Julien acknowledgment]
       - Operator: {name}. Date: {YYYY-MM-DD}. Reason: {missing staging credentials | build infra | walker missing}.
       - Phase 32 ship is NOT automatically approved. Julien must explicitly acknowledge the `nyquist_compliant: false` state and choose ONE:
         A) Arrange staging credentials + machine that can run the test; re-run J0 Task 2 to convert BLOCKED → PASS/FAIL.
         B) Accept the BLOCKED state and ship with a documented known-unknown; future phase will re-verify.
       - CLI fallback: `./tools/mint-routes health --owner=X` sequential mode still works (does not rely on auto-named transactions).
       ```
    4. The Phase 32 ship gate requires Julien to sign off on the `nyquist_compliant: false` state with the BLOCKED entry visible in §Risks.

    ### J0 Task 3 — Batch OR-query empirical limit

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT
    # Use the CLI's own probing. Exposure via a temporary helper:
    python3 -c "
    from tools.mint_routes.sentry_client import _build_batch_query, _call_sentry_issues, get_sentry_token
    paths = [f'/probe{i}' for i in range(30)]
    q = _build_batch_query(paths)
    print(f'Query length: {len(q)} chars')
    try:
        token = get_sentry_token()
        r = _call_sentry_issues(q, token=token, stats_period='24h')
        print(f'OK 30-term batch accepted. Top-level keys: {list(r.keys()) if isinstance(r, dict) else type(r)}')
    except SystemExit as e:
        print(f'FAIL exit={e.code} — batch size may be too large or token missing')
    " 2>&1 | tail -10
    ```

    Pass criterion: 30-term batch accepted (2xx response, no 414).
    Fail action: halve batch size (15, 8, 4, 2) until success; document the empirical limit in 32-VALIDATION.md AND update `tools/mint_routes/cli.py` argparse default (`--batch-size` default changed from 30 to empirical value).

    **If Sentry token not available, record "BLOCKED — requires staging token". CLI fallback to sequential 1-req/sec (3 min full scan) still works.**

    ### J0 Task 4 — Parity lint local run

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT
    python3 tools/checks/route_registry_parity.py 2>&1 | tail -5
    echo "Exit: $?"
    ```

    Pass criterion: exit 0 + stdout contains `routes parity OK`.
    Fail action: Plan 01 or Plan 03 regressed — investigate drift using stderr diff output.

    ### J0 Task 5 — CLI DRY_RUN pytest

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT
    MINT_ROUTES_DRY_RUN=1 python3 -m pytest tests/tools/test_mint_routes.py tests/checks/test_route_registry_parity.py -q 2>&1 | tail -10
    echo "Exit: $?"
    ```

    Pass criterion: exit 0; ≥14 tests passed (Plan 02) + ≥6 tests (Plan 04).
    Fail action: unit test regression — investigate.

    ### J0 Task 6 — walker.sh admin-routes smoke

    ```bash
    cd /Users/julienbattaglia/Desktop/MINT
    bash tools/simulator/walker.sh --scenario=admin-routes 2>&1 | tail -30
    ls -la .planning/phases/32-cartographier/screenshots/walker-$(date +%Y-%m-%d)/ 2>/dev/null | head
    ```

    Pass criterion: ≥5 screenshots captured at the expected path; no crash in walker log; `mint.admin.routes.viewed` breadcrumb visible in Sentry web UI (manual check, record outcome).
    Fail action: if simulator crash or RSoD (Red Screen of Death), **STOP autonomous flow per feedback_tests_green_app_broken** and report to Julien — do NOT self-patch L3 creator-device regressions.

    **If operator machine lacks iPhone 17 Pro simulator runtime**, record "BLOCKED — sim runtime missing on operator machine; deferred to creator device walkthrough". This is acceptable per ADR-20260419-autonomous-profile-tiered (L3 partial for this sub-task).

    ### Update `32-VALIDATION.md`

    For each J0 task, update the per-task status and append an appendix. Use the Edit tool on `32-VALIDATION.md` to change:

    1. Frontmatter line `nyquist_compliant: false` → `nyquist_compliant: true` (only if ALL 6 tasks are either PASS or documented-BLOCKED-with-acceptable-fallback; **per M-4 J0 Task 2 FAIL OR BLOCKED keeps `nyquist_compliant: false` and requires Julien acknowledgment**).
    2. Frontmatter line `wave_0_complete: false` → `wave_0_complete: true` (Wave 0 landed in Plan 00).
    3. Per-Task Verification Map status column: flip `⬜ pending` to `✅ green`, `❌ red`, or `⚠️ flaky`.
    4. Append section `## J0 Empirical Results (YYYY-MM-DD)`:
       ```markdown
       ## J0 Empirical Results — {YYYY-MM-DD}

       | Task | Status | Evidence | Notes |
       |------|--------|----------|-------|
       | 1 Tree-shake | PASS | kRouteRegistry=0, unique=0 | Confirmed on dev machine |
       | 2 SentryNavigatorObserver | PASS / FAIL / BLOCKED | {details — which of the 3 M-4 outcomes} | {if FAIL: §Risks entry reference; if BLOCKED: acknowledgment status} |
       | 3 Batch OR-query ≥30 | PASS/BLOCKED | {empirical batch size} | {fallback note if BLOCKED} |
       | 4 Parity lint | PASS | exit 0 | 147 routes parity OK |
       | 5 DRY_RUN pytest | PASS | 20/20 tests green | {Plan 02 + Plan 04 combined} |
       | 6 walker.sh smoke | PASS/BLOCKED | {screenshot count} | {creator-device status} |

       Verdict: {GREEN — ship ready} / {AMBER — ship with documented deferrals + Julien acknowledgment of nyquist_compliant: false} / {RED — block ship, escalate}
       ```

    Commit: `chore(32-05): execute J0 empirical gates + flip VALIDATION nyquist_compliant`.

    **No production code changes in this task** — only J0 execution + VALIDATION.md edits.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 tools/checks/route_registry_parity.py 2>&1 | tail -2 && MINT_ROUTES_DRY_RUN=1 python3 -m pytest tests/tools/test_mint_routes.py tests/checks/test_route_registry_parity.py -q 2>&1 | tail -5 && grep -E "nyquist_compliant|wave_0_complete" /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-VALIDATION.md | head -5</automated>
  </verify>
  <acceptance_criteria>
    - `32-VALIDATION.md` frontmatter has `wave_0_complete: true` (unconditional — Wave 0 landed via Plan 00)
    - `32-VALIDATION.md` frontmatter has `nyquist_compliant: true` IF AND ONLY IF J0 Task 2 is PASS AND all other tasks PASS or BLOCKED-acceptable; otherwise stays `false` with explicit §Risks entry per M-4
    - `32-VALIDATION.md` has a `## J0 Empirical Results — YYYY-MM-DD` section with a table of all 6 tasks
    - **M-4 fix**: J0 Task 2 row status is exactly one of `PASS`, `FAIL`, or `BLOCKED` (no "soft defer" or "acceptable" wording)
    - **M-4 fix**: If J0 Task 2 is FAIL → `32-VALIDATION.md §Risks` contains the P0 BLOCKER entry with the A/B remediation options, AND `nyquist_compliant: false`
    - **M-4 fix**: If J0 Task 2 is BLOCKED → `32-VALIDATION.md §Risks` contains the BLOCKED entry awaiting Julien acknowledgment, AND `nyquist_compliant: false`
    - J0 Task 4 (parity lint) is unambiguously PASS (deterministic — no environment dependency)
    - J0 Task 5 (DRY_RUN pytest) is unambiguously PASS (deterministic)
    - J0 Tasks 1, 3, 6 have either PASS or BLOCKED-with-fallback documented; no silent skips
  </acceptance_criteria>
  <done>6 J0 gates executed. VALIDATION.md reflects reality per the M-4 strict 3-branch hierarchy for Task 2. Phase ready for `/gsd-verify-work` (GREEN) or escalated to Julien for acknowledgment (AMBER) or blocked (RED).</done>
</task>

</tasks>

<verification>
End-of-plan gate (phase ship-ready after this):
- CI jobs defined in `ci.yml` (YAML valid; 4 jobs present).
- Docs shipped, README linked.
- walker.sh has admin-routes scenario.
- 6 J0 gates executed with verdict documented; J0 Task 2 has explicit PASS/FAIL/BLOCKED (not "soft defer").
- `32-VALIDATION.md` frontmatter updated (`wave_0_complete: true`, `nyquist_compliant: true/false` per empirical results with Julien acknowledgment if amber).
- No unchecked J0 task.

Git: three small commits (CI jobs / docs+walker / VALIDATION) OR one combined commit at operator discretion.
</verification>

<success_criteria>
- D-12 §1-3 + §5 CI jobs wired (route-registry-parity, mint-routes-tests, admin-build-sanity, cache-gitignore-check)
- D-09 operator playbook shipped (`docs/SETUP-MINT-ROUTES.md`)
- walker.sh supports `--scenario=admin-routes` (L3 partial creator-device gate)
- All 6 D-11 J0 empirical gates have explicit PASS / BLOCKED / FAIL verdicts documented in `32-VALIDATION.md`
- J0 Task 2 uses strict 3-branch fail hierarchy per M-4 — no "soft defer" language
- `nyquist_compliant: true` flipped only when evidence supports it (no blanket green-washing); `false` persists with explicit §Risks entry otherwise
</success_criteria>

<output>
After completion, create `.planning/phases/32-cartographier/32-05-SUMMARY.md` with:
- CI jobs added (names + purpose)
- SETUP-MINT-ROUTES.md section summary
- walker.sh admin-routes scenario invocation
- J0 results table (6 tasks × verdict × evidence) — J0 Task 2 explicit PASS/FAIL/BLOCKED per M-4
- 32-VALIDATION.md frontmatter final state + §Risks acknowledgment status (if amber)
- Commit SHAs
- Phase 32 ship readiness (green / amber / red)
- Unblocks: `/gsd-verify-work 32` can run
</output>
</content>
