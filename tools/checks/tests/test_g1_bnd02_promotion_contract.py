import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ACCEPTED_SHA = "1d022c5086393e3b2e9df8399232f3dbcc6284e8"
RUNTIME_MANIFEST = (
    ROOT
    / ".planning/runtime-evidence/phase-37/bnd-02a/runtime-1d022c508/runtime-manifest.json"
)


def _read(path: str) -> str:
    return (ROOT / path).read_text()


def _json(path: Path) -> dict:
    return json.loads(path.read_text())


def _ticket(ticket_id: str) -> dict:
    evidence = _json(
        ROOT / ".planning/runtime-evidence/phase-37/ticket-evidence.json"
    )
    return next(row for row in evidence["tickets"] if row["ticket_id"] == ticket_id)


def test_bnd02_and_bnd02a_have_exact_sha_technical_green_evidence() -> None:
    for ticket_id, artifact in (
        ("G1-BND-02", ".planning/runtime-evidence/phase-37/bnd-02/green.json"),
        ("G1-BND-02A", ".planning/runtime-evidence/phase-37/bnd-02a/green.json"),
    ):
        record = _ticket(ticket_id)
        assert record["state"] == "green"
        assert record["green_sha"] == ACCEPTED_SHA
        assert record["accepted_sha"] == ACCEPTED_SHA
        assert record["green_artifact"] == artifact

        green = _json(ROOT / artifact)
        assert green["stage"] == "GREEN"
        assert green["sha"] == ACCEPTED_SHA
        assert green["exit_code"] == 0
        assert green["synthetic_data_only"] is True


def test_promotion_keeps_activation_and_g1_fail_closed() -> None:
    manifest = _json(RUNTIME_MANIFEST)
    assert manifest["sha"] == ACCEPTED_SHA
    assert manifest["synthetic_data_only"] is True
    assert manifest["private_fixture_used"] is False
    assert manifest["patrol"] == {
        "writer": {"passed": 1, "failed": 0},
        "terminate_exit_code": 0,
        "cold_reader": {"passed": 1, "failed": 0},
        "normal_build_restored": True,
    }
    assert manifest["maestro"]["completed_steps"] == 17
    assert manifest["maestro"]["exit_code"] == 0
    assert manifest["maestro"]["normal_exact_sha_build"] is True
    assert manifest["technical_ticket_decision"] == {
        "G1-BND-02": "GREEN",
        "G1-BND-02A": "GREEN",
    }
    assert manifest["activation_decision"] == "NO_GO"
    assert manifest["g1_decision"] == "NO_GO"

    blocker_ids = {blocker["id"] for blocker in manifest["activation_blockers"]}
    assert blocker_ids == {
        "controller_identity",
        "privacy_contact",
        "anthropic_role_and_dpa",
        "processing_regions",
        "transfer_mechanism_and_tia",
        "retention_or_zdr",
        "aipd_decision",
        "account_free_rights_channel",
    }


def test_planning_and_graphs_distinguish_technical_green_from_activation() -> None:
    requirements = _read(".planning/REQUIREMENTS.md")
    assert "- [x] **RDY-BND-02**" in requirements
    assert "- [x] **RDY-BND-02A**" in requirements

    registry = _read(".planning/goals/G1-blocking-gate-tickets.md")
    for ticket_id in ("G1-BND-02", "G1-BND-02A"):
        row = next(line for line in registry.splitlines() if line.startswith(f"| {ticket_id} |"))
        assert row.endswith("| green |")

    validation = _read(
        ".planning/phases/37-ledger-runtime-readiness/37-VALIDATION.md"
    )
    assert "| G1-BND-02A |" in validation and "| ✅ | ✅ green |" in validation
    assert "| G1-BND-02 |" in validation

    ledger = _read("docs/codex/DATA_LEDGER.md")
    assert "BND-02 and BND-02A are technical GREEN at `1d022c508`" in ledger
    assert "activation and G1 remain NO-GO" in ledger

    wiring = _read("docs/codex/WIRING_GRAPH.mmd")
    journey = _read("docs/codex/PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd")
    assert "GREEN G1-BND-02 @ 1d022c508" in wiring
    assert "TECHNICAL GREEN G1-BND-02A @ 1d022c508" in wiring
    assert "BND-02 + BND-02A TECHNICAL GREEN @ 1d022c508" in journey
    assert "ACTIVATION + G1 NO-GO" in journey
