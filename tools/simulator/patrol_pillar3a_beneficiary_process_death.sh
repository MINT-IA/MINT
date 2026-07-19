#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --device <UDID> --bundle-id <bundle> --sha <40-hex> --artifacts <dir>" >&2
}

die() {
  echo "patrol_pillar3a_beneficiary_process_death: $*" >&2
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
if [[ -e "$artifacts" || -L "$artifacts" ]]; then
  [[ -d "$artifacts" && ! -L "$artifacts" ]] \
    || die "artifact path must be a physical directory"
  artifact_seed="$(find "$artifacts" -mindepth 1 -print -quit)"
  [[ -z "$artifact_seed" ]] \
    || die "artifact directory must be initially empty"
else
  mkdir -p "$artifacts"
fi

repo_root="$(git rev-parse --show-toplevel)"
head_sha="$(git -C "$repo_root" rev-parse HEAD)"
[[ "$sha" == "$head_sha" ]] || die "--sha must equal current HEAD ($head_sha)"
upstream_ref="$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" \
  || die "the current branch has no configured upstream"
git -C "$repo_root" merge-base --is-ancestor "$sha" "$upstream_ref" \
  || die "--sha is not present on the configured upstream"
# This witness is checked by the immutable runtime contract.
# shellcheck disable=SC2034
pushed_sha_verified=true

mobile_root="$repo_root/apps/mobile"
write_contract="apps/mobile/integration_test/g1_ret_ref_pillar3a_beneficiary_write_patrol_test.dart"
read_contract="apps/mobile/integration_test/g1_ret_ref_pillar3a_beneficiary_read_patrol_test.dart"
write_target="apps/mobile/test/patrol/g1_ret_ref_pillar3a_beneficiary_write_runtime_test.dart"
read_target="apps/mobile/test/patrol/g1_ret_ref_pillar3a_beneficiary_read_runtime_test.dart"
runtime_support="apps/mobile/integration_test/support/g1_ret_ref_pillar3a_beneficiary_runtime_contract.dart"
flow_before="apps/mobile/.maestro/g1_ret_ref_pillar3a_beneficiary_flag_off_before.yaml"
flow_after="apps/mobile/.maestro/g1_ret_ref_pillar3a_beneficiary_flag_off_after.yaml"
orchestrator_path="tools/simulator/patrol_pillar3a_beneficiary_process_death.sh"
generated_patrol_bundle="apps/mobile/test/patrol/test_bundle.dart"
runtime_paths=(
  "$write_contract"
  "$read_contract"
  "$write_target"
  "$read_target"
  "$runtime_support"
  "$flow_before"
  "$flow_after"
  "apps/mobile/lib/app.dart"
  "apps/mobile/lib/models/lpp_evidence.dart"
  "apps/mobile/lib/models/pillar3a_beneficiary_consumer.dart"
  "apps/mobile/lib/models/pillar3a_beneficiary_evidence.dart"
  "apps/mobile/lib/models/pillar3a_beneficiary_specialist_handoff.dart"
  "apps/mobile/lib/providers/scan_session_provider.dart"
  "apps/mobile/lib/providers/coach_profile_provider.dart"
  "apps/mobile/lib/providers/document_provider.dart"
  "apps/mobile/lib/screens/document_scan/document_scan_screen.dart"
  "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart"
  "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart"
  "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart"
  "apps/mobile/lib/models/financial_report.dart"
  "apps/mobile/lib/services/financial_report_service.dart"
  "apps/mobile/lib/services/report/pillar3a_beneficiary_handoff_section_content.dart"
  "apps/mobile/lib/services/pdf_service.dart"
  "apps/mobile/lib/services/consent/consent_service.dart"
  "apps/mobile/lib/services/document_service.dart"
  "apps/mobile/lib/services/feature_flags.dart"
  "apps/mobile/lib/services/report_persistence_service.dart"
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

untracked_runtime_guard() {
  local untracked_runtime
  untracked_runtime="$(
    git -C "$repo_root" ls-files --others --exclude-standard -- apps/mobile tools/simulator tools/checks
  )"
  [[ -z "$untracked_runtime" ]] \
    || die "untracked runtime files make --sha evidence ambiguous"
}

exact_sha_guard
untracked_runtime_guard

patrol_bin="${PATROL_BIN:-$HOME/.pub-cache/bin/patrol}"
default_maestro_runner="$repo_root/tools/simulator/maestro_env.sh"
if [[ -n "${MAESTRO_RUNNER:-}" ]]; then
  [[ -x "$MAESTRO_RUNNER" ]] || die "Maestro override is not executable"
  maestro_command=("$MAESTRO_RUNNER")
else
  [[ -f "$default_maestro_runner" ]] || die "default Maestro wrapper is missing"
  maestro_command=(bash "$default_maestro_runner")
fi
[[ -x "$patrol_bin" ]] || die "Patrol CLI is not executable at $patrol_bin"
for command_name in xcrun xcodebuild flutter find python3 tar codesign xattr git plutil stat pdftotext; do
  command -v "$command_name" >/dev/null 2>&1 || die "$command_name is required"
done

artifacts="$(cd "$artifacts" && pwd -P)"
metadata="$artifacts/metadata.json"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
external_root=""
external_build=""
production_export_root=""
production_mobile=""
production_app=""
production_archive=""
patrol_app=""
patrol_test_host=""
patrol_xctestrun=""
resolved_container=""
resolved_identity=""
resolved_state_witness=""
suite_data_container_identity=""
suite_runtime_state_witness=""
production_data_container=""
production_data_container_identity=""
mobile_build="$mobile_root/build"
build_backup="$mobile_root/.dart_tool/mint-patrol-g1-ret-ref-pillar3a-beneficiary-build-backup-$sha"
build_isolation_enabled=false
original_build_present=false
restoration_status="not_started"
production_source_exported_exact=false
production_source_physical=false
writer_reader_build_isolation_verified=false
runtime_completed=false
state_preserved_across_process_death=false
post_suite_container_and_state_captured=false
production_reinstall_preserved_identity_and_state=false
distinct_process_pid_verified=false
production_default_off_before_passed=false
production_default_off_after_passed=false
cleanup_status="pending"
artifact_cleanup_failed=false
stage_sanitization_failed=0
write_build_exit_code=""
write_exit_code=""
write_passed_tests=""
write_failed_tests=""
read_build_exit_code=""
read_exit_code=""
read_passed_tests=""
read_failed_tests=""
boot_status_exit_code=""
launch_exit_code=""
terminate_exit_code=""
production_export_exit_code=""
production_extract_exit_code=""
production_build_exit_code=""
production_codesign_verify_exit_code=""
production_xattr_inspect_exit_code=""
production_install_before_exit_code=""
production_install_after_exit_code=""
maestro_before_exit_code=""
maestro_after_exit_code=""

sanitize_log() {
  local raw="$1"
  local output="$2"
  local failed=0
  if ! python3 - "$raw" "$output" "$repo_root" "$HOME" "$device" \
    "$external_root" <<'PY'
import re
import sys
from pathlib import Path

raw_path, output_path, repo, home, device, external_root = sys.argv[1:]
text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
for private, token in (
    (repo, "REDACTED_REPO"),
    (home, "REDACTED_HOME"),
    (device, "REDACTED_SIMULATOR_UDID"),
):
    if private:
        text = text.replace(private, token)

external_aliases = {external_root} if external_root else set()
if external_root.startswith("/private/tmp/"):
    external_aliases.add(external_root[len("/private") :])
elif external_root.startswith("/tmp/"):
    external_aliases.add(f"/private{external_root}")
for private in sorted(external_aliases, key=len, reverse=True):
    text = text.replace(private, "REDACTED_EXTERNAL_BUILD")

text = re.sub(r"\S+\.xcresult(?:/\S*)?", "REDACTED_XCODE_RESULT", text)
text = re.sub(r"(?<![0-9A-Fa-f])[0-9A-Fa-f]{64}(?![0-9A-Fa-f])", "REDACTED_SHA256", text)
text = re.sub(r"%PDF-[^\r\n]*", "REDACTED_DOCUMENT_BYTES", text)
text = re.sub(r"/(?:private/)?var/folders/[^\s\"'<>]+", "REDACTED_PRIVATE_TEMP", text)
text = re.sub(r"/(?:private/)?tmp/[^\s\"'<>]+", "REDACTED_PRIVATE_TEMP", text)
Path(output_path).write_text(text, encoding="utf-8")
PY
  then
    echo "patrol_pillar3a_beneficiary_process_death: log sanitization failed" >&2
    failed=1
  fi
  if [[ -e "$raw" || -L "$raw" ]]; then
    if ! rm -f -- "$raw"; then
      echo "patrol_pillar3a_beneficiary_process_death: raw log removal failed" >&2
      failed=1
    fi
  fi
  return "$failed"
}

sanitize_stage_log() {
  stage_sanitization_failed=0
  if ! sanitize_log "$1" "$2"; then
    artifact_cleanup_failed=true
    stage_sanitization_failed=1
  fi
}

write_metadata() {
  local finished_at
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  MINT_META_SHA="$sha" \
  MINT_META_STARTED="$started_at" \
  MINT_META_FINISHED="$finished_at" \
  MINT_META_WRITE_BUILD="$write_build_exit_code" \
  MINT_META_WRITE="$write_exit_code" \
  MINT_META_WRITE_PASSED="$write_passed_tests" \
  MINT_META_WRITE_FAILED="$write_failed_tests" \
  MINT_META_READ_BUILD="$read_build_exit_code" \
  MINT_META_READ="$read_exit_code" \
  MINT_META_READ_PASSED="$read_passed_tests" \
  MINT_META_READ_FAILED="$read_failed_tests" \
  MINT_META_BOOT="$boot_status_exit_code" \
  MINT_META_LAUNCH="$launch_exit_code" \
  MINT_META_TERMINATE="$terminate_exit_code" \
  MINT_META_EXPORT="$production_export_exit_code" \
  MINT_META_EXTRACT="$production_extract_exit_code" \
  MINT_META_PRODUCTION_BUILD="$production_build_exit_code" \
  MINT_META_CODESIGN="$production_codesign_verify_exit_code" \
  MINT_META_XATTR="$production_xattr_inspect_exit_code" \
  MINT_META_INSTALL_BEFORE="$production_install_before_exit_code" \
  MINT_META_INSTALL_AFTER="$production_install_after_exit_code" \
  MINT_META_MAESTRO_BEFORE="$maestro_before_exit_code" \
  MINT_META_MAESTRO_AFTER="$maestro_after_exit_code" \
  MINT_META_CLEANUP="$cleanup_status" \
  MINT_META_RESTORATION="$restoration_status" \
  MINT_META_STATE="$state_preserved_across_process_death" \
  MINT_META_POST_SUITE_STATE="$post_suite_container_and_state_captured" \
  MINT_META_PRODUCTION_STATE="$production_reinstall_preserved_identity_and_state" \
  MINT_META_DISTINCT_PID="$distinct_process_pid_verified" \
  MINT_META_DEFAULT_BEFORE="$production_default_off_before_passed" \
  MINT_META_DEFAULT_AFTER="$production_default_off_after_passed" \
  MINT_META_SOURCE_EXACT="$production_source_exported_exact" \
  MINT_META_SOURCE_PHYSICAL="$production_source_physical" \
  MINT_META_BUILD_ISOLATION="$writer_reader_build_isolation_verified" \
  MINT_META_RUNTIME="$runtime_completed" \
  python3 - "$metadata" "$artifacts" <<'PY'
import json
import os
import sys
from pathlib import Path


def code(name: str):
    value = os.environ[name]
    return int(value) if value else None


expected_logs = [
    "doctor.log",
    "patrol-guard.log",
    "pillar3a-handoff-pdf-host.log",
    "production-export.log",
    "production-extract.log",
    "production-build.log",
    "production-codesign.log",
    "production-xattrs.log",
    "production-install-before.log",
    "maestro-before.log",
    "maestro-before-report.sanitized.xml",
    "write-build.log",
    "write.log",
    "write-xcresult-summary.sanitized.json",
    "read-build.log",
    "read.log",
    "read-xcresult-summary.sanitized.json",
    "app-container-after-suite.log",
    "bootstatus.log",
    "launch.log",
    "terminate.log",
    "production-install-after.log",
    "maestro-after.log",
    "maestro-after-report.sanitized.xml",
    "app-container-after-production-install.log",
    "app-container-after-maestro.log",
]
artifacts = Path(sys.argv[2])
logs = [name for name in expected_logs if (artifacts / name).is_file()]
payload = {
    "contract": "g1_ret_ref_pillar3a_beneficiary",
    "sha": os.environ["MINT_META_SHA"],
    "pushed_sha_verified": True,
    "started_at": os.environ["MINT_META_STARTED"],
    "finished_at": os.environ["MINT_META_FINISHED"],
    "write_build_exit_code": code("MINT_META_WRITE_BUILD"),
    "write_exit_code": code("MINT_META_WRITE"),
    "write_passed_tests": 1 if os.environ["MINT_META_WRITE_PASSED"] == "1" else None,
    "write_failed_tests": 0 if os.environ["MINT_META_WRITE_FAILED"] == "0" else None,
    "read_build_exit_code": code("MINT_META_READ_BUILD"),
    "read_exit_code": code("MINT_META_READ"),
    "read_passed_tests": 1 if os.environ["MINT_META_READ_PASSED"] == "1" else None,
    "read_failed_tests": 0 if os.environ["MINT_META_READ_FAILED"] == "0" else None,
    "boot_status_exit_code": code("MINT_META_BOOT"),
    "launch_exit_code": code("MINT_META_LAUNCH"),
    "terminate_exit_code": code("MINT_META_TERMINATE"),
    "production_export_exit_code": code("MINT_META_EXPORT"),
    "production_extract_exit_code": code("MINT_META_EXTRACT"),
    "production_build_exit_code": code("MINT_META_PRODUCTION_BUILD"),
    "production_codesign_verify_exit_code": code("MINT_META_CODESIGN"),
    "production_xattr_inspect_exit_code": code("MINT_META_XATTR"),
    "production_install_before_exit_code": code("MINT_META_INSTALL_BEFORE"),
    "production_install_after_exit_code": code("MINT_META_INSTALL_AFTER"),
    "maestro_before_exit_code": code("MINT_META_MAESTRO_BEFORE"),
    "maestro_after_exit_code": code("MINT_META_MAESTRO_AFTER"),
    "feature_activation": "test_process_static_flags_only",
    "state_preservation": "writer_process_death_cold_reader"
    if os.environ["MINT_META_STATE"] == "true"
    else None,
    "process_boundary": "separate_patrol_builds_explicit_terminate_distinct_pid",
    "simctl_terminate_boundary": "between_writer_and_reader",
    "post_suite_container_and_state_captured": os.environ["MINT_META_POST_SUITE_STATE"] == "true",
    "production_reinstall_preserved_identity_and_state": os.environ["MINT_META_PRODUCTION_STATE"] == "true",
    "distinct_process_pid_verified": os.environ["MINT_META_DISTINCT_PID"] == "true",
    "production_default_off_before_passed": os.environ["MINT_META_DEFAULT_BEFORE"] == "true",
    "production_default_off_after_passed": os.environ["MINT_META_DEFAULT_AFTER"] == "true",
    "production_source_exported_exact": os.environ["MINT_META_SOURCE_EXACT"] == "true",
    "production_source_physical": os.environ["MINT_META_SOURCE_PHYSICAL"] == "true",
    "writer_reader_build_isolation_verified": os.environ["MINT_META_BUILD_ISOLATION"] == "true",
    "synthetic_data_only": True,
    "private_fixture_used": False,
    "document_hash_retained": False,
    "raw_document_bytes_retained": False,
    "simulator_identifier_retained": False,
    "xcresult_retained": False,
    "cleanup_status": os.environ["MINT_META_CLEANUP"],
    "restoration_status": os.environ["MINT_META_RESTORATION"],
    "runtime_completed": os.environ["MINT_META_RUNTIME"] == "true",
    "evidence_logs_complete": logs == expected_logs,
    "expected_logs": expected_logs,
    "logs": logs,
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

verify_expected_logs_complete() {
  python3 - "$metadata" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
runtime_completed = payload.get("runtime_completed")
expected_logs = payload.get("expected_logs")
logs = payload.get("logs")
if not isinstance(runtime_completed, bool):
    raise SystemExit(1)
for values in (expected_logs, logs):
    if not isinstance(values, list) or not all(
        isinstance(value, str) and value for value in values
    ):
        raise SystemExit(1)
    if len(values) != len(set(values)):
        raise SystemExit(1)
if runtime_completed and logs != expected_logs:
    raise SystemExit(1)
PY
}

verify_retained_artifacts() {
  local retention_mode="${1:-partial}"
  python3 - "$artifacts" "$repo_root" "$HOME" "$device" \
    "$external_root" "$retention_mode" <<'PY'
import os
import re
import stat
import sys
from pathlib import Path

artifacts, repo, home, device, external_root, retention_mode = sys.argv[1:]
root = Path(artifacts)
expected_logs = [
    "doctor.log",
    "patrol-guard.log",
    "pillar3a-handoff-pdf-host.log",
    "production-export.log",
    "production-extract.log",
    "production-build.log",
    "production-codesign.log",
    "production-xattrs.log",
    "production-install-before.log",
    "maestro-before.log",
    "maestro-before-report.sanitized.xml",
    "write-build.log",
    "write.log",
    "write-xcresult-summary.sanitized.json",
    "read-build.log",
    "read.log",
    "read-xcresult-summary.sanitized.json",
    "app-container-after-suite.log",
    "bootstatus.log",
    "launch.log",
    "terminate.log",
    "production-install-after.log",
    "maestro-after.log",
    "maestro-after-report.sanitized.xml",
    "app-container-after-production-install.log",
    "app-container-after-maestro.log",
]


def fail(relative: str, reason: str) -> None:
    print(
        "patrol_pillar3a_beneficiary_process_death: "
        f"unsafe retained artifact ({relative}: {reason})",
        file=sys.stderr,
    )
    raise SystemExit(1)


try:
    root_status = os.lstat(root)
except OSError:
    fail(".", "artifact root is unavailable")
if not stat.S_ISDIR(root_status.st_mode) or stat.S_ISLNK(root_status.st_mode):
    fail(".", "artifact root is not a physical directory")
if retention_mode not in {"partial", "final"}:
    fail(".", "unknown retained-artifact verification mode")

allowed_paths = {*expected_logs, "metadata.json"}
actual_paths = set()
for current_root, directory_names, file_names in os.walk(
    root,
    topdown=True,
    followlinks=False,
):
    for name in (*directory_names, *file_names):
        actual_paths.add(Path(current_root, name).relative_to(root).as_posix())
unexpected_paths = actual_paths - allowed_paths
if unexpected_paths:
    fail(sorted(unexpected_paths)[0], "path is not in the retained allowlist")
if retention_mode == "final" and actual_paths != allowed_paths:
    missing_paths = allowed_paths - actual_paths
    fail(sorted(missing_paths)[0], "required final retained artifact is missing")

external_aliases = {external_root} if external_root else set()
if external_root.startswith("/private/tmp/"):
    external_aliases.add(external_root[len("/private") :])
elif external_root.startswith("/tmp/"):
    external_aliases.add(f"/private{external_root}")
forbidden_content = tuple(
    value
    for value in (
        repo,
        home,
        device,
        *sorted(external_aliases),
        "/Users/",
        "/private/",
        "/tmp/",
        "/var/folders/",
        "test/" + "golden",
        "MINT_LPP_" + "PRIVATE_MANIFEST",
        "%PDF-",
        ".xcresult",
    )
    if value
)
forbidden_names = {
    "maestro-report.xml",
    "maestro-debug",
    "maestro-test-output",
}
forbidden_suffixes = (
    ".sha256",
    ".raw.log",
    ".xcresult",
    ".pdf",
    ".jpeg",
    ".jpg",
    ".png",
    ".mp4",
)
sha256_pattern = re.compile(r"(?<![0-9A-Fa-f])[0-9A-Fa-f]{64}(?![0-9A-Fa-f])")
avs_pattern = re.compile(r"(?<!\d)756[. -]?\d{4}[. -]?\d{4}[. -]?\d{2}(?!\d)")
raw_content_markers = (
    "rawocr",
    "raw_ocr",
    "raw ocr",
    "sourcetext",
    "jvberi0",
)


def fail_walk(_error: OSError) -> None:
    fail(".", "artifact tree could not be inspected")


for current_root, directory_names, file_names in os.walk(
    root,
    topdown=True,
    onerror=fail_walk,
    followlinks=False,
):
    for name in (*directory_names, *file_names):
        path = Path(current_root, name)
        relative = path.relative_to(root).as_posix()
        lowered = name.lower()
        try:
            entry_status = os.lstat(path)
        except OSError:
            fail(relative, "artifact entry could not be inspected")
        if stat.S_ISLNK(entry_status.st_mode):
            fail(relative, "symlink")
        if lowered in forbidden_names or lowered.endswith(forbidden_suffixes):
            fail(relative, "private fixture, hash, raw report, or debug media")
        if stat.S_ISDIR(entry_status.st_mode):
            continue
        if not stat.S_ISREG(entry_status.st_mode):
            fail(relative, "non-regular artifact")
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            fail(relative, "artifact content could not be inspected")
        if any(private in content for private in forbidden_content):
            fail(relative, "private path, fixture, raw bytes, identifier, or result")
        lowered_content = content.lower()
        if any(marker in lowered_content for marker in raw_content_markers):
            fail(relative, "raw OCR field or base64 PDF marker")
        if avs_pattern.search(content):
            fail(relative, "Swiss AVS identifier")
        if sha256_pattern.search(content):
            fail(relative, "retained 64-hex hash")
PY
}

cleanup() {
  local exit_code=$?
  local cleanup_failed=0
  local tracked_status=0
  trap - EXIT HUP INT TERM
  cleanup_status="passed"

  if [[ "$artifact_cleanup_failed" == true ]]; then
    cleanup_failed=1
  fi
  for log_stem in \
    doctor patrol-guard pillar3a-handoff-pdf-host \
    production-export production-extract production-build \
    production-codesign production-xattrs production-install-before \
    maestro-before write-build write read-build read bootstatus launch terminate \
    production-install-after maestro-after; do
    raw_log="$artifacts/$log_stem.raw.log"
    if [[ -e "$raw_log" || -L "$raw_log" ]]; then
      if ! sanitize_log "$raw_log" "$artifacts/$log_stem.log"; then
        cleanup_failed=1
      fi
    fi
  done
  for raw_report in \
    "$artifacts/maestro-before-report.xml" \
    "$artifacts/maestro-after-report.xml"; do
    if [[ -e "$raw_report" || -L "$raw_report" ]]; then
      if ! rm -f -- "$raw_report"; then
        echo "patrol_pillar3a_beneficiary_process_death: raw Maestro report removal failed" >&2
        cleanup_failed=1
      fi
    fi
  done

  if [[ "$build_isolation_enabled" == true ]]; then
    if [[ -L "$mobile_build" && "$(readlink "$mobile_build")" == "$external_build" ]]; then
      rm -- "$mobile_build" || cleanup_failed=1
    elif [[ -e "$mobile_build" || -L "$mobile_build" ]]; then
      echo "patrol_pillar3a_beneficiary_process_death: isolated build path drifted" >&2
      cleanup_failed=1
    fi
    if [[ "$original_build_present" == true ]]; then
      if [[ ! -e "$mobile_build" && -d "$build_backup" ]]; then
        mv "$build_backup" "$mobile_build" || cleanup_failed=1
      else
        echo "patrol_pillar3a_beneficiary_process_death: original build restoration is ambiguous" >&2
        cleanup_failed=1
      fi
    elif [[ -e "$build_backup" || -L "$build_backup" ]]; then
      cleanup_failed=1
    fi
    restoration_status="$([[ "$cleanup_failed" -eq 0 ]] && echo restored || echo failed)"
  fi

  if [[ -e "$repo_root/$generated_patrol_bundle" ]]; then
    set +e
    git -C "$repo_root" ls-files --error-unmatch -- \
      "$generated_patrol_bundle" >/dev/null 2>&1
    tracked_status=$?
    set -e
    if [[ "$tracked_status" -eq 1 ]]; then
      if ! rm -f -- "$repo_root/$generated_patrol_bundle"; then
        echo "patrol_pillar3a_beneficiary_process_death: Patrol bundle cleanup failed" >&2
        cleanup_failed=1
      fi
    elif [[ "$tracked_status" -ne 0 ]]; then
      cleanup_failed=1
    fi
  fi

  if [[ -n "$external_root" && -d "$external_root" ]]; then
    if ! rm -rf -- "$external_root"; then
      echo "patrol_pillar3a_beneficiary_process_death: external build removal failed" >&2
      cleanup_failed=1
    fi
  fi
  if ! verify_retained_artifacts "partial"; then
    cleanup_failed=1
  fi
  if [[ "$cleanup_failed" -ne 0 ]]; then
    cleanup_status="failed"
  fi
  if ! write_metadata; then
    echo "patrol_pillar3a_beneficiary_process_death: metadata write failed" >&2
    cleanup_failed=1
  fi
  if [[ "$runtime_completed" == true ]]; then
    if ! verify_retained_artifacts "final"; then
      cleanup_failed=1
    fi
  elif ! verify_retained_artifacts "partial"; then
    cleanup_failed=1
  fi
  if ! verify_expected_logs_complete; then
    echo "patrol_pillar3a_beneficiary_process_death: runtime evidence logs are incomplete" >&2
    cleanup_failed=1
    cleanup_status="failed"
  fi
  if [[ "$cleanup_failed" -ne 0 ]]; then
    cleanup_status="failed"
    if ! write_metadata; then
      echo "patrol_pillar3a_beneficiary_process_death: final metadata write failed" >&2
      cleanup_failed=1
    fi
  fi
  if [[ "$runtime_completed" == true ]]; then
    if ! verify_retained_artifacts "final"; then
      cleanup_failed=1
    fi
  elif ! verify_retained_artifacts "partial"; then
    cleanup_failed=1
  fi
  if [[ "$exit_code" -ne 0 ]]; then
    exit "$exit_code"
  fi
  if [[ "$runtime_completed" != true || "$cleanup_failed" -ne 0 ]]; then
    exit 2
  fi
  echo "patrol_pillar3a_beneficiary_process_death: PASS sha=$sha"
  exit 0
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

assert_external_build_empty() {
  local stage="$1"
  local first_entry
  first_entry="$(find "$external_build" -mindepth 1 -print -quit)"
  [[ -z "$first_entry" ]] || die "$stage external build is not clean"
}

inspect_patrol_build() {
  local stage="$1"
  local expected_target="$2"
  local products="$external_build/ios_integ/Build/Products"
  local asset_manifest
  local app_bundle_id
  local test_host_bundle_id
  patrol_app="$(find "$products" -type d -path '*/Debug-iphonesimulator/Runner.app' -print -quit 2>/dev/null || true)"
  patrol_test_host="$(find "$products" -type d -path '*/Debug-iphonesimulator/RunnerUITests-Runner.app' -print -quit 2>/dev/null || true)"
  patrol_xctestrun="$(find "$products" -maxdepth 2 -type f -name '*.xctestrun' -print -quit 2>/dev/null || true)"
  [[ -n "$patrol_app" && -d "$patrol_app" ]] || die "Patrol Runner.app is missing"
  [[ -n "$patrol_test_host" && -d "$patrol_test_host" ]] \
    || die "Patrol RunnerUITests host is missing"
  [[ -n "$patrol_xctestrun" && -f "$patrol_xctestrun" ]] \
    || die "Patrol xctestrun is missing"
  asset_manifest="$patrol_app/Frameworks/App.framework/flutter_assets/AssetManifest.bin"
  [[ -s "$asset_manifest" ]] || die "Patrol AssetManifest.bin is missing"
  [[ -d "$patrol_test_host/PlugIns/RunnerUITests.xctest" ]] \
    || die "Patrol test bundle is missing"
  app_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$patrol_app/Info.plist")"
  test_host_bundle_id="$(
    plutil -extract CFBundleIdentifier raw -o - "$patrol_test_host/Info.plist"
  )"
  [[ "$app_bundle_id" == "$bundle_id" ]] || die "Patrol app bundle id drifted"
  [[ "$test_host_bundle_id" == "$bundle_id.RunnerUITests.xctrunner" ]] \
    || die "Patrol test-host bundle id drifted"
  python3 - "$repo_root/$generated_patrol_bundle" "$expected_target" <<'PY' \
    || die "$stage Patrol bundle is not the exact single target"
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = sys.argv[2].rsplit("/", 1)[-1]
if source.count(target) != 1:
    raise SystemExit(1)
PY
}

run_patrol_build() {
  local stage="$1"
  local target="$2"
  local build_exit_code
  assert_external_build_empty "$stage"
  set +e
  (cd "$mobile_root" && "$patrol_bin" --verbose build ios \
    --target "${target#apps/mobile/}" \
    --simulator --bundle-id "$bundle_id" \
    --dart-define=MINT_PATROL_CLI=true) \
    >"$artifacts/$stage-build.raw.log" 2>&1
  build_exit_code=$?
  set -e
  printf -v "${stage}_build_exit_code" '%s' "$build_exit_code"
  sanitize_stage_log \
    "$artifacts/$stage-build.raw.log" "$artifacts/$stage-build.log"
  [[ "$build_exit_code" -eq 0 ]] || exit "$build_exit_code"
  [[ "$stage_sanitization_failed" -eq 0 ]] \
    || die "$stage Patrol build sanitization failed"
  inspect_patrol_build "$stage" "$target"
}

run_xcode_test() {
  local stage="$1"
  local test_exit_code
  local result_bundle="$external_build/$stage.xcresult"
  [[ -f "$patrol_xctestrun" ]] || die "Patrol xctestrun is unavailable"
  set +e
  xcodebuild test-without-building \
    -xctestrun "$patrol_xctestrun" \
    -only-testing "RunnerUITests/RunnerUITests" \
    -parallel-testing-enabled NO \
    -destination "platform=iOS Simulator,id=$device" \
    -resultBundlePath "$result_bundle" \
    >"$artifacts/$stage.raw.log" 2>&1
  test_exit_code=$?
  set -e
  printf -v "${stage}_exit_code" '%s' "$test_exit_code"
  sanitize_stage_log \
    "$artifacts/$stage.raw.log" "$artifacts/$stage.log"
  [[ "$test_exit_code" -eq 0 ]] || exit "$test_exit_code"
  [[ "$stage_sanitization_failed" -eq 0 ]] \
    || die "$stage Patrol test sanitization failed"
  [[ -d "$result_bundle" ]] || die "$stage Patrol result bundle is missing"
}

verify_xcresult_one_of_one() {
  local stage="$1"
  local raw_summary="$external_root/$stage-xcresult-summary.raw.json"
  local raw_stderr="$external_root/$stage-xcresult-summary.raw.log"
  local sanitized_summary="$artifacts/$stage-xcresult-summary.sanitized.json"
  local summary_exit_code
  local metrics
  local passed_tests
  local failed_tests
  set +e
  xcrun xcresulttool get test-results summary \
    --path "$external_build/$stage.xcresult" --compact \
    >"$raw_summary" 2>"$raw_stderr"
  summary_exit_code=$?
  set -e
  [[ "$summary_exit_code" -eq 0 ]] || die "$stage Patrol summary failed"
  metrics="$(python3 - "$raw_summary" "$sanitized_summary" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
passed = payload.get("passedTests")
failed = payload.get("failedTests")
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump({"failed_tests": failed, "passed_tests": passed}, handle, sort_keys=True)
    handle.write("\n")
print(passed, failed)
PY
)"
  read -r passed_tests failed_tests <<<"$metrics"
  printf -v "${stage}_passed_tests" '%s' "$passed_tests"
  printf -v "${stage}_failed_tests" '%s' "$failed_tests"
  [[ "$passed_tests" == "1" && "$failed_tests" == "0" ]] \
    || die "$stage Patrol result is not exactly 1/1 PASS"
}

resolve_app_data_container() {
  local stage="$1"
  local candidate
  local identity
  set +e
  candidate="$(xcrun simctl get_app_container "$device" "$bundle_id" data 2>/dev/null)"
  local container_exit_code=$?
  set -e
  [[ "$container_exit_code" -eq 0 && -n "$candidate" ]] \
    || die "$stage app data container is unavailable"
  [[ -d "$candidate" && ! -L "$candidate" ]] \
    || die "$stage app data container is not a physical directory"
  identity="$(stat -f '%d:%i' "$candidate")"
  [[ "$identity" =~ ^[0-9]+:[0-9]+$ ]] || die "$stage app data identity is invalid"
  resolved_container="$candidate"
  resolved_identity="$identity"
  printf 'stage=%s\ncontainer_present=true\n' "$stage" \
    >"$artifacts/app-container-$stage.log"
}

assert_required_runtime_state() {
  local stage="$1"
  local preferences_plist="$resolved_container/Library/Preferences/$bundle_id.plist"
  local witness
  [[ -f "$preferences_plist" && ! -L "$preferences_plist" ]] \
    || die "$stage app preferences are unavailable"
  if ! witness="$(python3 - "$preferences_plist" <<'PY'
import json
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    preferences = plistlib.load(handle)
required = (
    "flutter.wizard_answers_v2",
    "flutter.coach_authority_active_slot_v1",
    "flutter._confirmed_document_references_v1",
)
witness = {key: preferences.get(key) for key in required}
if not all(isinstance(value, str) and value for value in witness.values()):
    raise SystemExit(1)
print(json.dumps(witness, separators=(",", ":"), sort_keys=True))
PY
  )"; then
    die "$stage required persisted app state is incomplete"
  fi
  resolved_state_witness="$witness"
  printf 'required_runtime_state=true\n' >>"$artifacts/app-container-$stage.log"
}

capture_completed_suite_container() {
  [[ -n "$resolved_container" && -n "$resolved_identity" ]] \
    || die "completed Patrol suite container witness is unavailable"
  assert_required_runtime_state "after-suite"
  suite_data_container_identity="$resolved_identity"
  suite_runtime_state_witness="$resolved_state_witness"
  printf 'post_suite_container_and_state_captured=true\n' \
    >>"$artifacts/app-container-after-suite.log"
  post_suite_container_and_state_captured=true
}

assert_production_reinstall_preserved_state() {
  [[ "$resolved_identity" == "$suite_data_container_identity" ]] \
    || die "production reinstall changed the app data container identity"
  assert_required_runtime_state "after-production-install"
  [[ "$resolved_state_witness" == "$suite_runtime_state_witness" ]] \
    || die "production reinstall changed the persisted app state"
  production_data_container="$resolved_container"
  production_data_container_identity="$resolved_identity"
  printf 'production_reinstall_preserved_identity_and_state=true\n' \
    >>"$artifacts/app-container-after-production-install.log"
  production_reinstall_preserved_identity_and_state=true
}

assert_same_production_container() {
  local stage="$1"
  [[ "$resolved_container" == "$production_data_container" ]] \
    || die "$stage production app data container path changed"
  [[ "$resolved_identity" == "$production_data_container_identity" ]] \
    || die "$stage production app data container identity changed"
  assert_required_runtime_state "$stage"
  [[ "$resolved_state_witness" == "$suite_runtime_state_witness" ]] \
    || die "$stage changed the persisted app state"
  printf 'production_container_preserved=true\n' \
    >>"$artifacts/app-container-$stage.log"
}

inspect_production_app() {
  [[ -x "$production_app/Runner" ]] || die "production Runner is missing"
  [[ -s "$production_app/Info.plist" ]] || die "production Info.plist is missing"
  [[ -s "$production_app/Frameworks/App.framework/flutter_assets/AssetManifest.bin" ]] \
    || die "production AssetManifest is missing"
}

export_production_source() {
  production_archive="$external_root/mobile.tar"
  production_export_root="$external_root/source"
  production_mobile="$production_export_root/apps/mobile"
  production_app="$production_mobile/build/ios/iphonesimulator/Runner.app"
  mkdir -p "$production_export_root"
  set +e
  git -C "$repo_root" archive --format=tar --output "$production_archive" "$sha" -- apps/mobile \
    >"$artifacts/production-export.raw.log" 2>&1
  production_export_exit_code=$?
  set -e
  sanitize_stage_log "$artifacts/production-export.raw.log" "$artifacts/production-export.log"
  [[ "$production_export_exit_code" -eq 0 ]] || exit "$production_export_exit_code"
  [[ -s "$production_archive" && ! -L "$production_archive" ]] || die "production archive missing"
  set +e
  tar -xf "$production_archive" -C "$production_export_root" \
    >"$artifacts/production-extract.raw.log" 2>&1
  production_extract_exit_code=$?
  set -e
  sanitize_stage_log "$artifacts/production-extract.raw.log" "$artifacts/production-extract.log"
  rm -f -- "$production_archive"
  [[ "$production_extract_exit_code" -eq 0 ]] || exit "$production_extract_exit_code"
  [[ -d "$production_mobile" && ! -L "$production_mobile" ]] \
    || die "production source is not physical"
  if ! python3 - "$production_mobile" <<'PY'
import os
import stat
import sys

root = sys.argv[1]
for current_root, directory_names, file_names in os.walk(root, followlinks=False):
    for name in (*directory_names, *file_names):
        entry_status = os.lstat(os.path.join(current_root, name))
        if stat.S_ISLNK(entry_status.st_mode):
            raise SystemExit(1)
        if stat.S_ISREG(entry_status.st_mode) and entry_status.st_nlink > 1:
            raise SystemExit(1)
PY
  then
    die "production source contains an unsafe alias"
  fi
  # These witnesses are checked by the immutable runtime contract.
  # shellcheck disable=SC2034
  production_source_exported_exact=true
  # shellcheck disable=SC2034
  production_source_physical=true
}

build_production_app() {
  local stage="$1"
  local build_exit_code
  set +e
  (cd "$production_mobile" && \
    flutter build ios --simulator --debug --target lib/main.dart) \
    >"$artifacts/production-build.raw.log" 2>&1
  build_exit_code=$?
  set -e
  production_build_exit_code="$build_exit_code"
  sanitize_stage_log "$artifacts/production-build.raw.log" "$artifacts/production-build.log"
  [[ "$build_exit_code" -eq 0 ]] || exit "$build_exit_code"
  [[ "$stage_sanitization_failed" -eq 0 ]] || die "$stage production build sanitization failed"
  inspect_production_app
  set +e
  codesign --verify --strict --deep "$production_app" \
    >"$artifacts/production-codesign.raw.log" 2>&1
  production_codesign_verify_exit_code=$?
  set -e
  sanitize_stage_log "$artifacts/production-codesign.raw.log" "$artifacts/production-codesign.log"
  [[ "$production_codesign_verify_exit_code" -eq 0 ]] || exit "$production_codesign_verify_exit_code"
  set +e
  xattr -r "$production_app" >"$artifacts/production-xattrs.raw.log" 2>&1
  production_xattr_inspect_exit_code=$?
  set -e
  sanitize_stage_log "$artifacts/production-xattrs.raw.log" "$artifacts/production-xattrs.log"
  [[ "$production_xattr_inspect_exit_code" -eq 0 ]] || exit "$production_xattr_inspect_exit_code"
  if grep -Fq 'com.apple.FinderInfo' "$artifacts/production-xattrs.log" \
    || grep -Fq 'com.apple.ResourceFork' "$artifacts/production-xattrs.log"; then
    die "production app has forbidden extended attributes"
  fi
  exact_sha_guard
}

install_production_app() {
  local stage="$1"
  local install_exit_code
  set +e
  xcrun simctl install "$device" "$production_app" \
    >"$artifacts/production-install-$stage.raw.log" 2>&1
  install_exit_code=$?
  set -e
  printf -v "production_install_${stage}_exit_code" '%s' "$install_exit_code"
  sanitize_stage_log \
    "$artifacts/production-install-$stage.raw.log" \
    "$artifacts/production-install-$stage.log"
  [[ "$install_exit_code" -eq 0 ]] || exit "$install_exit_code"
  [[ "$stage_sanitization_failed" -eq 0 ]] || die "$stage install sanitization failed"
}

run_maestro() {
  local stage="$1"
  local flow="$2"
  local maestro_exit
  local raw_report="$artifacts/maestro-$stage-report.xml"
  local sanitized_report="$artifacts/maestro-$stage-report.sanitized.xml"
  set +e
  "${maestro_command[@]}" test --udid "$device" --format JUNIT \
    --debug-output "$external_root/maestro-$stage-debug" \
    --test-output-dir "$external_root/maestro-$stage-test-output" \
    --output "$raw_report" "$repo_root/$flow" \
    >"$artifacts/maestro-$stage.raw.log" 2>&1
  maestro_exit=$?
  set -e
  printf -v "maestro_${stage}_exit_code" '%s' "$maestro_exit"
  sanitize_stage_log "$artifacts/maestro-$stage.raw.log" "$artifacts/maestro-$stage.log"
  [[ "$maestro_exit" -eq 0 ]] || exit "$maestro_exit"
  [[ -s "$raw_report" ]] || die "$stage raw Maestro report is missing"
  sanitize_stage_log "$raw_report" "$sanitized_report"
  [[ "$stage_sanitization_failed" -eq 0 ]] || die "$stage Maestro report sanitization failed"
  python3 - "$sanitized_report" <<'PY' || die "sanitized Maestro report is invalid"
import sys
import xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY
  if [[ "$stage" == "before" ]]; then
    production_default_off_before_passed=true
  else
    production_default_off_after_passed=true
  fi
  exact_sha_guard
}

mkdir -p "$mobile_root/.dart_tool"
[[ ! -e "$build_backup" && ! -L "$build_backup" ]] || die "build backup collision"
external_root="$(mktemp -d "/tmp/mint-patrol-g1-ret-ref-pillar3a-beneficiary-${sha:0:12}.XXXXXX")"
external_root="$(cd "$external_root" && pwd -P)"
external_build="$external_root/build"
mkdir -p "$external_build"
if [[ -e "$mobile_build" || -L "$mobile_build" ]]; then
  [[ -d "$mobile_build" && ! -L "$mobile_build" ]] || die "pre-existing build is not physical"
  mv "$mobile_build" "$build_backup"
  original_build_present=true
fi
ln -s "$external_build" "$mobile_build"
build_isolation_enabled=true
restoration_status="pending"

python3 "$repo_root/tools/checks/mint_os_doctor.py" \
  >"$artifacts/doctor.raw.log" 2>&1 || die "MINT Doctor runtime preflight failed"
sanitize_stage_log "$artifacts/doctor.raw.log" "$artifacts/doctor.log"
python3 "$repo_root/tools/checks/patrol_tooling_guard.py" \
  >"$artifacts/patrol-guard.raw.log" 2>&1 || die "Patrol tooling guard failed"
sanitize_stage_log "$artifacts/patrol-guard.raw.log" "$artifacts/patrol-guard.log"
(cd "$mobile_root" && \
  flutter test test/services/pillar3a_beneficiary_handoff_pdf_test.dart) \
  >"$artifacts/pillar3a-handoff-pdf-host.raw.log" 2>&1 \
  || die "Pillar 3a handoff PDF host test failed"
sanitize_stage_log \
  "$artifacts/pillar3a-handoff-pdf-host.raw.log" \
  "$artifacts/pillar3a-handoff-pdf-host.log"
# The host PDF test legitimately uses Flutter's build directory. Patrol's
# writer must still start from a physically empty disposable build root.
rm -rf -- "$external_build"
mkdir -p "$external_build"

export_production_source
build_production_app "before"
install_production_app "before"
run_maestro "before" "$flow_before"

run_patrol_build "write" "$write_target"
run_xcode_test "write"
verify_xcresult_one_of_one "write"
exact_sha_guard

set +e
xcrun simctl bootstatus "$device" -b >"$artifacts/bootstatus.raw.log" 2>&1
boot_status_exit_code=$?
set -e
sanitize_stage_log "$artifacts/bootstatus.raw.log" "$artifacts/bootstatus.log"
[[ "$boot_status_exit_code" -eq 0 ]] || exit "$boot_status_exit_code"
set +e
xcrun simctl launch "$device" "$bundle_id" >"$artifacts/launch.raw.log" 2>&1
launch_exit_code=$?
set -e
sanitize_stage_log "$artifacts/launch.raw.log" "$artifacts/launch.log"
[[ "$launch_exit_code" -eq 0 ]] || exit "$launch_exit_code"
set +e
xcrun simctl terminate "$device" "$bundle_id" >"$artifacts/terminate.raw.log" 2>&1
terminate_exit_code=$?
set -e
sanitize_stage_log "$artifacts/terminate.raw.log" "$artifacts/terminate.log"
[[ "$terminate_exit_code" -eq 0 ]] || exit "$terminate_exit_code"

[[ -L "$mobile_build" && "$(readlink "$mobile_build")" == "$external_build" ]] \
  || die "external build isolation drifted before reader"
rm -rf -- "$external_build"
mkdir -p "$external_build"
run_patrol_build "read" "$read_target"
run_xcode_test "read"
verify_xcresult_one_of_one "read"
writer_reader_build_isolation_verified=true
distinct_process_pid_verified=true
resolve_app_data_container "after-suite"
capture_completed_suite_container
exact_sha_guard

install_production_app "after"
resolve_app_data_container "after-production-install"
assert_production_reinstall_preserved_state
run_maestro "after" "$flow_after"
resolve_app_data_container "after-maestro"
assert_same_production_container "after-maestro"

state_preserved_across_process_death=true
exact_sha_guard
runtime_completed=true
