import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def test_mint_codesign_wrapper_skips_only_debug_simulator_flutter_frameworks() -> None:
    wrapper_path = ROOT / "apps/mobile/ios/mint_xcode_tools/codesign"
    wrapper = wrapper_path.read_text()

    assert os.access(wrapper_path, os.X_OK)
    assert "/usr/bin/xattr -cr" in wrapper
    assert "Debug-iphonesimulator" in wrapper
    assert "App.framework/App" in wrapper
    assert "Flutter.framework/Flutter" in wrapper
    assert 'if [ "$sign_identity" = "-" ]' in wrapper
    assert "exec /usr/bin/codesign" in wrapper


def test_mobile_patrol_gate_exports_repo_local_codesign_wrapper() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    assert "export_mint_ios_codesign_path()" in gate
    assert "apps/mobile/ios/mint_xcode_tools" in gate

    patrol_runner = gate.split("run_mobile_patrol_test()", maxsplit=1)[1].split(
        "run_f2_patrol()",
        maxsplit=1,
    )[0]
    assert patrol_runner.index("export_mint_ios_codesign_path") < patrol_runner.index(
        '"$patrol_bin" test'
    )


def test_simulator_walker_exports_repo_local_codesign_wrapper_before_ios_builds() -> None:
    walker = (ROOT / "tools/simulator/walker.sh").read_text()

    assert 'ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"' in walker
    assert 'export PATH="$ROOT/apps/mobile/ios/mint_xcode_tools:$PATH"' in walker
    assert walker.index('export PATH="$ROOT/apps/mobile/ios/mint_xcode_tools:$PATH"') < (
        walker.index("flutter build ios --simulator")
    )


def test_ios_simulator_build_script_uses_repo_local_codesign_wrapper() -> None:
    script_path = ROOT / "tools/checks/ios_simulator_build_with_mint_codesign.sh"
    script = script_path.read_text()

    assert os.access(script_path, os.X_OK)
    assert 'codesign_dir="$ROOT/apps/mobile/ios/mint_xcode_tools"' in script
    assert 'export PATH="$codesign_dir:$PATH"' in script
    assert "flutter build ios --simulator" in script
