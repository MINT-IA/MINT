#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_BASE_URL="${MINT_API_BASE_URL:-https://mint-staging.up.railway.app/api/v1}"
BUNDLE_ID="${MINT_IOS_BUNDLE_ID:-ch.mint.app}"
DRY_RUN=0
REQUIRES_AUTH_ONLY=0
RUNTIME_SET="${JOURNEY_OS_RUNTIME_SET:-core}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --requires-auth)
      REQUIRES_AUTH_ONLY=1
      shift
      ;;
    --set)
      RUNTIME_SET="${2:?missing Journey OS runtime set}"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

PLAN_FILE="$(mktemp)"
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$PLAN_FILE" "$RESULTS_FILE"' EXIT
GIT_HEAD=""
GIT_STATUS_PORCELAIN=""
GIT_STATUS_SHA256=""
GIT_DIFF_SHA256=""

set +e
python3 - "$ROOT" "$RUNTIME_SET" > "$PLAN_FILE" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
runtime_set = sys.argv[2]
known_sets = {"core", "top", "authenticated", "account_lifecycle"}
if runtime_set not in known_sets:
    print(f"unknown Journey OS runtime set: {runtime_set}", file=sys.stderr)
    raise SystemExit(2)

records = []
for path in sorted((root / ".planning/journeys/records").glob("*.json")):
    data = json.loads(path.read_text(encoding="utf-8"))
    replay = data.get("runtime_replay")
    if not isinstance(replay, dict) or runtime_set not in replay.get("sets", []):
        continue
    records.append(
        {
            "id": data["id"],
            "flow": replay["flow"],
            "requires_auth": "true" if replay["requires_auth"] else "false",
            "device": replay["device"],
            "build_defines": "\x1f".join(replay.get("build_defines", [])),
            "order": int(replay.get("order", 50)),
        }
    )

if not records:
    if runtime_set == "top":
        raise SystemExit(0)
    print(f"no Journey OS runtime_replay records for set: {runtime_set}", file=sys.stderr)
    raise SystemExit(1)

for item in sorted(records, key=lambda value: (value["order"], value["id"])):
    print(
        "\t".join(
            [
                item["id"],
                item["flow"],
                item["requires_auth"],
                item["device"],
                item["build_defines"],
            ]
        )
    )
PY
plan_status=$?
set -e
if [[ "$plan_status" -ne 0 ]]; then
  exit "$plan_status"
fi

PLAN_LINES=()
while IFS= read -r line; do
  PLAN_LINES+=("$line")
done < "$PLAN_FILE"

for item in "${PLAN_LINES[@]}"; do
  IFS=$'\t' read -r journey flow _requires_auth _device _defines <<< "$item"
  if [[ ! -f "$ROOT/$flow" ]]; then
    echo "missing Journey OS replay flow for $journey: $flow" >&2
    exit 1
  fi
done

SET_REQUIRES_AUTH=0
for item in "${PLAN_LINES[@]}"; do
  IFS=$'\t' read -r _journey _flow requires_auth _device _defines <<< "$item"
  if [[ "$requires_auth" == "true" ]]; then
    SET_REQUIRES_AUTH=1
    break
  fi
done

if [[ "$REQUIRES_AUTH_ONLY" -eq 1 ]]; then
  if [[ "$SET_REQUIRES_AUTH" -eq 1 ]]; then
    echo "true"
  else
    echo "false"
  fi
  exit 0
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "$SET_REQUIRES_AUTH" -eq 1 && -z "${MINT_E2E_EMAIL:-}" ]]; then
    echo "authenticated replay requires MINT_E2E_EMAIL" >&2
    exit 1
  fi
  if [[ "$SET_REQUIRES_AUTH" -eq 1 && -z "${MINT_E2E_PASSWORD:-}" ]]; then
    echo "authenticated replay requires MINT_E2E_PASSWORD" >&2
    exit 1
  fi
fi

build_command_preview() {
  local defines="$1"
  local cmd="CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign --dart-define=API_BASE_URL=$API_BASE_URL"
  if [[ -n "$defines" ]]; then
    local old_ifs="$IFS"
    IFS=$'\x1f'
    read -r -a define_items <<< "$defines"
    IFS="$old_ifs"
    for define in "${define_items[@]}"; do
      [[ -n "$define" ]] && cmd+=" --dart-define=$define"
    done
  fi
  printf '%s\n' "$cmd"
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "journey_os_runtime_replay: dry-run set=$RUNTIME_SET"
  for item in "${PLAN_LINES[@]}"; do
    IFS=$'\t' read -r journey flow requires_auth device defines <<< "$item"
    echo "journey: $journey"
    echo "  simulator: $device"
    echo "  requires_auth: $requires_auth"
    echo "  build: (cd apps/mobile && $(build_command_preview "$defines"))"
    echo "  flow: $flow"
  done
  exit 0
fi

capture_clean_git_state() {
  GIT_STATUS_PORCELAIN="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)"
  if [[ -n "$GIT_STATUS_PORCELAIN" ]]; then
    echo "Journey OS runtime replay requires a clean git worktree before writing durable evidence." >&2
    printf '%s\n' "$GIT_STATUS_PORCELAIN" >&2
    exit 1
  fi
  GIT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
  GIT_STATUS_SHA256="$(printf '%s' "$GIT_STATUS_PORCELAIN" | shasum -a 256 | awk '{print $1}')"
  GIT_DIFF_SHA256="$(git -C "$ROOT" diff --binary HEAD -- | shasum -a 256 | awk '{print $1}')"
}

capture_clean_git_state

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required for Journey OS runtime replay" >&2
  exit 1
fi
if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required for Journey OS iOS simulator replay" >&2
  exit 1
fi
if [[ ! -x "$ROOT/tools/simulator/maestro_with_watchdog.sh" ]]; then
  echo "tools/simulator/maestro_with_watchdog.sh is required for replay" >&2
  exit 1
fi

clear_extended_attributes() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  command -v xattr >/dev/null 2>&1 || return 0
  xattr -dr com.apple.provenance "$path" 2>/dev/null || true
  xattr -dr com.apple.FinderInfo "$path" 2>/dev/null || true
  xattr -dr com.apple.ResourceFork "$path" 2>/dev/null || true
  xattr -cr "$path" 2>/dev/null || true
}

scrub_ios_build_xattrs() {
  local mobile_build_dir="$ROOT/apps/mobile/build"
  local ios_build_dir="$mobile_build_dir/ios"
  local app_framework="$ios_build_dir/Debug-iphonesimulator/App.framework"
  local flutter_root=""
  local flutter_xcframework=""
  clear_extended_attributes "$ios_build_dir"
  flutter_root="$(
    cd "$ROOT/apps/mobile"
    flutter --version --machine | python3 -c 'import json, sys; print(json.load(sys.stdin).get("flutterRoot", ""))'
  )"
  flutter_xcframework="$flutter_root/bin/cache/artifacts/engine/ios/Flutter.xcframework"
  clear_extended_attributes "$flutter_xcframework"
  if [[ -d "$app_framework" ]]; then
    local stale_stamp="${STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
    if [[ ! "$stale_stamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
      echo "invalid stale App.framework stamp: $stale_stamp" >&2
      exit 1
    fi
    local stale_dir="$mobile_build_dir/.mint-stale-app-frameworks/ios"
    mkdir -p "$stale_dir"
    local stale_parent=""
    stale_parent="$(mktemp -d "$stale_dir/app-framework-$stale_stamp-XXXXXX")" || {
      echo "failed to create stale App.framework destination under $stale_dir" >&2
      exit 1
    }
    local stale_app_framework="$stale_parent/App.framework"
    mv "$app_framework" "$stale_app_framework" || {
      echo "failed to move stale App.framework to $stale_app_framework" >&2
      exit 1
    }
  fi
}

resolve_device_udid() {
  local device_name="$1"
  xcrun simctl list devices available -j | python3 -c '
import json
import sys

target = sys.argv[1]
data = json.load(sys.stdin)
matches = []
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("isAvailable") and device.get("name") == target:
            matches.append(device.get("udid"))

if len(matches) == 0:
    print(f"no available simulator named {target!r}", file=sys.stderr)
    raise SystemExit(3)
if len(matches) > 1:
    print(f"expected exactly one available simulator named {target!r}, found {len(matches)}", file=sys.stderr)
    raise SystemExit(4)
print(matches[0])
' "$device_name"
}

ensure_device_udid() {
  local device_name="$1"
  local udid=""
  set +e
  udid="$(resolve_device_udid "$device_name" 2>/dev/null)"
  local resolve_status=$?
  set -e
  if [[ "$resolve_status" -eq 0 && -n "$udid" ]]; then
    printf '%s\n' "$udid"
    return 0
  fi
  if [[ "$resolve_status" -ne 3 ]]; then
    resolve_device_udid "$device_name" >/dev/null
    return 1
  fi

  local device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-13-mini"
  local runtime_id=""
  runtime_id="$(xcrun simctl list runtimes available -j | python3 -c '
import json
import sys

data = json.load(sys.stdin)
runtimes = [
    item
    for item in data.get("runtimes", [])
    if item.get("isAvailable") and str(item.get("identifier", "")).startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
]
if not runtimes:
    print("no available iOS simulator runtime", file=sys.stderr)
    raise SystemExit(2)
runtimes.sort(key=lambda item: str(item.get("version", "")))
print(runtimes[-1]["identifier"])
')"
  xcrun simctl create "$device_name" "$device_type" "$runtime_id"
}

build_app() {
  local defines="$1"
  local -a cmd=(
    flutter build ios --simulator --debug --no-codesign
    "--dart-define=API_BASE_URL=$API_BASE_URL"
  )
  if [[ -n "$defines" ]]; then
    local old_ifs="$IFS"
    IFS=$'\x1f'
    read -r -a define_items <<< "$defines"
    IFS="$old_ifs"
    for define in "${define_items[@]}"; do
      [[ -n "$define" ]] && cmd+=("--dart-define=$define")
    done
  fi
  (
    cd "$ROOT/apps/mobile"
    CODE_SIGNING_ALLOWED=NO "${cmd[@]}"
  )
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_ROOT="$ROOT/.planning/journeys/evidence/runtime_replay/$STAMP"
DEBUG_ROOT="${JOURNEY_OS_DEBUG_ROOT:-${TMPDIR:-/tmp}/mint-journey-os-runtime-debug/$STAMP}"
mkdir -p "$OUT_ROOT"
mkdir -p "$DEBUG_ROOT"

write_manifest() {
  python3 - "$ROOT" "$PLAN_FILE" "$RESULTS_FILE" "$RUNTIME_SET" "$STAMP" "$GIT_HEAD" "$GIT_STATUS_PORCELAIN" "$GIT_STATUS_SHA256" "$GIT_DIFF_SHA256" > "$OUT_ROOT/manifest.json" <<'PY'
from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
plan_file, results_file, runtime_set, stamp, git_head, git_status, git_status_sha256, git_diff_sha256 = sys.argv[2:10]
results = {}
results_path = Path(results_file)
if results_path.exists():
    for line in results_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        journey, status, exit_code = line.split("\t")
        results[journey] = {"status": status, "exit_code": int(exit_code)}

def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

items = []
with open(plan_file, encoding="utf-8") as handle:
    for line in handle:
        journey, flow, requires_auth, device, defines = line.rstrip("\n").split("\t")
        entry = {
            "journey": journey,
            "flow": flow,
            "flow_sha256": sha256_file(root / flow),
            "requires_auth": requires_auth == "true",
            "device": device,
            "build_defines": [item for item in defines.split("\x1f") if item],
        }
        if journey in results:
            entry["result"] = results[journey]
        items.append(entry)

manifest = {
    "schema_version": 1,
    "created_at": stamp,
    "runtime_set": runtime_set,
    "git_head": git_head,
    "git_dirty": bool(git_status),
    "git_status_porcelain": git_status,
    "git_status_sha256": git_status_sha256,
    "git_diff_sha256": git_diff_sha256,
    "replay_script_sha256": sha256_file(root / "tools/simulator/journey_os_runtime_replay.sh"),
    "evidence_policy": "Commit manifest.json and per-journey result.xml only; raw Maestro debug artifacts stay outside .planning/journeys/evidence.",
    "journeys": items,
}
if results:
    manifest["completed_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(
    json.dumps(
        manifest,
        indent=2,
        sort_keys=True,
    )
)
PY
}

run_journey() {
  local journey="$1"
  local flow="$2"
  local requires_auth="$3"
  local device="$4"
  local defines="$5"
  (
    set -euo pipefail
    local out_dir="$OUT_ROOT/$journey"
    local debug_dir="$DEBUG_ROOT/$journey"
    mkdir -p "$out_dir" "$debug_dir"
    echo "journey_os_runtime_replay: preparing $journey on $device"

    local device_udid
    device_udid="$(ensure_device_udid "$device")"
    xcrun simctl shutdown all >/dev/null 2>&1 || true
    xcrun simctl boot "$device_udid"
    open -a Simulator >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device_udid" -b
    xcrun simctl keychain "$device_udid" reset

    scrub_ios_build_xattrs
    build_app "$defines"

    local app_path="$ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
    if [[ ! -d "$app_path" ]]; then
      echo "Runner.app not found at $app_path" >&2
      exit 1
    fi
    xcrun simctl uninstall "$device_udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl install "$device_udid" "$app_path"
    xcrun simctl launch "$device_udid" "$BUNDLE_ID" >/dev/null
    sleep 3

    local -a maestro_env=()
    if [[ "$requires_auth" == "true" ]]; then
      maestro_env+=(--env "MINT_E2E_EMAIL=$MINT_E2E_EMAIL")
      maestro_env+=(--env "MINT_E2E_PASSWORD=$MINT_E2E_PASSWORD")
    fi

    echo "journey_os_runtime_replay: running $journey"
    local -a maestro_cmd=(
      bash "$ROOT/tools/simulator/maestro_with_watchdog.sh"
      test
      --debug-output "$debug_dir/maestro-debug"
      --format junit
      --output "$out_dir/result.xml"
    )
    if [[ "$requires_auth" == "true" ]]; then
      maestro_cmd+=("${maestro_env[@]}")
    fi
    maestro_cmd+=("$ROOT/$flow")
    MAESTRO_HARD_LIMIT="${MAESTRO_HARD_LIMIT:-600}" \
    MAESTRO_STALL_THRESHOLD="${MAESTRO_STALL_THRESHOLD:-150}" \
    MINT_WALKER_ARTIFACTS="$debug_dir/watchdog" \
    "${maestro_cmd[@]}"
  )
}

write_manifest

EXIT_STATUS=0
for item in "${PLAN_LINES[@]}"; do
  IFS=$'\t' read -r journey flow requires_auth device defines <<< "$item"
  set +e
  run_journey "$journey" "$flow" "$requires_auth" "$device" "$defines"
  journey_status=$?
  set -e
  if [[ "$journey_status" -eq 0 ]]; then
    printf '%s\t%s\t%s\n' "$journey" "passed" "$journey_status" >> "$RESULTS_FILE"
  else
    printf '%s\t%s\t%s\n' "$journey" "failed" "$journey_status" >> "$RESULTS_FILE"
    EXIT_STATUS=1
  fi
done
write_manifest

echo "journey_os_runtime_replay: artifacts written to ${OUT_ROOT#$ROOT/}"
echo "journey_os_runtime_replay: raw debug written to $DEBUG_ROOT"
exit "$EXIT_STATUS"
