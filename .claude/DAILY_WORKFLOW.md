# DAILY_WORKFLOW.md -- Routine quotidienne MINT

> Julien arrive devant son ordi. Que fait-il ?

---

## Quick Reference (copie-colle ca)

```
MATIN (5-15 min)
  1. cd /Users/julienbattaglia/Desktop/MINT
  2. git checkout dev && git pull --rebase origin dev
  3. flutter analyze && flutter test              # depuis apps/mobile/
  4. python3 -m pytest tests/ -q                  # depuis services/backend/
  5. Decision : Feature / Bugfix / Qualite ?

FEATURE (2-5h)
  6. git branch --show-current                    # confirmer feature branch
  7. git checkout -b feature/S{XX}-<slug> dev
  8. Chat CADRAGE : pose les 6 questions (voir section detaillee)
  9. Chat PLAN : plan en tasks 2-5 min, review product x eng x compliance
  10. Chat BUILD : colle le plan, code task par task
  11. Toutes les 30 min : flutter analyze && flutter test
  12. Quand fini : /autoresearch-quality 10

APRES-MIDI (1-2h)
  13. Chat REVIEW : "Review ce diff" + /autoresearch-compliance-hardener 10
  14. /mint-commit → PR vers dev
  15. Lance 1-2 boucles autoresearch en fond (/autoresearch-i18n 30, etc.)

SOIR (10 min)
  16. git log --oneline -10 → note ce qui a ete fait
  17. Ecris 3 lignes dans MEMORY.md : etat, blocages, prochaine action
```

---

## Decision tree (choisis ton type de journee)

```
Tests verts ?
├── OUI → Que veux-tu faire ?
│   ├── Feature nouvelle     → Jour intense (CADRAGE → PLAN → BUILD → REVIEW → PR)
│   ├── Corriger un bug      → Jour bugfix (reproduire → BUILD → PR)
│   ├── Ameliorer la qualite → Jour autoresearch (boucles en serie)
│   ├── Preparer une release → Jour release (compliance + privacy + PR staging)
│   └── Pas d'idee           → Lis MEMORY.md "Prochaine action", sinon ROADMAP_V2.md
└── NON → /autoresearch-quality 10, puis recommence
```

---

## Les 5 types de chats

| # | Type | Quand | Duree | Ce que tu fais |
|---|------|-------|-------|----------------|
| 1 | **CADRAGE** | Avant toute feature | 10-15 min | 6 questions : Pourquoi ? Pour qui (quel life event) ? Quelles alternatives ? Quel risque compliance ? Quel impact sur les 8 archetypes ? Comment tester ? |
| 2 | **PLAN** | Apres cadrage | 15-30 min | Decompose en tasks 2-5 min. Chaque task = 1 fichier + 1 action. Ordre : modele → service → test → widget → ecran → i18n. Triple review : product / eng / compliance. |
| 3 | **BUILD** | Feature du jour | 2-5h | Colle le plan. Code task par task. Teste apres chaque task. Si bloque > 10 min, demande a Claude. |
| 4 | **REVIEW** | Feature terminee | 30-45 min | Montre le diff complet. Demande : bugs ? compliance ? regressions ? Puis /autoresearch-compliance-hardener 10. Puis /mint-commit. |
| 5 | **APPRENDRE** | Fin de journee ou fin de sprint | 10-15 min | git log du jour. Qu'est-ce qui a marche ? Qu'est-ce qui a casse ? Mets a jour MEMORY.md. |

---

## Routine detaillee

### 1. Matin : etat des lieux (15 min)

```bash
cd /Users/julienbattaglia/Desktop/MINT
git checkout dev && git pull --rebase origin dev
cd apps/mobile && flutter analyze && flutter test
cd /Users/julienbattaglia/Desktop/MINT/services/backend && python3 -m pytest tests/ -q
```

Si un test est rouge : **ne code rien d'autre**. Lance `/autoresearch-quality 10` pour reparer.

Si tout est vert : decide quoi faire aujourd'hui. Trois options :
- **Feature** → chat CADRAGE puis PLAN puis BUILD
- **Bugfix** → chat BUILD directement (le bug EST le cadrage)
- **Qualite** → lance des boucles autoresearch (voir section Boucles)©

### 2. Chat CADRAGE (10-15 min)

Ouvre un nouveau chat Claude Code. Pose ces 6 questions :

```
Je veux implementer [FEATURE].

1. POURQUOI maintenant ? (quel impact utilisateur ?)
2. POUR QUI ? (quel life event parmi les 18 ? quel archetype ?)
3. QUELLES ALTERNATIVES ai-je ignorees ?
4. QUELS RISQUES compliance ? (banned terms, no-advice, no-promise)
5. QUEL IMPACT sur les 8 archetypes ? (expat_us, cross_border, etc.)
6. COMMENT TESTER ? (golden couple Julien+Lauren ? nouveau scenario ?)
```

Exemples diversifies :
- Housing : "EPL de 50k pour achat a Sion, impact LPP + tax"
- Family : "Naissance d'un enfant, impact budget + allocations + 3a"
- Tax : "Demenagement GE→VD, delta fiscal + impact LaMAL"
- Career : "Passage independant sans LPP, 3a max 36'288"
- Debt : "Dette 40k, safe mode, desactiver optimisations 3a/LPP"
- Sante : "Invalidite partielle 50%, impact rente AI + LPP + budget"
- Patrimoine : "Heritage 200k, optimisation fiscale du retrait echelonne"

### 3. Chat PLAN (15-30 min)

```
Voici le cadrage de ma feature : [colle les reponses].

Genere un plan d'execution :
- Tasks de 2-5 min max chacune
- Chaque task = 1 fichier + 1 action precise
- Ordre : modele → service → test → widget → ecran → i18n
- Indique les skills MINT a utiliser par task
- Triple review : product / engineering / compliance
```

Si le plan depasse 15 tasks, decompose en 2 PRs.

### 4. Chat BUILD (2-5h)

```bash
git checkout -b feature/S{XX}-<slug> dev
```

Verifie ta branche avant de coder :
```bash
git branch --show-current   # JAMAIS main/staging/dev
```

Colle le plan dans un nouveau chat. Code task par task.

**Regles pendant le BUILD :**
- Apres chaque task : `flutter analyze` (0 erreurs)
- Toutes les 3 tasks : `flutter test <fichier_concerne>`
- Toutes les 30 min : `flutter test` (suite complete)
- Calculs → `financial_core/`. Jamais de `_calculate*()` local.
- Strings → ARB files (6 langues). `flutter gen-l10n` apres.
- Couleurs → `MintColors.*`. Jamais `Color(0xFF...)`.
- Navigation → `context.go()` / `context.push()`. Jamais `Navigator.push`.

**Check anti-facade (4 niveaux) apres chaque feature :**
1. **Existe** : le fichier/widget/service est cree
2. **Substantiel** : c'est du vrai code, pas un stub ou placeholder
3. **Cable** : il est importe et appele depuis un ecran ou service reel
4. **Donnees** : de vraies donnees circulent (pas juste des mocks)

**Skills a invoquer pendant le BUILD :**

| Situation | Skill |
|-----------|-------|
| Nouvel ecran Flutter | `/mint-flutter-dev` |
| Nouvel endpoint backend | `/mint-backend-dev` |
| Calcul financier a valider | `/autoresearch-calculator-forge 10` |
| Strings hardcodees | `/autoresearch-i18n 20` |

### 5. Chat REVIEW (30-45 min)

Feature terminee. Nouveau chat :

```
Voici le diff de ma feature :
git diff dev...HEAD

Review ce code pour :
1. Bugs (null safety, edge cases, dispose manquants)
2. Compliance (banned terms, no-advice, disclaimers)
3. Regressions (tests existants casses ?)
4. i18n (strings hardcodees ?)
5. Archetypes (fonctionne pour les 8 ?)
```

Puis verifications mecaniques :

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter analyze && flutter test
```

```
/autoresearch-compliance-hardener 10
```

### 6. Commit et PR

```
/mint-commit
```

Pour la PR :
```bash
gh pr create --base dev --title "feat(scope): description courte" --body "..."
```

### 7. Boucles autonomes en fond

Lance pendant que tu fais autre chose (review, specs, pause) :

| Boucle | Quand | Commande |
|--------|-------|----------|
| Bug hunter | Apres chaque PR | `/autoresearch-quality 20` |
| Tests manquants | 1x/semaine | `/autoresearch-test-coverage` puis `/autoresearch-test-generation 50` |
| Compliance | Avant release | `/autoresearch-compliance-hardener 30` |
| i18n | Apres feature UI | `/autoresearch-i18n 30` |
| UX polish | 1x/semaine | `/autoresearch-ux-polish 20` |
| Coach textes | Quand coach modifie | `/autoresearch-coach-evolution 20` |
| Prompts AI | Quand coach modifie | `/autoresearch-prompt-lab 20` |
| Privacy | Avant release | `/autoresearch-privacy-guard` |
| Calculateurs | Apres modif financial_core | `/autoresearch-calculator-forge 30` |
| Navigation | Apres ajout/suppression route | `/autoresearch-navigation 15` |

Max 2 boucles en parallele. Max 25-30 iterations par boucle (au-dela, le context se degrade — relancer une nouvelle session avec les learnings).

### 8. Fin de journee (10 min)

```bash
git log --oneline -10
git diff --stat dev
```

Ajoute dans MEMORY.md :
```
## ETAT [date]
- Fait : [1-2 lignes]
- Blocages : [si applicable]
- Prochaine action : [1 ligne]
```

---

## Variantes par type de journee

### Jour leger (3-4h) -- review, qualite, specs
```
1. Pull + baseline verte (15 min)
2. /autoresearch-quality 20 (laisser tourner)
3. /autoresearch-test-generation 50 (laisser tourner)
4. Specs/docs/cadrage pendant que ca tourne
5. Review les resultats, commit si amelioration
6. MAJ MEMORY.md
```

### Jour intense (6-8h) -- feature complete
```
1. Pull + baseline verte (15 min)
2. Chat CADRAGE (15 min)
3. Chat PLAN (20 min)
4. Chat BUILD matin (2-3h)
5. Pause
6. Chat BUILD apres-midi (1-2h)
7. Chat REVIEW (30 min)
8. /mint-commit + PR
9. Boucles autoresearch en fond
10. MAJ MEMORY.md
```

### Jour sprint autoresearch (4-5h) -- qualite massive
```
1. Pull + baseline verte (15 min)
2. /autoresearch-test-coverage → identifie les gaps
3. /autoresearch-test-generation 100 → genere les tests
4. /autoresearch-quality 30 → corrige les bugs trouves
5. /autoresearch-compliance-hardener 30 → teste les red lines
6. /autoresearch-i18n 40 → extrait les strings
7. /mint-commit le tout
8. MAJ MEMORY.md avec metriques (tests avant/apres)
```

### Jour bugfix (2-4h)
```
1. Pull + baseline verte (15 min)
2. Reproduis le bug (test qui echoue OU scenario manuel)
3. Debugging structure (4 phases) :
   a) ROOT CAUSE : lis l'erreur, trace le data flow, identifie le fichier
   b) PATTERN : cherche des cas similaires qui fonctionnent, compare
   c) HYPOTHESE : 1 hypothese a la fois, teste-la
   d) FIX : ecris le test qui echoue D'ABORD, puis corrige le code
   Regle des 3 : si 3 fixes echouent → STOP, questionne l'architecture
4. /autoresearch-quality 10 → pas de regression
5. /mint-commit + PR
6. MAJ MEMORY.md
```

---

## Skills : existants vs a creer

### Existants (18 skills operationnels)

**Orchestration :** `/mint-flutter-dev`, `/mint-backend-dev`, `/mint-commit`, `/mint-test-suite`, `/mint-phase-audit`, `/mint-audit-complet`, `/mint-swiss-compliance`

**Boucles autonomes :** `/autoresearch-quality`, `/autoresearch-test-generation`, `/autoresearch-test-coverage`, `/autoresearch-calculator-forge`, `/autoresearch-compliance-hardener`, `/autoresearch-i18n`, `/autoresearch-ux-polish`, `/autoresearch-navigation`, `/autoresearch-privacy-guard`, `/autoresearch-prompt-lab`, `/autoresearch-coach-evolution`

### Nouveaux (crees le 2026-04-05, audites par 3 agents independants)

| Skill | Objectif | Commande |
|-------|----------|----------|
| `/office-hours` | 6 questions de cadrage pre-feature. HARD GATE : pas de code avant approbation. | `/office-hours` |
| `/review-pr` | Staff review d'un diff. 8 passes + compliance hardener. Verdict PASS/WARN/BLOCKED. | `/review-pr` |
| `/retro` | Retrospective quantifiee. Git analysis + hotspots + persistence inter-sprints. | `/retro` ou `/retro 14` |

---

## FAQ

**Je ne sais pas quelle feature faire.**
Lis MEMORY.md → "Prochaine action". Si vide, ouvre ROADMAP_V2.md, cherche le premier item `planned`. Sinon, jour sprint autoresearch.

**Un test est rouge et je ne comprends pas.**
`/autoresearch-quality 10`. Si ca ne suffit pas, chat BUILD avec le message d'erreur complet.

**J'ai code sans cadrage.**
Fais-le maintenant (cadrage retroactif). Si les 6 questions revelent un probleme, refactore avant de PR.

**Quand faire la release ?**
Quand `dev` est stable (tests verts + analyze clean) :
1. `/autoresearch-compliance-hardener 30` + `/autoresearch-privacy-guard`
2. Verifie `LEGAL_RELEASE_CHECK.md` (chaque item coche)
3. PR dev→staging : titre "Staging to vX.Y.Z"
4. Test manuel sur staging (parcours complet : onboarding → chiffre choc → 1 hub → coach)
5. PR staging→main : titre "Production to vX.Y.Z"

**Je travaille sur du backend Python.**
Meme routine. `python3 -m pytest tests/ -q` au lieu de `flutter test`. `/mint-backend-dev` au lieu de `/mint-flutter-dev`.

**La feature touche frontend ET backend.**
Backend d'abord (source of truth), merge dans dev, puis frontend qui consomme. Deux branches separees.
