# Command ledger

The raw artifacts were generated under
`/tmp/mint-g1-expat-avs-e8c0263acb6d` and then preserved in this evidence
directory. The following is the audited, copy-ready command contract matching
the preserved SHA, device, bundle, logs, result bundle, normal build, watchdog,
and screenshot. It is a reproduction ledger; the raw shell transcript itself
was not one of the original artifacts.

## Exact-SHA and tool boundary

```zsh
set -euo pipefail
cd /Users/julienbattaglia/Desktop/MINT.nosync

SHA=e8c0263acb6ddad9b5acafd889193c4caf4909f3
UDID=B03E429D-0422-4357-B754-536637D979F9
RUN=/tmp/mint-g1-expat-avs-e8c0263acb6d
mkdir -p "$RUN"/{patrol,maestro/screenshots,maestro/debug,maestro/watchdog}

test "$(git rev-parse HEAD)" = "$SHA"
test -z "$(git status --porcelain)"
git rev-parse HEAD > "$RUN/sha-before.txt"
git status --porcelain > "$RUN/status-before.txt"

python3 tools/checks/mint_os_doctor.py \
  | tee "$RUN/mint-doctor.log"
python3 tools/checks/patrol_tooling_guard.py \
  | tee "$RUN/patrol-tooling-guard.log"
xcrun simctl bootstatus "$UDID" -b
```

## Patrol native run and independent result extraction

```zsh
find "$PWD/apps/mobile/build" -maxdepth 1 \
  -name 'ios_results_*.xcresult' -print 2>/dev/null \
  | sort > "$RUN/patrol/xcresults-before.txt"

set +e
(
  cd apps/mobile
  "$HOME/.pub-cache/bin/patrol" test \
    -t test/patrol/expat_avs_verification_runtime_test.dart \
    -d "$UDID" \
    --bundle-id ch.mint.app \
    --dart-define=MINT_PATROL_CLI=true \
    --no-uninstall
) 2>&1 | tee "$RUN/patrol/patrol.log"
PATROL_EXIT=$pipestatus[1]
set -e
printf '%s\n' "$PATROL_EXIT" > "$RUN/patrol/exit-code.txt"
test "$PATROL_EXIT" -eq 0

find "$PWD/apps/mobile/build" -maxdepth 1 \
  -name 'ios_results_*.xcresult' -print \
  | sort > "$RUN/patrol/xcresults-after.txt"
comm -13 "$RUN/patrol/xcresults-before.txt" \
  "$RUN/patrol/xcresults-after.txt" \
  > "$RUN/patrol/xcresults-new.txt"
XCRESULT="$(tail -1 "$RUN/patrol/xcresults-new.txt")"
test -n "$XCRESULT"
cp -R "$XCRESULT" "$RUN/patrol/"

xcrun xcresulttool get test-results summary \
  --path "$XCRESULT" --format json \
  > "$RUN/patrol/summary.json"
xcrun xcresulttool get test-results tests \
  --path "$XCRESULT" --format json \
  > "$RUN/patrol/tests.json"

# Patrol generates this source. Remove it before the clean-tree boundary and
# before rebuilding the normal app entrypoint.
rm -f apps/mobile/test/patrol/test_bundle.dart
```

## Normal Runner build and install

```zsh
set +e
(
  cd apps/mobile
  flutter build ios --simulator --debug
) 2>&1 | tee "$RUN/maestro/flutter-build-ios-simulator.log"
BUILD_EXIT=$pipestatus[1]
set -e
printf '%s\n' "$BUILD_EXIT" > "$RUN/maestro/build-exit-code.txt"
test "$BUILD_EXIT" -eq 0

xcrun simctl install "$UDID" \
  "$PWD/apps/mobile/build/ios/iphonesimulator/Runner.app"
xcrun simctl get_app_container "$UDID" ch.mint.app app \
  > "$RUN/maestro/installed-app-container.txt"
```

## Maestro real-app flow through both CTAs and screenshot

```zsh
set +e
MAESTRO_HARD_LIMIT=300 \
MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS="$RUN/maestro/watchdog" \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid "$UDID" \
  --no-ansi \
  --test-output-dir "$RUN/maestro/screenshots" \
  --debug-output "$RUN/maestro/debug" \
  --flatten-debug-output \
  apps/mobile/.maestro/expat_avs_verification.yaml \
  2>&1 | tee "$RUN/maestro/maestro.log"
MAESTRO_EXIT=$pipestatus[1]
set -e
printf '%s\n' "$MAESTRO_EXIT" > "$RUN/maestro/exit-code.txt"
test "$MAESTRO_EXIT" -eq 0

test -s \
  "$RUN/maestro/screenshots/screenshots/expat_avs_verification_guide.png"
rg 'avs_official_ci_request_cta.*COMPLETED' "$RUN/maestro/maestro.log"
rg 'avs_official_form_cta.*COMPLETED' "$RUN/maestro/maestro.log"
rg 'Take screenshot expat_avs_verification_guide.*COMPLETED' \
  "$RUN/maestro/maestro.log"
```

## Final exact-tree boundary

```zsh
git rev-parse HEAD > "$RUN/sha-after.txt"
git status --porcelain > "$RUN/status-after.txt"
cmp "$RUN/sha-before.txt" "$RUN/sha-after.txt"
test ! -s "$RUN/status-before.txt"
test ! -s "$RUN/status-after.txt"
```

## Independent quality verification performed on preserved artifacts

```zsh
cd /Users/julienbattaglia/Desktop/MINT.nosync
E=.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/expat-avs-verification-e8c0263acb6d
R="$E/runtime-exact-sha"
XC="$R/patrol/ios_results_1783978990507.xcresult"

cmp "$R/sha-before.txt" "$R/sha-after.txt"
test ! -s "$R/status-before.txt"
test ! -s "$R/status-after.txt"
test "$(cat "$R/patrol/exit-code.txt")" = 0
test "$(cat "$R/maestro/build-exit-code.txt")" = 0
test "$(cat "$R/maestro/exit-code.txt")" = 0
xcrun xcresulttool get test-results summary \
  --path "$XC" --format json
git diff 4330a292bca4 e8c0263acb6ddad9b5acafd889193c4caf4909f3 -- \
  apps/mobile/integration_test/expat_avs_verification_patrol_test.dart \
  apps/mobile/.maestro/expat_avs_verification.yaml \
  apps/mobile/lib/screens/expat_screen.dart
git diff 810741211de4 e8c0263acb6ddad9b5acafd889193c4caf4909f3 -- \
  apps/mobile/.maestro/expat_avs_verification.yaml \
  apps/mobile/lib/screens/expat_screen.dart
```
