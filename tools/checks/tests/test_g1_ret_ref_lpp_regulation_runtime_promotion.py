from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_SHA = "6066f1c94786aa1bc4697c29b4a670b7cea3dca4"
RECOVERY_SHA = "7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a"
AUTHORITY_SHA = "e97c0a77f0a9f17ff2cc0eb953b085547e8aa2c2"
PROOF = (
    ROOT
    / ".planning/runtime-evidence/phase-37/ret-ref-01"
    / "lpp-regulation-runtime-proof-6066f1c94"
)
SCORECARD = (
    ROOT
    / ".planning/runtime-evidence/g1-ledger-reality-baseline-20260712"
    / "SCORECARD.md"
)
GAP_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"

ARTIFACTS = {
    "README.md",
    "audit-dispositions.md",
    "audit-summary.sanitized.json",
    "maestro-summary.sanitized.json",
    "manifest.json",
    "metadata.sanitized.json",
    "patrol-suite-summary.sanitized.json",
    "quality-gate-scorecard.md",
    "state-preservation-summary.sanitized.json",
    "SHA256SUMS",
}

BOUNDARY = {
    "activation": "NO-GO",
    "fund_identity_objectively_proven": False,
    "fund_relationship": "currentFund",
    "fund_relationship_verification": "declared_unverified",
    "g1": "OPEN",
    "g1_score": "8.2/10",
    "g2": "FORBIDDEN",
    "g3": "FORBIDDEN",
    "ret_ref": "ticket_only",
    "technical_atom": "GREEN",
}


def _json(name: str) -> dict:
    return json.loads((PROOF / name).read_text(encoding="utf-8"))


def test_minimized_bundle_is_complete_and_semantically_bounded() -> None:
    assert PROOF.is_dir()
    assert {path.name for path in PROOF.iterdir() if path.is_file()} == ARTIFACTS

    metadata = _json("metadata.sanitized.json")
    assert metadata["source_sha"] == SOURCE_SHA
    assert metadata["pushed_sha_verified"] is True
    assert metadata["runtime_completed"] is True
    assert metadata["evidence_logs_complete"] is True
    assert metadata["expected_log_count"] == 22
    assert metadata["retained_log_count"] == 22
    assert metadata["suite"] == {"exit_code": 0, "failed": 0, "passed": 2}
    assert metadata["distinct_process_pid_verified"] is True
    assert metadata["patrol_full_isolation_zero_verified"] is True
    assert metadata["production_default_off"] == {"after": True, "before": True}
    assert metadata["authority"] == {
        "fund_identity_objectively_proven": False,
        "fund_relationship": "currentFund",
        "verification": "declared_unverified",
    }
    assert metadata["decision"] == {
        "activation": "NO-GO",
        "g1": "OPEN",
        "g1_score": "8.2/10",
        "g2": "FORBIDDEN",
        "g3": "FORBIDDEN",
        "ret_ref": "ticket_only",
        "technical_atom": "GREEN",
    }
    assert metadata["privacy"] == {
        "document_hash_retained": False,
        "private_fixture_used": False,
        "raw_document_bytes_retained": False,
        "simulator_identifier_retained": False,
        "synthetic_data_only": True,
        "xcresult_retained": False,
    }

    patrol = _json("patrol-suite-summary.sanitized.json")
    assert patrol.pop("boundary") == BOUNDARY
    assert patrol == {
        "contract": "g1_ret_ref_lpp_regulation",
        "failed_tests": 0,
        "passed_tests": 2,
        "status": "PASS",
    }
    maestro = _json("maestro-summary.sanitized.json")
    assert maestro.pop("boundary") == BOUNDARY
    assert maestro == {
        "after": {
            "failures": 0,
            "production_default_off": True,
            "status": "SUCCESS",
            "tests": 1,
        },
        "before": {
            "failures": 0,
            "production_default_off": True,
            "status": "SUCCESS",
            "tests": 1,
        },
    }

    state = _json("state-preservation-summary.sanitized.json")
    assert state["boundary"] == BOUNDARY
    assert state["cold_profile_started_without_numeric_lpp_snapshot"] is True
    assert state["regulation_reference_survived_numeric_snapshot_addition"] is True
    assert state["regulation_reference_survived_numeric_snapshot_replacement"] is True
    assert state["writer_reader_distinct_processes"] is True
    assert state["fund_relationship"] == "currentFund"
    assert state["fund_relationship_verification"] == "declared_unverified"
    assert state["fund_identity_objectively_proven"] is False

    audits = _json("audit-summary.sanitized.json")
    assert audits["boundary"] == BOUNDARY
    assert audits["runtime_harness"] == {
        "aggregate_p0": 0,
        "aggregate_p1": 0,
        "aggregate_verdict": "PASS",
        "lenses_passed": 2,
        "lenses_total": 2,
        "native_runtime_run_by_audit": False,
        "product_domain_p2": 2,
        "source_head": SOURCE_SHA,
    }
    assert audits["autonomous_authority"] == {
        "aggregate_p0": 0,
        "aggregate_p1": 0,
        "aggregate_verdict": "PASS",
        "invalid_isolation_outputs_excluded": True,
        "lenses_passed": 10,
        "lenses_total": 10,
        "source_head": AUTHORITY_SHA,
    }


def test_manifest_and_checksums_cover_exactly_the_allowlisted_bundle() -> None:
    manifest = _json("manifest.json")
    assert manifest["source_sha"] == SOURCE_SHA
    assert manifest["artifact_allowlist"] == sorted(ARTIFACTS)
    assert manifest["decision"] == {
        "activation": "NO-GO",
        "g1": "OPEN",
        "g1_score": "8.2/10",
        "g2": "FORBIDDEN",
        "g3": "FORBIDDEN",
        "ret_ref": "ticket_only",
        "technical_atom": "GREEN",
    }
    assert manifest["fund_relationship"] == {
        "identity_objectively_proven": False,
        "relationship": "currentFund",
        "verification": "declared_unverified",
    }

    checksum_lines = (PROOF / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    checksum_entries: dict[str, str] = {}
    for line in checksum_lines:
        digest, filename = line.split("  ", maxsplit=1)
        assert re.fullmatch(r"[0-9a-f]{64}", digest)
        checksum_entries[filename] = digest

    expected = ARTIFACTS - {"SHA256SUMS"}
    assert set(checksum_entries) == expected
    for filename, digest in checksum_entries.items():
        assert hashlib.sha256((PROOF / filename).read_bytes()).hexdigest() == digest


def test_global_g1_state_supersedes_snapshot_bound_runtime_without_promotion() -> None:
    scorecard = SCORECARD.read_text(encoding="utf-8")
    gap_matrix = GAP_MATRIX.read_text(encoding="utf-8")
    scorecard_words = re.sub(r"\s+", " ", scorecard)
    gap_matrix_words = re.sub(r"\s+", " ", gap_matrix)

    assert "## G1-RET-REF-01 `lppRegulationReference` — autonomous regulation-only runtime atom" in scorecard
    assert SOURCE_SHA in scorecard
    assert "currentFund` relationship is **declared/unverified**" in scorecard_words
    assert "does **not** objectively prove the caisse/fund identity" in scorecard_words
    assert "does not establish legal applicability" in scorecard_words
    assert "RET-REF remains `ticket_only`" in scorecard_words
    assert "G1 interim score remains 8.2/10" in scorecard_words
    assert "G2/G3 remain forbidden" in scorecard_words
    assert "## G1-RET-REF-01 `lppRegulationReference` — snapshot-bound runtime atom" not in scorecard

    assert SOURCE_SHA in gap_matrix
    assert RECOVERY_SHA in gap_matrix
    assert "autonomous regulation-only" in gap_matrix_words
    assert "currentFund` relationship is declared/unverified" in gap_matrix_words
    assert "does not objectively prove the caisse/fund identity" in gap_matrix_words
    assert "does not establish legal applicability" in gap_matrix_words
    assert "recovery_runtime_missing_bnd_7cb5ea4c6" in gap_matrix
    assert "visible_reconfirmation_path" not in gap_matrix
    assert "dossier_pdf_parity_runtime_274736a50" in gap_matrix
    assert "pdf_dossier_caveat_parity" not in gap_matrix
    assert "activation_decision" in gap_matrix
    assert "objective_current_fund_identity_verification" not in gap_matrix
    assert "autonomous_fund_authority_attestation" not in gap_matrix


def test_bundle_contains_no_raw_or_device_specific_evidence() -> None:
    forbidden = (
        r"/Users/",
        r"/private/",
        r"/tmp/",
        r"\.xcresult\b",
        r"\.log\b",
        r"\.pdf\b",
        r"\.png\b",
        r"\.jpe?g\b",
        r"\.mov\b",
        r"\.mp4\b",
        r"\bUDID\b",
        r"device_sha256",
        r"document_sha",
        r"%PDF",
        r"private fixture name",
    )
    for path in PROOF.iterdir():
        if not path.is_file() or path.name == "SHA256SUMS":
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in forbidden:
            assert re.search(pattern, text, flags=re.IGNORECASE) is None, (
                f"{path.name} contains forbidden pattern {pattern!r}"
            )
        assert re.search(r"\b[0-9a-f]{64}\b", text, flags=re.IGNORECASE) is None
