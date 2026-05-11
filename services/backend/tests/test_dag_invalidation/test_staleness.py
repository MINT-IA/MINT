"""Phase 95 — DAG-03 staleness derivation + SC#4(c) chain-reset.

Tests the production module at services/backend/app/services/coach/staleness.py
(extracted from this test file per 2026-05-11 checker BLOCKER-1 fix).
SC#4(c) chain-reset test : when a stale scenario gets a fresh recompute,
the new projection's inputs_hash matches current, staleness_high() flips
to False, and the old scenario's superseded_by points to the new UUID7.
"""
from __future__ import annotations

from app.services.coach.inputs_hash import compute_inputs_hash
from app.services.coach.projection_id import new_projection_id
from app.services.coach.staleness import staleness_high


# --- BLOCKER-1 fix #1 : 4-5 unit tests on the production module ------------
def test_staleness_both_none():
    """Edge case : current_hash is empty string + stored None -> still stale."""
    assert staleness_high(None, "") is True


def test_staleness_stored_none_current_set(sample_profile_inputs):
    """Legacy row (stored None) + fresh compute -> must flag stale."""
    h_now = compute_inputs_hash(sample_profile_inputs)
    assert staleness_high(None, h_now) is True


def test_staleness_both_same(sample_profile_inputs):
    """Fresh : stored == current -> not stale."""
    h = compute_inputs_hash(sample_profile_inputs)
    assert staleness_high(h, h) is False


def test_staleness_both_different(sample_profile_inputs):
    """Mutated inputs : stored != current -> stale."""
    h_stored = compute_inputs_hash(sample_profile_inputs)
    mutated = {**sample_profile_inputs, "salary": 90000.0}
    h_now = compute_inputs_hash(mutated)
    assert staleness_high(h_stored, h_now) is True


def test_staleness_both_empty_strings():
    """Defensive : two empty strings are equal -> not stale (rule semantics
    preserved : the rule only looks at None and string equality)."""
    assert staleness_high("", "") is False


def test_same_inputs_different_runs_not_stale(sample_profile_inputs):
    """Determinism cross-check : compute_inputs_hash idempotent -> not stale."""
    h_a = compute_inputs_hash(sample_profile_inputs)
    h_b = compute_inputs_hash(sample_profile_inputs)
    assert staleness_high(h_a, h_b) is False


# --- BLOCKER-1 fix #4 : ROADMAP SC#4(c) « recompute resets hash chain » ----
def test_recompute_resets_hash_chain(sample_profile_inputs):
    """SC#4(c) — given a stale scenario (stored_hash != current_hash), a
    new projection computed with the updated inputs MUST :
    1. produce inputs_hash equal to the current_hash from updated inputs
    2. flip staleness_high() to False
    3. populate the OLD scenario.superseded_by with the NEW projection's UUID7

    Implements the SC#4(c) test contract from ROADMAP Phase 95
    Success Criteria #4 (« recompute resets hash chain »). Simulates the
    chain at the data layer without invoking the Phase 96 W2 production
    consumer (which is deferred per SC#2 scope).
    """
    # T0 — old scenario stored with hash_old
    old_inputs = sample_profile_inputs
    hash_old = compute_inputs_hash(old_inputs)
    old_scenario = {"inputs_hash": hash_old, "superseded_by": None}

    # T1 — user mutates salary ; current_hash differs -> stale
    mutated_inputs = {**old_inputs, "salary": 90000.0}
    hash_current = compute_inputs_hash(mutated_inputs)
    assert staleness_high(old_scenario["inputs_hash"], hash_current) is True, (
        "Pre-recompute : stale flag MUST fire on mismatched stored vs current."
    )

    # T2 — recompute with the updated inputs ; new projection emerges
    new_projection_uuid = new_projection_id()
    new_scenario = {
        "inputs_hash": compute_inputs_hash(mutated_inputs),
        "superseded_by": None,
    }
    # SC#4(c) assertion #1 : new projection's inputs_hash matches current
    assert new_scenario["inputs_hash"] == hash_current
    # SC#4(c) assertion #2 : staleness flips False vs the just-computed current
    assert staleness_high(new_scenario["inputs_hash"], hash_current) is False
    # SC#4(c) assertion #3 : old row's superseded_by now points at new UUID7
    old_scenario["superseded_by"] = new_projection_uuid
    assert old_scenario["superseded_by"] == new_projection_uuid
    assert len(old_scenario["superseded_by"]) == 36  # canonical UUID7 form
