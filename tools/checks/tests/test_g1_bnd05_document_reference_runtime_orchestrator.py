from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = (
    ROOT / "tools/simulator/patrol_bnd05_document_reference_process_death.sh"
)
WRITER = (
    ROOT
    / "apps/mobile/integration_test/g1_bnd05_document_reference_write_patrol_test.dart"
)
READER = (
    ROOT
    / "apps/mobile/integration_test/g1_bnd05_document_reference_read_patrol_test.dart"
)
WRITE_WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_bnd05_document_reference_write_runtime_test.dart"
)
READ_WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_bnd05_document_reference_read_runtime_test.dart"
)
FLOW = ROOT / "apps/mobile/.maestro/g1_bnd05_document_reference_flag_off.yaml"
MAESTRO_PRODUCERS = (
    ROOT / "apps/mobile/lib/screens/document_scan/document_scan_screen.dart",
    ROOT / "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart",
    ROOT / "apps/mobile/lib/screens/document_detail_screen.dart",
    ROOT / "apps/mobile/lib/screens/documents_screen.dart",
)


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
    if re.search(r"\bidentifier\s*:\s*semanticsIdentifier\b", source):
        for match in re.finditer(r"\bsemanticsIdentifier\s*:\s*", source):
            expression = _dart_argument_expression(source, match.end())
            identifiers.update(
                re.findall(r"['\"]([A-Za-z0-9_-]+)['\"]", expression)
            )
    return identifiers


def _embedded_python(source: str, function_name: str) -> str:
    marker = f"{function_name}() {{"
    assert marker in source, f"missing executable {function_name} contract"
    function_start = source.index(marker)
    heredoc_start = source.index("<<'PY'\n", function_start) + len("<<'PY'\n")
    heredoc_end = source.index("\nPY\n", heredoc_start)
    return source[heredoc_start:heredoc_end]


def test_orchestrator_is_valid_bash() -> None:
    assert ORCHESTRATOR.is_file()
    assert ORCHESTRATOR.stat().st_mode & 0o111
    subprocess.run(["bash", "-n", str(ORCHESTRATOR)], check=True)


def test_orchestrator_is_bnd05_exact_sha_and_source_bounded() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "g1_bnd05_document_reference_write_patrol_test.dart",
        "g1_bnd05_document_reference_read_patrol_test.dart",
        "g1_bnd05_document_reference_write_runtime_test.dart",
        "g1_bnd05_document_reference_read_runtime_test.dart",
        "g1_bnd05_document_reference_flag_off.yaml",
        "apps/mobile/lib/app.dart",
        "apps/mobile/lib/models/lpp_evidence.dart",
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        "apps/mobile/lib/providers/document_provider.dart",
        "apps/mobile/lib/providers/timeline_provider.dart",
        "apps/mobile/lib/screens/document_detail_screen.dart",
        "apps/mobile/lib/screens/document_scan/document_scan_screen.dart",
        "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart",
        "apps/mobile/lib/screens/documents_screen.dart",
        "apps/mobile/lib/services/feature_flags.dart",
        "apps/mobile/lib/services/report_persistence_service.dart",
        "tools/simulator/maestro_env.sh",
        '[[ "$sha" == "$head_sha" ]]',
        "git -C \"$repo_root\" diff --quiet \"$sha\" --",
        "ls-files --others --exclude-standard -- apps/mobile",
        "runtime contract is not tracked by HEAD",
        "source-manifest.sha256",
    ):
        assert anchor in source, anchor
    for forbidden in (
        "g1_bnd03",
        "budget_",
        "g1_prov02",
        "g1_prov03",
    ):
        assert forbidden not in source, forbidden


def test_orchestrator_proves_real_process_death_and_production_restore() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        '"$patrol_bin" --verbose build ios',
        "--dart-define=MINT_PATROL_CLI=true",
        "xcodebuild test-without-building",
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
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


def test_orchestrator_sanitizes_every_retained_artifact() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
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
        '"contract": "g1_bnd05_document_reference"',
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


def test_log_sanitizer_normalizes_macos_tmp_aliases(tmp_path: Path) -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    sanitizer = _embedded_python(source, "sanitize_log")
    raw = tmp_path / "stage.raw.log"
    output = tmp_path / "stage.log"
    raw.write_text(
        "\n".join(
            (
                "/tmp/mint-patrol-synthetic/build/read.xcresult",
                "/private/tmp/mint-patrol-synthetic/build/write.xcresult",
            )
        ),
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


def test_final_retained_artifact_guard_is_executable_and_fail_closed(
    tmp_path: Path,
) -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    guard = _embedded_python(source, "verify_retained_artifacts")
    cleanup = source[source.index("cleanup() {") : source.index("trap cleanup EXIT")]
    guard_call = "if ! verify_retained_artifacts; then"
    assert guard_call in cleanup
    assert cleanup.index(guard_call) < cleanup.index('cleanup_status="failed"')
    assert cleanup.index(guard_call) < cleanup.index("write_metadata")

    repo = "/Users/synthetic/repo"
    home = "/Users/synthetic"
    device = "123E4567-E89B-42D3-A456-426614174000"
    external_root = "/private/tmp/mint-patrol-synthetic"

    def run_guard(artifacts: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                "-",
                str(artifacts),
                repo,
                home,
                device,
                external_root,
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
        "repo-path.log": repo,
        "home-path.log": f"{home}/Library/private.log",
        "tmp-path.log": "/tmp/mint-patrol-synthetic/result.xcresult",
        "private-tmp-path.log": f"{external_root}/result.xcresult",
        "private-var-path.log": "/private/var/folders/synthetic/result.xcresult",
        "raw-udid.log": device,
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


def test_runtime_contracts_are_synthetic_and_use_production_wiring() -> None:
    writer = WRITER.read_text(encoding="utf-8")
    reader = READER.read_text(encoding="utf-8")
    assert "const MintApp()" in writer
    assert "const MintApp()" in reader
    for source in (writer, reader):
        for anchor in (
            "CoachProfileProvider",
            "DocumentProvider",
            "TimelineProvider",
            "document_reference_remove",
            "DocumentReferenceStore.storageKey",
        ):
            assert anchor in source, anchor
        for forbidden in (
            "MINT_LPP_PRIVATE_MANIFEST",
            "/Users/",
        ):
            assert forbidden not in source, forbidden
    assert "acceptLppReview(" in writer
    assert "recordConfirmedLppReview(receipt)" in writer
    assert "acceptLppReview(" not in reader
    assert "recordConfirmedLppReview(" not in reader
    assert "deleteConfirmedReference" not in writer
    assert "strictRootBeforeDelete" in reader
    assert "ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1']" in reader
    assert "_rawMarker" in writer
    assert "synthetic runtime bytes only" in writer
    assert WRITE_WRAPPER.read_text(encoding="utf-8").count("write_patrol_test.dart") == 1
    assert READ_WRAPPER.read_text(encoding="utf-8").count("read_patrol_test.dart") == 1


def test_maestro_flow_is_fail_closed_and_synthetic() -> None:
    contents = FLOW.read_text(encoding="utf-8")
    header, body = contents.split("---", 1)
    assert yaml.safe_load(header) == {
        "appId": "ch.mint.app",
        "name": "G1 BND-05 production-default document reference fail-closed",
    }
    steps = yaml.safe_load(body)
    assert isinstance(steps, list)
    for anchor in (
        "clearState: true",
        "mint:///scan?type=lppCertificate",
        "document_scan_lpp_type_selector",
        "mint:///documents/45454545-4545-4545-8545-454545454545",
        "document_reference_missing_state",
        "document_reference_back_to_documents",
        "document_reference_remove",
        "tapOn:",
        "documents_screen_state",
        "CHF 143'287",
    ):
        assert anchor in contents, anchor
    recovery_tap = {"tapOn": {"id": "document_reference_back_to_documents"}}
    recovery_destination = {"assertVisible": {"id": "documents_screen_state"}}
    assert recovery_tap in steps
    assert recovery_destination in steps
    assert steps.index(recovery_tap) < steps.index(recovery_destination)
    assert "lpp_review_confirm_cta" not in contents
    assert "/Users/" not in contents
    assert "MINT_LPP_PRIVATE_MANIFEST" not in contents


def test_every_maestro_id_has_an_explicit_production_semantics_producer() -> None:
    _, body = FLOW.read_text(encoding="utf-8").split("---", 1)
    flow_ids = _collect_yaml_ids(yaml.safe_load(body))
    producer_ids: set[str] = set()
    for producer in MAESTRO_PRODUCERS:
        producer_ids.update(
            _semantics_identifiers(producer.read_text(encoding="utf-8"))
        )

    assert flow_ids
    assert flow_ids <= producer_ids, sorted(flow_ids - producer_ids)
