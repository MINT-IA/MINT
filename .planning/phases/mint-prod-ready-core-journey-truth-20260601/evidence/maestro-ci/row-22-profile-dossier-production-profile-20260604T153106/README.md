# Row 22 Profile/Dossier Production Profile Proof — 2026-06-04

Purpose: prove `/profile/bilan` first-viewport role after a non-seeded
production onboarding writer path and app restart.

Build used:

```bash
cd apps/mobile
xattr -rc build/ios 2>/dev/null || true
flutter build ios --simulator --debug \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Important: the first attempt with `--no-codesign` failed after restart because
SecureWizardStore could not persist sensitive wizard answers in local Keychain;
`/profile/bilan` showed `Aucun profil renseigné`. The normal simulator build
passed.

Flow:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row22_profile_dossier_production_profile.yaml
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=75 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test --format junit --output "$EVIDENCE/result.xml" "$FLOW"
```

Result:

- `result.xml`: `tests=1`, `failures=0`, `status=SUCCESS`, `time=57.0`.
- Watchdog exit: `0`.
- Screenshot: `row22-production-profile-dossier-first-viewport.png`.
