#!/usr/bin/env python3
"""Synthetic-fixture tests for the MINT Next navigation contract guard.

TDD: every case below is written against tiny in-memory fixtures (a minimal
navigation.yaml + a fake design-lab Dart file + an explicit waitlist) so the
guard's bidirectional parity logic is exercised without the real MINT Next
stack being present. These tests must run and pass on `dev`, where
`product/mint_next/**` does not exist yet.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

from tools.checks import mint_next_navigation_contract as guard

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/mint_next_navigation_contract.py"


# --------------------------------------------------------------------------
# fixture builders
# --------------------------------------------------------------------------

MINIMAL_CONTRACT = textwrap.dedent(
    """
    schema_version: 1
    journey_id: fixture_journey
    entry_node: home
    overlays:
      safe_exit:
        actions:
          resume: {operation: close}
          leave: {to: gone}
    nodes:
      home:
        purpose: Entry.
        requires_account: false
        actions:
          start: {to: step_one}
          open_safe_exit: {overlay: safe_exit}
      step_one:
        purpose: A middle node.
        requires_account: false
        actions:
          continue: {to: step_two, guard: something}
          back: {to: home}
          type_amount: {mutation: amount, value: entered}
          open_safe_exit: {overlay: safe_exit}
      step_two:
        purpose: Reached only when built.
        requires_account: false
        actions:
          finish: {to: gone}
          back: {to: step_one}
          open_safe_exit: {overlay: safe_exit}
      gone:
        terminal: true
        purpose: Terminal.
        requires_account: false
        actions:
          restart: {to: home}
    """
).strip()


def _write_contract(root: Path, body: str = MINIMAL_CONTRACT) -> Path:
    path = root / "product/mint_next/batch6/navigation.yaml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body + "\n", encoding="utf-8")
    return path


def _write_lab(root: Path, dart: str) -> Path:
    lab = root / "product/mint_next/batch7/design_lab"
    (lab / "lib").mkdir(parents=True, exist_ok=True)
    (lab / "lib/design_lab_app.dart").write_text(dart, encoding="utf-8")
    return lab


# A design lab that implements home + step_one faithfully, with the auto
# injected safe exit and a row-scoped control that must NOT be treated as a
# navigation-graph action. step_two/gone are intentionally left unbuilt.
FAITHFUL_LAB = textwrap.dedent(
    """
    class HomePage extends StatelessWidget {
      Widget build(BuildContext context) => _Page(
        nodeId: 'home',
        actions: [
          MintAction(key: ValueKey('action:home.start'), onPressed: onStart),
        ],
      );
    }
    class StepOnePage extends StatelessWidget {
      Widget build(BuildContext context) => _Page(
        nodeId: 'step_one',
        actions: [
          MintAction(key: ValueKey('action:step_one.continue'), onPressed: onNext),
          MintAction(key: ValueKey('action:step_one.back'), onPressed: onBack),
          RowControl(key: ValueKey('action:remove_row:${row.id}')),
        ],
      );
    }
    class _SafeExitHeader {
      Widget build() => IconButton(key: ValueKey('action:$nodeId.open_safe_exit'));
    }
    class _SafeExitOverlay {
      Widget build() => Column(children: [
        Semantics(key: ValueKey('overlay:safe_exit')),
        MintAction(key: ValueKey('overlay-action:safe_exit.resume')),
        MintAction(key: ValueKey('overlay-action:safe_exit.leave')),
      ]);
    }
    """
).strip()


def _base_waitlist() -> dict:
    # step_two and gone are legitimately not built yet.
    return {"unimplemented_nodes": ["step_two", "gone"]}


def _run_eval(root: Path, waitlist: dict | None) -> list[str]:
    model = guard.build_contract_model(
        guard.load_contract(root / "product/mint_next/batch6/navigation.yaml")
    )
    inv = guard.scan_lab(root / "product/mint_next/batch7/design_lab", root)
    wl = guard.waitlist_from_dict(waitlist or {})
    return guard.evaluate(model, inv, wl)


# --------------------------------------------------------------------------
# tests
# --------------------------------------------------------------------------


def test_parity_ok_passes(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    violations = _run_eval(tmp_path, _base_waitlist())
    assert violations == [], violations


def test_row_scoped_action_not_treated_as_navigation(tmp_path: Path) -> None:
    # The faithful lab contains ValueKey('action:remove_row:${row.id}'); it must
    # be ignored (row-scoped control, not a graph transition).
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    inv = guard.scan_lab(tmp_path / "product/mint_next/batch7/design_lab", tmp_path)
    assert "remove_row" not in {k.split(".")[0] for k in inv.action_sites}
    assert all("remove_row" not in k for k in inv.action_sites)


def test_auto_injected_safe_exit_satisfies_declared_action(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    inv = guard.scan_lab(tmp_path / "product/mint_next/batch7/design_lab", tmp_path)
    assert inv.has_auto_safe_exit is True
    # No literal action:home.open_safe_exit is emitted, yet parity holds.
    assert "home.open_safe_exit" not in inv.action_sites
    assert _run_eval(tmp_path, _base_waitlist()) == []


def test_declared_node_without_screen_fails(tmp_path: Path) -> None:
    # Drop step_one from the lab but keep it out of the waitlist -> contract
    # node with no screen and not deferred = violation.
    _write_contract(tmp_path)
    lab_without_step_one = FAITHFUL_LAB.replace("nodeId: 'step_one'", "nodeId: 'placeholder_only'")
    _write_lab(tmp_path, lab_without_step_one)
    violations = _run_eval(tmp_path, _base_waitlist())
    joined = "\n".join(violations)
    assert "step_one" in joined
    assert "no design-lab screen" in joined or "no screen" in joined
    assert any("contract->code" in v for v in violations)


def test_button_without_declaration_fails_with_path_line(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    rogue = FAITHFUL_LAB.replace(
        "RowControl(key: ValueKey('action:remove_row:${row.id}')),",
        "MintAction(key: ValueKey('action:step_one.teleport'), onPressed: onGo),",
    )
    _write_lab(tmp_path, rogue)
    violations = _run_eval(tmp_path, _base_waitlist())
    joined = "\n".join(violations)
    assert "step_one.teleport" in joined
    assert any("code->contract" in v for v in violations)
    # path:line must be cited
    assert "design_lab_app.dart:" in joined


def test_undeclared_node_button_fails(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    rogue = FAITHFUL_LAB.replace(
        "RowControl(key: ValueKey('action:remove_row:${row.id}')),",
        "MintAction(key: ValueKey('action:ghost_node.tap')),",
    )
    _write_lab(tmp_path, rogue)
    violations = _run_eval(tmp_path, _base_waitlist())
    joined = "\n".join(violations)
    assert "ghost_node" in joined
    assert any("code->contract" in v for v in violations)


def test_action_declared_without_element_fails(tmp_path: Path) -> None:
    # step_one implemented, but its 'back' element is removed. back to home
    # (implemented) is required -> violation.
    _write_contract(tmp_path)
    no_back = FAITHFUL_LAB.replace(
        "      MintAction(key: ValueKey('action:step_one.back'), onPressed: onBack),\n",
        "",
    )
    _write_lab(tmp_path, no_back)
    violations = _run_eval(tmp_path, _base_waitlist())
    joined = "\n".join(violations)
    assert "step_one.back" in joined
    assert any("contract->code" in v for v in violations)


def test_field_only_action_not_required_as_button(tmp_path: Path) -> None:
    # step_one.type_amount is a mutation-only field action (no to/overlay) and
    # must NOT be demanded as a discrete keyed button.
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    violations = _run_eval(tmp_path, _base_waitlist())
    assert all("type_amount" not in v for v in violations), violations


def test_action_to_unbuilt_node_not_required(tmp_path: Path) -> None:
    # step_one.continue routes to step_two, which is waitlisted (unbuilt). If
    # the continue button is absent, that must NOT be a violation (cannot wire
    # a button to a screen that does not exist yet).
    _write_contract(tmp_path)
    no_continue = FAITHFUL_LAB.replace(
        "      MintAction(key: ValueKey('action:step_one.continue'), onPressed: onNext),\n",
        "",
    )
    _write_lab(tmp_path, no_continue)
    violations = _run_eval(tmp_path, _base_waitlist())
    assert all("step_one.continue" not in v for v in violations), violations


def test_explicit_waitlist_honors_unimplemented_and_pending(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    rogue = FAITHFUL_LAB.replace(
        "RowControl(key: ValueKey('action:remove_row:${row.id}')),",
        "MintAction(key: ValueKey('action:step_one.teleport'), onPressed: onGo),",
    )
    _write_lab(tmp_path, rogue)
    waitlist = _base_waitlist()
    waitlist["pending_code_actions"] = ["step_one.teleport"]
    violations = _run_eval(tmp_path, waitlist)
    assert violations == [], violations


def test_stale_waitlist_node_flagged(tmp_path: Path) -> None:
    # home is implemented; waitlisting it as unimplemented is stale masking.
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    waitlist = {"unimplemented_nodes": ["step_two", "gone", "home"]}
    violations = _run_eval(tmp_path, waitlist)
    joined = "\n".join(violations)
    assert "home" in joined
    assert any("waitlist" in v for v in violations)
    assert any("stale" in v for v in violations)


def test_waitlist_unknown_node_flagged(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    waitlist = {"unimplemented_nodes": ["step_two", "gone", "not_a_real_node"]}
    violations = _run_eval(tmp_path, waitlist)
    joined = "\n".join(violations)
    assert "not_a_real_node" in joined
    assert any("waitlist" in v for v in violations)


def test_presence_detection_noops_when_content_absent(tmp_path: Path) -> None:
    # No product/mint_next at all -> run() no-ops green.
    status, violations = guard.run(root=tmp_path)
    assert status == "noop"
    assert violations == []


def test_run_enforces_when_content_present(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    rogue = FAITHFUL_LAB.replace(
        "RowControl(key: ValueKey('action:remove_row:${row.id}')),",
        "MintAction(key: ValueKey('action:step_one.teleport'), onPressed: onGo),",
    )
    _write_lab(tmp_path, rogue)
    status, violations = guard.run(root=tmp_path, waitlist_path=None)
    assert status == "checked"
    assert any("step_one.teleport" in v for v in violations)


def test_cli_noop_exit_zero_on_bare_root(tmp_path: Path) -> None:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr + proc.stdout
    assert "no-op" in (proc.stdout + proc.stderr).lower()


def test_cli_fails_on_violation(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    rogue = FAITHFUL_LAB.replace(
        "RowControl(key: ValueKey('action:remove_row:${row.id}')),",
        "MintAction(key: ValueKey('action:step_one.teleport'), onPressed: onGo),",
    )
    _write_lab(tmp_path, rogue)
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(tmp_path), "--no-waitlist"],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 1, proc.stdout
    assert "step_one.teleport" in proc.stdout


def test_cli_explain_outputs_contract(tmp_path: Path) -> None:
    _write_contract(tmp_path)
    _write_lab(tmp_path, FAITHFUL_LAB)
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(tmp_path), "--explain", "step_one"],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    out = proc.stdout
    assert "step_one" in out
    assert "continue" in out and "back" in out
    assert "step_two" in out  # destination shown
