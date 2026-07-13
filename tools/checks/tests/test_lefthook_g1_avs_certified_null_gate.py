from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
LEFTHOOK = ROOT / "lefthook.yml"


def _command_block(config: str, command_name: str) -> str:
    match = re.search(
        rf"^    {re.escape(command_name)}:\n(?P<body>(?:      .*\n)+)",
        config,
        re.MULTILINE,
    )
    assert match is not None, f"missing dedicated Lefthook command: {command_name}"
    return match.group("body")


def test_g1_avs_certified_null_hard_floor_is_dedicated_and_scoped() -> None:
    config = LEFTHOOK.read_text(encoding="utf-8")
    block = _command_block(config, "g1-avs-certified-null-hard-floor")

    assert (
        "run: python3 -m pytest "
        "tools/checks/tests/test_g1_avs_certified_null_contract.py -q" in block
    )
    assert "-k " not in block
    assert "--ignore" not in block
    assert "|| true" not in block
    assert "exit 0" not in block

    for trigger in (
        "apps/mobile/lib/**/*.dart",
        "services/backend/app/**/*.py",
        "tools/openapi/mint.openapi.canonical.json",
        "tools/checks/tests/test_g1_avs_certified_null_contract.py",
        "lefthook.yml",
    ):
        assert trigger in block, f"missing G1 AVS hard-floor trigger: {trigger}"
