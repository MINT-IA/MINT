---
name: autoresearch-coach-evolution
description: Autonomous autoresearch loop for coaching content quality. Generates N variants of coaching text (tips, chiffres-chocs, alertes), scores them mechanically, keeps the best. Invoke with /autoresearch-coach-evolution or /autoresearch-coach-evolution 30.
compatibility: Requires Flutter SDK, git. Works on education/inserts/ and apps/mobile/lib/.
allowed-tools: Bash(flutter:*) Bash(grep:*) Bash(git:*) Bash(wc:*) Bash(cd:*) Bash(tail:*) Bash(date:*) Bash(echo:*) Bash(cat:*)
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Coach Evolution — Content quality optimization loop

## Purpose

You are an **autonomous coaching content optimizer**. You score existing coaching text mechanically, generate 3 variants, keep the best if it improves by >= 5 points. The text is the "weights", the composite score is the "loss function".

## Scope: what content to optimize

1. **Educational inserts** (`education/inserts/`) — per-question explanations
2. **Coaching tips** in services (`coachingTip`, `microAction`, `narrative`)
3. **Chiffres-chocs** (`chiffreChoc`) — impactful number hooks
4. **Alertes** (`alertes`) — threshold warnings

## Composite Score (0-100)

For each text content, compute:

| Criterion | Weight | Ideal | Scoring |
|-----------|--------|-------|---------|
| **Length** | 15% | Tips: 50-150 chars, chiffres-chocs: 20-80 chars | 100 if in range, -2 per char outside, min 0 |
| **Readability** | 20% | < 20 words per sentence | 100 - (avg_words_per_sentence - 15) * 5, min 0 |
| **Tutoiement** | 10% | Uses "tu/ton/ta/tes", NOT "vous/votre" | 100 if tu-form, 0 if vous-form |
| **FR accents** | 10% | All accents correct (é not e, etc.) | 100 if correct, -10 per missing accent |
| **Compliance** | 25% | 0 banned terms + disclaimer if financial result + legal source cited | 100 if all OK, -25 per violation |
| **Actionable** | 20% | Contains action verb: vérifie, compare, demande, calcule, contacte, note, planifie | 100 if present, 50 if absent |

**Total** = weighted sum of all criteria.

### Scoring commands

```bash
# Length
echo -n "<text>" | wc -c

# Readability (words per sentence)
echo "<text>" | tr '.!?' '\n' | awk '{print NF}'

# Tutoiement
echo "<text>" | grep -c "tu \|ton \|ta \|tes "
echo "<text>" | grep -c "vous \|votre "

# Compliance — banned terms
echo "<text>" | grep -ci "garanti\|certain\|assuré\|sans risque\|optimal\|meilleur\|parfait"

# Actionable
echo "<text>" | grep -ci "vérifie\|compare\|demande\|calcule\|contacte\|note\|planifie"
```

## Loop (9 phases per iteration)

### Phase 1: INVENTORY
List all coaching content:
```bash
grep -rn "coachingTip\|chiffreChoc\|microAction\|narrative\|alertes" apps/mobile/lib/ education/ --include="*.dart" --include="*.md" -l
```

### Phase 2: SELECT
Pick the content with the lowest composite score.

### Phase 3: SCORE
Calculate the composite score of the current content.

### Phase 4: GENERATE
Produce 3 variants of the same content:
- Same factual information
- Improved formulation targeting weak criteria
- Always tu-form, inclusive, no banned terms
- Use placeholders for numbers (`{montant}`, `{pourcentage}`) — never invent figures

### Phase 5: SCORE ALL
Score all 3 variants + the original.

### Phase 6: SELECT BEST
Keep the variant with the highest score.

### Phase 7: APPLY
If best variant > original by >= 5 points:
a. Replace text in source file
b. `git commit -m "autoresearch-coach: improve <content_id> score <old>→<new>"`
c. Verify: `cd apps/mobile && flutter analyze 2>&1 | tail -3` + `flutter test 2>&1 | tail -5`
d. If regression → `git revert HEAD --no-edit`

If delta < 5 points → **SKIP** (not worth the churn).

### Phase 8: LOG
Append to `autoresearch-coach-results.tsv`:
```
iteration	content_id	file	type	score_before	score_after	delta	length	compliance	status
```

On first iteration, create the TSV with this header.

### Phase 9: REPEAT
Next content. Stop when max iterations reached or all content scored >= 80.

## Strict Rules

- **NEVER** modify calculation logic (only displayed text)
- **NEVER** invent numbers in chiffres-chocs (use placeholders `{montant}`, `{pourcentage}`)
- **NEVER** use banned terms: garanti, certain, optimal, meilleur, parfait, assuré, sans risque
- **ALWAYS** use informal tutoiement ("tu")
- **ALWAYS** use inclusive writing when applicable ("un·e spécialiste")
- Variants must be **factually identical** (same information, better formulation)
- **Minimum improvement threshold**: +5 points to justify a change
- **Maximum 60 iterations** per session (content optimization is slower than code fixes)
- TSV file at project root: `autoresearch-coach-results.tsv`

## Invocation

The user types `/autoresearch-coach-evolution` or `/autoresearch-coach-evolution 30`.

## Final Output

```
AUTORESEARCH-COACH-EVOLUTION SESSION SUMMARY
==============================================
Contents analyzed: X
Improved: Y (avg +Z.Z points)
Skipped: W (delta < 5 points)
Discarded: V (test regression)

SCORE DISTRIBUTION:
  Before: avg=XX, min=YY, max=ZZ
  After:  avg=XX, min=YY, max=ZZ

TOP IMPROVEMENTS:
  - tip_budget_01: 62→78 (+16) "Vérifie ton budget..."
  - choc_avs_gap: 45→71 (+26) "{montant} CHF de lacune..."
  - ...

REMAINING LOW-SCORE CONTENTS (< 60):
  - <content_id>: score=XX, file=<path>
  - ...
```
