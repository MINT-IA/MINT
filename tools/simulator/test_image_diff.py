#!/usr/bin/env python3
"""Smoke test for image_diff.py — Phase 74.

Synthesizes 2 PNGs in /tmp, diffs them, asserts result format. Exits 0
on success, non-zero on assertion failure.

Run :
    python3 tools/simulator/test_image_diff.py
"""

from __future__ import annotations

import os
import sys
import tempfile

import numpy as np
from PIL import Image

# Allow imports when invoked from repo root or alongside the script.
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import image_diff  # noqa: E402


def _write_png(path: str, arr: np.ndarray) -> None:
    Image.fromarray(arr).save(path, format="PNG")


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        # 200x300 RGB, mostly mid-grey
        ref = np.full((300, 200, 3), 128, dtype=np.uint8)
        cand_identical = ref.copy()
        cand_drift = ref.copy()
        # Inject a 60x100 red rectangle at (60, 100) → 6000 / 60000 = 10%
        # Big enough to fail both the SSIM (>=0.96) and the fallback
        # numpy abs-diff threshold (4%) modes.
        cand_drift[100:200, 60:120] = [255, 0, 0]

        ref_path = os.path.join(tmp, "ref.png")
        ident_path = os.path.join(tmp, "cand_identical.png")
        drift_path = os.path.join(tmp, "cand_drift.png")
        _write_png(ref_path, ref)
        _write_png(ident_path, cand_identical)
        _write_png(drift_path, cand_drift)

        out_dir = os.path.join(tmp, "out")

        # Identical case
        r1 = image_diff.diff(
            ref_path,
            ident_path,
            hero_bbox={"x": 0, "y": 0, "w": 200, "h": 300},
            threshold_pct=4.0,
            out_dir=out_dir,
        )
        assert isinstance(r1, dict), "diff() must return a dict"
        for key in (
            "diff_pct",
            "ssim",
            "passed",
            "diff_png",
            "reference",
            "candidate",
            "bbox",
            "ssim_threshold",
            "diff_pct_threshold",
        ):
            assert key in r1, f"missing key {key} in identical-case result"
        assert r1["passed"] is True, f"identical PNGs should pass : {r1}"
        assert r1["diff_pct"] == 0.0, f"identical PNGs diff_pct must be 0 : {r1}"
        assert r1["diff_png"] is not None and os.path.isfile(r1["diff_png"]), (
            f"diff PNG not written : {r1}"
        )

        # Drift case — 60x100 red rectangle = 10% of 200x300, > 4% threshold
        r2 = image_diff.diff(
            ref_path,
            drift_path,
            hero_bbox={"x": 0, "y": 0, "w": 200, "h": 300},
            threshold_pct=4.0,
            out_dir=out_dir,
        )
        assert r2["passed"] is False, f"red-square drift should fail : {r2}"
        assert r2["diff_pct"] > 4.0, (
            f"drift diff_pct should exceed threshold : {r2}"
        )

        # Bbox masking — same drift but bbox excludes the red square region
        r3 = image_diff.diff(
            ref_path,
            drift_path,
            hero_bbox={"x": 150, "y": 200, "w": 50, "h": 100},
            threshold_pct=4.0,
            out_dir=out_dir,
        )
        assert r3["passed"] is True, f"masked bbox should pass : {r3}"

        print(
            "[image_diff smoke] PASS — identical + drift + bbox-mask "
            "all behaved as expected"
        )
        print(f"[image_diff smoke]   identical : {r1}")
        print(f"[image_diff smoke]   drift     : {r2}")
        print(f"[image_diff smoke]   masked    : {r3}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
