#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE_NAME="${MINT_RUNTIME_DEBUG_DEVICE:-MINT iPhone 13 mini RvC}"
BUNDLE_ID="ch.mint.app"
API_BASE_URL="${MINT_API_BASE_URL:-https://mint-staging.up.railway.app/api/v1}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
ARTIFACT_ROOT="${MINT_RUNTIME_DEBUG_ARTIFACTS:-$ROOT/.planning/runtime-evidence/mint-runtime-debug-tooling-$RUN_ID}"
FOREGROUND_HOLD_SECONDS="${MINT_RUNTIME_DEBUG_FOREGROUND_HOLD_SECONDS:-20}"
FOREGROUND_READY_TIMEOUT_SECONDS="${MINT_RUNTIME_DEBUG_FOREGROUND_READY_TIMEOUT_SECONDS:-240}"
DRY_RUN=0
SCAN_ONLY=""
CI_STATIC_ONLY=0
RELEASE_SCAN_ONLY=0

usage() {
  cat <<EOF
Usage: tools/checks/mint_runtime_debug_tooling_gate.sh [--dry-run]
       tools/checks/mint_runtime_debug_tooling_gate.sh --ci-static-only
       tools/checks/mint_runtime_debug_tooling_gate.sh --release-scan-only
       tools/checks/mint_runtime_debug_tooling_gate.sh --artifact-scan-only <evidence-dir>

Runs the Mint Runtime Debug Tooling gate:
  simulator: $DEVICE_NAME
  staging:   $API_BASE_URL
  evidence:  .planning/runtime-evidence/mint-runtime-debug-tooling-<timestamp>/

True-fresh preflight:
  xcrun simctl shutdown <UDID>
  xcrun simctl boot <UDID>
  xcrun simctl keychain <UDID> reset
  xcrun simctl uninstall <UDID> $BUNDLE_ID

Runtime proof:
  Patrol reset leg    -> before_reset.json + after_reset.json
  Patrol relaunch leg -> after_relaunch.json
  host foreground proof -> foreground-proof.txt
  host foreground tree  -> host-ui-tree.json + host-ui-tree.txt
  host screenshot       -> final-reset-state.png
  Vision OCR          -> final-reset-state.ocr.txt
  Debug Spine redacted rows -> ui-tree.json + ui-tree.txt
  artifact scan       -> artifact-scan.log

CI-safe static proof:
  --ci-static-only runs deterministic Flutter/debug contract tests, artifact
  scanner self-tests, production workflow dart-define scans, and route/debug
  flag source checks. It is NOT iOS runtime proof.

Release/profile leakage proof:
  --release-scan-only scans production workflows and either scans paths from
  MINT_RELEASE_SCAN_PATHS or builds local iOS release/profile Runner.app
  no-codesign artifacts with admin/debug flags disabled before scanning them.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --artifact-scan-only)
      SCAN_ONLY="${2:-}"
      [ -n "$SCAN_ONLY" ] || {
        echo "--artifact-scan-only requires a path" >&2
        exit 2
      }
      shift 2
      ;;
    --ci-static-only)
      CI_STATIC_ONLY=1
      shift
      ;;
    --release-scan-only)
      RELEASE_SCAN_ONLY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

export PATH="$PATH:$HOME/.pub-cache/bin"

fail() {
  printf '\n[runtime-debug-gate] ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '\n[runtime-debug-gate] %s\n' "$*"
}

check_single_mode() {
  local count=0
  [ -n "$SCAN_ONLY" ] && count=$((count + 1))
  [ "$CI_STATIC_ONLY" -eq 1 ] && count=$((count + 1))
  [ "$RELEASE_SCAN_ONLY" -eq 1 ] && count=$((count + 1))
  if [ "$count" -gt 1 ]; then
    fail "--ci-static-only, --release-scan-only, and --artifact-scan-only are mutually exclusive"
  fi
}

require_patrol() {
  if ! dart pub global list | grep -q '^patrol_cli '; then
    cat >&2 <<'EOF'
patrol_cli is required for Mint runtime debug tooling.
Install it with:
  flutter pub global activate patrol_cli
EOF
    exit 1
  fi

  if ! command -v patrol >/dev/null 2>&1; then
    cat >&2 <<'EOF'
patrol executable is required but was not found on PATH.
Ensure Pub global executables are visible:
  export PATH="$PATH:$HOME/.pub-cache/bin"
EOF
    exit 1
  fi
}

clear_extended_attributes() {
  local path="$1"
  [ -e "$path" ] || return 0
  command -v xattr >/dev/null 2>&1 || return 0

  xattr -dr com.apple.provenance "$path" 2>/dev/null || true
  xattr -dr com.apple.FinderInfo "$path" 2>/dev/null || true
  xattr -dr com.apple.ResourceFork "$path" 2>/dev/null || true
  xattr -cr "$path" 2>/dev/null || true
}

remove_existing_signature() {
  local path="$1"
  [ -e "$path" ] || return 0

  /usr/bin/codesign --remove-signature "$path" 2>/dev/null || true
  if [ -d "$path" ]; then
    local bundle_executable="$path/$(basename "$path" .framework)"
    if [ -f "$bundle_executable" ]; then
      /usr/bin/codesign --remove-signature "$bundle_executable" 2>/dev/null || true
    fi
  fi
}

strip_norsrc_bundle() {
  local path="$1"
  [ -d "$path" ] || return 0

  clear_extended_attributes "$path"
  remove_existing_signature "$path"
  local parent_dir
  local base_name
  local tmp_path
  local backup_path
  parent_dir="$(cd "$(dirname "$path")" && pwd -P)"
  base_name="$(basename "$path")"
  tmp_path="$parent_dir/.${base_name}.norsrc.$$"
  backup_path="$parent_dir/.${base_name}.pre-xattr-strip.$$"
  rm -rf "$tmp_path" "$backup_path"
  /usr/bin/ditto --norsrc "$path" "$tmp_path"
  test -d "$tmp_path"
  mv "$path" "$backup_path"
  if mv "$tmp_path" "$path"; then
    rm -rf "$backup_path"
    remove_existing_signature "$path"
  else
    rm -rf "$path"
    mv "$backup_path" "$path"
    rm -rf "$tmp_path"
    exit 1
  fi
}

strip_flutter_engine_cache_xattrs() {
  local flutter_bin
  flutter_bin="$(command -v flutter || true)"
  [ -n "$flutter_bin" ] || return 0

  local flutter_root
  flutter_root="$(cd "$(dirname "$flutter_bin")/.." && pwd -P)"
  strip_norsrc_bundle \
    "$flutter_root/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator/Flutter.framework"
}

scrub_patrol_ios_build_xattrs() {
  local ios_build_dir="$ROOT/apps/mobile/build/ios"
  local ios_integ_dir="$ROOT/apps/mobile/build/ios_integ"
  local flutter_build_dir="$ROOT/apps/mobile/.dart_tool/flutter_build"
  local stale_frameworks=(
    "$ios_build_dir/Debug-iphonesimulator/Flutter.framework"
    "$ios_build_dir/Debug-iphonesimulator/App.framework"
    "$ios_integ_dir/Build/Products/Debug-iphonesimulator/Flutter.framework"
    "$ios_integ_dir/Build/Products/Debug-iphonesimulator/App.framework"
    "$ios_integ_dir/Build/Products/Debug-iphonesimulator/Runner.app/Frameworks/Flutter.framework"
    "$ios_integ_dir/Build/Products/Debug-iphonesimulator/Runner.app/Frameworks/App.framework"
  )

  log "resetting generated Patrol iOS build state and scrubbing xattrs"
  rm -rf "$ios_build_dir/Debug-iphonesimulator" "$ios_integ_dir" "$flutter_build_dir"
  strip_flutter_engine_cache_xattrs
  clear_extended_attributes "$ios_build_dir"
  clear_extended_attributes "$ios_integ_dir"
  clear_extended_attributes "$flutter_build_dir"
  if [ -d "$flutter_build_dir" ]; then
    while IFS= read -r framework; do
      /usr/bin/codesign --remove-signature "$framework" 2>/dev/null || true
      remove_existing_signature "$framework"
      rm -rf "$framework"
    done < <(find "$flutter_build_dir" -mindepth 2 -maxdepth 2 -type d -name App.framework 2>/dev/null)
  fi
  for framework in "${stale_frameworks[@]}"; do
    if [ -d "$framework" ]; then
      /usr/bin/codesign --remove-signature "$framework" 2>/dev/null || true
      remove_existing_signature "$framework"
      rm -rf "$framework"
    fi
  done
}

copy_container_evidence() {
  local evidence_dir="$1"
  local udid="$2"
  shift 2
  local container

  container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null || true)"
  [ -n "$container" ] || fail "could not resolve app data container for $BUNDLE_ID"

  local label
  for label in "$@"; do
    local source="$container/Library/Application Support/mint-runtime-debug-evidence/debug-spine-$label.json"
    [ -f "$source" ] || fail "missing runtime evidence file in app container: debug-spine-$label.json"
    cp "$source" "$evidence_dir/debug-spine-$label.json"
  done
}

wait_for_foreground_ready() {
  local udid="$1"
  local run_id="$2"
  local patrol_pid="$3"
  local container
  local attempt

  log "waiting for Patrol foreground-ready marker"
  for attempt in $(seq 1 "$FOREGROUND_READY_TIMEOUT_SECONDS"); do
    if ! kill -0 "$patrol_pid" 2>/dev/null; then
      fail "Patrol relaunch leg exited before foreground-ready marker for run_id $run_id"
    fi
    container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null || true)"
    if [ -n "$container" ]; then
      local proof="$container/Library/Application Support/mint-runtime-debug-evidence/foreground-proof.txt"
      if [ -f "$proof" ] && grep -Fq "run_id: $run_id" "$proof"; then
        return 0
      fi
    fi
    sleep 1
  done
  kill "$patrol_pid" 2>/dev/null || true
  wait "$patrol_pid" 2>/dev/null || true
  fail "timed out waiting for foreground-ready marker for run_id $run_id"
}

capture_host_foreground_artifacts() {
  local evidence_dir="$1"
  local udid="$2"
  local run_id="$3"
  local container
  local source_dir

  command -v idb >/dev/null 2>&1 || fail "idb is required for host native UI-tree foreground proof"

  container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data 2>/dev/null || true)"
  [ -n "$container" ] || fail "could not resolve app data container for $BUNDLE_ID"
  source_dir="$container/Library/Application Support/mint-runtime-debug-evidence"

  log "capturing host native foreground tree before screenshot"
  idb ui describe-all --udid "$udid" --json --nested > "$evidence_dir/host-ui-tree.json"
  idb ui describe-all --udid "$udid" > "$evidence_dir/host-ui-tree.txt"

  log "capturing host simulator screenshot"
  xcrun simctl io "$udid" screenshot "$evidence_dir/final-reset-state.png" >/dev/null

  log "copying Patrol Debug Spine redacted row evidence"
  for file_name in ui-tree.json ui-tree.txt; do
    [ -f "$source_dir/$file_name" ] || fail "missing Debug Spine redacted row evidence file in app container: $file_name"
    cp "$source_dir/$file_name" "$evidence_dir/$file_name"
  done

  cat > "$evidence_dir/foreground-proof.txt" <<EOF
run_id: $run_id
foreground: $BUNDLE_ID
os_native_foreground: proven_by_host_ui_tree_application_mint
host_ui_tree_source: idb ui describe-all --json --nested
flutter_ui_tree_source: patrol_debug_spine_redacted_rows
screenshot_source: xcrun simctl io screenshot
capture_sequence: ui_tree_before_screenshot
EOF
}

resolve_device_udid() {
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

if len(matches) != 1:
    print(
        f"expected exactly one available simulator named {target!r}, "
        f"found {len(matches)}",
        file=sys.stderr,
    )
    sys.exit(2)

print(matches[0])
' "$DEVICE_NAME"
}

run_artifact_scan() {
  local evidence_dir="$1"
  local simulator_udid="${2:-}"
  [ -d "$evidence_dir" ] || fail "artifact scan path is not a directory: $evidence_dir"
  python3 - "$evidence_dir" "$simulator_udid" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
simulator_udid = sys.argv[2] if len(sys.argv) > 2 else ""
patterns = [
    ("synthetic sentinel", re.compile(r"__MINT_SYNTHETIC_[A-Z0-9_]+__")),
    ("raw wizard key", re.compile(r"\bq_[A-Za-z0-9_]+\b")),
    ("synthetic account id", re.compile(r"\bplan02-(?:runtime-user|anon-conversation|user-conversation)\b")),
    ("auth or token marker", re.compile(
        r"\b(?:authorization|bearer|token|access_token|refresh_token|id_token|x-mint-auth)\b",
        re.IGNORECASE,
    )),
    ("query string", re.compile(r"[?&][A-Za-z0-9_.%-]+=")),
    ("email", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    ("raw uuid/device id", re.compile(
        r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"
    )),
    ("known financial sentinel", re.compile(
        r"37'600|37600|6'640|6640|Avoir LPP|Marge libre|"
        r"-?920000001(?:\.0)?|-?920000002(?:\.0)?|-?0\.920000003"
    )),
    ("value-bearing CHF", re.compile(r"(?:\d[\d'’.,\s]*\s*CHF|CHF\s*\d)", re.IGNORECASE)),
    ("http body log", re.compile(r"\bBODY req_id=|\bbody=")),
]
if simulator_udid:
    patterns.append(("simulator udid", re.compile(re.escape(simulator_udid), re.IGNORECASE)))

mint_foreground_anchor = re.compile(
    r"Debug spine|mint_debug_spine_snapshot|Redacted local-state inspector|"
    r"anonymousMessages|account handoff|wizardAnswers",
    re.IGNORECASE,
)
springboard_anchor = re.compile(
    r"\b(?:Fitness|Watch|Contacts|Files|Preview|Utilities|Safari|Messages|"
    r"spotlight-pill|RunnerUITests-Runner|Page \d+ of \d+)\b",
    re.IGNORECASE,
)

failures = []
scanned = 0
image_count = 0
ui_tree_evidence_text = []
ocr_evidence_text = []
foreground_proof_text = []
host_ui_tree_text = []
for path in sorted(root.rglob("*")):
    if not path.is_file():
        continue
    if path.suffix.lower() in {".png", ".jpg", ".jpeg"}:
        image_count += 1
        ocr_path = path.with_suffix(".ocr.txt")
        if not ocr_path.exists() or not ocr_path.read_text(encoding="utf-8", errors="ignore").strip():
            failures.append((path, "image_ocr_extraction"))
        continue
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError as exc:
        failures.append((path, f"read_error:{exc.__class__.__name__}"))
        continue
    scanned += 1
    if path.name == "ui-tree.txt":
        ui_tree_evidence_text.append(text)
    if path.name == "host-ui-tree.txt":
        host_ui_tree_text.append(text)
    if path.name.endswith(".ocr.txt"):
        ocr_evidence_text.append(text)
    if path.name == "foreground-proof.txt":
        foreground_proof_text.append(text)
    for label, pattern in patterns:
        match = pattern.search(text)
        if match:
            failures.append((path, label))

def check_mint_foreground_anchors(texts, missing_label, springboard_label):
    if not texts:
        return
    combined_ui_text = "\n".join(texts)
    has_mint_anchor = bool(mint_foreground_anchor.search(combined_ui_text))
    if not has_mint_anchor:
        failures.append((root / "ui-evidence", missing_label))
    if springboard_anchor.search(combined_ui_text) and not has_mint_anchor:
        failures.append((root / "ui-evidence", springboard_label))

check_mint_foreground_anchors(
    ui_tree_evidence_text,
    "missing Mint debug reset-state UI-tree foreground anchor",
    "SpringBoard/home-screen UI-tree evidence",
)
check_mint_foreground_anchors(
    ocr_evidence_text,
    "missing Mint debug reset-state screenshot OCR anchor",
    "SpringBoard/home-screen screenshot OCR evidence",
)

if ui_tree_evidence_text or ocr_evidence_text or image_count:
    if not foreground_proof_text:
        failures.append((root / "foreground-proof.txt", "missing host foreground proof"))
    else:
        combined_proof = "\n".join(foreground_proof_text)
        required = [
            "foreground: ch.mint.app",
            "os_native_foreground: proven_by_host_ui_tree_application_mint",
            "capture_sequence: ui_tree_before_screenshot",
        ]
        for marker in required:
            if marker not in combined_proof:
                failures.append((root / "foreground-proof.txt", f"missing foreground proof marker: {marker}"))
        if "os_native_foreground: not_proven" in combined_proof:
            failures.append((root / "foreground-proof.txt", "foreground proof explicitly not proven"))
    if not host_ui_tree_text:
        failures.append((root / "host-ui-tree.txt", "missing host foreground UI tree"))
    else:
        combined_host_tree = "\n".join(host_ui_tree_text)
        if "AXLabel\":\"MINT\"" not in combined_host_tree and "AXLabel\": \"MINT\"" not in combined_host_tree:
            failures.append((root / "host-ui-tree.txt", "missing host foreground MINT application label"))
        if springboard_anchor.search(combined_host_tree):
            failures.append((root / "host-ui-tree.txt", "SpringBoard/home-screen host UI-tree evidence"))

if failures:
    print("artifact scan failed")
    for path, label in failures:
        print(f"{path}: {label}: <redacted>")
    sys.exit(1)

print(f"artifact scan passed: {scanned} text artifacts scanned, {image_count} image artifacts covered by OCR text")
PY
}

run_artifact_scan_self_test() {
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mint-runtime-artifact-scan.XXXXXX")"

  printf 'network summary only\nendpoint_path=/health\nstatus_class=2xx\n' \
    > "$tmp_dir/safe.txt"
  printf 'Debug spine\nmint_debug_spine_snapshot\nwizardAnswers: absent\n' \
    > "$tmp_dir/ui-tree.txt"
  printf '[{"AXLabel":"MINT","role":"AXApplication"}]\n' \
    > "$tmp_dir/host-ui-tree.txt"
  printf 'Debug spine\nmint_debug_spine_snapshot\nwizardAnswers: absent\n' \
    > "$tmp_dir/final-reset-state.ocr.txt"
  printf 'foreground: ch.mint.app\nos_native_foreground: proven_by_host_ui_tree_application_mint\ncapture_sequence: ui_tree_before_screenshot\n' \
    > "$tmp_dir/foreground-proof.txt"
  run_artifact_scan "$tmp_dir" >/dev/null

  printf 'Authorization: bearer secret\nuser@example.com\n37600 CHF\n3D0534A9-8C3A-4663-9348-106D0599E9D6\n' > "$tmp_dir/unsafe.txt"
  local unsafe_output="$tmp_dir/unsafe-output.txt"
  if run_artifact_scan "$tmp_dir" >"$unsafe_output" 2>&1; then
    rm -rf "$tmp_dir"
    fail "artifact scan self-test did not reject unsafe token marker"
  fi
  if grep -Eq 'bearer|secret|Authorization|user@example\.com|37600|3D0534A9-8C3A-4663-9348-106D0599E9D6' "$unsafe_output"; then
    rm -rf "$tmp_dir"
    fail "artifact scan self-test leaked raw forbidden value in failure output"
  fi

  rm -rf "$tmp_dir"
  log "artifact scan self-test passed"
}

run_release_workflow_scan() {
  python3 "$ROOT/tools/checks/mint_runtime_debug_release_scan.py" \
    --root "$ROOT" \
    --workflows-only
}

check_debug_route_static_contract() {
  grep -q "path: '/admin/debug-spine'" "$ROOT/apps/mobile/lib/app.dart" \
    || fail "missing /admin/debug-spine route"
  grep -q "MintDebugToolsGate" "$ROOT/apps/mobile/lib/app.dart" \
    || fail "/admin/debug-spine route is not wrapped in MintDebugToolsGate"
  grep -q "ENABLE_DEBUG_TOOLS" "$ROOT/apps/mobile/lib/screens/admin/mint_debug_tools_gate.dart" \
    || fail "MintDebugToolsGate no longer checks ENABLE_DEBUG_TOOLS"
  log "debug route static contract passed"
}

run_ci_static_only() {
  log "CI static-only mode: deterministic checks only; this is NOT iOS runtime proof"
  log "Local macOS iOS runtime proof command: tools/checks/mint_runtime_debug_tooling_gate.sh"
  "$ROOT/tools/checks/mint_debug_spine_gate.sh"
  (
    cd "$ROOT/apps/mobile"
    flutter test test/architecture/route_guard_snapshot_test.dart --reporter compact
  )
  run_artifact_scan_self_test
  run_release_workflow_scan
  check_debug_route_static_contract
  log "PASS: CI static-only checks completed without claiming iOS runtime proof"
}

scan_release_artifact_paths() {
  python3 "$ROOT/tools/checks/mint_runtime_debug_release_scan.py" \
    --root "$ROOT" \
    --artifacts "$@"
}

scrub_release_ios_build_xattrs() {
  strip_flutter_engine_cache_xattrs
  clear_extended_attributes "$ROOT/apps/mobile/build/ios"
  clear_extended_attributes "$ROOT/apps/mobile/.dart_tool/flutter_build"
  strip_norsrc_bundle "$ROOT/apps/mobile/build/ios/Release-iphoneos/Flutter.framework"
  strip_norsrc_bundle "$ROOT/apps/mobile/build/ios/Release-iphoneos/App.framework"
  strip_norsrc_bundle "$ROOT/apps/mobile/build/ios/Profile-iphoneos/Flutter.framework"
  strip_norsrc_bundle "$ROOT/apps/mobile/build/ios/Profile-iphoneos/App.framework"
}

build_and_scan_ios_mode() {
  local mode="$1"
  local app_path="$ROOT/apps/mobile/build/ios/iphoneos/Runner.app"
  log "building local iOS $mode Runner.app artifact with admin/debug flags disabled"
  scrub_release_ios_build_xattrs
  (
    cd "$ROOT/apps/mobile"
    CODE_SIGNING_ALLOWED=NO flutter build ios "--$mode" --no-codesign \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=ENABLE_ADMIN=0 \
      --dart-define=ENABLE_DEBUG_TOOLS=0
  )
  [ -d "$app_path" ] || fail "iOS $mode build did not produce $app_path"
  scan_release_artifact_paths "$app_path"
}

run_release_scan_only() {
  log "release/profile scan: production workflows plus local iOS no-codesign artifacts or supplied artifact paths"
  run_release_workflow_scan

  if [ -n "${MINT_RELEASE_SCAN_PATHS:-}" ]; then
    # shellcheck disable=SC2086
    scan_release_artifact_paths $MINT_RELEASE_SCAN_PATHS
    log "PASS: release/profile scan completed using MINT_RELEASE_SCAN_PATHS"
    return 0
  fi

  local modes="${MINT_RELEASE_SCAN_BUILD_MODES:-release profile}"
  local mode
  for mode in $modes; do
    case "$mode" in
      release|profile)
        build_and_scan_ios_mode "$mode"
        ;;
      *)
        fail "unsupported MINT_RELEASE_SCAN_BUILD_MODES entry: $mode"
        ;;
    esac
  done
  log "PASS: release/profile scan completed"
}

extract_screenshot_ocr_text() {
  local evidence_dir="$1"
  command -v swift >/dev/null 2>&1 || fail "swift is required for Vision OCR screenshot extraction"
  local found=0
  while IFS= read -r image_path; do
    found=1
    local output_path="${image_path%.*}.ocr.txt"
    /usr/bin/swift - "$image_path" "$output_path" <<'SWIFT'
import AppKit
import Foundation
import Vision

let args = CommandLine.arguments
let imageURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

guard let image = NSImage(contentsOf: imageURL),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
  fputs("failed to load screenshot for OCR\n", stderr)
  exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
  try handler.perform([request])
  let lines = (request.results ?? []).compactMap { observation in
    observation.topCandidates(1).first?.string
  }
  try (lines.joined(separator: "\n") + "\n").write(
    to: outputURL,
    atomically: true,
    encoding: .utf8
  )
  if lines.isEmpty {
    fputs("OCR returned no text for screenshot\n", stderr)
    exit(1)
  }
} catch {
  fputs("screenshot OCR failed: \(error)\n", stderr)
  exit(1)
}
SWIFT
  done < <(find "$evidence_dir" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print)
  [ "$found" -eq 1 ] || fail "no screenshot artifacts found for OCR extraction"
}

extract_evidence_json() {
  local evidence_dir="$1"
  shift
  python3 - "$evidence_dir" "$@" <<'PY'
from pathlib import Path
import json
import sys

out_dir = Path(sys.argv[1])
logs = [Path(p) for p in sys.argv[2:]]
required = {"before_reset", "after_reset", "after_relaunch"}
seen = {}
prefix = "MINT_RUNTIME_DEBUG_EVIDENCE "

for label in required:
    path = out_dir / f"debug-spine-{label}.json"
    if path.exists():
        seen[label] = json.loads(path.read_text(encoding="utf-8"))

for log in logs:
    for raw_line in log.read_text(encoding="utf-8", errors="ignore").splitlines():
        marker = raw_line.find(prefix)
        if marker < 0:
            continue
        line = raw_line[marker + len(prefix):]
        label, payload = line.split(" ", 1)
        data = json.loads(payload)
        (out_dir / f"debug-spine-{label}.json").write_text(
            json.dumps(data, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        seen[label] = data

missing = required.difference(seen)
if missing:
    print(f"missing evidence labels: {sorted(missing)}", file=sys.stderr)
    sys.exit(1)

for label, data in seen.items():
    residue = data.get("residue", {})
    network = residue.get("networkSummary", {})
    if not isinstance(network, dict):
        print(f"{label}: networkSummary missing", file=sys.stderr)
        sys.exit(1)
    if network.get("status") != "recording":
        print(f"{label}: networkSummary not recording", file=sys.stderr)
        sys.exit(1)
    if network.get("forbiddenMatchCount", 0) != 0:
        print(f"{label}: forbidden network match found", file=sys.stderr)
        sys.exit(1)
    for entry in network.get("entries", []):
        if sorted(entry.keys()) != ["count", "endpoint_path", "forbidden_match", "method", "status_class"]:
            print(f"{label}: network entry contains non-redacted fields", file=sys.stderr)
            sys.exit(1)

for clean_label in ("after_reset", "after_relaunch"):
    residue = seen[clean_label].get("residue", {})
    wizard = residue.get("wizardAnswers", {})
    budget_inputs = residue.get("budgetInputs", {})
    account = residue.get("accountHandoff", {})
    install_purge = residue.get("installSecurePurge", {})
    owned_purge = residue.get("ownedSecurePurge", {})
    checks = [
        wizard.get("state") == "absent",
        wizard.get("keyCount") == 0,
        wizard.get("corrupt") is False,
        wizard.get("plainSensitiveKeyCount") == 0,
        budget_inputs.get("state") == "absent",
        budget_inputs.get("corrupt") is False,
        residue.get("budgetOverrides", {}).get("state") == "absent",
        residue.get("anonymousMessages", {}).get("count") == 0,
        residue.get("anonymousConversations", {}).get("count") == 0,
        residue.get("currentUserConversations", {}).get("count") == 0,
        residue.get("heldAnonymousDiagnostic", {}).get("present") is False,
        account.get("choice") == "none",
        account.get("hasLocalDataOwner") is False,
        account.get("migratedFlagCount") == 0,
        account.get("syncPendingFlagCount") == 0,
        account.get("cloudSyncLocalMode") is False,
        isinstance(install_purge.get("pending"), bool),
        isinstance(owned_purge.get("pending"), bool),
        residue.get("keychain", {}).get("status") == "keychain_reset_by_gate_when_true_fresh",
    ]
    if not all(checks):
        print(f"{clean_label}: reset/relaunch residue still present", file=sys.stderr)
        sys.exit(1)

print("extracted evidence JSON: " + ", ".join(sorted(seen)))
PY
}

run_patrol_leg() {
  local leg="$1"
  local log_file="$2"
  local run_id="$3"
  local hold_seconds="$4"
  local attempt
  for attempt in 1 2; do
    if (
      cd "$ROOT/apps/mobile"
      export COPYFILE_DISABLE=1
      PATROL_ANALYTICS_ENABLED=false patrol test \
        -d "$DEVICE_NAME" \
        -t test/patrol/mint_runtime_debug_gate_test.dart \
        --no-uninstall \
        --bundle-id "$BUNDLE_ID" \
        --dart-define=API_BASE_URL="$API_BASE_URL" \
        --dart-define=MINT_DISABLE_BETA_MODAL=true \
        --dart-define=MINT_E2E_MINT2_FIRST_EXPERIENCE=true \
        --dart-define=MINT_E2E_PROOF_ANCHORS=true \
        --dart-define=ENABLE_ADMIN=1 \
        --dart-define=ENABLE_DEBUG_TOOLS=1 \
        --dart-define=MINT_RUNTIME_DEBUG_EVIDENCE=true \
        --dart-define=MINT_RUNTIME_DEBUG_LEG="$leg" \
        --dart-define=MINT_RUNTIME_DEBUG_RUN_ID="$run_id" \
        --dart-define=MINT_RUNTIME_DEBUG_FOREGROUND_HOLD_SECONDS="$hold_seconds"
    ) 2>&1 | tee "$log_file"; then
      return 0
    fi

    if [ "$attempt" -lt 2 ] && grep -Eq 'xcodebuild exited with code 65|TEST BUILD FAILED' "$log_file"; then
      log "retrying Patrol $leg leg after xcodebuild 65 build failure"
      scrub_patrol_ios_build_xattrs
      continue
    fi
    return 1
  done
}

write_summary() {
  local exit_status="$1"
  local udid_hash="unresolved"
  if [ -n "${DEVICE_UDID:-}" ]; then
    udid_hash="$(printf '%s' "$DEVICE_UDID" | shasum -a 256 | awk '{print $1}')"
  fi
  {
    echo "run_id: $RUN_ID"
    echo "timestamp_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo: $ROOT"
    echo "branch: $(git -C "$ROOT" branch --show-current)"
    echo "head: $(git -C "$ROOT" rev-parse --short HEAD)"
    echo "simulator: $DEVICE_NAME"
    echo "device_udid: redacted"
    echo "device_udid_sha256: $udid_hash"
    echo "api_base_url: $API_BASE_URL"
    echo "exit_status: $exit_status"
    echo "evidence: $ARTIFACT_ROOT"
    echo "commands:"
    echo "  - xcrun simctl keychain <redacted-udid> reset"
    echo "  - patrol test --dart-define=MINT_RUNTIME_DEBUG_LEG=reset"
    echo "  - xcrun simctl terminate <redacted-udid> $BUNDLE_ID"
    echo "  - patrol test --dart-define=MINT_RUNTIME_DEBUG_LEG=relaunch"
    echo "  - wait for Patrol foreground-ready marker"
    echo "  - idb ui describe-all before screenshot"
    echo "  - xcrun simctl io screenshot"
    echo "  - Vision OCR final-reset-state.png"
    echo "remaining_gap: physical iPhone/TestFlight/iCloud restore is not closed by this simulator gate"
  } > "$ARTIFACT_ROOT/run-summary.txt"
}

check_single_mode

if [ "$CI_STATIC_ONLY" -eq 1 ]; then
  run_ci_static_only
  exit 0
fi

if [ "$RELEASE_SCAN_ONLY" -eq 1 ]; then
  run_release_scan_only
  exit 0
fi

if [ -n "$SCAN_ONLY" ]; then
  extract_evidence_json "$SCAN_ONLY"
  run_artifact_scan "$SCAN_ONLY"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  usage
  exit 0
fi

require_patrol

mkdir -p "$ARTIFACT_ROOT"
exec > >(tee "$ARTIFACT_ROOT/run.log") 2>&1
trap 'status=$?; if [ "$status" -ne 0 ]; then write_summary "$status"; fi' EXIT

log "evidence: $ARTIFACT_ROOT"
log "resolving exact simulator"
DEVICE_UDID="$(resolve_device_udid)"
log "device: $DEVICE_NAME (udid redacted)"

log "true-fresh simulator reset"
xcrun simctl shutdown "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b >/dev/null
xcrun simctl keychain "$DEVICE_UDID" reset
xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

RESET_LOG="$ARTIFACT_ROOT/patrol-reset.log"
RELAUNCH_LOG="$ARTIFACT_ROOT/patrol-relaunch.log"

log "Patrol reset leg"
scrub_patrol_ios_build_xattrs
run_patrol_leg "reset" "$RESET_LOG" "$RUN_ID-reset" "0"
copy_container_evidence "$ARTIFACT_ROOT" "$DEVICE_UDID" before_reset after_reset

log "terminating app before cold relaunch leg"
xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

log "Patrol relaunch leg"
scrub_patrol_ios_build_xattrs
run_patrol_leg "relaunch" "$RELAUNCH_LOG" "$RUN_ID-relaunch" "$FOREGROUND_HOLD_SECONDS" &
RELAUNCH_PID=$!
wait_for_foreground_ready "$DEVICE_UDID" "$RUN_ID-relaunch" "$RELAUNCH_PID"
capture_host_foreground_artifacts "$ARTIFACT_ROOT" "$DEVICE_UDID" "$RUN_ID-relaunch"
if ! wait "$RELAUNCH_PID"; then
  fail "Patrol relaunch leg failed after foreground capture"
fi
copy_container_evidence "$ARTIFACT_ROOT" "$DEVICE_UDID" after_relaunch

log "extracting Debug Spine JSON evidence"
extract_evidence_json "$ARTIFACT_ROOT" "$RESET_LOG" "$RELAUNCH_LOG"

log "extracting screenshot OCR text"
extract_screenshot_ocr_text "$ARTIFACT_ROOT"

log "scanning evidence artifacts"
write_summary 0
run_artifact_scan "$ARTIFACT_ROOT" "$DEVICE_UDID" | tee "$ARTIFACT_ROOT/artifact-scan.log"

log "PASS: Mint runtime debug tooling gate completed"
trap - EXIT
