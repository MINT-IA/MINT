---
name: autoresearch-prompt-lab
description: "Autonomous prompt optimizer for MINT coach AI. Modifies ONE aspect → scores mechanically against immutable eval fixtures → keeps if +3 improvement. Use with /autoresearch-prompt-lab or /autoresearch-prompt-lab 30."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch Prompt Lab v3 — Karpathy Prompt Optimizer

> "The coach prompt is the product. Every word shapes trust, compliance, and action."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `compliance_score` (binary: pass/fail on all 10 red lines). This NEVER decreases.
- **Secondary metric**: `mechanical_quality_score` — measured by grep/wc, NOT by LLM self-evaluation.
- **Time budget**: 5 min per modification. Score → modify ONE thing → re-score → keep/discard.
- **Single change**: ONE aspect per iteration. Never rewrite entire prompts.
- **Threshold**: keep only if delta >= +3 points. Below → discard.

## Context Budget Protocol

Your context window is a finite resource. Quality degrades as it fills.

| Tier | Context Used | Behavior |
|------|-------------|----------|
| PEAK | 0-30% | Full operations. Read freely, explore, try multiple approaches. |
| GOOD | 30-50% | Normal. Prefer targeted reads over exploratory. |
| DEGRADING | 50-70% | Economize. No exploration. Targeted fixes only. Warn in log. |
| POOR | 70%+ | STOP new iterations. Finish current only. Write report. Commit. |

### Degradation Warning Signs — STOP and assess if you notice:

- **Silent partial completion**: Claiming done but skipping verify steps you'd normally follow.
- **Increasing vagueness**: Writing "appropriate handling" instead of specific code references.
- **Skipped steps**: Iteration normally has 6 steps but you only did 4.

If ANY sign is present → treat as POOR tier. Write final report and stop.

### Iteration Budget

Estimate remaining iterations: `(100 - context_used%) / 3`.
At < 10 remaining → plan exit. At < 5 → STOP. Report only.

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

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY prompt modification, before reporting it as kept:

1. **RUN** the mechanical scoring commands fresh on the modified prompt. Paste exact breakdown.
2. **COMPARE** numerically: new_composite - old_composite >= +3? If not → DISCARD.
3. **RUN** compliance check: `grep -oiE "garanti|certain|..." <prompt>` — must return 0.
4. Every 5 modifications → `flutter test 2>&1 | tail -5`. Paste output.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "The prompt feels more natural now" | Score mechanically. Feelings are not data. |
| "Compliance is implied" | Explicit > implicit. Add the guardrail phrase and verify. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. If compliance regressed → DISCARD immediately, no exceptions. Return to the Loop.

Claiming work is complete without verification is dishonesty, not efficiency.

### Common Failures — what your claim REQUIRES (Superpowers)

| Claim | Requires | NOT Sufficient |
|-------|----------|----------------|
| "Compliance passes" | Fresh compliance check: 0 banned terms | Previous check, "should pass" |
| "Score improved" | Delta >= +3, measured mechanically | "Looks better", LLM self-evaluation |
| "No regressions" | Full eval fixtures re-scored, all pass | Running only one fixture |
| "Iteration complete" | All loop steps executed + output pasted | Steps skipped, partial evidence |
| "Ready to commit" | Compliance + score + tests all green, this iteration | Green from previous iteration |

### Red Flags — STOP if you catch yourself doing ANY of these:

- Using "should", "probably", "seems to" about test results
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit without fresh verification in THIS iteration
- Trusting a previous run's results after code changed
- Relying on partial verification ("I tested the main case")
- Thinking "just this once I can skip verification"
- Feeling rushed and wanting to move to the next iteration
- Using different words to dodge this rule ("appears to work" = "should work")
- Reporting fewer steps than the loop specifies (silent step-skipping)

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
