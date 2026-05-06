#!/usr/bin/env python3
"""image_diff.py — Phase 74 walker image diffing.

Compares two PNG screenshots inside an optional hero bounding box and
returns a structured pass/fail dict. Locked decisions (PANEL-VERDICT.md
sec.2) :

  - Pillow + scikit-image SSIM (numpy abs-diff fallback if scikit-image
    is unavailable).
  - SSIM threshold >= 0.96 inside hero bbox = pass.
  - Outputs a 3-panel composite diff PNG (ref | candidate | red overlay)
    plus a result.json keyed off the candidate filename.

CLI usage (called by walker_premier_eclairage.sh) :

    python3 tools/simulator/image_diff.py \\
        --reference goldens/julien_swiss/01-landing.png \\
        --candidate run/julien_swiss/screenshots/01-landing.png \\
        --bbox-key 01-landing \\
        --bboxes tools/simulator/hero_bboxes.json \\
        --out-dir run/julien_swiss/diff

Programmatic usage :

    from image_diff import diff
    result = diff(reference_png, candidate_png,
                  hero_bbox={"x": 0, "y": 800, "w": 1179, "h": 1200},
                  threshold_pct=4.0)
    # -> {"diff_pct": 1.7, "passed": True, "diff_png": ".../diff.png", ...}
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional

import numpy as np
from PIL import Image, ImageDraw, ImageFont

try:
    from skimage.metrics import structural_similarity as _ssim  # type: ignore
    _HAS_SSIM = True
except ImportError:  # pragma: no cover — fallback path covered by smoke test
    _HAS_SSIM = False

SSIM_PASS_THRESHOLD = 0.96
ABS_DIFF_TOLERANCE = 8  # per-channel value tolerance for numpy fallback


def _load_rgb(path: str) -> np.ndarray:
    """Load PNG as HxWx3 uint8 RGB array."""
    img = Image.open(path).convert("RGB")
    return np.asarray(img, dtype=np.uint8)


def _crop(arr: np.ndarray, bbox: Optional[dict]) -> np.ndarray:
    """Crop array to bbox or return full array."""
    if bbox is None:
        return arr
    x = max(0, int(bbox.get("x", 0)))
    y = max(0, int(bbox.get("y", 0)))
    w = int(bbox.get("w", arr.shape[1] - x))
    h = int(bbox.get("h", arr.shape[0] - y))
    h_max, w_max = arr.shape[:2]
    x2 = min(w_max, x + w)
    y2 = min(h_max, y + h)
    return arr[y:y2, x:x2]


def _numpy_diff_pct(a: np.ndarray, b: np.ndarray, tolerance: int) -> float:
    """Fallback : percent of pixels with abs-diff > tolerance on any channel."""
    if a.shape != b.shape:
        return 100.0
    delta = np.abs(a.astype(np.int16) - b.astype(np.int16))
    differs = np.any(delta > tolerance, axis=-1)
    return 100.0 * float(differs.sum()) / float(differs.size)


def _ssim_score(a: np.ndarray, b: np.ndarray) -> float:
    """Compute SSIM on RGB. Uses scikit-image when available."""
    if a.shape != b.shape:
        return 0.0
    # channel_axis=2 (RGB last). data_range=255 for uint8.
    return float(
        _ssim(a, b, channel_axis=2, data_range=255)  # type: ignore[arg-type]
    )


def _compose_three_panel(
    ref: np.ndarray,
    cand: np.ndarray,
    bbox: Optional[dict],
    out_path: str,
) -> None:
    """Write 3-panel composite PNG : ref | candidate | red overlay."""
    h, w = ref.shape[:2]
    # Ensure same size for cand
    if cand.shape != ref.shape:
        cand_img = Image.fromarray(cand).resize((w, h))
        cand = np.asarray(cand_img.convert("RGB"), dtype=np.uint8)
    # Red overlay: pixels where abs diff > tolerance get marked red on ref
    delta = np.abs(ref.astype(np.int16) - cand.astype(np.int16))
    differs = np.any(delta > ABS_DIFF_TOLERANCE, axis=-1)
    overlay = ref.copy()
    overlay[differs] = [255, 0, 0]
    # bbox outline on each panel
    panels = []
    for arr, label in ((ref, "REF"), (cand, "CAND"), (overlay, "DIFF")):
        img = Image.fromarray(arr).convert("RGB")
        draw = ImageDraw.Draw(img)
        if bbox is not None:
            x = int(bbox.get("x", 0))
            y = int(bbox.get("y", 0))
            bw = int(bbox.get("w", w - x))
            bh = int(bbox.get("h", h - y))
            draw.rectangle([(x, y), (x + bw, y + bh)], outline=(0, 255, 0), width=4)
        try:
            font = ImageFont.load_default()
        except Exception:  # pragma: no cover
            font = None
        draw.text((24, 24), label, fill=(255, 255, 0), font=font)
        panels.append(img)
    composite = Image.new("RGB", (w * 3, h), (0, 0, 0))
    for i, p in enumerate(panels):
        composite.paste(p, (i * w, 0))
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    composite.save(out_path, format="PNG", optimize=True)


def diff(
    reference_png: str,
    candidate_png: str,
    hero_bbox: Optional[dict] = None,
    threshold_pct: float = 4.0,
    out_dir: Optional[str] = None,
) -> dict:
    """Diff two PNGs inside hero_bbox. Returns structured result.

    Pass criterion :
        SSIM (when available) >= SSIM_PASS_THRESHOLD inside bbox
        OR fallback abs-diff pct <= threshold_pct.

    Returned dict :
        {
          "diff_pct":   <0..100>,         # always populated
          "ssim":       <0..1> or None,   # None if scikit-image missing
          "passed":     bool,
          "diff_png":   "<path>" or None, # written only if out_dir set
          "reference":  "<path>",
          "candidate":  "<path>",
        }
    """
    ref = _load_rgb(reference_png)
    cand = _load_rgb(candidate_png)
    ref_crop = _crop(ref, hero_bbox)
    cand_crop = _crop(cand, hero_bbox)

    diff_pct = _numpy_diff_pct(ref_crop, cand_crop, ABS_DIFF_TOLERANCE)
    ssim_score: Optional[float] = None
    if _HAS_SSIM and ref_crop.size > 0 and cand_crop.size > 0:
        ssim_score = _ssim_score(ref_crop, cand_crop)
        passed = ssim_score >= SSIM_PASS_THRESHOLD
    else:
        passed = diff_pct <= threshold_pct

    diff_png_path: Optional[str] = None
    if out_dir is not None:
        cand_basename = os.path.splitext(os.path.basename(candidate_png))[0]
        diff_png_path = os.path.join(out_dir, f"{cand_basename}_diff.png")
        _compose_three_panel(ref, cand, hero_bbox, diff_png_path)

    return {
        "diff_pct": round(diff_pct, 3),
        "ssim": round(ssim_score, 4) if ssim_score is not None else None,
        "passed": bool(passed),
        "diff_png": diff_png_path,
        "reference": os.path.abspath(reference_png),
        "candidate": os.path.abspath(candidate_png),
        "bbox": hero_bbox,
        "ssim_threshold": SSIM_PASS_THRESHOLD,
        "diff_pct_threshold": threshold_pct,
    }


# ── CLI ────────────────────────────────────────────────────────────────


def _bbox_from_key(bboxes_path: str, key: str) -> Optional[dict]:
    if not os.path.isfile(bboxes_path):
        return None
    with open(bboxes_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    val = data.get(key)
    if not isinstance(val, dict):
        return None
    return {k: v for k, v in val.items() if k in {"x", "y", "w", "h"}}


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(
        description="Phase 74 walker image diff (SSIM + bbox + 3-panel PNG)",
    )
    p.add_argument("--reference", required=True, help="reference PNG path")
    p.add_argument("--candidate", required=True, help="candidate PNG path")
    p.add_argument(
        "--bbox-key",
        default=None,
        help="hero bbox key (e.g. 01-landing) — looked up in --bboxes",
    )
    p.add_argument(
        "--bboxes",
        default=os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "hero_bboxes.json"
        ),
        help="path to hero_bboxes.json",
    )
    p.add_argument(
        "--threshold-pct",
        type=float,
        default=4.0,
        help="fallback abs-diff threshold (used when scikit-image absent)",
    )
    p.add_argument(
        "--out-dir",
        default=None,
        help="if set, write diff.png + result.json under this directory",
    )
    args = p.parse_args(argv)

    bbox = None
    if args.bbox_key is not None:
        bbox = _bbox_from_key(args.bboxes, args.bbox_key)

    result = diff(
        reference_png=args.reference,
        candidate_png=args.candidate,
        hero_bbox=bbox,
        threshold_pct=args.threshold_pct,
        out_dir=args.out_dir,
    )

    if args.out_dir is not None:
        os.makedirs(args.out_dir, exist_ok=True)
        cand_basename = os.path.splitext(os.path.basename(args.candidate))[0]
        result_path = os.path.join(args.out_dir, f"{cand_basename}_result.json")
        with open(result_path, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2, sort_keys=True)

    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0 if result["passed"] else 2


if __name__ == "__main__":
    sys.exit(main())
