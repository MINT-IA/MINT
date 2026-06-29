#!/usr/bin/env python3
"""Generate Journey OS Markdown and Mermaid views from JSON records."""
from __future__ import annotations

import argparse, json, re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

JOURNEYS = Path(".planning/journeys")
RECORDS = JOURNEYS / "records"
ISSUES = JOURNEYS / "issues"
SUMMARY = JOURNEYS / "JOURNEYS.md"
BOARD = JOURNEYS / "BOARD.md"
TODAY = JOURNEYS / "TODAY.md"
CARDS = JOURNEYS / "CARDS.md"
DIAGRAMS = JOURNEYS / "diagrams"
SYSTEM_MAP = DIAGRAMS / "system_map.mmd"
ROUTE_TOPOLOGY = DIAGRAMS / "route_topology.mmd"
JOURNEY_STATE = DIAGRAMS / "journey_state.mmd"
PRIORITY_POSITIVE = {"trust_blast_radius", "release_blocker_weight", "user_frequency", "evidence_gap", "route_centrality", "compliance_risk", "learning_value"}
EVIDENCE_STATUS_RANK = {"red": 0, "missing": 1, "baselined": 2, "green": 3}

def load_records(root: Path) -> list[dict[str, Any]]:
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted((root / RECORDS).glob("*.json"))]

def load_issues(root: Path) -> list[dict[str, Any]]:
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted((root / ISSUES).glob("*.json"))]

def _cell(value: object) -> str:
    text = ", ".join(value) if isinstance(value, list) else str(value)
    return text.replace("|", "\\|")

def priority_score(rec: dict[str, Any]) -> str:
    priority = rec.get("priority")
    if not isinstance(priority, dict):
        return ""
    try:
        return str(sum(int(priority.get(key, 0)) for key in PRIORITY_POSITIVE) - int(priority.get("proof_cost", 0)))
    except (TypeError, ValueError):
        return ""

def _issues_for(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {str(rec.get("id")): [] for rec in records}
    for issue in issues:
        grouped.setdefault(str(issue.get("journey_id", "")), []).append(issue)
    for items in grouped.values():
        items.sort(key=lambda item: str(item.get("id", "")))
    return grouped

def _latest_evidence(rec: dict[str, Any]) -> dict[str, Any]:
    items = [item for item in rec.get("evidence", []) if isinstance(item, dict)]
    if not items:
        return {}
    return max(enumerate(items), key=lambda pair: _evidence_sort_key(pair[1], pair[0]))[1]

def _evidence_sort_key(item: dict[str, Any], index: int) -> tuple[int, float, int]:
    value = item.get("verified_at")
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return (0, 0.0, index)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return (1, parsed.timestamp(), index)
    return (0, 0.0, index)

def _short_commit(value: object) -> str:
    text = str(value or "")
    return text[:8] if text else ""

def _artifact(value: object) -> str:
    return str(value or "")

def _latest_summary(rec: dict[str, Any]) -> str:
    latest = _latest_evidence(rec)
    if not latest:
        return ""
    status = str(latest.get("status", ""))
    kind = str(latest.get("kind", ""))
    verified_at = str(latest.get("verified_at", ""))
    commit = _short_commit(latest.get("verified_commit"))
    parts = [part for part in (status, kind, verified_at, commit) if part]
    return " / ".join(parts)

def _ranked_issues(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id = {str(rec.get("id")): rec for rec in records}
    severity_rank = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    evidence_rank = {"red": 0, "missing": 1, "baselined": 2, "green": 3}
    return sorted(
        issues,
        key=lambda issue: (
            evidence_rank.get(str(issue.get("evidence_status")), 9),
            severity_rank.get(str(issue.get("severity")), 9),
            -int(priority_score(by_id.get(str(issue.get("journey_id")), {})) or 0),
            str(issue.get("id", "")),
        ),
    )

def _board_row(issue: dict[str, Any], journey: dict[str, Any]) -> str:
    latest = _latest_evidence(journey)
    return "| {id} | {severity} | {status} | {journey} | {journey_status} | {priority} | {owner} | {evidence} | {latest} | {artifact} | {action} |".format(
        id=_cell(issue.get("id", "")),
        severity=_cell(issue.get("severity", "")),
        status=_cell(issue.get("status", "")),
        journey=_cell(issue.get("journey_id", "")),
        journey_status=_cell(journey.get("status", "")),
        priority=priority_score(journey),
        owner=_cell(issue.get("owner", "")),
        evidence=_cell(issue.get("evidence_status", "")),
        latest=_cell(_latest_summary(journey)),
        artifact=_cell(_artifact(latest.get("artifact"))),
        action=_cell(issue.get("next_action", "")),
    )

def markdown(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    grouped = _issues_for(records, issues)
    lines = ["# Mint Journey OS", "", "Generated from `.planning/journeys/records/*.json`. Do not edit directly.", "", "| ID | Tier | Priority | Status | Promise | Accountable team | Routes | Issues | Evidence | Latest proof | Latest artifact |", "|---|---:|---:|---|---|---|---|---|---|---|---|"]
    for rec in records:
        statuses = sorted({str(e.get("status")) for e in rec.get("evidence", []) if isinstance(e, dict)})
        latest = _latest_evidence(rec)
        issue_labels = [
            f"{issue.get('id')}:{issue.get('status')}/{issue.get('evidence_status')}"
            for issue in grouped.get(str(rec.get("id")), [])
        ]
        lines.append("| {id} | {tier} | {priority} | {status} | {promise} | {team} | {routes} | {issues} | {evidence} | {latest} | {artifact} |".format(id=_cell(rec.get("id", "")), tier=_cell(rec.get("tier", "")), priority=priority_score(rec), status=_cell(rec.get("status", "")), promise=_cell(rec.get("human_promise", "")), team=_cell(rec.get("accountable_team", "")), routes=_cell(rec.get("route_paths", [])), issues=_cell(issue_labels), evidence=_cell(statuses), latest=_cell(_latest_summary(rec)), artifact=_cell(_artifact(latest.get("artifact")))))
    return "\n".join(lines) + "\n"

def board(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    by_id = {str(rec.get("id")): rec for rec in records}
    ranked = _ranked_issues(records, issues)
    lines = [
        "# Next Journey OS Work",
        "",
        "Generated from `.planning/journeys/issues/*.json`. Do not edit directly.",
        "",
        "| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |",
        "|---|---|---|---|---|---:|---|---|---|---|---|",
    ]
    for issue in ranked:
        journey = by_id.get(str(issue.get("journey_id")), {})
        lines.append(_board_row(issue, journey))
    return "\n".join(lines) + "\n"

def _list_cell(value: object) -> str:
    if isinstance(value, list):
        return ", ".join(str(item) for item in value) if value else "-"
    text = str(value or "")
    return text if text else "-"

def _runtime_replay_cell(rec: dict[str, Any]) -> str:
    replay = rec.get("runtime_replay")
    if not isinstance(replay, dict):
        return "-"
    sets = _list_cell(replay.get("sets"))
    flow = _list_cell(replay.get("flow"))
    device = _list_cell(replay.get("device"))
    auth = "auth" if replay.get("requires_auth") is True else "no-auth"
    return f"{sets} / {auth} / {device} / {flow}"

def cards(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    grouped = _issues_for(records, issues)
    lines = [
        "# Journey OS Cards",
        "",
        "Generated from `.planning/journeys/records/*.json`. Do not edit directly.",
    ]
    for rec in records:
        latest = _latest_evidence(rec)
        issue_labels = [
            f"{issue.get('id')}:{issue.get('status')}/{issue.get('evidence_status')}"
            for issue in grouped.get(str(rec.get("id")), [])
        ]
        lines += [
            "",
            f"## {rec.get('id', '')}",
            "",
            f"- Title: {_list_cell(rec.get('title'))}",
            f"- Tier: {_list_cell(rec.get('tier'))}",
            f"- Status: {_list_cell(rec.get('status'))}",
            f"- Persona: {_list_cell(rec.get('personas'))}",
            f"- Entry state: {_list_cell(rec.get('entry_state'))}",
            f"- Account state: {_list_cell(rec.get('account_state'))}",
            f"- Success state: {_list_cell(rec.get('success_state'))}",
            f"- Negative assertions: {_list_cell(rec.get('negative_assertions'))}",
            f"- Routes: {_list_cell(rec.get('route_paths'))}",
            f"- APIs: {_list_cell(rec.get('external_apis'))}",
            f"- Runtime replay: {_runtime_replay_cell(rec)}",
            f"- Issues: {_list_cell(issue_labels)}",
            f"- Proof owner: {_list_cell(rec.get('proof_owner'))}",
            f"- Fix owner: {_list_cell(rec.get('fix_owner'))}",
            f"- Latest proof: {_list_cell(_latest_summary(rec))}",
            f"- Latest artifact: {_list_cell(latest.get('artifact') if latest else '')}",
        ]
    return "\n".join(lines) + "\n"

def today(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    by_id = {str(rec.get("id")): rec for rec in records}
    top_issue = next(
        (
            issue for issue in _ranked_issues(records, issues)
            if issue.get("evidence_status") in {"missing", "red", "baselined"}
            or issue.get("status") in {"proof_needed", "regressed", "blocked"}
        ),
        None,
    )
    header = "| Issue | Severity | Status | Journey | Journey status | Journey priority | Owner | Evidence | Latest proof | Artifact | Next action |"
    separator = "|---|---|---|---|---|---:|---|---|---|---|---|"
    top_row = (
        _board_row(top_issue, by_id.get(str(top_issue.get("journey_id")), {}))
        if top_issue
        else "No red, missing, or baselined Journey OS issue is currently queued."
    )
    lines = [
        "# Journey OS Today",
        "",
        "Generated from Journey OS records and issues. Do not edit directly.",
        "",
        "## Top Queue Item",
        "",
        header,
        separator,
        top_row or "No Journey OS issue is currently queued.",
        "",
        "## Operating Rule",
        "",
        "Pick the highest ranked red, missing, or baselined T0 issue unless the PR explicitly names the override.",
        "When the current top issue closes, move `runtime_replay.sets` `top` to the next actionable issue in the same PR; if that issue requires auth, the replay workflow must route through the authenticated job.",
        "",
        "## Proof Discipline",
        "",
        "A journey proof is valid only when the referenced artifact is durable, repo-relative, and accepted by `python3 tools/checks/journey_os_check.py`.",
    ]
    return "\n".join(lines) + "\n"

def _node(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_") or "root"

def _label(value: object) -> str:
    return str(value).replace('"', "'").replace("\n", " ").replace("|", "/").replace(";", ",")

def _class_for(status: object) -> str:
    text = str(status or "")
    if text in {"live_proven", "verified", "green"}:
        return "green"
    if text in {"regressed", "red"}:
        return "red"
    if text in {"partial", "baselined"}:
        return "amber"
    if text in {"blocked", "missing"}:
        return "blocked"
    return "neutral"

def _class_defs() -> list[str]:
    return [
        "  classDef green fill:#e8f5e9,stroke:#1b5e20,color:#0b3d1a;",
        "  classDef red fill:#ffebee,stroke:#b71c1c,color:#5f1111;",
        "  classDef amber fill:#fff8e1,stroke:#ff8f00,color:#5f3b00;",
        "  classDef blocked fill:#eceff1,stroke:#455a64,color:#263238;",
        "  classDef neutral fill:#f5f5f5,stroke:#616161,color:#212121;",
        "  classDef route fill:#e3f2fd,stroke:#0d47a1,color:#082f66;",
        "  classDef surface fill:#f3e5f5,stroke:#4a148c,color:#2b0d52;",
        "  classDef api fill:#e0f2f1,stroke:#00695c,color:#003d35;",
    ]

def _route_metadata(root: Path) -> dict[str, dict[str, str]]:
    path = root / "apps/mobile/lib/routes/route_metadata.dart"
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}
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
            "category": _route_field(body, "category") or "unknown",
            "owner": _route_field(body, "owner") or "unknown",
            "requiresAuth": _route_field(body, "requiresAuth") or "unknown",
            "killFlag": _route_field(body, "killFlag") or "",
            "description": _route_field(body, "description") or "",
        }
    return meta

def _route_field(body: str, name: str) -> str:
    quoted = re.search(rf"\b{name}:\s*'([^']*)'", body)
    if quoted:
        return quoted.group(1)
    quoted = re.search(rf'\b{name}:\s*"([^"]*)"', body)
    if quoted:
        return quoted.group(1)
    enum_or_bool = re.search(rf"\b{name}:\s*(Route(?:Category|Owner)\.[A-Za-z0-9_]+|true|false)", body)
    if enum_or_bool:
        return enum_or_bool.group(1).split(".")[-1]
    return ""

def _route_target(meta: dict[str, str]) -> str:
    description = meta.get("description", "")
    match = re.search(r"(?:redirects?\s+(?:to\s+)?|->\s*)(/[A-Za-z0-9_/:.-]+)", description, re.IGNORECASE)
    return match.group(1).rstrip(".,;") if match else ""

def route_topology(root: Path, records: list[dict[str, Any]]) -> str:
    meta = _route_metadata(root)
    included = {
        str(route)
        for rec in records
        for route in rec.get("route_paths", [])
        if isinstance(route, str)
    }
    for route, item in meta.items():
        target = _route_target(item)
        if item.get("category") == "alias" and target in included:
            included.add(route)

    lines = [
        "%% Generated route topology for Journey OS routes",
        "flowchart LR",
        "  classDef route fill:#e3f2fd,stroke:#0d47a1,color:#082f66;",
        "  classDef alias fill:#f5f5f5,stroke:#616161,color:#212121,stroke-dasharray: 4 3;",
        "  classDef auth fill:#fff8e1,stroke:#ff8f00,color:#5f3b00;",
        "  classDef public fill:#e8f5e9,stroke:#1b5e20,color:#0b3d1a;",
    ]
    for route in sorted(included):
        item = meta.get(route, {})
        node = "route__" + _node(route)
        category = item.get("category", "unknown")
        owner = item.get("owner", "unknown")
        auth = item.get("requiresAuth", "unknown")
        flag = item.get("killFlag", "")
        auth_label = "auth" if auth == "true" else "public" if auth == "false" else "auth unknown"
        flag_label = f"<br/>flag {flag}" if flag else ""
        lines += [
            f'  {node}["{_label(route)}<br/>{_label(category)}/{_label(owner)}<br/>{auth_label}{flag_label}"]',
            f"  class {node} {'alias' if category == 'alias' else 'route'}",
            f"  class {node} {'auth' if auth == 'true' else 'public' if auth == 'false' else 'route'}",
        ]
    for route in sorted(included):
        target = _route_target(meta.get(route, {}))
        if target and target in included:
            lines.append(f"  route__{_node(route)} -. redirects .-> route__{_node(target)}")
    return "\n".join(dict.fromkeys(lines)) + "\n"

def journey_state(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    grouped = _issues_for(records, issues)
    lines = [
        "%% Generated Journey OS state ledger",
        "stateDiagram-v2",
    ]
    for rec in records:
        rid = str(rec.get("id", ""))
        journey_node = "journey_" + _node(rid)
        latest = _latest_evidence(rec)
        latest_status = str(latest.get("status", "missing") if latest else "missing")
        latest_kind = str(latest.get("kind", "missing") if latest else "missing")
        evidence_node = "evidence_" + _node(rid)
        lines += [
            f'  state "{_label(rid)} {_label(rec.get("status", ""))}" as {journey_node}',
            f'  state "latest {latest_kind} {latest_status}" as {evidence_node}',
            f"  [*] --> {journey_node}",
            f"  {journey_node} --> {evidence_node}: proof",
        ]
        for issue in grouped.get(rid, []):
            issue_id = str(issue.get("id", ""))
            issue_node = "issue_" + _node(issue_id)
            issue_label = f"{issue_id} {issue.get('status')}/{issue.get('evidence_status')}"
            lines += [
                f'  state "{_label(issue_label)}" as {issue_node}',
                f"  {journey_node} --> {issue_node}: issue",
            ]
    return "\n".join(lines) + "\n"

def sequence(rec: dict[str, Any], issues: list[dict[str, Any]]) -> str:
    rid = str(rec.get("id", ""))
    latest = _latest_evidence(rec)
    routes = _list_cell(rec.get("route_paths"))
    surfaces = _list_cell(rec.get("surfaces"))
    apis = _list_cell(rec.get("external_apis"))
    replay = _runtime_replay_cell(rec)
    latest_label = _latest_summary(rec) or "no durable proof"
    issue_label = _list_cell([issue.get("id", "") for issue in issues])
    lines = [
        f"%% Generated from .planning/journeys/records/{rid}.json",
        "sequenceDiagram",
        "  participant User",
        "  participant Journey",
        "  participant Routes",
        "  participant Surfaces",
        "  participant APIs",
        "  participant Evidence",
        f"  User->>Journey: {_label(rec.get('human_promise', ''))}",
        f"  Journey->>Routes: {_label(routes)}",
        f"  Routes->>Surfaces: {_label(surfaces)}",
    ]
    if apis != "-":
        lines.append(f"  Surfaces->>APIs: {_label(apis)}")
        lines.append("  APIs-->>Surfaces: canonical contract")
    lines += [
        f"  Surfaces-->>Journey: {_label(rec.get('success_state', ''))}",
        f"  Journey->>Evidence: replay {_label(replay)}",
        f"  Journey->>Evidence: {_label(latest_label)}",
        f"  Evidence-->>Journey: issues {_label(issue_label)}",
    ]
    return "\n".join(lines) + "\n"

def mermaid(rec: dict[str, Any], issues: list[dict[str, Any]]) -> str:
    rid = str(rec["id"])
    latest = _latest_evidence(rec)
    latest_label = _latest_summary(rec) or "no proof"
    lines = [f"%% Generated from .planning/journeys/records/{rid}.json", "flowchart TD", f'  promise["{_label(rec["human_promise"])}"]', f'  team["{_label(rec["accountable_team"])}"]', f'  latest["latest proof: {_label(latest_label)}"]', "  promise --> latest"]
    lines += _class_defs()
    lines += [f"  class latest {_class_for(latest.get('status'))}"]
    if priority_score(rec):
        lines += [f'  priority["priority score {priority_score(rec)}"]', "  priority --> promise"]
    for route in rec.get("route_paths", []):
        node = "route_" + _node(str(route))
        lines += [f'  {node}["{_label(route)}"]', f"  promise --> {node}", f"  {node} --> team", f"  class {node} route"]
    for surface in rec.get("surfaces", []):
        node = "surface_" + _node(str(surface))
        lines += [f'  {node}["{_label(surface)}"]', f"  promise -.-> {node}", f"  class {node} surface"]
    for api in rec.get("external_apis", []):
        node = "api_" + _node(str(api))
        lines += [f'  {node}["{_label(api)}"]', f"  promise -.-> {node}", f"  class {node} api"]
    for issue in issues:
        node = "issue_" + _node(str(issue.get("id", "")))
        label = f"{issue.get('id')} {issue.get('status')}/{issue.get('evidence_status')}"
        lines += [f'  {node}["{_label(label)}"]', f"  {node} --> promise", f"  class {node} {_class_for(issue.get('evidence_status'))}"]
    return "\n".join(lines) + "\n"

def system_map(records: list[dict[str, Any]], issues: list[dict[str, Any]]) -> str:
    grouped = _issues_for(records, issues)
    lines = ["%% Generated from .planning/journeys/records/*.json and issues/*.json", "flowchart LR"]
    lines += _class_defs()
    for rec in records:
        jid = "journey_" + _node(str(rec.get("id", "")))
        latest = _latest_evidence(rec)
        label = f"{rec.get('id')}<br/>{rec.get('status')}<br/>latest {latest.get('status', 'missing')}"
        lines += [f'  {jid}["{_label(label)}"]', f"  class {jid} {_class_for(latest.get('status') or rec.get('status'))}"]
        for route in rec.get("route_paths", []):
            route_node = "route_" + _node(str(route))
            lines += [f'  {route_node}["{_label(route)}"]', f"  {jid} --> {route_node}", f"  class {route_node} route"]
        for surface in rec.get("surfaces", []):
            surface_node = "surface_" + _node(str(surface))
            lines += [f'  {surface_node}["{_label(surface)}"]', f"  {jid} -.-> {surface_node}", f"  class {surface_node} surface"]
        for api in rec.get("external_apis", []):
            api_node = "api_" + _node(str(api))
            lines += [f'  {api_node}["{_label(api)}"]', f"  {jid} -.-> {api_node}", f"  class {api_node} api"]
        for issue in grouped.get(str(rec.get("id")), []):
            issue_node = "issue_" + _node(str(issue.get("id", "")))
            label = f"{issue.get('id')}<br/>{issue.get('status')}/{issue.get('evidence_status')}"
            lines += [f'  {issue_node}["{_label(label)}"]', f"  {issue_node} --> {jid}", f"  class {issue_node} {_class_for(issue.get('evidence_status'))}"]
    return "\n".join(dict.fromkeys(lines)) + "\n"

def expected(root: Path) -> dict[Path, str]:
    records = load_records(root)
    issues = load_issues(root)
    grouped = _issues_for(records, issues)
    out = {
        SUMMARY: markdown(records, issues),
        BOARD: board(records, issues),
        TODAY: today(records, issues),
        CARDS: cards(records, issues),
        SYSTEM_MAP: system_map(records, issues),
        ROUTE_TOPOLOGY: route_topology(root, records),
        JOURNEY_STATE: journey_state(records, issues),
    }
    out.update({DIAGRAMS / f"{rec['id']}.mmd": mermaid(rec, grouped.get(str(rec.get("id")), [])) for rec in records})
    out.update({DIAGRAMS / f"{rec['id']}_sequence.mmd": sequence(rec, grouped.get(str(rec.get("id")), [])) for rec in records})
    return out

def write(root: Path) -> None:
    for rel, content in expected(root).items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    write(args.root.resolve())
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
