# Failed Maestro Artifact Quarantine — 2026-06-04

## TLDR

Four local Row 22 Maestro artifact folders are intentionally **not** release
evidence. They are failed/stale scratch runs and are quarantined from local git
status via `.git/info/exclude` without deleting the files.

## Why

State-of-the-art CJT evidence hygiene requires separating:

- green runtime evidence cited by the matrix;
- red/stalled diagnostic runs useful for local forensic context;
- stale screenshots that must not be mistaken for current proof.

The Journey Truth Matrix already cites the later successful Row 22 runs:

- `row-22-profile-dossier-seeded-crawl-20260604T151030/`
- `row-22-profile-dossier-production-profile-20260604T153106/`

The local folders below predate or sit outside those proofs and should stay out
of committed evidence unless a future forensic report explicitly cites them.

## Quarantined Local Folders

| Path | Verdict | Reason |
|---|---|---|
| `evidence/maestro-ci/row-22-profile-dossier-facts-first-20260604T150129/` | failed scratch | `result.xml` has `failures=1`; watchdog wrote `STALLED` / `stall_79s`. |
| `evidence/maestro-ci/row-22-profile-dossier-production-profile-20260604T152734/` | failed scratch | `result.xml` has `failures=1`; assertion failed for `profile_dossier_facts_summary`. |
| `evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T150644/` | failed scratch | `result.xml` has `failures=1`; assertion failed for retirement-projection text absence during first-viewport validation. |
| `evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T151030/stale-root-screenshots-from-failed-run/` | stale scratch | Screenshot subfolder is explicitly labelled stale and is superseded by the successful seeded crawl evidence. |

## Local Exclude

The exact paths above are added to `.git/info/exclude` so working-tree status
stays readable. This is local-only and non-destructive: files remain on disk,
but they stop appearing as candidate release evidence.

## Verification

Run:

```bash
git status --short --untracked-files=all
```

Expected: no untracked Row 22 failed/stale artifact folders appear.
