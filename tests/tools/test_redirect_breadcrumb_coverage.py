"""Phase 32 Wave 3 — per-call-site breadcrumb coverage test.

Parses .planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md
§Redirect Call-Site Inventory and validates each of the 43 redirect
callbacks in apps/mobile/lib/app.dart emits the expected number of
MintBreadcrumbs.legacyRedirectHit calls per the inventory's
redirect_branches column.

Supersedes the fragile `grep -c == 43` total assertion (M-3 checker
finding). The RECONCILE-REPORT inventory is the authoritative contract.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
RECONCILE = REPO_ROOT / ".planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md"
APP_DART = REPO_ROOT / "apps/mobile/lib/app.dart"


def _parse_inventory() -> List[Dict[str, Any]]:
    """Parse RECONCILE-REPORT.md §Redirect Call-Site Inventory table.

    Returns list of 43 dicts, each with: site_no, line, source, targets,
    redirect_branches, null_pass_through.
    """
    if not RECONCILE.exists():
        pytest.skip("RECONCILE-REPORT.md not yet produced (Plan 00 Wave 0 artifact)")
    text = RECONCILE.read_text()
    # Find the §Redirect Call-Site Inventory section, then the pipe table.
    sec = re.search(
        r"##\s+Redirect Call-Site Inventory.*?(?=\n##\s)",
        text,
        flags=re.DOTALL,
    )
    if not sec:
        pytest.fail("Section '## Redirect Call-Site Inventory' not found")
    rows_src = sec.group(0)
    # Inventory rows look like:
    #   | 1 | 531 | `/coach/dashboard` | `/retraite` | 1 | 0 | `(_, __) => '/retraite'` |
    # The source/target columns are wrapped in backticks. Match digits for the
    # site_no + line columns and capture the free-form columns in between.
    row_re = re.compile(
        r"\|\s*(\d+)\s*"                      # site_no
        r"\|\s*(\d+)\s*"                      # line
        r"\|\s*(.+?)\s*"                      # source pattern
        r"\|\s*(.+?)\s*"                      # target(s)
        r"\|\s*(\d+)\s*"                      # redirect_branches
        r"\|\s*(\d+)\s*"                      # null_pass_through
        r"\|"
    )
    rows: List[Dict[str, Any]] = []
    for m in row_re.finditer(rows_src):
        rows.append({
            "site_no": int(m.group(1)),
            "line": int(m.group(2)),
            "source": m.group(3).strip().strip("`"),
            "targets": m.group(4).strip().strip("`"),
            "redirect_branches": int(m.group(5)),
            "null_pass_through": int(m.group(6)),
        })
    return rows


def _extract_callback_body_by_source(src: str, source_path: str) -> str:
    """Extract the callback body for the ScopedGoRoute declaring [source_path].

    RECONCILE-REPORT line numbers are pinned to app.dart SHA b7a88cc8;
    wiring the 43 breadcrumbs shifts every line, so we locate each
    call-site by its source path literal instead. Works for both
    single-line and block-form declarations.
    """
    # Look for ScopedGoRoute(...path: '<source>'...) — capture the smallest
    # enclosing balanced-paren slice. Handles both:
    #   ScopedGoRoute(path: '/x', redirect: (_, state) { ... })
    # and:
    #   ScopedGoRoute(
    #     path: '/x',
    #     scope: RouteScope.onboarding,
    #     redirect: (_, state) { ... },
    #   )
    needle_single = "path: '{0}'".format(source_path)
    needle_double = 'path: "{0}"'.format(source_path)
    idx = src.find(needle_single)
    if idx == -1:
        idx = src.find(needle_double)
    if idx == -1:
        return ""
    # Walk backward to the matching "ScopedGoRoute(" opening paren.
    head = src.rfind("ScopedGoRoute(", 0, idx)
    if head == -1:
        return ""
    # Walk forward from the opening paren, tracking balance.
    depth = 0
    opened = False
    open_paren = src.find("(", head)
    if open_paren == -1:
        return ""
    for i in range(open_paren, min(len(src), open_paren + 4000)):
        ch = src[i]
        if ch == "(":
            depth += 1
            opened = True
        elif ch == ")":
            depth -= 1
            if opened and depth == 0:
                return src[head:i + 1]
    return src[head:min(len(src), head + 4000)]


def test_reconcile_report_lists_43_redirect_sites() -> None:
    rows = _parse_inventory()
    assert len(rows) == 43, (
        "RECONCILE-REPORT inventory should enumerate exactly 43 sites, "
        "got {0}".format(len(rows))
    )


def test_per_site_breadcrumb_coverage_matches_inventory() -> None:
    rows = _parse_inventory()
    src = APP_DART.read_text()

    breadcrumb_re = re.compile(r"MintBreadcrumbs\.legacyRedirectHit\s*\(")
    failures: List[str] = []

    for row in rows:
        # Source column in RECONCILE-REPORT may carry extra descriptors
        # in parentheses (e.g. "/onboarding/quick` (parent L1089)"); strip
        # after the first backtick/paren/space to get the bare path.
        raw_source = row["source"]
        source = re.split(r"[`\s(]", raw_source, maxsplit=1)[0]
        body = _extract_callback_body_by_source(src, source)
        if not body:
            failures.append(
                "site #{0} (source={1}): could not locate ScopedGoRoute in "
                "app.dart".format(row["site_no"], source)
            )
            continue
        actual = len(breadcrumb_re.findall(body))
        expected = row["redirect_branches"]
        if actual != expected:
            failures.append(
                "site #{0} (line {1}, source={2}): expected {3} "
                "MintBreadcrumbs.legacyRedirectHit call(s), got {4}".format(
                    row["site_no"],
                    row["line"],
                    source,
                    expected,
                    actual,
                )
            )

    assert not failures, (
        "Per-site breadcrumb coverage mismatch:\n  " + "\n  ".join(failures)
    )


def test_total_emissions_equals_inventory_sum() -> None:
    """Cross-check: global count matches the sum of redirect_branches.

    Tighter than a loose `>= 43` check because it ties the concrete
    number to the inventory's authoritative sum.
    """
    rows = _parse_inventory()
    expected_sum = sum(r["redirect_branches"] for r in rows)
    src = APP_DART.read_text()
    actual = len(re.findall(r"MintBreadcrumbs\.legacyRedirectHit\s*\(", src))
    assert actual == expected_sum, (
        "Total breadcrumb source-call count {0} != RECONCILE inventory "
        "sum {1}".format(actual, expected_sum)
    )
