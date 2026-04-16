"""Weighted ordinal Krippendorff α — pure-Python implementation.

Used by Phase 11 (VOICE-05) to validate inter-rater reliability of the voice
cursor reference phrases. 15 raters × 50 frozen reference phrases × blind
ordinal classification (N1..N5). Pass threshold: overall α ≥ 0.67 AND
per-level α ≥ 0.67 for the N4 / N5 subset.

This module deliberately implements the formula from scratch (no pip
``krippendorff`` package) so the math is auditable inline. The formula
follows Krippendorff (2011) "Computing Krippendorff's Alpha-Reliability"
and uses the coincidence-matrix form for the ordinal metric.

Input format
============
JSON file shaped like::

    {
      "levels": ["N1", "N2", "N3", "N4", "N5"],
      "ratings": {
        "<rater_id>": {"<item_id>": "<level>", ...},
        ...
      }
    }

Missing ratings are encoded by simply omitting the key (or using ``null``).
Items rated by fewer than 2 raters contribute 0 to the coincidence matrix
per Krippendorff's specification.

Output
======
``compute_alpha(...)`` returns a dict::

    {
      "alpha_overall": float,
      "alpha_per_level": {"N1": float, ..., "N5": float},
      "n_items": int,
      "n_raters": int,
      "n_pairable_units": int
    }

Per-level α is computed by collapsing labels into a binary "is this level /
is not this level" coding (with the nominal metric on the resulting binary)
which gives a per-level reliability slice usable by Phase 11 gates.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional, Union

Number = Union[int, float]


def load_ratings(path: Path) -> dict:
    """Load a ratings JSON file from disk."""
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _build_value_by_unit(
    ratings: Dict[str, Dict[str, str]],
    levels: List[str],
) -> Dict[str, List[int]]:
    """Return ``{item_id: [level_index, ...]}`` keyed by item.

    Each list is the multiset of ordinal indices given by raters for that
    item. Items rated by fewer than 2 raters are still returned (caller
    drops them). Missing values (``None``) are skipped.
    """
    level_index = {label: i for i, label in enumerate(levels)}
    by_unit: Dict[str, List[int]] = {}
    for _rater_id, item_map in ratings.items():
        for item_id, label in item_map.items():
            if label is None:
                continue
            if label not in level_index:
                raise ValueError(
                    f"Rating '{label}' for item '{item_id}' is not in levels {levels}"
                )
            by_unit.setdefault(item_id, []).append(level_index[label])
    return by_unit


def _ordinal_distance(c: int, k: int, n_c: List[int]) -> float:
    """Krippendorff ordinal metric (squared distance) between ranks c and k.

    Per Krippendorff (2011) §5.4: the ordinal distance for two ordinal
    categories c, k is the *squared* sum of the marginal frequencies of the
    categories strictly between them, plus half of the marginal frequencies
    of c and k themselves.
    """
    if c == k:
        return 0.0
    lo, hi = (c, k) if c < k else (k, c)
    inner = sum(n_c[lo + 1 : hi])
    s = inner + (n_c[lo] + n_c[hi]) / 2.0
    return s * s


def _compute_alpha_ordinal(
    by_unit: Dict[str, List[int]],
    n_levels: int,
) -> float:
    """Compute Krippendorff α with the ordinal metric from per-unit ratings."""
    # Drop items rated by fewer than 2 raters (they contribute 0).
    pairable_units = {u: vs for u, vs in by_unit.items() if len(vs) >= 2}
    if not pairable_units:
        return float("nan")

    # Coincidence matrix o[c][k] (n_levels × n_levels).
    o = [[0.0] * n_levels for _ in range(n_levels)]
    for _u, vs in pairable_units.items():
        m_u = len(vs)
        # For each ORDERED pair (i, j) with i != j in this unit, add 1/(m_u-1).
        for i_idx, c in enumerate(vs):
            for j_idx, k in enumerate(vs):
                if i_idx == j_idx:
                    continue
                o[c][k] += 1.0 / (m_u - 1)

    # Marginals n_c = sum over k of o[c][k] (= row sums; matrix is symmetric).
    n_c = [sum(row) for row in o]
    n_total = sum(n_c)
    if n_total == 0:
        return float("nan")

    # Numerator: observed disagreement.
    do_num = 0.0
    for c in range(n_levels):
        for k in range(n_levels):
            if c == k:
                continue
            do_num += o[c][k] * _ordinal_distance(c, k, n_c)

    # Denominator: expected disagreement under chance.
    de_num = 0.0
    for c in range(n_levels):
        for k in range(n_levels):
            if c == k:
                continue
            de_num += n_c[c] * n_c[k] * _ordinal_distance(c, k, n_c)
    de_denom = n_total - 1.0
    if de_denom <= 0 or de_num == 0:
        return float("nan")

    do = do_num  # numerator already in the form Σ o_ck δ²
    de = de_num / de_denom

    return 1.0 - (do / de)


def _compute_alpha_nominal_binary(
    by_unit: Dict[str, List[int]],
    target_index: int,
) -> float:
    """Per-level α via binary collapse (1 = is target, 0 = otherwise).

    Uses the nominal metric (δ² = 0 if equal else 1) on the binary recoding.
    """
    pairable_units = {u: vs for u, vs in by_unit.items() if len(vs) >= 2}
    if not pairable_units:
        return float("nan")

    o = [[0.0, 0.0], [0.0, 0.0]]
    for _u, vs in pairable_units.items():
        m_u = len(vs)
        binary = [1 if v == target_index else 0 for v in vs]
        for i_idx, c in enumerate(binary):
            for j_idx, k in enumerate(binary):
                if i_idx == j_idx:
                    continue
                o[c][k] += 1.0 / (m_u - 1)

    n_c = [sum(row) for row in o]
    n_total = sum(n_c)
    if n_total == 0:
        return float("nan")

    do = o[0][1] + o[1][0]  # nominal: δ² = 1 for unequal pairs only
    de_num = (n_c[0] * n_c[1] + n_c[1] * n_c[0])
    de_denom = n_total - 1.0
    if de_denom <= 0 or de_num == 0:
        return float("nan")
    de = de_num / de_denom
    return 1.0 - (do / de)


def compute_alpha(
    ratings_or_path: Union[dict, str, Path],
    levels: Optional[List[str]] = None,
) -> dict:
    """Compute Krippendorff α (overall ordinal + per-level binary) for a ratings set.

    Accepts either a parsed dict or a path to a JSON file. ``levels`` defaults
    to ``["N1","N2","N3","N4","N5"]`` and is overridden by the ``levels`` key
    in the input dict if present.
    """
    if isinstance(ratings_or_path, (str, Path)):
        data = load_ratings(Path(ratings_or_path))
    else:
        data = ratings_or_path

    used_levels = data.get("levels") or levels or ["N1", "N2", "N3", "N4", "N5"]
    ratings: Dict[str, Dict[str, str]] = data["ratings"]

    by_unit = _build_value_by_unit(ratings, used_levels)
    pairable_units = {u: vs for u, vs in by_unit.items() if len(vs) >= 2}

    alpha_overall = _compute_alpha_ordinal(by_unit, n_levels=len(used_levels))
    alpha_per_level = {
        label: _compute_alpha_nominal_binary(by_unit, target_index=i)
        for i, label in enumerate(used_levels)
    }

    return {
        "alpha_overall": alpha_overall,
        "alpha_per_level": alpha_per_level,
        "n_items": len(by_unit),
        "n_raters": len(ratings),
        "n_pairable_units": len(pairable_units),
    }


if __name__ == "__main__":  # pragma: no cover
    import sys

    if len(sys.argv) != 2:
        print("Usage: python krippendorff_alpha.py <ratings.json>")
        sys.exit(2)
    result = compute_alpha(sys.argv[1])
    print(f"alpha_overall    = {result['alpha_overall']:.4f}")
    print(f"n_items          = {result['n_items']}")
    print(f"n_raters         = {result['n_raters']}")
    print(f"n_pairable_units = {result['n_pairable_units']}")
    print("alpha_per_level:")
    for label, value in result["alpha_per_level"].items():
        print(f"  {label}: {value:.4f}")
