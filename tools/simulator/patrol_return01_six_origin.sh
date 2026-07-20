#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
  cat >&2 <<'USAGE'
Usage: patrol_return01_six_origin.sh \
  --device <booted-simulator-udid> \
  --bundle-id ch.mint.app \
  --sha <exact-40-char-pushed-HEAD> \
  --artifacts <repo>/.planning/runtime-evidence/phase-37/return-01/runtime-<shortsha>-<UTC>
USAGE
}

die() {
  printf 'patrol_return01_six_origin: %s\n' "$1" >&2
  exit 2
}

device=''
bundle_id=''
expected_sha=''
artifacts=''
while (($#)); do
  case "$1" in
    --device)
      (($# >= 2)) || die 'missing --device value'
      device=$2
      shift 2
      ;;
    --bundle-id)
      (($# >= 2)) || die 'missing --bundle-id value'
      bundle_id=$2
      shift 2
      ;;
    --sha)
      (($# >= 2)) || die 'missing --sha value'
      expected_sha=$2
      shift 2
      ;;
    --artifacts)
      (($# >= 2)) || die 'missing --artifacts value'
      artifacts=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      die 'unknown argument'
      ;;
  esac
done

[[ "$device" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
  || die 'device must be an iOS Simulator UDID'
[[ "$bundle_id" == 'ch.mint.app' ]] || die 'unexpected iOS bundle id'
[[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]] \
  || die 'sha must be 40 lowercase hex characters'
[[ -n "$artifacts" ]] || die 'artifacts path is required'

repo=$(git rev-parse --show-toplevel 2>/dev/null) || die 'not inside a git checkout'
head_sha=$(git -C "$repo" rev-parse HEAD)
[[ "$head_sha" == "$expected_sha" ]] || die 'requested sha is not current HEAD'
upstream_sha=$(git -C "$repo" rev-parse '@{upstream}' 2>/dev/null) \
  || die 'configured upstream is required'
[[ "$head_sha" == "$upstream_sha" ]] || die 'HEAD must equal its configured upstream'
[[ -z "$(git -C "$repo" status --porcelain --untracked-files=all)" ]] \
  || die 'HEAD must be clean before runtime evidence'

patrol="$HOME/.pub-cache/bin/patrol"
rvc_runner="$repo/tools/simulator/patrol_return01_rvc_lpp_scan_return.sh"
maestro_runner="$repo/tools/simulator/maestro_with_watchdog.sh"

integration_target='apps/mobile/integration_test/g1_return01_six_origin_patrol_test.dart'
patrol_wrapper='apps/mobile/test/patrol/g1_return01_six_origin_runtime_test.dart'
runtime_contract='apps/mobile/test/runtime/g1_return01_six_origin_runtime_test.dart'

maestro_flow_for_stage() {
  case "${1:-}" in
    work_save) printf '%s\n' 'apps/mobile/.maestro/g1_return01_work_return.yaml' ;;
    housing_cancel) printf '%s\n' 'apps/mobile/.maestro/g1_return01_housing_cancel_return.yaml' ;;
    disability_validation_cancel) printf '%s\n' 'apps/mobile/.maestro/g1_return01_disability_return.yaml' ;;
    succession_save) printf '%s\n' 'apps/mobile/.maestro/g1_return01_succession_return.yaml' ;;
    frontalier_inline) printf '%s\n' 'apps/mobile/.maestro/g1_return01_frontalier_inline.yaml' ;;
    *) return 2 ;;
  esac
}

witness_name_for_stage() {
  case "${1:-}" in
    work_save) printf '%s\n' 'mint-g1-return01-work_save-witness-v1.json' ;;
    housing_cancel) printf '%s\n' 'mint-g1-return01-housing_cancel-witness-v1.json' ;;
    disability_validation_cancel) printf '%s\n' 'mint-g1-return01-disability_validation_cancel-witness-v1.json' ;;
    succession_save) printf '%s\n' 'mint-g1-return01-succession_save-witness-v1.json' ;;
    frontalier_inline) printf '%s\n' 'mint-g1-return01-frontalier_inline-witness-v1.json' ;;
    *) return 2 ;;
  esac
}

final_anchor_for_stage() {
  case "${1:-}" in
    work_save) printf '%s\n' 'first_job_salary_authority' ;;
    housing_cancel) printf '%s\n' 'mortgage_enrich_profile_cta' ;;
    disability_validation_cancel) printf '%s\n' 'disability_gap_ledger_facts' ;;
    succession_save) printf '%s\n' 'succession_mortgage_missing' ;;
    frontalier_inline) printf '%s\n' 'frontier_jurisdiction_known_state' ;;
    *) return 2 ;;
  esac
}

tracked_files=(
  "$integration_target"
  "$patrol_wrapper"
  "$runtime_contract"
  "$(maestro_flow_for_stage work_save)"
  "$(maestro_flow_for_stage housing_cancel)"
  "$(maestro_flow_for_stage disability_validation_cancel)"
  "$(maestro_flow_for_stage succession_save)"
  "$(maestro_flow_for_stage frontalier_inline)"
  'tools/simulator/patrol_return01_rvc_lpp_scan_return.sh'
  'tools/simulator/patrol_return01_six_origin.sh'
  'tools/simulator/maestro_with_watchdog.sh'
  'tools/checks/mint_os_doctor.py'
  'tools/checks/patrol_tooling_guard.py'
)
for relative in "${tracked_files[@]}"; do
  git -C "$repo" ls-files --error-unmatch -- "$relative" >/dev/null 2>&1 \
    || die 'runtime contract files must be tracked at HEAD'
done
git -C "$repo" diff --quiet "$expected_sha" -- "${tracked_files[@]}" \
  || die 'runtime contract files differ from the requested SHA'

artifacts=$(python3 - "$artifacts" "$repo" "$expected_sha" <<'PY'
import datetime
import pathlib
import re
import sys

candidate = pathlib.Path(sys.argv[1]).resolve(strict=False)
repo = pathlib.Path(sys.argv[2]).resolve(strict=True)
sha = sys.argv[3]
parent = repo / ".planning/runtime-evidence/phase-37/return-01"
if candidate.parent != parent:
    raise SystemExit("artifacts must be directly under phase-37/return-01")
match = re.fullmatch(rf"runtime-{re.escape(sha[:10])}-(\d{{8}}T\d{{6}}Z)", candidate.name)
if match is None:
    raise SystemExit("artifacts must match runtime-<shortsha>-<UTC>")
datetime.datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ")
print(candidate)
PY
) || die 'invalid RETURN-01 artifacts path'
[[ ! -e "$artifacts" && ! -L "$artifacts" ]] \
  || die 'artifacts directory already exists'

for command_name in git python3 tar find shasum xcrun xcodebuild flutter codesign xattr; do
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required"
done
[[ -x "$patrol" ]] || die 'Patrol CLI is not executable in the Dart pub cache'
[[ -x "$rvc_runner" ]] || die 'RVC runtime runner is not executable'
[[ -x "$maestro_runner" ]] || die 'Maestro watchdog is not executable'
xcrun simctl list devices booted | grep -Fq -- "$device" \
  || die 'requested iOS Simulator is not booted'

mkdir -p -- "$artifacts"
chmod 700 "$artifacts"
private_root=$(mktemp -d "${TMPDIR:-/tmp}/mint-return01-six.XXXXXX")
source_root="$private_root/source"
normal_app=''
first_job_app=''
cleanup_status='pending'
restoration_status='pending'

sanitize_log() {
  local source=$1
  local destination=$2
  python3 - "$source" "$destination" "$repo" "$HOME" "$private_root" "${TMPDIR:-/tmp}" "$device" <<'PY'
import pathlib
import re
import sys

source, destination, repo, home, private_root, temp_root, device = sys.argv[1:]
text = pathlib.Path(source).read_text(encoding="utf-8", errors="replace")
replacements = sorted(
    ((repo, "REDACTED_REPO"), (home, "REDACTED_HOME"),
     (private_root, "REDACTED_PRIVATE_TEMP"), (temp_root, "REDACTED_PRIVATE_TEMP"),
     (device, "REDACTED_SIMULATOR_UDID")),
    key=lambda item: len(item[0]), reverse=True,
)
for raw, marker in replacements:
    if raw:
        text = text.replace(raw, marker)
text = re.sub(
    r"(?i)(?:[0-9a-f]{8}-){1}[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
    "REDACTED_RUNTIME_UUID", text,
)
pathlib.Path(destination).write_text(text, encoding="utf-8")
PY
  chmod 600 "$destination"
}

verify_runtime_sources_clean() {
  local current_head current_upstream
  current_head=$(git -C "$repo" rev-parse HEAD) || return 1
  current_upstream=$(git -C "$repo" rev-parse '@{upstream}') || return 1
  [[ "$current_head" == "$expected_sha" && "$current_upstream" == "$expected_sha" ]] \
    || { printf 'HEAD/upstream changed during runtime evidence\n' >&2; return 1; }
  [[ -z "$(git -C "$repo" status --porcelain --untracked-files=all)" ]]
}

restore_normal_build() {
  [[ -n "$normal_app" && -d "$normal_app" && ! -L "$normal_app" ]] || return 1
  xcrun simctl terminate "$device" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$device" "$normal_app" \
    >"$private_root/restoration-install.raw.log" 2>&1 || return 1
  xcrun simctl launch "$device" "$bundle_id" \
    >"$private_root/restoration-launch.raw.log" 2>&1 || return 1
  sanitize_log "$private_root/restoration-install.raw.log" "$artifacts/restoration-install.log"
  sanitize_log "$private_root/restoration-launch.raw.log" "$artifacts/restoration-launch.log"
  restoration_status='restored'
}

cleanup() {
  local status=$?
  local cleanup_failed=0
  if [[ "$restoration_status" != 'restored' && -n "$normal_app" \
    && -d "$normal_app" && ! -L "$normal_app" ]]; then
    restore_normal_build || cleanup_failed=1
  fi
  if [[ -d "$private_root" && ! -L "$private_root" ]]; then
    rm -rf -- "$private_root" || cleanup_failed=1
  else
    cleanup_failed=1
  fi
  if ((cleanup_failed == 0)); then
    cleanup_status='passed'
  else
    cleanup_status='failed'
  fi
  if ((status == 0 && cleanup_failed != 0)); then
    status=2
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

export_physical_source() {
  mkdir -p "$source_root"
  (
    cd "$repo"
    git archive --format=tar "$expected_sha"
  ) >"$private_root/source.tar" 2>"$private_root/production-export.raw.log"
  tar -xf "$private_root/source.tar" -C "$source_root"
  git -C "$repo" ls-tree -r --full-tree "$expected_sha" \
    | shasum -a 256 >"$artifacts/source-manifest.sha256"
  sanitize_log "$private_root/production-export.raw.log" "$artifacts/production-export.log"
}

build_physical_source() {
  local built_app="$source_root/apps/mobile/build/ios/iphonesimulator/Runner.app"
  (
    cd "$source_root/apps/mobile"
    flutter pub get
    flutter build ios --simulator --debug
  ) >"$private_root/production-build.raw.log" 2>&1
  [[ -d "$built_app" && ! -L "$built_app" ]] || die 'physical production app missing'
  normal_app="$private_root/normal-production-app/Runner.app"
  mkdir -p "${normal_app%/*}"
  /usr/bin/ditto "$built_app" "$normal_app"
  [[ -d "$normal_app" && ! -L "$normal_app" ]] \
    || die 'immutable production app snapshot missing'

  (
    cd "$source_root/apps/mobile"
    flutter build ios --simulator --debug --dart-define=MINT_TEST_FIRST_JOB=true
  ) >>"$private_root/production-build.raw.log" 2>&1
  [[ -d "$built_app" && ! -L "$built_app" ]] \
    || die 'physical First Job proof app missing'
  first_job_app="$private_root/first-job-proof-app/Runner.app"
  mkdir -p "${first_job_app%/*}"
  /usr/bin/ditto "$built_app" "$first_job_app"
  [[ -d "$first_job_app" && ! -L "$first_job_app" ]] \
    || die 'immutable First Job proof app snapshot missing'

  sanitize_log "$private_root/production-build.raw.log" "$artifacts/production-build.log"
  {
    codesign --verify --deep --strict "$normal_app"
    codesign --verify --deep --strict "$first_job_app"
  } >"$private_root/production-codesign.raw.log" 2>&1
  {
    xattr -lr "$normal_app" || true
    xattr -lr "$first_job_app" || true
  } >"$private_root/production-xattrs.raw.log" 2>&1
  sanitize_log "$private_root/production-codesign.raw.log" "$artifacts/production-codesign.log"
  sanitize_log "$private_root/production-xattrs.raw.log" "$artifacts/production-xattrs.log"
  xcrun simctl uninstall "$device" "$bundle_id" \
    >"$private_root/production-uninstall.raw.log" 2>&1 || true
  xcrun simctl install "$device" "$normal_app" \
    >"$private_root/production-install.raw.log" 2>&1
  sanitize_log "$private_root/production-uninstall.raw.log" "$artifacts/production-uninstall.log"
  sanitize_log "$private_root/production-install.raw.log" "$artifacts/production-install.log"
}

capture_hierarchy() {
  local label=$1
  local anchor=$2
  local raw="$private_root/hierarchy-$label.raw.log"
  local private_home="$private_root/maestro-hierarchy-$label-java-home"
  local walker="$private_root/maestro-hierarchy-$label-walker"
  mkdir -p "$private_home" "$walker"
  MAESTRO_OPTS="-Duser.home=$private_home" \
    MINT_WALKER_ARTIFACTS="$walker" \
    bash "$maestro_runner" --udid "$device" hierarchy --compact >"$raw" 2>&1
  sanitize_log "$raw" "$artifacts/hierarchy-$label.log"
  [[ -s "$artifacts/hierarchy-$label.log" ]] || die "$label hierarchy is empty"
  grep -Fq -- "$anchor" "$artifacts/hierarchy-$label.log" \
    || die "$label hierarchy lacks strict anchor $anchor"
}

capture_screenshot() {
  local label=$1
  xcrun simctl io "$device" screenshot "$artifacts/$label.png" \
    >"$private_root/screenshot-$label.raw.log" 2>&1
  [[ -s "$artifacts/$label.png" && ! -L "$artifacts/$label.png" ]] \
    || die "$label screenshot is missing"
}

capture_failed_maestro_diagnostics() {
  local stage=$1
  local private_stage=$2
  local hierarchy_raw="$private_stage/failure-hierarchy.raw.log"

  if xcrun simctl io "$device" screenshot "$artifacts/maestro-$stage.png" \
    >"$private_stage/failure-screenshot.raw.log" 2>&1; then
    [[ -s "$artifacts/maestro-$stage.png" \
      && ! -L "$artifacts/maestro-$stage.png" ]] \
      || rm -f -- "$artifacts/maestro-$stage.png" || true
  else
    rm -f -- "$artifacts/maestro-$stage.png" || true
  fi

  if python3 - "$private_stage/debug-output" "$hierarchy_raw" \
    2>"$private_stage/failure-hierarchy-extract.raw.log" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve(strict=True)
destination = pathlib.Path(sys.argv[2])
for path in reversed(sorted(root.glob("commands-*.json"))):
    if path.is_symlink() or not path.is_file():
        continue
    resolved = path.resolve(strict=True)
    if resolved.parent != root:
        continue
    try:
        commands = json.loads(resolved.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        continue
    if not isinstance(commands, list):
        continue
    for command in reversed(commands):
        try:
            hierarchy = command["metadata"]["error"]["hierarchyRoot"]
        except (KeyError, TypeError):
            continue
        if not isinstance(hierarchy, (dict, list)):
            continue
        destination.write_text(
            json.dumps(hierarchy, ensure_ascii=False, separators=(",", ":"), sort_keys=True),
            encoding="utf-8",
        )
        raise SystemExit(0)
raise SystemExit(1)
PY
  then
    if sanitize_log "$hierarchy_raw" "$artifacts/hierarchy-maestro-$stage.log"; then
      [[ -s "$artifacts/hierarchy-maestro-$stage.log" \
        && ! -L "$artifacts/hierarchy-maestro-$stage.log" ]] \
        || rm -f -- "$artifacts/hierarchy-maestro-$stage.log" || true
    else
      rm -f -- "$artifacts/hierarchy-maestro-$stage.log" || true
    fi
  else
    rm -f -- "$artifacts/hierarchy-maestro-$stage.log" || true
  fi
  return 0
}

fingerprint_persistent_app_data() {
  local container=$1
  python3 - "$container" <<'PY'
import hashlib
import os
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve(strict=True)
if not root.is_dir():
    raise SystemExit("app data container is not a directory")
digest = hashlib.sha256()
file_count = 0
byte_count = 0
for relative_root in (pathlib.Path("Documents"), pathlib.Path("Library/Preferences")):
    selected = root / relative_root
    if not selected.exists():
        continue
    if selected.is_symlink() or not selected.is_dir():
        raise SystemExit(f"invalid persistent data root: {relative_root}")
    for directory, names, files in os.walk(selected, followlinks=False):
        names.sort()
        directory_path = pathlib.Path(directory)
        if any((directory_path / name).is_symlink() for name in names):
            raise SystemExit("persistent data contains a directory symlink")
        for name in sorted(files):
            path = directory_path / name
            if path.is_symlink() or not path.is_file():
                raise SystemExit("persistent data contains a non-regular file")
            relative = path.relative_to(root).as_posix().encode("utf-8")
            digest.update(len(relative).to_bytes(8, "big"))
            digest.update(relative)
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    byte_count += len(chunk)
                    digest.update(chunk)
            file_count += 1
if file_count < 1 or byte_count < 1:
    raise SystemExit("persistent app data is empty")
print(f"{file_count}:{byte_count}:{digest.hexdigest()}")
PY
}

run_maestro_stage() {
  local stage=$1
  local flow=''
  local anchor=''
  flow=$(maestro_flow_for_stage "$stage") || die "unknown Maestro stage $stage"
  anchor=$(final_anchor_for_stage "$stage") || die "unknown Maestro stage $stage"
  local private_stage="$private_root/maestro-$stage"
  local container_before=''
  local container_after=''
  local data_before=''
  local data_after=''
  local synthetic_seed='reset'
  local container_identity='reset'
  local persistent_data='not_applicable'
  local overlay_app=$normal_app
  mkdir -p "$private_stage"
  case "$stage" in
    work_save)
      overlay_app=$first_job_app
      [[ -d "$overlay_app" && ! -L "$overlay_app" ]] \
        || die 'First Job Maestro proof app is invalid'
      xcrun simctl uninstall "$device" "$bundle_id" >/dev/null 2>&1 || true
      ;;
    disability_validation_cancel | succession_save)
      # These black-box flows own their synthetic save from an empty install.
      xcrun simctl uninstall "$device" "$bundle_id" >/dev/null 2>&1 || true
      ;;
    housing_cancel | frontalier_inline)
      # Preserve the integration-test-created synthetic seed while replacing
      # the test host with the physically exported normal application.
      container_before=$(resolve_app_container) \
        || die "$stage pre-overlay app container is invalid"
      data_before=$(fingerprint_persistent_app_data "$container_before") \
        || die "$stage pre-overlay persistent app data is invalid"
      synthetic_seed='preserved'
      ;;
    *)
      die "unknown Maestro stage $stage"
      ;;
  esac
  xcrun simctl install "$device" "$overlay_app" >/dev/null
  if [[ -n "$container_before" ]]; then
    container_after=$(resolve_app_container) \
      || die "$stage post-overlay app container is invalid"
    data_after=$(fingerprint_persistent_app_data "$container_after") \
      || die "$stage post-overlay persistent app data is invalid"
    if [[ "$container_before" == "$container_after" ]]; then
      container_identity='preserved'
    else
      container_identity='relocated'
    fi
    [[ "$data_before" == "$data_after" ]] \
      || die "$stage production overlay changed persistent app data"
    persistent_data='verified'
  fi
  printf 'stage=%s production_overlay=verified synthetic_seed=%s container_identity=%s persistent_data=%s\n' \
    "$stage" "$synthetic_seed" \
    "$container_identity" "$persistent_data" \
    >"$artifacts/production-overlay-$stage.log"
  local maestro_status=0
  local junit_retained=false
  set +e
  (
    cd "$source_root"
    MINT_WALKER_ARTIFACTS="$private_stage" \
      bash tools/simulator/maestro_with_watchdog.sh test \
        --device "$device" --format JUNIT \
        --test-output-dir "$private_stage/test-output" \
        --debug-output "$private_stage/debug-output" \
        --flatten-debug-output \
        --output "$private_stage/report.xml" "$flow"
  ) >"$private_stage/maestro.raw.log" 2>&1
  maestro_status=$?
  set -e
  [[ -f "$private_stage/maestro.raw.log" \
    && ! -L "$private_stage/maestro.raw.log" ]] \
    || die "Maestro stage $stage produced an invalid raw log"
  sanitize_log "$private_stage/maestro.raw.log" "$artifacts/maestro-$stage.log"
  if [[ -e "$private_stage/report.xml" || -L "$private_stage/report.xml" ]]; then
    [[ -f "$private_stage/report.xml" && ! -L "$private_stage/report.xml" ]] \
      || die "Maestro stage $stage produced an invalid JUnit artifact"
    sanitize_log "$private_stage/report.xml" \
      "$artifacts/maestro-$stage-report.sanitized.xml"
    junit_retained=true
  fi
  if ((maestro_status != 0)); then
    capture_failed_maestro_diagnostics "$stage" "$private_stage" || true
    die "Maestro stage $stage failed with exit $maestro_status; sanitized log retained"
  fi
  [[ "$junit_retained" == true ]] \
    || die "Maestro stage $stage passed without a JUnit artifact"
  python3 - "$artifacts/maestro-$stage-report.sanitized.xml" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET

root = ET.fromstring(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
if not suites:
    raise SystemExit("Maestro JUnit has no testsuite")
tests = sum(int(s.attrib.get("tests", "0")) for s in suites)
failures = sum(int(s.attrib.get("failures", "0")) for s in suites)
errors = sum(int(s.attrib.get("errors", "0")) for s in suites)
if tests < 1 or failures != 0 or errors != 0:
    raise SystemExit("Maestro JUnit is not a clean pass")
PY
  capture_hierarchy "maestro-$stage" "$anchor"
  capture_screenshot "maestro-$stage"
}

resolve_app_container() {
  local container
  container=$(xcrun simctl get_app_container "$device" "$bundle_id" data) || return 1
  python3 - "$container" "$device" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1]).resolve(strict=True)
device = sys.argv[2]
parts = path.parts
if not path.is_dir() or device not in parts:
    raise SystemExit(1)
if re.fullmatch(
    r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
    parts[-1],
) is None:
    raise SystemExit(1)
print(path)
PY
}

validate_stage_witness() {
  local stage=$1
  local source_witness=$2
  local retained_witness=$3
  python3 - "$source_witness" "$retained_witness" "$stage" "$expected_sha" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
stage, sha = sys.argv[3], sys.argv[4]
data = json.loads(path.read_text(encoding="utf-8"))
origins = {
    "work_save": "/first-job",
    "housing_cancel": "/hypotheque",
    "disability_validation_cancel": "/invalidite",
    "succession_save": "/succession",
    "frontalier_inline": "/segments/frontalier",
}
required = {
    "schemaVersion", "caseId", "stage", "sourceSha", "syntheticDataOnly", "routeBefore",
    "routeAfter", "collectorRouteVerified", "routeAfterVerified",
    "storeWriteVerified", "storeUnchangedVerified", "validationRetainedVerified",
    "noDataBlockVerified", "frontalierCanonicalWritesVerified",
}
if set(data) != required:
    raise SystemExit(f"unexpected witness keys: {sorted(set(data) ^ required)}")
if data["schemaVersion"] != 1 or isinstance(data["schemaVersion"], bool):
    raise SystemExit("wrong witness schema")
if data["caseId"] != "G1-RETURN-01" or data["stage"] != stage:
    raise SystemExit("wrong case or stage")
if data["sourceSha"] != sha or data["syntheticDataOnly"] is not True:
    raise SystemExit("wrong source or data class")
if data["routeBefore"] != origins[stage] or data["routeAfter"] != origins[stage]:
    raise SystemExit("route witness mismatch")
if data["routeAfterVerified"] is not True:
    raise SystemExit("route-after witness missing")
expected_true = {
    "work_save": {"collectorRouteVerified", "storeWriteVerified"},
    "housing_cancel": {"collectorRouteVerified", "storeUnchangedVerified"},
    "disability_validation_cancel": {
        "collectorRouteVerified", "storeUnchangedVerified", "validationRetainedVerified"
    },
    "succession_save": {"collectorRouteVerified", "storeWriteVerified"},
    "frontalier_inline": {"noDataBlockVerified", "frontalierCanonicalWritesVerified"},
}[stage]
for key in expected_true:
    if data[key] is not True:
        raise SystemExit(f"missing stage truth: {key}")
boolean_keys = {
    "collectorRouteVerified", "routeAfterVerified", "storeWriteVerified",
    "storeUnchangedVerified", "validationRetainedVerified", "noDataBlockVerified",
    "frontalierCanonicalWritesVerified",
}
if any(not isinstance(data[key], bool) for key in boolean_keys | {"syntheticDataOnly"}):
    raise SystemExit("witness truth fields must be real booleans")
expected_false = boolean_keys - expected_true - {"routeAfterVerified"}
for key in expected_false:
    if data[key] is not False:
        raise SystemExit(f"non-applicable witness truth must be false: {key}")
destination.write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
PY
  chmod 600 "$retained_witness"
}

archive_xcresult_summary() {
  local stage=$1
  local xcresult
  xcresult=$(find "$source_root/apps/mobile/build" -type d -name '*.xcresult' -print \
    | sort | tail -1)
  [[ -n "$xcresult" ]] || die "$stage xcresult is missing"
  xcrun xcresulttool get test-results summary --path "$xcresult" \
    >"$private_root/xcresult-$stage.raw.json" 2>"$private_root/xcresult-$stage.raw.log"
  sanitize_log "$private_root/xcresult-$stage.raw.json" \
    "$artifacts/patrol-$stage-xcresult-summary.sanitized.json"
}

run_patrol_stage() {
  local stage=$1
  local raw="$private_root/patrol-$stage.raw.log"
  local patrol_status=0
  local app_container witness_source witness_name
  # Bash 3.2 + `set -u` treats an empty-array expansion as unbound. Keep one
  # explicit false value for non-First-Job stages and replace it only for the
  # bounded work proof.
  local -a first_job_define=(--dart-define=MINT_TEST_FIRST_JOB=false)
  witness_name=$(witness_name_for_stage "$stage") \
    || die "unknown Patrol stage $stage"
  case "$stage" in
    work_save) first_job_define=(--dart-define=MINT_TEST_FIRST_JOB=true) ;;
  esac
  set +e
  (
    cd "$source_root/apps/mobile"
    MINT_G1_RETURN01_STAGE="$stage" \
      "$patrol" test -t "test/patrol/g1_return01_six_origin_runtime_test.dart" \
        --no-uninstall --device "$device" \
        --dart-define=MINT_PATROL_CLI=true \
        "${first_job_define[@]}" \
        --dart-define=MINT_G1_RETURN01_STAGE="$stage" \
        --dart-define=MINT_G1_RETURN01_SOURCE_SHA="$expected_sha"
  ) >"$raw" 2>&1
  patrol_status=$?
  set -e
  sanitize_log "$raw" "$artifacts/patrol-$stage.log"
  if ((patrol_status != 0)); then
    if ! (
      set -e
      archive_xcresult_summary "$stage"
    ); then
      rm -f -- "$artifacts/patrol-$stage-xcresult-summary.sanitized.json" || true
    fi
    die "Patrol stage $stage failed with exit $patrol_status; sanitized log retained"
  fi
  archive_xcresult_summary "$stage"
  app_container=$(resolve_app_container) || die "$stage app container is invalid"
  witness_source="$app_container/tmp/$witness_name"
  [[ -s "$witness_source" && ! -L "$witness_source" ]] \
    || die "$stage strict witness is missing"
  validate_stage_witness "$stage" "$witness_source" "$artifacts/witness-$stage.json"
  rm -f -- "$witness_source"
}

validate_rvc_metadata() {
  local metadata=$1
  python3 - "$metadata" "$expected_sha" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
sha = data.get("sourceSha", data.get("commitSha"))
if sha != sys.argv[2]:
    raise SystemExit("RVC source SHA mismatch")
if data.get("patrolResult") != "passed" or data.get("maestroResult") != "passed":
    raise SystemExit("RVC stage did not pass both runners")
PY
}

run_rvc_stage() {
  local timestamp=${artifacts##*-}
  timestamp=${timestamp%Z}Z
  local rvc_artifacts="$repo/.planning/runtime-evidence/phase-37/return-01-rvc/runtime-${expected_sha:0:10}-$timestamp"
  local rvc_status=0
  set +e
  bash "$rvc_runner" --device "$device" --bundle-id "$bundle_id" \
    --sha "$expected_sha" --artifacts "$rvc_artifacts" \
    >"$private_root/rvc-runner.raw.log" 2>&1
  rvc_status=$?
  set -e
  sanitize_log "$private_root/rvc-runner.raw.log" "$artifacts/rvc-runner.log"
  if ((rvc_status != 0)); then
    die "RVC stage failed with exit $rvc_status; sanitized log retained"
  fi
  validate_rvc_metadata "$rvc_artifacts/metadata.json"
  python3 - "$artifacts/rvc-link.json" "$repo" "$rvc_artifacts" <<'PY'
import json
import pathlib
import sys

destination = pathlib.Path(sys.argv[1])
repo = pathlib.Path(sys.argv[2]).resolve()
rvc = pathlib.Path(sys.argv[3]).resolve()
destination.write_text(json.dumps({
    "artifactRoot": str(rvc.relative_to(repo)),
    "metadataSha256": __import__("hashlib").sha256((rvc / "metadata.json").read_bytes()).hexdigest(),
    "sha256SumsPresent": (rvc / "SHA256SUMS").is_file(),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

verify_privacy_inventory() {
  python3 - "$artifacts" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
patterns = (r"/Users/", r"/private/(?:var|tmp)/", r"(?<![A-Za-z0-9])/(?:var/)?tmp/", r"julienbattaglia")
for path in root.rglob("*"):
    if not path.is_file() or path.suffix.lower() == ".png":
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    for pattern in patterns:
        if re.search(pattern, text, re.IGNORECASE):
            raise SystemExit(f"private token in {path.name}: {pattern}")
PY
}

verify_artifact_allowlist() {
  find "$artifacts" -type f -print0 | MINT_ARTIFACT_ROOT="$artifacts" python3 -c '
import os, re, sys
allowed = re.compile(r"^(?:metadata\.json|device\.sha256|source-manifest\.sha256|SHA256SUMS|doctor\.log|patrol-tooling\.log|production-(?:export|build|codesign|xattrs|install|uninstall|overlay-(?:work_save|housing_cancel|disability_validation_cancel|succession_save|frontalier_inline))\.log|restoration-(?:install|launch)\.log|rvc-(?:runner\.log|link\.json)|(?:maestro|patrol)-(?:work_save|housing_cancel|disability_validation_cancel|succession_save|frontalier_inline)(?:-report\.sanitized\.xml|-xcresult-summary\.sanitized\.json|\.log|\.png)|hierarchy-(?:maestro|patrol)-(?:work_save|housing_cancel|disability_validation_cancel|succession_save|frontalier_inline)\.log|witness-(?:work_save|housing_cancel|disability_validation_cancel|succession_save|frontalier_inline)\.json)$")
root = os.environ["MINT_ARTIFACT_ROOT"]
items = sys.stdin.buffer.read().split(b"\0")
for raw in filter(None, items):
    relative = os.path.relpath(os.fsdecode(raw), root)
    if os.sep in relative or not allowed.fullmatch(relative):
        raise SystemExit("artifact not allowlisted: " + relative)
'
}

write_metadata() {
  local requested_result=$1
  python3 - "$artifacts/metadata.json" "$expected_sha" "$bundle_id" "$requested_result" \
    "$restoration_status" "$cleanup_status" <<'PY'
import json
import pathlib
import sys

path, sha, bundle, result, restoration, cleanup = sys.argv[1:]
passed = result == "passed"
payload = {
    "schemaVersion": 1,
    "caseId": "G1-RETURN-01",
    "sourceSha": sha,
    "bundleId": bundle,
    "result": result,
    "pushedShaVerified": passed,
    "sourceTreeCleanAfterRuntime": passed,
    "productionSourceExportedExact": passed,
    "productionSourcePhysical": passed,
    "productionOverlayVerified": passed,
    "productionFailureInjectionUsed": False,
    "syntheticDataOnly": True,
    "rawRuntimeOutputsRetained": False,
    "workSaveVerified": passed,
    "housingCancelNoWriteVerified": passed,
    "disabilityValidationCancelNoWriteVerified": passed,
    "successionSaveVerified": passed,
    "frontalierInlineNoDataBlockVerified": passed,
    "rvcExactShaVerified": passed,
    "maestroStagesVerified": passed,
    "patrolStagesVerified": passed,
    "hierarchyWitnessesVerified": passed,
    "storeWitnessesVerified": passed,
    "screenshotsVerified": passed,
    "checksumsVerified": passed,
    "restorationStatus": restoration,
    "cleanupStatus": cleanup,
}
pathlib.Path(path).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  chmod 600 "$artifacts/metadata.json"
}

# Preflight is retained and happens before any mobile stage.
(
  cd "$repo"
  python3 tools/checks/mint_os_doctor.py
) >"$private_root/doctor.raw.log" 2>&1
sanitize_log "$private_root/doctor.raw.log" "$artifacts/doctor.log"
(
  cd "$repo"
  python3 tools/checks/patrol_tooling_guard.py
) >"$private_root/patrol-tooling.raw.log" 2>&1
sanitize_log "$private_root/patrol-tooling.raw.log" "$artifacts/patrol-tooling.log"

printf '%s' "$device" | shasum -a 256 | awk '{print $1}' >"$artifacts/device.sha256"
export_physical_source
build_physical_source

run_patrol_stage work_save
run_maestro_stage work_save
run_patrol_stage housing_cancel
run_maestro_stage housing_cancel
run_patrol_stage disability_validation_cancel
run_maestro_stage disability_validation_cancel
run_patrol_stage succession_save
run_maestro_stage succession_save
run_patrol_stage frontalier_inline
run_maestro_stage frontalier_inline

run_rvc_stage
restore_normal_build || die 'normal production restoration failed'
verify_runtime_sources_clean || die 'runtime sources are not clean or exact after execution'
verify_privacy_inventory
verify_artifact_allowlist

# Cleanup is part of acceptance, not an optimistic metadata claim.
rm -rf -- "$private_root" || die 'private runtime cleanup failed'
cleanup_status='passed'
trap - EXIT HUP INT TERM

# Write success metadata, then hash every retained artifact exactly once.
write_metadata passed
if ! (
  cd "$artifacts"
  checksum_tmp=$(mktemp .SHA256SUMS.XXXXXX)
  find . -type f ! -name SHA256SUMS ! -name '.SHA256SUMS.*' -print0 \
    | sort -z | xargs -0 shasum -a 256 >"$checksum_tmp"
  mv -- "$checksum_tmp" SHA256SUMS
  shasum -a 256 -c SHA256SUMS >/dev/null
); then
  write_metadata failed
  die 'retained artifact checksum verification failed'
fi
verify_privacy_inventory || { write_metadata failed; die 'final privacy inventory failed'; }
verify_artifact_allowlist || { write_metadata failed; die 'final artifact allowlist failed'; }
printf 'RETURN-01 six-origin runtime evidence written: %s\n' "$artifacts"
