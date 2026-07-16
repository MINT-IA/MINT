#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --device <UDID> --bundle-id <bundle> --sha <40-hex> --artifacts <dir>" >&2
}

die() {
  echo "patrol_bnd03_budget_process_death: $*" >&2
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
write_contract="apps/mobile/integration_test/g1_bnd03_budget_persistence_write_patrol_test.dart"
read_contract="apps/mobile/integration_test/g1_bnd03_budget_persistence_read_patrol_test.dart"
write_target="apps/mobile/test/patrol/g1_bnd03_budget_persistence_write_runtime_test.dart"
read_target="apps/mobile/test/patrol/g1_bnd03_budget_persistence_read_runtime_test.dart"
maestro_flow="apps/mobile/.maestro/g1_bnd03_budget_cold.yaml"
orchestrator_path="tools/simulator/patrol_bnd03_budget_process_death.sh"
default_maestro_path="tools/simulator/maestro_env.sh"
generated_patrol_bundle="apps/mobile/test/patrol/test_bundle.dart"
runtime_paths=(
  "$write_contract"
  "$read_contract"
  "$write_target"
  "$read_target"
  "$maestro_flow"
  "apps/mobile/lib/screens/budget/budget_container_screen.dart"
  "apps/mobile/lib/screens/budget/budget_setup_screen.dart"
  "apps/mobile/lib/screens/budget/budget_screen.dart"
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
command -v python3 >/dev/null 2>&1 || die "python3 is required"

mkdir -p "$artifacts"
artifacts="$(cd "$artifacts" && pwd)"
metadata="$artifacts/metadata.json"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_exit_code=""
launch_exit_code=""
terminate_exit_code=""
read_exit_code=""
maestro_exit_code=""
cleanup_status="pending"
runtime_completed=false

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
  python3 - "$raw" "$output" "$repo_root" "$HOME" "$device" <<'PY'
import re
import sys
from pathlib import Path

raw_path, output_path, repo, home, device = sys.argv[1:]
text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
for private, token in (
    (repo, "REDACTED_REPO"),
    (home, "REDACTED_HOME"),
    (device, "REDACTED_SIMULATOR_UDID"),
):
    if private:
        text = text.replace(private, token)
text = re.sub(
    r"/private/var/folders/[^\s\"'<>]+",
    "REDACTED_PRIVATE_TEMP",
    text,
)
Path(output_path).write_text(text, encoding="utf-8")
PY
  rm -f "$raw"
}

write_metadata() {
  local finished_at
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  MINT_META_SHA="$sha" \
  MINT_META_BUNDLE="$bundle_id" \
  MINT_META_DEVICE_SHA="$device_sha256" \
  MINT_META_STARTED="$started_at" \
  MINT_META_FINISHED="$finished_at" \
  MINT_META_WRITE="$write_exit_code" \
  MINT_META_LAUNCH="$launch_exit_code" \
  MINT_META_TERMINATE="$terminate_exit_code" \
  MINT_META_READ="$read_exit_code" \
  MINT_META_MAESTRO="$maestro_exit_code" \
  MINT_META_CLEANUP="$cleanup_status" \
  python3 - "$metadata" <<'PY'
import json
import os
import sys


def code(name: str):
    value = os.environ[name]
    return int(value) if value else None


payload = {
    "contract": "g1_bnd03_budget",
    "sha": os.environ["MINT_META_SHA"],
    "bundle_id": os.environ["MINT_META_BUNDLE"],
    "device_sha256": os.environ["MINT_META_DEVICE_SHA"],
    "started_at": os.environ["MINT_META_STARTED"],
    "finished_at": os.environ["MINT_META_FINISHED"],
    "write_exit_code": code("MINT_META_WRITE"),
    "launch_exit_code": code("MINT_META_LAUNCH"),
    "terminate_exit_code": code("MINT_META_TERMINATE"),
    "read_exit_code": code("MINT_META_READ"),
    "maestro_exit_code": code("MINT_META_MAESTRO"),
    "cleanup_status": os.environ["MINT_META_CLEANUP"],
    "synthetic_data_only": True,
    "private_fixture_used": False,
    "source_manifest": "source-manifest.sha256",
    "logs": [
        "write.log",
        "launch.log",
        "terminate.log",
        "read.log",
        "maestro.log",
        "maestro-report.sanitized.xml",
    ],
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

cleanup() {
  local exit_code=$?
  local cleanup_failed=0
  local tracked_status=0
  trap - EXIT
  cleanup_status="passed"
  if [[ -e "$repo_root/$generated_patrol_bundle" ]]; then
    set +e
    git -C "$repo_root" ls-files --error-unmatch -- \
      "$generated_patrol_bundle" >/dev/null 2>&1
    tracked_status=$?
    set -e
    if [[ "$tracked_status" -eq 1 ]]; then
      if ! rm -f -- "$repo_root/$generated_patrol_bundle"; then
        echo "patrol_bnd03_budget_process_death: Patrol bundle cleanup failed" >&2
        cleanup_failed=1
      fi
    elif [[ "$tracked_status" -ne 0 ]]; then
      echo "patrol_bnd03_budget_process_death: could not verify Patrol bundle tracking" >&2
      cleanup_failed=1
    fi
  fi
  if [[ "$cleanup_failed" -ne 0 ]]; then
    cleanup_status="failed"
  fi
  if ! write_metadata; then
    echo "patrol_bnd03_budget_process_death: metadata write failed" >&2
    cleanup_failed=1
  fi
  if [[ "$exit_code" -ne 0 ]]; then
    exit "$exit_code"
  fi
  if [[ "$runtime_completed" != true || "$cleanup_failed" -ne 0 ]]; then
    exit 2
  fi
  echo "patrol_bnd03_budget_process_death: PASS sha=$sha"
  exit 0
}
trap cleanup EXIT

write_command=(
  "$patrol_bin" test
  --target "${write_target#apps/mobile/}"
  --no-uninstall
  --device "$device"
  --bundle-id "$bundle_id"
  --dart-define=MINT_PATROL_CLI=true
)
read_command=(
  "$patrol_bin" test
  --target "${read_target#apps/mobile/}"
  --no-uninstall
  --device "$device"
  --bundle-id "$bundle_id"
  --dart-define=MINT_PATROL_CLI=true
)

set +e
(cd "$mobile_root" && "${write_command[@]}") \
  >"$artifacts/write.raw.log" 2>&1
write_exit_code=$?
set -e
sanitize_log "$artifacts/write.raw.log" "$artifacts/write.log"
if [[ "$write_exit_code" -ne 0 ]]; then
  echo "patrol_bnd03_budget_process_death: write stage failed ($write_exit_code)" >&2
  exit "$write_exit_code"
fi
exact_sha_guard

set +e
xcrun simctl launch "$device" "$bundle_id" \
  >"$artifacts/launch.raw.log" 2>&1
launch_exit_code=$?
set -e
sanitize_log "$artifacts/launch.raw.log" "$artifacts/launch.log"
if [[ "$launch_exit_code" -ne 0 ]]; then
  echo "patrol_bnd03_budget_process_death: launch stage failed ($launch_exit_code)" >&2
  exit "$launch_exit_code"
fi

set +e
xcrun simctl terminate "$device" "$bundle_id" \
  >"$artifacts/terminate.raw.log" 2>&1
terminate_exit_code=$?
set -e
sanitize_log "$artifacts/terminate.raw.log" "$artifacts/terminate.log"
if [[ "$terminate_exit_code" -ne 0 ]]; then
  echo "patrol_bnd03_budget_process_death: terminate stage failed ($terminate_exit_code)" >&2
  exit "$terminate_exit_code"
fi
exact_sha_guard

set +e
(cd "$mobile_root" && "${read_command[@]}") \
  >"$artifacts/read.raw.log" 2>&1
read_exit_code=$?
set -e
sanitize_log "$artifacts/read.raw.log" "$artifacts/read.log"
if [[ "$read_exit_code" -ne 0 ]]; then
  echo "patrol_bnd03_budget_process_death: read stage failed ($read_exit_code)" >&2
  exit "$read_exit_code"
fi
exact_sha_guard

set +e
"${maestro_command[@]}" test --udid "$device" --format JUNIT \
  --output "$artifacts/maestro-report.xml" "$repo_root/$maestro_flow" \
  >"$artifacts/maestro.raw.log" 2>&1
maestro_exit_code=$?
set -e
sanitize_log "$artifacts/maestro.raw.log" "$artifacts/maestro.log"
if [[ "$maestro_exit_code" -ne 0 ]]; then
  echo "patrol_bnd03_budget_process_death: Maestro stage failed ($maestro_exit_code)" >&2
  exit "$maestro_exit_code"
fi
if [[ ! -s "$artifacts/maestro-report.xml" ]]; then
  maestro_exit_code=2
  die "Maestro JUnit report is missing or empty"
fi
sanitize_log \
  "$artifacts/maestro-report.xml" \
  "$artifacts/maestro-report.sanitized.xml"
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
