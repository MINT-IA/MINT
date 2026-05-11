"""Phase 95 DAG-INVALIDATION — frequentiste bootstrap CIs (D-12).

200-iter resample-with-replacement on existing monte_carlo_service.dart
output trajectories (per RESEARCH §D-12). Returns (P5, P95) of the
resample-mean distribution as Decimals.

LSFin compliance — narrator MUST annotate emitted intervals with
« selon le modèle simplifié actuel » verbatim (D-12 escape hatch
enforced by tools/checks/banned_terms_python.py extension in Task 6).
The iid-Gaussian MC assumption is documented as insufficient — HMM
regime-switching is backlog 999.1.

Seed strategy (CONTEXT « Claude's Discretion ») : fixed-42 by default
for reproducibility ; callers may override via rng_seed kwarg to derive
seeds from inputs_hash (e.g. `int(inputs_hash[:8], 16) % (2**32)`).
The fixed-42 default matches the existing test_property_invariants.py
precedent.

Performance budget (RESEARCH §D-12) : ~2-5 ms wall-clock per call on
N=1000 trajectories. Within the 50 ms gate p95 budget.
"""
from __future__ import annotations

from decimal import Decimal


def bootstrap_ci_p5_p95(
    trajectories: list,
    iterations: int = 200,
    rng_seed: int = 42,
) -> tuple:
    """Return (P5, P95) of the bootstrap-mean distribution as Decimals.

    Args:
        trajectories: N terminal-wealth or projection samples (floats).
        iterations: number of resample iterations (D-12 default 200).
        rng_seed: deterministic seed (D-12 default 42 ; callers may
            derive from inputs_hash for per-input variation).

    Returns:
        (P5, P95) tuple of Decimal, both rounded to 2 decimals.

    Raises:
        ValueError: if trajectories is empty.
    """
    if not trajectories:
        raise ValueError("trajectories must be non-empty")
    import numpy as np
    rng = np.random.RandomState(rng_seed)
    arr = np.array(trajectories, dtype=np.float64)
    n = len(arr)
    means = np.empty(iterations, dtype=np.float64)
    for i in range(iterations):
        sample = rng.choice(arr, size=n, replace=True)
        means[i] = sample.mean()
    p5 = float(np.percentile(means, 5))
    p95 = float(np.percentile(means, 95))
    return (
        Decimal(str(round(p5, 2))),
        Decimal(str(round(p95, 2))),
    )


__all__ = ["bootstrap_ci_p5_p95"]
