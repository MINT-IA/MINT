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
command -v xcrun >/dev/null 2>&1 || die "xcrun is required"

mkdir -p "$artifacts"
artifacts="$(cd "$artifacts" && pwd)"
metadata="$artifacts/metadata.json"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
finished_at=""
write_exit_code=""
launch_exit_code=""
terminate_exit_code=""
read_exit_code=""

write_command=(
  "$patrol_bin" test --target "$write_target" --no-uninstall
  --device "$device" --bundle-id "$bundle_id"
  --dart-define=MINT_PATROL_CLI=true
)
read_command=(
  "$patrol_bin" test --target "$read_target" --no-uninstall
  --device "$device" --bundle-id "$bundle_id"
  --dart-define=MINT_PATROL_CLI=true
)
printf -v write_command_text '%q ' "${write_command[@]}"
printf -v read_command_text '%q ' "${read_command[@]}"
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
  MINT_META_LAUNCH_COMMAND="$launch_command_text" \
  MINT_META_TERMINATE_COMMAND="$terminate_command_text" \
  MINT_META_READ_COMMAND="$read_command_text" \
  MINT_META_WRITE_EXIT="$write_exit_code" \
  MINT_META_LAUNCH_EXIT="$launch_exit_code" \
  MINT_META_TERMINATE_EXIT="$terminate_exit_code" \
  MINT_META_READ_EXIT="$read_exit_code" \
  python3 - "$metadata" <<'PY'
import json
import os
import sys


def exit_code(name: str):
    value = os.environ[name]
    return int(value) if value else None


payload = {
    "contract": "g1_prov03_tax",
    "device": os.environ["MINT_META_DEVICE"],
    "bundle_id": os.environ["MINT_META_BUNDLE"],
    "sha": os.environ["MINT_META_SHA"],
    "started_at": os.environ["MINT_META_STARTED"],
    "finished_at": os.environ["MINT_META_FINISHED"],
    "write_command": os.environ["MINT_META_WRITE_COMMAND"].strip(),
    "launch_command": os.environ["MINT_META_LAUNCH_COMMAND"],
    "terminate_command": os.environ["MINT_META_TERMINATE_COMMAND"],
    "read_command": os.environ["MINT_META_READ_COMMAND"].strip(),
    "write_exit_code": exit_code("MINT_META_WRITE_EXIT"),
    "launch_exit_code": exit_code("MINT_META_LAUNCH_EXIT"),
    "terminate_exit_code": exit_code("MINT_META_TERMINATE_EXIT"),
    "read_exit_code": exit_code("MINT_META_READ_EXIT"),
    "synthetic_data_only": True,
    "feature_activation": "test_process_static_flags_only",
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}
trap write_metadata EXIT

set +e
(cd "$mobile_root" && "${write_command[@]}") 2>&1 | tee "$artifacts/write.log"
write_exit_code=${PIPESTATUS[0]}
set -e
if [[ "$write_exit_code" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: write stage failed ($write_exit_code)" >&2
  exit "$write_exit_code"
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

set +e
(cd "$mobile_root" && "${read_command[@]}") 2>&1 | tee "$artifacts/read.log"
read_exit_code=${PIPESTATUS[0]}
set -e
if [[ "$read_exit_code" -ne 0 ]]; then
  echo "patrol_tax_provenance_process_death: read stage failed ($read_exit_code)" >&2
  exit "$read_exit_code"
fi

echo "patrol_tax_provenance_process_death: PASS device=$device bundle=$bundle_id sha=$sha"
