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
    ROOT / "apps/mobile/integration_test/g1_bnd06_financial_plan_write_patrol_test.dart"
)
READER = (
    ROOT / "apps/mobile/integration_test/g1_bnd06_financial_plan_read_patrol_test.dart"
)
WRITE_WRAPPER = (
    ROOT / "apps/mobile/test/patrol/g1_bnd06_financial_plan_write_runtime_test.dart"
)
READ_WRAPPER = (
    ROOT / "apps/mobile/test/patrol/g1_bnd06_financial_plan_read_runtime_test.dart"
)
FLOW = ROOT / "apps/mobile/.maestro/g1_bnd06_financial_plan_staleness.yaml"
FEATURE_FLAGS = ROOT / "apps/mobile/lib/services/feature_flags.dart"
SETUP_CARD = ROOT / "apps/mobile/lib/widgets/coach/financial_plan_setup_card.dart"
MAESTRO_PRODUCERS = (
    ROOT / "apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart",
    ROOT / "apps/mobile/lib/widgets/home/financial_plan_card.dart",
    SETUP_CARD,
)
AMOUNT = "54’321 CHF / mois"
MAESTRO_ACCESSIBILITY_AMOUNT = "54\u202f321 CHF / mois"
MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN = f".*{MAESTRO_ACCESSIBILITY_AMOUNT}.*"
TEST_FINANCIAL_PLAN_FLAG = "MINT_TEST_FINANCIAL_PLAN_SETUP"


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
    identifiers = set(
        re.findall(r"\bidentifier\s*:\s*['\"]([A-Za-z0-9_-]+)['\"]", source)
    )
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
        for match in re.finditer(r"\bidentifier\s*:\s*", block):
            expression = _dart_argument_expression(block, match.end())
            identifiers.update(re.findall(r"['\"]([A-Za-z0-9_-]+)['\"]", expression))
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
        FEATURE_FLAGS,
        SETUP_CARD,
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
        "apps/mobile/lib/services/feature_flags.dart",
        "apps/mobile/lib/services/plan_generation_service.dart",
        "apps/mobile/lib/widgets/coach/financial_plan_setup_card.dart",
        "apps/mobile/lib/widgets/home/financial_plan_card.dart",
        "tools/simulator/maestro_env.sh",
        '[[ "$sha" == "$head_sha" ]]',
        'git -C "$repo_root" diff --quiet "$sha" --',
        "ls-files --others --exclude-standard -- apps/mobile",
        "runtime contract is not tracked by HEAD",
        'git -C "$repo_root" archive --format=tar',
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
        'git -C "$repo_root" archive --format=tar',
        "production_source_exported_exact=true",
        "production_source_physical=true",
        "stat.S_ISLNK",
        "entry_status.st_nlink > 1",
        "flutter build ios --simulator --debug --target lib/main.dart",
        f"--dart-define={TEST_FINANCIAL_PLAN_FLAG}=true",
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

    test_opt_in = f"--dart-define={TEST_FINANCIAL_PLAN_FLAG}=true"
    assert source.count(test_opt_in) == 1
    assert source.index("production_source_physical=true") < source.index(test_opt_in)


def test_financial_plan_test_opt_in_is_explicit_fail_closed_and_local_only() -> None:
    flags = _required_source(FEATURE_FLAGS)
    declaration = re.search(
        r"financialPlanSetupEnabled\s*=\s*const bool\.fromEnvironment\(\s*"
        rf"['\"]{TEST_FINANCIAL_PLAN_FLAG}['\"]\s*,\s*"
        r"defaultValue:\s*false\s*,?\s*\)",
        flags,
    )
    assert declaration, "financial plan setup must use the named test-only opt-in"

    apply_from_map = flags[
        flags.index("static void applyFromMap") : flags.index(
            "// ── Server-driven refresh", flags.index("static void applyFromMap")
        )
    ]
    assert "financialPlanSetupEnabled" not in apply_from_map
    assert TEST_FINANCIAL_PLAN_FLAG not in apply_from_map

    orchestrator = _required_source(ORCHESTRATOR)
    for anchor in (
        'production_entrypoint="lib/main.dart"',
        f'test_compile_time_opt_in="{TEST_FINANCIAL_PLAN_FLAG}"',
        "test_compile_time_opt_in_default=false",
        'test_compile_time_opt_in_scope="exact_archive_production_entrypoint_debug_build_only"',
        '"production_entrypoint": os.environ["MINT_META_PRODUCTION_ENTRYPOINT"]',
        '"test_compile_time_opt_in"',
        '"default": os.environ["MINT_META_TEST_OPT_IN_DEFAULT"] == "true"',
        '"scope": os.environ["MINT_META_TEST_OPT_IN_SCOPE"]',
    ):
        assert anchor in orchestrator, anchor


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
    for source, plan_name in ((writer, "generated"), (reader, "regenerated")):
        for anchor in (
            "const MintApp()",
            "CoachProfileProvider",
            "FinancialPlanProvider",
            "dependencyHash",
            "profileHashAtGeneration",
        ):
            assert anchor in source, anchor
        assert re.search(
            rf"expect\(\s*{plan_name}\.dependencyHash,\s*"
            rf"{plan_name}\.profileHashAtGeneration\s*,?\s*\)",
            source,
        ), plan_name
        assert "synthetic" in source.lower()
        for forbidden in (
            "MINT_LPP_PRIVATE_MANIFEST",
            "/Users/",
            "test/fixtures/",
            ".p12",
            ".pdf",
        ):
            assert forbidden not in source, forbidden
    assert (
        _required_source(WRITE_WRAPPER).count(
            "g1_bnd06_financial_plan_write_patrol_test.dart"
        )
        == 1
    )
    assert (
        _required_source(READ_WRAPPER).count(
            "g1_bnd06_financial_plan_read_patrol_test.dart"
        )
        == 1
    )


def test_patrol_contracts_enable_and_restore_financial_plan_flag() -> None:
    for path in (WRITER, READER):
        source = _required_source(path)
        enabled = "FeatureFlags.financialPlanSetupEnabled = true;"
        restored = "FeatureFlags.financialPlanSetupEnabled = false;"
        pump = "await $.pumpWidgetAndSettle(const MintApp());"

        assert "services/feature_flags.dart" in source, path.name
        assert source.count(enabled) == 1, path.name
        assert source.count(restored) == 1, path.name
        assert "addTearDown(()" in source, path.name
        assert source.index(enabled) < source.index("addTearDown(()"), path.name
        assert source.index("addTearDown(()") < source.index(restored), path.name
        assert source.index(restored) < source.index(pump), path.name


def test_writer_generates_then_invalidates_plan_without_leaking_amount() -> None:
    writer = _required_source(WRITER)
    for anchor in (
        "PlanGenerationService.generate(",
        "goalCategory: 'goal_retirement_plan'",
        "'q_date_of_birth'",
        "'q_has_pension_fund': false",
        "'prevoyance.hasPensionFund'",
        "'source': 'userInput'",
        "inputAsOf.month + 1",
        "targetDate.year - 58",
        "targetDate.year - 59",
        "goalAmount: 54321",
        "generated.monthlyTarget, 54321",
        "generated.dependencyBranch, 'retirementNoLpp'",
        ".setPlan(",
        "financial_plan_stale_state",
        "financial_plan_stale_recalculate",
        AMOUNT,
        "findsNothing",
    ):
        assert anchor in writer, anchor
    date_mutation = re.search(r"applySaveFact\(\s*['\"]dateOfBirth['\"]", writer)
    assert date_mutation, "writer must mutate a retirementNoLpp dependency"
    assert not re.search(r"applySaveFact\(\s*['\"]incomeGrossMonthly['\"]", writer)
    assert writer.index("PlanGenerationService.generate(") < writer.index(".setPlan(")
    assert writer.index(".setPlan(") < date_mutation.start()
    assert date_mutation.start() < writer.index("financial_plan_stale_state")
    assert writer.index("financial_plan_stale_state") < writer.index(AMOUNT)


def test_cold_reader_recovers_without_reverse_writes_then_reinvalidates() -> None:
    reader = _required_source(READER)
    for anchor in (
        "financial_plan_stale_state",
        "financial_plan_stale_recalculate",
        "financial_plan_setup_retirement_horizon",
        "await retirementHorizon.tap();",
        "financial_plan_setup_retirement_continue",
        "await retirementContinue.tap();",
        "financial_plan_setup_review",
        "financial_plan_setup_confirmation",
        "financial_plan_setup_confirm",
        "initialPlanId",
        "goalDescriptionBefore",
        "goalCategoryBefore",
        "targetDateBefore",
        "finalTargetBefore",
        "ledgerJsonBeforeRegeneration",
        "ledgerJsonAfterRegeneration",
        "jsonEncode(",
        "profileHashAtGeneration",
        "dependencyHash",
        "isNot(initialPlanId)",
        "regenerated.dependencyBranch, 'retirementNoLpp'",
        "targetDateBefore.year - 60",
        AMOUNT,
    ):
        assert anchor in reader, anchor
    assert "financial_plan_setup_retirement_scope" not in reader
    assert "financial_plan_setup_return_assumption" not in reader
    assert not re.search(r"applySaveFact\(\s*['\"]incomeGrossMonthly['\"]", reader)
    date_mutations = list(
        re.finditer(r"applySaveFact\(\s*['\"]dateOfBirth['\"]", reader)
    )
    assert len(date_mutations) == 1
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
    horizon = reader.index("financial_plan_setup_retirement_horizon", recovery)
    horizon_tap = reader.index("await retirementHorizon.tap();", horizon)
    retirement_continue = reader.index(
        "financial_plan_setup_retirement_continue", horizon_tap
    )
    continue_tap = reader.index("await retirementContinue.tap();", retirement_continue)
    review = reader.index("financial_plan_setup_review", continue_tap)
    confirmation = reader.index("financial_plan_setup_confirmation", review)
    confirm = reader.index("'financial_plan_setup_confirm'", confirmation)
    new_id = reader.index("isNot(initialPlanId)")
    fingerprint_alias = reader.index("regenerated.dependencyHash", new_id)
    unchanged_ledger = reader.index("ledgerJsonAfterRegeneration", fingerprint_alias)
    second_mutation = date_mutations[0].start()
    assert second_mutation > unchanged_ledger
    final_stale = reader.index("financial_plan_stale_state", second_mutation)
    assert (
        recovery
        < horizon
        < horizon_tap
        < retirement_continue
        < continue_tap
        < review
        < confirmation
        < confirm
        < new_id
        < fingerprint_alias
        < unchanged_ledger
        < second_mutation
        < final_stale
    )


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
        "financial_plan_setup_retirement_horizon",
        "financial_plan_setup_retirement_continue",
        "financial_plan_setup_review",
        "financial_plan_setup_confirmation",
        "financial_plan_setup_confirm",
        MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN,
    ):
        assert anchor in contents, anchor
    assert AMOUNT not in contents
    assert f'"{MAESTRO_ACCESSIBILITY_AMOUNT}"' not in contents
    assert "clearState: true" not in contents
    assert "/Users/" not in contents
    assert "MINT_LPP_PRIVATE_MANIFEST" not in contents
    assert "financial_plan_setup_retirement_scope" not in contents
    assert "financial_plan_setup_return_assumption" not in contents

    absent = {"assertNotVisible": MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN}
    tap = {"tapOn": {"id": "financial_plan_stale_recalculate"}}
    horizon_tap = {"tapOn": {"id": "financial_plan_setup_retirement_horizon"}}
    continue_tap = {"tapOn": {"id": "financial_plan_setup_retirement_continue"}}
    review_visible = {"assertVisible": {"id": "financial_plan_setup_review"}}
    review_tap = {"tapOn": {"id": "financial_plan_setup_review"}}
    confirmation = {"assertVisible": {"id": "financial_plan_setup_confirmation"}}
    confirm_tap = {"tapOn": {"id": "financial_plan_setup_confirm"}}
    visible = {"assertVisible": MAESTRO_ACCESSIBILITY_AMOUNT_PATTERN}
    assert absent in steps
    assert tap in steps
    assert visible in steps
    assert (
        steps.index(absent)
        < steps.index(tap)
        < steps.index(horizon_tap)
        < steps.index(continue_tap)
        < steps.index(review_visible)
        < steps.index(review_tap)
        < steps.index(confirmation)
        < steps.index(confirm_tap)
        < steps.index(visible)
    )

    flow_ids = _collect_yaml_ids(steps)
    producer_ids: set[str] = set()
    for producer in MAESTRO_PRODUCERS:
        producer_ids.update(_semantics_identifiers(_required_source(producer)))
    assert flow_ids
    assert flow_ids <= producer_ids, sorted(flow_ids - producer_ids)
