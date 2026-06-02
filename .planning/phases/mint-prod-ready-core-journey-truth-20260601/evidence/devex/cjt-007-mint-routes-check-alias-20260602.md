---
id: CJT-007
date: 2026-06-02
status: verified
area: devex-route-tooling
---

# CJT-007 — `mint-routes check` preflight alias

## Finding

`AGENTS.md` tells agents touching a new route to run:

```sh
./tools/mint-routes check
```

The CLI did not expose `check`; it exposed `health`, `redirects`,
`reconcile`, and `purge-cache`. That made the documented route preflight fail
before the route parity guard could run.

## Root Cause

The documentation and CLI drifted. The correct behavior for `check` is local
route registry parity, not Sentry health, because the AGENTS.md row is a route
preflight and must stay network-independent.

## Red Proof

Regression added in `tests/tools/test_mint_routes.py`:

```sh
pytest tests/tools/test_mint_routes.py -q --tb=short
```

Observed before fix:

- Exit code: `1`
- Failing test: `test_check_alias_runs_local_route_parity`
- CLI result: `mint-routes: error: argument command: invalid choice: 'check'`
- `check` returned exit code `2`

## Fix

- Added `check` subcommand in `tools/mint_routes/cli.py`.
- Dispatches `check` to `_cmd_reconcile(args)`.
- Updated wrapper usage in `tools/mint-routes`.

## Green Proof

Focused tests:

```sh
pytest tests/tools/test_mint_routes.py -q --tb=short
```

Result:

- Exit code: `0`
- `15 passed`

Manual CLI:

```sh
MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes check
```

Result:

- Exit code: `0`
- `[OK] 145 routes parity OK (after KNOWN-MISSES exemption).`

Help output:

```sh
./tools/mint-routes --help
```

Result includes:

```text
{health,redirects,reconcile,check,purge-cache}
check               Alias for reconcile; kept for AGENTS.md preflight.
```

Workflow-equivalent suite:

```sh
pytest tests/tools/test_mint_routes.py tests/tools/test_redirect_breadcrumb_coverage.py tests/checks/test_route_registry_parity.py -q --tb=short
```

Result:

- Exit code: `0`
