#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
  cat >&2 <<'USAGE'
Usage: patrol_coach01_inline_amount.sh \
  --device <booted-simulator-udid> \
  --bundle-id ch.mint.app \
  --sha <exact-40-char-HEAD> \
  --artifacts <repo>/.planning/runtime-evidence/phase-37/coach-01/runtime-<shortsha>-<UTC>
USAGE
}

fail() {
  printf 'patrol_coach01_inline_amount: %s\n' "$1" >&2
  exit 2
}

device=''
bundle_id=''
expected_sha=''
artifacts=''
while (($#)); do
  case "$1" in
    --device)
      (($# >= 2)) || fail 'missing --device value'
      device=$2
      shift 2
      ;;
    --bundle-id)
      (($# >= 2)) || fail 'missing --bundle-id value'
      bundle_id=$2
      shift 2
      ;;
    --sha)
      (($# >= 2)) || fail 'missing --sha value'
      expected_sha=$2
      shift 2
      ;;
    --artifacts)
      (($# >= 2)) || fail 'missing --artifacts value'
      artifacts=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      fail 'unknown argument'
      ;;
  esac
done

[[ "$device" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
  || fail 'device must be an iOS Simulator UDID'
[[ "$bundle_id" == 'ch.mint.app' ]] || fail 'unexpected iOS bundle id'
[[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]] || fail 'sha must be 40 lowercase hex characters'
[[ -n "$artifacts" ]] || fail 'artifacts path is required'

repo=$(git rev-parse --show-toplevel 2>/dev/null) \
  || fail 'not inside a git checkout'
head_sha=$(git -C "$repo" rev-parse HEAD)
[[ "$head_sha" == "$expected_sha" ]] || fail 'requested sha is not current HEAD'
mobile="$repo/apps/mobile"
generated_bundle="$mobile/test/patrol/test_bundle.dart"
mobile_build="$mobile/build"
build_backup="$mobile/.dart_tool/mint-patrol-g1-coach01-build-backup-$expected_sha"
[[ ! -e "$generated_bundle" && ! -L "$generated_bundle" ]] \
  || fail 'refusing to touch a preexisting Patrol test bundle'
[[ ! -L "$mobile_build" ]] || fail 'refusing a preexisting build symlink'
[[ ! -e "$mobile_build" || -d "$mobile_build" ]] \
  || fail 'refusing a non-directory build path'
[[ ! -e "$build_backup" && ! -L "$build_backup" ]] \
  || fail 'refusing a preexisting build backup'
[[ ! -L "$mobile/.dart_tool" ]] || fail 'refusing a symlinked .dart_tool directory'
[[ ! -e "$mobile/.dart_tool" || -d "$mobile/.dart_tool" ]] \
  || fail 'refusing a non-directory .dart_tool path'

status=$(git -C "$repo" status --porcelain --untracked-files=all)
[[ -z "$status" ]] || fail 'HEAD must be clean before runtime evidence'

tracked_files=(
  'apps/mobile/integration_test/g1_coach01_inline_amount_patrol_test.dart'
  'apps/mobile/test/patrol/g1_coach01_inline_amount_runtime_test.dart'
  'tools/simulator/patrol_coach01_inline_amount.sh'
)
for relative in "${tracked_files[@]}"; do
  git -C "$repo" ls-files --error-unmatch -- "$relative" >/dev/null 2>&1 \
    || fail 'runtime contract files must be tracked at HEAD'
done
git -C "$repo" diff --quiet "$expected_sha" -- "${tracked_files[@]}" \
  || fail 'runtime contract files differ from the requested SHA'

artifacts_abs=$(python3 - "$artifacts" "$repo" "$expected_sha" <<'PY'
import datetime
import pathlib
import re
import sys

candidate = pathlib.Path(sys.argv[1]).resolve(strict=False)
repo = pathlib.Path(sys.argv[2]).resolve(strict=True)
sha = sys.argv[3]
expected_parent = repo / ".planning/runtime-evidence/phase-37/coach-01"
if candidate.parent != expected_parent:
    raise SystemExit("artifacts must be directly under phase-37/coach-01")
match = re.fullmatch(
    rf"runtime-{re.escape(sha[:10])}-(\d{{8}}T\d{{6}}Z)",
    candidate.name,
)
if match is None:
    raise SystemExit("artifacts must match runtime-<shortsha>-<UTC>")
datetime.datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ")
print(candidate)
PY
) || fail 'invalid phase-37 COACH-01 artifacts directory'
[[ ! -e "$artifacts_abs" && ! -L "$artifacts_abs" ]] \
  || fail 'artifacts directory already exists'

patrol="$HOME/.pub-cache/bin/patrol"
[[ -x "$patrol" ]] || fail 'Patrol CLI is not executable in the Dart pub cache'
command -v xcrun >/dev/null 2>&1 || fail 'xcrun is required'
command -v xcodebuild >/dev/null 2>&1 || fail 'xcodebuild is required'
command -v find >/dev/null 2>&1 || fail 'find is required'
command -v shasum >/dev/null 2>&1 || fail 'shasum is required'
if ! xcrun simctl list devices booted | grep -Fq -- "$device"; then
  fail 'requested iOS Simulator is not booted'
fi

mkdir -p -- "$artifacts_abs"
chmod 700 "$artifacts_abs"
private_dir=$(mktemp -d "${TMPDIR:-/tmp}/mint-coach01.XXXXXX")
raw_log="$private_dir/patrol.raw.log"
private_screenshot="$private_dir/final.png"
sanitized_log="$artifacts_abs/patrol.log"
final_screenshot="$artifacts_abs/final.png"
metadata="$artifacts_abs/metadata.json"
bundle_cleanup_armed=true
patrol_pid=''
external_root=''
external_build=''
build_isolation_armed=false
original_build_present=false
visual_marker_name='mint-g1-coach01-visual-ready-v1.marker'
visual_marker_payload='MINT_G1_COACH01_VISUAL_READY_V1'
app_container=''
visual_marker=''

remove_generated_bundle() {
  if [[ "$bundle_cleanup_armed" != true ]]; then
    return 0
  fi
  if [[ -e "$generated_bundle" || -L "$generated_bundle" ]]; then
    [[ -f "$generated_bundle" && ! -L "$generated_bundle" ]] || return 1
    rm -f -- "$generated_bundle" || return 1
  fi
  bundle_cleanup_armed=false
}

resolve_app_container() {
  local candidate=''
  local validated=''
  if ! candidate=$(xcrun simctl get_app_container \
    "$device" "$bundle_id" data 2>>"$raw_log"); then
    return 1
  fi
  validated=$(python3 - "$candidate" "$device" <<'PY'
import pathlib
import re
import sys

candidate = pathlib.Path(sys.argv[1])
device = sys.argv[2]
try:
    resolved = candidate.resolve(strict=True)
except (OSError, RuntimeError):
    raise SystemExit(1)
expected = (
    "Library",
    "Developer",
    "CoreSimulator",
    "Devices",
    device,
    "data",
    "Containers",
    "Data",
    "Application",
)
parts = resolved.parts
if not candidate.is_absolute() or candidate != resolved or not resolved.is_dir():
    raise SystemExit(1)
if len(parts) < 10 or tuple(parts[-10:-1]) != expected:
    raise SystemExit(1)
if re.fullmatch(
    r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
    parts[-1],
) is None:
    raise SystemExit(1)
temp_directory = resolved / "tmp"
try:
    resolved_temp = temp_directory.resolve(strict=True)
except (OSError, RuntimeError):
    raise SystemExit(1)
if resolved_temp != temp_directory or not resolved_temp.is_dir():
    raise SystemExit(1)
print(resolved)
PY
  ) || return 2
  app_container=$validated
  visual_marker="$app_container/tmp/$visual_marker_name"
}

validate_visual_marker() {
  [[ -n "$visual_marker" && -f "$visual_marker" && ! -L "$visual_marker" ]] \
    || return 1
  python3 - "$visual_marker" "$visual_marker_payload" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
expected = (sys.argv[2] + "\n").encode()
try:
    payload = path.read_bytes()
except OSError:
    raise SystemExit(1)
raise SystemExit(0 if payload == expected else 1)
PY
}

remove_visual_marker() {
  if [[ -z "$visual_marker" \
    || (! -e "$visual_marker" && ! -L "$visual_marker") ]]; then
    return 0
  fi
  validate_visual_marker || return 1
  rm -- "$visual_marker"
}

cleanup_visual_marker() {
  if [[ -z "$visual_marker" \
    || (! -e "$visual_marker" && ! -L "$visual_marker") ]]; then
    return 0
  fi
  [[ -f "$visual_marker" && ! -L "$visual_marker" ]] || return 1
  rm -- "$visual_marker"
}

prepare_visual_handshake() {
  local container_status=0
  if resolve_app_container; then
    remove_visual_marker
    return
  else
    container_status=$?
  fi
  if ((container_status == 1)); then
    app_container=''
    visual_marker=''
    return 0
  fi
  return 1
}

wait_for_visual_marker() {
  local deadline=$((SECONDS + 120))
  local container_status=0
  while ((SECONDS <= deadline)); do
    if resolve_app_container; then
      if [[ -e "$visual_marker" || -L "$visual_marker" ]]; then
        validate_visual_marker || return 2
        kill -0 "$patrol_pid" 2>/dev/null || return 1
        return 0
      fi
    else
      container_status=$?
      ((container_status == 1)) || return 2
    fi
    kill -0 "$patrol_pid" 2>/dev/null || return 1
    sleep 0.1
  done
  return 3
}

restore_build_isolation() {
  if [[ "$build_isolation_armed" != true ]]; then
    return 0
  fi

  local failed=0
  local current_target=''
  if [[ -L "$mobile_build" ]]; then
    current_target=$(readlink "$mobile_build") || failed=1
    if [[ "$current_target" == "$external_build" ]]; then
      if ! rm -- "$mobile_build"; then
        printf 'patrol_coach01_inline_amount: external build symlink cleanup failed\n' >&2
        failed=1
      fi
    else
      printf 'patrol_coach01_inline_amount: build symlink target drifted\n' >&2
      failed=1
    fi
  elif [[ -e "$mobile_build" ]]; then
    if [[ "$original_build_present" != true \
      || -e "$build_backup" || -L "$build_backup" ]]; then
      printf 'patrol_coach01_inline_amount: build path changed during isolation\n' >&2
      failed=1
    fi
  fi

  if [[ "$original_build_present" == true ]]; then
    if [[ ! -e "$mobile_build" && ! -L "$mobile_build" \
      && -d "$build_backup" && ! -L "$build_backup" ]]; then
      if ! mv -- "$build_backup" "$mobile_build"; then
        printf 'patrol_coach01_inline_amount: original build restoration failed\n' >&2
        failed=1
      fi
    elif [[ ! -d "$mobile_build" || -L "$mobile_build" \
      || -e "$build_backup" || -L "$build_backup" ]]; then
      printf 'patrol_coach01_inline_amount: original build restoration is ambiguous\n' >&2
      failed=1
    fi
  elif [[ -e "$mobile_build" || -L "$mobile_build" \
    || -e "$build_backup" || -L "$build_backup" ]]; then
    printf 'patrol_coach01_inline_amount: isolated build cleanup is ambiguous\n' >&2
    failed=1
  fi

  if [[ -n "$external_root" ]]; then
    if [[ -d "$external_root" && ! -L "$external_root" ]]; then
      if ! rm -rf -- "$external_root"; then
        printf 'patrol_coach01_inline_amount: external build removal failed\n' >&2
        failed=1
      fi
    elif [[ -e "$external_root" || -L "$external_root" ]]; then
      printf 'patrol_coach01_inline_amount: external build root is ambiguous\n' >&2
      failed=1
    fi
  fi

  if ((failed != 0)); then
    return 1
  fi
  build_isolation_armed=false
}

prepare_build_isolation() {
  mkdir -p -- "$mobile/.dart_tool" || return 1
  external_root=$(mktemp -d "${TMPDIR:-/tmp}/mint-coach01-build.XXXXXX") \
    || return 1
  build_isolation_armed=true
  external_root=$(cd "$external_root" && pwd -P) || return 1
  case "$external_root" in
    "$repo" | "$repo"/*)
      printf 'patrol_coach01_inline_amount: external build root is inside the checkout\n' >&2
      return 1
      ;;
  esac
  external_build="$external_root/build"
  mkdir -p -- "$external_build" || return 1

  if [[ -d "$mobile_build" ]]; then
    original_build_present=true
    mv -- "$mobile_build" "$build_backup" || return 1
  fi
  ln -s -- "$external_build" "$mobile_build" || return 1
}

cleanup() {
  local exit_status=$?
  local cleanup_failed=0
  trap - EXIT HUP INT TERM
  if ! remove_generated_bundle; then
    cleanup_failed=1
  fi
  if ! cleanup_visual_marker; then
    cleanup_failed=1
  fi
  if ! restore_build_isolation; then
    cleanup_failed=1
  fi
  if ! rm -rf -- "$private_dir"; then
    cleanup_failed=1
  fi
  if ((exit_status == 0 && cleanup_failed != 0)); then
    exit_status=1
  fi
  exit "$exit_status"
}

handle_signal() {
  local exit_status=$1
  trap - HUP INT TERM
  if [[ -n "$patrol_pid" ]] && kill -0 "$patrol_pid" 2>/dev/null; then
    kill -TERM "$patrol_pid" 2>/dev/null || true
    wait "$patrol_pid" 2>/dev/null || true
    patrol_pid=''
  fi
  exit "$exit_status"
}

trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

sanitize_log() {
  python3 - \
    "$raw_log" \
    "$sanitized_log" \
    "$repo" \
    "$HOME" \
    "$private_dir" \
    "${TMPDIR:-/tmp}" \
    "$device" <<'PY'
import pathlib
import re
import sys

source, destination, repo, home, private_dir, temp_root, device = sys.argv[1:]
text = pathlib.Path(source).read_text(encoding="utf-8", errors="replace")
replacements = (
    (private_dir, "<TMP>"),
    (temp_root, "<TMP>"),
    (repo, "<REPO>"),
    (home, "<HOME>"),
    (device, "<DEVICE>"),
)
for raw, replacement in sorted(replacements, key=lambda item: len(item[0]), reverse=True):
    if raw:
        text = text.replace(raw, replacement)
text = re.sub(
    r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
    "<DEVICE>",
    text,
)
for forbidden in (repo, home, private_dir, temp_root, device):
    if forbidden and forbidden in text:
        raise SystemExit("sanitizer left a private runtime identifier")
pathlib.Path(destination).write_text(text, encoding="utf-8")
PY
  chmod 600 "$sanitized_log"
}

write_metadata() {
  local result=$1
  local log_hash=$2
  local screenshot_hash=${3:-}
  python3 - \
    "$metadata" \
    "$expected_sha" \
    "$bundle_id" \
    "$result" \
    "$log_hash" \
    "$screenshot_hash" <<'PY'
import json
import pathlib
import sys

path, sha, bundle, result, log_hash, screenshot_hash = sys.argv[1:]
payload = {
    "schemaVersion": 1,
    "caseId": "G1-COACH-01",
    "commitSha": sha,
    "bundleId": bundle,
    "patrolTarget": "test/patrol/g1_coach01_inline_amount_runtime_test.dart",
    "result": result,
    "device": "<redacted>",
    "logSha256": log_hash,
    "screenshotSha256": screenshot_hash or None,
}
pathlib.Path(path).write_text(
    json.dumps(payload, ensure_ascii=True, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  chmod 600 "$metadata"
}

verify_runtime_sources_clean() {
  [[ ! -e "$generated_bundle" && ! -L "$generated_bundle" ]] || return 1
  [[ "$(git -C "$repo" rev-parse HEAD)" == "$expected_sha" ]] || return 1
  git -C "$repo" diff --quiet "$expected_sha" -- \
    apps/mobile "${tracked_files[@]}" || return 1
  local untracked_mobile
  untracked_mobile=$(git -C "$repo" ls-files --others --exclude-standard -- apps/mobile) \
    || return 1
  [[ -z "$untracked_mobile" ]]
}

xctestrun=''
inspect_patrol_build() {
  local products="$external_build/ios_integ/Build/Products"
  local runner_app="$products/Debug-iphonesimulator/Runner.app"
  local asset_manifest=
  local -a xctestruns=()

  if [[ ! -d "$runner_app" || -L "$runner_app" ]]; then
    printf 'Patrol build inspection: Runner.app is missing or ambiguous\n' \
      >>"$raw_log"
    return 1
  fi
  asset_manifest="$runner_app/Frameworks/App.framework/flutter_assets/AssetManifest.bin"
  if [[ ! -s "$asset_manifest" || -L "$asset_manifest" ]]; then
    printf 'Patrol build inspection: AssetManifest.bin is missing or empty\n' \
      >>"$raw_log"
    return 1
  fi
  while IFS= read -r candidate; do
    xctestruns+=("$candidate")
  done < <(
    find "$products" -maxdepth 2 -type f -name '*.xctestrun' -print \
      2>/dev/null
  )
  if ((${#xctestruns[@]} != 1)); then
    printf 'Patrol build inspection: expected exactly one xctestrun, found %s\n' \
      "${#xctestruns[@]}" >>"$raw_log"
    return 1
  fi
  xctestrun=${xctestruns[0]}
}

if ! prepare_build_isolation; then
  fail 'external build isolation setup failed'
fi

set +e
(
  cd "$mobile"
  exec "$patrol" --verbose build ios \
    --target test/patrol/g1_coach01_inline_amount_runtime_test.dart \
    --simulator \
    --bundle-id "$bundle_id" \
    --dart-define=MINT_PATROL_CLI=true
) >"$raw_log" 2>&1 &
patrol_pid=$!
wait "$patrol_pid"
runtime_status=$?
patrol_pid=''
set -e

if ((runtime_status == 0)); then
  if ! inspect_patrol_build; then
    runtime_status=2
  else
    result_bundle="$external_build/coach01.xcresult"
    if [[ -e "$result_bundle" || -L "$result_bundle" ]]; then
      printf 'xcodebuild result bundle path already exists\n' >>"$raw_log"
      runtime_status=2
    elif ! prepare_visual_handshake; then
      printf 'visual handshake stale-marker cleanup failed\n' >>"$raw_log"
      runtime_status=2
    else
      set +e
      (
        cd "$mobile"
        exec xcodebuild test-without-building \
          -xctestrun "$xctestrun" \
          -only-testing 'RunnerUITests/RunnerUITests' \
          -destination "platform=iOS Simulator,id=$device" \
          -resultBundlePath "$result_bundle"
      ) >>"$raw_log" 2>&1 &
      patrol_pid=$!
      set -e

      set +e
      wait_for_visual_marker
      visual_wait_status=$?
      set -e
      screenshot_status=0
      xcode_killed_for_handshake=false
      if ((visual_wait_status == 0)); then
        set +e
        xcrun simctl io "$device" screenshot "$private_screenshot" \
          >>"$raw_log" 2>&1
        screenshot_status=$?
        set -e
        if ((screenshot_status != 0)) || [[ ! -s "$private_screenshot" ]]; then
          printf 'visual handshake screenshot failed\n' >>"$raw_log"
          screenshot_status=2
        fi
        if ! remove_visual_marker; then
          printf 'visual handshake marker acknowledgement failed\n' >>"$raw_log"
          screenshot_status=2
          kill -TERM "$patrol_pid" 2>/dev/null || true
          xcode_killed_for_handshake=true
        fi
      else
        printf 'visual handshake marker was not observed while XCTest ran\n' \
          >>"$raw_log"
        if kill -0 "$patrol_pid" 2>/dev/null; then
          kill -TERM "$patrol_pid" 2>/dev/null || true
          xcode_killed_for_handshake=true
        fi
      fi

      set +e
      wait "$patrol_pid"
      xcode_status=$?
      set -e
      patrol_pid=''
      if [[ "$xcode_killed_for_handshake" == true ]]; then
        runtime_status=2
      elif ((xcode_status != 0)); then
        runtime_status=$xcode_status
      elif ((visual_wait_status != 0 || screenshot_status != 0)); then
        runtime_status=2
      else
        runtime_status=0
      fi
      if ((runtime_status == 0)) && [[ ! -d "$result_bundle" ]]; then
        printf 'xcodebuild did not produce its result bundle\n' >>"$raw_log"
        runtime_status=2
      fi
    fi
  fi
fi

if ! remove_generated_bundle; then
  sanitize_log
  log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
  write_metadata 'failed' "$log_hash"
  fail 'generated Patrol bundle cleanup failed'
fi
if ! restore_build_isolation; then
  sanitize_log
  log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
  write_metadata 'failed' "$log_hash"
  fail 'external build restoration failed'
fi
if ! verify_runtime_sources_clean; then
  sanitize_log
  log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
  write_metadata 'failed' "$log_hash"
  fail 'runtime sources are not clean after Patrol execution'
fi

if ((runtime_status != 0)); then
  sanitize_log
  log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
  write_metadata 'failed' "$log_hash"
  exit "$runtime_status"
fi

sanitize_log
log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
if [[ ! -s "$private_screenshot" ]]; then
  write_metadata 'failed' "$log_hash"
  fail 'in-test simulator screenshot is missing'
fi

python3 - \
  "$private_screenshot" \
  "$repo" \
  "$HOME" \
  "$private_dir" \
  "${TMPDIR:-/tmp}" \
  "$device" <<'PY'
import pathlib
import sys

path, *forbidden = sys.argv[1:]
payload = pathlib.Path(path).read_bytes()
for value in forbidden:
    if value and value.encode() in payload:
        raise SystemExit("screenshot contains a private runtime identifier")
PY
install -m 600 "$private_screenshot" "$final_screenshot"
screenshot_hash=$(shasum -a 256 "$final_screenshot" | awk '{print $1}')
if ! verify_runtime_sources_clean; then
  write_metadata 'failed' "$log_hash" "$screenshot_hash"
  fail 'runtime contract SHA changed during Patrol execution'
fi
write_metadata 'passed' "$log_hash" "$screenshot_hash"

printf 'G1-COACH-01 Patrol evidence written.\n'
