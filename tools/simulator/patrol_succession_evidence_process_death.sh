#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --device <UDID> --bundle-id <bundle> --sha <40-hex> --artifacts <dir>" >&2
}

die() {
  echo "patrol_succession_evidence_process_death: $*" >&2
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

[[ "$device" =~ ^[0-9A-Fa-f-]{36}$ ]] || die "--device must be one simulator UDID"
[[ "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]] || die "--bundle-id is invalid"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "--sha must be a 40-hex commit"
[[ -n "$artifacts" ]] || die "--artifacts is required"

repo_root="$(git rev-parse --show-toplevel)"
head_sha="$(git -C "$repo_root" rev-parse HEAD)"
[[ "$sha" == "$head_sha" ]] || die "--sha must equal current HEAD ($head_sha)"
evidence_root="$repo_root/.planning/runtime-evidence/phase-37/succession-01"
[[ -d "$evidence_root" && ! -L "$evidence_root" ]] \
  || die "G1 SUCCESSION evidence root must be one physical directory"
artifacts="$(python3 - "$artifacts" <<'PY'
import sys
from pathlib import Path
print(Path(sys.argv[1]).expanduser().resolve(strict=False))
PY
)"
[[ "$(dirname "$artifacts")" == "$evidence_root" ]] \
  || die "artifacts path must be under the G1 SUCCESSION evidence root"
artifact_name="$(basename "$artifacts")"
[[ "$artifact_name" =~ ^runtime-${sha:0:12}-[0-9]{8}T[0-9]{6}Z$ ]] \
  || die "artifacts basename must bind short SHA and UTC timestamp (runtime-${sha:0:12}-YYYYMMDDTHHMMSSZ)"
upstream_ref="$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" \
  || die "the current branch has no configured upstream"
git -C "$repo_root" merge-base --is-ancestor "$sha" "$upstream_ref" \
  || die "--sha is not present on the configured upstream"
[[ "$sha" == "$(git -C "$repo_root" rev-parse "$upstream_ref")" ]] \
  || die "--sha must equal the configured upstream head"
[[ -z "$(git -C "$repo_root" status --porcelain)" ]] \
  || die "runtime requires a clean worktree"

mobile_root="$repo_root/apps/mobile"
civil_guard_seed_contract="apps/mobile/integration_test/g1_succession_civil_guard_seed_patrol_test.dart"
native_present_contract="apps/mobile/integration_test/g1_succession_native_present_patrol_test.dart"
absent_write_contract="apps/mobile/integration_test/g1_succession_absent_write_patrol_test.dart"
cold_read_contract="apps/mobile/integration_test/g1_succession_cold_read_patrol_test.dart"
civil_guard_seed_target="apps/mobile/test/patrol/g1_succession_civil_guard_seed_runtime_test.dart"
native_present_target="apps/mobile/test/patrol/g1_succession_native_present_runtime_test.dart"
absent_write_target="apps/mobile/test/patrol/g1_succession_absent_write_runtime_test.dart"
cold_read_target="apps/mobile/test/patrol/g1_succession_cold_read_runtime_test.dart"
runtime_support="apps/mobile/integration_test/support/g1_succession_runtime_contract.dart"
flag_off_flow="apps/mobile/.maestro/g1_succession_flag_off.yaml"
flag_on_flow="apps/mobile/.maestro/g1_succession_progressive.yaml"
orchestrator_path="tools/simulator/patrol_succession_evidence_process_death.sh"
maestro_wrapper="tools/simulator/maestro_env.sh"
generated_patrol_bundle="apps/mobile/test/patrol/test_bundle.dart"
runtime_paths=(
  "$civil_guard_seed_contract"
  "$native_present_contract"
  "$absent_write_contract"
  "$cold_read_contract"
  "$civil_guard_seed_target"
  "$native_present_target"
  "$absent_write_target"
  "$cold_read_target"
  "$runtime_support"
  "$flag_off_flow"
  "$flag_on_flow"
  "apps/mobile/lib/app.dart"
  "apps/mobile/lib/models/coach_profile.dart"
  "apps/mobile/lib/providers/coach_profile_provider.dart"
  "apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart"
  "apps/mobile/lib/services/feature_flags.dart"
  "apps/mobile/lib/services/report_persistence_service.dart"
  "apps/mobile/lib/widgets/coach/succession_evidence_quest.dart"
  "tools/checks/tests/test_g1_succession_runtime_orchestrator.py"
  "tools/checks/mint_os_doctor.py"
  "tools/checks/patrol_tooling_guard.py"
  "$orchestrator_path"
  "$maestro_wrapper"
)

for runtime_path in "${runtime_paths[@]}"; do
  [[ -f "$repo_root/$runtime_path" ]] || die "runtime contract is missing: $runtime_path"
  git -C "$repo_root" ls-files --error-unmatch -- "$runtime_path" >/dev/null \
    || die "runtime contract is not tracked by HEAD: $runtime_path"
done

grep -Fq 'successionWriterPid' "$repo_root/$runtime_support" \
  || die "runtime support lacks the writer PID witness"
grep -Fq 'successionWriterStateWitness' "$repo_root/$runtime_support" \
  || die "runtime support lacks the exact state witness"
grep -Fq 'pid' "$repo_root/$cold_read_contract" \
  || die "cold reader lacks a distinct-process assertion"

exact_sha_guard() {
  git -C "$repo_root" diff --quiet "$sha" -- \
    || die "runtime contract differs from --sha HEAD"
}
exact_sha_guard
[[ -z "$(git -C "$repo_root" ls-files --others --exclude-standard -- apps/mobile tools/simulator)" ]] \
  || die "untracked runtime files make --sha evidence ambiguous"

verify_maestro_contract() {
  python3 - "$repo_root/$flag_off_flow" "$repo_root/$flag_on_flow" <<'PY'
import sys
from pathlib import Path

off = Path(sys.argv[1]).read_text(encoding="utf-8")
on = Path(sys.argv[2]).read_text(encoding="utf-8")

def require_prepared_route_flow(flow, label):
    for forbidden in ("- stopApp", "- launchApp:", "clearState:", "- openLink:"):
        if forbidden in flow:
            raise SystemExit(
                f"{label} has forbidden in prepared Maestro flow: {forbidden}"
            )
    lines = flow.split("---", 1)[1].splitlines()
    while lines and (not lines[0].strip() or lines[0].lstrip().startswith("#")):
        lines.pop(0)
    commands = "\n".join(lines)
    required_start = (
        '- extendedWaitUntil:\n'
        '    visible:\n'
        '      id: "property_market_value_input"\n'
        '    timeout: 20000\n'
        '- assertVisible:\n'
        '    id: "property_market_value_input"'
    )
    if not commands.startswith(required_start):
        raise SystemExit(
            f"{label} must start from the prepared property route with wait then assertion"
        )

require_prepared_route_flow(off, "flag-off")
require_prepared_route_flow(on, "flag-on")

def require_ordered(flow, label, markers):
    cursor = 0
    for marker in markers:
        position = flow.find(marker, cursor)
        if position < 0:
            raise SystemExit(f"{label} flow lacks ordered marker {marker!r}")
        cursor = position + len(marker)

for needle in ("assertVisible", "succession_reference_quest_flag_off"):
    if needle not in off:
        raise SystemExit(f"flag-off flow lacks {needle}")
require_ordered(
    off,
    "flag-off",
    (
        'id: "patrimoine_save_cta"',
        '- scrollUntilVisible:\n    element:\n      id: "succession_reference_quest_flag_off"',
        'direction: DOWN',
        '- assertVisible:\n    id: "succession_reference_quest_flag_off"',
    ),
)
for needle in (
    "succession_reference_quest",
    "succession_civil_status_guard",
    "succession_civil_status_confirm",
    "civil_status_single_choice",
    "household_save_cta",
    "succession_instrument_will_question",
):
    if needle not in on:
        raise SystemExit(f"flag-on flow lacks {needle}")
require_ordered(
    on,
    "flag-on",
    (
        'id: "patrimoine_save_cta"',
        '- scrollUntilVisible:\n    element:\n      id: "succession_civil_status_guard"',
        'direction: DOWN',
        '- assertVisible:\n    id: "succession_reference_quest"',
        '- assertVisible:\n    id: "succession_civil_status_guard"',
        '- tapOn:\n    id: "succession_civil_status_confirm"',
    ),
)
PY
}
verify_maestro_contract

verify_patrol_contracts() {
  python3 - \
    "$repo_root/$civil_guard_seed_contract" \
    "$repo_root/$native_present_contract" \
    "$repo_root/$absent_write_contract" \
    "$repo_root/$cold_read_contract" \
    "$repo_root/$civil_guard_seed_target" \
    "$repo_root/$native_present_target" \
    "$repo_root/$absent_write_target" \
    "$repo_root/$cold_read_target" <<'PY'
import sys
from pathlib import Path

seed, present, writer, reader, *wrappers = [
    Path(value).read_text(encoding="utf-8") for value in sys.argv[1:]
]
for needle in (
    "clearDiagnostic()",
    "saveAnswers",
    "'q_civil_status': 'partenariat'",
    "isMiniOnboardingCompleted()",
    "persisted['q_civil_status']",
    "CoachProfile.fromWizardAnswers(persisted)",
    "civilStatusNeedsConfirmation",
):
    if needle not in seed:
        raise SystemExit(f"civil-guard seed contract lacks {needle}")
if "setMiniOnboardingCompleted" in seed:
    raise SystemExit("civil-guard seed must not complete onboarding")
for needle in (
    "clearDiagnostic()",
    "succession_instrument_will_source_date",
    "succession_instrument_will_legal_year",
    ".enterText(",
    "EstateEvidenceRoot.fromJsonString",
    "EstateInstrumentSlotState.confirmedPresent",
):
    if needle not in present:
        raise SystemExit(f"native-present contract lacks {needle}")
for needle in (
    "succession_instrument_will_absent",
    "succession_answer_saved",
    "successionWriterPid",
    "successionWriterStateWitness",
):
    if needle not in writer:
        raise SystemExit(f"absent writer lacks {needle}")
last_saved = writer.rindex("succession_answer_saved")
next_positions = []
offset = 0
while True:
    position = writer.find("succession_next_question", offset)
    if position < 0:
        break
    next_positions.append(position)
    offset = position + 1
if not next_positions or any(position > last_saved for position in next_positions):
    raise SystemExit("absent writer must stop at the durable acknowledgement before process death")
if "succession_instrument_inheritancePact_question" in writer:
    raise SystemExit("absent writer must not render the post-death inheritance-pact question")
for needle in (
    "expect(pid, isNot(writerPid))",
    "successionWriterStateWitness",
    "EstateInstrumentSlotState.confirmedAbsent",
    "succession_instrument_inheritancePact_question",
):
    if needle not in reader:
        raise SystemExit(f"cold reader lacks {needle}")
expected_imports = (
    "g1_succession_civil_guard_seed_patrol_test.dart",
    "g1_succession_native_present_patrol_test.dart",
    "g1_succession_absent_write_patrol_test.dart",
    "g1_succession_cold_read_patrol_test.dart",
)
for wrapper, expected in zip(wrappers, expected_imports):
    if expected not in wrapper:
        raise SystemExit(f"Patrol wrapper does not bind {expected}")
PY
}
verify_patrol_contracts

for command_name in git python3 tar find shasum stat cmp xcrun xcodebuild flutter codesign xattr plutil; do
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required"
done
patrol_bin="${PATROL_BIN:-$HOME/.pub-cache/bin/patrol}"
[[ -x "$patrol_bin" ]] || die "Patrol CLI is not executable at $patrol_bin"
maestro_runner="$repo_root/$maestro_wrapper"
[[ -r "$maestro_runner" ]] || die "Maestro wrapper is missing"
xcrun simctl list devices booted | grep -Fq -- "$device" \
  || die "requested iOS Simulator is not booted"

[[ ! -e "$artifacts" && ! -L "$artifacts" ]] \
  || die "artifacts directory must not already exist"
mkdir -p "$artifacts"
artifacts="$(cd "$artifacts" && pwd -P)"
chmod 700 "$artifacts"

private_root="$(mktemp -d "${TMPDIR:-/tmp}/mint-g1-succession-${sha:0:12}.XXXXXX")"
private_root="$(cd "$private_root" && pwd -P)"
external_build="$private_root/patrol-build"
mkdir -p "$external_build"
mobile_build="$mobile_root/build"
build_backup="$mobile_root/.dart_tool/mint-patrol-g1-succession-build-backup-$sha"
original_build_present=false
build_isolation_enabled=false
restoration_status=pending
cleanup_status=pending
generated_bundle_armed=false
runtime_completed=false
writer_reader_distinct_pid_verified=false
state_preserved_across_process_death=false
no_data_erase_between_writer_reader=false
production_source_exported_exact=false
production_source_physical=false
flag_off_route_anchor_verified=false
flag_off_marker_verified=false
flag_on_civil_return_verified=false
civil_guard_seed_verified=false
seed_post_terminate_witness_verified=false
seed_post_overlay_witness_verified=false
seed_overlay_container_identity_verified=false
seed_witnesses_equal_verified=false
seed_state_preserved_to_maestro=false
seed_witness_container_identity=""
seed_post_terminate_container_identity=""
synthetic_data_only=true
raw_runtime_outputs_retained=false

remove_generated_bundle() {
  if [[ "$generated_bundle_armed" == true && (-e "$repo_root/$generated_patrol_bundle" || -L "$repo_root/$generated_patrol_bundle") ]]; then
    [[ -f "$repo_root/$generated_patrol_bundle" && ! -L "$repo_root/$generated_patrol_bundle" ]] \
      || return 1
    rm -f -- "$repo_root/$generated_patrol_bundle" || return 1
  fi
  generated_bundle_armed=false
}

restore_build_isolation() {
  [[ "$build_isolation_enabled" == true ]] || return 0
  local failed=0
  if [[ -L "$mobile_build" ]]; then
    [[ "$(readlink "$mobile_build")" == "$external_build" ]] || failed=1
    ((failed == 0)) && rm -- "$mobile_build" || true
  elif [[ -e "$mobile_build" ]]; then
    failed=1
  fi
  if [[ "$original_build_present" == true ]]; then
    [[ ! -e "$mobile_build" && ! -L "$mobile_build" && -d "$build_backup" && ! -L "$build_backup" ]] \
      || failed=1
    ((failed == 0)) && mv -- "$build_backup" "$mobile_build" || true
  else
    [[ ! -e "$build_backup" && ! -L "$build_backup" ]] || failed=1
  fi
  if ((failed == 0)); then
    restoration_status=restored
    build_isolation_enabled=false
    return 0
  fi
  restoration_status=failed
  return 1
}

cleanup() {
  local status=$?
  trap - EXIT HUP INT TERM
  local failed=0
  remove_generated_bundle || failed=1
  restore_build_isolation || failed=1
  rm -rf -- "$private_root" || failed=1
  if ((failed == 0)); then
    cleanup_status=passed
  else
    cleanup_status=failed
  fi
  if ((status == 0 && failed != 0)); then
    status=2
  fi
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

[[ ! -e "$repo_root/$generated_patrol_bundle" && ! -L "$repo_root/$generated_patrol_bundle" ]] \
  || die "pre-existing generated Patrol bundle is ambiguous"

mkdir -p "$mobile_root/.dart_tool"
[[ ! -e "$build_backup" && ! -L "$build_backup" ]] || die "build backup collision"
build_isolation_enabled=true
if [[ -e "$mobile_build" || -L "$mobile_build" ]]; then
  [[ -d "$mobile_build" && ! -L "$mobile_build" ]] \
    || die "pre-existing build path is not a physical directory"
  original_build_present=true
  mv "$mobile_build" "$build_backup"
fi
ln -s "$external_build" "$mobile_build"

python3 - "$device" >"$artifacts/device.sha256" <<'PY'
import hashlib
import sys
print(hashlib.sha256(sys.argv[1].encode()).hexdigest())
PY

: >"$artifacts/source-manifest.sha256"
for runtime_path in "${runtime_paths[@]}"; do
  printf '%s  %s\n' \
    "$(shasum -a 256 "$repo_root/$runtime_path" | awk '{print $1}')" \
    "$runtime_path" >>"$artifacts/source-manifest.sha256"
done

sanitize_log() {
  local raw="$1"
  local retained="$2"
  python3 - "$raw" "$retained" "$repo_root" "$HOME" "$device" "$private_root" <<'PY'
import re
import sys
from pathlib import Path

raw, retained, repo, home, device, private = sys.argv[1:]
text = Path(raw).read_text(encoding="utf-8", errors="replace")
for value, token in (
    (repo, "REDACTED_REPO"),
    (home, "REDACTED_HOME"),
    (device, "REDACTED_SIMULATOR_UDID"),
    (private, "REDACTED_PRIVATE_TEMP"),
):
    if value:
        text = text.replace(value, token)
text = re.sub(r"/(?:private/)?var/folders/[^\s\"'<>]+", "REDACTED_PRIVATE_TEMP", text)
text = re.sub(r"/(?:private/)?tmp/[^\s\"'<>]+", "REDACTED_PRIVATE_TEMP", text)
Path(retained).write_text(text, encoding="utf-8")
PY
  rm -f -- "$raw"
}

run_logged() {
  local name="$1"
  shift
  local raw="$private_root/$name.raw.log"
  local status
  set +e
  "$@" >"$raw" 2>&1
  status=$?
  set -e
  sanitize_log "$raw" "$artifacts/$name.log"
  ((status == 0)) || exit "$status"
}

# SEED_TERMINATE_CLASSIFIER_BEGIN
seed_terminate_is_already_dead() {
  local status="$1"
  local raw="$2"
  ((status == 3)) \
    && grep -Fq 'domain=NSPOSIXErrorDomain, code=3' "$raw" \
    && grep -Fxq 'found nothing to terminate' "$raw"
}
# SEED_TERMINATE_CLASSIFIER_END

terminate_seed_app_idempotently() {
  local name="$1"
  local raw="$private_root/$name.raw.log"
  local status
  local already_dead=false
  set +e
  xcrun simctl terminate "$device" "$bundle_id" >"$raw" 2>&1
  status=$?
  set -e
  if seed_terminate_is_already_dead "$status" "$raw"; then
    already_dead=true
  fi
  sanitize_log "$raw" "$artifacts/$name.log"
  if ((status == 0)) || [[ "$already_dead" == true ]]; then
    return 0
  fi
  exit "$status"
}

reset_external_build() {
  [[ -L "$mobile_build" && "$(readlink "$mobile_build")" == "$external_build" ]] \
    || die "Patrol build isolation drifted"
  rm -rf -- "$external_build"
  mkdir -p "$external_build"
  [[ ! -e "$repo_root/$generated_patrol_bundle" && ! -L "$repo_root/$generated_patrol_bundle" ]] \
    || die "generated Patrol bundle exists before stage build"
  generated_bundle_armed=true
}

patrol_app=""
patrol_host=""
patrol_xctestrun=""
inspect_patrol_build() {
  local expected_target="$1"
  local products="$external_build/ios_integ/Build/Products"
  patrol_app="$(find "$products" -type d -path '*/Debug-iphonesimulator/Runner.app' -print -quit 2>/dev/null || true)"
  patrol_host="$(find "$products" -type d -path '*/Debug-iphonesimulator/RunnerUITests-Runner.app' -print -quit 2>/dev/null || true)"
  patrol_xctestrun="$(find "$products" -maxdepth 2 -type f -name '*.xctestrun' -print -quit 2>/dev/null || true)"
  [[ -d "$patrol_app" && -d "$patrol_host" && -f "$patrol_xctestrun" ]] \
    || die "Patrol build products are incomplete"
  [[ "$(plutil -extract CFBundleIdentifier raw -o - "$patrol_app/Info.plist")" == "$bundle_id" ]] \
    || die "Patrol app bundle id drifted"
  [[ "$(plutil -extract CFBundleIdentifier raw -o - "$patrol_host/Info.plist")" == "$bundle_id.RunnerUITests.xctrunner" ]] \
    || die "Patrol host bundle id drifted"
  python3 - "$repo_root/$generated_patrol_bundle" "$expected_target" <<'PY'
import sys
from pathlib import Path
source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = sys.argv[2].rsplit("/", 1)[-1]
if source.count(target) != 1:
    raise SystemExit("generated Patrol bundle is not the exact single target")
PY
}

summarize_xcresult() {
  local stage="$1"
  local result_bundle="$2"
  local raw="$private_root/$stage-xcresult.raw.json"
  local stderr="$private_root/$stage-xcresult.raw.log"
  set +e
  xcrun xcresulttool get test-results summary --path "$result_bundle" --compact \
    >"$raw" 2>"$stderr"
  local status=$?
  set -e
  sanitize_log "$stderr" "$artifacts/$stage-xcresult-tool.log"
  ((status == 0)) || exit "$status"
  python3 - "$raw" "$artifacts/$stage-xcresult-summary.sanitized.json" <<'PY'
import json
import sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
passed, failed = payload.get("passedTests"), payload.get("failedTests")
if passed != 1 or failed != 0:
    raise SystemExit(f"expected exact 1/1 PASS, got passed={passed}, failed={failed}")
Path(sys.argv[2]).write_text(
    json.dumps({"failed_tests": failed, "passed_tests": passed}, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  rm -f -- "$raw"
}

run_patrol_stage() {
  local stage="$1"
  local target="$2"
  reset_external_build
  local build_raw="$private_root/$stage-build.raw.log"
  set +e
  (cd "$mobile_root" && "$patrol_bin" --verbose build ios \
    --target "${target#apps/mobile/}" \
    --simulator --bundle-id "$bundle_id" \
    --dart-define=MINT_PATROL_CLI=true \
    --dart-define=MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION=true) \
    >"$build_raw" 2>&1
  local build_status=$?
  set -e
  sanitize_log "$build_raw" "$artifacts/$stage-build.log"
  ((build_status == 0)) || exit "$build_status"
  inspect_patrol_build "$target"
  local result_bundle="$external_build/$stage.xcresult"
  local test_raw="$private_root/$stage-test.raw.log"
  set +e
  xcodebuild test-without-building \
    -xctestrun "$patrol_xctestrun" \
    -only-testing "RunnerUITests/RunnerUITests" \
    -parallel-testing-enabled NO \
    -destination "platform=iOS Simulator,id=$device" \
    -resultBundlePath "$result_bundle" >"$test_raw" 2>&1
  local test_status=$?
  set -e
  sanitize_log "$test_raw" "$artifacts/$stage-test.log"
  ((test_status == 0)) || exit "$test_status"
  summarize_xcresult "$stage" "$result_bundle"
  remove_generated_bundle
  exact_sha_guard
}

capture_screenshot() {
  local name="$1"
  local private_image="$private_root/$name"
  xcrun simctl io "$device" screenshot "$private_image" >/dev/null
  [[ -s "$private_image" ]] || die "screenshot $name is empty"
  python3 - "$private_image" <<'PY'
import struct
import sys
from pathlib import Path
payload = Path(sys.argv[1]).read_bytes()
if len(payload) < 24 or payload[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("PNG signature or dimensions are invalid")
width, height = struct.unpack(">II", payload[16:24])
if width < 320 or height < 480:
    raise SystemExit("PNG signature or dimensions are invalid")
PY
  install -m 600 "$private_image" "$artifacts/$name"
}

reject_source_aliases() {
  local root="$1"
  python3 - "$root" <<'PY'
import os
import stat
import sys
for current, directories, files in os.walk(sys.argv[1], followlinks=False):
    for name in (*directories, *files):
        value = os.lstat(os.path.join(current, name))
        if stat.S_ISLNK(value.st_mode):
            raise SystemExit("physical archive contains a symlink")
        if stat.S_ISREG(value.st_mode) and value.st_nlink > 1:
            raise SystemExit("physical archive contains a hardlink alias")
PY
}

flag_off_app=""
flag_on_app=""
export_production_source() {
  local stage="$1"
  local root="$private_root/production-$stage"
  local archive="$private_root/production-$stage.tar"
  mkdir -p "$root"
  local raw="$private_root/production-$stage-export.raw.log"
  set +e
  git -C "$repo_root" archive --format=tar "$sha" -- apps/mobile \
    >"$archive" 2>"$raw"
  local status=$?
  set -e
  sanitize_log "$raw" "$artifacts/production-$stage-export.log"
  ((status == 0)) || exit "$status"
  printf 'stage=%s\nsource_sha=%s\narchive_sha256=%s\n' \
    "$stage" "$sha" "$(shasum -a 256 "$archive" | awk '{print $1}')" \
    >>"$artifacts/production-$stage-export.log"
  tar -xf "$archive" -C "$root"
  rm -f -- "$archive"
  # Bash 3.2 disables errexit inside command substitution. Keep this explicit:
  # otherwise the following printf can mask a failed physical-source guard.
  reject_source_aliases "$root/apps/mobile" || exit 1
  printf '%s\n' "$root/apps/mobile"
}

build_production_app() {
  local stage="$1"
  local enable_succession="$2"
  local source_root
  source_root="$(export_production_source "$stage")"
  # export_production_source runs in command substitution; set truth witnesses
  # here in the parent shell only after archive extraction and alias rejection.
  production_source_exported_exact=true
  production_source_physical=true
  local raw="$private_root/production-$stage-build.raw.log"
  set +e
  if [[ "$enable_succession" == true ]]; then
    (cd "$source_root" && flutter build ios --simulator --debug --target lib/main.dart \
      --dart-define=MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION=true) >"$raw" 2>&1
  else
    (cd "$source_root" && flutter build ios --simulator --debug --target lib/main.dart) \
      >"$raw" 2>&1
  fi
  local status=$?
  set -e
  sanitize_log "$raw" "$artifacts/production-$stage-build.log"
  ((status == 0)) || exit "$status"
  local app="$source_root/build/ios/iphonesimulator/Runner.app"
  [[ -d "$app" ]] || die "$stage production app is missing"
  [[ "$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")" == "$bundle_id" ]] \
    || die "$stage production bundle id drifted"
  run_logged "production-$stage-codesign" codesign --verify --strict --deep "$app"
  run_logged "production-$stage-xattrs" xattr -r "$app"
  if grep -Eq 'com\.apple\.(FinderInfo|ResourceFork)' "$artifacts/production-$stage-xattrs.log"; then
    die "$stage production app contains forbidden extended attributes"
  fi
  if [[ "$stage" == flag_off ]]; then flag_off_app="$app"; else flag_on_app="$app"; fi
  exact_sha_guard
}

install_production_app() {
  local stage="$1"
  local app="$2"
  run_logged "production-$stage-install" xcrun simctl install "$device" "$app"
}

prepare_maestro_route() {
  local stage="$1"
  local app="$2"
  install_production_app "$stage-prime" "$app"
  run_logged "production-$stage-uninstall" \
    xcrun simctl uninstall "$device" "$bundle_id"
  install_production_app "$stage-final" "$app"
  run_logged "production-$stage-launch" \
    xcrun simctl launch "$device" "$bundle_id"
  wait_for_landing "$stage"
  run_logged "production-$stage-openurl" \
    xcrun simctl openurl "$device" \
      "mint:///data-block/patrimoine?inputKey=q_property_market_value&returnUri=/succession"
  wait_for_property_input "$stage"
}

run_maestro() {
  local stage="$1"
  local flow="$2"
  local raw="$private_root/maestro-$stage.raw.log"
  local report="$private_root/maestro-$stage.raw.xml"
  set +e
  bash "$maestro_runner" test --udid "$device" --format JUNIT \
    --debug-output "$private_root/maestro-$stage-debug" \
    --test-output-dir "$private_root/maestro-$stage-output" \
    --output "$report" "$repo_root/$flow" >"$raw" 2>&1
  local status=$?
  set -e
  sanitize_log "$raw" "$artifacts/maestro-$stage.log"
  ((status == 0)) || exit "$status"
  [[ -s "$report" ]] || die "$stage Maestro report is missing"
  sanitize_log "$report" "$artifacts/maestro-$stage-report.sanitized.xml"
  python3 - "$artifacts/maestro-$stage-report.sanitized.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
failures = sum(int(suite.attrib.get("failures", "0")) for suite in root.iter("testsuite"))
tests = sum(int(suite.attrib.get("tests", "0")) for suite in root.iter("testsuite"))
if tests < 1 or failures != 0:
    raise SystemExit(f"invalid Maestro result tests={tests} failures={failures}")
PY
  exact_sha_guard
}

wait_for_seed_witness() {
  local stage="$1"
  local deadline=$((SECONDS + 30))
  local candidate=""
  local identity=""
  local preferences_plist=""
  local witness=""
  local status=1
  while ((SECONDS <= deadline)); do
    set +e
    candidate="$(xcrun simctl get_app_container "$device" "$bundle_id" data 2>/dev/null)"
    status=$?
    set -e
    if ((status == 0)) && [[ -n "$candidate" && -d "$candidate" && ! -L "$candidate" ]]; then
      identity="$(stat -f '%d:%i' "$candidate")"
      [[ "$identity" =~ ^[0-9]+:[0-9]+$ ]] \
        || die "$stage app data identity is invalid"
      preferences_plist="$candidate/Library/Preferences/$bundle_id.plist"
      if [[ -f "$preferences_plist" && ! -L "$preferences_plist" ]]; then
        set +e
        # SEED_WITNESS_PYTHON_BEGIN
        witness="$(python3 - "$preferences_plist" <<'PY'
import hashlib
import json
import plistlib
import sys

try:
    with open(sys.argv[1], "rb") as handle:
        preferences = plistlib.load(handle)
    raw_answers = preferences.get("flutter.wizard_answers_v2")
    answers = json.loads(raw_answers) if isinstance(raw_answers, str) else None
except (OSError, ValueError, plistlib.InvalidFileException):
    raise SystemExit(1)
if not isinstance(answers, dict):
    raise SystemExit(1)
civil_status = answers.get("q_civil_status")
birth_year = answers.get("q_birth_year")
canton = answers.get("q_canton")
mini_incomplete = (
    preferences.get("flutter.mini_onboarding_completed", False) is False
)
property_absent = "q_property_market_value" not in answers
if (
    birth_year != 1980
    or canton != "VD"
    or civil_status != "partenariat"
    or not mini_incomplete
    or not property_absent
):
    raise SystemExit(1)
selected = json.dumps({
    "miniOnboardingCompleted": False,
    "propertyMarketValuePresent": False,
    "q_birth_year": birth_year,
    "q_canton": canton,
    "q_civil_status": civil_status,
}, separators=(",", ":"), sort_keys=True)
print(json.dumps({
    "birthYearExpected": True,
    "cantonExpected": True,
    "civilStatusAmbiguous": True,
    "miniOnboardingIncomplete": True,
    "propertyMarketValueAbsent": True,
    "schemaVersion": 1,
    "selectedValuesSha256": hashlib.sha256(selected.encode()).hexdigest(),
}, separators=(",", ":"), sort_keys=True))
PY
)"
        status=$?
        # SEED_WITNESS_PYTHON_END
        set -e
        if ((status == 0)); then
          printf '%s\n' "$witness" >"$artifacts/seed-witness-$stage.json"
          chmod 600 "$artifacts/seed-witness-$stage.json"
          seed_witness_container_identity="$identity"
          return 0
        fi
      fi
    fi
    sleep 1
  done
  die "$stage did not expose the flushed civil-guard seed before timeout"
}

wait_for_landing() {
  local stage="$1"
  local deadline=$((SECONDS + 30))
  local raw="$private_root/hierarchy-$stage-landing.raw.log"
  local attempt="$private_root/hierarchy-$stage-landing-attempt.raw.log"
  local found=false
  local status=0
  local attempt_number=0
  : >"$raw"
  while ((SECONDS <= deadline)); do
    attempt_number=$((attempt_number + 1))
    set +e
    bash "$maestro_runner" --udid "$device" hierarchy --compact \
      >"$attempt" 2>&1
    status=$?
    set -e
    {
      printf '%s\n' "attempt=$attempt_number status=$status"
      cat "$attempt"
    } >>"$raw"
    if ((status == 0)) && grep -Fq 'landing_route' "$attempt"; then
      found=true
      break
    fi
    sleep 1
  done
  rm -f -- "$attempt"
  sanitize_log "$raw" "$artifacts/hierarchy-$stage-landing.log"
  [[ "$found" == true ]] \
    || die "$stage did not expose landing_route before timeout"
}

wait_for_property_input() {
  local stage="$1"
  local deadline=$((SECONDS + 30))
  local raw="$private_root/hierarchy-$stage-property.raw.log"
  local attempt="$private_root/hierarchy-$stage-property-attempt.raw.log"
  local found=false
  local status=0
  local attempt_number=0
  : >"$raw"
  while ((SECONDS <= deadline)); do
    attempt_number=$((attempt_number + 1))
    set +e
    bash "$maestro_runner" --udid "$device" hierarchy --compact \
      >"$attempt" 2>&1
    status=$?
    set -e
    {
      printf '%s\n' "attempt=$attempt_number status=$status"
      cat "$attempt"
    } >>"$raw"
    if ((status == 0)) && grep -Fq 'property_market_value_input' "$attempt"; then
      found=true
      break
    fi
    sleep 1
  done
  rm -f -- "$attempt"
  sanitize_log "$raw" "$artifacts/hierarchy-$stage-property.log"
  [[ "$found" == true ]] \
    || die "$stage did not expose property_market_value_input before timeout"
}

wait_for_succession_quest() {
  local stage="$1"
  local deadline=$((SECONDS + 30))
  local raw="$private_root/hierarchy-$stage.raw.log"
  local attempt="$private_root/hierarchy-$stage-attempt.raw.log"
  local found=false
  local status=0
  local attempt_number=0
  : >"$raw"
  while ((SECONDS <= deadline)); do
    attempt_number=$((attempt_number + 1))
    set +e
    bash "$maestro_runner" --udid "$device" hierarchy --compact \
      >"$attempt" 2>&1
    status=$?
    set -e
    {
      printf '%s\n' "attempt=$attempt_number status=$status"
      cat "$attempt"
    } >>"$raw"
    if ((status == 0)) && grep -Fq 'succession_reference_quest' "$attempt"; then
      found=true
      break
    fi
    sleep 1
  done
  rm -f -- "$attempt"
  sanitize_log "$raw" "$artifacts/hierarchy-$stage.log"
  [[ "$found" == true ]] \
    || die "$stage did not expose succession_reference_quest before timeout"
}

python3 "$repo_root/tools/checks/mint_os_doctor.py" >"$private_root/doctor.raw.log" 2>&1 \
  || { sanitize_log "$private_root/doctor.raw.log" "$artifacts/doctor.log"; exit 1; }
sanitize_log "$private_root/doctor.raw.log" "$artifacts/doctor.log"
python3 "$repo_root/tools/checks/patrol_tooling_guard.py" >"$private_root/patrol-tooling.raw.log" 2>&1 \
  || { sanitize_log "$private_root/patrol-tooling.raw.log" "$artifacts/patrol-tooling.log"; exit 1; }
sanitize_log "$private_root/patrol-tooling.raw.log" "$artifacts/patrol-tooling.log"

# Production-default proof is built from a physical exact archive with no
# succession define. It scrolls to the explicit marker rendered at the disabled
# quest insertion point, so the flag-off proof is positive and non-vacuous.
build_production_app "flag_off" false
prepare_maestro_route "flag_off" "$flag_off_app"
run_maestro "flag_off" "$flag_off_flow"
flag_off_route_anchor_verified=true
flag_off_marker_verified=true
capture_screenshot "flag-off.png"

# This is the exact production entrypoint with one test-only compile define,
# not a Patrol app. The isolated setup stage seeds an ambiguous legacy civil
# status without completing onboarding. Installing over it must preserve the
# encrypted container; unlike flag-off, this boundary must never uninstall.
build_production_app "flag_on" true
run_patrol_stage "civil_guard_seed" "$civil_guard_seed_target"
civil_guard_seed_verified=true
terminate_seed_app_idempotently "civil-guard-seed-terminate"
wait_for_seed_witness "post-terminate"
seed_post_terminate_witness_verified=true
seed_post_terminate_container_identity="$seed_witness_container_identity"
install_production_app "flag_on-seeded" "$flag_on_app"
wait_for_seed_witness "post-overlay"
seed_post_overlay_witness_verified=true
[[ "$seed_witness_container_identity" == "$seed_post_terminate_container_identity" ]] \
  || die "flag-on overlay changed the app data device/inode identity"
seed_overlay_container_identity_verified=true
cmp -s "$artifacts/seed-witness-post-terminate.json" \
  "$artifacts/seed-witness-post-overlay.json" \
  || die "flag-on overlay changed the selected seed witness"
seed_witnesses_equal_verified=true
run_logged "flag-on-seeded-launch" xcrun simctl launch "$device" "$bundle_id"
wait_for_landing "flag_on-seeded"
run_logged "flag-on-seeded-openurl" xcrun simctl openurl "$device" \
  "mint:///data-block/patrimoine?inputKey=q_property_market_value&returnUri=/succession"
wait_for_property_input "flag_on-seeded"
run_maestro "flag_on" "$flag_on_flow"
seed_state_preserved_to_maestro=true
flag_on_civil_return_verified=true
capture_screenshot "civil-return.png"

# This stage begins the independent three-stage process-death evidence chain
# and clears the setup seed through its checked-in clearDiagnostic contract.
run_patrol_stage "native_present" "$native_present_target"
install_production_app "flag_on-present" "$flag_on_app"
run_logged "flag-on-present-launch" xcrun simctl launch "$device" "$bundle_id"
run_logged "flag-on-present-openurl" xcrun simctl openurl "$device" "mint:///succession"
wait_for_succession_quest "native-present"
capture_screenshot "native-present.png"

run_patrol_stage "absent_write" "$absent_write_target"

# Make process death explicit without erasing the app data container. The
# absent writer contract stored the exact strict-root state and its PID.
run_logged "writer-launch-boundary" xcrun simctl launch "$device" "$bundle_id"
xcrun simctl terminate "$device" "$bundle_id" >"$private_root/writer-terminate.raw.log" 2>&1 \
  || { sanitize_log "$private_root/writer-terminate.raw.log" "$artifacts/writer-terminate.log"; exit 1; }
sanitize_log "$private_root/writer-terminate.raw.log" "$artifacts/writer-terminate.log"
no_data_erase_between_writer_reader=true
reset_external_build

run_patrol_stage "cold_read" "$cold_read_target"
writer_reader_distinct_pid_verified=true
state_preserved_across_process_death=true

# Reinstalling (never uninstalling) the exact flag-on production app preserves
# the cold-reader container and yields a clean-chrome deterministic screenshot.
install_production_app "flag_on-cold" "$flag_on_app"
run_logged "flag-on-cold-launch" xcrun simctl launch "$device" "$bundle_id"
run_logged "flag-on-cold-openurl" xcrun simctl openurl "$device" "mint:///succession"
wait_for_succession_quest "cold-continuation"
capture_screenshot "cold-continuation.png"

runtime_completed=true

expected_stage_artifacts=(
  civil_guard_seed-build.log
  civil_guard_seed-test.log
  civil_guard_seed-xcresult-summary.sanitized.json
  seed-witness-post-terminate.json
  seed-witness-post-overlay.json
  native_present-build.log
  native_present-test.log
  native_present-xcresult-summary.sanitized.json
  absent_write-build.log
  absent_write-test.log
  absent_write-xcresult-summary.sanitized.json
  cold_read-build.log
  cold_read-test.log
  cold_read-xcresult-summary.sanitized.json
)
for retained in "${expected_stage_artifacts[@]}"; do
  [[ -s "$artifacts/$retained" ]] || die "retained stage evidence is missing: $retained"
done

# METADATA_PYTHON_BEGIN
python3 - \
  "$artifacts/metadata.json" \
  "$sha" \
  "$bundle_id" \
  "$artifacts/device.sha256" \
  true \
  "$production_source_exported_exact" \
  "$production_source_physical" \
  "$flag_off_route_anchor_verified" \
  "$flag_off_marker_verified" \
  "$flag_on_civil_return_verified" \
  "$civil_guard_seed_verified" \
  "$seed_post_terminate_witness_verified" \
  "$seed_post_overlay_witness_verified" \
  "$seed_overlay_container_identity_verified" \
  "$seed_witnesses_equal_verified" \
  "$seed_state_preserved_to_maestro" \
  "$writer_reader_distinct_pid_verified" \
  "$state_preserved_across_process_death" \
  "$no_data_erase_between_writer_reader" \
  "$synthetic_data_only" \
  "$raw_runtime_outputs_retained" \
  "$runtime_completed" <<'PY'
import json
import sys
from pathlib import Path


def parse_bool(value: str) -> bool:
    if value == "true":
        return True
    if value == "false":
        return False
    raise ValueError(f"invalid boolean: {value!r}")


(
    metadata_path,
    source_sha,
    bundle_id,
    device_sha_path,
    pushed_sha_verified,
    source_exported_exact,
    source_physical,
    flag_off_anchor,
    flag_off_marker,
    flag_on_return,
    civil_guard_seed,
    seed_post_terminate,
    seed_post_overlay,
    seed_overlay_identity,
    seed_witnesses_equal,
    seed_preserved_to_maestro,
    distinct_pid,
    state_preserved,
    no_data_erase,
    synthetic_only,
    raw_outputs_retained,
    completed,
) = sys.argv[1:]
payload = {
    "schemaVersion": 1,
    "caseId": "G1-SUCCESSION-01",
    "sourceSha": source_sha,
    "bundleId": bundle_id,
    "deviceSha256": Path(device_sha_path).read_text().strip(),
    "pushedShaVerified": parse_bool(pushed_sha_verified),
    "productionSourceMode": "git_archive_physical",
    "productionSourceExportedExact": parse_bool(source_exported_exact),
    "productionSourcePhysical": parse_bool(source_physical),
    "flagOffRouteAnchorVerified": parse_bool(flag_off_anchor),
    "flagOffExplicitMarkerVerified": parse_bool(flag_off_marker),
    "flagOnCivilReturnVerified": parse_bool(flag_on_return),
    "civilGuardSeedVerified": parse_bool(civil_guard_seed),
    "seedPostTerminateWitnessVerified": parse_bool(seed_post_terminate),
    "seedPostOverlayWitnessVerified": parse_bool(seed_post_overlay),
    "seedOverlayContainerIdentityVerified": parse_bool(seed_overlay_identity),
    "seedWitnessesEqualVerified": parse_bool(seed_witnesses_equal),
    "seedStatePreservedToMaestro": parse_bool(seed_preserved_to_maestro),
    "setupPatrolStages": ["civil_guard_seed"],
    "patrolStages": ["native_present", "absent_write", "cold_read"],
    "writerReaderDistinctPidVerified": parse_bool(distinct_pid),
    "statePreservedAcrossProcessDeath": parse_bool(state_preserved),
    "noDataEraseBetweenWriterReader": parse_bool(no_data_erase),
    "syntheticDataOnly": parse_bool(synthetic_only),
    "rawRuntimeOutputsRetained": parse_bool(raw_outputs_retained),
    "runtimeCompleted": parse_bool(completed),
    "cleanupStatus": "pending_until_exit",
    "restorationStatus": "pending_until_exit",
}
Path(metadata_path).write_text(
    json.dumps(payload, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
# METADATA_PYTHON_END

python3 - "$artifacts" <<'PY'
import hashlib
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
images = {}
for path in sorted(root.glob("*.png")):
    images[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
(root / "screenshot-sha256.json").write_text(json.dumps(images, indent=2, sort_keys=True) + "\n")
PY

restore_build_isolation || die "build restoration failed"
remove_generated_bundle || die "generated Patrol bundle cleanup failed"
rm -rf -- "$private_root" || die "private runtime cleanup failed"
cleanup_status=passed
trap - EXIT HUP INT TERM
python3 - "$artifacts/metadata.json" "$cleanup_status" "$restoration_status" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["cleanupStatus"] = sys.argv[2]
payload["restorationStatus"] = sys.argv[3]
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY

python3 - "$artifacts" <<'PY'
import hashlib
import sys
from pathlib import Path
root = Path(sys.argv[1])
lines = []
for path in sorted(root.iterdir(), key=lambda value: value.name):
    if not path.is_file() or path.name == "SHA256SUMS":
        continue
    lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
(root / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
exact_sha_guard

python3 - "$artifacts" "$repo_root" "$HOME" "$device" "$private_root" <<'PY'
import sys
from pathlib import Path
root, repo, home, device, private_root = sys.argv[1:]
for path in Path(root).iterdir():
    if path.suffix not in {".log", ".json", ".xml", ".sha256"} and path.name not in {"SHA256SUMS"}:
        continue
    data = path.read_bytes()
    for private in (repo, home, device, private_root):
        if private.encode() in data:
            raise SystemExit(f"retained evidence leaks a private identifier: {path.name}")
PY

echo "patrol_succession_evidence_process_death: PASS"
