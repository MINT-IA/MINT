---
description: P003 Pillar 6 Verification Cube — 4 GREEN dimensions with deterministic citations. Per MDM v1.
type: cycle-verification
bug_id: P003
phase: 97-w7
created: 2026-05-12
---

# P003 — Verification Cube

Per MDM Pillar 6, a bug is RESOLVED only when all 4 dimensions are GREEN
with deterministic citations. Status as of 2026-05-12T07:XXZ :

| Dim | Dimension | Status | Citation |
|---|---|---|---|
| 1 | Code correctness | GREEN | `tests/test_citation_gate/test_p003_user_input_awareness.py` 12/12 PASS in 0.22s |
| 2 | Integration correctness | GREEN | full backend `pytest tests/` → 6662 passed, 62 skipped, 1 xfailed in 111.13s ; `tools/checks/accent_lint_fr.py` clean on new files ; `tools/checks/banned_terms_python.py` clean on new code (pre-existing « assure » hit at coach_chat.py:3102 is OUT of P003 scope, Karpathy #3 surgical) |
| 3 | System correctness | PENDING — awaiting Railway redeploy on staging post-merge | Will be filled in after PR merge + Railway picks up the new code. The L3 curl with Julien's exact prompt should then return a non-empty, non-FALLBACK response in < 15s. |
| 4 | User correctness | PENDING — awaiting Julien sim re-test post-deploy | Will be filled in after Julien re-runs his 2026-05-12T08:13Z test on his sim and reports back. |

## Detailed citations

### Dim 1 — Code correctness (GREEN)

```
$ python3 -m pytest tests/test_citation_gate/test_p003_user_input_awareness.py -q
............                                                             [100%]
12 passed in 0.22s
```

Test coverage :
- 4 extractor correctness tests (Julien's prompt 4-number extraction, Swiss apostrophe, space-separated thousands, empty input).
- 7 gate exemption mechanics tests (pre-P003 baseline, post-P003 pass with kwarg, fabricated-number rejection still works, Swiss-format echo passes, byte-identity when kwarg None, banned-claim still caught, retry-not-needed on first-pass pass).
- 1 « 49 ans » duration edge case.

### Dim 2 — Integration correctness (GREEN)

```
$ python3 -m pytest tests/ -q --ignore=tests/test_dag_invalidation/test_hash_parity.py
... 6662 passed, 62 skipped, 1 xfailed in 111.13s (0:01:51)
```

Adjacent suites that exercise the gate path :
- `tests/test_citation_gate/` (190 + 12 P003 = 202 PASS)
- `tests/test_coach_chat_endpoint.py` (multi-test PASS)
- `tests/test_chat_as_verb/` (Phase 96 path, PASS)
- `tests/test_anonymous_chat.py` (anonymous chat, PASS)

Linters :
- `tools/checks/banned_terms_python.py` on the 4 P003 files : zero new violations. Pre-existing « assure » at `coach_chat.py:3102` belongs to a salary-formatter helper unrelated to P003 scope (filed as P004 hygiene candidate, not bundled per discipline).
- `tools/checks/accent_lint_fr.py --file citation_grammar.py --file test_p003_user_input_awareness.py` : zero output (clean).

### Dim 3 — System correctness (PENDING)

L3 re-run plan, executable after PR merge + Railway staging deploy :

```bash
# After merge to dev → staging, Railway picks up the new container.
# Wait ~3 min for deploy, then :

TOKEN="<staging debug auth token>"
JULIEN_PROMPT="j'ai 49 ans, je vis en Valais, je suis marié, je gagne 7600 CHF net par mois, j'ai 300 000 CHF de rachat potentiel dans mon deuxième pilier, et j'ai 5 comptes de troisième pilier, qu'est-ce que je dois faire ?"

curl -sS -w '\n---HTTP_STATUS:%{http_code}---TIME:%{time_total}---' \
  -X POST https://mint-staging.up.railway.app/api/v1/coach/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"$JULIEN_PROMPT\",\"provider\":\"claude\",\"language\":\"fr\"}" \
  --max-time 30
```

Expected post-fix :
- `HTTP_STATUS:200`
- `message` field NON-EMPTY and NOT equal to FALLBACK_TEMPLATED_TEXT
- `TIME` < 15s (no retry cascade)
- `responseMeta.degraded` = false

Pre-fix L3 baseline already captured at REPRO-AND-RCA.md (HTTP 200, message="", 7s wall, 15958 tokens — empty-narrator path).

### Dim 4 — User correctness (PENDING)

Julien re-tests on his sim with the same verbatim prompt after staging deploy. Expected :
- The coach bubble renders a substantive response that acknowledges his 49 ans / Valais / marié / 7'600 CHF / 300'000 CHF / 5 comptes 3a.
- Wall-time visibly shorter than the prior 30s observation.
- No « Je n'ai pas cette donnée pour l'instant » canned text.

This dimension is filled in by Julien's confirmation (chat reply or screenshot). The cycle is NOT closed until this is captured.

## Cycle exit blockers

- Dim 3 + Dim 4 must be GREEN before P003 row is marked RESOLVED in `97-BUGS-REGISTRY.md`. The PR can MERGE before they're green, but the bug stays IN_PROGRESS until they are. This matches MDM Pillar 6 contract.
