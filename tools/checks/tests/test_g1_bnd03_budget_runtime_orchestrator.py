from __future__ import annotations

import json
import os
import re
import shutil
import signal
import stat
import subprocess
import tarfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
FLOW = ROOT / "apps/mobile/.maestro/g1_bnd03_budget_cold.yaml"
WRITE_CONTRACT = (
    ROOT / "apps/mobile/integration_test/g1_bnd03_budget_persistence_write_patrol_test.dart"
)
READ_CONTRACT = (
    ROOT / "apps/mobile/integration_test/g1_bnd03_budget_persistence_read_patrol_test.dart"
)
WRITE_RUNNER = (
    ROOT / "apps/mobile/test/patrol/g1_bnd03_budget_persistence_write_runtime_test.dart"
)
READ_RUNNER = (
    ROOT / "apps/mobile/test/patrol/g1_bnd03_budget_persistence_read_runtime_test.dart"
)
ORCHESTRATOR = ROOT / "tools/simulator/patrol_bnd03_budget_process_death.sh"
BUDGET_SCREEN = ROOT / "apps/mobile/lib/screens/budget/budget_screen.dart"
SYNTHETIC_UDID = "B03E429D-0422-4357-B754-536637D979F9"
SYNTHETIC_SHA = "3" * 40
BUNDLE_ID = "ch.mint.app"


def _write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_runtime(
    tmp_path: Path,
    *,
    write_build_exit: int = 0,
    write_exit: int = 0,
    launch_exit: int = 0,
    terminate_exit: int = 0,
    read_build_exit: int = 0,
    read_exit: int = 0,
    production_export_exit: int = 0,
    production_extract_exit: int = 0,
    production_build_exit: int = 0,
    production_codesign_exit: int = 0,
    production_xattr_exit: int = 0,
    production_xattr_output: str = "",
    production_install_exit: int = 0,
    maestro_exit: int = 0,
    maestro_report: bool = True,
    maestro_invalid_xml: bool = False,
    maestro_override: bool = True,
    diff_exit: int = 0,
    untracked_mobile: bool = False,
    generate_bundle: bool = True,
    bundle_as_directory: bool = False,
    bundle_tracked: bool = False,
    patrol_sleep: int = 0,
    archive_sleep: int = 0,
    tar_sleep: int = 0,
    flutter_sleep: int = 0,
    product_failure: str = "",
    unsafe_export_entry: str = "",
) -> dict[str, str]:
    repo = tmp_path / "repo"
    mobile = repo / "apps/mobile"
    for relative in (
        "integration_test/g1_bnd03_budget_persistence_write_patrol_test.dart",
        "integration_test/g1_bnd03_budget_persistence_read_patrol_test.dart",
        "test/patrol/g1_bnd03_budget_persistence_write_runtime_test.dart",
        "test/patrol/g1_bnd03_budget_persistence_read_runtime_test.dart",
        ".maestro/g1_bnd03_budget_cold.yaml",
        "lib/screens/budget/budget_container_screen.dart",
        "lib/screens/budget/budget_setup_screen.dart",
        "lib/screens/budget/budget_screen.dart",
    ):
        target = mobile / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("tracked synthetic contract\n", encoding="utf-8")
    original_build = mobile / "build"
    original_build.mkdir(parents=True)
    (original_build / "original-build-marker.txt").write_text(
        "must survive every exit path\n",
        encoding="utf-8",
    )
    flutter_cache = (
        original_build
        / "ios/Debug-iphonesimulator/Flutter.framework/Flutter"
    )
    flutter_cache.parent.mkdir(parents=True)
    flutter_cache.write_text("normal cached Flutter framework\n", encoding="utf-8")
    (mobile / ".dart_tool").mkdir()
    simulator = repo / "tools/simulator"
    simulator.mkdir(parents=True)
    (simulator / "patrol_bnd03_budget_process_death.sh").write_text(
        "tracked synthetic orchestrator\n", encoding="utf-8"
    )

    archive_source = tmp_path / "archive-source/apps/mobile"
    for relative in (
        "pubspec.yaml",
        "pubspec.lock",
        "lib/main.dart",
        "ios/Podfile",
        "ios/Podfile.lock",
        "ios/Runner.xcodeproj/project.pbxproj",
        "ios/Flutter/Debug.xcconfig",
    ):
        target = archive_source / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(f"tracked archive input: {relative}\n", encoding="utf-8")
    if unsafe_export_entry == "symlink":
        (archive_source / "unsafe-alias").symlink_to(tmp_path / "outside")
    elif unsafe_export_entry == "hardlink":
        first_alias = archive_source / "unsafe-hardlink-a"
        first_alias.write_text("unsafe linked fixture\n", encoding="utf-8")
        os.link(first_alias, archive_source / "unsafe-hardlink-b")
    elif unsafe_export_entry:
        raise ValueError(f"unsupported unsafe export entry: {unsafe_export_entry}")
    production_archive = tmp_path / "tracked-mobile.tar"
    with tarfile.open(production_archive, "w") as archive:
        archive.add(archive_source.parent, arcname="apps")
    production_mobile_tree = "4" * 40
    real_tar = shutil.which("tar")
    assert real_tar is not None

    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls = tmp_path / "calls.log"
    fake_git = fake_bin / "git"
    fake_patrol = fake_bin / "patrol"
    fake_xcodebuild = fake_bin / "xcodebuild"
    fake_flutter = fake_bin / "flutter"
    fake_tar = fake_bin / "tar"
    fake_codesign = fake_bin / "codesign"
    fake_xattr = fake_bin / "xattr"
    fake_xcrun = fake_bin / "xcrun"
    fake_maestro = fake_bin / "maestro-runner"
    default_maestro = simulator / "maestro_env.sh"
    default_maestro.write_text(
        '#!/usr/bin/env bash\nexec "$MINT_TEST_DEFAULT_MAESTRO" "$@"\n',
        encoding="utf-8",
    )
    default_maestro.chmod(0o644)

    _write_executable(
        fake_git,
        "#!/usr/bin/env bash\n"
        'printf \'git %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "$*" == *"--show-toplevel"* ]]; then printf \'%s\\n\' "$MINT_TEST_REPO"; exit 0; fi\n'
        'if [[ "$*" == *"rev-parse HEAD"* ]]; then printf \'%s\\n\' "$MINT_TEST_SHA"; exit 0; fi\n'
        'if [[ "$*" == *"rev-parse $MINT_TEST_SHA:apps/mobile"* ]]; then\n'
        '  printf \'%s\\n\' "$MINT_TEST_MOBILE_TREE"\n'
        '  exit 0\n'
        'fi\n'
        'if [[ "$*" == *"archive --format=tar"* ]]; then\n'
        '  output=""\n'
        '  previous=""\n'
        '  for argument in "$@"; do\n'
        '    if [[ "$previous" == "--output" ]]; then output="$argument"; fi\n'
        '    previous="$argument"\n'
        '  done\n'
        '  [[ -n "$output" && "$*" == *"$MINT_TEST_SHA -- apps/mobile"* ]] || exit 92\n'
        '  case "$output" in "$MINT_TEST_REPO"/*) exit 93 ;; esac\n'
        '  printf \'private export repo=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        '  if [[ "$MINT_TEST_ARCHIVE_SLEEP" -gt 0 ]]; then sleep "$MINT_TEST_ARCHIVE_SLEEP"; fi\n'
        '  if [[ "$MINT_TEST_PRODUCTION_EXPORT_EXIT" != "0" ]]; then exit "$MINT_TEST_PRODUCTION_EXPORT_EXIT"; fi\n'
        '  cp "$MINT_TEST_PRODUCTION_ARCHIVE" "$output"\n'
        '  exit 0\n'
        'fi\n'
        'if [[ "$*" == *"ls-files --others"* ]]; then\n'
        '  if [[ "$MINT_TEST_UNTRACKED_MOBILE" == "1" ]]; then printf \'apps/mobile/untracked.dart\\n\'; fi\n'
        '  exit 0\n'
        'fi\n'
        'if [[ "$*" == *"ls-files --error-unmatch"* && "$*" == *"test/patrol/test_bundle.dart"* ]]; then\n'
        '  exit "$MINT_TEST_BUNDLE_TRACKED"\n'
        'fi\n'
        'if [[ "$*" == *"ls-files --error-unmatch"* ]]; then exit 0; fi\n'
        'if [[ "$*" == *"diff --quiet"* ]]; then exit "$MINT_TEST_DIFF_EXIT"; fi\n'
        "exit 91\n",
    )
    _write_executable(
        fake_patrol,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'build_target="$(readlink build 2>/dev/null || true)"\n'
        'printf \'patrol cwd=%s build=%s args=%s\\n\' "$PWD" "$build_target" "$*" >> "$MINT_TEST_CALLS"\n'
        '[[ "${1:-}" == "--verbose" && "${2:-}" == "build" && "${3:-}" == "ios" ]] || exit 93\n'
        '[[ "$*" == *"--simulator"* && "$*" == *"--bundle-id $MINT_TEST_BUNDLE_ID"* ]] || exit 98\n'
        '[[ -L build && -d "$build_target" ]] || exit 94\n'
        'case "$build_target" in "$MINT_TEST_REPO"/*) exit 95 ;; esac\n'
        'printf \'verbose repo=%s external=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$build_target" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        'if [[ "$MINT_TEST_GENERATE_BUNDLE" == "1" ]]; then\n'
        '  if [[ "$MINT_TEST_BUNDLE_AS_DIRECTORY" == "1" ]]; then\n'
        '    mkdir -p test/patrol/test_bundle.dart\n'
        '  else\n'
        '    mkdir -p test/patrol\n'
        '    printf \'generated bundle\\n\' > test/patrol/test_bundle.dart\n'
        '  fi\n'
        'fi\n'
        'stage=read\n'
        'if [[ "$*" == *"write_runtime"* ]]; then stage=write; fi\n'
        'if [[ "$stage" == "read" && -e build/writer-contamination-marker.txt ]]; then exit 96; fi\n'
        'if [[ "$stage" == "write" ]]; then printf \'writer cache\\n\' > build/writer-contamination-marker.txt; fi\n'
        'products=build/ios_integ/Build/Products\n'
        'runner="$products/Debug-iphonesimulator/Runner.app"\n'
        'if [[ "$MINT_TEST_PRODUCT_FAILURE" != "$stage-runner" ]]; then\n'
        '  asset_dir="$runner/Frameworks/App.framework/flutter_assets"\n'
        '  mkdir -p "$asset_dir"\n'
        '  if [[ "$MINT_TEST_PRODUCT_FAILURE" == "$stage-asset" ]]; then\n'
        '    : > "$asset_dir/AssetManifest.bin"\n'
        '  else\n'
        '    printf \'asset manifest %s\\n\' "$stage" > "$asset_dir/AssetManifest.bin"\n'
        '  fi\n'
        'fi\n'
        'if [[ "$MINT_TEST_PRODUCT_FAILURE" != "$stage-xctestrun" ]]; then\n'
        '  mkdir -p "$products"\n'
        '  printf \'%s\\n\' "$stage" > "$products/Runner_iphonesimulator26.2-arm64-x86_64.xctestrun"\n'
        'fi\n'
        'if [[ "$stage" == "write" ]]; then\n'
        '  if [[ "$MINT_TEST_PATROL_SLEEP" -gt 0 ]]; then sleep "$MINT_TEST_PATROL_SLEEP"; fi\n'
        '  exit "$MINT_TEST_WRITE_BUILD_EXIT"\n'
        'fi\n'
        'exit "$MINT_TEST_READ_BUILD_EXIT"\n',
    )
    _write_executable(
        fake_xcodebuild,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'xcodebuild %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        '[[ "${1:-}" == "test-without-building" ]] || exit 93\n'
        'xctestrun=""\n'
        'result_bundle=""\n'
        'previous=""\n'
        'for argument in "$@"; do\n'
        '  if [[ "$previous" == "-xctestrun" ]]; then xctestrun="$argument"; fi\n'
        '  if [[ "$previous" == "-resultBundlePath" ]]; then result_bundle="$argument"; fi\n'
        '  previous="$argument"\n'
        'done\n'
        '[[ -f "$xctestrun" && -n "$result_bundle" ]] || exit 94\n'
        '[[ "$*" == *"-only-testing RunnerUITests/RunnerUITests"* ]] || exit 95\n'
        '[[ "$*" == *"-destination platform=iOS Simulator,id=$MINT_TEST_DEVICE"* ]] || exit 96\n'
        'case "$result_bundle" in "$MINT_TEST_REPO"/*) exit 98 ;; esac\n'
        'stage="$(cat "$xctestrun")"\n'
        'mkdir -p "$result_bundle"\n'
        'printf \'xcresult %s\\n\' "$stage" > "$result_bundle/result.txt"\n'
        'printf \'verbose repo=%s xctestrun=%s result=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$xctestrun" "$result_bundle" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        'if [[ "$stage" == "write" ]]; then\n'
        '  printf \'shared preferences survive build reset\\n\' > "$MINT_TEST_DEVICE_STATE"\n'
        '  exit "$MINT_TEST_WRITE_EXIT"\n'
        'fi\n'
        '[[ -s "$MINT_TEST_DEVICE_STATE" ]] || exit 97\n'
        'exit "$MINT_TEST_READ_EXIT"\n',
    )
    _write_executable(
        fake_flutter,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'flutter cwd=%s build=%s args=%s\\n\' "$PWD" "$PWD/build" "$*" >> "$MINT_TEST_CALLS"\n'
        '[[ "$*" == "build ios --simulator --debug --target lib/main.dart" ]] || exit 93\n'
        '[[ "$*" != *"MINT_PATROL_CLI"* && "$*" != *"test_bundle"* ]] || exit 94\n'
        'case "$PWD" in "$MINT_TEST_REPO"/*) exit 95 ;; esac\n'
        '[[ "$PWD" == */source/apps/mobile ]] || exit 96\n'
        'for forbidden in .git build .dart_tool ios/Pods ios/.symlinks ios/Flutter/Generated.xcconfig; do\n'
        '  [[ ! -e "$forbidden" && ! -L "$forbidden" ]] || exit 97\n'
        'done\n'
        'for required in pubspec.yaml pubspec.lock lib/main.dart ios/Podfile ios/Podfile.lock ios/Runner.xcodeproj/project.pbxproj ios/Flutter/Debug.xcconfig; do\n'
        '  [[ -s "$required" ]] || exit 98\n'
        'done\n'
        'printf \'production repo=%s build=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$PWD/build" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        'app=build/ios/iphonesimulator/Runner.app\n'
        'asset_dir="$app/Frameworks/App.framework/flutter_assets"\n'
        'mkdir -p "$asset_dir"\n'
        'if [[ "$MINT_TEST_PRODUCT_FAILURE" != "production-runner" ]]; then\n'
        '  printf \'production runner\\n\' > "$app/Runner"\n'
        '  chmod +x "$app/Runner"\n'
        'fi\n'
        'MINT_FAKE_PLIST_BUNDLE="$MINT_TEST_BUNDLE_ID"\n'
        'if [[ "$MINT_TEST_PRODUCT_FAILURE" == "production-plist" ]]; then MINT_FAKE_PLIST_BUNDLE=ch.mint.wrong; fi\n'
        'MINT_FAKE_PLIST_BUNDLE="$MINT_FAKE_PLIST_BUNDLE" python3 - "$app/Info.plist" <<\'PY\'\n'
        "import os\n"
        "import plistlib\n"
        "import sys\n"
        "\n"
        "with open(sys.argv[1], 'wb') as handle:\n"
        "    plistlib.dump({'CFBundleIdentifier': os.environ['MINT_FAKE_PLIST_BUNDLE']}, handle)\n"
        "PY\n"
        'if [[ "$MINT_TEST_PRODUCT_FAILURE" == "production-asset" ]]; then\n'
        '  : > "$asset_dir/AssetManifest.bin"\n'
        'else\n'
        '  printf \'production assets\\n\' > "$asset_dir/AssetManifest.bin"\n'
        'fi\n'
        'if [[ "$MINT_TEST_FLUTTER_SLEEP" -gt 0 ]]; then sleep "$MINT_TEST_FLUTTER_SLEEP"; fi\n'
        'exit "$MINT_TEST_PRODUCTION_BUILD_EXIT"\n',
    )
    _write_executable(
        fake_tar,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'tar %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'printf \'extract repo=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        '[[ "${1:-}" == "-xf" && "${3:-}" == "-C" && "$#" == 4 ]] || exit 93\n'
        'archive="${2:-}"\n'
        'destination="${4:-}"\n'
        'case "$archive $destination" in *"$MINT_TEST_REPO"*) exit 94 ;; esac\n'
        '[[ -s "$archive" && -d "$destination" ]] || exit 95\n'
        'if [[ "$MINT_TEST_TAR_SLEEP" -gt 0 ]]; then sleep "$MINT_TEST_TAR_SLEEP"; fi\n'
        'if [[ "$MINT_TEST_PRODUCTION_EXTRACT_EXIT" != "0" ]]; then exit "$MINT_TEST_PRODUCTION_EXTRACT_EXIT"; fi\n'
        'exec "$MINT_TEST_REAL_TAR" "$@"\n',
    )
    _write_executable(
        fake_codesign,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'codesign %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'printf \'verify repo=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        '[[ "${1:-}" == "--verify" && "${2:-}" == "--strict" && "${3:-}" == "--deep" && "$#" == 4 ]] || exit 93\n'
        'staged_app="${4:-}"\n'
        'case "$staged_app" in "$MINT_TEST_REPO"/*) exit 94 ;; esac\n'
        '[[ -x "$staged_app/Runner" ]] || exit 95\n'
        'exit "$MINT_TEST_PRODUCTION_CODESIGN_EXIT"\n',
    )
    _write_executable(
        fake_xattr,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'xattr %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'printf \'xattr repo=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        '[[ "${1:-}" == "-r" && "$#" == 2 ]] || exit 93\n'
        'case "${2:-}" in "$MINT_TEST_REPO"/*) exit 94 ;; esac\n'
        '[[ "${2:-}" == */source/apps/mobile/build/ios/iphonesimulator/Runner.app ]] || exit 95\n'
        '[[ -x "${2:-}/Runner" ]] || exit 96\n'
        'printf \'%s\' "$MINT_TEST_PRODUCTION_XATTR_OUTPUT"\n'
        'exit "$MINT_TEST_PRODUCTION_XATTR_EXIT"\n',
    )
    _write_executable(
        fake_xcrun,
        "#!/usr/bin/env bash\n"
        'printf \'xcrun %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "${2:-}" == "launch" ]]; then exit "$MINT_TEST_LAUNCH_EXIT"; fi\n'
        'if [[ "${2:-}" == "terminate" ]]; then exit "$MINT_TEST_TERMINATE_EXIT"; fi\n'
        'if [[ "${2:-}" == "install" ]]; then\n'
        '  [[ -d "${4:-}" && -x "${4:-}/Runner" ]] || exit 94\n'
        '  case "${4:-}" in "$MINT_TEST_REPO"/*) exit 96 ;; esac\n'
        '  [[ -s "$MINT_TEST_DEVICE_STATE" ]] || exit 95\n'
        '  printf \'install app=%s repo=%s home=%s device=%s temp=%s\\n\' "${4:-}" "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        '  if [[ "$MINT_TEST_PRODUCTION_INSTALL_EXIT" != "0" ]]; then exit "$MINT_TEST_PRODUCTION_INSTALL_EXIT"; fi\n'
        '  printf \'production entrypoint installed\\n\' > "$MINT_TEST_PRODUCTION_INSTALLED"\n'
        '  exit 0\n'
        'fi\n'
        "exit 92\n",
    )
    _write_executable(
        fake_maestro,
        "#!/usr/bin/env bash\n"
        '[[ -s "$MINT_TEST_DEVICE_STATE" ]] || exit 97\n'
        '[[ -s "$MINT_TEST_PRODUCTION_INSTALLED" ]] || exit 98\n'
        'printf \'maestro %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'output=""\n'
        'debug_output=""\n'
        'test_output_dir=""\n'
        'previous=""\n'
        'for argument in "$@"; do\n'
        '  if [[ "$previous" == "--output" ]]; then output="$argument"; fi\n'
        '  if [[ "$previous" == "--debug-output" ]]; then debug_output="$argument"; fi\n'
        '  if [[ "$previous" == "--test-output-dir" ]]; then test_output_dir="$argument"; fi\n'
        '  previous="$argument"\n'
        'done\n'
        '[[ -n "$debug_output" && -n "$test_output_dir" ]] || exit 93\n'
        'case "$debug_output $test_output_dir" in *"$MINT_TEST_REPO"*) exit 94 ;; esac\n'
        'external_root="${debug_output%/maestro-debug}"\n'
        '[[ "$debug_output" == "$external_root/maestro-debug" ]] || exit 95\n'
        '[[ "$test_output_dir" == "$external_root/maestro-test-output" ]] || exit 96\n'
        'mkdir -p "$debug_output" "$test_output_dir"\n'
        'printf \'private debug repo=%s device=%s\\n\' "$MINT_TEST_REPO" "$MINT_TEST_DEVICE" > "$debug_output/debug.log"\n'
        'printf \'private test repo=%s device=%s\\n\' "$MINT_TEST_REPO" "$MINT_TEST_DEVICE" > "$test_output_dir/test.log"\n'
        'printf \'private udid=%s repo=%s home=%s temp=%s\\n\' "$MINT_TEST_DEVICE" "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_PRIVATE_TEMP"\n'
        'if [[ "$MINT_TEST_MAESTRO_REPORT" == "1" && -n "$output" ]]; then\n'
        '  if [[ "$MINT_TEST_MAESTRO_INVALID_XML" == "1" ]]; then\n'
        '    printf \'<testsuite name="unterminated"\' > "$output"\n'
        '  else\n'
        '    printf \'<testsuite name="synthetic" device="%s" repo="%s" home="%s" temp="%s"/>\\n\' "$MINT_TEST_DEVICE" "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_PRIVATE_TEMP" > "$output"\n'
        '  fi\n'
        'fi\n'
        'exit "$MINT_TEST_MAESTRO_EXIT"\n',
    )
    env = {
        **os.environ,
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "PATROL_BIN": str(fake_patrol),
        "MINT_TEST_CALLS": str(calls),
        "MINT_TEST_REPO": str(repo),
        "MINT_TEST_SHA": SYNTHETIC_SHA,
        "MINT_TEST_WRITE_BUILD_EXIT": str(write_build_exit),
        "MINT_TEST_WRITE_EXIT": str(write_exit),
        "MINT_TEST_LAUNCH_EXIT": str(launch_exit),
        "MINT_TEST_TERMINATE_EXIT": str(terminate_exit),
        "MINT_TEST_READ_BUILD_EXIT": str(read_build_exit),
        "MINT_TEST_READ_EXIT": str(read_exit),
        "MINT_TEST_PRODUCTION_EXPORT_EXIT": str(production_export_exit),
        "MINT_TEST_PRODUCTION_EXTRACT_EXIT": str(production_extract_exit),
        "MINT_TEST_PRODUCTION_BUILD_EXIT": str(production_build_exit),
        "MINT_TEST_PRODUCTION_CODESIGN_EXIT": str(production_codesign_exit),
        "MINT_TEST_PRODUCTION_XATTR_EXIT": str(production_xattr_exit),
        "MINT_TEST_PRODUCTION_XATTR_OUTPUT": production_xattr_output,
        "MINT_TEST_PRODUCTION_INSTALL_EXIT": str(production_install_exit),
        "MINT_TEST_MAESTRO_EXIT": str(maestro_exit),
        "MINT_TEST_MAESTRO_REPORT": "1" if maestro_report else "0",
        "MINT_TEST_MAESTRO_INVALID_XML": "1" if maestro_invalid_xml else "0",
        "MINT_TEST_DEVICE": SYNTHETIC_UDID,
        "MINT_TEST_DIFF_EXIT": str(diff_exit),
        "MINT_TEST_UNTRACKED_MOBILE": "1" if untracked_mobile else "0",
        "MINT_TEST_GENERATE_BUNDLE": "1" if generate_bundle else "0",
        "MINT_TEST_BUNDLE_AS_DIRECTORY": "1" if bundle_as_directory else "0",
        "MINT_TEST_BUNDLE_TRACKED": "0" if bundle_tracked else "1",
        "MINT_TEST_PATROL_SLEEP": str(patrol_sleep),
        "MINT_TEST_ARCHIVE_SLEEP": str(archive_sleep),
        "MINT_TEST_TAR_SLEEP": str(tar_sleep),
        "MINT_TEST_FLUTTER_SLEEP": str(flutter_sleep),
        "MINT_TEST_PRODUCT_FAILURE": product_failure,
        "MINT_TEST_BUNDLE_ID": BUNDLE_ID,
        "MINT_TEST_MOBILE_TREE": production_mobile_tree,
        "MINT_TEST_PRODUCTION_ARCHIVE": str(production_archive),
        "MINT_TEST_REAL_TAR": real_tar,
        "MINT_TEST_DEVICE_STATE": str(tmp_path / "device-state.txt"),
        "MINT_TEST_PRODUCTION_INSTALLED": str(
            tmp_path / "production-installed.txt"
        ),
        "MINT_TEST_DEFAULT_MAESTRO": str(fake_maestro),
        "MINT_TEST_PRIVATE_TEMP": "/private/var/folders/aa/bb/T/mint-bnd03",
    }
    if maestro_override:
        env["MAESTRO_RUNNER"] = str(fake_maestro)
    else:
        env.pop("MAESTRO_RUNNER", None)
    return env


def _assert_original_build_restored(env: dict[str, str], inode: int) -> None:
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert mobile_build.stat().st_ino == inode
    assert (mobile_build / "original-build-marker.txt").read_text(
        encoding="utf-8"
    ) == "must survive every exit path\n"
    assert (
        mobile_build / "ios/Debug-iphonesimulator/Flutter.framework/Flutter"
    ).read_text(encoding="utf-8") == "normal cached Flutter framework\n"


def _run(
    tmp_path: Path,
    env: dict[str, str],
    *,
    sha: str = SYNTHETIC_SHA,
    include_device: bool = True,
) -> subprocess.CompletedProcess[str]:
    command = ["bash", str(ORCHESTRATOR)]
    if include_device:
        command.extend(["--device", SYNTHETIC_UDID])
    command.extend(
        [
            "--bundle-id",
            BUNDLE_ID,
            "--sha",
            sha,
            "--artifacts",
            str(tmp_path / "artifacts"),
        ]
    )
    return subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_budget_runtime_contracts_use_real_ui_and_cold_canonical_seams() -> None:
    writer = WRITE_CONTRACT.read_text(encoding="utf-8")
    reader = READ_CONTRACT.read_text(encoding="utf-8")
    write_runner = WRITE_RUNNER.read_text(encoding="utf-8")
    read_runner = READ_RUNNER.read_text(encoding="utf-8")
    flow = FLOW.read_text(encoding="utf-8")
    screen = BUDGET_SCREEN.read_text(encoding="utf-8")
    orchestrator = ORCHESTRATOR.read_text(encoding="utf-8")

    assert "ReportPersistenceService.clearDiagnostic()" in writer
    assert "ReportPersistenceService.saveAnswers(" not in writer
    for identifier in (
        "salary_input",
        "salary_save_cta",
        "budget_setup_housing_input",
        "budget_setup_lamal_input",
        "budget_setup_save_cta",
        "budget_future_input",
        "budget_variables_input",
        "budget_available_hero",
    ):
        assert f"#{identifier}" in writer
    assert writer.index("#budget_future_input") < writer.index("budget_inputs_v1")
    assert "SharedPreferences.getInstance()" in writer
    assert "999999" in writer
    assert "waitForOverridePersistence()" in writer
    assert "openUrl('mint:///budget/setup')" not in writer
    first_budget = writer.index("openUrl('mint:///budget')")
    setup_start = writer.index("#budget_setup_start_cta")
    setup_housing = writer.index("#budget_setup_housing_input")
    setup_save = writer.index("#budget_setup_save_cta")
    first_hero = writer.index("#budget_available_hero")
    revenue = writer.index("openUrl('mint:///data-block/revenu')")
    salary = writer.index("#salary_input")
    salary_save = writer.index("#salary_save_cta")
    final_budget = writer.index("openUrl('mint:///budget')", first_budget + 1)
    future = writer.index("#budget_future_input")
    assert (
        first_budget
        < setup_start
        < setup_housing
        < setup_save
        < first_hero
        < revenue
        < salary
        < salary_save
        < final_budget
        < future
    )

    assert "ReportPersistenceService.clearDiagnostic()" not in reader
    assert "CoachProfileProvider" in reader
    assert "BudgetProvider" in reader
    assert "MintStateProvider" in reader
    assert "BudgetInputs.fromCoachProfile(profile!)" in reader
    assert "budget_inputs_v1" in reader
    assert "budget_override_future" in reader
    assert "budget_override_variables" in reader
    assert "#budget_available_hero" in reader
    assert "monthlyFree" in reader
    assert "waitForOverridePersistence()" in reader

    assert "g1_bnd03_budget_persistence_write_patrol_test.dart" in write_runner
    assert "g1_bnd03_budget_persistence_read_patrol_test.dart" in read_runner
    assert "budget_available_hero" in screen
    assert "budget_future_input" in screen
    assert "budget_variables_input" in screen

    assert "clearState" not in flow
    assert "takeScreenshot" not in flow
    assert flow.index("- stopApp") < flow.index("- launchApp")
    assert "launchApp" in flow
    assert 'id: "budget_available_hero"' in flow
    assert 'id: "budget_future_input"' in flow
    assert 'id: "budget_variables_input"' in flow

    assert "set -euo pipefail" in orchestrator
    assert "ls-files --error-unmatch" in orchestrator
    assert "ls-files --others --exclude-standard -- apps/mobile" in orchestrator
    assert "diff --quiet" in orchestrator
    assert re.search(
        r'git -C "\$repo_root" diff --quiet "\$sha" --\s*\\$',
        orchestrator,
        re.MULTILINE,
    )
    assert orchestrator.count('xcrun simctl terminate "$device" "$bundle_id"') == 1
    assert "MAESTRO_RUNNER" in orchestrator
    assert '"tools/simulator/maestro_env.sh"' in orchestrator
    assert 'maestro_command=(bash "$default_maestro_runner")' in orchestrator
    assert 'maestro_command=("$MAESTRO_RUNNER")' in orchestrator
    assert orchestrator.count('--debug-output "$external_root/maestro-debug"') == 1
    assert orchestrator.count('--test-output-dir "$external_root/maestro-test-output"') == 1
    assert "xml.etree.ElementTree" in orchestrator
    assert "test/patrol/test_bundle.dart" in orchestrator
    assert "budget_container_screen.dart" in orchestrator
    assert "budget_setup_screen.dart" in orchestrator
    assert 'mobile_build="$mobile_root/build"' in orchestrator
    assert 'rm -rf -- "$external_build"' in orchestrator
    assert 'mv "$mobile_build" "$build_backup"' in orchestrator
    assert 'ln -s "$external_build" "$mobile_build"' in orchestrator
    assert "pre-existing build symlink" in orchestrator
    assert "backup collision" in orchestrator
    assert "trap 'exit 143' TERM" in orchestrator
    assert orchestrator.count('"$patrol_bin" --verbose build ios') == 2
    assert orchestrator.count("--simulator") == 3
    assert "--no-uninstall" not in orchestrator
    assert "--verbose test" not in orchestrator
    assert orchestrator.count("xcodebuild test-without-building") == 1
    assert orchestrator.count('run_xcode_test "write"') == 1
    assert orchestrator.count('run_xcode_test "read"') == 1
    assert orchestrator.count('-only-testing "RunnerUITests/RunnerUITests"') == 1
    assert 'result_bundle="$external_build/$stage.xcresult"' in orchestrator
    assert '$artifacts/$stage.xcresult' not in orchestrator
    assert orchestrator.count(
        "flutter build ios --simulator --debug --target lib/main.dart"
    ) == 1
    assert orchestrator.count(
        'git -C "$repo_root" archive --format=tar --output '
        '"$production_archive" "$sha" -- apps/mobile'
    ) == 1
    assert orchestrator.count(
        'tar -xf "$production_archive" -C "$production_export_root"'
    ) == 1
    assert 'production_mobile_tree="$(git -C "$repo_root" rev-parse "$sha:apps/mobile")"' in orchestrator
    assert 'production_source_mode="git_archive"' in orchestrator
    assert 'production_mobile="$production_export_root/apps/mobile"' in orchestrator
    assert 'production_app="$production_mobile/build/ios/iphonesimulator/Runner.app"' in orchestrator
    assert 'rm -f -- "$production_archive"' in orchestrator
    assert orchestrator.count('codesign --verify --strict --deep "$production_app"') == 1
    assert orchestrator.count('xattr -r "$production_app"') == 1
    assert orchestrator.count(
        'xcrun simctl install "$device" "$production_app"'
    ) == 1
    assert "simctl uninstall" not in orchestrator
    assert "clearState" not in orchestrator
    assert 'xattr -crs "$mobile_build/ios"' not in orchestrator
    assert "normal Flutter.framework cache is missing or empty" not in orchestrator
    assert "restore_normal_build_for_production" not in orchestrator
    assert "ditto --norsrc" not in orchestrator
    assert "git worktree" not in orchestrator
    assert "--no-codesign" not in orchestrator
    assert "CODE_SIGNING_ALLOWED" not in orchestrator
    assert "CODE_SIGNING_REQUIRED" not in orchestrator
    ordered_production_steps = (
        'git -C "$repo_root" archive --format=tar',
        'tar -xf "$production_archive"',
        'rm -f -- "$production_archive"',
        "flutter build ios --simulator --debug --target lib/main.dart",
        'inspect_production_app "$production_app"',
        'codesign --verify --strict --deep "$production_app"',
        'xattr -r "$production_app"',
        'xcrun simctl install "$device" "$production_app"',
    )
    assert list(map(orchestrator.index, ordered_production_steps)) == sorted(
        map(orchestrator.index, ordered_production_steps)
    )
    staged_tail = orchestrator[orchestrator.index('xattr -r "$production_app"') :]
    assert staged_tail.index("exact_sha_guard") < staged_tail.index(
        'xcrun simctl install "$device" "$production_app"'
    )
    assert "CFBundleIdentifier" in orchestrator
    assert "production AssetManifest.bin is missing or empty" in orchestrator
    production_build = re.search(
        r"flutter build ios.*?(?=\n\s*>|\n\s*production_build_exit_code)",
        orchestrator,
        re.DOTALL,
    )
    assert production_build is not None
    assert "MINT_PATROL_CLI" not in production_build.group(0)
    assert "Runner.app" in orchestrator
    assert "AssetManifest.bin" in orchestrator
    assert "*.xctestrun" in orchestrator
    assert "command -v xcodebuild" in orchestrator
    assert "command -v flutter" in orchestrator
    assert "command -v find" in orchestrator
    assert "command -v python3" in orchestrator
    assert "command -v tar" in orchestrator
    assert "command -v codesign" in orchestrator
    assert "command -v xattr" in orchestrator
    assert "os.lstat" in orchestrator
    assert "followlinks=False" in orchestrator
    assert "stat.S_ISLNK" in orchestrator
    assert "st_nlink" in orchestrator
    assert "retry" not in orchestrator.lower()
    assert "codesign --force" not in orchestrator
    assert "codesign --sign" not in orchestrator
    assert "codesign --display" not in orchestrator
    assert "xattr -lr" not in orchestrator
    assert "com.apple.FinderInfo" in orchestrator
    assert "com.apple.ResourceFork" in orchestrator
    assert "com.apple.provenance" not in orchestrator
    assert "entitlements" not in orchestrator
    assert "sed -i" not in orchestrator
    assert "synthetic_data_only" in orchestrator
    assert "device_sha256" in orchestrator
    assert '"device"' not in orchestrator


def test_budget_orchestrator_runs_writer_death_reader_then_maestro(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(
        tmp_path,
        production_xattr_output="Runner.app: com.apple.provenance\n",
    )
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    result = _run(tmp_path, env)

    assert result.returncode == 0, result.stderr
    _assert_original_build_restored(env, original_inode)
    assert result.stdout.count("patrol_bnd03_budget_process_death: PASS") == 1
    assert not (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    ).exists()
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    git_calls = [line for line in calls if line.startswith("git ")]
    runtime_calls = [line for line in calls if not line.startswith("git ")]
    assert len(runtime_calls) == 12
    assert any(
        line.endswith(f"rev-parse {SYNTHETIC_SHA}:apps/mobile")
        for line in git_calls
    )
    archive_call = next(line for line in git_calls if " archive " in line)
    assert "archive --format=tar --output" in archive_call
    assert archive_call.endswith(f"{SYNTHETIC_SHA} -- apps/mobile")
    assert "write_runtime" in runtime_calls[0]
    patrol_calls = [line for line in runtime_calls if line.startswith("patrol ")]
    assert len(patrol_calls) == 2
    assert all("args=--verbose build ios" in line for line in patrol_calls)
    assert all("--simulator" in line for line in patrol_calls)
    assert all(f"--bundle-id {BUNDLE_ID}" in line for line in patrol_calls)
    external_targets = {
        re.search(r" build=([^ ]+) args=", line).group(1) for line in patrol_calls
    }
    assert len(external_targets) == 1
    external_target = Path(external_targets.pop())
    assert not external_target.is_relative_to(Path(env["MINT_TEST_REPO"]))
    assert not external_target.exists()
    xcodebuild_calls = [
        line for line in runtime_calls if line.startswith("xcodebuild ")
    ]
    assert len(xcodebuild_calls) == 2
    assert all("test-without-building" in line for line in xcodebuild_calls)
    assert all(
        "-only-testing RunnerUITests/RunnerUITests" in line
        for line in xcodebuild_calls
    )
    assert all(
        f"-destination platform=iOS Simulator,id={SYNTHETIC_UDID}" in line
        for line in xcodebuild_calls
    )
    assert f"-resultBundlePath {external_target}/write.xcresult" in xcodebuild_calls[0]
    assert f"-resultBundlePath {external_target}/read.xcresult" in xcodebuild_calls[1]
    assert runtime_calls[2] == f"xcrun simctl launch {SYNTHETIC_UDID} {BUNDLE_ID}"
    assert runtime_calls[3] == f"xcrun simctl terminate {SYNTHETIC_UDID} {BUNDLE_ID}"
    assert "read_runtime" in runtime_calls[4]
    external_root = external_target.parent
    production_mobile = external_root / "source/apps/mobile"
    production_app = production_mobile / "build/ios/iphonesimulator/Runner.app"
    production_archive = external_root / "mobile.tar"
    assert runtime_calls[6] == (
        f"tar -xf {production_archive} -C {external_root / 'source'}"
    )
    assert runtime_calls[7].startswith("flutter ")
    assert f"cwd={production_mobile}" in runtime_calls[7]
    assert "args=build ios --simulator --debug --target lib/main.dart" in runtime_calls[7]
    assert "MINT_PATROL_CLI" not in runtime_calls[7]
    assert "test_bundle" not in runtime_calls[7]
    assert runtime_calls[8] == (
        f"codesign --verify --strict --deep {production_app}"
    )
    assert runtime_calls[9] == f"xattr -r {production_app}"
    assert runtime_calls[10] == (
        f"xcrun simctl install {SYNTHETIC_UDID} {production_app}"
    )
    assert "uninstall" not in "\n".join(runtime_calls)
    assert "g1_bnd03_budget_cold.yaml" in runtime_calls[11]
    assert f"--debug-output {external_root}/maestro-debug" in runtime_calls[11]
    assert (
        f"--test-output-dir {external_root}/maestro-test-output"
        in runtime_calls[11]
    )
    assert not production_archive.exists()
    assert not production_mobile.exists()
    assert not production_app.exists()

    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["contract"] == "g1_bnd03_budget"
    assert metadata["sha"] == SYNTHETIC_SHA
    assert metadata["synthetic_data_only"] is True
    assert metadata["private_fixture_used"] is False
    assert metadata["mode"] == (
        "patrol_external_build_xcode_then_exact_archive_physical_"
        "production_install"
    )
    assert metadata["production_source_mode"] == "git_archive"
    assert metadata["production_mobile_tree"] == "4" * 40
    assert metadata["write_build_exit_code"] == 0
    assert metadata["write_exit_code"] == 0
    assert metadata["launch_exit_code"] == 0
    assert metadata["terminate_exit_code"] == 0
    assert metadata["read_build_exit_code"] == 0
    assert metadata["read_exit_code"] == 0
    assert metadata["production_export_exit_code"] == 0
    assert metadata["production_extract_exit_code"] == 0
    assert metadata["production_build_exit_code"] == 0
    assert metadata["production_codesign_verify_exit_code"] == 0
    assert metadata["production_xattr_inspect_exit_code"] == 0
    assert metadata["production_install_exit_code"] == 0
    assert metadata["maestro_exit_code"] == 0
    assert metadata["cleanup_status"] == "passed"
    assert metadata["build_isolation"] == {
        "enabled": True,
        "original_build_present": True,
        "patrol_build_purged_before_production": True,
        "production_source_exported_exact": True,
        "production_source_physical": True,
        "reset_between_patrol_stages": True,
        "restoration_status": "restored",
    }
    expected_logs = (
        "write-build.log",
        "write.log",
        "launch.log",
        "terminate.log",
        "read-build.log",
        "read.log",
        "production-export.log",
        "production-extract.log",
        "production-build.log",
        "production-codesign.log",
        "production-xattrs.log",
        "production-install.log",
        "maestro.log",
        "maestro-report.sanitized.xml",
    )
    assert metadata["expected_logs"] == list(expected_logs)
    assert metadata["logs"] == list(expected_logs)
    assert metadata["device_sha256"] != SYNTHETIC_UDID
    assert SYNTHETIC_UDID not in (tmp_path / "artifacts/metadata.json").read_text()
    artifacts = tmp_path / "artifacts"
    assert all((artifacts / log).is_file() for log in metadata["logs"])
    report = artifacts / "maestro-report.sanitized.xml"
    assert report.is_file()
    private_values = (
        SYNTHETIC_UDID,
        env["MINT_TEST_REPO"],
        env["HOME"],
        str(external_root),
    )
    for sanitized in (report, *artifacts.glob("*.log")):
        sanitized_text = sanitized.read_text(encoding="utf-8")
        assert all(private not in sanitized_text for private in private_values)
    assert "REDACTED_SIMULATOR_UDID" in report.read_text(encoding="utf-8")
    assert "REDACTED_REPO" in report.read_text(encoding="utf-8")
    assert "REDACTED_HOME" in report.read_text(encoding="utf-8")
    assert "REDACTED_PRIVATE_TEMP" in report.read_text(encoding="utf-8")
    assert ET.parse(report).getroot().tag == "testsuite"
    assert "REDACTED_SIMULATOR_UDID" in (artifacts / "maestro.log").read_text(
        encoding="utf-8"
    )
    for patrol_log in (
        artifacts / "write-build.log",
        artifacts / "write.log",
        artifacts / "read-build.log",
        artifacts / "read.log",
    ):
        text = patrol_log.read_text(encoding="utf-8")
        assert "REDACTED_REPO" in text
        assert "REDACTED_HOME" in text
        assert "REDACTED_SIMULATOR_UDID" in text
        assert "REDACTED_PRIVATE_TEMP" in text
        assert "REDACTED_EXTERNAL_BUILD" in text
    for production_log in (
        artifacts / "production-export.log",
        artifacts / "production-extract.log",
        artifacts / "production-build.log",
        artifacts / "production-codesign.log",
        artifacts / "production-xattrs.log",
        artifacts / "production-install.log",
    ):
        text = production_log.read_text(encoding="utf-8")
        assert "REDACTED_REPO" in text
        assert "REDACTED_HOME" in text
        assert "REDACTED_SIMULATOR_UDID" in text
        assert "REDACTED_PRIVATE_TEMP" in text
    metadata_text = (artifacts / "metadata.json").read_text(encoding="utf-8")
    assert str(tmp_path) not in metadata_text
    assert not any("path" in key for key in metadata["build_isolation"])
    assert not (artifacts / "maestro-report.xml").exists()
    assert not list(artifacts.glob("*.raw.log"))
    assert not list(artifacts.glob("*.xcresult"))


def test_budget_orchestrator_uses_default_non_executable_maestro_via_bash(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, maestro_override=False)
    default_runner = Path(env["MINT_TEST_REPO"]) / "tools/simulator/maestro_env.sh"
    assert not os.access(default_runner, os.X_OK)

    result = _run(tmp_path, env)

    assert result.returncode == 0, result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "maestro " in calls
    assert (tmp_path / "artifacts/maestro-report.sanitized.xml").is_file()


def test_budget_orchestrator_rejects_maestro_success_without_junit(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, maestro_report=False)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode != 0
    _assert_original_build_restored(env, original_inode)
    assert "Maestro JUnit report is missing or empty" in result.stderr
    assert "PASS" not in result.stdout
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["maestro_exit_code"] != 0
    assert not (tmp_path / "artifacts/maestro-report.sanitized.xml").exists()
    assert not (tmp_path / "artifacts/maestro-report.xml").exists()


def test_budget_orchestrator_rejects_invalid_sanitized_junit(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, maestro_invalid_xml=True)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode != 0
    _assert_original_build_restored(env, original_inode)
    assert "sanitized Maestro JUnit report is invalid XML" in result.stderr
    assert "PASS" not in result.stdout
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["maestro_exit_code"] != 0


@pytest.mark.parametrize(
    ("runtime", "expected", "forbidden"),
    [
        ({"write_build_exit": 7}, "write build stage failed", "xcodebuild "),
        ({"write_exit": 8}, "write test stage failed", "xcrun simctl launch"),
        ({"launch_exit": 9}, "launch stage failed", "xcrun simctl terminate"),
        ({"terminate_exit": 10}, "terminate stage failed", "read_runtime"),
        ({"read_build_exit": 11}, "read build stage failed", "read.xcresult"),
        ({"read_exit": 12}, "read test stage failed", "maestro "),
        (
            {"production_export_exit": 16},
            "production export stage failed",
            "tar ",
        ),
        (
            {"production_extract_exit": 17},
            "production extract stage failed",
            "flutter ",
        ),
        (
            {"production_build_exit": 13},
            "production build stage failed",
            "xcrun simctl install",
        ),
        (
            {"production_codesign_exit": 18},
            "production codesign verification failed",
            "xattr -r",
        ),
        (
            {"production_xattr_exit": 19},
            "production xattr inspection failed",
            "xcrun simctl install",
        ),
        (
            {"production_install_exit": 14},
            "production install stage failed",
            "maestro ",
        ),
        ({"maestro_exit": 15}, "Maestro stage failed", "PASS"),
    ],
)
def test_budget_orchestrator_fails_closed(
    tmp_path: Path,
    runtime: dict[str, int],
    expected: str,
    forbidden: str,
) -> None:
    env = _fake_runtime(tmp_path, **runtime)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    result = _run(tmp_path, env)

    assert result.returncode == next(iter(runtime.values()))
    _assert_original_build_restored(env, original_inode)
    assert expected in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    runtime_calls = "\n".join(line for line in calls if not line.startswith("git "))
    assert forbidden not in runtime_calls + result.stdout
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert not generated_bundle.exists()
    artifacts = tmp_path / "artifacts"
    assert (artifacts / "metadata.json").is_file()
    metadata = json.loads(
        (artifacts / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["logs"] == [
        log for log in metadata["expected_logs"] if (artifacts / log).is_file()
    ]
    assert not list(artifacts.glob("*.raw.log"))
    assert not (artifacts / "maestro-report.xml").exists()


@pytest.mark.parametrize(
    "forbidden_xattr",
    ("com.apple.FinderInfo", "com.apple.ResourceFork"),
)
def test_budget_orchestrator_rejects_forbidden_xattrs_on_exported_production_app(
    tmp_path: Path,
    forbidden_xattr: str,
) -> None:
    env = _fake_runtime(
        tmp_path,
        production_xattr_output=f"Runner.app: {forbidden_xattr}\n",
    )
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_inode)
    assert "production exported app has forbidden extended attribute" in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "codesign --verify --strict --deep" in calls
    assert "xattr -r" in calls
    assert "xcrun simctl install" not in calls
    assert "maestro " not in calls
    artifacts = tmp_path / "artifacts"
    assert not list(artifacts.glob("*.raw.log"))
    sanitized = (artifacts / "production-xattrs.log").read_text(encoding="utf-8")
    assert forbidden_xattr in sanitized
    assert env["MINT_TEST_REPO"] not in sanitized


@pytest.mark.parametrize(
    ("product_failure", "expected", "xcodebuild_count", "install_count"),
    [
        ("write-runner", "write Runner.app is missing", 0, 0),
        ("write-xctestrun", "write xctestrun is missing", 0, 0),
        ("read-asset", "read AssetManifest.bin is missing or empty", 1, 0),
        (
            "production-runner",
            "production Runner executable is missing",
            2,
            0,
        ),
        (
            "production-plist",
            "production CFBundleIdentifier mismatch",
            2,
            0,
        ),
        (
            "production-asset",
            "production AssetManifest.bin is missing or empty",
            2,
            0,
        ),
    ],
)
def test_budget_orchestrator_rejects_incomplete_patrol_build_products(
    tmp_path: Path,
    product_failure: str,
    expected: str,
    xcodebuild_count: int,
    install_count: int,
) -> None:
    env = _fake_runtime(tmp_path, product_failure=product_failure)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_inode)
    assert expected in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert calls.count("xcodebuild test-without-building") == xcodebuild_count
    assert "codesign --verify --strict --deep" not in calls
    assert calls.count("xcrun simctl install") == install_count
    artifacts = tmp_path / "artifacts"
    assert not list(artifacts.glob("*.raw.log"))
    assert not list(artifacts.glob("*.xcresult"))


def test_budget_orchestrator_rejects_missing_device_and_sha_drift(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)

    missing_device = _run(tmp_path, env, include_device=False)
    wrong_sha = _run(tmp_path, env, sha="a" * 40)

    assert missing_device.returncode != 0
    assert "--device is required" in missing_device.stderr
    assert wrong_sha.returncode != 0
    assert "must equal current HEAD" in wrong_sha.stderr


def test_budget_orchestrator_rejects_any_tracked_worktree_drift(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, diff_exit=12)

    result = _run(tmp_path, env)

    assert result.returncode != 0
    assert "runtime contract differs from --sha HEAD" in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "patrol " not in calls


def test_budget_orchestrator_rejects_untracked_mobile_before_runtime(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, untracked_mobile=True)

    result = _run(tmp_path, env)

    assert result.returncode != 0
    assert "untracked mobile files make --sha evidence ambiguous" in result.stderr
    assert "patrol " not in (tmp_path / "calls.log").read_text(encoding="utf-8")


def test_budget_orchestrator_cleanup_preserves_tracked_patrol_bundle(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, bundle_tracked=True)

    result = _run(tmp_path, env)

    assert result.returncode == 0, result.stderr
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert generated_bundle.read_text(encoding="utf-8") == "generated bundle\n"


def test_budget_orchestrator_success_fails_closed_when_metadata_is_directory(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    metadata = tmp_path / "artifacts/metadata.json"
    metadata.mkdir(parents=True)

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    assert metadata.is_dir()
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert not generated_bundle.exists()


def test_budget_orchestrator_success_fails_closed_when_bundle_cleanup_fails(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, bundle_as_directory=True)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert generated_bundle.is_dir()
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["cleanup_status"] == "failed"


def test_budget_orchestrator_stage_failure_preserves_code_when_cleanup_fails(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, write_exit=7, bundle_as_directory=True)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 7
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    assert (tmp_path / "artifacts/metadata.json").is_file()


def test_budget_orchestrator_stage_failure_preserves_code_when_sanitization_fails(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, write_exit=7)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    artifacts = tmp_path / "artifacts"
    (artifacts / "write.log").mkdir(parents=True)

    result = _run(tmp_path, env)

    assert result.returncode == 7
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    assert not list(artifacts.glob("*.raw.log"))
    metadata = json.loads((artifacts / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["cleanup_status"] == "failed"


def test_budget_orchestrator_requires_normal_build(
    tmp_path: Path,
) -> None:
    missing_build_env = _fake_runtime(tmp_path / "missing-build")
    missing_build = Path(missing_build_env["MINT_TEST_REPO"]) / "apps/mobile/build"
    shutil.rmtree(missing_build)

    missing_build_result = _run(tmp_path / "missing-build", missing_build_env)

    assert missing_build_result.returncode == 2
    assert "normal mobile build directory is required" in missing_build_result.stderr
    assert "patrol " not in (tmp_path / "missing-build/calls.log").read_text(
        encoding="utf-8"
    )


@pytest.mark.parametrize("unsafe_export_entry", ("symlink", "hardlink"))
def test_budget_orchestrator_rejects_unsafe_export_aliases_before_flutter(
    tmp_path: Path,
    unsafe_export_entry: str,
) -> None:
    env = _fake_runtime(tmp_path, unsafe_export_entry=unsafe_export_entry)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_build_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_build_inode)
    assert "production mobile export contains an unsafe alias" in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "xattr " not in calls
    assert "flutter " not in calls
    assert not list((tmp_path / "artifacts").glob("*.raw.log"))


def test_budget_orchestrator_rejects_build_symlink_and_backup_collision(
    tmp_path: Path,
) -> None:
    symlink_env = _fake_runtime(tmp_path / "symlink")
    symlink_build = Path(symlink_env["MINT_TEST_REPO"]) / "apps/mobile/build"
    shutil.rmtree(symlink_build)
    foreign_build = tmp_path / "foreign-build"
    foreign_build.mkdir()
    symlink_build.symlink_to(foreign_build, target_is_directory=True)

    symlink_result = _run(tmp_path / "symlink", symlink_env)

    assert symlink_result.returncode != 0
    assert "pre-existing build symlink" in symlink_result.stderr
    assert symlink_build.is_symlink()
    assert symlink_build.resolve() == foreign_build.resolve()

    collision_env = _fake_runtime(tmp_path / "collision")
    collision_repo = Path(collision_env["MINT_TEST_REPO"])
    collision_build = collision_repo / "apps/mobile/build"
    original_inode = collision_build.stat().st_ino
    backup = (
        collision_repo
        / "apps/mobile/.dart_tool"
        / f"mint-patrol-g1-bnd03-build-backup-{SYNTHETIC_SHA}"
    )
    backup.mkdir()
    (backup / "stale-backup-marker.txt").write_text("preserve\n", encoding="utf-8")

    collision_result = _run(tmp_path / "collision", collision_env)

    assert collision_result.returncode != 0
    assert "backup collision" in collision_result.stderr
    _assert_original_build_restored(collision_env, original_inode)
    assert (backup / "stale-backup-marker.txt").read_text(encoding="utf-8") == (
        "preserve\n"
    )
    assert "patrol " not in (tmp_path / "collision/calls.log").read_text(
        encoding="utf-8"
    )


def test_budget_orchestrator_restores_original_build_on_term_signal(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, patrol_sleep=30)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    command = [
        "bash",
        str(ORCHESTRATOR),
        "--device",
        SYNTHETIC_UDID,
        "--bundle-id",
        BUNDLE_ID,
        "--sha",
        SYNTHETIC_SHA,
        "--artifacts",
        str(tmp_path / "artifacts"),
    ]
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    artifacts = tmp_path / "artifacts"
    calls_path = tmp_path / "calls.log"
    write_raw = artifacts / "write-build.raw.log"
    deadline = time.monotonic() + 10
    patrol_write_call = ""
    while time.monotonic() < deadline:
        if process.poll() is not None:
            break
        if calls_path.exists():
            patrol_write_call = next(
                (
                    line
                    for line in calls_path.read_text(encoding="utf-8").splitlines()
                    if line.startswith("patrol ")
                    and "--verbose build ios" in line
                    and "write_runtime" in line
                ),
                "",
            )
        if patrol_write_call and write_raw.is_file() and write_raw.stat().st_size > 0:
            break
        time.sleep(0.05)
    assert patrol_write_call, process.communicate(timeout=2)
    assert write_raw.is_file() and write_raw.stat().st_size > 0
    assert mobile_build.is_symlink()
    external_target_match = re.search(r" build=([^ ]+) args=", patrol_write_call)
    assert external_target_match is not None
    external_root = str(Path(external_target_match.group(1)).parent)

    os.killpg(process.pid, signal.SIGTERM)
    stdout, stderr = process.communicate(timeout=10)

    assert process.returncode == 143, stdout + stderr
    _assert_original_build_restored(env, original_inode)
    metadata = json.loads(
        (artifacts / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["build_isolation"]["restoration_status"] == "restored"
    assert not list(artifacts.glob("*.raw.log"))
    write_log = artifacts / "write-build.log"
    assert write_log.is_file()
    sanitized = write_log.read_text(encoding="utf-8")
    for private in (
        env["MINT_TEST_REPO"],
        env["HOME"],
        SYNTHETIC_UDID,
        env["MINT_TEST_PRIVATE_TEMP"],
        external_root,
    ):
        assert private not in sanitized


@pytest.mark.parametrize(
    ("sleep_kwargs", "call_marker", "raw_stem"),
    [
        ({"archive_sleep": 30}, " archive ", "production-export"),
        ({"tar_sleep": 30}, "tar -xf ", "production-extract"),
        ({"flutter_sleep": 30}, "flutter ", "production-build"),
    ],
)
def test_budget_orchestrator_sanitizes_production_handoff_on_term_signal(
    tmp_path: Path,
    sleep_kwargs: dict[str, int],
    call_marker: str,
    raw_stem: str,
) -> None:
    env = _fake_runtime(tmp_path, **sleep_kwargs)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    artifacts = tmp_path / "artifacts"
    calls_path = tmp_path / "calls.log"
    process = subprocess.Popen(
        [
            "bash",
            str(ORCHESTRATOR),
            "--device",
            SYNTHETIC_UDID,
            "--bundle-id",
            BUNDLE_ID,
            "--sha",
            SYNTHETIC_SHA,
            "--artifacts",
            str(artifacts),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    raw_log = artifacts / f"{raw_stem}.raw.log"
    deadline = time.monotonic() + 10
    stage_call = ""
    while time.monotonic() < deadline:
        if process.poll() is not None:
            break
        if calls_path.exists():
            stage_call = next(
                (
                    line
                    for line in calls_path.read_text(encoding="utf-8").splitlines()
                    if call_marker in line
                ),
                "",
            )
        if stage_call and raw_log.is_file() and raw_log.stat().st_size > 0:
            break
        time.sleep(0.05)
    assert stage_call, process.communicate(timeout=2)
    assert raw_log.is_file() and raw_log.stat().st_size > 0
    calls = calls_path.read_text(encoding="utf-8").splitlines()
    patrol_call = next(line for line in calls if line.startswith("patrol "))
    external_target_match = re.search(r" build=([^ ]+) args=", patrol_call)
    assert external_target_match is not None
    external_root = str(Path(external_target_match.group(1)).parent)
    assert mobile_build.is_symlink()

    os.killpg(process.pid, signal.SIGTERM)
    stdout, stderr = process.communicate(timeout=10)

    assert process.returncode == 143, stdout + stderr
    _assert_original_build_restored(env, original_inode)
    assert not Path(external_root).exists()
    assert not list(artifacts.glob("*.raw.log"))
    assert not Path(env["MINT_TEST_PRODUCTION_INSTALLED"]).exists()
    assert "maestro " not in calls_path.read_text(encoding="utf-8")
    metadata = json.loads((artifacts / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["build_isolation"]["restoration_status"] == "restored"
    sanitized = (artifacts / f"{raw_stem}.log").read_text(encoding="utf-8")
    for private in (
        env["MINT_TEST_REPO"],
        env["HOME"],
        SYNTHETIC_UDID,
        env["MINT_TEST_PRIVATE_TEMP"],
        external_root,
    ):
        assert private not in sanitized
