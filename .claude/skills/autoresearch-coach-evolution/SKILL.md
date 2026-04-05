---
name: autoresearch-coach-evolution
description: "Autonomous coaching content optimizer. Scores text MECHANICALLY (grep/wc, not LLM), generates 3 variants, keeps best if +5 points. Pattern: concret → émotionnel → actionnable. Use with /autoresearch-coach-evolution or /autoresearch-coach-evolution 30."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch Coach Evolution v3 — Karpathy Content Optimizer

> "Coaching content must fight drop-off. Pattern: concret → émotionnel → actionnable."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `mechanical_score` (0-100) measured by grep/wc. NOT by LLM self-evaluation.
- **Time budget**: 5 min per text. Score → generate 3 variants → pick best → keep if +5 → next.
- **Threshold**: +5 minimum improvement. Below → discard all variants, move on.
- **Single target**: ONE coaching text per iteration.
- **Guard**: `flutter gen-l10n` must succeed. `flutter test` every 5 optimizations.

## Mechanical Scoring (immutable eval — agent CANNOT modify these rules)

Each text is scored by **counting measurable properties**:

```bash
TEXT="$(cat text_to_score)"

# Concreteness (0-20): count CHF amounts, percentages, dates
concrete=$(echo "$TEXT" | grep -oE "[0-9]+['\u2019]?[0-9]*\s*CHF|[0-9]+\s*%|[0-9]{4}" | wc -l)
# 0 matches = 0, 1 = 5, 2 = 10, 3 = 15, 4+ = 20

# Jargon penalty (0-15): unexplained technical terms
jargon=$(echo "$TEXT" | grep -oiE "LPP|AVS|LIFD|OPP|LAMal|LAVS|taux de conversion|déduction de coordination|salaire coordonné|bonification" | wc -l)
# 0 terms = 15, 1 = 10, 2 = 5, 3+ = 0

# Brevity (0-10): word count
words=$(echo "$TEXT" | wc -w)
# 50-100 = 10, 100-150 = 7, 150-200 = 4, 200+ = 0, <50 = 5

# Actionability (0-20): action phrases
actions=$(echo "$TEXT" | grep -oiE "tu peux|envisage|compare|vérifie|demande|contacte|calcule|simule|note que" | wc -l)
# 0 = 0, 1 = 7, 2 = 14, 3+ = 20

# Emotional hook (0-20): relatable words
emotion=$(echo "$TEXT" | grep -oiE "imagine|ressens|inquiet|tranquille|serein|stress|confiance|peur|envie|bonne nouvelle" | wc -l)
# 0 = 0, 1 = 7, 2 = 14, 3+ = 20

# Compliance gate (binary): banned terms
banned=$(echo "$TEXT" | grep -oiE "garanti|certain|assuré|sans risque|optimal|meilleur|parfait|conseiller" | wc -l)
# >0 = REJECT IMMEDIATELY (score = 0)

# MINT voice (0-15): informal "tu", conditional
voice=$(echo "$TEXT" | grep -oiE "tu |pourrait|envisager|une option|un·e spécialiste" | wc -l)
# 0 = 0, 1 = 5, 2 = 10, 3+ = 15

# TOTAL = concrete + jargon_free + brevity + actions + emotion + voice (max 100)
```

## Context-Based Weight Adjustment

> Segmentation by life event and literacy level — NEVER by age (CLAUDE.md §1).

| Context | Trigger (life event or literacy) | Adjustment |
|---------|----------------------------------|------------|
| First financial event | `firstJob`, first `housingPurchase` | Standard weights |
| Building phase | `marriage`, `birth`, `housingPurchase`, `concubinage` | Concreteness weight ×1.25 |
| Complexity peak | `selfEmployment`, `inheritance`, `divorce`, `countryMove` | Concreteness ×1.25, Guardrail ×1.25 |
| Transition event | `retirement`, `jobLoss`, `disability`, `housingSale` | Actionability weight ×1.25 |
| Mobility event | `cantonMove`, `countryMove` | Standard weights (concreteness ×1.1 for tax implications) |
| Legacy event | `donation`, `deathOfRelative` | Jargon-free ×1.5, brevity ×1.5 |
| Career change | `newJob` | Standard weights |
| Literacy: beginner | `literacy_level = beginner` | Jargon-free weight ×1.5 |
| Literacy: advanced | `literacy_level = advanced` | Concreteness weight ×1.5 |
| Crisis mode | `debtCrisis`, Safe Mode active | Brevity ×1.5, Actionability ×1.5, emotion = empathy only |

**Precedence (when multiple events):** Crisis mode > Complexity peak > Transition > Building > Mobility > Standard. Apply the HIGHEST-priority context's weights. Do NOT stack multipliers.

## The Loop

```
┌─ INVENTORY: Find coaching content:
│  grep -rl "coaching\|fallback\|template\|insight\|tip" lib/services/ lib/data/ --include="*.dart"
│  grep -n "coach\|insight\|tip\|conseil" lib/l10n/app_fr.arb | head -30
│
├─ BASELINE: Score every text. Sort ascending. Record in TSV.
│
├─ SELECT: Lowest-scoring text not yet optimized.
│
├─ GENERATE (≤3 min): 3 variants. Each must:
│  - Keep same information (never invent facts)
│  - Follow: concret → émotionnel → actionnable
│  - Use MINT voice (tu, conditional, inclusive)
│  - Be shorter or equal in word count
│  - Pass compliance gate (0 banned terms)
│
├─ SCORE: Score all 3 mechanically. Pick best.
│
├─ EVALUATE:
│  Best variant >= +5 vs original → KEEP, apply edit.
│  Best variant < +5 → DISCARD ALL, log, move on.
│
├─ VERIFY:
│  If ARB change → flutter gen-l10n (must succeed)
│  Every 5 optimizations → flutter test
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add ... && git commit -m "coach: optimize <key> (+N points)"
│
└─ REPEAT until: budget exhausted | all texts >= 75 | 3 consecutive discards (plateau)
```

## Good Pattern

```
[CHF number or concrete fact]           ← concret
[Why this matters to YOU]               ← émotionnel
[1-3 things you can do about it]        ← actionnable
```

## Bad Patterns (fix these)

| Anti-pattern | Fix |
|-------------|-----|
| Abstract opening ("La prévoyance est importante") | Start with a CHF number |
| Jargon dump ("Le taux de conversion LPP...") | Plain language first, source in footnote |
| No action ("Voilà ta situation") | Add "Tu peux..." with 1-3 steps |
| Formal tone ("Vous devriez consulter") | "Tu pourrais en parler à un·e spécialiste" |
| Too long (250+ words) | Cut to 80 words |
| Fear-based ("Attention, tu risques...") | "Bonne nouvelle, tu peux encore..." |

## Rules

- **NEVER invent financial facts** — only reframe existing information
- **NEVER use banned terms** — garanti, certain, assuré, sans risque, optimal, meilleur, parfait, conseiller
- **NEVER be prescriptive** — use "pourrait", "envisager", "une option serait"
- **+5 minimum threshold** — no churn for marginal gains
- **Accents MANDATORY** — prévoyance, impôt, être, retraité
- **NBSP before double punctuation** — `\u00a0` before `!?:;%`
- **Preserve placeholders** — {amount}, {name} must survive
- **Keep under 100 words** when possible

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY optimization, before reporting it as kept:

1. **RUN** the mechanical scoring commands fresh on the NEW text. Not from memory.
2. **PASTE** the exact score breakdown (concrete, jargon, brevity, actions, emotion, voice) in your log.
3. **COMPARE** numerically: new_score - old_score >= +5? If not → DISCARD. No exceptions.
4. **RUN** `flutter gen-l10n` if ARB changed. Paste output. Every 5 optimizations → `flutter test`.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "The text reads better now" | Score it mechanically. Feelings are not data. |
| "The LLM would prefer this version" | LLM opinion is not a metric. grep/wc only. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. Return to the Loop and retry with a different variant. If stuck 3x on same text → log as `discard` and move to next target.

Claiming work is complete without verification is dishonesty, not efficiency.

## Experiment Log (append-only)

```
iteration  file               key                score_before  score_after  delta  status
1          fallback_templates greeting           35            72           +37    keep
2          app_fr.arb         insightLppBuyback  55            58           +3     discard (<5)
3          app_fr.arb         retirementTip1     40            78           +38    keep
```

## Final Report

```
AUTORESEARCH COACH EVOLUTION — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y

Avg score: X → Y (+Z)
Texts improved (+5): K | Attempts discarded: J

KEPT: [file, key, before, after, delta]
DISCARDED: [file, key, score, best_variant, delta]

EXPERIMENT LOG:
iter  file  key  before  after  delta  status
1     ...
```

## Invocation

- `/autoresearch-coach-evolution` — 20 attempts (default)
- `/autoresearch-coach-evolution 30` — deep optimization
- `/autoresearch-coach-evolution 50` — comprehensive pass
