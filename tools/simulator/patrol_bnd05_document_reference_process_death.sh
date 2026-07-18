#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --device <UDID> --bundle-id <bundle> --sha <40-hex> --artifacts <dir>" >&2
}

die() {
  echo "patrol_bnd05_document_reference_process_death: $*" >&2
  exit 2
}

device=""
bundle_id=""
sha=""
artifacts=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) device="${2:-}"; shift 2 ;;
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    --artifacts) artifacts="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown argument '$1'" ;;
  esac
done

[[ -n "$device" ]] || die "--device is required"
[[ "$device" =~ ^[0-9A-Fa-f-]{36}$ ]] || die "--device must be one simulator UDID"
[[ -n "$bundle_id" ]] || die "--bundle-id is required"
[[ "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]] || die "--bundle-id is invalid"
[[ -n "$sha" ]] || die "--sha is required"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "--sha must be a 40-hex commit"
[[ -n "$artifacts" ]] || die "--artifacts is required"

repo_root="$(git rev-parse --show-toplevel)"
head_sha="$(git -C "$repo_root" rev-parse HEAD)"
[[ "$sha" == "$head_sha" ]] || die "--sha must equal current HEAD ($head_sha)"
mobile_root="$repo_root/apps/mobile"
write_contract="apps/mobile/integration_test/g1_bnd05_document_reference_write_patrol_test.dart"
read_contract="apps/mobile/integration_test/g1_bnd05_document_reference_read_patrol_test.dart"
write_target="apps/mobile/test/patrol/g1_bnd05_document_reference_write_runtime_test.dart"
read_target="apps/mobile/test/patrol/g1_bnd05_document_reference_read_runtime_test.dart"
maestro_flow="apps/mobile/.maestro/g1_bnd05_document_reference_flag_off.yaml"
orchestrator_path="tools/simulator/patrol_bnd05_document_reference_process_death.sh"
default_maestro_path="tools/simulator/maestro_env.sh"
generated_patrol_bundle="apps/mobile/test/patrol/test_bundle.dart"
runtime_paths=(
  "$write_contract"
  "$read_contract"
  "$write_target"
  "$read_target"
  "$maestro_flow"
  "apps/mobile/lib/app.dart"
  "apps/mobile/lib/models/lpp_evidence.dart"
  "apps/mobile/lib/providers/coach_profile_provider.dart"
  "apps/mobile/lib/providers/document_provider.dart"
  "apps/mobile/lib/providers/timeline_provider.dart"
  "apps/mobile/lib/screens/document_detail_screen.dart"
  "apps/mobile/lib/screens/document_scan/document_scan_screen.dart"
  "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart"
  "apps/mobile/lib/screens/documents_screen.dart"
  "apps/mobile/lib/services/feature_flags.dart"
  "apps/mobile/lib/services/report_persistence_service.dart"
  "$orchestrator_path"
  "tools/simulator/maestro_env.sh"
)

for runtime_path in "${runtime_paths[@]}"; do
  [[ -f "$repo_root/$runtime_path" ]] || die "runtime contract is missing: $runtime_path"
  git -C "$repo_root" ls-files --error-unmatch -- "$runtime_path" >/dev/null \
    || die "runtime contract is not tracked by HEAD: $runtime_path"
done

exact_sha_guard() {
  git -C "$repo_root" diff --quiet "$sha" -- \
    || die "runtime contract differs from --sha HEAD"
}
untracked_mobile_guard() {
  local untracked_mobile
  untracked_mobile="$(
    git -C "$repo_root" ls-files --others --exclude-standard -- apps/mobile
  )"
  [[ -z "$untracked_mobile" ]] \
    || die "untracked mobile files make --sha evidence ambiguous"
}
exact_sha_guard
untracked_mobile_guard

patrol_bin="${PATROL_BIN:-$HOME/.pub-cache/bin/patrol}"
[[ -x "$patrol_bin" ]] || die "Patrol CLI is not executable at $patrol_bin"
default_maestro_runner="$repo_root/$default_maestro_path"
if [[ -n "${MAESTRO_RUNNER:-}" ]]; then
  [[ -x "$MAESTRO_RUNNER" ]] \
    || die "Maestro runner override is not executable at $MAESTRO_RUNNER"
  maestro_command=("$MAESTRO_RUNNER")
else
  [[ -f "$default_maestro_runner" ]] \
    || die "default Maestro wrapper is missing at $default_maestro_runner"
  maestro_command=(bash "$default_maestro_runner")
fi
command -v xcrun >/dev/null 2>&1 || die "xcrun is required"
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild is required"
command -v flutter >/dev/null 2>&1 || die "flutter is required"
command -v find >/dev/null 2>&1 || die "find is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
command -v codesign >/dev/null 2>&1 || die "codesign is required"
command -v xattr >/dev/null 2>&1 || die "xattr is required"

mkdir -p "$artifacts"
artifacts="$(cd "$artifacts" && pwd)"
metadata="$artifacts/metadata.json"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mode="patrol_external_build_xcode_then_exact_archive_physical_production_install"
production_source_mode="git_archive"
write_build_exit_code=""
write_exit_code=""
launch_exit_code=""
terminate_exit_code=""
read_build_exit_code=""
read_exit_code=""
production_export_exit_code=""
production_extract_exit_code=""
production_build_exit_code=""
production_codesign_verify_exit_code=""
production_xattr_inspect_exit_code=""
production_install_exit_code=""
maestro_exit_code=""
cleanup_status="pending"
runtime_completed=false
mobile_build="$mobile_root/build"
build_backup="$mobile_root/.dart_tool/mint-patrol-g1-bnd05-document-reference-build-backup-$sha"
external_root=""
external_build=""
production_archive=""
production_export_root=""
production_mobile=""
production_app=""
production_mobile_tree=""
build_isolation_enabled=false
original_build_present=false
restoration_status="not_started"
reset_between_patrol_stages=false
patrol_build_purged_before_production=false
production_source_exported_exact=false
production_source_physical=false
artifact_cleanup_failed=false
stage_sanitization_failed=0

python3 - "$device" >"$artifacts/device.sha256" <<'PY'
import hashlib
import sys
print(hashlib.sha256(sys.argv[1].encode("utf-8")).hexdigest())
PY
device_sha256="$(cat "$artifacts/device.sha256")"

: >"$artifacts/source-manifest.sha256"
for runtime_path in "${runtime_paths[@]}"; do
  digest="$(shasum -a 256 "$repo_root/$runtime_path" | awk '{print $1}')"
  printf '%s  %s\n' "$digest" "$runtime_path" >>"$artifacts/source-manifest.sha256"
done

sanitize_log() {
  local raw="$1"
  local output="$2"
  local failed=0
  if ! python3 - "$raw" "$output" "$repo_root" "$HOME" "$device" \
    "$external_root" <<'PY'
import re
import sys
from pathlib import Path

raw_path, output_path, repo, home, device, external_root = sys.argv[1:]
text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
for private, token in (
    (repo, "REDACTED_REPO"),
    (home, "REDACTED_HOME"),
    (device, "REDACTED_SIMULATOR_UDID"),
):
    if private:
        text = text.replace(private, token)

external_aliases = {external_root} if external_root else set()
if external_root.startswith("/private/tmp/"):
    external_aliases.add(external_root[len("/private") :])
elif external_root.startswith("/tmp/"):
    external_aliases.add(f"/private{external_root}")
for private in sorted(external_aliases, key=len, reverse=True):
    text = text.replace(private, "REDACTED_EXTERNAL_BUILD")

text = re.sub(
    r"/(?:private/)?var/folders/[^\s\"'<>]+",
    "REDACTED_PRIVATE_TEMP",
    text,
)
text = re.sub(
    r"/(?:private/)?tmp/[^\s\"'<>]+",
    "REDACTED_PRIVATE_TEMP",
    text,
)
Path(output_path).write_text(text, encoding="utf-8")
PY
  then
    echo "patrol_bnd05_document_reference_process_death: log sanitization failed" >&2
    failed=1
  fi
  if [[ -e "$raw" || -L "$raw" ]]; then
    if ! rm -f -- "$raw"; then
      echo "patrol_bnd05_document_reference_process_death: raw log removal failed" >&2
      failed=1
    fi
  fi
  return "$failed"
}

sanitize_stage_log() {
  stage_sanitization_failed=0
  if ! sanitize_log "$1" "$2"; then
    artifact_cleanup_failed=true
    stage_sanitization_failed=1
  fi
}

write_metadata() {
  local finished_at
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  MINT_META_SHA="$sha" \
  MINT_META_BUNDLE="$bundle_id" \
  MINT_META_DEVICE_SHA="$device_sha256" \
  MINT_META_STARTED="$started_at" \
  MINT_META_FINISHED="$finished_at" \
  MINT_META_MODE="$mode" \
  MINT_META_SOURCE_MODE="$production_source_mode" \
  MINT_META_MOBILE_TREE="$production_mobile_tree" \
  MINT_META_WRITE_BUILD="$write_build_exit_code" \
  MINT_META_WRITE="$write_exit_code" \
  MINT_META_LAUNCH="$launch_exit_code" \
  MINT_META_TERMINATE="$terminate_exit_code" \
  MINT_META_READ_BUILD="$read_build_exit_code" \
  MINT_META_READ="$read_exit_code" \
  MINT_META_PRODUCTION_EXPORT="$production_export_exit_code" \
  MINT_META_PRODUCTION_EXTRACT="$production_extract_exit_code" \
  MINT_META_PRODUCTION_BUILD="$production_build_exit_code" \
  MINT_META_PRODUCTION_CODESIGN="$production_codesign_verify_exit_code" \
  MINT_META_PRODUCTION_XATTR="$production_xattr_inspect_exit_code" \
  MINT_META_PRODUCTION_INSTALL="$production_install_exit_code" \
  MINT_META_MAESTRO="$maestro_exit_code" \
  MINT_META_CLEANUP="$cleanup_status" \
  MINT_META_BUILD_ENABLED="$build_isolation_enabled" \
  MINT_META_ORIGINAL_BUILD="$original_build_present" \
  MINT_META_RESTORATION="$restoration_status" \
  MINT_META_BUILD_RESET="$reset_between_patrol_stages" \
  MINT_META_PATROL_PURGED="$patrol_build_purged_before_production" \
  MINT_META_SOURCE_EXACT="$production_source_exported_exact" \
  MINT_META_SOURCE_PHYSICAL="$production_source_physical" \
  python3 - "$metadata" "$artifacts" <<'PY'
import json
import os
import sys
from pathlib import Path


def code(name: str):
    value = os.environ[name]
    return int(value) if value else None


expected_logs = [
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
]
artifacts = Path(sys.argv[2])
payload = {
    "contract": "g1_bnd05_document_reference",
    "sha": os.environ["MINT_META_SHA"],
    "bundle_id": os.environ["MINT_META_BUNDLE"],
    "device_sha256": os.environ["MINT_META_DEVICE_SHA"],
    "started_at": os.environ["MINT_META_STARTED"],
    "finished_at": os.environ["MINT_META_FINISHED"],
    "mode": os.environ["MINT_META_MODE"],
    "production_source_mode": os.environ["MINT_META_SOURCE_MODE"],
    "production_mobile_tree": os.environ["MINT_META_MOBILE_TREE"] or None,
    "write_build_exit_code": code("MINT_META_WRITE_BUILD"),
    "write_exit_code": code("MINT_META_WRITE"),
    "launch_exit_code": code("MINT_META_LAUNCH"),
    "terminate_exit_code": code("MINT_META_TERMINATE"),
    "read_build_exit_code": code("MINT_META_READ_BUILD"),
    "read_exit_code": code("MINT_META_READ"),
    "production_export_exit_code": code("MINT_META_PRODUCTION_EXPORT"),
    "production_extract_exit_code": code("MINT_META_PRODUCTION_EXTRACT"),
    "production_build_exit_code": code("MINT_META_PRODUCTION_BUILD"),
    "production_codesign_verify_exit_code": code("MINT_META_PRODUCTION_CODESIGN"),
    "production_xattr_inspect_exit_code": code("MINT_META_PRODUCTION_XATTR"),
    "production_install_exit_code": code("MINT_META_PRODUCTION_INSTALL"),
    "maestro_exit_code": code("MINT_META_MAESTRO"),
    "cleanup_status": os.environ["MINT_META_CLEANUP"],
    "build_isolation": {
        "enabled": os.environ["MINT_META_BUILD_ENABLED"] == "true",
        "original_build_present": os.environ["MINT_META_ORIGINAL_BUILD"] == "true",
        "patrol_build_purged_before_production": os.environ["MINT_META_PATROL_PURGED"] == "true",
        "production_source_exported_exact": os.environ["MINT_META_SOURCE_EXACT"] == "true",
        "production_source_physical": os.environ["MINT_META_SOURCE_PHYSICAL"] == "true",
        "reset_between_patrol_stages": os.environ["MINT_META_BUILD_RESET"] == "true",
        "restoration_status": os.environ["MINT_META_RESTORATION"],
    },
    "synthetic_data_only": True,
    "private_fixture_used": False,
    "source_manifest": "source-manifest.sha256",
    "expected_logs": expected_logs,
    "logs": [log for log in expected_logs if (artifacts / log).is_file()],
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

verify_retained_artifacts() {
  python3 - "$artifacts" "$repo_root" "$HOME" "$device" \
    "$external_root" <<'PY'
import os
import stat
import sys
from pathlib import Path


artifacts, repo, home, device, external_root = sys.argv[1:]
root = Path(artifacts)


def fail(relative: str, reason: str) -> None:
    print(
        "patrol_bnd05_document_reference_process_death: "
        f"unsafe retained artifact ({relative}: {reason})",
        file=sys.stderr,
    )
    raise SystemExit(1)


try:
    root_status = os.lstat(root)
except OSError:
    fail(".", "artifact root is unavailable")
if not stat.S_ISDIR(root_status.st_mode) or stat.S_ISLNK(root_status.st_mode):
    fail(".", "artifact root is not a physical directory")

external_aliases = {external_root} if external_root else set()
if external_root.startswith("/private/tmp/"):
    external_aliases.add(external_root[len("/private") :])
elif external_root.startswith("/tmp/"):
    external_aliases.add(f"/private{external_root}")

forbidden_content = tuple(
    value
    for value in (
        repo,
        home,
        device,
        *sorted(external_aliases),
        "/Users/",
        "/private/",
        "/tmp/",
        "/private/tmp/",
        "/var/folders/",
        "/private/var/folders/",
    )
    if value
)
forbidden_names = {
    "maestro-debug",
    "maestro-report.xml",
    "maestro-test-output",
}
forbidden_suffixes = (
    ".mp4",
    ".png",
    ".raw.log",
    ".xcresult",
)


def fail_walk(_error: OSError) -> None:
    fail(".", "artifact tree could not be inspected")


for current_root, directory_names, file_names in os.walk(
    root,
    topdown=True,
    onerror=fail_walk,
    followlinks=False,
):
    for name in (*directory_names, *file_names):
        path = Path(current_root, name)
        relative = path.relative_to(root).as_posix()
        lowered = name.lower()
        try:
            entry_status = os.lstat(path)
        except OSError:
            fail(relative, "artifact entry could not be inspected")
        if stat.S_ISLNK(entry_status.st_mode):
            fail(relative, "symlink")
        if lowered in forbidden_names or lowered.endswith(forbidden_suffixes):
            fail(relative, "raw report or debug media")
        if stat.S_ISDIR(entry_status.st_mode):
            continue
        if not stat.S_ISREG(entry_status.st_mode):
            fail(relative, "non-regular artifact")
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            fail(relative, "artifact content could not be inspected")
        if any(private in content for private in forbidden_content):
            fail(relative, "absolute private path or raw simulator identifier")
PY
}

cleanup() {
  local exit_code=$?
  local cleanup_failed=0
  local build_cleanup_failed=0
  local tracked_status=0
  trap - EXIT HUP INT TERM
  cleanup_status="passed"

  if [[ "$artifact_cleanup_failed" == true ]]; then
    cleanup_failed=1
  fi
  for log_stem in \
    write-build write launch terminate read-build read \
    production-export production-extract production-build \
    production-codesign production-xattrs production-install maestro; do
    raw_log="$artifacts/$log_stem.raw.log"
    if [[ -e "$raw_log" || -L "$raw_log" ]]; then
      if ! sanitize_log "$raw_log" "$artifacts/$log_stem.log"; then
        cleanup_failed=1
      fi
    fi
  done
  if [[ -e "$artifacts/maestro-report.xml" \
    || -L "$artifacts/maestro-report.xml" ]]; then
    if ! rm -f -- "$artifacts/maestro-report.xml"; then
      echo "patrol_bnd05_document_reference_process_death: raw Maestro report removal failed" >&2
      cleanup_failed=1
    fi
  fi

  if [[ "$build_isolation_enabled" == true ]]; then
    if [[ -L "$mobile_build" ]]; then
      if [[ "$(readlink "$mobile_build")" == "$external_build" ]]; then
        if ! rm -- "$mobile_build"; then
          echo "patrol_bnd05_document_reference_process_death: external build symlink cleanup failed" >&2
          build_cleanup_failed=1
        fi
      else
        echo "patrol_bnd05_document_reference_process_death: build symlink target drifted" >&2
        build_cleanup_failed=1
      fi
    elif [[ -e "$mobile_build" ]]; then
      if [[ "$original_build_present" != true || -e "$build_backup" ]]; then
        echo "patrol_bnd05_document_reference_process_death: build path changed during isolation" >&2
        build_cleanup_failed=1
      fi
    fi

    if [[ "$original_build_present" == true ]]; then
      if [[ ! -e "$mobile_build" && -d "$build_backup" ]]; then
        if ! mv "$build_backup" "$mobile_build"; then
          echo "patrol_bnd05_document_reference_process_death: original build restoration failed" >&2
          build_cleanup_failed=1
        fi
      elif [[ ! -d "$mobile_build" || -L "$mobile_build" || -e "$build_backup" ]]; then
        echo "patrol_bnd05_document_reference_process_death: original build restoration is ambiguous" >&2
        build_cleanup_failed=1
      fi
    elif [[ -e "$mobile_build" || -L "$mobile_build" || -e "$build_backup" ]]; then
      echo "patrol_bnd05_document_reference_process_death: isolated build cleanup is ambiguous" >&2
      build_cleanup_failed=1
    fi

    if [[ "$build_cleanup_failed" -ne 0 ]]; then
      restoration_status="failed"
      cleanup_failed=1
    else
      restoration_status="restored"
    fi
  fi

  if [[ -n "$external_root" && -d "$external_root" ]]; then
    if ! rm -rf -- "$external_root"; then
      echo "patrol_bnd05_document_reference_process_death: external build removal failed" >&2
      restoration_status="failed"
      cleanup_failed=1
    fi
  fi

  if [[ -e "$repo_root/$generated_patrol_bundle" ]]; then
    set +e
    git -C "$repo_root" ls-files --error-unmatch -- \
      "$generated_patrol_bundle" >/dev/null 2>&1
    tracked_status=$?
    set -e
    if [[ "$tracked_status" -eq 1 ]]; then
      if ! rm -f -- "$repo_root/$generated_patrol_bundle"; then
        echo "patrol_bnd05_document_reference_process_death: Patrol bundle cleanup failed" >&2
        cleanup_failed=1
      fi
    elif [[ "$tracked_status" -ne 0 ]]; then
      echo "patrol_bnd05_document_reference_process_death: could not verify Patrol bundle tracking" >&2
      cleanup_failed=1
    fi
  fi
  if ! verify_retained_artifacts; then
    cleanup_failed=1
  fi
  if [[ "$cleanup_failed" -ne 0 ]]; then
    cleanup_status="failed"
  fi
  if ! write_metadata; then
    echo "patrol_bnd05_document_reference_process_death: metadata write failed" >&2
    cleanup_failed=1
  fi
  if [[ "$exit_code" -ne 0 ]]; then
    exit "$exit_code"
  fi
  if [[ "$runtime_completed" != true || "$cleanup_failed" -ne 0 ]]; then
    exit 2
  fi
  echo "patrol_bnd05_document_reference_process_death: PASS sha=$sha"
  exit 0
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

assert_external_build_empty() {
  local stage="$1"
  local first_entry
  first_entry="$(find "$external_build" -mindepth 1 -print -quit)"
  [[ -z "$first_entry" ]] || die "$stage external build is not clean"
}

inspect_patrol_build() {
  local stage="$1"
  local products="$external_build/ios_integ/Build/Products"
  local runner_app
  local asset_manifest
  local xctestrun

  runner_app="$(find "$products" -type d \
    -path '*/Debug-iphonesimulator/Runner.app' -print -quit 2>/dev/null || true)"
  [[ -n "$runner_app" && -d "$runner_app" ]] \
    || die "$stage Runner.app is missing"
  asset_manifest="$runner_app/Frameworks/App.framework/flutter_assets/AssetManifest.bin"
  [[ -s "$asset_manifest" ]] \
    || die "$stage AssetManifest.bin is missing or empty"
  xctestrun="$(find "$products" -maxdepth 2 -type f \
    -name '*.xctestrun' -print -quit 2>/dev/null || true)"
  [[ -n "$xctestrun" && -f "$xctestrun" ]] \
    || die "$stage xctestrun is missing"
  printf -v "${stage}_xctestrun" '%s' "$xctestrun"
}

inspect_production_app() {
  local app="$1"
  local runner_executable="$app/Runner"
  local info_plist="$app/Info.plist"
  local asset_manifest="$app/Frameworks/App.framework/flutter_assets/AssetManifest.bin"

  [[ -x "$runner_executable" ]] \
    || die "production Runner executable is missing"
  [[ -s "$info_plist" ]] || die "production Info.plist is missing or empty"
  if ! python3 - "$info_plist" "$bundle_id" <<'PY'
import plistlib
import sys


try:
    with open(sys.argv[1], "rb") as handle:
        payload = plistlib.load(handle)
except (OSError, plistlib.InvalidFileException, ValueError, TypeError):
    raise SystemExit(1)
raise SystemExit(0 if payload.get("CFBundleIdentifier") == sys.argv[2] else 1)
PY
  then
    die "production CFBundleIdentifier mismatch"
  fi
  [[ -s "$asset_manifest" ]] \
    || die "production AssetManifest.bin is missing or empty"
}

run_xcode_test() {
  local stage="$1"
  local xctestrun_variable="${stage}_xctestrun"
  local xctestrun="${!xctestrun_variable}"
  local result_bundle="$external_build/$stage.xcresult"
  local test_exit_code

  [[ -n "$xctestrun" && -f "$xctestrun" ]] \
    || die "$stage xctestrun is missing before test"
  [[ ! -e "$result_bundle" && ! -L "$result_bundle" ]] \
    || die "$stage xcresult path already exists"

  set +e
  xcodebuild test-without-building \
    -xctestrun "$xctestrun" \
    -only-testing "RunnerUITests/RunnerUITests" \
    -destination "platform=iOS Simulator,id=$device" \
    -resultBundlePath "$result_bundle" \
    >"$artifacts/$stage.raw.log" 2>&1
  test_exit_code=$?
  set -e
  printf -v "${stage}_exit_code" '%s' "$test_exit_code"
  sanitize_stage_log "$artifacts/$stage.raw.log" "$artifacts/$stage.log"
  if [[ "$test_exit_code" -ne 0 ]]; then
    echo "patrol_bnd05_document_reference_process_death: $stage test stage failed ($test_exit_code)" >&2
    exit "$test_exit_code"
  fi
  [[ "$stage_sanitization_failed" -eq 0 ]] \
    || die "$stage test log sanitization failed"
  [[ -d "$result_bundle" ]] || die "$stage xcresult is missing"
}

[[ ! -L "$mobile_build" ]] || die "pre-existing build symlink"
[[ -d "$mobile_build" ]] || die "normal mobile build directory is required"
[[ ! -e "$build_backup" && ! -L "$build_backup" ]] || die "backup collision"
mkdir -p "$mobile_root/.dart_tool"
external_root="$(mktemp -d "/tmp/mint-patrol-g1-bnd05-document-reference-${sha:0:12}.XXXXXX")"
external_root="$(cd "$external_root" && pwd -P)"
external_build="$external_root/build"
mkdir -p "$external_build"
build_isolation_enabled=true
restoration_status="pending"
original_build_present=true
mv "$mobile_build" "$build_backup"
ln -s "$external_build" "$mobile_build"

write_build_command=(
  "$patrol_bin" --verbose build ios
  --target "${write_target#apps/mobile/}"
  --simulator
  --bundle-id "$bundle_id"
  --dart-define=MINT_PATROL_CLI=true
)
read_build_command=(
  "$patrol_bin" --verbose build ios
  --target "${read_target#apps/mobile/}"
  --simulator
  --bundle-id "$bundle_id"
  --dart-define=MINT_PATROL_CLI=true
)

assert_external_build_empty "write"
set +e
(cd "$mobile_root" && "${write_build_command[@]}") \
  >"$artifacts/write-build.raw.log" 2>&1
write_build_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/write-build.raw.log" \
  "$artifacts/write-build.log"
if [[ "$write_build_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: write build stage failed ($write_build_exit_code)" >&2
  exit "$write_build_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "write build log sanitization failed"
inspect_patrol_build "write"
run_xcode_test "write"
exact_sha_guard

set +e
xcrun simctl launch "$device" "$bundle_id" \
  >"$artifacts/launch.raw.log" 2>&1
launch_exit_code=$?
set -e
sanitize_stage_log "$artifacts/launch.raw.log" "$artifacts/launch.log"
if [[ "$launch_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: launch stage failed ($launch_exit_code)" >&2
  exit "$launch_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] || die "launch log sanitization failed"

set +e
xcrun simctl terminate "$device" "$bundle_id" \
  >"$artifacts/terminate.raw.log" 2>&1
terminate_exit_code=$?
set -e
sanitize_stage_log "$artifacts/terminate.raw.log" "$artifacts/terminate.log"
if [[ "$terminate_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: terminate stage failed ($terminate_exit_code)" >&2
  exit "$terminate_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "terminate log sanitization failed"
exact_sha_guard

# Patrol may otherwise reuse the writer entrypoint's Flutter artifacts for the
# reader. Reset only the disposable external build after the real process death;
# xcodebuild installs the reader bundle over the existing simulator app without
# deleting its SharedPreferences container.
[[ -L "$mobile_build" && "$(readlink "$mobile_build")" == "$external_build" ]] \
  || die "external build isolation drifted before reader"
rm -rf -- "$external_build"
mkdir -p "$external_build"
reset_between_patrol_stages=true

assert_external_build_empty "read"
set +e
(cd "$mobile_root" && "${read_build_command[@]}") \
  >"$artifacts/read-build.raw.log" 2>&1
read_build_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/read-build.raw.log" \
  "$artifacts/read-build.log"
if [[ "$read_build_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: read build stage failed ($read_build_exit_code)" >&2
  exit "$read_build_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "read build log sanitization failed"
inspect_patrol_build "read"
run_xcode_test "read"
exact_sha_guard

# The reader xcode test leaves the Patrol entrypoint installed. The checkout is
# FileProvider-backed, so build the production entrypoint from the exact commit
# in a physical, disposable source tree instead of touching the checkout cache.
[[ -L "$mobile_build" && "$(readlink "$mobile_build")" == "$external_build" ]] \
  || die "external build isolation drifted before production export"
rm -rf -- "$external_build"
patrol_build_purged_before_production=true

production_archive="$external_root/mobile.tar"
production_export_root="$external_root/source"
production_mobile="$production_export_root/apps/mobile"
production_app="$production_mobile/build/ios/iphonesimulator/Runner.app"
[[ ! -e "$production_archive" && ! -L "$production_archive" ]] \
  || die "production archive path already exists"
[[ ! -e "$production_export_root" && ! -L "$production_export_root" ]] \
  || die "production export path already exists"
mkdir -p "$production_export_root"

production_mobile_tree="$(git -C "$repo_root" rev-parse "$sha:apps/mobile")"
[[ "$production_mobile_tree" =~ ^[0-9a-f]{40}$ ]] \
  || die "production mobile tree is invalid"

set +e
git -C "$repo_root" archive --format=tar --output "$production_archive" "$sha" -- apps/mobile \
  >"$artifacts/production-export.raw.log" 2>&1
production_export_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/production-export.raw.log" \
  "$artifacts/production-export.log"
if [[ "$production_export_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: production export stage failed ($production_export_exit_code)" >&2
  exit "$production_export_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "production export log sanitization failed"
[[ -s "$production_archive" && ! -L "$production_archive" ]] \
  || die "production archive is missing or empty"

set +e
tar -xf "$production_archive" -C "$production_export_root" \
  >"$artifacts/production-extract.raw.log" 2>&1
production_extract_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/production-extract.raw.log" \
  "$artifacts/production-extract.log"
if ! rm -f -- "$production_archive"; then
  die "production archive removal failed"
fi
if [[ "$production_extract_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: production extract stage failed ($production_extract_exit_code)" >&2
  exit "$production_extract_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "production extract log sanitization failed"

[[ -d "$production_mobile" && ! -L "$production_mobile" ]] \
  || die "production mobile export is not a physical directory"
resolved_production_mobile="$(cd "$production_mobile" && pwd -P)"
[[ "$resolved_production_mobile" == "$production_export_root/apps/mobile" ]] \
  || die "production mobile export escaped the external root"
for forbidden_export_path in \
  .git build .dart_tool ios/Pods ios/.symlinks \
  ios/Flutter/Generated.xcconfig; do
  [[ ! -e "$production_mobile/$forbidden_export_path" \
    && ! -L "$production_mobile/$forbidden_export_path" ]] \
    || die "production export contains generated path: $forbidden_export_path"
done
for required_export_path in \
  pubspec.yaml pubspec.lock lib/main.dart ios/Podfile ios/Podfile.lock \
  ios/Runner.xcodeproj/project.pbxproj ios/Flutter/Debug.xcconfig; do
  [[ -s "$production_mobile/$required_export_path" ]] \
    || die "production export is missing: $required_export_path"
done

if ! python3 - "$production_mobile" <<'PY'
import os
import stat
import sys


root = sys.argv[1]


def fail_walk(_error):
    raise SystemExit(1)


try:
    root_status = os.lstat(root)
except OSError:
    raise SystemExit(1)
if stat.S_ISLNK(root_status.st_mode):
    raise SystemExit(1)

for current_root, directory_names, file_names in os.walk(
    root,
    topdown=True,
    onerror=fail_walk,
    followlinks=False,
):
    for name in (*directory_names, *file_names):
        try:
            entry_status = os.lstat(os.path.join(current_root, name))
        except OSError:
            raise SystemExit(1)
        if stat.S_ISLNK(entry_status.st_mode):
            raise SystemExit(1)
        if stat.S_ISREG(entry_status.st_mode) and entry_status.st_nlink > 1:
            raise SystemExit(1)
PY
then
  die "production mobile export contains an unsafe alias"
fi
production_source_exported_exact=true
production_source_physical=true

set +e
(cd "$production_mobile" && \
  flutter build ios --simulator --debug --target lib/main.dart) \
  >"$artifacts/production-build.raw.log" 2>&1
production_build_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/production-build.raw.log" \
  "$artifacts/production-build.log"
if [[ "$production_build_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: production build stage failed ($production_build_exit_code)" >&2
  exit "$production_build_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "production build log sanitization failed"
inspect_production_app "$production_app"
exact_sha_guard

set +e
codesign --verify --strict --deep "$production_app" \
  >"$artifacts/production-codesign.raw.log" 2>&1
production_codesign_verify_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/production-codesign.raw.log" \
  "$artifacts/production-codesign.log"
if [[ "$production_codesign_verify_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: production codesign verification failed ($production_codesign_verify_exit_code)" >&2
  exit "$production_codesign_verify_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "production codesign log sanitization failed"

set +e
xattr -r "$production_app" \
  >"$artifacts/production-xattrs.raw.log" 2>&1
production_xattr_inspect_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/production-xattrs.raw.log" \
  "$artifacts/production-xattrs.log"
if [[ "$production_xattr_inspect_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: production xattr inspection failed ($production_xattr_inspect_exit_code)" >&2
  exit "$production_xattr_inspect_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "production xattr inspection log sanitization failed"
if grep -Fq 'com.apple.FinderInfo' "$artifacts/production-xattrs.log" \
  || grep -Fq 'com.apple.ResourceFork' "$artifacts/production-xattrs.log"; then
  die "production exported app has forbidden extended attribute"
fi
exact_sha_guard

set +e
xcrun simctl install "$device" "$production_app" \
  >"$artifacts/production-install.raw.log" 2>&1
production_install_exit_code=$?
set -e
sanitize_stage_log \
  "$artifacts/production-install.raw.log" \
  "$artifacts/production-install.log"
if [[ "$production_install_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: production install stage failed ($production_install_exit_code)" >&2
  exit "$production_install_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] \
  || die "production install log sanitization failed"
exact_sha_guard

set +e
"${maestro_command[@]}" test --udid "$device" --format JUNIT \
  --debug-output "$external_root/maestro-debug" \
  --test-output-dir "$external_root/maestro-test-output" \
  --output "$artifacts/maestro-report.xml" "$repo_root/$maestro_flow" \
  >"$artifacts/maestro.raw.log" 2>&1
maestro_exit_code=$?
set -e
sanitize_stage_log "$artifacts/maestro.raw.log" "$artifacts/maestro.log"
if [[ "$maestro_exit_code" -ne 0 ]]; then
  echo "patrol_bnd05_document_reference_process_death: Maestro stage failed ($maestro_exit_code)" >&2
  exit "$maestro_exit_code"
fi
[[ "$stage_sanitization_failed" -eq 0 ]] || die "Maestro log sanitization failed"
if [[ ! -s "$artifacts/maestro-report.xml" ]]; then
  maestro_exit_code=2
  die "Maestro JUnit report is missing or empty"
fi
sanitize_stage_log \
  "$artifacts/maestro-report.xml" \
  "$artifacts/maestro-report.sanitized.xml"
if [[ "$stage_sanitization_failed" -ne 0 ]]; then
  maestro_exit_code=2
  die "Maestro JUnit report sanitization failed"
fi
if ! python3 - "$artifacts/maestro-report.sanitized.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

ET.parse(sys.argv[1])
PY
then
  maestro_exit_code=2
  die "sanitized Maestro JUnit report is invalid XML"
fi
exact_sha_guard

runtime_completed=true
