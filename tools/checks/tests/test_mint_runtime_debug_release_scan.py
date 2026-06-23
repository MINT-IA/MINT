import importlib.util
import sys
import zipfile
from pathlib import Path


def load_scanner():
    root = Path(__file__).resolve().parents[1]
    module_path = root / "mint_runtime_debug_release_scan.py"
    spec = importlib.util.spec_from_file_location(
        "mint_runtime_debug_release_scan",
        module_path,
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_prod_workflows(root: Path, testflight: str, play_store: str = "") -> None:
    workflows = root / ".github" / "workflows"
    workflows.mkdir(parents=True)
    (workflows / "testflight.yml").write_text(testflight, encoding="utf-8")
    (workflows / "play-store.yml").write_text(play_store, encoding="utf-8")


def test_workflow_scan_flags_enabled_debug_define_but_ignores_comments(tmp_path):
    scanner = load_scanner()
    write_prod_workflows(
        tmp_path,
        """
        # Documentation only: --dart-define=ENABLE_ADMIN=1
        run: |
          EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_TOOLS=true"
          flutter build ios --release $EXTRA_DEFINES
        """,
    )

    findings = scanner.scan_release_workflows(tmp_path)

    assert len(findings) == 1
    assert findings[0].label == "ENABLE_DEBUG_TOOLS=true"


def test_workflow_scan_checks_dart_define_from_file_inputs(tmp_path):
    scanner = load_scanner()
    (tmp_path / "apps" / "mobile").mkdir(parents=True)
    (tmp_path / "apps" / "mobile" / "release_defines.json").write_text(
        '{"API_BASE_URL":"https://example.test","ENABLE_ADMIN":true}\n',
        encoding="utf-8",
    )
    write_prod_workflows(
        tmp_path,
        """
        run: |
          flutter build ios --release --dart-define-from-file=release_defines.json
        """,
    )

    findings = scanner.scan_release_workflows(tmp_path)

    assert len(findings) == 1
    assert findings[0].label == "ENABLE_ADMIN=true"
    assert findings[0].path.name == "release_defines.json"


def test_workflow_scan_rejects_dynamic_debug_define_values(tmp_path):
    scanner = load_scanner()
    write_prod_workflows(
        tmp_path,
        """
        run: |
          flutter build ios --release --dart-define=ENABLE_ADMIN=${{ vars.ENABLE_ADMIN }}
        """,
        """
        run: |
          EXTRA_DEFINES="--dart-define=ENABLE_DEBUG_TOOLS=$ENABLE_DEBUG_TOOLS"
        """,
    )

    findings = scanner.scan_release_workflows(tmp_path)

    labels = {finding.label for finding in findings}
    assert "ENABLE_ADMIN=dynamic" in labels
    assert "ENABLE_DEBUG_TOOLS=dynamic" in labels


def test_artifact_scan_accepts_clean_artifact(tmp_path):
    scanner = load_scanner()
    app = tmp_path / "Runner.app"
    app.mkdir()
    (app / "App").write_bytes(b"API_BASE_URL\x00Mint production build")

    assert scanner.scan_artifacts([app]) == []


def test_artifact_scan_rejects_debug_route_and_flag(tmp_path):
    scanner = load_scanner()
    app = tmp_path / "Runner.app"
    app.mkdir()
    (app / "App").write_bytes(
        b"/admin/debug-spine\x00ENABLE_DEBUG_TOOLS\x00debug-spine-after_reset"
    )

    findings = scanner.scan_artifacts([app])

    labels = {finding.label for finding in findings}
    assert "/admin/debug-spine" in labels
    assert "ENABLE_DEBUG_TOOLS" in labels
    assert "debug-spine snapshot id" in labels


def test_artifact_scan_rejects_admin_shell_leak(tmp_path):
    scanner = load_scanner()
    app = tmp_path / "Runner.app"
    app.mkdir()
    (app / "App").write_bytes(b"ENABLE_ADMIN\x00/admin/routes\x00Routes owned by admin")

    findings = scanner.scan_artifacts([app])

    labels = {finding.label for finding in findings}
    assert "ENABLE_ADMIN" in labels
    assert "/admin/routes" in labels
    assert "admin route registry label" in labels


def test_artifact_scan_ignores_debug_spine_worktree_path(tmp_path):
    scanner = load_scanner()
    app = tmp_path / "Runner.app"
    app.mkdir()
    (app / "Runner").write_bytes(
        b"/Users/julienbattaglia/Desktop/MINT.debug-spine.nosync/apps/mobile/ios/Pods/Sentry"
    )

    assert scanner.scan_artifacts([app]) == []


def test_artifact_scan_checks_compressed_release_archives(tmp_path):
    scanner = load_scanner()
    archive = tmp_path / "Mint.ipa"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zipped:
        zipped.writestr("Payload/Runner.app/App", b"/admin/debug-spine")

    findings = scanner.scan_artifacts([archive])

    assert len(findings) == 1
    assert findings[0].label == "/admin/debug-spine"
    assert "Payload/Runner.app/App" in str(findings[0].path)
