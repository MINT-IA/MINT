#!/usr/bin/env bash
# Phase 95 Plan 95-03 / TEST-03 — alembic full-chain check.
#
# Runs against the DATABASE_URL provided by the caller (CI uses Postgres
# 15-alpine sidecar; local dev can pass any Postgres URL pointing at a
# disposable DB, e.g. the testcontainers one). Closes the
# « eclairage_delivered does not exist » class of bug per doctrine
# 2026-05-06 §7 ship-gate item.
#
# Four steps:
#   [1/4] alembic upgrade head      — forward all migrations
#   [2/4] alembic check             — model ↔ migration drift detector
#   [3/4] alembic downgrade base    — exercise every migration's downgrade()
#   [4/4] alembic upgrade head      — idempotency guard
#
# A failure at step [2] means a SQLAlchemy model field exists without a
# matching alembic migration (or vice-versa) — that's the bug we want
# this gate to catch at PR-time, NOT at staging-time.

set -euo pipefail

cd "$(dirname "$0")/../../services/backend"

: "${DATABASE_URL:?DATABASE_URL must be set (Postgres URL — sqlite path will not catch the bugs we care about)}"

echo "[1/4] alembic upgrade head"
alembic upgrade head

echo "[2/4] alembic check (model vs migrations)"
alembic check

echo "[3/4] alembic downgrade base"
alembic downgrade base

echo "[4/4] alembic upgrade head (idempotency)"
alembic upgrade head

echo "alembic full-chain check: OK"
