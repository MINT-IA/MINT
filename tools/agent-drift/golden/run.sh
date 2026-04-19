#!/usr/bin/env bash
# Golden prompts harness runner (CTX-02 metric d — time-to-first-correct-output).
#
# Wave 0: --dry-run prints the prompt count. Wave 1 Plan 01 Task 5 wires
# `claude --headless` (or the fallback documented by the A7 spike).
#
# Per D-11: 20 prompts covering 5 domains (i18n, financial_core, retirement,
# banned terms, read-before-write) — sample representatif des feedback_*
# MEMORY.md entries.
set -e
DRY_RUN=0
if [ "$1" = "--dry-run" ]; then DRY_RUN=1; fi
PROMPTS=tools/agent-drift/golden/prompts.jsonl
test -f "$PROMPTS" || { echo "missing $PROMPTS"; exit 1; }
COUNT=$(wc -l < "$PROMPTS" | tr -d ' ')
echo "golden harness: $COUNT prompts registered"
if [ "$DRY_RUN" = "1" ]; then echo "dry-run OK"; exit 0; fi
echo "TODO Wave 1 Plan 01 Task 5: invoke each prompt via claude --headless (or fallback A7)"
exit 0
