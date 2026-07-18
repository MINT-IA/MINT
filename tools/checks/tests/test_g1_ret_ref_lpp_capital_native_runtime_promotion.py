from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_SHA = "36152b997fbf0c32c1120ddb61f0a8e9d589aa52"
PROOF_NAME = "lpp-capital-native-runtime-proof-36152b997"
PROOF = ROOT / ".planning/runtime-evidence/phase-37/ret-ref-01" / PROOF_NAME
SCORECARD = (
    ROOT
    / ".planning/runtime-evidence/g1-ledger-reality-baseline-20260712"
    / "SCORECARD.md"
)
GAP_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
SCREEN_CONTRACTS = ROOT / "docs/codex/SCREEN_CONTRACTS.md"
MAESTRO_FLOWS = ROOT / "docs/codex/MAESTRO_FLOWS.md"
WIRING_GRAPH = ROOT / "docs/codex/WIRING_GRAPH.mmd"

ARTIFACTS = {
    "README.md",
    "acquisition-summary.sanitized.json",
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
    "capital_notice_dossier_pdf_parity": "OPEN",
    "g1": "OPEN",
    "g1_score": "8.2/10",
    "g2": "FORBIDDEN",
    "g3": "FORBIDDEN",
    "ret_ref": "ticket_only",
    "technical_atom": "GREEN",
}


def _json(name: str) -> dict:
    return json.loads((PROOF / name).read_text(encoding="utf-8"))


def test_minimized_native_bundle_is_complete_and_bounded() -> None:
    assert PROOF.is_dir()
    assert {path.name for path in PROOF.iterdir() if path.is_file()} == ARTIFACTS

    metadata = _json("metadata.sanitized.json")
    assert metadata == {
        "decision": BOUNDARY,
        "distinct_process_pid_verified": True,
        "evidence_logs_complete": True,
        "expected_log_count": 17,
        "maestro": {"exit_code": 0, "failures": 0, "tests": 1},
        "normal_build_core_hashes_verified": True,
        "privacy": {
            "document_hash_retained": False,
            "private_fixture_used": False,
            "raw_document_bytes_retained": False,
            "simulator_identifier_retained": False,
            "synthetic_data_only": True,
            "xcresult_retained": False,
        },
        "production_build_install_passed": True,
        "production_default_off": True,
        "production_external_io_proven": False,
        "production_ui_acquisition_seam_used": True,
        "pushed_sha_verified": True,
        "retained_log_count": 17,
        "runtime_completed": True,
        "source_sha": SOURCE_SHA,
        "suite": {"exit_code": 0, "failed": 0, "passed": 2},
    }

    patrol = _json("patrol-suite-summary.sanitized.json")
    assert patrol == {
        "boundary": BOUNDARY,
        "cold_reader": {"failed": 0, "passed": 1, "status": "PASS"},
        "contract": "g1_ret_ref_lpp_capital_notice",
        "native_writer": {"failed": 0, "passed": 1, "status": "PASS"},
        "status": "PASS",
    }

    maestro = _json("maestro-summary.sanitized.json")
    assert maestro == {
        "boundary": BOUNDARY,
        "failures": 0,
        "production_default_off": True,
        "status": "SUCCESS",
        "tests": 1,
    }


def test_native_acquisition_and_invalidation_claims_are_exact() -> None:
    acquisition = _json("acquisition-summary.sanitized.json")
    assert acquisition == {
        "boundary": BOUNDARY,
        "capital_candidate_from_production_scan_session": True,
        "consent_purpose": "visionExtraction",
        "external_document_io": "synthetic_adapter",
        "mutation_order": [
            "accept_regulation",
            "record_regulation",
            "accept_capital",
            "record_capital",
        ],
        "numeric_snapshot_from_production_certificate_review": True,
        "plan_route": "/scan?type=lppPlan",
        "plan_session_purged_after_confirmation": True,
        "review_fields": [
            "sourceDate",
            "legalYear",
            "fundRelationship=currentFund",
            "deadlineDate",
        ],
        "ui_chain": [
            "DocumentScanScreen",
            "ExtractionReviewScreen",
            "RetirementDashboardScreen",
        ],
    }

    state = _json("state-preservation-summary.sanitized.json")
    assert state == {
        "authority_replacement_invalidated_notice": True,
        "boundary": BOUNDARY,
        "cold_reader_hydrated_exact_notice": True,
        "deadline_banner_rendered": True,
        "numeric_snapshot_replacement_purged_notice": True,
        "production_default_banner_absent": True,
        "writer_reader_distinct_processes": True,
    }


def test_wrapper_only_opus_audits_are_dispositioned() -> None:
    audits = _json("audit-summary.sanitized.json")
    assert audits == {
        "aggregate_p0": 0,
        "aggregate_p1": 0,
        "aggregate_verdict": "PASS",
        "boundary": BOUNDARY,
        "code": {
            "p0": 0,
            "p1": 0,
            "p2": 3,
            "source_head": SOURCE_SHA,
            "verdict": "PASS",
        },
        "lenses_passed": 2,
        "lenses_total": 2,
        "native_runtime_run_by_audit": False,
        "product_domain": {
            "p0": 0,
            "p1": 0,
            "p2": 3,
            "source_head": SOURCE_SHA,
            "verdict": "PASS",
        },
        "wrapper_only": True,
    }
    dispositions = (PROOF / "audit-dispositions.md").read_text(encoding="utf-8")
    for required in (
        "backend package install retained",
        "local exact-SHA runtime",
        "external IO remains synthetic",
        "deadline plausibility",
        "consent scope",
        "supplement the seven earlier topology lenses",
        "exact assembled runtime tree",
    ):
        assert required in dispositions


def test_manifest_and_checksums_cover_exact_allowlist() -> None:
    manifest = _json("manifest.json")
    assert manifest == {
        "artifact_allowlist": sorted(ARTIFACTS),
        "decision": BOUNDARY,
        "proof_name": PROOF_NAME,
        "source_sha": SOURCE_SHA,
    }

    checksum_entries: dict[str, str] = {}
    for line in (PROOF / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        digest, filename = line.split("  ", maxsplit=1)
        assert re.fullmatch(r"[0-9a-f]{64}", digest)
        checksum_entries[filename] = digest

    assert set(checksum_entries) == ARTIFACTS - {"SHA256SUMS"}
    for filename, digest in checksum_entries.items():
        assert hashlib.sha256((PROOF / filename).read_bytes()).hexdigest() == digest


def test_docs_supersede_bridge_only_capital_notice_truth() -> None:
    scorecard = SCORECARD.read_text(encoding="utf-8")
    matrix = GAP_MATRIX.read_text(encoding="utf-8")
    ledger = DATA_LEDGER.read_text(encoding="utf-8")
    screens = SCREEN_CONTRACTS.read_text(encoding="utf-8")
    maestro = MAESTRO_FLOWS.read_text(encoding="utf-8")
    graph = WIRING_GRAPH.read_text(encoding="utf-8")
    combined = "\n".join((scorecard, matrix, ledger, screens, maestro, graph))

    for document in (scorecard, matrix, ledger, screens, maestro, graph):
        assert SOURCE_SHA in document
    assert PROOF_NAME in scorecard
    assert PROOF_NAME in matrix
    assert PROOF_NAME in ledger
    assert PROOF_NAME in screens
    assert PROOF_NAME in maestro

    assert "production UI acquisition seam" in combined
    assert "external document/OCR IO remains synthetic" in combined
    assert "capital_notice_dossier_pdf_parity" in matrix
    assert "production_acquisition_seam,activation_decision" not in matrix
    assert "schemaVersion: 3" in ledger
    assert "authorityReferenceId" in ledger
    assert "LCN_NO_ACQ" not in graph
    assert "LCN_NATIVE_ACQ" in graph
    assert "RET-REF remains `ticket_only`" in scorecard
    assert "G1 remains open at 8.2/10" in scorecard
    assert "G2/G3 remain forbidden" in scorecard


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
        r"test/golden",
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
