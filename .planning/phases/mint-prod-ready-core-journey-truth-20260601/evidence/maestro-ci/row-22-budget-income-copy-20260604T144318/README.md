---
description: Runtime evidence that fresh Budget surfaces no longer expose salary-only copy.
date: 2026-06-04
status: evidence
---

# Row 22 / 23 Budget Income Copy Evidence

Purpose: verify the Budget first viewport no longer forces a salaried-worker
assumption after replacing salary-only empty-state copy with income-inclusive
copy.

Build:

```bash
cd apps/mobile
flutter build ios --simulator --debug --no-codesign --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Runtime:

- Simulator: iPhone 17 Pro, iOS 26.2.
- App bundle: `ch.mint.app`.
- App data was cleared by uninstalling and reinstalling the debug simulator
  build before capture.
- Deep links:
  - `mintapp:///budget`
  - `mintapp:///budget/setup`

Screenshots:

- `01-budget-empty-state-fresh-install.jpg` — `/budget` fresh-state Budget
  container. CTA is `Poser mes charges`, not salary-only.
- `02-budget-setup-fresh-install.jpg` — `/budget/setup` fresh-state setup.
  First viewport is fixed-charge entry, not salary/income capture.

Companion widget proof:

- `apps/mobile/test/screens/budget_screen_smoke_test.dart` asserts the direct
  `BudgetScreen` empty-state CTA is `Ajouter mes revenus` and that no
  salary-only text is rendered on that surface.

Limit:

This evidence proves the fresh Budget runtime surfaces inspected here. It does
not by itself prove the direct `BudgetScreen` CTA text, which is covered by the
widget test above. It does not close Row 22: Row 23 design/i18n/accessibility
and broader release proof remain open.
