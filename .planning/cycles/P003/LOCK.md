---
description: P003 Pillar 7 Regression Lock — 3 layers protecting against recurrence. Per MDM v1.
type: cycle-lock
bug_id: P003
phase: 97-w7
created: 2026-05-12
---

# P003 — Regression Lock

The bug is FIXED when code lands ; it is LOCKED when the 3 layers below
ensure no future PR can silently regress the same defect.

## Layer 1 — Test (CI-enforced)

File : `services/backend/tests/test_citation_gate/test_p003_user_input_awareness.py`
12 tests covering :
- Extractor surfaces all 4 user numbers from Julien's verbatim prompt (the literal regression case).
- Extractor handles Swiss notation : apostrophe (`7'600`), regular space (`300 000`), no separator.
- Gate exempts user-input numbers when kwarg is populated.
- Gate rejects fabricated numbers (not in user message) — adversarial preservation.
- Banned-claim verb regex still fires on user-input numbers (« vous gagnerez 7600 » → REJECTED_BANNED_CLAIM) — LSFin no-promise invariant.
- Byte-identity when `user_input_numbers=None` — preserves pre-P003 behaviour on the flag-OFF path.
- The « 49 ans » duration edge case (extracted AND exempted).

These tests run in every CI invocation of the Phase 94 citation_gate
suite. Future PRs that break the contract fail this file → PR blocked.

## Layer 2 — Lint (citation_grammar parity check)

Deferred to a follow-up PR within this cycle (filed as a Karpathy #3
surgical separation : the parity check itself is its own perimeter).

The intended check, `tools/checks/citation_grammar_parity.py`, will
assert that the narrator system prompt fragment at
`services/backend/app/services/coach/citation_grammar.py` accurately
describes the gate's actual exemption set. Specifically :
- The fragment must NOT contain the previous lie wording (« la garde
  reconnaît les négations et les méta-citations » when talking about
  user-input numbers ; that specific phrasing is forbidden as a
  regression marker).
- The fragment SHOULD contain the new accurate wording (some derivative
  of « la garde reconnaît automatiquement les chiffres présents dans
  le message de l'utilisateur »).
- The fragment must NOT teach the narrator to emit FALLBACK_TEMPLATED_TEXT
  verbatim as an "ACCEPTÉ" example.

For this cycle, the post-P003 fragment text is the authoritative
state ; the parity lint formalises that bond in a follow-up.

## Layer 3 — Documentation

### `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` D-04 amendment

D-04 (the gate's exemption rules) is amended to add bullet #5 :

```
5. P003 (2026-05-12) — User-input numbers : if the matched numeric
   token normalises (Swiss-notation aware Decimal) to a value the
   user supplied in their own message (`body.message` + last 8 user
   turns of `conversation_history`), the gate skips it as exempted.
   This brings the gate's behaviour into alignment with the narrator
   system prompt fragment that has always promised this exemption.
   Single source of truth : `citation_parser.extract_user_input_numbers`
   + the `user_input_numbers` kwarg on `gate(...)`.
```

The full amendment is filed inline at
`.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` in this PR.

### Cycle artifact

This LOCK document, plus the rest of `.planning/cycles/P003/` (CONTEXT,
PANEL, REPRO-AND-RCA, FIX-DECISION, VERIFICATION, LOCK), is the
permanent ground truth. PR description links to this folder. The
BUGS-REGISTRY row links to it too.

## Future-proofing notes

- The new `extract_user_input_numbers` helper is intentionally
  permissive on Swiss notation. Future locales (German `1.234,56`
  vs French `1 234,56`) may surface edge cases. Add fixtures as they
  appear, not pre-emptively.
- The exemption set passed to the gate is `frozenset[Decimal]`. Decimal
  was chosen over float to avoid floating-point comparison drift on
  decimal fractions like `7.5%`. Future PRs MUST NOT migrate to float.
- The kwarg name `user_input_numbers` is a stable API contract. The
  Phase 96 chat-as-verb path also passes this kwarg through (verified
  by `test_chat_as_verb/` 12/12 PASS) — both paths share the same
  exemption mechanism.
