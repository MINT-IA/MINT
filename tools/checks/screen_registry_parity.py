#!/usr/bin/env python3
"""Phase 53-01 — ScreenRegistry × app.dart parity lint.

Compares path literals extracted from `apps/mobile/lib/app.dart` (via
`GoRoute|ScopedGoRoute(path: ...)` regex) against the `route:` literals
declared inside `ScreenEntry(...)` constructor calls in
`apps/mobile/lib/services/navigation/screen_registry.dart`.

Mirror of `tools/checks/route_registry_parity.py` (Phase 32-04 / MAP-04)
applied to the SemanTIc screen registry instead of the route metadata
registry. The two registries serve different purposes:
  * `kRouteMetadata` (route_registry_parity.py) — telemetry / admin / breadcrumbs
  * `MintScreenRegistry` (this lint)             — chat → intent → screen routing

Both must stay in sync with `app.dart`.

Exits:
  0 — parity holds (after KNOWN-MISSES exemption).
  1 — drift detected (registry missing a route OR ghost entry with no route).
  2 — usage / argument / missing-file error (sysexits.h EX_USAGE).

Usage:
    python3 tools/checks/screen_registry_parity.py
    python3 tools/checks/screen_registry_parity.py --extract-only apps
    python3 tools/checks/screen_registry_parity.py --extract-only registry

Python 3.9-compatible (dev 3.9.6, CI 3.11). stdlib-only.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_DART = REPO_ROOT / "apps" / "mobile" / "lib" / "app.dart"
REGISTRY_DART = (
    REPO_ROOT / "apps" / "mobile" / "lib" / "services" / "navigation" / "screen_registry.dart"
)

# ---------------------------------------------------------------------------
# KNOWN-MISSES allow-lists
# (See tools/checks/screen_registry_parity-KNOWN-MISSES.md for rationale.)
# ---------------------------------------------------------------------------
# Routes present in app.dart that are intentionally NOT in the chat-routable
# screen registry. Examples: shell tabs, auth flows, landing, achievements,
# admin-only surfaces, dev-only debug screens.
#
# A route belongs here when ScreenEntry would have `preferFromChat: false`
# AND opening it from the chat surface would be either nonsensical (auth) or
# undesirable (admin). Adding here requires a one-line entry in the
# KNOWN-MISSES.md doc explaining WHY it's not chat-routable.
_NOT_CHAT_ROUTABLE: Set[str] = {
    # Shell + landing + tab routes
    "/",
    "/start",
    "/onb",
    # Auth flows
    "/auth/login",
    "/auth/register",
    "/auth/forgot-password",
    "/auth/verify-email",
    "/auth/verify",
    # Anonymous wedge (pre-auth)
    "/anonymous/intent",
    "/anonymous/chat",
    # Admin / dev-only
    "/admin/routes",
    "/admin/observability",
    "/admin/analytics",
    # Achievements / progress
    "/achievements",
    # Coach surface itself (the chat is the SOURCE of routing; you don't route INTO it)
    "/coach",
    "/coach/chat",
    # Phase 53-01 — about + onboarding flows are pre-chat or post-chat-irrelevant
    "/about",
    "/onboarding/enrichment",
    "/onboarding/intent",
    "/onboarding/minimal",
    "/onboarding/plan",
    "/onboarding/promise",
    "/onboarding/quick-start",
    "/onboarding/smart",
}

# Routes that belong to the registry but use a dynamic / parametric form
# in app.dart that the regex doesn't reliably extract (e.g. `path: '/profile'`
# with nested `routes: [...]` children). The lint sees the bare segment in
# app.dart but the registry stores the composed form. Both halves are
# exempted from comparison here.
#
# Format: (segment_in_app_dart, composed_form_in_registry).
_NESTED_PROFILE_CHILDREN: Set[Tuple[str, str]] = {
    ("admin-observability", "/profile/admin-observability"),
    ("admin-analytics", "/profile/admin-analytics"),
    ("byok", "/profile/byok"),
    ("slm", "/profile/slm"),
    ("bilan", "/profile/bilan"),
    ("privacy-control", "/profile/privacy-control"),
    ("privacy", "/profile/privacy"),
}

# ---------------------------------------------------------------------------
# Regex library
# ---------------------------------------------------------------------------
# Matches `path: '...'` inside GoRoute(...) or ScopedGoRoute(...) declarations
# in app.dart. DOTALL lets the regex cross newlines between `(` and `path:`.
# The non-greedy `[^)]*?` prevents swallowing the whole route list.
_GOROUTE_RE = re.compile(
    r"""(?:GoRoute|ScopedGoRoute)\s*\(       # constructor
        [^)]*?                                 # any preceding kwargs (scope:, name:, ...)
        path\s*:\s*                            # path kwarg
        (?P<q>['"])(?P<path>[^'"]+?)(?P=q)     # captured path literal
    """,
    re.VERBOSE | re.DOTALL,
)

# Matches `route: '/...'` literals inside ScreenEntry(...) constructors in
# screen_registry.dart. Less complex than the GoRoute regex because every
# ScreenEntry has a flat `route:` field (no nested routes concept here).
# Anchored on the `route:` field name to avoid false positives on other
# string fields (intentTag, fallbackRoute also use string literals).
_SCREEN_ENTRY_ROUTE_RE = re.compile(
    r"""ScreenEntry\s*\(             # constructor
        [^)]*?                          # any preceding kwargs
        \broute\s*:\s*                  # route kwarg (word-boundary excludes fallbackRoute)
        (?P<q>['"])(?P<path>[^'"]+?)(?P=q)
    """,
    re.VERBOSE | re.DOTALL,
)


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------
def extract_app_paths(src: str) -> Set[str]:
    return {m.group("path") for m in _GOROUTE_RE.finditer(src)}


def extract_registry_routes(src: str) -> Set[str]:
    """Extract registry route literals, normalizing query strings.

    `ScreenEntry(route: '/coach/chat?topic=foo')` is a parameter-bearing
    shortcut — the actual GoRouter target is the bare `/coach/chat`.
    Strip `?...` so the comparison against app.dart's path declarations
    matches the routing reality.
    """
    raw = {m.group("path") for m in _SCREEN_ENTRY_ROUTE_RE.finditer(src)}
    return {p.split("?", 1)[0] for p in raw}


def _apply_known_misses(
    app_paths: Set[str], reg_routes: Set[str]
) -> Tuple[Set[str], Set[str]]:
    """Strip KNOWN-MISSES exemptions from both sides before comparison.

    Returns (app_paths_cleaned, reg_routes_cleaned).
    """
    # Not-chat-routable: exempt from BOTH sides. The registry intentionally
    # holds entries for some non-chat-routable surfaces (auth, achievements,
    # shell tabs) so the LLM can refer to them by intent without actually
    # navigating users there (gated by `preferFromChat: false`). The lint
    # should not enforce parity in either direction for these — they're
    # known by the system but exempted from chat-route discipline.
    app_cleaned = set(app_paths) - _NOT_CHAT_ROUTABLE
    reg_cleaned = set(reg_routes) - _NOT_CHAT_ROUTABLE

    # Nested children: bare segment from app side, composed from registry side.
    nested_segments = {seg for seg, _ in _NESTED_PROFILE_CHILDREN}
    nested_composed = {composed for _, composed in _NESTED_PROFILE_CHILDREN}
    app_cleaned = app_cleaned - nested_segments
    reg_cleaned = reg_cleaned - nested_composed

    return app_cleaned, reg_cleaned


# ---------------------------------------------------------------------------
# Core comparison
# ---------------------------------------------------------------------------
def run_parity(app_src: str, registry_src: str) -> int:
    app_paths = extract_app_paths(app_src)
    reg_routes = extract_registry_routes(registry_src)

    app_cmp, reg_cmp = _apply_known_misses(app_paths, reg_routes)
    missing_in_registry = app_cmp - reg_cmp
    ghost_in_registry = reg_cmp - app_cmp

    sys.stderr.write(
        "[info] extracted {n} path literal(s) from app.dart\n".format(n=len(app_paths))
    )
    sys.stderr.write(
        "[info] registry has {n} ScreenEntry route(s); "
        "{a} not-chat-routable + {p} nested-profile entries "
        "exempted per KNOWN-MISSES.md\n".format(
            n=len(reg_routes),
            a=len(_NOT_CHAT_ROUTABLE & app_paths),
            p=len(_NESTED_PROFILE_CHILDREN),
        )
    )

    if not missing_in_registry and not ghost_in_registry:
        print(
            "[OK] {n} routes parity OK (after KNOWN-MISSES exemption).".format(
                n=len(app_cmp)
            )
        )
        return 0

    if missing_in_registry:
        sys.stderr.write(
            "[FAIL] {n} path(s) present in app.dart but absent from MintScreenRegistry:\n".format(
                n=len(missing_in_registry)
            )
        )
        for p in sorted(missing_in_registry):
            sys.stderr.write("  + {p}\n".format(p=p))
        sys.stderr.write(
            "  Fix: add a `static const _name = ScreenEntry(route: '<path>', ...)` "
            "entry to apps/mobile/lib/services/navigation/screen_registry.dart "
            "AND register it in the master `entries` list (~line 1487). OR, if the "
            "route is intentionally not chat-routable (auth flow / shell tab / "
            "admin-only), add it to `_NOT_CHAT_ROUTABLE` in this script AND "
            "document the reason in tools/checks/screen_registry_parity-KNOWN-MISSES.md.\n"
        )

    if ghost_in_registry:
        sys.stderr.write(
            "[FAIL] {n} ScreenEntry route(s) declared in registry but absent from app.dart (ghost):\n".format(
                n=len(ghost_in_registry)
            )
        )
        for p in sorted(ghost_in_registry):
            sys.stderr.write("  - {p}\n".format(p=p))
        sys.stderr.write(
            "  Fix: remove the stale ScreenEntry OR restore the GoRoute/ScopedGoRoute "
            "declaration in app.dart.\n"
        )

    return 1


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--extract-only",
        choices=["app", "registry"],
        default=None,
        help="Print extracted path literals from app.dart OR registry, sorted, then exit 0.",
    )
    args = parser.parse_args(argv)

    if not APP_DART.exists():
        sys.stderr.write(
            "[FAIL] app.dart not found at {p}\n".format(p=APP_DART)
        )
        return 2
    if not REGISTRY_DART.exists():
        sys.stderr.write(
            "[FAIL] screen_registry.dart not found at {p}\n".format(p=REGISTRY_DART)
        )
        return 2

    app_src = APP_DART.read_text(encoding="utf-8")
    registry_src = REGISTRY_DART.read_text(encoding="utf-8")

    if args.extract_only == "app":
        for p in sorted(extract_app_paths(app_src)):
            print(p)
        return 0
    if args.extract_only == "registry":
        for p in sorted(extract_registry_routes(registry_src)):
            print(p)
        return 0

    return run_parity(app_src, registry_src)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
