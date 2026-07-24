#!/usr/bin/env python3
"""GATE: the ci-gate aggregator must actually gate the compliance jobs.

Audit état-des-lieux 2026-07, cluster T15-F01/F02 (beads MINT_nosync-aoa):
"CI Gate" is the SOLE required status check (scripts/setup-branch-protection.sh),
but its `needs` list omitted `contracts-drift` and `pii-log-gate`, and it
converted `skipped -> success` for every job. Failure mode: contracts-drift
fails -> backend/flutter (which need it) are skipped -> collapsed to success ->
"CI Gate" green -> merge allowed with red contract drift. pii-log-gate's red
never blocked anything.

This check fails (exit 1) unless, in .github/workflows/ci.yml:
  1. `contracts-drift` and `pii-log-gate` appear in ci-gate's `needs`;
  2. the aggregation script reads both results
     (needs.contracts-drift.result / needs.pii-log-gate.result);
  3. the script does NOT collapse contracts-drift skipped->success
     (contracts-drift has no path-filter `if`; a skip is never legitimate);
  4. the final failure condition references both variables.

Text-based on purpose (no yaml dependency in the lefthook environment).
Anti-façade: RED on the pre-fix tree by construction.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CI_YML = REPO_ROOT / ".github" / "workflows" / "ci.yml"

# Compliance jobs that must be wired into the sole required check, mapped to
# the shell variable carrying their result in the aggregation script. EVERY
# entry must appear in needs, be read, AND be tied to the failure predicate
# (Codex review MINT_nosync-aoa: checking the predicate for only one job let
# a mutation silently disconnect pii-log-gate).
REQUIRED_IN_GATE = {
    "contracts-drift": "contracts_drift",
    "pii-log-gate": "pii_log",
    # Audit T15-F03 (cluster enforcement, campagne-A): these compliance jobs
    # were DEFINED in ci.yml but absent from ci-gate's `needs`, so they ran but
    # never blocked a merge ("CI Gate" is the sole required check). Wire them.
    "pg-integration": "pg_integration",
    "truth-in-crypto": "truth_in_crypto",
    "screen-registry-parity": "screen_registry_parity",
    "screen-registry-three-way-parity": "screen_registry_three_way",
    # Campagne-A cluster C: guards served-content fiscal facts (RAG corpus +
    # ARB) against regression of the 2026 values (beads #1010/#1013/#1014/#1015).
    "education-facts": "education_facts",
}
# Jobs with no path-filter `if:` — a skip is never legitimate, so the
# aggregator must not collapse their skipped result to success. (pg-integration
# is NOT here: it has `if: needs.changes.outputs.backend == 'true' || push`, so
# a skip on a mobile/docs-only PR is legitimate and must collapse to success.)
NO_SKIP_COLLAPSE = {
    "contracts-drift": "contracts_drift",
    "truth-in-crypto": "truth_in_crypto",
    "screen-registry-parity": "screen_registry_parity",
    "screen-registry-three-way-parity": "screen_registry_three_way",
    "education-facts": "education_facts",
}


def main() -> int:
    if not CI_YML.exists():
        print(f"ERROR: {CI_YML} not found")
        return 1
    text = CI_YML.read_text(encoding="utf-8")

    # Isolate the ci-gate job block (from `  ci-gate:` to end of file — it is
    # the last job; keep the slice robust by stopping at the next top-level job
    # if one ever gets added after it).
    m = re.search(r"^  ci-gate:\n(.*)", text, re.DOTALL | re.MULTILINE)
    if not m:
        print("ERROR: ci-gate job not found in ci.yml")
        return 1
    block = m.group(1)
    nxt = re.search(r"^  [a-zA-Z0-9_-]+:\s*$", block, re.MULTILINE)
    if nxt:
        block = block[: nxt.start()]

    errors: list[str] = []

    needs_m = re.search(r"needs:\s*\[([^\]]*)\]", block)
    needs = [n.strip() for n in needs_m.group(1).split(",")] if needs_m else []
    for job, var in REQUIRED_IN_GATE.items():
        if job not in needs:
            errors.append(f"ci-gate needs is missing compliance job '{job}'")
        if f"needs.{job}.result" not in block:
            errors.append(f"ci-gate script never reads needs.{job}.result")
        # The variable must be tied to the final failure predicate.
        if not re.search(rf'"\${var}"\s*!=\s*"success"', block):
            errors.append(
                f"ci-gate final condition does not fail on '{job}' != success"
            )

    for job, var in NO_SKIP_COLLAPSE.items():
        if re.search(rf'"\${var}"\s*==\s*"skipped"', block):
            errors.append(
                f"ci-gate collapses skipped->success for '{job}' — it has no "
                "path-filter `if`, a skip is never legitimate (cancelled or "
                "dependency failure must fail the gate)"
            )

    if errors:
        print("CI GATE AGGREGATION — compliance jobs not really gated:")
        for e in errors:
            print(f"  ✗ {e}")
        print(
            "\nFix: add the jobs to ci-gate needs, read their results in the "
            "aggregation script, and fail the gate when they are not success "
            "(audit T15-F01/F02, beads MINT_nosync-aoa)."
        )
        return 1

    print("OK: ci-gate really gates the compliance jobs.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
