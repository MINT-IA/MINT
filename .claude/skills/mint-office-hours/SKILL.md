---
name: mint-office-hours
description: "8 questions de cadrage pre-feature + premise challenge + spec self-review. HARD GATE: pas de code avant approbation. Anti-sycophancy enforced. Use with /office-hours."
compatibility: Any
metadata:
  author: mint-team
  version: "2.0"
  source: "GStack /office-hours (6 Forcing Questions, pushback patterns, anti-sycophancy, escape hatch) + Superpowers /brainstorming (HARD GATE, one-at-a-time, spec self-review, YAGNI)"
---

# Office Hours v2 — Cadrage pre-code

> "If you can't answer 8 questions about your feature, you're not ready to code it."

## HARD GATE (NON-NEGOTIABLE)

**Do NOT write any code, create any file, modify any file, or invoke any implementation skill
until ALL questions are answered and the user has approved the design.**

This applies to EVERY feature regardless of perceived simplicity.
This applies to ANY file — screens, services, providers, configs, ARB files, tests.

Anti-pattern: "This is too simple to need cadrage" — Every feature goes through this process.
A config change, a label fix, a new button — all of them.

## When to use this skill

- Before any new feature
- Before any sprint
- Before any refactor that touches more than 3 files
- When the user says "je veux faire X" or "on devrait ajouter Y"
- NOT for bugfixes (the bug IS the cadrage)

## Anti-sycophancy rules (NON-NEGOTIABLE)

You MUST NOT say any of these phrases during cadrage:
- "That's an interesting approach"
- "There are many ways to do this"
- "You might want to consider..."
- "That could work"
- "I can see why you'd think that"

Instead: be direct. If an answer is vague, say "This answer is vague. I need specifics."
If a premise is wrong, say "I don't think this premise holds. Here's why."

## Escape hatch (if user is impatient)

If the user says "on a pas le temps" or "skip" or shows frustration:
1. Say: "OK, je comprends. Laisse-moi au moins poser les 2 questions les plus critiques."
2. Pick the 2 most relevant unanswered questions (usually Q1 POURQUOI + Q7 VERSION MINIMALE)
3. Get answers to those 2
4. Produce a MINIMAL design doc (flagged as "cadrage partiel")
5. Proceed — but note in the design doc: "Cadrage partiel — risque de scope creep"

## The 8 Questions (ask ONE AT A TIME, never in batch)

Ask each question, wait for the answer, then ask the next.
Prefer multiple-choice when possible (easier to answer, harder to dodge).
Adapt follow-ups based on answers.

### Q1 — POURQUOI maintenant ? (GStack: "Demand Reality")
"Quel impact utilisateur concret cette feature apporte-t-elle ?"

**Pushback patterns — if the answer sounds like:**
| Bad answer | Pushback |
|-----------|----------|
| "Les utilisateurs vont aimer" | "Quelle preuve ? Qui l'a demande ? Sois specifique." |
| "C'est une bonne pratique" | "Bonne pratique pour qui ? Quel probleme concret ca resout pour NOS utilisateurs ?" |
| "On devrait avoir ca" | "Pourquoi maintenant et pas dans 3 mois ? Qu'est-ce qui urge ?" |
| "C'est dans la roadmap" | "La roadmap dit quoi exactement ? Montre-moi la ligne." |

If the answer is "je sais pas" → the feature might not be necessary. Say so directly.

### Q2 — QUE FONT LES UTILISATEURS AUJOURD'HUI ? (GStack: "Status Quo")
"Comment les utilisateurs resolvent ce probleme aujourd'hui, meme mal ?"

- If there's a workaround → the feature replaces it. Measure the improvement.
- If there's nothing → the feature creates new behavior. Higher risk.
- If they use a competitor → which one? What does it do that we don't?

### Q3 — POUR QUI ? (GStack: "Desperate Specificity")
"Quel life event parmi les 18 ? Quel archetype parmi les 8 ?"

Life events (enum — pick at least one):
```
marriage, divorce, birth, concubinage, deathOfRelative,
firstJob, newJob, selfEmployment, jobLoss, retirement,
housingPurchase, housingSale, inheritance, donation,
disability, cantonMove, countryMove, debtCrisis
```

Archetypes (pick all affected):
```
swiss_native, expat_eu, expat_non_eu, expat_us,
independent_with_lpp, independent_no_lpp, cross_border, returning_swiss
```

If the answer is "tous" → push back: "Lequel est le plus impacte ? Nomme UNE personne reelle (Julien? Lauren? un ami?) qui beneficierait cette semaine."

### Q4 — QUELLES ALTERNATIVES ? (includes GStack: "do nothing")
"As-tu considere au moins 2 autres approches ?"
- Option A (proposed) vs Option B (simpler?) vs Option C (different angle?)
- If the user has only 1 idea → brainstorm 2 alternatives with trade-offs
- ALWAYS propose the "do nothing" option: "Que se passe-t-il si on ne fait rien ?"

### Q5 — QUELS RISQUES compliance ?
Check against CLAUDE.md §6 compliance rules:
- Banned terms: "garanti", "optimal", "meilleur", "parfait", "certain", "assure", "sans risque"
- Banned: "conseiller" → use "specialiste" (inclusive)
- No-advice: will this feature recommend specific products? (FORBIDDEN)
- No-promise: will this feature show guaranteed returns? (FORBIDDEN)
- No-ranking: will this feature rank options? (must be side-by-side)
- Privacy: will this feature log identifiable data? (FORBIDDEN)

If the feature touches calculators:
- Source: which law article? (LPP art. X, LIFD art. Y, LAVS art. Z)
- Disclaimer: mandatory on every output
- Confidence score: mandatory on every projection

### Q6 — QUEL IMPACT sur les 8 archetypes ?
"Cette feature fonctionne-t-elle pour :"
- swiss_native (modele par defaut) — probably yes
- expat_eu (totalisation periodes EU) — different AVS calc?
- expat_us (FATCA, double taxation) — special constraints?
- independent_no_lpp (3a max 36'288, pas de 2e pilier) — different path?
- cross_border (permis G, impot source) — different tax rules?

If the answer is "ca marche pareil pour tous" → challenge: "Es-tu sur ? Verifie les calculs pour expat_us et independent_no_lpp."

### Q7 — QUELLE EST LA VERSION MINIMALE ? (GStack: "Narrowest Wedge")
"Quelle est la plus petite version de cette feature qui apporte de la valeur CETTE SEMAINE ?"

This is the anti-scope-creep question. Rules:
- The minimal version must be SHIPPABLE (not a stub, not a placeholder)
- It must solve the core problem from Q1, even partially
- Everything else goes in "nice-to-have" (not in the plan)
- Apply YAGNI ruthlessly: remove unnecessary features from the design

### Q8 — COMMENT TESTER ?
"Quel scenario prouve que ca marche ?"
- Golden couple: Julien (swiss_native, 49, 122'207, VS, CPE) + Lauren (expat_us, 43, 67'000, VS, HOTELA)
- Which facets? (retraite, logement, fiscalite, couple, archetype)
- Edge cases: que se passe-t-il avec 0 CHF ? avec 1M CHF ? avec un frontalier ?
- Anti-facade check: "Qui CONSOMME cet output ? Quel ecran l'affiche ? Quelles donnees circulent ?"

## Phase PREMISE CHALLENGE (after Q8, before design doc)

Before writing the design doc, challenge the premises:
1. Re-read the answers to Q1-Q8
2. Ask yourself: "What assumption am I making that might be wrong?"
3. Challenge at least 1 premise explicitly to the user:
   "Tu assumes que [X]. Est-ce vraiment le cas ? Qu'est-ce qui se passe si [X] est faux ?"

Examples:
- "Tu assumes que les utilisateurs connaissent leur avoir LPP. Et si 80% ne le connaissent pas ?"
- "Tu assumes que le scan OCR fonctionne pour tous les certificats. Et si les caisses ont des formats differents ?"

## Produce the design doc

Write a structured summary (NOT a file — just in the conversation):

```
## Design: [Feature Name]

**Pourquoi**: [1 phrase concrete, pas vague]
**Status quo**: [ce que les users font aujourd'hui]
**Pour qui**: [life events] × [archetypes]
**Approche choisie**: [Option X parce que...]
**Version minimale**: [la plus petite version shippable]
**Nice-to-have** (PAS dans le plan): [tout le reste]
**Compliance**: [risques identifies et mitigations]
**Archetypes impactes**: [liste avec notes]
**Premise challengee**: [l'hypothese testee et la conclusion]
**Test plan**: [scenarios golden couple + edge cases]
**Anti-facade**: [qui consomme → quel ecran → quelles donnees]

**Estimation**: [S/M/L] — [nombre de fichiers touches]
**Prerequis**: [dependencies]
```

## Spec self-review (before presenting to user)

Before presenting the design doc, run these 4 checks:
1. **Placeholder scan**: any "TBD", "TODO", "a definir", "[...]" in the doc? → fill them or remove
2. **Internal consistency**: does the test plan match the version minimale? (not the nice-to-have)
3. **Scope check**: is the version minimale really MINIMAL? Can it be smaller?
4. **Ambiguity check**: would 2 different engineers interpret this doc the same way?

If any check fails → fix the doc before presenting.

## USER APPROVAL GATE

Present the design doc and ask:
"Est-ce qu'on part la-dessus ? Si oui, ouvre un chat PLAN pour decomposer en tasks."

Do NOT proceed to implementation without explicit "oui" or equivalent.

## What this skill does NOT do

- Write code (use /mint-flutter-dev or /mint-backend-dev)
- Create a plan (use a PLAN chat)
- Review code (use /mint-review-pr)
- Run tests (use /mint-test-suite or /autoresearch-quality)
- Commit (use /mint-commit)

## Anti-rationalization table

| Thought | Reality |
|---------|---------|
| "C'est juste un petit fix" | Small fixes break big systems. 5 minutes of cadrage saves 2 hours of debugging. |
| "Le user m'a dit exactement quoi faire" | The user said WHAT. Cadrage answers WHY, FOR WHOM, and HOW TO TEST. |
| "On a deja discute" | Did you answer all 8 questions? If not, you didn't do cadrage. |
| "Ca va ralentir" | Shipping the wrong thing is slower than 15 minutes of questions. |
| "Le code est trivial" | Trivial code in the wrong place = facade sans cablage. |
| "L'utilisateur est presse" | Use the escape hatch (2 critical questions). Don't skip entirely. |
