# Mint Runtime Debug Tooling M1 — Plan 03 Closeout

## Verdict

GO for local Plan 03 CI/static gate, simulator runtime evidence, and local
release/profile leakage scans.

NO claim is made for physical iPhone, signed TestFlight IPA, or iCloud restore.
That gap remains open and must not be represented as closed by this simulator
and local no-codesign evidence.

## Scope

- Worktree: `/Users/julienbattaglia/Desktop/MINT.debug-spine.nosync`
- Branch: `feature/S09-mint2-runtime-quality-gate`
- Start HEAD: `04ac39382`
- Plan: `.planning/phases/mint-runtime-debug-tooling-m1/03-ci-release-closeout-PLAN.md`

## Implemented

- Added `tools/checks/mint_runtime_debug_tooling_gate.sh --ci-static-only`.
- Added `tools/checks/mint_runtime_debug_tooling_gate.sh --release-scan-only`.
- Added `tools/checks/mint_runtime_debug_release_scan.py`.
- Added `tools/checks/tests/test_mint_runtime_debug_release_scan.py`.
- Wired CI Flutter services shard to run the static-only gate without claiming
  iOS runtime proof.
- Wired CI release sanity to run scanner unit tests and workflow scans.
- Updated `.github/workflows/patrol.md` with static/runtime/release scan
  commands.
- Hardened runtime evidence capture:
  - old Plan 02 SpringBoard/home-screen evidence is rejected;
  - Patrol writes deterministic Debug Spine reset-state redacted row text with
    `mint_debug_spine_snapshot`;
  - the host captures `idb ui describe-all` before screenshot to prove the
    foreground AX application is MINT, not SpringBoard;
  - the host captures `final-reset-state.png` with `xcrun simctl io screenshot`;
  - OCR and Debug Spine row text must contain a deterministic Mint Debug
    Spine anchor.
- Hardened macOS Sequoia/Tahoe simulator build handling by removing existing
  Flutter framework signatures before Patrol rebuilds, avoiding the known
  `com.apple.provenance` ad-hoc codesign replacement failure path.

## Evidence

- Passing runtime evidence:
  `.planning/runtime-evidence/mint-runtime-debug-tooling-20260623T065625Z/`
- Known rejected evidence:
  `.planning/runtime-evidence/mint-runtime-debug-tooling-20260622T194729Z/`
  fails because OCR/UI tree captured SpringBoard/home-screen content.

## Commands

| Command | Exit | Evidence |
|---|---:|---|
| `tools/checks/mint_runtime_debug_tooling_gate.sh` | 0 | `.planning/runtime-evidence/mint-runtime-debug-tooling-20260623T065625Z/`; artifact scan passed with 14 text artifacts and 1 OCR-covered image. |
| `tools/checks/mint_runtime_debug_tooling_gate.sh --artifact-scan-only .planning/runtime-evidence/mint-runtime-debug-tooling-20260623T065625Z` | 0 | Re-extracted JSON and passed artifact scan. |
| `tools/checks/mint_runtime_debug_tooling_gate.sh --ci-static-only` | 0 | Admin/debug flag tests, route snapshot test, artifact scan self-test, workflow scan; explicitly logs that it is not iOS runtime proof. |
| `tools/checks/mint_runtime_debug_tooling_gate.sh --release-scan-only` | 0 | Production workflow scan plus local iOS release/profile no-codesign `Runner.app` artifact scans passed. |
| `python3 -m pytest tools/checks/tests/test_mint_runtime_debug_release_scan.py -q` | 0 | `8 passed in 0.12s`. |
| `flutter analyze` | 0 | `No issues found`. |
| `git diff --check && git diff --cached --check` | 0 | Whitespace checks passed. |
| UUID leak negative scan | 0 | Injected raw simulator UDID into a copy of the passing evidence; `--artifact-scan-only` failed and redacted the UUID in output. |

## Release/Profile Scan Details

- Production workflow scan rejects `ENABLE_ADMIN` / `ENABLE_DEBUG_TOOLS` unless
  values are statically disabled as `0` or `false`.
- Workflow scan covers direct dart-define assignments, environment-wrapped
  assignments, `--dart-define-from-file`, and base64-encoded Dart define values.
- Artifact scan covers expanded paths and compressed `.ipa`, `.aab`, `.apk`,
  and `.zip` entries.
- Artifact scan rejects `/admin/debug-spine`, `/admin/routes`, Debug Spine
  labels, debug snapshot identifiers, `ENABLE_ADMIN`, `ENABLE_DEBUG_TOOLS`, and
  Mint runtime debug evidence markers.
- The default local build path now proves local iOS no-codesign release and
  profile `Runner.app` artifacts. Signed TestFlight IPA / Android AAB scan must
  still be run via `MINT_RELEASE_SCAN_PATHS` when those artifacts are available.

## Review Verdicts

- `flutter-expert`: GO. Found one low wording issue: `ui-tree.*` was labeled as
  a Flutter render-tree though it is Debug Spine redacted row evidence backed by
  widget assertions. Wording was corrected in the Patrol test, gate script, and
  this summary.
- `mobile-security-coder`: GO. No blocker/high/medium/low findings. Confirmed
  scanner redacts failure output, checks token/email/CHF/raw-answer/UDID
  patterns, rejects SpringBoard false positives, and states the remaining
  signed TestFlight/AAB/physical/iCloud gap honestly.
- `code-reviewer`: found one blocker: `--artifact-scan-only` did not know the
  current simulator UDID, so a raw UDID could pass unless the full runtime mode
  supplied the UDID to the scanner. Fixed by rejecting generic UUID/device-id
  patterns in all artifact-scan modes and adding a self-test that verifies the
  failure output remains redacted. Follow-up review returned GO for code/CI.
- Previous Plan 03 reviews found CI scanner tests missing, workflow/doc
  path-filter gaps, compressed archive blind spots, runtime artifact redaction
  risk, and missing foreground-state proof. Those findings are fixed by the
  current diff.

## Remaining Gap

Physical iPhone/TestFlight/iCloud restore remains open. This Plan 03 closeout
does not claim that signed beta distribution or restore behavior is proven.
