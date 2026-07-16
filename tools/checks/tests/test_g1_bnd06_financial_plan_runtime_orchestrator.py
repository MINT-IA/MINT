from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = ROOT / "tools/simulator/patrol_bnd06_financial_plan_process_death.sh"
WRITER = (
    ROOT
    / "apps/mobile/integration_test/g1_bnd06_financial_plan_write_patrol_test.dart"
)
READER = (
    ROOT
    / "apps/mobile/integration_test/g1_bnd06_financial_plan_read_patrol_test.dart"
)
WRITE_WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_bnd06_financial_plan_write_runtime_test.dart"
)
READ_WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_bnd06_financial_plan_read_runtime_test.dart"
)
FLOW = ROOT / "apps/mobile/.maestro/g1_bnd06_financial_plan_staleness.yaml"
MAESTRO_PRODUCERS = (
    ROOT / "apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart",
    ROOT / "apps/mobile/lib/widgets/home/financial_plan_card.dart",
)
AMOUNT = "54’321 CHF / mois"
MAESTRO_ACCESSIBILITY_AMOUNT = "54\u202f321 CHF / mois"
MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN = f".*{MAESTRO_ACCESSIBILITY_AMOUNT}.*"


def _required_source(path: Path) -> str:
    assert path.is_file(), f"missing runtime implementation: {path.relative_to(ROOT)}"
    return path.read_text(encoding="utf-8")


def _collect_yaml_ids(value: Any) -> set[str]:
    if isinstance(value, dict):
        result = {value["id"]} if isinstance(value.get("id"), str) else set()
        for nested in value.values():
            result.update(_collect_yaml_ids(nested))
        return result
    if isinstance(value, list):
        result: set[str] = set()
        for nested in value:
            result.update(_collect_yaml_ids(nested))
        return result
    return set()


def _dart_argument_expression(source: str, start: int) -> str:
    depths = {"(": 0, "[": 0, "{": 0}
    matching = {")": "(", "]": "[", "}": "{"}
    quote: str | None = None
    escaped = False
    cursor = start
    while cursor < len(source):
        char = source[cursor]
        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in ("'", '"'):
            quote = char
        elif char in depths:
            depths[char] += 1
        elif char in matching:
            depths[matching[char]] -= 1
        elif char == "," and not any(depths.values()):
            break
        cursor += 1
    return source[start:cursor]


def _semantics_identifiers(source: str) -> set[str]:
    identifiers: set[str] = set()
    cursor = 0
    while (start := source.find("Semantics(", cursor)) != -1:
        open_paren = source.index("(", start)
        depth = 1
        quote: str | None = None
        escaped = False
        end = open_paren + 1
        while end < len(source) and depth:
            char = source[end]
            if quote is not None:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            elif char in ("'", '"'):
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            end += 1
        block = source[open_paren + 1 : end - 1]
        match = re.search(r"\bidentifier\s*:\s*", block)
        if match is not None:
            expression = _dart_argument_expression(block, match.end())
            identifiers.update(
                re.findall(r"['\"]([A-Za-z0-9_-]+)['\"]", expression)
            )
        cursor = end
    return identifiers


def _embedded_python(source: str, function_name: str) -> str:
    marker = f"{function_name}() {{"
    assert marker in source, f"missing executable {function_name} contract"
    function_start = source.index(marker)
    heredoc_start = source.index("<<'PY'\n", function_start) + len("<<'PY'\n")
    heredoc_end = source.index("\nPY\n", heredoc_start)
    return source[heredoc_start:heredoc_end]


def test_runtime_files_exist_and_orchestrator_is_valid_bash() -> None:
    required = (
        ORCHESTRATOR,
        WRITER,
        READER,
        WRITE_WRAPPER,
        READ_WRAPPER,
        FLOW,
    )
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    assert not missing, f"missing BND-06 runtime implementation: {missing}"
    assert ORCHESTRATOR.stat().st_mode & 0o111
    subprocess.run(["bash", "-n", str(ORCHESTRATOR)], check=True)


def test_orchestrator_is_bnd06_exact_head_and_source_bounded() -> None:
    source = _required_source(ORCHESTRATOR)
    for anchor in (
        "g1_bnd06_financial_plan_write_patrol_test.dart",
        "g1_bnd06_financial_plan_read_patrol_test.dart",
        "g1_bnd06_financial_plan_write_runtime_test.dart",
        "g1_bnd06_financial_plan_read_runtime_test.dart",
        "g1_bnd06_financial_plan_staleness.yaml",
        "apps/mobile/lib/app.dart",
        "apps/mobile/lib/models/financial_plan.dart",
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        "apps/mobile/lib/providers/financial_plan_provider.dart",
        "apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart",
        "apps/mobile/lib/services/plan_generation_service.dart",
        "apps/mobile/lib/widgets/home/financial_plan_card.dart",
        "tools/simulator/maestro_env.sh",
        '[[ "$sha" == "$head_sha" ]]',
        "git -C \"$repo_root\" diff --quiet \"$sha\" --",
        "ls-files --others --exclude-standard -- apps/mobile",
        "runtime contract is not tracked by HEAD",
        "git -C \"$repo_root\" archive --format=tar",
        "source-manifest.sha256",
    ):
        assert anchor in source, anchor
    for forbidden in (
        "g1_bnd03",
        "g1_bnd05",
        "g1_prov02",
        "g1_prov03",
    ):
        assert forbidden not in source, forbidden


def test_orchestrator_proves_process_death_clean_build_and_physical_restore() -> None:
    source = _required_source(ORCHESTRATOR)
    for anchor in (
        '"$patrol_bin" --verbose build ios',
        "--dart-define=MINT_PATROL_CLI=true",
        "xcodebuild test-without-building",
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
        "assert_external_build_empty",
        'rm -rf -- "$external_build"',
        "reset_between_patrol_stages=true",
        "git -C \"$repo_root\" archive --format=tar",
        "production_source_exported_exact=true",
        "production_source_physical=true",
        "stat.S_ISLNK",
        "entry_status.st_nlink > 1",
        "flutter build ios --simulator --debug --target lib/main.dart",
        "codesign --verify --strict --deep",
        'xattr -r "$production_app"',
        "com.apple.FinderInfo",
        "com.apple.ResourceFork",
        'xcrun simctl install "$device" "$production_app"',
        '"${maestro_command[@]}" test --udid "$device"',
        "maestro-report.sanitized.xml",
        "runtime_completed=true",
    ):
        assert anchor in source, anchor


def test_orchestrator_sanitizes_and_guards_every_retained_artifact(
    tmp_path: Path,
) -> None:
    source = _required_source(ORCHESTRATOR)
    for anchor in (
        "device.sha256",
        "REDACTED_REPO",
        "REDACTED_HOME",
        "REDACTED_SIMULATOR_UDID",
        "REDACTED_EXTERNAL_BUILD",
        "REDACTED_PRIVATE_TEMP",
        'rm -f -- "$raw"',
        "raw Maestro report removal failed",
        "external build removal failed",
        "Patrol bundle cleanup failed",
        '"contract": "g1_bnd06_financial_plan"',
        '"synthetic_data_only": True',
        '"private_fixture_used": False',
        '"write_build_exit_code"',
        '"write_exit_code"',
        '"launch_exit_code"',
        '"terminate_exit_code"',
        '"read_build_exit_code"',
        '"read_exit_code"',
        '"production_export_exit_code"',
        '"production_extract_exit_code"',
        '"production_build_exit_code"',
        '"production_codesign_verify_exit_code"',
        '"production_xattr_inspect_exit_code"',
        '"production_install_exit_code"',
        '"maestro_exit_code"',
    ):
        assert anchor in source, anchor

    sanitizer = _embedded_python(source, "sanitize_log")
    raw = tmp_path / "stage.raw.log"
    output = tmp_path / "stage.log"
    raw.write_text(
        "/tmp/mint-patrol-synthetic/read.xcresult\n"
        "/private/tmp/mint-patrol-synthetic/write.xcresult\n",
        encoding="utf-8",
    )
    subprocess.run(
        [
            sys.executable,
            "-",
            str(raw),
            str(output),
            "/Users/synthetic/repo",
            "/Users/synthetic",
            "123E4567-E89B-42D3-A456-426614174000",
            "/private/tmp/mint-patrol-synthetic",
        ],
        input=sanitizer,
        text=True,
        check=True,
    )
    sanitized = output.read_text(encoding="utf-8")
    assert sanitized.count("REDACTED_EXTERNAL_BUILD") == 2
    assert "/tmp/" not in sanitized
    assert "/private/tmp/" not in sanitized

    guard = _embedded_python(source, "verify_retained_artifacts")
    cleanup = source[source.index("cleanup() {") : source.index("trap cleanup EXIT")]
    guard_call = "if ! verify_retained_artifacts; then"
    assert guard_call in cleanup
    assert cleanup.index(guard_call) < cleanup.index('cleanup_status="failed"')
    assert cleanup.index(guard_call) < cleanup.index("write_metadata")

    def run_guard(artifacts: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                "-",
                str(artifacts),
                "/Users/synthetic/repo",
                "/Users/synthetic",
                "123E4567-E89B-42D3-A456-426614174000",
                "/private/tmp/mint-patrol-synthetic",
            ],
            input=guard,
            text=True,
            capture_output=True,
            check=False,
        )

    safe = tmp_path / "safe"
    safe.mkdir()
    (safe / "metadata.json").write_text(
        '{"cleanup_status":"passed"}\n', encoding="utf-8"
    )
    (safe / "maestro-report.sanitized.xml").write_text(
        '<testsuite device="REDACTED_SIMULATOR_UDID"/>\n', encoding="utf-8"
    )
    assert run_guard(safe).returncode == 0

    unsafe_cases = {
        "repo-path.log": "/Users/synthetic/repo",
        "home-path.log": "/Users/synthetic/Library/private.log",
        "tmp-path.log": "/tmp/mint-patrol-synthetic/result.xcresult",
        "private-tmp.log": "/private/tmp/mint-patrol-synthetic/result.xcresult",
        "private-var.log": "/private/var/folders/synthetic/result.xcresult",
        "raw-udid.log": "123E4567-E89B-42D3-A456-426614174000",
        "stage.raw.log": "must not survive cleanup",
        "maestro-report.xml": "unsanitized report",
        "maestro-debug.png": "unsanitized debug media",
        "maestro-recording.mp4": "unsanitized debug media",
    }
    for name, content in unsafe_cases.items():
        case = tmp_path / name.replace(".", "-")
        case.mkdir()
        (case / name).write_text(content, encoding="utf-8")
        assert run_guard(case).returncode != 0, name


def test_patrol_contracts_use_mint_app_and_only_synthetic_data() -> None:
    writer = _required_source(WRITER)
    reader = _required_source(READER)
    for source in (writer, reader):
        for anchor in (
            "const MintApp()",
            "CoachProfileProvider",
            "FinancialPlanProvider",
            "computeProfileHash",
        ):
            assert anchor in source, anchor
        assert "synthetic" in source.lower()
        for forbidden in (
            "MINT_LPP_PRIVATE_MANIFEST",
            "/Users/",
            "test/fixtures/",
            ".p12",
            ".pdf",
        ):
            assert forbidden not in source, forbidden
    assert _required_source(WRITE_WRAPPER).count(
        "g1_bnd06_financial_plan_write_patrol_test.dart"
    ) == 1
    assert _required_source(READ_WRAPPER).count(
        "g1_bnd06_financial_plan_read_patrol_test.dart"
    ) == 1


def test_writer_generates_then_invalidates_plan_without_leaking_amount() -> None:
    writer = _required_source(WRITER)
    for anchor in (
        "PlanGenerationService.generate(",
        ".setPlan(",
        "applySaveFact('incomeGrossMonthly'",
        "financial_plan_stale_state",
        "financial_plan_stale_recalculate",
        AMOUNT,
        "findsNothing",
    ):
        assert anchor in writer, anchor
    assert writer.index("PlanGenerationService.generate(") < writer.index(".setPlan(")
    assert writer.index(".setPlan(") < writer.index(
        "applySaveFact('incomeGrossMonthly'"
    )
    assert writer.index("applySaveFact('incomeGrossMonthly'") < writer.index(
        "financial_plan_stale_state"
    )
    assert writer.index("financial_plan_stale_state") < writer.index(AMOUNT)


def test_cold_reader_recovers_without_reverse_writes_then_reinvalidates() -> None:
    reader = _required_source(READER)
    for anchor in (
        "financial_plan_stale_state",
        "financial_plan_stale_recalculate",
        "initialPlanId",
        "goalDescriptionBefore",
        "goalCategoryBefore",
        "targetDateBefore",
        "finalTargetBefore",
        "ledgerJsonBeforeRegeneration",
        "ledgerJsonAfterRegeneration",
        "jsonEncode(",
        "profileHashAtGeneration",
        "computeProfileHash(",
        "isNot(initialPlanId)",
        "applySaveFact('incomeGrossMonthly'",
        AMOUNT,
    ):
        assert anchor in reader, anchor
    assert reader.count("applySaveFact('incomeGrossMonthly'") == 1
    assert re.search(
        r"expect\(\s*ledgerJsonAfterRegeneration,\s*ledgerJsonBeforeRegeneration\s*,?\s*\)",
        reader,
    )
    for preserved in (
        "goalDescriptionBefore",
        "goalCategoryBefore",
        "targetDateBefore",
        "finalTargetBefore",
    ):
        assert reader.count(preserved) >= 2, preserved
    recovery = reader.index("financial_plan_stale_recalculate")
    new_id = reader.index("isNot(initialPlanId)")
    current_hash = reader.index("computeProfileHash(", new_id)
    unchanged_ledger = reader.index("ledgerJsonAfterRegeneration", current_hash)
    second_mutation = reader.index("applySaveFact('incomeGrossMonthly'", unchanged_ledger)
    final_stale = reader.index("financial_plan_stale_state", second_mutation)
    assert recovery < new_id < current_hash < unchanged_ledger < second_mutation < final_stale


def test_maestro_preserves_cold_state_and_recovers_visible_amount() -> None:
    contents = _required_source(FLOW)
    header, body = contents.split("---", 1)
    assert yaml.safe_load(header) == {
        "appId": "ch.mint.app",
        "name": "G1 BND-06 persisted financial plan staleness recovery",
    }
    steps = yaml.safe_load(body)
    assert isinstance(steps, list)
    for anchor in (
        "clearState: false",
        "mint:///home",
        "home_route",
        "financial_plan_stale_state",
        "financial_plan_stale_recalculate",
        MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN,
    ):
        assert anchor in contents, anchor
    assert AMOUNT not in contents
    assert f'"{MAESTRO_ACCESSIBILITY_AMOUNT}"' not in contents
    assert "clearState: true" not in contents
    assert "/Users/" not in contents
    assert "MINT_LPP_PRIVATE_MANIFEST" not in contents

    absent = {"assertNotVisible": MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN}
    tap = {"tapOn": {"id": "financial_plan_stale_recalculate"}}
    visible = {"assertVisible": MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN}
    assert absent in steps
    assert tap in steps
    assert visible in steps
    assert steps.index(absent) < steps.index(tap) < steps.index(visible)

    flow_ids = _collect_yaml_ids(steps)
    producer_ids: set[str] = set()
    for producer in MAESTRO_PRODUCERS:
        producer_ids.update(_semantics_identifiers(_required_source(producer)))
    assert flow_ids
    assert flow_ids <= producer_ids, sorted(flow_ids - producer_ids)
