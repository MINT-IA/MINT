# Phase 38 — 3a Comparator Residual Neutrality Cleanup

## Goal

Close the non-blocking Claude review residues after the 3a comparator
neutrality work.

## Scope

- Remove dead recommendation UI plumbing from the 3a comparator row builder.
- Remove no-longer-used provider-specific ARB keys from the six locale files.
- Replace the remaining provider-specific VIAC phrasing in the 3a education
  explanation with neutral scenario language.
- Extend tests so the comparator and explanation cannot regress to provider
  steering.

## Acceptance

- No `isRecommended` branch remains in the 3a comparator.
- No `pillar3aOpenViac`, `pillar3aViacGainLabel`, `pillar3aMoreAtRetirement`,
  `pillar3aViac45`, or `pillar3aRecommended` generated l10n API remains.
- The focused 3a education/comparator tests pass.
- ARB parity remains green.
- `git diff --check` remains green.
