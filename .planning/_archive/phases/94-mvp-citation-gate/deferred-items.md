---
phase: 94-mvp-citation-gate
plan: 94-03
artifact: deferred-items
date: 2026-05-10
status: SURFACED — awaits scoping decision
description: Items found during Plan 94-03 execution that exceed the plan's
  files_modified scope. Each item is a Rule 4 (architectural) discovery
  documented for Julien GO/NO-GO on Wave 4 / Phase 96.
---

# Phase 94 — Deferred Items

## D1. Anonymous chat path does NOT use the citation gate

**Found during :** Plan 94-03 Task 2 — Maestro G1 flow.
**Surface :** `services/backend/app/api/v1/endpoints/anonymous_chat.py`.

### Evidence

```
$ grep -nE "COACH_CITATION_GATE|citation_gate|_run_narrator_with_gate" \
    services/backend/app/api/v1/endpoints/anonymous_chat.py
(no matches)
```

Plan 94-02 Wave 1 wired `_run_narrator_with_gate()` ONLY inside
`services/backend/app/api/v1/endpoints/coach_chat.py:_run_agent_loop`
narrator handler (CONTEXT D-11). The anonymous chat endpoint at
`/api/v1/anonymous/chat` calls the narrator through a separate code
path — `claude_coach_service.ask_anonymous_coach()` — which has NO
gate wrapper. Therefore the closed-world gate does NOT protect
anonymous-session narrator output today.

### Symptom observed (Maestro G1 second run, 2026-05-10T21:18Z)

Profile-empty anonymous user typed « combien je gagne ». Narrator
emitted :

> « Salut. Dis-moi ce qui te trotte... ... Je ne connais pas encore
>  ton revenu — tu ne me l'as pas indiqué. Mais voici un angle mort
>  intéressant : en Suisse, **le salaire médian tourne autour de
>  6 500 CHF bruts par mois**, pourtant très peu de gens savent ce
>  qu'ils gagnent **réellement** une fois soustraits les trois piliers,
>  l'assurance maladie et l'impôt à la source (si concerné). **La
>  différence entre brut et net disponible peut atteindre 25 à 30%.** »

Two uncited number families surfaced :
- **« 6 500 CHF bruts par mois »** — currency, NO `{{cite:<key>}}`
  adjacent. Closed-world breach.
- **« 25 à 30% »** — percentage, NO `{{cite:<key>}}` adjacent.
  Closed-world breach.

Screenshot evidence : `~/.maestro/tests/2026-05-10_211635/screenshot-❌-1778440705686-(flow_narrator_refuses_uncited_numbers).png`.

### Why this is a Rule 4 (architectural) item, not a Rule 2 auto-fix

Plan 94-03 `files_modified` frontmatter explicitly lists 9 files :

- `services/backend/tools/eval_narrator.py`
- `services/backend/tests/fixtures/citation_gate_eval_50.jsonl`
- `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml`
- 3 eval-run JSON outputs
- `94-03-EVAL-RESULTS.md` + `94-03-FLAG-FLIP-PROPOSAL.md` + `94-03-SUMMARY.md`

`anonymous_chat.py` is NOT on the list. Wiring the gate on a second
endpoint changes the structural surface protected by the closed-world
contract — that is Phase 96 (CHAT-AS-VERB) territory per CONTEXT
`Out of scope (deferred)` § « Multi-turn citation continuity ... Phase
94 only gates a single narrator response ». Anonymous narrator is a
distinct entry point that today's wave does not cover.

### Wave 2 (Plan 94-03) downstream effect

The Maestro G1 flow as currently authored exercises the anonymous
path. Since the gate is not wired there, the flow CANNOT verify the
closed-world contract end-to-end without wiring the gate on the
anonymous endpoint first.

**Two paths forward** :

1. **Defer Maestro G1 to Wave 4 / Phase 96** — Plan 94-03 close-out
   acknowledges the gate is wired only on the auth coach path. G1 is
   recorded as DEFERRED with a Phase 96 follow-up ticket. Stage 3
   eval (50-fixture pack, both Sonnet + Haiku) IS the Phase 94
   verification, because the eval harness calls `gate()` directly
   on the narrator response (not via the API endpoint), so the
   protection contract IS measured.

2. **Wire the gate on `anonymous_chat.py` in this plan** — adds 1 file
   to `files_modified`, mirrors the `coach_chat.py:_run_narrator_with_gate`
   closure pattern, lands tests. Then re-run Maestro G1.

### Recommendation

**Option 1.** The 5-gate exit contract per CONTEXT §Strategic Frame is :
G1 Maestro flow / G2 Julien device / G3 dev CI / G4 regression suite /
G5 LSFin+accent+ARB lint. G1 SHOULD be deferred to Wave 4 (or even
Phase 96) IF Julien accepts that the eval-pack Stage 3 numbers carry
the closed-world contract for the auth-coach path, AND a follow-up
ticket explicitly tracks the anonymous-path gate wiring.

This preserves Karpathy #3 surgical scope (don't expand a wave's
files_modified mid-execution) AND maintains 0-trust (the Plan 94-03
SUMMARY says exactly « G1 deferred ; gate verified on auth-coach
path only ; anonymous-path gate wiring is Wave 4 territory »).

The 50-fixture Stage 3 eval below — the next deliverable in Plan
94-03 — exercises `citation_parser.gate()` directly on the narrator
response with `is_retry=False` and `is_retry=True`, so it remains the
deterministic verification of the closed-world contract for any
narrator call. The eval pack is path-agnostic — it tests the gate
function, not the endpoint.

---

*Surfaced 2026-05-10 by Plan 94-03 executor. Awaits Julien GO/NO-GO
on `approved-deferred-g1` / `wire-gate-anonymous-now` / other.*
