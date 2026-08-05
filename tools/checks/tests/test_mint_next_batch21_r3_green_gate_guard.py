#!/usr/bin/env python3
"""Hostile suite for the Batch21 R3 GREEN-GATE guard.

Runs isolated (python3 -ISB unittest). Asserts the LIVE pending manifest passes
the structure gate and that each fail-closed invariant actually closes: descriptor
drift, wrong candidate payload, a pending manifest claiming reviews, a duplicate
YAML key, and the descriptor's deliberate exclusion of the state-dependent
not_accepted boundary (so pending and accepted share one replayable descriptor).
"""

from __future__ import annotations

import copy
import unittest
from pathlib import Path

from tools.checks import mint_next_batch21_r3_green_gate_guard as guard

ROOT = guard.REPO_ROOT


def _load_live() -> dict:
    return guard._load_manifest_bytes((ROOT / guard.MANIFEST).read_bytes())


class Batch21R3GreenGateGuardTest(unittest.TestCase):
    def test_live_pending_manifest_passes_contract(self) -> None:
        # The committed pending manifest validates structurally (no Flutter).
        guard.validate(ROOT, check_git=False)

    def test_live_manifest_is_pending(self) -> None:
        data = _load_live()
        self.assertEqual(data.get("status"), guard.PENDING_STATUS)
        self.assertEqual(data.get("current_verdict"), guard.PENDING_VERDICT)

    def test_candidate_payload_matches_recomputed(self) -> None:
        data = _load_live()
        self.assertEqual(
            data["mechanical_binding"]["candidate_payload_sha256"],
            guard._payload(ROOT),
        )

    def test_descriptor_excludes_not_accepted(self) -> None:
        data = _load_live()
        self.assertEqual(
            set(guard._descriptor(data)),
            {"supersedes", "green_gate", "re_pinned_immutables", "runtime_regating"},
        )

    def test_core_rejects_drifted_green_gate(self) -> None:
        data = _load_live()
        data["green_gate"]["test_sha256"] = "0" * 64
        with self.assertRaises(guard.GuardFailure):
            guard._core(ROOT, data)

    def test_core_rejects_widened_runtime_surface(self) -> None:
        data = _load_live()
        data["runtime_surface"] = "public_product_route"
        with self.assertRaises(guard.GuardFailure):
            guard._core(ROOT, data)

    def test_pending_rejects_wrong_candidate_payload(self) -> None:
        data = _load_live()
        with self.assertRaises(guard.GuardFailure):
            guard._pending(data, "deadbeef")

    def test_pending_rejects_accept_review(self) -> None:
        data = copy.deepcopy(_load_live())
        payload = guard._payload(ROOT)
        role = next(iter(data["reviews"]))
        data["reviews"][role] = {
            "verdict": "ACCEPT", "p1": 0, "p2": 0, "p3": 0,
            "reviewed_payload_sha256": payload,
        }
        with self.assertRaises(guard.GuardFailure):
            guard._pending(data, payload)

    def test_pending_rejects_claimed_reviewed_binding(self) -> None:
        data = copy.deepcopy(_load_live())
        payload = guard._payload(ROOT)
        data["mechanical_binding"]["reviewed_payload_sha256"] = payload
        with self.assertRaises(guard.GuardFailure):
            guard._pending(data, payload)

    def test_pending_rejects_premature_lib_inventory(self) -> None:
        data = copy.deepcopy(_load_live())
        payload = guard._payload(ROOT)
        data["mechanical_binding"]["green_lib_inventory_sha256"] = "a" * 64
        with self.assertRaises(guard.GuardFailure):
            guard._pending(data, payload)

    def test_duplicate_yaml_key_rejected(self) -> None:
        with self.assertRaises(guard.GuardFailure):
            guard._load_manifest_bytes(b"status: a\nstatus: b\n")

    def test_green_gate_pins_amended_test_not_red(self) -> None:
        # The GREEN gate must pin the AMENDED integration test, distinct from the
        # frozen RED test the red guard pins.
        self.assertNotEqual(guard.GREEN_TEST_SHA256, guard.red.EXPECTED_TEST_SHA256)
        self.assertEqual(guard.GREEN_SUMMARY["passed"], 14)
        self.assertEqual(len(guard.GREEN_TEST_NAMES), 14)

    def test_repinned_immutables_equal_live_files(self) -> None:
        self.assertEqual(guard.red._sha(ROOT / guard.RED_GUARD), guard.RED_GUARD_SHA256)
        self.assertEqual(guard.red._sha(ROOT / guard.REGISTRY), guard.REGISTRY_SHA256)


if __name__ == "__main__":
    unittest.main()
