from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_SHA = "7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a"
PROOF = (
    ROOT
    / ".planning/runtime-evidence/phase-37/ret-ref-01"
    / "lpp-regulation-recovery-runtime-proof-7cb5ea4c6"
)
SCORECARD = (
    ROOT
    / ".planning/runtime-evidence/g1-ledger-reality-baseline-20260712"
    / "SCORECARD.md"
)
GAP_MATRIX = ROOT / ".planning/goals/G1-ledger-gap-matrix.md"
TRACKED_READER = (
    "apps/mobile/integration_test/"
    "g1_ret_ref_lpp_regulation_read_patrol_test.dart"
)

ARTIFACTS = {
    "README.md",
    "SHA256SUMS",
    "audit-dispositions.md",
    "audit-summary.sanitized.json",
    "maestro-summary.sanitized.json",
    "manifest.json",
    "metadata.sanitized.json",
    "patrol-suite-summary.sanitized.json",
    "quality-gate-scorecard.md",
    "recovery-ui-summary.sanitized.json",
    "state-preservation-summary.sanitized.json",
}

BOUNDARY = {
    "activation": "NO-GO",
    "g1": "OPEN",
    "g1_score": "8.2/10",
    "g2": "FORBIDDEN",
    "g3": "FORBIDDEN",
    "production_default_off": True,
    "recovery_slice": "GREEN",
    "ret_ref": "ticket_only",
    "runtime_recovery_state": "missingDocumentReference",
}

MISSING_BODY_FR = (
    "Une déclaration non vérifiée existe, mais sa référence locale manque. "
    "Reconfirme-la à partir du document. MINT n’en déduit ni l’origine, ni "
    "l’institution concernée, ni l’application du règlement à ta situation, "
    "ni tes droits ni aucun montant."
)


def _json(name: str) -> dict:
    return json.loads((PROOF / name).read_text(encoding="utf-8"))


def test_recovery_runtime_bundle_is_complete_and_bounded() -> None:
    assert PROOF.is_dir(), "TDD RED: recovery runtime proof bundle is missing"
    assert {path.name for path in PROOF.iterdir() if path.is_file()} == ARTIFACTS

    metadata = _json("metadata.sanitized.json")
    assert metadata["source_sha"] == SOURCE_SHA
    assert metadata["boundary"] == BOUNDARY
    assert metadata["pushed_sha_verified"] is True
    assert metadata["runtime_completed"] is True
    assert metadata["evidence_outputs_complete"] is True
    assert metadata["expected_output_count"] == 22
    assert metadata["retained_output_count"] == 22
    assert metadata["suite"] == {"exit_code": 0, "failed": 0, "passed": 2}
    assert metadata["distinct_process_pid_verified"] is True
    assert metadata["patrol_full_isolation_zero_verified"] is True
    assert metadata["production_default_off"] == {"after": True, "before": True}
    assert metadata["cleanup_status"] == "passed"
    assert metadata["restoration_status"] == "restored"
    assert metadata["privacy"] == {
        "document_hash_retained": False,
        "private_fixture_used": False,
        "raw_document_bytes_retained": False,
        "simulator_identifier_retained": False,
        "synthetic_data_only": True,
        "xcresult_retained": False,
    }

    patrol = _json("patrol-suite-summary.sanitized.json")
    assert patrol == {
        "assertion_trace": {
            "internal_assertions_exposed_by_xctest_output": False,
            "source_sha": SOURCE_SHA,
            "tracked_reader": TRACKED_READER,
        },
        "boundary": BOUNDARY,
        "contract": "g1_ret_ref_lpp_regulation",
        "failed_tests": 0,
        "passed_tests": 2,
        "status": "PASS",
    }

    maestro = _json("maestro-summary.sanitized.json")
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
        "boundary": BOUNDARY,
    }


def test_recovery_ui_claims_trace_to_tracked_reader_and_passing_suite() -> None:
    recovery = _json("recovery-ui-summary.sanitized.json")
    assert recovery["boundary"] == BOUNDARY
    assert recovery["assertion_trace"] == {
        "claim_basis": "tracked_reader_contract_executed_in_passing_native_suite",
        "internal_assertions_exposed_by_xctest_output": False,
        "source_sha": SOURCE_SHA,
        "suite_failed_tests": 0,
        "suite_passed_tests": 2,
        "tracked_reader": TRACKED_READER,
    }
    assert recovery["resolution"] == "missingDocumentReference"
    assert recovery["known_surface"] == {
        "education_card_visible": False,
        "handoff_cta_visible": False,
    }
    assert recovery["recovery_surface"] == {
        "body_fr": MISSING_BODY_FR,
        "card_visible": True,
        "cta_visible": True,
    }
    assert recovery["stale_tuple_exposure"] == {
        "fund_relationship_declaration": False,
        "local_reference_identifier": False,
    }
    assert recovery["navigation"] == {
        "cta_route": "/scan?type=lppPlan",
        "route_verified_after_tap": True,
    }
    assert recovery["bnd_restoration"] == {
        "original_list_saved_temporarily": True,
        "persisted_list_emptied": True,
        "restored_in_finally": True,
        "restored_list_reloaded_and_compared": True,
    }

    audits = _json("audit-summary.sanitized.json")
    assert audits == {
        "boundary": BOUNDARY,
        "external_audit": {
            "aggregate_p0": 0,
            "aggregate_p1": 0,
            "aggregate_p2": 4,
            "aggregate_verdict": "PASS",
            "archive_manual_preflight": "PASS",
            "base_sha": "c37da786b477aec34f785fceaacd51d7d8e4d61e",
            "code": {
                "effort": "high",
                "model": "opus",
                "p0": 0,
                "p1": 0,
                "p2": 2,
                "pass": "first",
                "verdict": "PASS",
            },
            "native_runtime_run_by_audit": False,
            "product_domain": {
                "effort": "high",
                "model": "opus",
                "p0": 0,
                "p1": 0,
                "p2": 2,
                "pass": "first",
                "verdict": "PASS",
            },
            "source_head": SOURCE_SHA,
            "trace_disposition": {
                "internal_assertions_exposed_by_xctest_output": False,
                "runtime_claim_basis": (
                    "tracked_reader_contract_plus_passing_native_suite"
                ),
                "suite_failed_tests": 0,
                "suite_passed_tests": 2,
            },
        },
    }


def test_recovery_summary_claims_exist_in_the_exact_tracked_reader() -> None:
    reader = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_SHA}:{TRACKED_READER}"],
        text=True,
        capture_output=True,
        check=True,
    ).stdout
    for anchor in (
        "LppRegulationReferenceResolution.missingDocumentReference",
        "'retirement_lpp_regulation_reference_education'",
        "'retirement_lpp_regulation_handoff_cta'",
        "'retirement_lpp_regulation_reference_recovery'",
        "'retirement_lpp_regulation_reconfirm_cta'",
        "expect(find.text(_missingDocumentReferenceBodyFr), findsOneWidget);",
        "isNot(contains(candidate.referenceId))",
        "isNot(contains(typedCandidate.fundRelationship.wireName))",
        "'/scan?type=lppPlan'",
        "await referenceStore.save(originalDocumentReferences);",
        "final restoredDocumentReferences = await referenceStore.load();",
        "reason: 'the temporary BND loss must not alter final runtime state'",
    ):
        assert anchor in reader, anchor

    emptied = reader.index(
        "await referenceStore.save(const <ConfirmedDocumentReference>[]);"
    )
    resolved = reader.index(
        "LppRegulationReferenceResolution.missingDocumentReference"
    )
    recovery = reader.index("'retirement_lpp_regulation_reference_recovery'")
    route = reader.index("'/scan?type=lppPlan'")
    restored = reader.index("await referenceStore.save(originalDocumentReferences);")
    compared = reader.index(
        "reason: 'the temporary BND loss must not alter final runtime state'"
    )
    assert emptied < resolved < recovery < route < restored < compared


def test_state_manifest_and_checksums_cover_only_the_allowlist() -> None:
    state = _json("state-preservation-summary.sanitized.json")
    assert state == {
        "boundary": BOUNDARY,
        "post_suite_state_captured": True,
        "production_reinstall_preserved_state": True,
        "required_runtime_state_present_after_final_maestro": True,
        "writer_reader_distinct_processes": True,
    }

    manifest = _json("manifest.json")
    assert manifest["source_sha"] == SOURCE_SHA
    assert manifest["boundary"] == BOUNDARY
    assert manifest["artifact_allowlist"] == sorted(ARTIFACTS)
    assert manifest["logical_sources"] == [
        "accepted_exact_sha_runtime_metadata",
        "accepted_sanitized_suite_and_maestro_summaries",
        "tracked_reader_contract_at_exact_sha",
        "bounded_external_audit",
    ]
    assert manifest["privacy_policy"] == {
        "allowlist_only": True,
        "device_specific_evidence_retained": False,
        "private_fixture_data_retained": False,
        "raw_document_evidence_retained": False,
        "raw_runtime_output_retained": False,
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


def test_global_g1_state_records_recovery_without_promoting_ret_ref() -> None:
    scorecard = re.sub(r"\s+", " ", SCORECARD.read_text(encoding="utf-8"))
    gap_matrix = re.sub(r"\s+", " ", GAP_MATRIX.read_text(encoding="utf-8"))

    for text in (scorecard, gap_matrix):
        assert SOURCE_SHA in text
        assert "missingDocumentReference" in text
        assert "RET-REF remains `ticket_only`" in text
        assert "G1 remains open at 8.2/10" in text
        assert "G2/G3 remain forbidden" in text
        assert "PDF/dossier" in text
        assert "activation" in text

    assert "visible_legacy_reprompt" not in gap_matrix
    assert "visible_reconfirmation_path" not in gap_matrix

    local_scorecard = (PROOF / "quality-gate-scorecard.md").read_text(
        encoding="utf-8"
    )
    assert "**Recovery slice** | **10.0** | **9.9**" in local_scorecard
    assert "G1 | OPEN — 8.2/10" in local_scorecard
    assert "RET-REF | `ticket_only`" in local_scorecard
    assert "G2 / G3 | FORBIDDEN" in local_scorecard


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
