# G1 AVS B2 exact-SHA iOS runtime proof

Date: 2026-07-13
Commit under test: `6d0b1d19532c6ef498307d0ecf68507de9a9819a`
Branch: `codex/mint-product-usability-plan-20260712`
Device: iPhone 17 Pro simulator (`B03E429D-0422-4357-B754-536637D979F9`), iOS 26.2, model `iPhone18,1`
Bundle: `ch.mint.app`
Data: synthetic only; no personal document, AVS identifier, or production write.

## Exact-tree boundary

`git status --porcelain -- apps/mobile` and full `git status --porcelain` were
empty before the build and after Patrol cleanup. Patrol's generated
`apps/mobile/test/patrol/test_bundle.dart` was explicitly deleted. `GIT_SHA.txt`
and `GIT_SHA-after.txt` are identical.

## Tooling and build

- Full MINT Doctor: PASS for repo contracts and host Patrol, Maestro, Mermaid,
  Claude, and Beads CLIs.
- `patrol_tooling_guard.py`: PASS; Patrol CLI
  `/Users/julienbattaglia/.pub-cache/bin/patrol` (`v4.4.0`).
- `flutter build ios --simulator --debug`: PASS.
- Exact Runner installed on the named simulator; bundle ID and binary SHA-256
  are preserved in `bundle-id.txt` and `runner-binary.sha256`.

## Maestro real-app flow

Checked-in flow: `apps/mobile/.maestro/retirement_missing_avs.yaml`.
Watchdog: 300-second hard limit, 90-second stall threshold.
Result: PASS, exit 0.

The passing flow proves, in order:

1. synthetic salary/canton/birth-year/LPP facts are saved;
2. `/retraite` shows `retirement_missing_avs_state` and retained capital;
3. complete retirement income and replacement rate remain absent;
4. the dashboard CTA `retirement_avs_document_cta` is tapped;
5. the AVS guide displays `318.282`;
6. `avs_official_form_cta` is scrolled into view and asserted;
7. `takeScreenshot` captures `retirement_missing_avs_official_form.png` inside
   the still-passing flow.

Visual inspection: PASS for the requested proof. The screenshot visibly shows
the AVS guide, readable request steps, and the complete “Ouvrir le formulaire
officiel” CTA without overlap. The preceding `318.282` assertion is recorded in
`maestro-run.log` before the screenshot scroll position.

Screenshot:
`maestro/screenshots/screenshots/retirement_missing_avs_official_form.png`
(1206 × 2622). A byte-identical convenience copy is at
`maestro/retirement_missing_avs_official_form.png`.

The optional initial `Cancel` tap emitted a non-blocking WARN because that
system control was absent; every required product assertion completed.

## Patrol native flow and independent xcresult

Checked-in wrapper:
`apps/mobile/test/patrol/retirement_missing_avs_runtime_test.dart`.
Checked-in integration body:
`apps/mobile/integration_test/retirement_missing_avs_patrol_test.dart`.

Patrol result: PASS, exit 0. It independently exercised the missing-AVS state,
hidden complete totals, dashboard CTA, AVS guide `318.282`, and official-form
CTA.

The `.xcresult` bundle is preserved at `patrol/ios_results.xcresult`.
Independent `xcresulttool` extraction reports:

- result: `Passed`
- total: 1
- passed: 1
- failed: 0
- skipped: 0

See `patrol/xcresult-summary.json` and `patrol/xcresult-tests.json`.

## Boundary

This proves the requested missing-official-AVS runtime chain on the exact SHA.
It does not by itself close unrelated G1 Swiss-law, parser/source-date,
partner-consent, or legacy CoupleOptimizer blockers. G2/G3 remain out of scope.
