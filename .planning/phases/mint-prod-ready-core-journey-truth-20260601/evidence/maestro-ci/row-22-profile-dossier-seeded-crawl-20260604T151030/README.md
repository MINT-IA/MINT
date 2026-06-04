# Row 22 Profile/Dossier Seeded Crawl — 2026-06-04

Purpose: runtime visual proof that `/profile/bilan` leads with dossier facts,
source provenance, and correction before any retirement projection appears.

Build used:

```bash
cd apps/mobile
xattr -rc build/ios 2>/dev/null || true
flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Flow:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=75 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test --format junit --output "$EVIDENCE/result.xml" "$FLOW"
```

Result:

- `result.xml`: `tests=1`, `failures=0`, `status=SUCCESS`, `time=50.0`.
- Watchdog exit: `0`.
- Key screenshot: `02-row22-profile-bilan-primary.png`.

Important scope note: this is seed-driven visual role evidence. It does not
prove production onboarding persistence or authenticated profile hydration.
