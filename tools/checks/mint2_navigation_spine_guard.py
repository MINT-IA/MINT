#!/usr/bin/env python3
"""Validate the executable Mint 2.0 navigation spine.

This guard intentionally derives facts from runtime-facing source files. It
protects the active Mint 2.0 first-value path from drifting across app.dart,
route metadata, and the Maestro replay flow.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROUTE_METADATA = Path("apps/mobile/lib/routes/route_metadata.dart")
APP = Path("apps/mobile/lib/app.dart")
MINT2_FLOW = Path(
    "tools/simulator/flows/maestro-perfect-set/"
    "flow_mint2_first_experience_rente_capital_entry.yaml"
)
REGISTER_FLOW = Path(
    "tools/simulator/flows/maestro-perfect-set/"
    "flow_jos001_account_lifecycle_seeded_delete.yaml"
)
ACCOUNT_WALL_TITLE = "Cr\u00e9er ton compte"

SPINE_DESTINATIONS = {
    "/onb": {"scope": "public", "category": "destination", "requiresAuth": "false"},
    "/rente-vs-capital": {
        "scope": "onboarding",
        "category": "destination",
        "requiresAuth": "false",
    },
    "/coach/chat": {"scope": "public", "category": "destination", "requiresAuth": "false"},
}
RVC_ALIASES = {
    "/arbitrage/rente-vs-capital": "/rente-vs-capital",
    "/simulator/rente-capital": "/rente-vs-capital",
}
ONBOARDING_COMPAT_ALIASES = {
    "/start": "/onb",
    "/anonymous/chat": "/onb",
    "/onboarding/quick": "/coach/chat",
    "/onboarding/quick-start": "/coach/chat",
    "/onboarding/premier-eclairage": "/coach/chat",
    "/onboarding/intent": "/coach/chat",
    "/onboarding/promise": "/coach/chat",
    "/onboarding/plan": "/coach/chat",
    "/onboarding/smart": "/coach/chat",
    "/onboarding/minimal": "/coach/chat",
}


def _read(root: Path, rel: Path) -> str:
    return (root / rel).read_text(encoding="utf-8", errors="ignore")


def _route_field(body: str, name: str) -> str:
    quoted = re.search(rf"\b{name}:\s*'([^']*)'", body)
    if quoted:
        return quoted.group(1)
    quoted = re.search(rf'\b{name}:\s*"([^"]*)"', body)
    if quoted:
        return quoted.group(1)
    enum_or_bool = re.search(
        rf"\b{name}:\s*(Route(?:Category|Owner)\.[A-Za-z0-9_]+|true|false)",
        body,
    )
    if enum_or_bool:
        return enum_or_bool.group(1).split(".")[-1]
    return ""


def _route_target_from_description(description: str) -> str:
    match = re.search(
        r"(?:redirects?\s+(?:to\s+)?|->\s*)(/[A-Za-z0-9_/:.-]+)",
        description,
        re.IGNORECASE,
    )
    return match.group(1).rstrip(".,;") if match else ""


def _route_metadata(root: Path) -> dict[str, dict[str, str]]:
    lines = _read(root, ROUTE_METADATA).splitlines()
    meta: dict[str, dict[str, str]] = {}
    for index, line in enumerate(lines):
        match = re.match(r"\s*'(?P<key>[^']+)':\s*RouteMeta\((?P<tail>.*)$", line)
        if not match:
            continue
        route = match.group("key")
        body_lines = [match.group("tail")]
        if ")," not in match.group("tail"):
            for next_line in lines[index + 1 :]:
                body_lines.append(next_line)
                if next_line.strip().startswith("),"):
                    break
        body = "\n".join(body_lines)
        meta[route] = {
            "path": _route_field(body, "path") or route,
            "category": _route_field(body, "category"),
            "owner": _route_field(body, "owner"),
            "requiresAuth": _route_field(body, "requiresAuth"),
            "description": _route_field(body, "description"),
        }
    return meta


def _find_call_blocks(source: str, call_name: str) -> list[str]:
    blocks: list[str] = []
    index = 0
    needle = f"{call_name}("
    while True:
        start = source.find(needle, index)
        if start == -1:
            return blocks
        pos = start + len(call_name)
        depth = 0
        quote: str | None = None
        escaped = False
        for cursor in range(pos, len(source)):
            char = source[cursor]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char in {"'", '"'}:
                quote = char
                continue
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    blocks.append(source[start : cursor + 1])
                    index = cursor + 1
                    break
        else:
            return blocks


def _app_routes(root: Path) -> dict[str, dict[str, str]]:
    routes: dict[str, dict[str, str]] = {}
    for block in _find_call_blocks(_read(root, APP), "ScopedGoRoute"):
        path = _route_field(block, "path")
        if not path:
            continue
        scope_match = re.search(r"\bscope:\s*RouteScope\.([A-Za-z0-9_]+)", block)
        redirect_match = re.search(r"=>\s*['\"]([^'\"]+)['\"]", block)
        if redirect_match is None:
            redirect_match = re.search(r"\breturn\s+['\"]([^'\"]+)['\"]\s*;", block)
        routes[path] = {
            "scope": scope_match.group(1) if scope_match else "authenticated",
            "redirect": redirect_match.group(1) if redirect_match else "",
        }
    return routes


def _check_route(
    errors: list[str],
    metadata: dict[str, dict[str, str]],
    app_routes: dict[str, dict[str, str]],
    route: str,
    expected: dict[str, str],
) -> None:
    meta = metadata.get(route)
    app = app_routes.get(route)
    if not meta:
        errors.append(f"{route} is missing from route_metadata.dart")
        return
    if not app:
        errors.append(f"{route} is missing from app.dart ScopedGoRoute")
        return
    for field, value in expected.items():
        if field == "scope":
            actual = app.get("scope")
            if actual != value:
                errors.append(f"{route} must use RouteScope.{value}; found {actual or '<missing>'}")
        else:
            actual = meta.get(field)
            if actual != value:
                label = "not require auth" if field == "requiresAuth" and value == "false" else f"set {field}={value}"
                errors.append(f"{route} must {label}; found {actual or '<missing>'}")


def _check_alias(
    errors: list[str],
    metadata: dict[str, dict[str, str]],
    app_routes: dict[str, dict[str, str]],
    route: str,
    target: str,
) -> None:
    meta = metadata.get(route)
    app = app_routes.get(route)
    if not meta:
        errors.append(f"{route} alias is missing from route_metadata.dart")
        return
    if not app:
        errors.append(f"{route} alias is missing from app.dart")
        return
    if meta.get("category") != "alias":
        errors.append(f"{route} must be a route_metadata alias; found {meta.get('category') or '<missing>'}")
    if meta.get("requiresAuth") != "false" and target in {"/onb", "/rente-vs-capital", "/coach/chat"}:
        errors.append(f"{route} must not require auth before reaching {target}")
    described_target = _route_target_from_description(meta.get("description", ""))
    if described_target != target:
        errors.append(f"{route} metadata must document redirect -> {target}; found {described_target or '<missing>'}")
    if app.get("redirect") != target:
        errors.append(f"{route} app redirect must target {target}; found {app.get('redirect') or '<missing>'}")


def _check_maestro_flow(errors: list[str], root: Path) -> None:
    flow_path = root / MINT2_FLOW
    if not flow_path.exists():
        errors.append(f"missing Mint 2.0 runtime flow: {MINT2_FLOW}")
        return
    text = flow_path.read_text(encoding="utf-8", errors="ignore")
    required_fragments = {
        'clearState: true': "must clear app state",
        'id: "mint2-axis-lpp_rente_capital"': "must assert the live LPP axis",
        'id: "rente_vs_capital_screen"': "must assert rente_vs_capital_screen",
        ACCOUNT_WALL_TITLE: "must assert the account gate is absent after route",
    }
    for fragment, reason in required_fragments.items():
        if fragment not in text:
            errors.append(f"{MINT2_FLOW} {reason}")


def _check_account_wall_positive_control(errors: list[str], root: Path) -> None:
    flow_path = root / REGISTER_FLOW
    if not flow_path.exists():
        errors.append(f"missing account wall positive-control flow: {REGISTER_FLOW}")
        return
    text = flow_path.read_text(encoding="utf-8", errors="ignore")
    if ACCOUNT_WALL_TITLE not in text:
        errors.append(
            f"{REGISTER_FLOW} must positively assert {ACCOUNT_WALL_TITLE!r}"
        )


def check(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    try:
        metadata = _route_metadata(root)
        app_routes = _app_routes(root)
    except OSError as exc:
        return [f"unable to read navigation source: {exc}"]

    for route, expected in SPINE_DESTINATIONS.items():
        _check_route(errors, metadata, app_routes, route, expected)
    for route, target in RVC_ALIASES.items():
        _check_alias(errors, metadata, app_routes, route, target)
        if app_routes.get(route, {}).get("scope") != "onboarding":
            errors.append(f"{route} must stay in RouteScope.onboarding")
    for route, target in ONBOARDING_COMPAT_ALIASES.items():
        _check_alias(errors, metadata, app_routes, route, target)

    _check_maestro_flow(errors, root)
    _check_account_wall_positive_control(errors, root)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root)
    if not errors:
        print("OK mint2_navigation_spine_guard: Mint 2.0 navigation spine is coherent.")
        return 0
    print("FAIL mint2_navigation_spine_guard: Mint 2.0 navigation spine drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
