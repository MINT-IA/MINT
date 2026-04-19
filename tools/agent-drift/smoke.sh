#!/usr/bin/env bash
# Phase-gate smoke: pytest + node tests in one shot (CTX-02 verification harness).
# Wave 0 stubs must all collect cleanly (skipped tests OK).
set -e
python3 -m pytest tools/agent-drift/tests/ -q
# Node v22 test runner requires explicit file glob (directory form requires v24+).
node --test .claude/hooks/tests/*.mjs
echo "smoke: OK"
