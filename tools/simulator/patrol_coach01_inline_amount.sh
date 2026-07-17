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

cleanup() {
  rm -rf -- "$private_dir"
}
trap cleanup EXIT INT TERM

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

set +e
(
  cd "$repo/apps/mobile"
  "$patrol" --verbose test \
    --target test/patrol/g1_coach01_inline_amount_runtime_test.dart \
    --no-generate-bundle \
    --device "$device" \
    --bundle-id "$bundle_id" \
    --dart-define=MINT_PATROL_CLI=true \
    --no-uninstall
) >"$raw_log" 2>&1
patrol_status=$?
set -e

if ((patrol_status != 0)); then
  sanitize_log
  log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
  write_metadata 'failed' "$log_hash"
  exit "$patrol_status"
fi

set +e
xcrun simctl io "$device" screenshot "$private_screenshot" >>"$raw_log" 2>&1
screenshot_status=$?
set -e
sanitize_log
log_hash=$(shasum -a 256 "$sanitized_log" | awk '{print $1}')
if ((screenshot_status != 0)) || [[ ! -s "$private_screenshot" ]]; then
  write_metadata 'failed' "$log_hash"
  fail 'final simulator screenshot failed'
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
post_sha=$(git -C "$repo" rev-parse HEAD)
if [[ "$post_sha" != "$expected_sha" ]] \
  || ! git -C "$repo" diff --quiet "$expected_sha" -- "${tracked_files[@]}"; then
  write_metadata 'failed' "$log_hash" "$screenshot_hash"
  fail 'runtime contract SHA changed during Patrol execution'
fi
write_metadata 'passed' "$log_hash" "$screenshot_hash"

printf 'G1-COACH-01 Patrol evidence written.\n'
