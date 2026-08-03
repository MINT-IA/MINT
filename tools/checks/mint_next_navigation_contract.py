#!/usr/bin/env python3
"""MINT Next navigation-contract guard — bidirectional, mechanical.

Doctrine (product/mint_next/batch6/navigation.yaml invariants):

    every_visible_control_has_one_declared_destination
    no_dead_node_no_orphan_renderer_no_hidden_route

This guard turns "chaque bouton a un sens ; il n'existe pas s'il n'a pas de
route" into a CI gate over the executable Design Lab
(product/mint_next/batch7/design_lab), in BOTH directions:

  1. contract -> code : every contract node with an implemented surface must
     have a Design Lab screen (`nodeId: '<node>'`), and every declared action
     that routes to a *built* destination must have an interactive element
     (`'action:<node>.<action>'`). Every declared overlay must be built (or
     waitlisted) and its declared actions wired. Nodes/overlays not yet built
     live on an EXPLICIT waitlist — never silently ignored.

  2. code -> contract : every navigation element wired in the Design Lab
     (a `nodeId`, an `action:<node>.<action>` key, an `overlay:<id>` or
     `overlay-action:<id>.<action>` key) must be declared in the contract.
     An undeclared control is a FAIL with `path:line`.

Parsing approach (Karpathy #2 — robust and simple). The Design Lab already
maintains an explicit, greppable key registry, so the guard reads that
convention rather than doing fragile AST analysis. Systematic exceptions are
handled explicitly:

  * the safe-exit header is auto-injected for every scaffolded node as
    `ValueKey('action:$nodeId.open_safe_exit')` — recognised as an auto action;
  * row-scoped controls use `'action:<verb>:${row.id}'` — not graph
    transitions, excluded by construction.

To keep the code->contract direction from being bypassed by a different spelling
of the same key, the scanner accepts single OR double quotes, and — crucially —
any OTHER `action:` string that it cannot resolve to a clean literal (an
interpolated id, an adjacent-string concatenation, a key built from a variable)
is reported as an *unresolvable navigation key* FAIL: ambiguity fails closed.

Known scope boundary (documented, not hidden): a purely static scan cannot see
navigation expressed WITHOUT the key registry — an unkeyed `Navigator.push`,
`InkWell`/`GestureDetector` `onTap`, or a node id interpolated at runtime. The
contract's own `renderer_binding.verified_manifest`
(`generated_flutter_design_lab_runtime_inventory`) is the designated RUNTIME
complement that resolves those. This guard is the fast, Flutter-free CI gate
over the declared key registry plus a fail-closed detector for dynamic keys.
Contract-internal integrity (targets exist, reachability, cardinality) is owned
by `tools/checks/mint_next_batch6_navigation_guard.py` and not re-implemented
here.

The guard NO-OPS GREEN only when BOTH the contract and the Design Lab are absent
(the legitimate pre-landing state on `dev`). If exactly one side is present it
FAILS — a half-present tree is a deletion/rename accident, not a no-op.

Usage:
    python3 tools/checks/mint_next_navigation_contract.py            # gate
    python3 tools/checks/mint_next_navigation_contract.py --explain result
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_ROOT = SCRIPT_DIR.parents[1]
CONTRACT_RELPATH = "product/mint_next/batch6/navigation.yaml"
LAB_RELPATH = "product/mint_next/batch7/design_lab"
DEFAULT_WAITLIST = SCRIPT_DIR / "mint_next_navigation_contract_waitlist.yaml"

# Actions the Design Lab provides via the shared scaffold rather than a literal
# per-node key. Only satisfied when the interpolated header is present.
AUTO_INJECTED_ACTIONS = frozenset({"open_safe_exit"})

_Q = r"['\"]"  # single or double quote
NODE_RE = re.compile(rf"nodeId:\s*{_Q}([a-z0-9_]+){_Q}")
# Every quoted string that starts with the `action:` prefix, captured whole so
# the scanner can classify it (literal / auto safe-exit / row-scoped / dynamic).
ACTION_TOKEN_RE = re.compile(rf"{_Q}action:([^'\"]*){_Q}")
OVERLAY_RE = re.compile(rf"{_Q}overlay:([a-z0-9_]+){_Q}")
OVERLAY_ACTION_RE = re.compile(rf"{_Q}overlay-action:([a-z0-9_]+)\.([a-z0-9_]+){_Q}")

LITERAL_ACTION_RE = re.compile(r"^([a-z0-9_]+)\.([a-z0-9_]+)$")
AUTO_SAFE_EXIT_RE = re.compile(r"^\$[A-Za-z_][A-Za-z0-9_]*\.open_safe_exit$")
ROW_SCOPED_RE = re.compile(r"^[a-z0-9_]+:")  # `verb:${row.id}` — not a transition


# --------------------------------------------------------------------------
# contract model
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class ContractAction:
    node: str
    action: str
    to: str | None
    overlay: str | None
    outcomes: tuple[str, ...]  # destination node ids
    operation: str | None

    @property
    def destinations(self) -> tuple[str, ...]:
        dests = []
        if self.to:
            dests.append(self.to)
        dests.extend(self.outcomes)
        return tuple(dests)

    @property
    def routes(self) -> bool:
        """A control that changes location (node or overlay), vs a pure field
        mutation (e.g. entering an amount) that needs no discrete button."""
        return bool(self.to or self.overlay or self.outcomes)


@dataclass
class ContractModel:
    entry: str
    nodes: dict[str, dict]
    actions: dict[str, dict[str, ContractAction]]
    terminal: set[str]
    overlays: dict[str, set[str]]


def load_contract(path: Path) -> dict:
    return yaml.safe_load(Path(path).read_text(encoding="utf-8"))


def build_contract_model(data: dict) -> ContractModel:
    nodes = data.get("nodes", {}) or {}
    entry = data.get("entry_node")
    terminal: set[str] = set()
    actions: dict[str, dict[str, ContractAction]] = {}
    for node_id, node in nodes.items():
        if node.get("terminal"):
            terminal.add(node_id)
        node_actions: dict[str, ContractAction] = {}
        for action_id, spec in (node.get("actions", {}) or {}).items():
            spec = spec or {}
            outcomes = spec.get("outcomes", {}) or {}
            node_actions[action_id] = ContractAction(
                node=node_id,
                action=action_id,
                to=spec.get("to"),
                overlay=spec.get("overlay"),
                outcomes=tuple(sorted(str(v) for v in outcomes.values())),
                operation=spec.get("operation"),
            )
        actions[node_id] = node_actions

    overlays: dict[str, set[str]] = {}
    for overlay_id, overlay in (data.get("overlays", {}) or {}).items():
        overlays[overlay_id] = set((overlay.get("actions", {}) or {}).keys())

    return ContractModel(
        entry=entry, nodes=nodes, actions=actions, terminal=terminal, overlays=overlays
    )


# --------------------------------------------------------------------------
# design-lab inventory
# --------------------------------------------------------------------------


@dataclass
class CodeInventory:
    node_sites: dict[str, str] = field(default_factory=dict)  # node -> "path:line"
    action_sites: dict[str, str] = field(default_factory=dict)  # "node.action" -> site
    overlay_sites: dict[str, str] = field(default_factory=dict)
    overlay_action_sites: dict[str, str] = field(default_factory=dict)
    unresolved_action_sites: dict[str, str] = field(default_factory=dict)  # raw -> site
    has_auto_safe_exit: bool = False

    @property
    def action_namespaces(self) -> set[str]:
        return {key.split(".", 1)[0] for key in self.action_sites}


def _is_comment(line: str) -> bool:
    stripped = line.lstrip()
    return stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("///")


def scan_lab(lab_dir: Path, root: Path) -> CodeInventory:
    inv = CodeInventory()
    lab_dir = Path(lab_dir)
    root = Path(root)
    for dart in sorted((lab_dir / "lib").rglob("*.dart")):
        if "/generated/" in dart.as_posix():
            continue
        rel = dart.relative_to(root).as_posix()
        for lineno, line in enumerate(dart.read_text(encoding="utf-8").splitlines(), 1):
            if _is_comment(line):
                continue  # doc/example lines are not wiring
            site = f"{rel}:{lineno}"
            for m in NODE_RE.finditer(line):
                inv.node_sites.setdefault(m.group(1), site)
            for m in ACTION_TOKEN_RE.finditer(line):
                inner = m.group(1)
                lit = LITERAL_ACTION_RE.match(inner)
                if lit:
                    inv.action_sites.setdefault(f"{lit.group(1)}.{lit.group(2)}", site)
                elif AUTO_SAFE_EXIT_RE.match(inner):
                    inv.has_auto_safe_exit = True
                elif ROW_SCOPED_RE.match(inner):
                    continue  # row-scoped control, not a graph transition
                else:
                    # An `action:` key we cannot resolve to a clean literal —
                    # interpolated id, concatenation, variable. Fail closed.
                    inv.unresolved_action_sites.setdefault(f"action:{inner}", site)
            for m in OVERLAY_RE.finditer(line):
                inv.overlay_sites.setdefault(m.group(1), site)
            for m in OVERLAY_ACTION_RE.finditer(line):
                inv.overlay_action_sites.setdefault(f"{m.group(1)}.{m.group(2)}", site)
    return inv


# --------------------------------------------------------------------------
# waitlist
# --------------------------------------------------------------------------


@dataclass
class Waitlist:
    unimplemented_nodes: set[str] = field(default_factory=set)
    unimplemented_overlays: set[str] = field(default_factory=set)
    pending_code_nodes: set[str] = field(default_factory=set)
    pending_code_actions: set[str] = field(default_factory=set)
    pending_code_overlays: set[str] = field(default_factory=set)
    pending_code_overlay_actions: set[str] = field(default_factory=set)
    contract_action_gaps: set[str] = field(default_factory=set)
    contract_overlay_action_gaps: set[str] = field(default_factory=set)


def waitlist_from_dict(data: dict | None) -> Waitlist:
    data = data or {}

    def _set(key: str) -> set[str]:
        return set(data.get(key, []) or [])

    return Waitlist(
        unimplemented_nodes=_set("unimplemented_nodes"),
        unimplemented_overlays=_set("unimplemented_overlays"),
        pending_code_nodes=_set("pending_code_nodes"),
        pending_code_actions=_set("pending_code_actions"),
        pending_code_overlays=_set("pending_code_overlays"),
        pending_code_overlay_actions=_set("pending_code_overlay_actions"),
        contract_action_gaps=_set("contract_action_gaps"),
        contract_overlay_action_gaps=_set("contract_overlay_action_gaps"),
    )


def load_waitlist(path: Path | None) -> Waitlist:
    if path is None:
        return Waitlist()
    path = Path(path)
    if not path.is_file():
        return Waitlist()
    return waitlist_from_dict(yaml.safe_load(path.read_text(encoding="utf-8")) or {})


# --------------------------------------------------------------------------
# evaluation
# --------------------------------------------------------------------------


def _action_requires_element(
    ca: ContractAction, model: ContractModel, inv: CodeInventory
) -> bool:
    """A declared action needs a keyed interactive element iff it is the Back
    control of a built non-entry non-terminal node, OR it routes to a
    destination that is already built. A button to a not-yet-built screen is
    not required (you cannot wire a route to a node that does not exist)."""
    if ca.action == "back" and ca.node != model.entry and ca.node not in model.terminal:
        return True
    if not ca.routes:
        return False
    for dest in ca.destinations:
        if dest in inv.node_sites:
            return True
    if ca.overlay and ca.overlay in inv.overlay_sites:
        return True
    return False


def _waitlist_hygiene(model: ContractModel, inv: CodeInventory, wl: Waitlist) -> list[str]:
    """Every mask must correspond to a real, still-present divergence. A stale
    entry is a silent green — flag it so the ledger cannot rot."""
    out: list[str] = []
    for node in sorted(wl.unimplemented_nodes):
        if node not in model.nodes:
            out.append(f"[waitlist] '{node}' is waitlisted (unimplemented_nodes) but is not a contract node (stale)")
        elif node in inv.node_sites:
            out.append(f"[waitlist] '{node}' is waitlisted (unimplemented_nodes) but the design lab already renders it ({inv.node_sites[node]}) — stale mask, remove the entry")
    for overlay in sorted(wl.unimplemented_overlays):
        if overlay not in model.overlays:
            out.append(f"[waitlist] '{overlay}' is waitlisted (unimplemented_overlays) but is not a contract overlay (stale)")
        elif overlay in inv.overlay_sites:
            out.append(f"[waitlist] '{overlay}' is waitlisted (unimplemented_overlays) but the design lab already renders it ({inv.overlay_sites[overlay]}) — stale mask, remove the entry")
    for node in sorted(wl.pending_code_nodes):
        if node not in inv.node_sites and node not in inv.action_namespaces:
            out.append(f"[waitlist] '{node}' is waitlisted (pending_code_nodes) but the design lab no longer references it (stale)")
    for key in sorted(wl.pending_code_actions):
        if key not in inv.action_sites:
            out.append(f"[waitlist] 'action:{key}' is waitlisted (pending_code_actions) but the design lab no longer wires it (stale)")
    for key in sorted(wl.pending_code_overlay_actions):
        if key not in inv.overlay_action_sites:
            out.append(f"[waitlist] 'overlay-action:{key}' is waitlisted but the design lab no longer wires it (stale)")
    for key in sorted(wl.contract_action_gaps):
        if key in inv.action_sites:
            out.append(f"[waitlist] 'action:{key}' is waitlisted (contract_action_gaps) but the design lab now has an element ({inv.action_sites[key]}) — stale mask, remove it")
    for key in sorted(wl.contract_overlay_action_gaps):
        if key in inv.overlay_action_sites:
            out.append(f"[waitlist] 'overlay-action:{key}' is waitlisted but the design lab now has an element ({inv.overlay_action_sites[key]}) — stale mask, remove it")
    return out


def evaluate(model: ContractModel, inv: CodeInventory, waitlist: Waitlist) -> list[str]:
    violations: list[str] = []
    violations += _waitlist_hygiene(model, inv, waitlist)

    # ---- unresolvable keys : ambiguity fails closed ---------------------
    for raw, site in sorted(inv.unresolved_action_sites.items()):
        violations.append(
            f"[code->contract] design lab wires an unresolvable navigation key "
            f"'{raw}' (interpolated / concatenated / non-literal) — use a literal "
            f"'action:<node>.<action>' so parity can be verified ({site})"
        )

    # ---- direction 1 : code -> contract ---------------------------------
    for node, site in sorted(inv.node_sites.items()):
        if node in model.nodes or node in waitlist.pending_code_nodes:
            continue
        violations.append(
            f"[code->contract] design lab renders node '{node}' that is not declared "
            f"in the navigation contract ({site})"
        )

    for key, site in sorted(inv.action_sites.items()):
        node, action = key.split(".", 1)
        if key in waitlist.pending_code_actions:
            continue
        if node not in model.nodes:
            if node in waitlist.pending_code_nodes:
                continue
            violations.append(
                f"[code->contract] design lab wires control 'action:{key}' but node "
                f"'{node}' is not in the navigation contract ({site})"
            )
            continue
        declared = set(model.actions.get(node, {})) | AUTO_INJECTED_ACTIONS
        if action not in declared:
            violations.append(
                f"[code->contract] design lab wires control 'action:{key}' but action "
                f"'{action}' is not declared on node '{node}' ({site})"
            )

    for overlay, site in sorted(inv.overlay_sites.items()):
        if overlay in model.overlays or overlay in waitlist.pending_code_overlays:
            continue
        violations.append(
            f"[code->contract] design lab renders overlay '{overlay}' not declared in "
            f"the navigation contract ({site})"
        )

    for key, site in sorted(inv.overlay_action_sites.items()):
        overlay, action = key.split(".", 1)
        if key in waitlist.pending_code_overlay_actions:
            continue
        if overlay not in model.overlays:
            violations.append(
                f"[code->contract] design lab wires 'overlay-action:{key}' but overlay "
                f"'{overlay}' is not in the navigation contract ({site})"
            )
        elif action not in model.overlays[overlay]:
            violations.append(
                f"[code->contract] design lab wires 'overlay-action:{key}' but action "
                f"'{action}' is not declared on overlay '{overlay}' ({site})"
            )

    # ---- direction 2 : contract -> code (nodes) -------------------------
    for node in sorted(model.nodes):
        if node in waitlist.unimplemented_nodes:
            continue
        if node not in inv.node_sites:
            violations.append(
                f"[contract->code] contract node '{node}' has no design-lab screen "
                f"(no `nodeId: '{node}'`) and is not on the explicit waitlist "
                f"({CONTRACT_RELPATH})"
            )
            continue
        for action_id, ca in model.actions.get(node, {}).items():
            if action_id in AUTO_INJECTED_ACTIONS and inv.has_auto_safe_exit:
                continue
            if not _action_requires_element(ca, model, inv):
                continue
            key = f"{node}.{action_id}"
            if key in inv.action_sites or key in waitlist.contract_action_gaps:
                continue
            dest = ", ".join(ca.destinations) or ca.overlay or "(back)"
            violations.append(
                f"[contract->code] contract declares control 'action:{key}' -> {dest} "
                f"but the design lab has no interactive element for it "
                f"({CONTRACT_RELPATH})"
            )

    # ---- direction 2 : contract -> code (overlays) ----------------------
    for overlay in sorted(model.overlays):
        if overlay in waitlist.unimplemented_overlays:
            continue
        if overlay not in inv.overlay_sites:
            violations.append(
                f"[contract->code] contract overlay '{overlay}' has no design-lab "
                f"surface (no `overlay:{overlay}`) and is not on the explicit waitlist "
                f"({CONTRACT_RELPATH})"
            )
            continue
        for action_id in sorted(model.overlays[overlay]):
            key = f"{overlay}.{action_id}"
            if key in inv.overlay_action_sites or key in waitlist.contract_overlay_action_gaps:
                continue
            violations.append(
                f"[contract->code] contract declares 'overlay-action:{key}' but the "
                f"design lab has no interactive element for it ({CONTRACT_RELPATH})"
            )

    return violations


# --------------------------------------------------------------------------
# runner / CLI
# --------------------------------------------------------------------------


def _presence(root: Path) -> tuple[bool, bool]:
    root = Path(root)
    return (
        (root / CONTRACT_RELPATH).is_file(),
        (root / LAB_RELPATH).is_dir(),
    )


def run(
    root: Path,
    waitlist_path: Path | None = DEFAULT_WAITLIST,
) -> tuple[str, list[str]]:
    """Return (status, violations). status is 'noop' when BOTH the contract and
    the design lab are absent, 'half' when exactly one is present (fail-closed),
    else 'checked'."""
    root = Path(root)
    has_contract, has_lab = _presence(root)
    if not has_contract and not has_lab:
        return "noop", []
    if has_contract != has_lab:
        missing = LAB_RELPATH if has_contract else CONTRACT_RELPATH
        present = CONTRACT_RELPATH if has_contract else LAB_RELPATH
        return "half", [
            f"[presence] {present} is present but {missing} is missing — the "
            f"navigation contract and its design lab must land and leave together; "
            f"a half-present tree cannot be checked and is not a valid no-op"
        ]
    model = build_contract_model(load_contract(root / CONTRACT_RELPATH))
    inv = scan_lab(root / LAB_RELPATH, root)
    waitlist = load_waitlist(waitlist_path)
    return "checked", evaluate(model, inv, waitlist)


def explain(model: ContractModel, inv: CodeInventory, waitlist: Waitlist, node_id: str) -> str:
    if node_id not in model.nodes:
        return f"node '{node_id}' is not declared in {CONTRACT_RELPATH}"
    node = model.nodes[node_id]
    lines: list[str] = []
    lines.append(f"node: {node_id}")
    lines.append(f"  purpose: {node.get('purpose', '(none)')}")
    lines.append(f"  requires_account: {node.get('requires_account')}")
    if node.get("terminal"):
        lines.append("  terminal: true")
    if node.get("renderer"):
        lines.append(f"  renderer: {node['renderer']}")
    if node.get("temporal_guard"):
        lines.append(f"  temporal_guard: {node['temporal_guard']}")
    if node_id in waitlist.unimplemented_nodes:
        status = "WAITLISTED (unimplemented — deferred)"
    elif node_id in inv.node_sites:
        status = f"implemented at {inv.node_sites[node_id]}"
    else:
        status = "MISSING (not implemented, not waitlisted)"
    lines.append(f"  implementation: {status}")
    lines.append("  actions:")
    for action_id, ca in model.actions.get(node_id, {}).items():
        dest = ", ".join(ca.destinations) or (f"overlay:{ca.overlay}" if ca.overlay else "(no route)")
        key = f"{node_id}.{action_id}"
        if action_id in AUTO_INJECTED_ACTIONS:
            elem = "auto-injected (safe-exit header)"
        elif key in inv.action_sites:
            elem = f"element at {inv.action_sites[key]}"
        elif key in waitlist.contract_action_gaps:
            elem = "WAITLISTED gap (no element yet)"
        else:
            elem = "no element"
        lines.append(f"    - {action_id} -> {dest}  [{elem}]")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT), help="repo root to scan")
    parser.add_argument("--explain", metavar="NODE", help="print the contract of a node")
    parser.add_argument(
        "--no-waitlist", action="store_true", help="ignore the shipped waitlist"
    )
    parser.add_argument("--waitlist", help="explicit waitlist path")
    args = parser.parse_args(argv)

    root = Path(args.root)
    if args.no_waitlist:
        waitlist_path: Path | None = None
    elif args.waitlist:
        waitlist_path = Path(args.waitlist)
    else:
        waitlist_path = DEFAULT_WAITLIST

    contract_path = root / CONTRACT_RELPATH
    lab_dir = root / LAB_RELPATH

    if args.explain:
        if not contract_path.is_file():
            print(f"no-op: {CONTRACT_RELPATH} absent on this base")
            return 0
        model = build_contract_model(load_contract(contract_path))
        inv = scan_lab(lab_dir, root) if lab_dir.is_dir() else CodeInventory()
        print(explain(model, inv, load_waitlist(waitlist_path), args.explain))
        return 0

    status, violations = run(root, waitlist_path)
    if status == "noop":
        print(
            "no-op: navigation contract and design lab both absent on this base "
            "(nothing to check) — green."
        )
        return 0
    if violations:
        print(
            f"NAVIGATION CONTRACT GUARD: {len(violations)} violation(s) between "
            f"{CONTRACT_RELPATH} and {LAB_RELPATH}:"
        )
        for v in violations:
            print(f"  {v}")
        return 1
    print(
        "OK mint_next_navigation_contract: contract <-> design lab are in "
        "bidirectional parity (waitlist honoured)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
