#!/usr/bin/env python3
"""Generate a report comparing real Flutter route literals to registry edges."""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on fresh envs.
    yaml = None  # type: ignore[assignment]

REPORT_PATH = Path(".planning/journeys/INTERACTION_COVERAGE_AUDIT.md")
ROUTE_METADATA = Path("apps/mobile/lib/routes/route_metadata.dart")
ROUTE_CALL_RE = re.compile(
    r"context\.(?P<method>push|go|replace)(?:<[^>]+>)?\(\s*(?P<quote>['\"])(?P<route>/[^'\"]+)(?P=quote)",
)
ROUTE_FIELD_RE = re.compile(r"\broute:\s*(?P<quote>['\"])(?P<route>/[^'\"]+)(?P=quote)")
INTERPOLATION_RE = re.compile(r"\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*")
REFERENCE_EXCLUDED_FILES = {
    Path("apps/mobile/lib/routes/route_metadata.dart"),
    Path("apps/mobile/lib/services/navigation/screen_registry.dart"),
}


@dataclass(frozen=True)
class RouteReference:
    path: Path
    line: int
    kind: str
    method: str
    raw_route: str
    canonical_route: str

    def location(self, root: Path) -> str:
        return f"{self.path.relative_to(root)}:{self.line}"


def _route_registry(root: Path) -> set[str]:
    route_file = root / ROUTE_METADATA
    if not route_file.is_file():
        return set()
    text = route_file.read_text(encoding="utf-8")
    return set(re.findall(r"^\s*'([^']+)':\s*RouteMeta\(", text, flags=re.MULTILINE))


def _strip_query(route: str) -> str:
    return route.split("?", 1)[0]


def _template_segments(route: str) -> list[str]:
    return [segment for segment in route.strip("/").split("/") if segment]


def _matches_template(candidate: str, template: str) -> bool:
    candidate_segments = _template_segments(candidate)
    template_segments = _template_segments(template)
    if len(candidate_segments) != len(template_segments):
        return False
    for candidate_segment, template_segment in zip(candidate_segments, template_segments):
        if template_segment.startswith(":") or candidate_segment == ":dynamic":
            continue
        if candidate_segment != template_segment:
            return False
    return True


def _template_score(candidate: str, template: str) -> int:
    score = 0
    for candidate_segment, template_segment in zip(_template_segments(candidate), _template_segments(template)):
        if not template_segment.startswith(":") and candidate_segment == template_segment:
            score += 1
    return score


def canonicalize_route(raw_route: str, route_registry: set[str]) -> str:
    path = _strip_query(raw_route)
    path = INTERPOLATION_RE.sub(":dynamic", path)
    if path in route_registry:
        return path
    matches = [route for route in route_registry if _matches_template(path, route)]
    if matches:
        scored = sorted(((_template_score(path, route), route) for route in matches), key=lambda item: (-item[0], item[1]))
        if scored[0][0] == 0 and ":dynamic" in _template_segments(path):
            return path
        return scored[0][1]
    return path


def _is_reference_file(root: Path, path: Path) -> bool:
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    return relative not in REFERENCE_EXCLUDED_FILES


def _strip_comments(line: str, in_block_comment: bool) -> tuple[str, bool]:
    code: list[str] = []
    quote: str | None = None
    escaped = False
    index = 0
    while index < len(line):
        char = line[index]
        next_char = line[index + 1] if index + 1 < len(line) else ""
        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote is not None:
            code.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char in {"'", '"'}:
            quote = char
            code.append(char)
            index += 1
            continue
        if char == "/" and next_char == "/":
            break
        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue
        code.append(char)
        index += 1
    return "".join(code), in_block_comment


def extract_references(root: Path) -> list[RouteReference]:
    root = root.resolve()
    routes = _route_registry(root)
    refs: list[RouteReference] = []
    lib_root = root / "apps/mobile/lib"
    for path in sorted(lib_root.rglob("*.dart")):
        if not _is_reference_file(root, path):
            continue
        in_block_comment = False
        for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            code_line, in_block_comment = _strip_comments(line, in_block_comment)
            if not code_line.strip():
                continue
            for match in ROUTE_CALL_RE.finditer(code_line):
                raw_route = match.group("route")
                refs.append(
                    RouteReference(
                        path=path,
                        line=line_number,
                        kind="navigation_call",
                        method=match.group("method"),
                        raw_route=raw_route,
                        canonical_route=canonicalize_route(raw_route, routes),
                    ),
                )
            for match in ROUTE_FIELD_RE.finditer(code_line):
                raw_route = match.group("route")
                refs.append(
                    RouteReference(
                        path=path,
                        line=line_number,
                        kind="route_field",
                        method="route",
                        raw_route=raw_route,
                        canonical_route=canonicalize_route(raw_route, routes),
                    ),
                )
    return sorted(refs, key=lambda ref: (ref.canonical_route, ref.location(root), ref.raw_route))


def _load_interactions(root: Path) -> list[dict[str, Any]]:
    if yaml is None:
        raise RuntimeError(
            "PyYAML is required for interaction coverage audit; install with: python3 -m pip install pyyaml",
        )
    interactions_dir = root / "interactions"
    docs: list[dict[str, Any]] = []
    if not interactions_dir.is_dir():
        return docs
    for path in sorted(interactions_dir.glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if isinstance(data, dict):
            docs.append(data)
    return docs


def declared_edge_target_routes(root: Path) -> set[str]:
    routes: set[str] = set()
    for doc in _load_interactions(root):
        nodes = {
            node.get("id"): node.get("route")
            for node in doc.get("nodes", [])
            if isinstance(node, dict) and node.get("kind") == "route"
        }
        for edge in doc.get("edges", []):
            if isinstance(edge, dict):
                route = nodes.get(edge.get("to"))
                if isinstance(route, str):
                    routes.add(route)
    return routes


def _group_locations(refs: list[RouteReference], root: Path, limit: int = 4) -> str:
    locations = [ref.location(root) for ref in refs[:limit]]
    extra = len(refs) - len(locations)
    suffix = f" (+{extra} more)" if extra > 0 else ""
    return ", ".join(locations) + suffix


def generate_report(root: Path) -> str:
    root = root.resolve()
    route_registry = _route_registry(root)
    refs = extract_references(root)
    declared = declared_edge_target_routes(root)
    refs_by_route: dict[str, list[RouteReference]] = {}
    for ref in refs:
        refs_by_route.setdefault(ref.canonical_route, []).append(ref)

    known_routes = set(refs_by_route).intersection(route_registry)
    unknown_routes = set(refs_by_route).difference(route_registry)
    covered_routes = known_routes.intersection(declared)
    uncovered_routes = known_routes.difference(declared)

    lines = [
        "# Interaction Coverage Audit",
        "",
        "<!-- Generated by tools/checks/interaction_coverage_audit.py -- do not edit manually. -->",
        "",
        "## Summary",
        "",
        f"- Extracted Flutter route references: {len(refs)}",
        f"- Distinct known route templates referenced: {len(known_routes)}",
        f"- Covered by declared Interaction Registry edge targets: {len(covered_routes)}",
        f"- Known route templates not yet declared as edge targets: {len(uncovered_routes)}",
        f"- Unknown route literals/templates: {len(unknown_routes)}",
        "",
        "## Covered Routes",
        "",
        "| Status | Route | References |",
        "|---|---|---|",
    ]
    for route in sorted(covered_routes):
        lines.append(
            f"| covered by declared edge target | `{route}` | {_group_locations(refs_by_route[route], root)} |",
        )
    if not covered_routes:
        lines.append("| covered by declared edge target | _none_ |  |")

    lines.extend(
        [
            "",
            "## Uncovered Known Routes",
            "",
            "| Status | Route | References |",
            "|---|---|---|",
        ],
    )
    for route in sorted(uncovered_routes):
        lines.append(f"| uncovered literal route | `{route}` | {_group_locations(refs_by_route[route], root)} |")
    if not uncovered_routes:
        lines.append("| uncovered literal route | _none_ |  |")

    lines.extend(
        [
            "",
            "## Unknown Route Literals",
            "",
            "| Status | Route | References |",
            "|---|---|---|",
        ],
    )
    for route in sorted(unknown_routes):
        lines.append(f"| unknown route literal | `{route}` | {_group_locations(refs_by_route[route], root)} |")
    if not unknown_routes:
        lines.append("| unknown route literal | _none_ |  |")
    lines.extend(
        [
            "",
            "## Declared Edge Target Routes",
            "",
            "| Route |",
            "|---|",
        ],
    )
    for route in sorted(declared):
        lines.append(f"| `{route}` |")
    if not declared:
        lines.append("| _none_ |")
    return "\n".join(lines) + "\n"


def write_report(root: Path) -> None:
    report = generate_report(root)
    path = root / REPORT_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(report, encoding="utf-8")


def check(root: Path) -> list[str]:
    root = root.resolve()
    expected = generate_report(root)
    path = root / REPORT_PATH
    if not path.is_file() or path.read_text(encoding="utf-8") != expected:
        return [
            f"{REPORT_PATH} is missing or stale; run tools/checks/interaction_coverage_audit.py --write",
        ]
    return []


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--write", action="store_true", help="rewrite generated coverage report")
    args = parser.parse_args(argv)
    try:
        if args.write:
            write_report(args.root)
            print("OK interaction_coverage_audit: coverage report updated.")
            return 0
        errors = check(args.root)
    except RuntimeError as exc:
        errors = [str(exc)]
    if not errors:
        print("OK interaction_coverage_audit: coverage report is current.")
        return 0
    print("FAIL interaction_coverage_audit: coverage report is stale.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
