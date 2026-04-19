# Wave C Scan Handoff — DEFERRED to v2.9+

**Archived:** 2026-04-19 at milestone v2.8 "L'Oracle & La Boucle" kickoff
**Status:** PLAN.md drafted, 3 expert panels executed (PANEL-ADVERSAIRE, PANEL-ARCHITECTURE, PANEL-ICONOCLASTE), no code committed
**Reason:** Scan handoff = coach/docs feature enhancement. Does NOT fit v2.8 doctrine "0 feature nouvelle, workflow refonte only".

## Why deferred (not killed)

Wave C has value but wrong milestone:
- Scan handoff improves an existing feature (coach ↔ document scanner handoff UX)
- v2.8 is **workflow refonte**, not product feature work
- Per [kill-policy ADR](../../decisions/ADR-20260419-v2.8-kill-policy.md), 0 feature nouvelle scellée
- Wave C should revive as v2.9+ REQ once v2.8 closes

## What to do when reviving

1. Read `PLAN.md` + 3 panel files for context
2. Re-assess : is this still relevant after v2.8 findings (Sentry Replay, kill-switches, etc.) ?
3. If yes : promote to v2.9 REQ `SCAN-01..N` (adjust category name)
4. If no : close archive with decision note

## Original branch

Work was staged on `feature/wave-c-scan-handoff-coach` (not pushed). If branch still exists locally, can cherry-pick or cold-start fresh.

## Files archived

- `PLAN.md` — Wave C plan (5 commits C1-C5 intended)
- `PANEL-ADVERSAIRE.md` — adversarial expert panel output
- `PANEL-ARCHITECTURE.md` — architecture panel output
- `PANEL-ICONOCLASTE.md` — iconoclast panel output
