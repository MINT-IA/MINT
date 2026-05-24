description: Plan 23 exposes fixed charges and investments in the strict coach context packet so the chat can reason from the same situation facts as Mon Argent.

# Plan 23 — Coach Context Fixed Situation Facts

## Goal

Give the coach packet the missing fixed situation facts already present in
`DataSpineSnapshot.situation`: housing cost, LAMal premium, and investments.

## Scope

- Add strict allowlist IDs for the three facts.
- Emit the facts only when the corresponding `SpineValue` has a value.
- Extend the existing packet service test.

## Verification

- First run the targeted test red with expectations only.
- Run the targeted packet test green after implementation.
- Run packet + data spine service tests.
- Run Dart analysis on the touched files.
- Run design lints and `git diff --check` before commit.
