#!/usr/bin/env bash
# Real-device preflight for the Mint 2.0 Keychain/iCloud restore gap.
#
# This does not claim restore proof by itself. It records whether a physical
# iPhone is available for a TestFlight/restore run and exits BLOCKED when it is
# not. Simulator proof must not close the Keychain/iCloud restore requirement.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET_DEVICE_NAME="${MINT2_DEVICE_NAME:-Jul}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
ARTIFACT_ROOT="${MINT2_REAL_DEVICE_ARTIFACTS:-$REPO_ROOT/.planning/runtime-evidence/mint2-real-device-restore-gate-$RUN_ID}"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: bash tools/simulator/mint2_real_device_restore_gate.sh [--dry-run]

Checks whether a physical iPhone is available for the Mint 2.0
Keychain/iCloud restore proof.

Target device name:
  $TARGET_DEVICE_NAME

Evidence:
  .planning/runtime-evidence/mint2-real-device-restore-gate-<timestamp>/

Verdicts:
  READY_FOR_MANUAL_RESTORE_PROOF  exit 0
  BLOCKED_NO_AVAILABLE_DEVICE     exit 2

This gate is a preflight, not a restore proof. A PASS restore claim still
requires TestFlight/manual-device evidence captured after the device is
available.
EOF
}

if [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

cd "$REPO_ROOT"

if [ "$DRY_RUN" -eq 1 ]; then
  usage
  cat <<EOF

Commands:
  xcrun devicectl list devices --json-output <raw-json>
  xcrun xctrace list devices

Artifacts:
  device-inventory-redacted.json
  xctrace-devices-redacted.txt
  verdict.json
  run-summary.txt
EOF
  exit 0
fi

mkdir -p "$ARTIFACT_ROOT"
exec > >(tee "$ARTIFACT_ROOT/run.log") 2>&1

log() {
  printf '\n[mint2-device-gate] %s\n' "$*"
}

RAW_DEVICECTL_JSON="$ARTIFACT_ROOT/.devicectl-devices.raw.json"

log "evidence: $ARTIFACT_ROOT"
log "target device name: $TARGET_DEVICE_NAME"

if [ -n "${MINT2_DEVICECTL_JSON:-}" ]; then
  cp "$MINT2_DEVICECTL_JSON" "$RAW_DEVICECTL_JSON"
else
  xcrun devicectl list devices --json-output "$RAW_DEVICECTL_JSON" \
    > "$ARTIFACT_ROOT/devicectl-devices.txt"
fi

if [ -n "${MINT2_DEVICECTL_JSON:-}" ]; then
  printf 'xctrace skipped: MINT2_DEVICECTL_JSON fixture mode\n' \
    > "$ARTIFACT_ROOT/xctrace-devices-redacted.txt"
else
  xcrun xctrace list devices 2>/dev/null \
    | python3 -c '
import re
import sys

text = sys.stdin.read()
text = re.sub(
    r"\(([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}|[0-9A-F]{8}-[0-9A-F]{16})\)",
    "(redacted-device-id)",
    text,
)
print(text, end="")
' > "$ARTIFACT_ROOT/xctrace-devices-redacted.txt"
fi

set +e
python3 - "$RAW_DEVICECTL_JSON" "$TARGET_DEVICE_NAME" "$ARTIFACT_ROOT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

raw_path = Path(sys.argv[1])
target_name = sys.argv[2]
artifact_root = Path(sys.argv[3])

data = json.loads(raw_path.read_text())
devices = data.get("result", {}).get("devices", [])


def short_hash(value: object) -> str:
    if value in (None, ""):
        return ""
    return hashlib.sha256(str(value).encode("utf-8")).hexdigest()[:12]


inventory = []
matching_physical = []
matching_available = []

for device in devices:
    props = device.get("deviceProperties", {})
    hw = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    name = props.get("name", "")
    model = hw.get("marketingName", "")
    platform = hw.get("platform", "")
    reality = hw.get("reality", "")
    tunnel = connection.get("tunnelState", "")
    ddi = props.get("ddiServicesAvailable")
    raw_identity = hw.get("udid") or device.get("identifier")
    is_physical_ios = reality == "physical" and platform == "iOS"
    target_matches = not target_name or name == target_name
    available = is_physical_ios and tunnel != "unavailable" and ddi is True
    row = {
        "name": name,
        "model": model,
        "platform": platform,
        "reality": reality,
        "tunnelState": tunnel,
        "ddiServicesAvailable": ddi,
        "identityHash": short_hash(raw_identity),
        "targetMatch": target_matches,
        "availableForDeviceGate": available,
    }
    inventory.append(row)
    if is_physical_ios and target_matches:
        matching_physical.append(row)
        if available:
            matching_available.append(row)

status = "READY_FOR_MANUAL_RESTORE_PROOF"
exit_code = 0
reason = "physical iPhone is available; run the manual TestFlight restore proof next"

if not matching_physical:
    status = "BLOCKED_NO_TARGET_PHYSICAL_DEVICE"
    exit_code = 2
    reason = f"no physical iOS device named {target_name!r} is known to CoreDevice"
elif not matching_available:
    status = "BLOCKED_NO_AVAILABLE_DEVICE"
    exit_code = 2
    reason = (
        f"physical iOS device named {target_name!r} exists but is not available "
        "for CoreDevice automation"
    )

verdict = {
    "status": status,
    "reason": reason,
    "targetDeviceName": target_name,
    "matchingPhysicalCount": len(matching_physical),
    "matchingAvailableCount": len(matching_available),
    "restoreProofClaimed": False,
    "nextRequiredEvidence": [
        "TestFlight build identifier",
        "fresh install or explicit app deletion on physical iPhone",
        "restore/iCloud/Keychain residue attempt",
        "screenshots or AX/device transcript showing no stale Mint2 financial residue",
    ],
}

(artifact_root / "device-inventory-redacted.json").write_text(
    json.dumps({"devices": inventory}, indent=2, ensure_ascii=False) + "\n"
)
(artifact_root / "verdict.json").write_text(
    json.dumps(verdict, indent=2, ensure_ascii=False) + "\n"
)
(artifact_root / "run-summary.txt").write_text(
    "\n".join(
        [
            f"status: {status}",
            f"reason: {reason}",
            f"target_device_name: {target_name}",
            f"matching_physical_count: {len(matching_physical)}",
            f"matching_available_count: {len(matching_available)}",
            "restore_proof_claimed: false",
            "",
        ]
    )
)

print(f"VERDICT: {status}")
print(reason)
sys.exit(exit_code)
PY
PY_EXIT=$?
set -e

rm -f "$RAW_DEVICECTL_JSON"
exit "$PY_EXIT"
