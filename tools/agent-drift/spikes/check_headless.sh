#!/usr/bin/env bash
# A7 spike (30.5-RESEARCH.md §Assumptions Log): validates `claude --headless`
# availability for metric (d) golden prompts harness.
#
# HIGH RISK if the CLI has no non-interactive mode — metric (d) must then run
# on-demand (Julien manual batch once per baseline), NOT nightly cron. This
# spike always exits 0; the diagnostic is the result file content.
#
# Output: tools/agent-drift/spikes/A7_headless_result.txt with one of:
#   AVAILABLE               — headless/eval/print/oneshot mode found
#   FALLBACK_ON_DEMAND      — claude CLI present but no non-interactive mode
#   NOT_AVAILABLE           — claude CLI not found on PATH

set -e
OUT="tools/agent-drift/spikes/A7_headless_result.txt"
mkdir -p "$(dirname "$OUT")"

if ! command -v claude >/dev/null 2>&1; then
  echo "A7: claude CLI NOT FOUND in PATH — metric (d) must be manual/deferred. Documenting fallback."
  echo "A7: NOT_AVAILABLE (no claude CLI)" > "$OUT"
  exit 0
fi

HELP=$(claude --help 2>&1 || true)
MODES=$(echo "$HELP" | grep -iE 'headless|--print|-p |oneshot|eval' || true)

if [ -n "$MODES" ]; then
  echo "A7: AVAILABLE — modes detected:"
  echo "$MODES"
  echo "A7: AVAILABLE" > "$OUT"
  echo "$MODES" >> "$OUT"
else
  echo "A7: FALLBACK REQUIRED — no headless/eval/print mode found in claude --help."
  echo "    → metric (d) runs on-demand only (Julien batch manually once per baseline capture)."
  echo "    → documented in 30.5-RESEARCH.md §Environment Availability."
  echo "A7: FALLBACK_ON_DEMAND" > "$OUT"
fi
exit 0
