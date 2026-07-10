from __future__ import annotations

from pathlib import Path

from tools.checks import patrol_tooling_guard


def _write_project(root: Path, pubspec: str) -> None:
    mobile = root / "apps" / "mobile"
    (mobile / "test" / "patrol").mkdir(parents=True)
    (mobile / "test" / "patrol" / "mint_runtime_smoke_test.dart").write_text(
        "const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');\nvoid main() {}\n",
        encoding="utf-8",
    )
    (mobile / "pubspec.yaml").write_text(pubspec, encoding="utf-8")
    runbook = root / ".github" / "workflows"
    runbook.mkdir(parents=True)
    (runbook / "patrol.md").write_text("--dart-define=MINT_PATROL_CLI=true\n", encoding="utf-8")


def _valid_pubspec() -> str:
    return """
name: mint_mobile
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol: ^4.6.1
  flutter_lints: ^3.0.0

patrol:
  app_name: Mint
  test_directory: test/patrol
  ios:
    bundle_id: ch.mint.app
"""


def test_guard_accepts_pub_cache_patrol_even_when_not_on_path(monkeypatch, tmp_path: Path) -> None:
    _write_project(tmp_path, _valid_pubspec())
    patrol = tmp_path / ".pub-cache" / "bin" / "patrol"
    patrol.parent.mkdir(parents=True)
    patrol.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    patrol.chmod(0o755)

    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setattr(patrol_tooling_guard.shutil, "which", lambda binary: None)

    assert patrol_tooling_guard.check(tmp_path) == []


def test_guard_rejects_missing_patrol_dependency(tmp_path: Path) -> None:
    _write_project(
        tmp_path,
        """
name: mint_mobile
dev_dependencies:
  flutter_test:
    sdk: flutter

patrol:
  app_name: Mint
  test_directory: test/patrol
  ios:
    bundle_id: ch.mint.app
""",
    )

    errors = patrol_tooling_guard.check(tmp_path, require_cli=False)

    assert "apps/mobile/pubspec.yaml must declare dev_dependencies.patrol" in errors


def test_guard_rejects_missing_patrol_config(tmp_path: Path) -> None:
    _write_project(
        tmp_path,
        """
name: mint_mobile
dev_dependencies:
  patrol: ^4.6.1
""",
    )

    errors = patrol_tooling_guard.check(tmp_path, require_cli=False)

    assert "apps/mobile/pubspec.yaml must define patrol app_name, test_directory, and iOS bundle_id" in errors


def test_guard_rejects_missing_patrol_tests(tmp_path: Path) -> None:
    mobile = tmp_path / "apps" / "mobile"
    mobile.mkdir(parents=True)
    (mobile / "pubspec.yaml").write_text(_valid_pubspec(), encoding="utf-8")

    errors = patrol_tooling_guard.check(tmp_path, require_cli=False)

    assert "apps/mobile/test/patrol must contain at least one *_test.dart" in errors


def test_guard_rejects_missing_patrol_define_in_test(tmp_path: Path) -> None:
    _write_project(tmp_path, _valid_pubspec())
    test_file = tmp_path / "apps" / "mobile" / "test" / "patrol" / "mint_runtime_smoke_test.dart"
    test_file.write_text("void main() {}\n", encoding="utf-8")

    errors = patrol_tooling_guard.check(tmp_path, require_cli=False)

    assert "Patrol smoke tests must gate native-only patrolTest with MINT_PATROL_CLI" in errors


def test_guard_rejects_missing_patrol_define_in_runbook(tmp_path: Path) -> None:
    _write_project(tmp_path, _valid_pubspec())
    (tmp_path / ".github" / "workflows" / "patrol.md").write_text("patrol test\n", encoding="utf-8")

    errors = patrol_tooling_guard.check(tmp_path, require_cli=False)

    assert "Patrol runbook must pass --dart-define=MINT_PATROL_CLI=true" in errors
