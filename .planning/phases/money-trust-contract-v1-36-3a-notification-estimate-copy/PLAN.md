# Phase 36 — 3a Notification Estimate Copy

## Goal

Remove notification copy that frames a 3a tax estimate as money "in play".

## Scope

- Update mobile notification scheduler fallback copy.
- Update mobile re-engagement fallback copy.
- Update all six ARB locale source strings and regenerate Flutter localizations.
- Add regression assertions for December 3a notification/re-engagement copy.

## Acceptance Criteria

- December 3a notifications say the tax saving is estimated.
- December 3a notifications no longer say `en jeu`.
- ARB key parity remains green across six locales.
- Targeted notification and re-engagement tests pass.
