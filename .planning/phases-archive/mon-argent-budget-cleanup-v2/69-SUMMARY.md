Phase 69 adds a navigation contract for Mon Argent section aliases so the hub
can be opened reliably from routes and coach actions.

## Goal

Protect Mon Argent deep-link semantics across French and canonical aliases.

## Changed

- `apps/mobile/test/screens/mon_argent_screen_test.dart`
  - Added `direct section aliases route to stable Mon Argent sections`.
  - Covered aliases:
    - `mois` → Month/Budget section.
    - `patrimoine` → Wealth section.
    - `prevoyance` and `prévoyance` → Pension section.
    - `futur` → Future/Trajectory section.
    - unknown value → Today synthesis fallback.

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart --plain-name "direct section aliases route to stable Mon Argent sections"`
  - 1 test passed.

## Review Notes

- This is test-only. No production behavior changed.
- The contract supports Mon Argent as a stable hub for Budget, Patrimoine,
  Prévoyance and Futur navigation.
