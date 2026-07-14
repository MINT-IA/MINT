#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --device <UDID> --bundle-id <bundle> --sha <40-hex> --artifacts <dir>" >&2
}

die() {
  echo "patrol_tax_provenance_process_death: $*" >&2
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
write_contract="integration_test/g1_prov03_tax_persistence_write_patrol_test.dart"
read_contract="integration_test/g1_prov03_tax_persistence_read_patrol_test.dart"
write_target="test/patrol/g1_prov03_tax_persistence_write_runtime_test.dart"
read_target="test/patrol/g1_prov03_tax_persistence_read_runtime_test.dart"
[[ -f "$mobile_root/$write_contract" ]] || die "tax write contract is missing"
[[ -f "$mobile_root/$read_contract" ]] || die "tax read contract is missing"
[[ -f "$mobile_root/$write_target" ]] || die "tax write target is missing"
[[ -f "$mobile_root/$read_target" ]] || die "tax read target is missing"

runtime_paths=(
  "apps/mobile/$write_contract"
  "apps/mobile/$read_contract"
  "apps/mobile/$write_target"
  "apps/mobile/$read_target"
  "tools/simulator/patrol_tax_provenance_process_death.sh"
)
for runtime_path in "${runtime_paths[@]}"; do
  git -C "$repo_root" ls-files --error-unmatch -- "$runtime_path" >/dev/null \
    || die "runtime contract is not tracked by HEAD: $runtime_path"
done
untracked_mobile="$(
  git -C "$repo_root" ls-files --others --exclude-standard -- apps/mobile
)"
[[ -z "$untracked_mobile" ]] \
  || die "untracked mobile files make --sha evidence ambiguous"
git -C "$repo_root" diff --quiet HEAD -- apps/mobile \
  tools/simulator/patrol_tax_provenance_process_death.sh \
  || die "runtime files differ from --sha HEAD"

patrol_bin="${PATROL_BIN:-$HOME/.pub-cache/bin/patrol}"
[[ -x "$patrol_bin" ]] || die "Patrol CLI is not executable at $patrol_bin"
for required_command in xcrun xcodebuild codesign xattr python3; do
  command -v "$required_command" >/dev/null 2>&1 \
    || die "$required_command is required"
done

mkdir -p "$artifacts"
artifacts="$(cd "$artifacts" && pwd)"
metadata="$artifacts/metadata.json"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
finished_at=""
write_exit_code=""
boot_status_exit_code=""
launch_exit_code=""
terminate_exit_code=""
read_exit_code=""
boot_status_log="$artifacts/bootstatus.log"

mobile_build="$mobile_root/build"
build_backup="$mobile_root/.dart_tool/mint-patrol-g1-prov03-build-backup-$sha"
external_root=""
external_build=""
original_build_present=false
restoration_status="not_started"

write_result_path=""
write_result_sha256=""
write_result_manifest=""
read_result_path=""
read_result_sha256=""
read_result_manifest=""
write_entitlements_path=""
write_entitlements_sha256=""
write_der_path=""
write_der_sha256=""
read_entitlements_path=""
read_entitlements_sha256=""
read_der_path=""
read_der_sha256=""

write_command_text="$patrol_bin build ios --target $write_target --simulator --bundle-id $bundle_id --dart-define=MINT_PATROL_CLI=true"
read_command_text="$patrol_bin build ios --target $read_target --simulator --bundle-id $bundle_id --dart-define=MINT_PATROL_CLI=true"
boot_status_command_text="xcrun simctl bootstatus $device -b"
launch_command_text="xcrun simctl launch $device $bundle_id"
terminate_command_text="xcrun simctl terminate $device $bundle_id"

write_metadata() {
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  MINT_META_DEVICE="$device" \
  MINT_META_BUNDLE="$bundle_id" \
  MINT_META_SHA="$sha" \
  MINT_META_STARTED="$started_at" \
  MINT_META_FINISHED="$finished_at" \
  MINT_META_WRITE_COMMAND="$write_command_text" \
  MINT_META_BOOT_STATUS_COMMAND="$boot_status_command_text" \
  MINT_META_BOOT_STATUS_LOG="$boot_status_log" \
  MINT_META_LAUNCH_COMMAND="$launch_command_text" \
  MINT_META_TERMINATE_COMMAND="$terminate_command_text" \
  MINT_META_READ_COMMAND="$read_command_text" \
  MINT_META_WRITE_EXIT="$write_exit_code" \
  MINT_META_BOOT_STATUS_EXIT="$boot_status_exit_code" \
  MINT_META_LAUNCH_EXIT="$launch_exit_code" \
  MINT_META_TERMINATE_EXIT="$terminate_exit_code" \
  MINT_META_READ_EXIT="$read_exit_code" \
  MINT_META_EXTERNAL_BUILD="$external_build" \
  MINT_META_BUILD_BACKUP="$build_backup" \
  MINT_META_ORIGINAL_BUILD="$original_build_present" \
  MINT_META_RESTORATION="$restoration_status" \
  MINT_META_WRITE_RESULT="$write_result_path" \
  MINT_META_WRITE_RESULT_SHA="$write_result_sha256" \
  MINT_META_WRITE_RESULT_MANIFEST="$write_result_manifest" \
  MINT_META_READ_RESULT="$read_result_path" \
  MINT_META_READ_RESULT_SHA="$read_result_sha256" \
  MINT_META_READ_RESULT_MANIFEST="$read_result_manifest" \
  MINT_META_WRITE_ENTITLEMENTS="$write_entitlements_path" \
  MINT_META_WRITE_ENTITLEMENTS_SHA="$write_entitlements_sha256" \
  MINT_META_WRITE_DER="$write_der_path" \
  MINT_META_WRITE_DER_SHA="$write_der_sha256" \
  MINT_META_READ_ENTITLEMENTS="$read_entitlements_path" \
  MINT_META_READ_ENTITLEMENTS_SHA="$read_entitlements_sha256" \
  MINT_META_READ_DER="$read_der_path" \
  MINT_META_READ_DER_SHA="$read_der_sha256" \
  python3 - "$metadata" <<'PY'
import json
import os
import sys


def exit_code(name: str):
    value = os.environ[name]
    return int(value) if value else None


def stage_result(stage: str):
    prefix = f"MINT_META_{stage.upper()}_RESULT"
    path = os.environ[prefix]
    if not path:
        return None
    return {
        "path": path,
        "sha256": os.environ[f"{prefix}_SHA"],
        "manifest_path": os.environ[f"{prefix}_MANIFEST"],
    }


def stage_sections(stage: str):
    prefix = f"MINT_META_{stage.upper()}"
    entitlements = os.environ[f"{prefix}_ENTITLEMENTS"]
    if not entitlements:
        return None
    return {
        "entitlements_path": entitlements,
        "entitlements_sha256": os.environ[f"{prefix}_ENTITLEMENTS_SHA"],
        "der_path": os.environ[f"{prefix}_DER"],
        "der_sha256": os.environ[f"{prefix}_DER_SHA"],
    }


payload = {
    "contract": "g1_prov03_tax",
    "device": os.environ["MINT_META_DEVICE"],
    "bundle_id": os.environ["MINT_META_BUNDLE"],
    "sha": os.environ["MINT_META_SHA"],
    "started_at": os.environ["MINT_META_STARTED"],
    "finished_at": os.environ["MINT_META_FINISHED"],
    "write_command": os.environ["MINT_META_WRITE_COMMAND"],
    "boot_status_command": os.environ["MINT_META_BOOT_STATUS_COMMAND"],
    "boot_status_log": os.environ["MINT_META_BOOT_STATUS_LOG"],
    "launch_command": os.environ["MINT_META_LAUNCH_COMMAND"],
    "terminate_command": os.environ["MINT_META_TERMINATE_COMMAND"],
    "read_command": os.environ["MINT_META_READ_COMMAND"],
    "write_exit_code": exit_code("MINT_META_WRITE_EXIT"),
    "boot_status_exit_code": exit_code("MINT_META_BOOT_STATUS_EXIT"),
    "launch_exit_code": exit_code("MINT_META_LAUNCH_EXIT"),
    "terminate_exit_code": exit_code("MINT_META_TERMINATE_EXIT"),
    "read_exit_code": exit_code("MINT_META_READ_EXIT"),
    "synthetic_data_only": True,
    "feature_activation": "test_process_static_flags_only",
    "external_build": {
        "enabled": bool(os.environ["MINT_META_EXTERNAL_BUILD"]),
        "path": os.environ["MINT_META_EXTERNAL_BUILD"],
        "backup_path": os.environ["MINT_META_BUILD_BACKUP"],
        "original_build_present": os.environ["MINT_META_ORIGINAL_BUILD"] == "true",
        "restoration_status": os.environ["MINT_META_RESTORATION"],
    },
    "xcresults": {
        "write": stage_result("write"),
        "read": stage_result("read"),
    },
    "mach_o_sections": {
        "write": stage_sections("write"),
        "read": stage_sections("read"),
    },
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

cleanup() {
  local exit_code=$?
  trap - EXIT
  set +e
  local cleanup_failed=false

  if [[ -L "$mobile_build" ]]; then
    if [[ "$(readlink "$mobile_build")" == "$external_build" ]]; then
      rm "$mobile_build" || cleanup_failed=true
    else
      cleanup_failed=true
    fi
  elif [[ -e "$mobile_build" && "$restoration_status" != "not_started" ]]; then
    cleanup_failed=true
  fi

  if [[ "$original_build_present" == true ]]; then
    if [[ ! -e "$mobile_build" && -d "$build_backup" ]]; then
      mv "$build_backup" "$mobile_build" || cleanup_failed=true
    elif [[ ! -d "$mobile_build" || -e "$build_backup" ]]; then
      cleanup_failed=true
    fi
  fi

  generated_bundle="$mobile_root/test/patrol/test_bundle.dart"
  if [[ -f "$generated_bundle" ]] \
    && ! git -C "$repo_root" ls-files --error-unmatch -- \
      "apps/mobile/test/patrol/test_bundle.dart" >/dev/null 2>&1; then
    rm "$generated_bundle" || cleanup_failed=true
  fi

  if [[ "$cleanup_failed" == true ]]; then
    restoration_status="failed"
    [[ "$exit_code" -ne 0 ]] || exit_code=2
  elif [[ "$restoration_status" != "not_started" ]]; then
    restoration_status="restored"
  fi

  if [[ -n "$external_root" && -d "$external_root" ]]; then
    rm -rf "$external_root" || {
      restoration_status="failed"
      [[ "$exit_code" -ne 0 ]] || exit_code=2
    }
  fi
  write_metadata
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

hash_tree() {
  local tree="$1"
  local manifest="$2"
  python3 - "$tree" "$manifest" <<'PY'
import hashlib
import sys
from pathlib import Path


root = Path(sys.argv[1])
manifest = Path(sys.argv[2])
lines = []
for path in sorted(item for item in root.rglob("*") if item.is_file()):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    lines.append(f"{digest}  {path.relative_to(root).as_posix()}")
manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(hashlib.sha256(("\n".join(lines) + "\n").encode()).hexdigest())
PY
}

inspect_runner() {
  local stage="$1"
  local products="$external_build/ios_integ/Build/Products"
  local runner_app
  local xctestrun
  runner_app="$(find "$products" -type d -path '*/Debug-iphonesimulator/Runner.app' -print -quit)"
  [[ -n "$runner_app" && -d "$runner_app" ]] \
    || die "$stage Runner.app is missing"
  xctestrun="$(find "$products" -maxdepth 2 -type f -name '*.xctestrun' -print -quit)"
  [[ -n "$xctestrun" && -f "$xctestrun" ]] \
    || die "$stage xctestrun is missing"

  cp "$xctestrun" "$artifacts/$stage-Runner.xctestrun"
  printf -v "${stage}_xctestrun" '%s' "$xctestrun"

  local asset_manifest="$runner_app/Frameworks/App.framework/flutter_assets/AssetManifest.bin"
  [[ -s "$asset_manifest" ]] \
    || die "$stage AssetManifest.bin is missing or empty"
  cp "$asset_manifest" "$artifacts/$stage-AssetManifest.bin"
  shasum -a 256 "$asset_manifest" | awk '{print $1}' \
    >"$artifacts/$stage-AssetManifest.sha256"

  if ! codesign --verify --strict --deep "$runner_app" \
    >"$artifacts/$stage-codesign-verify.log" 2>&1; then
    die "$stage codesign verification failed"
  fi

  if ! xattr -lr "$runner_app" >"$artifacts/$stage-xattrs.txt" 2>&1; then
    die "$stage xattr inspection failed"
  fi
  if grep -Fq 'com.apple.FinderInfo' "$artifacts/$stage-xattrs.txt" \
    || grep -Fq 'com.apple.ResourceFork' "$artifacts/$stage-xattrs.txt"; then
    die "$stage forbidden extended attribute"
  fi

  local runner_binary="$runner_app/Runner"
  local thin_binary="$artifacts/$stage-Runner-arm64"
  local otool_output="$artifacts/$stage-Runner-otool.txt"
  local entitlements_output="$artifacts/$stage-Runner-MachO-entitlements.plist"
  local der_output="$artifacts/$stage-Runner-MachO-ents.der"
  [[ -f "$runner_binary" ]] || die "$stage Runner executable is missing"
  xcrun lipo -thin arm64 "$runner_binary" -output "$thin_binary"
  xcrun otool -l "$thin_binary" >"$otool_output"

  python3 - "$thin_binary" "$otool_output" "$entitlements_output" \
    "$der_output" "7F5UDGYS5H.$bundle_id" <<'PY'
import plistlib
import sys
from pathlib import Path


binary_path, otool_path, entitlements_path, der_path, expected_app_id = sys.argv[1:]
binary = Path(binary_path).read_bytes()
lines = Path(otool_path).read_text(encoding="utf-8").splitlines()


def section(name: str):
    for index, line in enumerate(lines):
        if line.strip() != f"sectname {name}":
            continue
        segment = None
        size = None
        offset = None
        for detail in lines[index + 1 :]:
            stripped = detail.strip()
            if stripped == "Section" or stripped.startswith("sectname "):
                break
            if stripped.startswith("segname "):
                segment = stripped.split(maxsplit=1)[1]
            elif stripped.startswith("size "):
                size = int(stripped.split(maxsplit=1)[1], 0)
            elif stripped.startswith("offset "):
                offset = int(stripped.split(maxsplit=1)[1], 0)
        if segment == "__TEXT" and size and offset is not None:
            end = offset + size
            if end > len(binary):
                raise SystemExit(f"invalid __TEXT,{name} section bounds")
            return binary[offset:end]
    return None


xml = section("__entitlements")
if xml is None:
    raise SystemExit("missing __TEXT,__entitlements section")
der = section("__ents_der")
if der is None:
    raise SystemExit("missing __TEXT,__ents_der section")

try:
    payload = plistlib.loads(xml)
except Exception as error:
    raise SystemExit(f"invalid simulated entitlement plist: {error}") from error
if payload.get("application-identifier") != expected_app_id:
    raise SystemExit("application-identifier mismatch")
if payload.get("keychain-access-groups") != [expected_app_id]:
    raise SystemExit("keychain-access-groups mismatch")
if set(payload) != {"application-identifier", "keychain-access-groups"}:
    raise SystemExit("unexpected simulated entitlement keys")

Path(entitlements_path).write_bytes(xml)
Path(der_path).write_bytes(der)
PY

  local entitlements_sha
  local der_sha
  entitlements_sha="$(shasum -a 256 "$entitlements_output" | awk '{print $1}')"
  der_sha="$(shasum -a 256 "$der_output" | awk '{print $1}')"
  printf -v "${stage}_entitlements_path" '%s' "$entitlements_output"
  printf -v "${stage}_entitlements_sha256" '%s' "$entitlements_sha"
  printf -v "${stage}_der_path" '%s' "$der_output"
  printf -v "${stage}_der_sha256" '%s' "$der_sha"
}

run_xcode_test() {
  local stage="$1"
  local xctestrun_variable="${stage}_xctestrun"
  local xctestrun="${!xctestrun_variable}"
  local result_bundle="$artifacts/$stage.xcresult"
  local result_manifest="$artifacts/$stage-xcresult.sha256"
  [[ ! -e "$result_bundle" ]] || die "$stage xcresult path already exists"

  set +e
  xcodebuild test-without-building \
    -xctestrun "$xctestrun" \
    -only-testing "RunnerUITests/RunnerUITests" \
    -destination "platform=iOS Simulator,id=$device" \
    -resultBundlePath "$result_bundle" \
    2>&1 | tee "$artifacts/$stage.log"
  local test_exit_code=${PIPESTATUS[0]}
  set -e
  printf -v "${stage}_exit_code" '%s' "$test_exit_code"

  [[ -d "$result_bundle" ]] || die "$stage xcresult is missing"
  local result_sha
  result_sha="$(hash_tree "$result_bundle" "$result_manifest")"
  printf -v "${stage}_result_path" '%s' "$result_bundle"
  printf -v "${stage}_result_sha256" '%s' "$result_sha"
  printf -v "${stage}_result_manifest" '%s' "$result_manifest"

  if [[ "$test_exit_code" -ne 0 ]]; then
    echo "patrol_tax_provenance_process_death: $stage test stage failed ($test_exit_code)" >&2
    exit "$test_exit_code"
  fi
}

[[ ! -L "$mobile_build" ]] || die "pre-existing build symlink"
[[ ! -e "$build_backup" ]] || die "backup collision"
mkdir -p "$mobile_root/.dart_tool"
external_root="$(mktemp -d "/tmp/mint-patrol-g1-prov03-${sha:0:12}.XXXXXX")"
external_build="$external_root/build"
mkdir -p "$external_build"
if [[ -e "$mobile_build" ]]; then
  [[ -d "$mobile_build" ]] || die "pre-existing build path is not a directory"
  original_build_present=true
  mv "$mobile_build" "$build_backup"
fi
ln -s "$external_build" "$mobile_build"
restoration_status="pending"

set +e
(cd "$mobile_root" && "$patrol_bin" build ios \
  --target "$write_target" --simulator --bundle-id "$bundle_id" \
  --dart-define=MINT_PATROL_CLI=true) 2>&1 | tee "$artifacts/write-build.log"
write_build_exit=${PIPESTATUS[0]}
set -e
if [[ "$write_build_exit" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: write build stage failed ($write_build_exit)" >&2
  exit "$write_build_exit"
fi
inspect_runner "write"
run_xcode_test "write"

set +e
xcrun simctl bootstatus "$device" -b >"$boot_status_log" 2>&1
boot_status_exit_code=$?
set -e
if [[ "$boot_status_exit_code" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: bootstatus stage failed ($boot_status_exit_code)" >&2
  exit "$boot_status_exit_code"
fi

set +e
xcrun simctl launch "$device" "$bundle_id" >"$artifacts/launch.log" 2>&1
launch_exit_code=$?
set -e
if [[ "$launch_exit_code" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: launch stage failed ($launch_exit_code)" >&2
  exit "$launch_exit_code"
fi

set +e
xcrun simctl terminate "$device" "$bundle_id" >"$artifacts/terminate.log" 2>&1
terminate_exit_code=$?
set -e
if [[ "$terminate_exit_code" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: terminate stage failed ($terminate_exit_code)" >&2
  exit "$terminate_exit_code"
fi

# Flutter/Patrol can reuse the writer target's App.framework while switching
# entrypoints, producing a reader bundle without AssetManifest.bin.
rm -rf -- "$external_build"
mkdir -p "$external_build"

set +e
(cd "$mobile_root" && "$patrol_bin" build ios \
  --target "$read_target" --simulator --bundle-id "$bundle_id" \
  --dart-define=MINT_PATROL_CLI=true) 2>&1 | tee "$artifacts/read-build.log"
read_build_exit=${PIPESTATUS[0]}
set -e
if [[ "$read_build_exit" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: read build stage failed ($read_build_exit)" >&2
  exit "$read_build_exit"
fi
inspect_runner "read"
run_xcode_test "read"

echo "patrol_tax_provenance_process_death: PASS device=$device bundle=$bundle_id sha=$sha"
