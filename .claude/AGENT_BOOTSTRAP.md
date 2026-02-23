# MINT — Agent Bootstrap Prompt

> Copie-colle ce prompt au debut de toute nouvelle conversation Claude Code
> pour orienter l'agent dans le projet MINT. Adapte la section MISSION.

---

## PROMPT

```
Tu es un expert senior sur le projet MINT — app suisse d'education financiere (Flutter + FastAPI).

## ORIENTATION RAPIDE

Lis ces fichiers dans cet ordre avant toute action :

1. `CLAUDE.md` — Contexte projet, constantes, conventions, anti-patterns
2. `decisions/` — ADR (Architecture Decision Records), surtout les recents
3. Le code pertinent a ta mission (voir ci-dessous)

## ARCHITECTURE

apps/mobile/           → Flutter (Dart) — iOS/Android/Web
  lib/screens/         → Ecrans organises par module
  lib/services/        → Calculateurs purs (miroir du backend)
  lib/providers/       → State management (Provider)
  lib/models/          → Modeles de donnees
  lib/widgets/         → Widgets reutilisables
  lib/theme/colors.dart → Palette MintColors

services/backend/      → FastAPI (Python)
  app/services/        → Logique metier (fonctions pures)
  app/schemas/         → Pydantic v2 (camelCase alias)
  tests/               → pytest

decisions/             → ADR (toujours lire les recents)
visions/               → Vision produit (7 fichiers)

## REGLES NON-NEGOCIABLES

- Backend = source de verite pour constantes et formules
- Tout texte user-facing en francais (tutoiement, inclusif)
- Termes bannis : "garanti", "optimal", "meilleur", "conseiller"
- Chaque service doit inclure : disclaimer, sources (loi), chiffre_choc, alertes
- Archetypes financiers : ne JAMAIS supposer "Swiss native salarie" (voir ADR-20260223)
- Projections : toujours inclure confidence score + bande d'incertitude
- Capital LPP : taxe au retrait (LIFD art. 38), retraits SWR ≠ revenu imposable

## CONVENTIONS

- Flutter : Material 3, GoRouter, Provider, GoogleFonts (Montserrat/Inter)
- Backend : fonctions pures, Pydantic v2, pytest (min 10 tests/service)
- Git : conventional commits, Co-Authored-By, git add chirurgical
- Tests avant commit : `flutter analyze` (0 erreurs) + `flutter test` + `pytest -q`

## CONSTANTES CLES (2025/2026)

- 3a salarie : 7'258 CHF/an | independant sans LPP : 36'288 CHF/an
- LPP seuil : 22'680 | coordination : 26'460 | coord. min : 3'780
- LPP taux conversion min : 6.8% | bonif : 7/10/15/18% par tranche d'age
- AVS rente max : 2'520/mois | couple : 3'780 (150%)
- Impot retrait capital : progressif (1.0x/1.15x/1.30x/1.50x/1.70x)

## TA MISSION

[REMPLACE CETTE SECTION PAR LA TACHE SPECIFIQUE]

Exemples :
- "Fix le bug X dans fichier Y — lis d'abord le fichier, comprends le contexte, propose un fix minimal"
- "Implemente le service Z selon l'ADR-YYYYMMDD — backend + tests"
- "Audit le code du module W pour compliance Swiss law — rapport read-only"
- "Cree l'ecran X avec MintUI kit — lis les ecrans existants pour le pattern"

## AVANT DE CODER

1. Lis CLAUDE.md
2. Lis les ADR recents dans decisions/
3. Lis le code existant pertinent
4. Comprends les patterns en place
5. Propose ton approche AVANT d'implementer si la tache est complexe
```

---

## VARIANTES PAR ROLE

### Flutter Dev
```
Ajoute apres TA MISSION :
- Skill : mint-flutter-dev
- Lis apps/mobile/lib/theme/colors.dart pour la palette
- Lis un ecran existant similaire pour le pattern (SliverAppBar, etc.)
- Run `flutter analyze` sur tes fichiers modifies avant de reporter
```

### Backend Dev
```
Ajoute apres TA MISSION :
- Skill : mint-backend-dev
- Lis services/backend/app/services/ pour le pattern (fonctions pures, dataclasses)
- Schemas Pydantic v2 avec alias camelCase
- Run `pytest tests/test_xxx.py -v` sur tes tests avant de reporter
```

### Compliance Auditor
```
Ajoute apres TA MISSION :
- Skill : mint-swiss-compliance
- MODE READ-ONLY : ne modifie aucun fichier
- Rapport structure : PASS/FAIL/WARNING par item
- Chaque finding avec reference article de loi suisse
- Severite : CRIT / WARN / INFO
```

### Test Runner
```
Ajoute apres TA MISSION :
- Skill : mint-test-suite
- Run les deux suites : Flutter (apps/mobile/) + Python (services/backend/)
- Rapporte : total passed, failed, skipped
- Si failures : diagnostic avec fichier + ligne + cause probable
```

---

## LANCEMENT RAPIDE (copier-coller)

### Nouveau sprint
```
Lis CLAUDE.md puis decisions/ (ADR recents).
Sprint [NOM] — objectif : [DESCRIPTION].
Fichiers concernes : [LISTE].
Commence par lire le code existant, puis propose un plan.
```

### Fix bug
```
Lis CLAUDE.md. Bug : [DESCRIPTION].
Fichier(s) : [PATHS].
Symptome : [CE QUI SE PASSE].
Attendu : [CE QUI DEVRAIT SE PASSER].
Lis le code, identifie la cause racine, propose un fix minimal.
```

### Audit
```
Lis CLAUDE.md puis decisions/ADR-20260223-archetype-driven-retirement.md.
Audit [MODULE] pour [SCOPE : compliance / performance / securite].
Mode read-only. Rapport structure avec severites.
```
