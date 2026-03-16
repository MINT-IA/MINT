---
name: autoresearch-coach-evolution
description: "Autonomous coaching content optimizer. Scores coaching text mechanically, generates 3 variants, keeps best if +5 points improvement. Use with /autoresearch-coach-evolution or /autoresearch-coach-evolution 30."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(grep:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Coach Evolution — Autonomous Coaching Content Optimizer

## Philosophy

Coaching content in MINT must fight drop-off. Every coaching text is scored mechanically on a composite scale. The agent generates 3 variants per text, keeps the best one only if it improves by at least +5 points. Pattern: **concret -> emotionnel -> actionnable**.

## Composite Score (0-100)

Each coaching text is scored on these criteria:

| Criterion | Weight | 0 points | 50 points | 100 points |
|-----------|--------|----------|-----------|------------|
| **Concreteness** | 20% | Abstract, no numbers | Some specifics | CHF amounts, dates, percentages |
| **Emotional hook** | 20% | Dry, technical | Some empathy | Opens with relatable scenario or feeling |
| **Actionability** | 20% | No next step | Vague suggestion | 1-3 specific, doable actions |
| **Jargon-free** | 15% | Heavy jargon, no explanation | Some jargon explained | Plain language throughout |
| **Brevity** | 10% | >200 words | 100-200 words | 50-100 words (sweet spot) |
| **MINT voice** | 10% | Formal "vous", prescriptive | Mixed | Informal "tu", conditional, inclusive |
| **Compliance** | 5% | Banned terms present | Minor issues | Clean: no garanti/optimal/conseiller |

**Composite** = weighted sum of all criteria.

## Scoring Commands

To mechanically score a text, check these measurable proxies:

```bash
# Concreteness: count CHF amounts, percentages, dates
echo "$TEXT" | grep -oE "[0-9]+['\u2019]?[0-9]*\s*CHF|[0-9]+\s*%|[0-9]{4}" | wc -l

# Jargon: count unexplained technical terms
echo "$TEXT" | grep -oiE "LPP|AVS|LIFD|OPP|LAMal|LAVS|taux de conversion|deduction de coordination|salaire coordonne|bonification" | wc -l

# Brevity: word count
echo "$TEXT" | wc -w

# Compliance: banned terms
echo "$TEXT" | grep -oiE "garanti|certain|assure|sans risque|optimal|meilleur|parfait|conseiller" | wc -l

# Actionability: count imperative/action phrases
echo "$TEXT" | grep -oiE "tu peux|envisage|compare|verifie|demande|contacte|calcule|simule|note que" | wc -l

# Emotional: check for relatable hooks
echo "$TEXT" | grep -oiE "imagine|ressens|inquiet|tranquille|serein|stress|confiance|peur|envie" | wc -l
```

## Loop Structure (9 Phases)

### Phase 1 — INVENTORY

Find all coaching content files:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# Coaching templates / fallback content
grep -rl "coaching\|fallback\|template\|insight\|tip\|conseil" lib/services/coach/ lib/data/ lib/widgets/ --include="*.dart" | head -20

# Education inserts
ls /Users/julienbattaglia/Desktop/MINT/education/inserts/

# ARB coaching keys
grep -n "coach\|insight\|tip\|conseil\|astuce" lib/l10n/app_fr.arb | head -30
```

### Phase 2 — BASELINE

Score every coaching text found. Record in TSV:

```
file	key_or_line	text_preview	score	concreteness	emotional	actionability	jargon	brevity	voice	compliance
coach_templates.dart	greeting	"Bonjour ! Voici..."	45	30	20	50	80	60	40	100
```

Sort by score ascending. The lowest-scoring texts are the highest priority.

### Phase 3 — SELECT TARGET

Pick the lowest-scoring text that hasn't been optimized yet.

### Phase 4 — GENERATE 3 VARIANTS

For the selected text, generate 3 improved variants. Each variant must:

1. **Keep the same information** (don't invent facts)
2. **Follow the pattern**: concret -> emotionnel -> actionnable
3. **Use MINT voice**: informal "tu", conditional ("pourrait", "envisager"), inclusive ("un-e specialiste")
4. **Stay compliant**: no banned terms
5. **Be shorter or equal** in word count

Example transformation:

**Before** (score 35):
```
"La LPP est le deuxieme pilier. Le taux de conversion est de 6.8%.
Vous pouvez faire un rachat pour ameliorer votre rente."
```

**After** (score 78):
```
"Ton 2e pilier va te verser environ {monthlyRente} CHF/mois a la retraite.
C'est souvent moins que prevu... mais tu peux agir : un rachat de {buybackAmount} CHF
augmenterait ta rente de {renteDelta} CHF/mois, et c'est deductible des impots."
```

### Phase 5 — SCORE VARIANTS

Score all 3 variants using the same criteria table.

### Phase 6 — KEEP OR DISCARD

- If the best variant scores **+5 points or more** than the original: **KEEP IT**. Apply the edit.
- If no variant improves by +5: **DISCARD ALL**. Log the attempt and move on.

This threshold prevents churn (changing text for marginal improvement).

### Phase 7 — VERIFY

After each text replacement:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# If text was in ARB: regenerate
flutter gen-l10n 2>&1

# Check no banned terms introduced
grep -n "garanti\|sans risque\|optimal\|meilleur\|parfait\|conseiller" lib/l10n/app_fr.arb | tail -5

# Analyze
flutter analyze 2>&1 | tail -5
```

Every 5 optimizations, run:

```bash
flutter test 2>&1 | tail -10
```

### Phase 8 — LOG

Append to session log (TSV format).

### Phase 9 — REPEAT

Go back to Phase 3 until:
- Budget exhausted
- All texts score >= 75 (quality floor reached)
- 3 consecutive attempts with 0 improvements (all variants < +5 delta)

## Strict Rules

1. **NEVER invent financial facts.** Variants must contain the same information as the original. Only the framing, tone, and structure can change.
2. **NEVER use banned terms.** garanti, certain, assure, sans risque, optimal, meilleur, parfait, conseiller — all BANNED in user-facing text.
3. **NEVER be prescriptive.** Use conditional language: "pourrait", "envisager", "une option serait". Never "tu dois", "il faut".
4. **+5 minimum improvement threshold.** Do not apply changes for marginal gains. Log and move on.
5. **Accents are mandatory.** prevoyance -> prevoyance (with accents). impot -> impot (with accents). This is French, not ASCII.
6. **NBSP before double punctuation.** `\u00a0` before `!`, `?`, `:`, `;`, `%` in French text.
7. **Preserve placeholders.** If the original has `{amount}` or `{name}`, the variant must keep them.
8. **Keep it under 100 words** when possible. Coaching text should be scannable, not a wall of text.
9. **Run flutter gen-l10n after ARB changes.** If it fails, fix syntax before continuing.
10. **If tests break, fix immediately** before continuing.

## Content Quality Patterns

### Good pattern: concret -> emotionnel -> actionnable

```
[CHF number or concrete fact]
[Why this matters to YOU — emotional connection]
[1-3 things you can do about it — specific, doable]
```

### Bad patterns to fix

| Anti-pattern | Example | Fix |
|-------------|---------|-----|
| Abstract opening | "La prevoyance est importante" | Start with a CHF number |
| Jargon dump | "Le taux de conversion LPP selon l'art. 14..." | Plain language first, source in footnote |
| No action | "Voila ta situation" | Add "Tu peux..." with 1-3 steps |
| Formal tone | "Vous devriez consulter un conseiller" | "Tu pourrais en parler a un-e specialiste" |
| Too long | 250+ words of explanation | Cut to 80 words, link to "En savoir plus" |
| Fear-based | "Attention, tu risques de..." | "Bonne nouvelle, tu peux encore..." |

## TSV Session Log Format

```
attempt	file	key	score_before	score_after	delta	kept	reason
1	coach_templates.dart	greeting	35	72	+37	YES	concret+emotional hook
2	app_fr.arb	insightLppBuyback	55	58	+3	NO	delta < 5
3	app_fr.arb	retirementTip1	40	78	+38	YES	full rewrite pattern
```

## Final Output

```
## Autoresearch Coach Evolution — Session Report

**Date**: YYYY-MM-DD
**Branch**: feature/S{XX}-...
**Budget**: X attempts used / Y total

### Results
| Metric | Before | After |
|--------|--------|-------|
| Texts scored | N | N |
| Avg score | X | Y |
| Texts improved (+5) | - | K |
| Texts attempted (no gain) | - | J |

### Improvements Applied
| File | Key | Before | After | Delta |
|------|-----|--------|-------|-------|
| coach_templates.dart | greeting | 35 | 72 | +37 |
| app_fr.arb | retirementTip1 | 40 | 78 | +38 |

### Attempts Discarded (delta < 5)
| File | Key | Score | Best variant | Delta |
|------|-----|-------|-------------|-------|
| app_fr.arb | insightLppBuyback | 55 | 58 | +3 |

### Score Distribution
| Range | Count before | Count after |
|-------|-------------|-------------|
| 0-25 | X | Y |
| 25-50 | X | Y |
| 50-75 | X | Y |
| 75-100 | X | Y |
```

## Invocation

- `/autoresearch-coach-evolution` — run with default budget of 20 attempts
- `/autoresearch-coach-evolution 30` — run with budget of 30 attempts
- `/autoresearch-coach-evolution 50` — run with budget of 50 attempts

The number is the maximum number of text optimization attempts. Each attempt = 1 text scored + 3 variants generated + best kept or discarded.
