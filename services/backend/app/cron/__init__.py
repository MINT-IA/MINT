"""Cron jobs for Phase 02 Plan 02-03 + later.

This package holds Railway- and GH-Actions-cron-driven entry points that
do not belong to the HTTP request flow. Each module exposes a `main()`
callable so the scheduler can invoke it via `python3 -m app.cron.<name>`.
"""
