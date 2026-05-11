"""Phase 95 — DAG-01 inputs_hash determinism + float quantize."""
from __future__ import annotations

import pytest

from app.services.coach.inputs_hash import compute_inputs_hash, _quantize_floats


def test_deterministic(sample_profile_inputs):
    h1 = compute_inputs_hash(sample_profile_inputs)
    h2 = compute_inputs_hash(sample_profile_inputs)
    assert h1 == h2
    assert len(h1) == 64
    assert all(c in "0123456789abcdef" for c in h1)


def test_key_order_independent():
    a = {"a": 1, "b": 2, "c": 3}
    b = {"c": 3, "b": 2, "a": 1}
    assert compute_inputs_hash(a) == compute_inputs_hash(b)


def test_float_quantize_eliminates_ieee_754_drift():
    # 0.1 + 0.2 = 0.30000000000000004 ; after Decimal(0.01) quantize, both -> 0.30
    a = {"x": 0.1 + 0.2}
    b = {"x": 0.3}
    assert compute_inputs_hash(a) == compute_inputs_hash(b)


def test_bool_distinct_from_int():
    # Python bool is subclass of int — quantize MUST preserve type distinction
    assert compute_inputs_hash({"x": True}) != compute_inputs_hash({"x": 1})
    assert compute_inputs_hash({"x": False}) != compute_inputs_hash({"x": 0})


def test_nested_recursion():
    d = {"prevoyance": {"avoir_lpp": 350000.0, "taux_conv": 0.068, "history": [1.0, 2.5, 3.75]}}
    h = compute_inputs_hash(d)
    assert len(h) == 64


def test_numpy_float64_cast():
    pytest.importorskip("numpy")
    import numpy as np
    a = {"x": float(0.3)}
    b = {"x": np.float64(0.3)}
    assert compute_inputs_hash(a) == compute_inputs_hash(b)


def test_nan_raises():
    with pytest.raises(ValueError, match="NaN"):
        compute_inputs_hash({"x": float("nan")})


def test_inf_raises():
    with pytest.raises(ValueError, match="inf"):
        compute_inputs_hash({"x": float("inf")})
    with pytest.raises(ValueError, match="inf"):
        compute_inputs_hash({"x": float("-inf")})


def test_quantize_preserves_int():
    assert _quantize_floats(42) == 42
    assert _quantize_floats({"x": 42}) == {"x": 42}


def test_quantize_handles_lists_tuples():
    assert _quantize_floats([1.0, 2.5]) == [1.0, 2.5]
    assert _quantize_floats((1.0, 2.5)) == [1.0, 2.5]  # tuple -> list
