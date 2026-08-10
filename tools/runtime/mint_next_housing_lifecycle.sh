#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLOW="$ROOT/tools/simulator/flows/maestro-perfect-set/flow_mint_next_housing_lifecycle.yaml"
PHASE_EVIDENCE="$ROOT/.planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle"
RUNTIME_COMMIT=""
CAPTURE=0

assert_status_is_evidence_only() {
  local line path
  local final=".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle"
  local staging="$final.staging.$$"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="${line:3}"
    case "$path" in
      "$final"|"$final/"*|"$staging"|"$staging/"*) ;;
      *) echo "checkout changed outside runtime evidence: $line" >&2; return 1 ;;
    esac
  done
}

promote_evidence() {
  local staging="$1" final="$2" previous="$3"
  rm -rf "$final"
  mv "$staging" "$final"
  rm -rf "$previous"
}

restore_previous_evidence() {
  local final="$1" previous="$2"
  if [[ ! -e "$final" && -e "$previous" ]]; then mv "$previous" "$final"; fi
}

delete_disposable_device() {
  local device="$1" xcrun_bin="${XCRUN_BIN:-xcrun}"
  [[ -z "$device" ]] || "$xcrun_bin" simctl delete "$device" >/dev/null 2>&1 || true
}

self_test() {
  local sandbox fake_xcrun
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/mint-housing-self-test.XXXXXX")"
  trap 'rm -rf "$sandbox"' RETURN
  mkdir -p "$sandbox/final"
  printf old >"$sandbox/final/runtime.json"
  mv "$sandbox/final" "$sandbox/previous"
  restore_previous_evidence "$sandbox/final" "$sandbox/previous"
  [[ "$(cat "$sandbox/final/runtime.json")" == old ]]
  mv "$sandbox/final" "$sandbox/previous"
  mkdir "$sandbox/staging"
  printf new >"$sandbox/staging/runtime.json"
  promote_evidence "$sandbox/staging" "$sandbox/final" "$sandbox/previous"
  [[ "$(cat "$sandbox/final/runtime.json")" == new && ! -e "$sandbox/previous" ]]
  printf '?? .planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle.staging.%s/\n' "$$" |
    assert_status_is_evidence_only
  if printf ' M apps/mobile/pubspec.lock\n' | assert_status_is_evidence_only 2>/dev/null; then
    echo "self-test accepted a non-evidence mutation" >&2; return 1
  fi
  if printf '?? .planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle-evil/\n' |
    assert_status_is_evidence_only 2>/dev/null; then
    echo "self-test accepted an adjacent evidence path" >&2; return 1
  fi
  fake_xcrun="$sandbox/xcrun"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$DELETE_LOG"\n' >"$fake_xcrun"
  chmod +x "$fake_xcrun"
  export DELETE_LOG="$sandbox/deletes.log" XCRUN_BIN="$fake_xcrun"
  delete_disposable_device disposable-udid
  grep -Fx 'simctl delete disposable-udid' "$DELETE_LOG" >/dev/null
  echo "OK mint_next_housing_lifecycle self-test"
}

if [[ "${1:-}" == "--self-test" ]]; then self_test; exit 0; fi

while (($#)); do
  case "$1" in
    --runtime-commit) RUNTIME_COMMIT="${2:-}"; shift 2 ;;
    --capture-evidence) CAPTURE=1; shift ;;
    *) echo "usage: $0 --runtime-commit <40hex> [--capture-evidence]" >&2; exit 2 ;;
  esac
done

[[ "$RUNTIME_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
  echo "runtime commit is required" >&2; exit 2;
}
[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$RUNTIME_COMMIT" ]] || {
  echo "runtime commit is not checked out" >&2; exit 1;
}
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || {
  echo "runtime capture requires a clean checkout" >&2; exit 1;
}
for command in flutter maestro xcrun python3 shasum codesign; do command -v "$command" >/dev/null; done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mint-housing-runtime.XXXXXX")"
OUT="$TMP/evidence"
EVIDENCE_PARENT="$(dirname "$PHASE_EVIDENCE")"
STAGING="$PHASE_EVIDENCE.staging.$$"
PREVIOUS="$TMP/previous-evidence"
DEVICE=""
cleanup() {
  delete_disposable_device "$DEVICE"
  rm -rf "$STAGING"
  if ((CAPTURE)); then restore_previous_evidence "$PHASE_EVIDENCE" "$PREVIOUS"; fi
  rm -rf "$TMP"
}
trap cleanup EXIT
if ((CAPTURE)); then
  mkdir -p "$EVIDENCE_PARENT"
  rm -rf "$STAGING"
  if [[ -e "$PHASE_EVIDENCE" ]]; then mv "$PHASE_EVIDENCE" "$PREVIOUS"; fi
  OUT="$STAGING"
fi
mkdir -p "$OUT"
LOG="$OUT/maestro.log"

# clearState does not erase Keychain. Create a disposable simulator instead of
# accepting an arbitrary UDID that could erase a developer's working device.
RUNTIME_SELECTION="$(xcrun simctl list runtimes available -j | python3 -c '
import json,sys
r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS" and x["isAvailable"]]
if not r: raise SystemExit("no available iOS runtime")
def version(x): return tuple(int(p) for p in x["version"].split("."))
chosen=max(r, key=version)
print(chosen["identifier"]+"|"+chosen["version"])
')"
RUNTIME="${RUNTIME_SELECTION%%|*}"
RUNTIME_VERSION="${RUNTIME_SELECTION#*|}"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16e"
DEVICE_NAME="Mint Housing Proof-${RUNTIME_COMMIT:0:9}-$$"
DEVICE="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")"
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl spawn "$DEVICE" defaults write NSGlobalDomain AppleLocale fr_CH
xcrun simctl spawn "$DEVICE" defaults write NSGlobalDomain AppleLanguages -array fr-CH fr
xcrun simctl shutdown "$DEVICE"
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b

(
  cd "$ROOT/apps/mobile"
  flutter build ios --simulator --debug \
    --dart-define=MINT_E2E_MINT_NEXT_HOUSING=true
)
APP="$ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
EXECUTABLE="$APP/Runner"
[[ -x "$EXECUTABLE" ]] || { echo "simulator app executable missing" >&2; exit 1; }
codesign --verify --deep --strict "$APP"
SIGNATURE_INFO="$(codesign -dvvv "$APP" 2>&1)"
APP_SIGNATURE="$(printf '%s\n' "$SIGNATURE_INFO" | awk -F= '$1 == "Signature" { print $2 }')"
APP_CDHASH="$(printf '%s\n' "$SIGNATURE_INFO" | awk -F= '$1 == "CDHash" { print $2 }')"
[[ "$APP_SIGNATURE" == "adhoc" && "$APP_CDHASH" =~ ^[0-9a-f]+$ ]] || {
  echo "simulator app is not verifiably ad-hoc signed" >&2; exit 1;
}
xcrun simctl install "$DEVICE" "$APP"

set +e
maestro --device "$DEVICE" test --env "OUTPUT_DIR=$OUT" "$FLOW" 2>&1 | tee "$LOG"
MAESTRO_EXIT=${PIPESTATUS[0]}
set -e
((MAESTRO_EXIT == 0)) || exit "$MAESTRO_EXIT"

for image in \
  01-created-visible.png \
  02-cold-relaunch-visible.png \
  03-edited-visible.png \
  04-deleted-absent.png \
  05-delete-survives-relaunch.png; do
  [[ -s "$OUT/$image" ]] || {
    echo "missing runtime screenshot: $image" >&2; exit 1;
  }
done

# The runtime may only create evidence. A lockfile/source mutation invalidates
# the clean-SHA statement even when Maestro itself passed.
git -C "$ROOT" status --porcelain --untracked-files=all | assert_status_is_evidence_only

FLOW_SHA="$(shasum -a 256 "$FLOW" | awk '{print $1}')"
APP_SHA="$(shasum -a 256 "$EXECUTABLE" | awk '{print $1}')"
MAESTRO_VERSION="$(maestro --version 2>&1 | head -1)"
export OUT RUNTIME_COMMIT FLOW_SHA APP_SHA MAESTRO_VERSION DEVICE DEVICE_NAME
export RUNTIME RUNTIME_VERSION DEVICE_TYPE APP_SIGNATURE APP_CDHASH
python3 - <<'PY'
import hashlib, json, os
from datetime import datetime, timezone
from pathlib import Path

out = Path(os.environ["OUT"])
screens = {}
for path in sorted(out.glob("*.png")):
    screens[path.name] = {
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "bytes": path.stat().st_size,
    }
receipt = {
    "schema_version": 1,
    "status": "passed",
    "runtime_commit": os.environ["RUNTIME_COMMIT"],
    "git_dirty": False,
    "flow": "tools/simulator/flows/maestro-perfect-set/flow_mint_next_housing_lifecycle.yaml",
    "flow_sha256": os.environ["FLOW_SHA"],
    "app_sha256": os.environ["APP_SHA"],
    "app_signature": os.environ["APP_SIGNATURE"],
    "app_cdhash": os.environ["APP_CDHASH"],
    "device_udid": os.environ["DEVICE"],
    "device_name": os.environ["DEVICE_NAME"],
    "device_type": os.environ["DEVICE_TYPE"],
    "runtime_identifier": os.environ["RUNTIME"],
    "runtime_version": os.environ["RUNTIME_VERSION"],
    "locale": "fr_CH",
    "maestro_version": os.environ["MAESTRO_VERSION"],
    "command": (
        "bash tools/runtime/mint_next_housing_lifecycle.sh "
        f"--runtime-commit {os.environ['RUNTIME_COMMIT']} "
        "--capture-evidence"
    ),
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "ordered_outcomes": [
        "saved fact visible",
        "saved fact survives cold relaunch",
        "edited fact visible",
        "delete dialog dismissed and fact absent",
        "deletion survives cold relaunch",
    ],
    "screenshots": screens,
    "maestro_log_sha256": hashlib.sha256((out / "maestro.log").read_bytes()).hexdigest(),
}
(out / "runtime.json").write_text(
    json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
)
PY

if ((CAPTURE)); then
  promote_evidence "$STAGING" "$PHASE_EVIDENCE" "$PREVIOUS"
fi

echo "OK housing lifecycle runtime: $RUNTIME_COMMIT"
