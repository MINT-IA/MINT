#!/usr/bin/env bash
# Phase mint-data-architecture-v1-02 W0 Plan 02-01 — iter-2 Tier-B B13
# (postgres-pro MED) : probe Railway-staging Postgres major.minor version.
#
# Output shape :
#   railway:<MAJOR>.<MINOR>     when STAGING_DATABASE_URL is set + psql succeeds
#   default:15.5                when STAGING_DATABASE_URL is unset (silent fallback,
#                               prints WARN to stderr so the fallback isn't silent)
#
# Consumed by `services/backend/tests/fixtures/pg_fixture.py::_probe_pg_version`
# to dynamically pin the testcontainers PG image so local dev + CI track Railway.

set -euo pipefail

if [[ -z "${STAGING_DATABASE_URL:-}" ]]; then
  echo "WARN: STAGING_DATABASE_URL unset, defaulting to 15.5" >&2
  echo "default:15.5"
  exit 0
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "WARN: psql binary not on PATH, defaulting to 15.5" >&2
  echo "default:15.5"
  exit 0
fi

# Query Railway PG. `current_setting('server_version')` returns e.g. "15.5 (Debian 15.5-1.pgdg120+1)".
# Take the first 8 chars + strip whitespace to get the MAJOR.MINOR (or MAJOR.MINOR.PATCH if short).
VER=$(psql "$STAGING_DATABASE_URL" -tAc "SELECT current_setting('server_version')" 2>/dev/null | head -c8 | tr -d ' \n' || true)

if [[ -z "$VER" ]]; then
  echo "WARN: psql query failed against STAGING_DATABASE_URL, defaulting to 15.5" >&2
  echo "default:15.5"
  exit 0
fi

# Extract just MAJOR.MINOR (drop any trailing chars).
MAJOR_MINOR=$(echo "$VER" | grep -oE '^[0-9]+\.[0-9]+' || true)
if [[ -z "$MAJOR_MINOR" ]]; then
  echo "WARN: malformed PG version '$VER', defaulting to 15.5" >&2
  echo "default:15.5"
  exit 0
fi

echo "railway:${MAJOR_MINOR}"
