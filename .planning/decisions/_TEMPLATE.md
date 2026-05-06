---
date: YYYY-MM-DD
status: Proposed | Decided | Superseded
authors: <name(s)>
panel: <single | 4-pers | 6-pers | etc.>
supersedes: <prior decision file path>
superseded_by: —
description: <one-line TLDR for `.planning/INDEX.md` ; ≤150 chars>
related:
  - <relevant related file path>
---

# <Decision title — short, present-tense, action-oriented>

## TLDR

One sentence : what was decided + the single dominant reason. Lives in
`description:` frontmatter too — keep both in sync.

## Context

What forced this decision. Quote prior artifacts (REQUIREMENTS, panel
verdicts, postmortems) instead of paraphrasing.

## Decision

The thing decided, in present tense (« We do X » not « We will do X »).
Ban hedging language ; if unsure, status should be Proposed not Decided.

## Counter-arguments and data gaps

**REQUIRED — Karpathy Wiki Pattern practice 3.** Without this section
the wiki becomes an echo chamber : every ADR confidently claims its
position with nothing pushing back, and confidence compounds across
references. Format :

- **What does the strongest opposing view say ?**
  Steel-man the alternative we did NOT pick. One paragraph, accurate,
  not a strawman.
- **What does this source not address ?**
  Empirical gaps : numbers we don't have, populations we didn't sample,
  edge cases we didn't simulate.
- **What would change this conclusion ?**
  Concrete future signal that would force re-litigation. (E.g. « if
  CodeGraph adds dart-define injection by v3.0, revisit Maestro lock. »)

If any of those three sub-questions returns « nothing », the decision
is probably under-examined or under-scoped — flag for review rather
than silencing the section.

## Sources

- Files cited (use full paths from repo root)
- External URLs with fetch date
- Slack / Linear / GitHub issue references

## Status & follow-up

- Implementation tracking : link to PR(s) / phase artifact(s)
- Re-litigation triggers : list specific signals that would re-open

---
*Template v1 — Wiki Pattern Karpathy practice 3 enforced by `tools/checks/wiki_lint.py`.*
