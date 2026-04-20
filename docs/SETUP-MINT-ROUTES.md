# mint-routes — Operator Setup Guide

> Phase 32 MAP-02a deliverable. One-time setup for new developers before
> running `./tools/mint-routes health`. Reused by Phase 35 dogfood loop.

## Prerequisites

- macOS (for Keychain) OR Linux/CI (env var only).
- Python 3.9+ (3.10+ preferred; CI runs 3.11; dev machine 3.9.6 supported).
- `sentry-cli` installed (`brew install sentry-cli`) — optional, not required
  for live queries (CLI uses urllib).

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
