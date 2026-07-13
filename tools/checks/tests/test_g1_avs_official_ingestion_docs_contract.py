from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACT = ROOT / "docs/codex/AVS_OFFICIAL_PENSION_INGESTION.md"
DIAGRAM = ROOT / "docs/codex/AVS_OFFICIAL_PENSION_INGESTION.mmd"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"
WIRING_GRAPH = ROOT / "docs/codex/WIRING_GRAPH.mmd"


def _read(path: Path) -> str:
    assert path.is_file(), f"missing G1 official AVS contract artifact: {path}"
    return path.read_text(encoding="utf-8")


def test_official_avs_contract_has_exact_self_only_identity() -> None:
    contract = _read(CONTRACT)

    required_lines = {
        "- `scope`: `self-only`",
        "- `canonical_key`: `avs_official_monthly_pension`",
        "- `document_type`: `avs_official_pension`",
        "- `secure_key`: `_coach_avs_official_monthly_pension`",
        "- `secure_record`: `{value, source, sourceDate, updatedAt}`",
        "- `mobile_flag`: `enableOfficialAvsPensionIngestion` (default `false`)",
        "- `backend_flag`: `AVS_OFFICIAL_PENSION_INGESTION_ENABLED` (default `false`)",
    }

    assert required_lines <= set(contract.splitlines())


def test_official_avs_provenance_is_atomic_and_corrections_do_not_launder() -> None:
    contract = _read(CONTRACT)
    normalized_contract = " ".join(contract.split())

    for phrase in (
        "`sourceDate` and `updatedAt` are semantically distinct fields",
        "`sourceDate` must never be derived from or replaced by confirmation time",
        "Both fields must be present for an untouched certificate",
        "Their values may share the same calendar date",
        "There is no mandatory value inequality between them",
    ):
        assert phrase in normalized_contract
    assert "`sourceDate != updatedAt`" not in contract
    assert "`source=certificate, sourceDate=<official document date>`" in contract
    assert "`source=userInput, sourceDate=null`" in contract
    assert "one strict-secure atomic envelope" in contract
    assert "no split value/provenance write" in contract


def test_ci_and_legacy_estimate_are_explicitly_non_certifying() -> None:
    contract = _read(CONTRACT)

    assert (
        "| `avs_extract` | CI contribution history only | **cannot certify** "
        "`avs_official_monthly_pension` |" in contract
    )
    assert (
        "| `_coach_avs_rente_estimee` | legacy estimate storage | "
        "**cannot certify** `avs_official_monthly_pension` |" in contract
    )

    positive_certification = re.compile(
        r"\b(?:can|may|does|will) certify\b|\bcertifies\b|"
        r"\bis certificate-grade\b|\bis official evidence\b",
        flags=re.IGNORECASE,
    )
    for path in (CONTRACT, DATA_LEDGER, WIRING_GRAPH):
        for line_number, line in enumerate(_read(path).splitlines(), start=1):
            if not any(
                token in line
                for token in ("avs_extract", "_coach_avs_rente_estimee")
            ):
                continue
            assert not positive_certification.search(line), (
                f"{path.name}:{line_number} implies a non-certifying AVS "
                f"input can certify the official pension: {line.strip()}"
            )


def test_candidate_path_has_no_pre_review_backend_write() -> None:
    contract = _read(CONTRACT)

    for phrase in (
        "candidate-only",
        "NO pre-review write",
        "NO backend `ProfileModel.data` mirror",
        "kill-switch rejection",
        "no partner writer",
        "household calculations remain fail-closed",
    ):
        assert phrase in contract


def test_ledger_and_wiring_reference_the_focused_contract() -> None:
    ledger = _read(DATA_LEDGER)
    graph = _read(WIRING_GRAPH)

    for text in (ledger, graph):
        assert "AVS_OFFICIAL_PENSION_INGESTION.md" in text
        assert "avs_official_monthly_pension" in text
        assert "avs_official_pension" in text

    assert "{value, source, sourceDate, updatedAt}" in ledger
    assert "NO ProfileModel mirror" in graph
    assert "default false" in graph
    assert "household calculations stay null" in graph


def test_focused_mermaid_covers_review_rejection_write_and_relaunch() -> None:
    diagram = _read(DIAGRAM)

    required = (
        "sequenceDiagram",
        "participant Scan",
        "participant Candidate",
        "participant Review",
        "participant Secure",
        "participant Relaunch",
        "participant EvidenceCard",
        "alt mobile or backend kill switch is false",
        "candidate-only; no ProfileModel mirror",
        "correction: userInput + null sourceDate",
        "atomic secure envelope",
        "show self evidence only",
        "household calculations stay fail-closed",
    )
    for token in required:
        assert token in diagram
