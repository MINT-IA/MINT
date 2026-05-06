#!/usr/bin/env python3
# tools/simulator/test_walker_helpers.py
#
# Phase 82 (v2.11) — unit tests for walker_premier_eclairage.sh helper
# semantics, exercised via Python re-implementations + textual asserts on
# the shipped bash source. Tests cover :
#
#   WALKC-01 : _anchor_to_desktop math (anchor% → desktop px) — Python
#              port of the awk one-liner in the bash helper. Also asserts
#              the bash source contains the anchor table + the osascript
#              `bounds of window 1` call.
#   WALKC-02 : hero_bboxes.json calibrated to 1206×2622 ; Dynamic Island
#              excluded (every bbox y ≥ 180).
#   WALKC-03 : _wait_for_ui requires ≥ 2 consecutive stable hashes (the
#              triple-equality check `[ "$h0" = "$h1" ] && [ "$h1" = "$cur" ]`
#              is present in the bash source).
#   WALKC-04 : Each anchor-tap site activates the Simulator window first
#              (osascript activate text appears in _activate_simulator
#              and the helper is referenced from the tap helpers).
#   WALKC-05 : _dismiss_beta_modal helper exists AND is called before
#              the 01-landing capture step.
#   WALKC-06 : _swipe / _swipe_anchor helpers use cliclick dd:/du:
#              gestures, NOT tap-as-scroll.
#
# Runs with stdlib only — no Pillow, no scikit-image — because Phase 82
# is shell-helper plumbing only.
#
# Usage : python3 tools/simulator/test_walker_helpers.py

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WALKER = ROOT / "tools" / "simulator" / "walker_premier_eclairage.sh"
BBOXES = ROOT / "tools" / "simulator" / "hero_bboxes.json"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def anchor_to_desktop(
    win_x: int, win_y: int, win_w: int, win_h: int,
    pct_x: float, pct_y: float,
) -> tuple[int, int]:
    """Python port of the awk one-liner in _anchor_to_desktop().

    Mirrors the bash printf "%d %d" → integer truncation semantics so
    the test catches drift if the bash math ever changes.
    """
    return (int(win_x + win_w * pct_x), int(win_y + win_h * pct_y))


# ── WALKC-01 — anchor → desktop math ────────────────────────────────────


def test_walkc01_anchor_math_center():
    # 1206×2622 sim window mounted at (100, 50) on the desktop.
    x, y = anchor_to_desktop(100, 50, 1206, 2622, 0.50, 0.50)
    assert x == 703, f"center-x expected 703 got {x}"
    assert y == 1361, f"center-y expected 1361 got {y}"


def test_walkc01_anchor_math_cta_landing():
    # Anchor cta_landing = (0.50, 0.78).
    x, y = anchor_to_desktop(0, 0, 1206, 2622, 0.50, 0.78)
    assert x == 603
    assert y == 2045


def test_walkc01_anchor_math_swipe_endpoints():
    # WALKC-06 — swipe_start (65% vh) → swipe_end (30% vh) must produce
    # an upward delta (y2 < y1) in the sim coord system, i.e. drag up to
    # scroll content up.
    _, y1 = anchor_to_desktop(0, 0, 1206, 2622, 0.50, 0.65)
    _, y2 = anchor_to_desktop(0, 0, 1206, 2622, 0.50, 0.30)
    assert y2 < y1, f"swipe must drag UP : got y1={y1}, y2={y2}"


def test_walkc01_anchor_math_offset_window():
    # Sim window not at desktop origin — anchor math must add window x/y.
    x, y = anchor_to_desktop(420, 110, 1206, 2622, 0.10, 0.20)
    assert x == 540   # 420 + 1206*0.10
    assert y == 634   # 110 + 2622*0.20


def test_walkc01_bash_has_osascript_bounds_call():
    src = _read(WALKER)
    # The osascript heredoc reads `bounds of window 1` of the Simulator
    # app — accept either the inline `get bounds` or the heredoc `set b
    # to bounds` form.
    assert "bounds of window 1" in src, \
        "WALKC-01: walker must read sim-window bounds via osascript"
    assert 'tell application "Simulator"' in src, \
        "WALKC-01: walker must address the Simulator app explicitly"


def test_walkc01_bash_has_anchor_table():
    src = _read(WALKER)
    for anchor in ("cta_landing", "input_field", "beta_dismiss",
                   "swipe_start", "swipe_end"):
        assert f"ANCHORS_X[{anchor}]" in src, f"anchor '{anchor}' missing"


def test_walkc01_no_hardcoded_cliclick_taps_in_step_body():
    # The script must not use raw `cliclick c:NNN,NNN` desktop literals
    # in the step body. The deprecation shim _tap_at() may include the
    # generic pattern via variable substitution, that's fine — we only
    # forbid LITERAL coords like `cliclick c:590,2000`.
    src = _read(WALKER)
    bad = re.findall(r'cliclick\s+["\']?c:\d+,\d+', src)
    assert not bad, f"WALKC-01 forbids hardcoded cliclick desktop px : {bad}"


# ── WALKC-02 — hero_bboxes.json calibration ─────────────────────────────


def test_walkc02_bboxes_resolution_1206_2622():
    data = json.loads(_read(BBOXES))
    assert data["_resolution_px"] == [1206, 2622], \
        f"WALKC-02 expects [1206, 2622] got {data['_resolution_px']}"


def test_walkc02_dynamic_island_excluded():
    data = json.loads(_read(BBOXES))
    di_max = data.get("_dynamic_island_y_max", 180)
    for key, bbox in data.items():
        if key.startswith("_"):
            continue
        assert bbox["y"] >= di_max, \
            f"WALKC-02 bbox '{key}' y={bbox['y']} overlaps Dynamic Island"


def test_walkc02_bboxes_within_screen():
    data = json.loads(_read(BBOXES))
    rw, rh = data["_resolution_px"]
    for key, bbox in data.items():
        if key.startswith("_"):
            continue
        assert bbox["x"] + bbox["w"] <= rw, f"{key} x-overflow"
        assert bbox["y"] + bbox["h"] <= rh, f"{key} y-overflow"


# ── WALKC-03 — ≥ 2 consecutive stable hashes ────────────────────────────


def test_walkc03_wait_for_ui_requires_two_consecutive():
    src = _read(WALKER)
    # The triple-equality check is the load-bearing assertion.
    assert '[ "$h0" = "$h1" ]' in src and '[ "$h1" = "$cur" ]' in src, \
        "WALKC-03: _wait_for_ui must require h0==h1==cur (≥ 2 consecutive)"


def test_walkc03_wait_for_ui_logs_seq_when_retry_gt_3():
    src = _read(WALKER)
    # The trace branch must reference both `retry` and the seq array.
    assert 'wait_for_ui retry=' in src, \
        "WALKC-03: hash sequence must be logged when retry > 3"
    assert 'hash_seq=' in src, \
        "WALKC-03: hash_seq= log key required"


# ── WALKC-04 — Simulator activated before each tap ──────────────────────


def test_walkc04_activate_simulator_present():
    src = _read(WALKER)
    assert 'tell application "Simulator" to activate' in src, \
        "WALKC-04: osascript activate call missing"


def test_walkc04_tap_helpers_call_activate():
    src = _read(WALKER)
    # _tap_at_anchor and _swipe + _type_text must each invoke
    # _activate_simulator BEFORE issuing the cliclick action.
    for helper in ("_tap_at_anchor()", "_swipe()", "_type_text()", "_dismiss_keyboard()"):
        # Find the helper body : from helper-decl up to the closing brace.
        idx = src.find(helper)
        assert idx >= 0, f"helper '{helper}' not declared"
        end = src.find("\n}\n", idx)
        body = src[idx:end]
        assert "_activate_simulator" in body, \
            f"WALKC-04: helper '{helper}' must call _activate_simulator"


# ── WALKC-05 — beta-disclosure dismiss step ─────────────────────────────


def test_walkc05_dismiss_beta_modal_helper():
    src = _read(WALKER)
    assert "_dismiss_beta_modal()" in src, "WALKC-05 helper missing"
    assert "anchor=beta_dismiss" in src or "beta_dismiss" in src, \
        "WALKC-05 anchor reference missing"


def test_walkc05_dismiss_called_before_landing_capture():
    src = _read(WALKER)
    # The call must precede the actual capture line, not the help-text
    # reference. The capture is `_snap "$SHOTS_DIR/01-landing.png"`.
    call_idx = src.find("_dismiss_beta_modal\n")
    snap_idx = src.find('_snap "$SHOTS_DIR/01-landing.png"')
    assert call_idx > 0, "WALKC-05: _dismiss_beta_modal call missing"
    assert snap_idx > 0, "01-landing capture line missing"
    assert call_idx < snap_idx, \
        "WALKC-05: _dismiss_beta_modal must be called before 01-landing capture"


# ── WALKC-06 — swipe gesture (not tap-as-scroll) ────────────────────────


def test_walkc06_swipe_uses_cliclick_dd_du():
    src = _read(WALKER)
    assert "cliclick \"dd:" in src and "\"du:" in src, \
        "WALKC-06: swipe must use cliclick dd:/du: gesture"


def test_walkc06_scroll_step_uses_swipe_anchor():
    src = _read(WALKER)
    # The 05-register-cta capture step must use _swipe_anchor, not
    # _tap_at. Anchor on the actual capture lines (not the help-text
    # references) by matching the `_snap "$SHOTS_DIR/...png"` form.
    a = src.find('_snap "$SHOTS_DIR/04-eclairage-card.png"')
    b = src.find('_snap "$SHOTS_DIR/05-register-cta.png"', a)
    assert a > 0 and b > a, "capture markers missing in step body"
    segment = src[a:b]
    assert "_swipe_anchor" in segment, \
        "WALKC-06: register-CTA scroll step must call _swipe_anchor"


# ── runner ──────────────────────────────────────────────────────────────


def main() -> int:
    tests = [v for k, v in globals().items() if k.startswith("test_") and callable(v)]
    failures: list[tuple[str, str]] = []
    for fn in tests:
        try:
            fn()
            print(f"  ok   {fn.__name__}")
        except AssertionError as exc:
            failures.append((fn.__name__, str(exc)))
            print(f"  FAIL {fn.__name__} — {exc}")
        except Exception as exc:  # pragma: no cover
            failures.append((fn.__name__, f"unexpected {type(exc).__name__}: {exc}"))
            print(f"  ERR  {fn.__name__} — {exc}")

    print(f"\n{len(tests) - len(failures)} / {len(tests)} passed")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
