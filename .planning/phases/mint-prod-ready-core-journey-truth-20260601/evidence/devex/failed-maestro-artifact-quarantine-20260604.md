# Failed Maestro Artifact Quarantine — 2026-06-04

## TLDR

Local failed/stale Maestro artifact folders are intentionally **not** release
evidence. They are diagnostic scratch runs and are quarantined from local git
status via `.git/info/exclude` without deleting the files.

## Why

State-of-the-art CJT evidence hygiene requires separating:

- green runtime evidence cited by the matrix;
- red/stalled diagnostic runs useful for local forensic context;
- stale screenshots that must not be mistaken for current proof.

The Journey Truth Matrix already cites the later successful Row 22 runs:

- `row-22-profile-dossier-seeded-crawl-20260604T151030/`
- `row-22-profile-dossier-production-profile-20260604T153106/`

It also cites the later successful Row 20 Coach history run:

- `row-20-coach-history-resume-20260604T224120/`

It also cites the later successful Row 17 Rente vs Capital runtime visual run:

- `row-17-rente-vs-capital-runtime-20260604T225941/`

The local folders below predate or sit outside those proofs and should stay out
of committed evidence unless a future forensic report explicitly cites them.

## Quarantined Local Folders

| Path | Verdict | Reason |
|---|---|---|
| `evidence/maestro-ci/row-22-profile-dossier-facts-first-20260604T150129/` | failed scratch | `result.xml` has `failures=1`; watchdog wrote `STALLED` / `stall_79s`. |
| `evidence/maestro-ci/row-22-profile-dossier-production-profile-20260604T152734/` | failed scratch | `result.xml` has `failures=1`; assertion failed for `profile_dossier_facts_summary`. |
| `evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T150644/` | failed scratch | `result.xml` has `failures=1`; assertion failed for retirement-projection text absence during first-viewport validation. |
| `evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T151030/stale-root-screenshots-from-failed-run/` | stale scratch | Screenshot subfolder is explicitly labelled stale and is superseded by the successful seeded crawl evidence. |
| `evidence/maestro-ci/row-20-coach-history-resume-20260604T221728/` | failed scratch | Early Row 20 runtime attempt before the supported-seed/runtime locator contract was stable. |
| `evidence/maestro-ci/row-20-coach-history-resume-20260604T222032/` | failed scratch | Early Row 20 runtime attempt superseded by the green `20260604T224120` run. |
| `evidence/maestro-ci/row-20-coach-history-resume-20260604T222420/` | failed scratch | Intermediate Row 20 runtime attempt; screenshots useful for local diagnosis only. |
| `evidence/maestro-ci/row-20-coach-history-resume-20260604T222909/` | failed scratch | Intermediate Row 20 runtime attempt; superseded by the stable user-message semantics run. |
| `evidence/maestro-ci/row-20-coach-history-resume-20260604T223156/` | failed scratch | Final pre-fix Row 20 attempt; visible product state was close, but JUnit still failed. |
| `evidence/maestro-ci/row-20-coach-history-resume-debug-20260604T222141/` | debug scratch | Diagnostic run showing anonymous/empty-profile hard gate; learning is preserved in the Row 20 proof report. |
| `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225134/` | failed scratch | Early Row 17 runtime attempt; Maestro could not reliably match the visually present income label as text. |
| `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225328/` | failed scratch | Early Row 17 runtime attempt; positive income-label AX text assertion was visually true but Maestro-red. |
| `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225459/` | failed scratch | Intermediate Row 17 attempt; advanced label assertion used the incomplete field label. |
| `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225641/` | failed scratch | Intermediate Row 17 attempt; advanced field label was visually present but not exposed reliably to Maestro. |
| `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225809/` | failed scratch | Final pre-proof Row 17 attempt; advanced Canton text was visually present but not exposed reliably to Maestro. |

## Local Exclude

The exact paths above are added to `.git/info/exclude` so working-tree status
stays readable. This is local-only and non-destructive: files remain on disk,
but they stop appearing as candidate release evidence.

## Verification

Run:

```bash
git status --short --untracked-files=all
```

Expected: no untracked Row 17/20/22 failed/stale artifact folders appear.
