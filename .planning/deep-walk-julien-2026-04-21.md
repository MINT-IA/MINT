# Deep walkthrough — Julien-persona, 2026-04-21

**Persona:** Julien, 34 ans, Lausanne, célibataire 1 enfant, 7500 CHF brut, loyer 1800, LAMal 340, certif LPP 143k qui traîne. Mercredi 21h, fatigué. Méfiant des apps bancaires.

**Méthode.** Visuel + data + émotionnel + gap par écran. Pas de « ça marche tap fait le job » — vraiment ressentir en tant que Julien.

---

## Catalogue brut — 15 cracks identifiés en 8 écrans

| # | Gravité | Écran | Crack | Root cause |
|---|---|---|---|---|
| 1 | 🟠 P1 | Opener | Chips sont `StaticText` en AX, pas `Button` | `_OpenerChip` `InkWell` sans `Semantics(button: true)` |
| 2 | 🔴 P0 | Scanner | "Certificat de prevoyance LPP" accent | ARB key `scanDocTypeLpp` |
| 3 | 🔴 P0 | Scanner | "Declaration fiscale" accent | ARB key |
| 4 | 🟠 P1 | Scanner | Pas de type "Certificat de salaire" malgré `DocumentType.salaryCertificate` | Missing from UI enum list |
| 5 | 🔴 P0 | Scanner verify | "Salaire assure" / "deces" / "invalidite" / "projetee" / "employe" | Labels extraction backend ou i18n |
| 6 | 🟡 P2 | Scanner verify | "Ouvert depuis un lien direct" hors-contexte | Message conditionnel mal écrit |
| 7 | 🟡 P2 | Impact | QR-grid icon sans label | Accessibility |
| 8 | 🔴🔴 P0 | After impact | « On regarde ce que ça change » → renvoie à opener coach (rupture trust) | `hasSeenPremierEclairage` flag pas set après scan |
| 9 | 🔴 P0 | Aujourd'hui | Layout overflow "RIGHT OVERFLOWED BY 27 PIXELS" sur Cap du jour | Text overflow dans pastille Cap du jour |
| 10 | 🔴 P0 | Aujourd'hui | "annees effectives" accent | ARB key |
| 11 | 🟠 P1 | Aujourd'hui | "Commence par parler au coach" section séparée redondante avec Cap du jour | Empty state widget mal composé |
| 12 | 🟠 P1 | Mon argent | "💡 Scanne un certificat LPP ou 3a" après scan LPP = hint obsolète | Whisper pas contextuel au scan history |
| 13 | 🟡 P2 | Budget setup | Pas d'exemple / placeholder guide | Optional improvement |
| 14 | 🟡 P2 | Budget setup | Pas de total live pendant saisie | Optional |
| 15 | 🔴🔴 P0 | Mon argent post-flow | Card Patrimoine VIDE alors que scan LPP confirmé (card Budget OK) | Asymétrie `BudgetProvider.refreshFromProfile` vs `PatrimoineAggregator` cache |

---

## Priorité fix P0 (MVP blocker — 3 items)

1. **#8 Rupture de confiance opener** — après scan complet, retour chat = opener. User traité comme nouveau venu. Fix : `ReportPersistenceService.markPremierEclairageSeen()` doit être appelé après scan confirm (extraction_review) + budget save + premier message chat.

2. **#15 Asymétrie post-save cards** — card Budget refresh, card Patrimoine pas. Fix : après scan, forcer `context.read<CoachProfileProvider>().notifyListeners()` OU que PatrimoineSummaryCard écoute `profile` via `watch`.

3. **#9 Layout overflow Aujourd'hui** — 27px right overflow visible sur Cap du jour. Fix : wrap Text in Expanded / Flexible.

## Priorité fix P1 (UX degradation — 5 items)

- **#1 Chips opener AX role** — wrap chips in `Semantics(button: true, label: ...)`.
- **#2 #3 #5 #10 Accents** — regex sweep sur ARB fr + fr backend extraction labels.
- **#4 Salary cert doc type** — add to Scanner UI enum.
- **#11 Redundant « Tes premières tensions »** — conditional rendering sur profile.isLoaded.
- **#12 Whisper Mon argent contextuel** — lire `profile.dataSources` pour savoir quelles sources captées.

## Priorité fix P2 (polish post-MVP — 3 items)

- **#6 #7 #13 #14** — delight, not MVP blocker.

---

## Positifs (trust-building working)

- ✅ Landing minimaliste, LSFin dès le landing
- ✅ Opener « Je ne vends rien, je ne note rien, je ne te compare à personne » = trust win
- ✅ Scanner Confirmer + « Confiance 42% → 71% » = WOW moment effectif
- ✅ Disclaimer post-scan + refs LPP / OPP2 = pro
- ✅ Budget form structured 2 champs requis = rapide
- ✅ Mon argent whisper « Tu pourrais verser 680 CHF en 3a » = actionable
- ✅ Revenus / Dépenses / Reste calcul correct post-budget

---

## Next: fix P0 en série sur feat/budget_setup_form branch puis walk re-test
