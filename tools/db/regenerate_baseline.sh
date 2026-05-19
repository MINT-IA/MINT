#!/usr/bin/env bash
# Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-23) — regenerate the
# pg_dump baseline snapshot from an isolated Postgres testcontainer.
#
# Usage : bash tools/db/regenerate_baseline.sh
#
# Output : tools/db/baseline_snapshot_2026-05-18.sql (schema-only, no owner, no privs)
#
# Reproducibility contract : running this script twice on the same alembic chain
# yields `git diff --exit-code` exit 0. NOTE : the 2026-05-18 stamp is the
# pre-Phase-02-schema baseline ; Plan 02-02 will REGENERATE this file once p98
# ships (do NOT rename across regenerations, this is the stable historical anchor).
#
# Requirements : Docker daemon reachable, python3 + alembic + psycopg2 installed
# (already in services/backend pyproject `dependencies`).
#
# Pre-existing dual-head condition (DEFERRED-02-01-A) : the script runs
# `alembic upgrade heads` (plural) so both `p112_audit_event_user_hash` and
# `p86_eclairage_delivered` chains land in the dump.

set -euo pipefail

# Resolve repo root from the script's own location (no cwd assumption).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKEND_DIR="$REPO_ROOT/services/backend"
OUT_FILE="$REPO_ROOT/tools/db/baseline_snapshot_2026-05-18.sql"

echo "[regenerate_baseline] repo_root=$REPO_ROOT"
echo "[regenerate_baseline] backend_dir=$BACKEND_DIR"
echo "[regenerate_baseline] out_file=$OUT_FILE"

# 1. Docker available?
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon unreachable. Cannot spin Postgres testcontainer." >&2
  echo "       (CI runners ship Docker pre-installed ; local dev needs Docker Desktop.)" >&2
  exit 1
fi

# 2. pg_dump available?
if ! command -v pg_dump >/dev/null 2>&1; then
  echo "ERROR: pg_dump not on PATH. Install postgresql-client (brew install libpq) or run inside Docker." >&2
  exit 1
fi

# 3. Spin a Postgres 15.5 container, get alembic to upgrade, pg_dump, tear down.
CONTAINER_NAME="mint-baseline-regen-$$"
PG_PASSWORD="baseline_regen_pwd"
PG_PORT="55432"

echo "[regenerate_baseline] starting postgres:15.5 container '$CONTAINER_NAME' on port $PG_PORT..."
docker run -d --name "$CONTAINER_NAME" \
  -e POSTGRES_PASSWORD="$PG_PASSWORD" \
  -e POSTGRES_DB=baseline \
  -p "$PG_PORT:5432" \
  postgres:15.5 >/dev/null

# Trap to ensure container is always cleaned up.
trap 'echo "[regenerate_baseline] tearing down container $CONTAINER_NAME..."; docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true' EXIT

# 4. Wait for Postgres to be ready (max 30s).
DB_URL="postgresql+psycopg2://postgres:${PG_PASSWORD}@localhost:${PG_PORT}/baseline"
echo "[regenerate_baseline] waiting for postgres readiness..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" pg_isready -U postgres -d baseline >/dev/null 2>&1; then
    echo "[regenerate_baseline] postgres ready after ${i}s"
    break
  fi
  sleep 1
  if [[ "$i" == "30" ]]; then
    echo "ERROR: postgres failed to start within 30s." >&2
    exit 1
  fi
done

# 5. Run alembic upgrade heads (plural — dual-head condition).
cd "$BACKEND_DIR"
echo "[regenerate_baseline] running alembic upgrade heads..."
SQLALCHEMY_URL="$DB_URL" python3 -c "
import os
from alembic.config import Config
from alembic import command
cfg = Config('alembic.ini')
cfg.set_main_option('sqlalchemy.url', os.environ['SQLALCHEMY_URL'])
command.upgrade(cfg, 'heads')
"

# 6. pg_dump schema-only, no owner, no privs.
echo "[regenerate_baseline] running pg_dump --schema-only..."
PSQL_URL="postgresql://postgres:${PG_PASSWORD}@localhost:${PG_PORT}/baseline"
pg_dump --schema-only --no-owner --no-privileges "$PSQL_URL" > "$OUT_FILE"

# 7. Strip non-deterministic comments (server version banner) to keep reproducibility.
# pg_dump emits `-- Dumped from database version 15.5 (...)` — that's stable per image pin.
# It also emits `-- Dumped by pg_dump version ...` which DRIFTS with client version on host.
# Mask the client version line to keep the file diff-stable across hosts.
sed -i.bak -E 's|^(-- Dumped by pg_dump version) .*$|\1 <masked-for-reproducibility>|' "$OUT_FILE"
rm -f "$OUT_FILE.bak"

# 8. Print the alembic heads as a sanity-check trailer.
echo ""
echo "[regenerate_baseline] alembic heads in this baseline :"
SQLALCHEMY_URL="$DB_URL" python3 -c "
import os
from alembic.config import Config
from alembic.script import ScriptDirectory
cfg = Config('alembic.ini')
s = ScriptDirectory.from_config(cfg)
for h in s.get_heads():
    print('  ' + h)
"

echo ""
echo "[regenerate_baseline] OK — wrote $(wc -l < "$OUT_FILE") lines to $OUT_FILE"
