---
name: autoresearch-prompt-lab
description: "Autonomous prompt optimizer for MINT coach AI. Modifies ONE aspect → scores mechanically against immutable eval fixtures → keeps if +3 improvement. Use with /autoresearch-prompt-lab or /autoresearch-prompt-lab 30."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch Prompt Lab v2 — Karpathy Prompt Optimizer

> "The coach prompt is the product. Every word shapes trust, compliance, and action."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `compliance_score` (binary: pass/fail on all 10 red lines). This NEVER decreases.
- **Secondary metric**: `mechanical_quality_score` — measured by grep/wc, NOT by LLM self-evaluation.
- **Time budget**: 5 min per modification. Score → modify ONE thing → re-score → keep/discard.
- **Single change**: ONE aspect per iteration. Never rewrite entire prompts.
- **Threshold**: keep only if delta >= +3 points. Below → discard.

## Mutable / Immutable

| Mutable (ONE prompt per iteration) | Immutable (evaluation harness) |
|------------------------------------|-------------------------------|
| `lib/services/coach_llm_service.dart` (system prompts) | ComplianceGuard (must pass all output) |
| `lib/services/fallback_templates.dart` (offline templates) | CLAUDE.md § 6 (banned terms, rules) |
| | LEGAL_RELEASE_CHECK.md |
| | Eval fixtures below (agent cannot modify) |

## Mechanical Scoring (NOT LLM-judging-LLM)

Score each prompt by counting measurable properties:

```bash
PROMPT="$(cat prompt_text)"

# Compliance (binary gate — must be 100%)
echo "$PROMPT" | grep -oiE "garanti|certain|assuré|sans risque|optimal|meilleur|parfait|conseiller" | wc -l
# Must be 0. If >0 → REJECT immediately.

# Actionability: count action instruction patterns
echo "$PROMPT" | grep -oiE "propose.*action|étape concrète|tu peux|next step|action.*priorit" | wc -l

# Brevity: word count (sweet spot: 200-400 words for system prompt)
echo "$PROMPT" | wc -w

# Guardrail density: count explicit constraints
echo "$PROMPT" | grep -oiE "ne jamais|toujours|interdit|obligatoire|never|always|must not" | wc -l

# Disclaimer instruction: must instruct AI to include disclaimer
echo "$PROMPT" | grep -oiE "disclaimer|avertissement|outil éducatif|ne constitue pas" | wc -l
```

**Composite** = guardrail_density × 3 + actionability × 4 + disclaimer × 5 + brevity_penalty
(brevity_penalty: 0 if 200-400 words, -2 per 50 words over 400, -1 per 50 words under 200)

## Sub-Prompts to Optimize (pick ONE per iteration)

| Prompt | Purpose |
|--------|---------|
| `system_prompt_general` | Default coaching mode |
| `system_prompt_safe_mode` | Debt crisis / toxic situation |
| `system_prompt_onboarding` | First-time user guidance |
| `system_prompt_simulation` | Calculation explanation mode |
| `system_prompt_jit_card` | Just-in-time educational cards |

## The Loop

```
┌─ BASELINE: Read all sub-prompts. Score each mechanically.
│  Record: prompt_name, word_count, guardrails, actionability, compliance, composite
│
├─ SELECT: Lowest-scoring (prompt, weakness) pair.
│
├─ MODIFY (≤3 min): Change ONE aspect:
│  - Add a compliance guardrail phrase
│  - Rephrase for clarity
│  - Add action template instruction
│  - Remove jargon
│  - Add disclaimer pattern
│  - Shorten (if >400 words)
│
├─ SCORE: Re-run mechanical scoring on modified prompt.
│
├─ EVALUATE:
│  delta >= +3 → KEEP, commit.
│  delta +1 to +2 → KEEP tentatively, verify no compliance regression.
│  delta <= 0 → DISCARD, revert.
│  ANY compliance regression → DISCARD immediately.
│
├─ LOG: Append to experiment log
│
├─ VERIFY: Every 5 modifications → flutter test 2>&1 | tail -5
│
├─ COMMIT: git add ... && git commit -m "prompt: improve <sub-prompt> <axis> (+N)"
│
└─ REPEAT until: budget exhausted | all prompts score >= 85 | 3 consecutive discards (plateau)
```

## Rules

- **NEVER invent financial facts** in prompts
- **NEVER use banned terms** (garanti, optimal, meilleur, sans risque, etc.)
- **Compliance axis NEVER decreases** — if change improves clarity but adds compliance risk → DISCARD
- **ONE change at a time** — never rewrite entire prompts
- **Fallback templates must work WITHOUT LLM** — they are the offline safety net
- **NEVER make prompts longer without measurable improvement**
- **NEVER add if/else logic in prompts** — keep declarative

## Experiment Log (append-only)

```
iteration  prompt              aspect        score_before  score_after  delta  status
1          general             actionability 62            68           +6     keep
2          safe_mode           empathy       55            58           +3     keep
3          onboarding          brevity       70            71           +1     keep (tentative)
4          simulation          clarity       65            64           -1     discard
5          general             guardrails    68            68           0      discard
```

## Final Report

```
AUTORESEARCH PROMPT LAB — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y

Per sub-prompt: [name] X → Y (+Z)
Compliance: 100% maintained ✅

KEPT:
  1. [+6] general — added "propose 1-3 actions concrètes" → actionability
  2. [+3] safe_mode — added empathy hook for debt → tone

DISCARDED:
  1. [-1] simulation — shorter intro lost clarity
  2. [+1] onboarding — marginal, below threshold

EXPERIMENT LOG:
iter  prompt  aspect  before  after  delta  status
1     ...
```

## Invocation

- `/autoresearch-prompt-lab` — 15 modifications (default)
- `/autoresearch-prompt-lab 30` — deep optimization
