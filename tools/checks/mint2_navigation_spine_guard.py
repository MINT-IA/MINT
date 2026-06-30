#!/usr/bin/env python3
"""Validate the executable Mint 2.0 navigation spine.

This guard intentionally derives facts from runtime-facing source files. It
protects the active Mint 2.0 first-value path from drifting across app.dart,
route metadata, and the Maestro replay flow.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROUTE_METADATA = Path("apps/mobile/lib/routes/route_metadata.dart")
APP = Path("apps/mobile/lib/app.dart")
SCREEN_REGISTRY = Path("apps/mobile/lib/services/navigation/screen_registry.dart")
MINT2_FLOW = Path(
    "tools/simulator/flows/maestro-perfect-set/"
    "flow_mint2_first_experience_rente_capital_entry.yaml"
)
REGISTER_FLOW = Path(
    "tools/simulator/flows/maestro-perfect-set/"
    "flow_jos001_account_lifecycle_seeded_delete.yaml"
)
JOURNEY_RECORD = Path(".planning/journeys/records/onboarding_first_value.json")
JOURNEY_ISSUE = Path(".planning/journeys/issues/JOS-005.json")
JOURNEY_DIAGRAMS = (
    Path(".planning/journeys/diagrams/onboarding_first_value.mmd"),
    Path(".planning/journeys/diagrams/onboarding_first_value_sequence.mmd"),
)
ACCOUNT_WALL_TITLE = "Cr\u00e9er ton compte"
EMAIL_FALLBACK_CTA = "Cr\u00e9er avec e-mail"
REGISTER_EMAIL_FIELD_RE = re.compile(
    r"visible:\s*(?:\{\s*id:\s*['\"]auth_register_email_field['\"]\s*\}|"
    r"id:\s*['\"]auth_register_email_field['\"])"
)
REGISTER_EMAIL_TAP_RE = re.compile(
    r"tapOn:\s*(?:\{\s*id:\s*['\"]auth_register_email_field['\"]\s*\}|"
    r"id:\s*['\"]auth_register_email_field['\"])"
)
EMAIL_FALLBACK_ASSERT_RE = re.compile(
    rf"assertNotVisible:\s*(?:['\"]{re.escape(EMAIL_FALLBACK_CTA)}['\"]|"
    rf"text:\s*['\"]{re.escape(EMAIL_FALLBACK_CTA)}['\"])"
)
EMAIL_FALLBACK_TAP_RE = re.compile(
    rf"tapOn:\s*(?:['\"]{re.escape(EMAIL_FALLBACK_CTA)}['\"]|"
    rf"text:\s*['\"]{re.escape(EMAIL_FALLBACK_CTA)}['\"])"
)
EMAIL_FALLBACK_VISIBLE_RE = re.compile(
    rf"visible:\s*['\"]{re.escape(EMAIL_FALLBACK_CTA)}['\"]"
)

SPINE_DESTINATIONS = {
    "/onb": {"scope": "public", "category": "destination", "requiresAuth": "false"},
    "/retraite/rente-vs-capital": {
        "scope": "onboarding",
        "category": "destination",
        "requiresAuth": "false",
    },
    "/coach/chat": {"scope": "public", "category": "destination", "requiresAuth": "false"},
}
RVC_ALIASES = {
    "/rente-vs-capital": "/retraite/rente-vs-capital",
    "/arbitrage/rente-vs-capital": "/retraite/rente-vs-capital",
    "/simulator/rente-capital": "/retraite/rente-vs-capital",
}
ONBOARDING_COMPAT_ALIASES = {
    "/start": "/onb",
    "/anonymous/chat": "/onb",
    "/onboarding/quick": "/onb",
    "/onboarding/quick-start": "/onb",
    "/onboarding/premier-eclairage": "/onb",
    "/onboarding/intent": "/onb",
    "/onboarding/promise": "/onb",
    "/onboarding/plan": "/onb",
    "/onboarding/smart": "/onb",
    "/onboarding/minimal": "/onb",
}
EXPECTED_JOURNEY_ROUTES = [
    "/onb",
    "/retraite/rente-vs-capital",
    "/coach/chat",
    "/home",
]
EXPECTED_JOURNEY_BUILD_DEFINES = {
    "MINT_DISABLE_BETA_MODAL=true",
    "MINT_E2E_MINT2_FIRST_EXPERIENCE=true",
    "MINT_E2E_PROOF_ANCHORS=true",
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
        rf"\b{name}:\s*([A-Za-z0-9_]+\.[A-Za-z0-9_]+|true|false)",
        body,
    )
    if enum_or_bool:
        return enum_or_bool.group(1).split(".")[-1]
    return ""


def _list_field_items(body: str, name: str) -> list[str]:
    match = re.search(rf"\b{name}:\s*\[([^\]]*)\]", body, re.DOTALL)
    if match is None:
        return []
    return re.findall(r"['\"]([^'\"]+)['\"]", match.group(1))


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


def route_metadata(root: Path) -> dict[str, dict[str, str]]:
    """Return parsed route metadata for other navigation guards."""
    return _route_metadata(root)


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
    if expected.get("category") == "destination" and app.get("redirect"):
        errors.append(
            f"{route} must be a terminal destination, not redirect to {app['redirect']}"
        )


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
    if meta.get("requiresAuth") != "false" and target in {
        "/onb",
        "/retraite/rente-vs-capital",
        "/coach/chat",
    }:
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
    email_field = REGISTER_EMAIL_FIELD_RE.search(text)
    email_tap = REGISTER_EMAIL_TAP_RE.search(text)
    fallback_assert = EMAIL_FALLBACK_ASSERT_RE.search(text)
    if fallback_assert is None:
        errors.append(
            f"{REGISTER_FLOW} must reject the hidden email fallback CTA "
            f"{EMAIL_FALLBACK_CTA!r}"
        )
    if email_field is None:
        errors.append(
            f"{REGISTER_FLOW} must assert direct register email field visibility"
        )
    if email_tap is None:
        errors.append(
            f"{REGISTER_FLOW} must tap the direct register email field by id"
        )
    if (
        email_field is not None
        and fallback_assert is not None
        and email_field.start() > fallback_assert.start()
    ):
        errors.append(
            f"{REGISTER_FLOW} must assert direct email field before rejecting the fallback CTA"
        )
    if EMAIL_FALLBACK_TAP_RE.search(text) is not None:
        errors.append(
            f"{REGISTER_FLOW} must not tap the hidden email fallback CTA "
            f"{EMAIL_FALLBACK_CTA!r}"
        )
    if EMAIL_FALLBACK_VISIBLE_RE.search(text) is not None:
        errors.append(
            f"{REGISTER_FLOW} must not branch on hidden email fallback CTA "
            f"{EMAIL_FALLBACK_CTA!r}"
        )


def _read_json(
    errors: list[str],
    root: Path,
    rel: Path,
) -> dict[str, object] | None:
    path = root / rel
    if not path.exists():
        errors.append(f"missing Journey OS contract file: {rel}")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{rel} must be valid JSON: {exc}")
        return None
    if not isinstance(data, dict):
        errors.append(f"{rel} must contain a JSON object")
        return None
    return data


def _check_journey_os_contract(errors: list[str], root: Path) -> None:
    record = _read_json(errors, root, JOURNEY_RECORD)
    issue = _read_json(errors, root, JOURNEY_ISSUE)
    if record is None or issue is None:
        return

    if record.get("id") != "onboarding_first_value":
        errors.append(
            f"{JOURNEY_RECORD} must describe onboarding_first_value; "
            f"found {record.get('id') or '<missing>'}"
        )
    routes = record.get("route_paths")
    if routes != EXPECTED_JOURNEY_ROUTES:
        errors.append(
            "onboarding_first_value route_paths must be "
            f"{EXPECTED_JOURNEY_ROUTES}; found {routes!r}"
        )

    runtime = record.get("runtime_replay")
    if not isinstance(runtime, dict):
        errors.append("onboarding_first_value runtime_replay must be an object")
        runtime = {}
    expected_flow = MINT2_FLOW.as_posix()
    if runtime.get("flow") != expected_flow:
        errors.append(
            "onboarding_first_value runtime_replay.flow must be "
            f"{expected_flow}; found {runtime.get('flow') or '<missing>'}"
        )
    if runtime.get("requires_auth") is not False:
        errors.append(
            "onboarding_first_value runtime_replay.requires_auth must be false"
        )
    sets = runtime.get("sets")
    if not isinstance(sets, list) or "core" not in sets:
        errors.append("onboarding_first_value runtime_replay.sets must include core")
    build_defines = runtime.get("build_defines")
    if not isinstance(build_defines, list):
        errors.append("onboarding_first_value runtime_replay.build_defines must be a list")
        build_defines_set: set[str] = set()
    else:
        build_defines_set = {str(item) for item in build_defines}
    missing_defines = sorted(EXPECTED_JOURNEY_BUILD_DEFINES - build_defines_set)
    if missing_defines:
        errors.append(
            "onboarding_first_value runtime_replay.build_defines missing "
            f"{missing_defines}"
        )

    if "JOS-005" not in set(map(str, record.get("issues", []))):
        errors.append("onboarding_first_value issues must include JOS-005")
    if issue.get("journey_id") != "onboarding_first_value":
        errors.append(
            f"{JOURNEY_ISSUE} must point to onboarding_first_value; "
            f"found {issue.get('journey_id') or '<missing>'}"
        )

    forbidden_aliases = set(RVC_ALIASES)
    for rel in JOURNEY_DIAGRAMS:
        path = root / rel
        if not path.exists():
            errors.append(f"missing Journey OS Mermaid diagram: {rel}")
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for route in EXPECTED_JOURNEY_ROUTES:
            if route not in text:
                errors.append(f"{rel.name} must include {route}")
        for alias in sorted(forbidden_aliases):
            alias_pattern = re.compile(
                rf"(?<![A-Za-z0-9_-]){re.escape(alias)}(?![A-Za-z0-9_/-])"
            )
            if alias_pattern.search(text):
                errors.append(
                    f"{rel.name} must not promote legacy alias {alias}; "
                    "use /retraite/rente-vs-capital in the Journey OS spine"
                )


def _check_screen_registry_contract(errors: list[str], root: Path) -> None:
    registry_path = root / SCREEN_REGISTRY
    if not registry_path.exists():
        errors.append(f"missing navigation screen registry: {SCREEN_REGISTRY}")
        return
    text = registry_path.read_text(encoding="utf-8", errors="ignore")
    for stale_fallback in ("/onboarding/quick", "/onboarding/quick-start"):
        if f"fallbackRoute: '{stale_fallback}'" in text:
            errors.append(
                f"{SCREEN_REGISTRY} must not use {stale_fallback} as a planner fallback; use /onb"
            )

    screen_entries = _find_call_blocks(text, "ScreenEntry")
    onboarding_quick = next(
        (
            block
            for block in screen_entries
            if _route_field(block, "intentTag") == "onboarding_quick"
        ),
        None,
    )
    if onboarding_quick is None:
        errors.append(f"{SCREEN_REGISTRY} must keep an onboarding_quick registry entry")
        return
    if _route_field(onboarding_quick, "route") != "/onb":
        errors.append(
            f"{SCREEN_REGISTRY} onboarding_quick must target /onb, not a deleted onboarding alias"
        )
    onb_routes = [
        block for block in screen_entries if _route_field(block, "route") == "/onb"
    ]
    if len(onb_routes) != 1:
        errors.append(
            f"{SCREEN_REGISTRY} must have exactly one primary ScreenEntry route for /onb; found {len(onb_routes)}"
        )
    for block in screen_entries:
        behavior = _route_field(block, "behavior")
        fallback = _route_field(block, "fallbackRoute").split("?", 1)[0]
        prefer_from_chat = _route_field(block, "preferFromChat")
        required_fields = _list_field_items(block, "requiredFields")
        if (
            prefer_from_chat == "true"
            and behavior in {"decisionCanvas", "roadmapFlow"}
            and fallback == "/coach/chat"
            and required_fields
        ):
            intent = _route_field(block, "intentTag") or "<missing-intent>"
            route = _route_field(block, "route") or "<missing-route>"
            errors.append(
                f"{SCREEN_REGISTRY} {intent} ({route}) must not fallback to /coach/chat "
                "when required fields are missing; use /onb or a scoped capture route"
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
    _check_journey_os_contract(errors, root)
    _check_screen_registry_contract(errors, root)
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
