# Phase 1: Pre-Refactor Cleanup - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 01-pre-refactor-cleanup
**Areas discussed:** Duplicate resolution, Route triage, Dead screen removal, Legacy term cleanup

---

## Duplicate Service Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Trace imports, keep most-used | Canonical = most importers, delete the other | ✓ |
| Keep both with re-export shim | Backward compat wrapper at old location | |
| Merge into new unified file | Combine logic from both copies | |

**User's choice:** Trace imports, keep most-used copy, delete the other entirely
**Notes:** User confirmed Claude's recommended approach. No re-export shims.

---

## Route Triage Criteria

| Option | Description | Selected |
|--------|-------------|----------|
| Live/Redirected/Archived classification | 3-tier: keep live, keep redirects, remove dead | ✓ |
| Keep all routes with stubs | Preserve all 67 routes, add "coming soon" for unused | |

**User's choice:** 3-tier classification (live/redirected/archived)
**Notes:** Wire Spec V2 archived routes keep their existing redirects. Dead = no screen + no redirect + no references.

---

## Dead Screen Removal

| Option | Description | Selected |
|--------|-------------|----------|
| Remove unreachable + deprecated | Delete screens with no routes AND deprecated screens with active redirects | ✓ |
| Remove only truly unreachable | Keep deprecated screens that have redirect shims | |
| Aggressive — remove all unused | Also remove screens referenced only in tests | |

**User's choice:** Remove unreachable screens + deprecated screens (keep their redirects)
**Notes:** `ask_mint_screen.dart` file removed, redirect stays. `theme_detail_screen.dart` with broken imports removed.

---

## Legacy Term Cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Fold into Phase 1 | Rename "chiffre choc" to "premier eclairage" in 51 files | |
| Defer to separate sprint | Internal-only term, doesn't block wiring work | ✓ |

**User's choice:** Defer — not a cleanup prerequisite
**Notes:** 51 files affected. Term is internal naming only (not user-facing). Captured as deferred idea.

---

## Claude's Discretion

- Operation order, commit granularity, redirect comments

## Deferred Ideas

- Legacy "chiffre choc" rename (51 files) — separate sprint
- i18n hardcoded French strings (~120 strings) — tracked separately
