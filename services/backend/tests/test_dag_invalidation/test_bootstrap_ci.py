"""Phase 95 — D-12 bootstrap CI frequentiste 200 iter."""
from __future__ import annotations

from decimal import Decimal
from unittest.mock import patch

import pytest

np = pytest.importorskip("numpy")

from app.services.coach.bootstrap_ci import bootstrap_ci_p5_p95  # noqa: E402


def test_deterministic_for_same_seed():
    traj = [100.0, 200.0, 300.0, 400.0, 500.0] * 200  # 1000 trajectories
    a = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    b = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    assert a == b


def test_different_seed_different_result():
    traj = [100.0, 200.0, 300.0, 400.0, 500.0] * 200
    a = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    b = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=43)
    assert a != b


def test_p5_le_p95():
    traj = [100.0, 200.0, 300.0, 400.0, 500.0] * 200
    p5, p95 = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    assert p5 <= p95


def test_returns_decimal():
    traj = [100.0, 200.0, 300.0]
    p5, p95 = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    assert isinstance(p5, Decimal)
    assert isinstance(p95, Decimal)


def test_constant_trajectories_collapse():
    traj = [42.0] * 100
    p5, p95 = bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    assert p5 == p95 == Decimal("42.00")


def test_iterations_parameter_respected():
    """Verify .choice is called exactly `iterations` times via instrumented RandomState."""
    traj = [10.0, 20.0, 30.0]
    # Use a real RandomState but instrumented to count .choice calls.
    import numpy as np
    original_rs = np.random.RandomState

    call_count = {"n": 0}

    class CountingRS(original_rs):  # type: ignore[misc]
        def choice(self, *args, **kwargs):
            call_count["n"] += 1
            return super().choice(*args, **kwargs)

    with patch.object(np.random, "RandomState", CountingRS):
        bootstrap_ci_p5_p95(traj, iterations=200, rng_seed=42)
    assert call_count["n"] == 200


def test_empty_trajectories_raises():
    with pytest.raises(ValueError):
        bootstrap_ci_p5_p95([], iterations=200, rng_seed=42)
