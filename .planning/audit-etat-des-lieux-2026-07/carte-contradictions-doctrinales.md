---
description: Carte des couches doctrinales contradictoires du repo (2026-08-03) — 7 contradictions neutralisées (bandeau ROADMAP_V2, étalon ESTV dans swiss-brain, routeur ACTIVE_CONTEXT, phases mortes AGENTS/backend), 8 observations sans action ; source unique = ADR doctrine-reconstruction 2026-08-03.
---

# Carte des contradictions doctrinales — 2026-08-03

Constat de départ (Julien) : des documents contradictoires ont biaisé les
agents « encore et encore ». Cette carte inventorie la surface doctrinale du
repo, liste les prescriptions qui contredisent la doctrine canonique
(`.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md`, PR #1173 —
fil rouge 6 étapes, anti-dérive v2, runtime touchable par batch, preuves CI
liées au SHA, zéro-confiance symétrique) ou l'état réel du code, et documente
la neutralisation appliquée.

Méthode : chaque claim de doc vérifié contre dev actuel (règle anti-dérive 9 —
« inventorie contre dev, jamais contre un souvenir »). Citations `path:line`
ou sortie de commande pour chaque contradiction retenue.

## Contradictions neutralisées (les plus graves en premier)

| # | Document | Prescription périmée | Preuve de péremption | Ce qui la remplace | Action appliquée |
|---|---|---|---|---|---|
| C1 | `docs/ROADMAP_V2.md` | Phases 1-4 « SHIPPED » (Voice AI, Expert tier, agent autonome, B2B, APIs institutionnelles) ; exécution par « autoresearch nightly agents » ; monétisation Free/Plus/Pro ; « 0 GoogleFonts in lib/ » | Claims sans citation (violation 0-trust CLAUDE.md §9) ; GoogleFonts présent (`apps/mobile/lib/app.dart`, `lib/theme/mint_text_styles.dart` — grep 2026-08-03) ; BYOK hors périmètre ; les sprints S51-S75 ne routent plus rien | ADR doctrine 2026-08-03 (workflow batch A→I) + ADR north-star 2026-07-31 (D1-D5) + `.planning/journeys/` | **Bandeau SUPERSEDED** en tête |
| C2 | `docs/AGENTS/swiss-brain.md` §3 | « Capital withdrawal tax (progressive) : 0-100k ×1.00 \| … \| 1M+ ×1.70 » présentée comme LE modèle | Mobile délègue à `estimateCapitalWithdrawalTaxV2` (130 points ESTV) — `apps/mobile/lib/services/financial_core/tax_calculator.dart:276-287` : « l'ancien taux de base x multiplicateurs approximait à ±40 % sur certains cantons » ; backend canonique `app/services/fiscal/cantonal_comparator.py::estimate_capital_withdrawal_tax` (IFD art. 38 exact + interpolation ESTV) | Étalon fiscal ESTV, une seule source de taux (doctrine « Ce qui est déjà prouvé » ; lint anti-nouvelle-table PR #1062) | **Amendé** : §3 pointe l'étalon ESTV, table multiplicateurs marquée interdite à recomposer |
| C3 | `.planning/ACTIVE_CONTEXT.md` | « Active milestone: mint-2-0-first-experience-rente-capital » sans mention de sa péremption + 17 « temporary branches » de juin 2026 présentées comme autorisations vivantes | `.planning/STATE.md:5` : `status: historical-receipt-superseded-by-journey-os` ; branches jos001→jos005 fusionnées/clôturées depuis fin juin. rules.md donne autorité à ACTIVE_CONTEXT → le routeur contredisait sa propre source aval | `.planning/journeys/` (TODAY/BOARD) comme routeur quotidien ; patterns `codex/jos*` / `codex/journey-os-*` du manifest comme autorisations vivantes | **Amendé** : milestone annoté « receipt historique », liste de branches repliée en note historique (manifest JSON intact — Promotion Rule non exécutée ici) |
| C4 | `AGENTS.md` §drift-catchers + règle vibe 7 | « Until v2.8 Phases 33/34/35 land… », « Phase 33 mechanizes this — until shipped » | Numérotation du roadmap 2026-03 abandonné ; lefthook (ex-« Phase 34 ») existe (`lefthook.yml`) ; aucun plan v2.8 actif | Doctrine anti-dérive v2 : règle 5 (flag + kill switch), règle 6 (preuves CI liées au SHA ; lefthook = filtre local qui ne promeut rien) | **Amendé** : section réécrite sur ce qui est vivant, refs doctrine |
| C5 | `docs/AGENTS/backend.md` §1, §9, §10, §12 | `rules_engine.py # ALL financial calculations` ; « Phase 30.6 (cette phase) exposera » ; « pre-Phase 31 / Phase 34 / Phase 36 » ; « Active Chantiers » | `app/services/fiscal/` est canonique pour l'impôt (section finale du même doc, 2026-07) — contradiction interne ; `get_swiss_constants` MCP existe (CLAUDE.md §3) ; phases 31/34/36 mortes ; chantiers §12 non présents au board | Étalon ESTV + Journey OS board | **Amendé** : arbre §1 corrigé (fiscal/ ★), §9 au présent, §10 sans numérotation morte, §12 marqué historique |
| C6 | `docs/AGENTS/flutter.md` §11 | Référence `docs/UX_WIDGET_REDESIGN_MASTERPLAN.md` | Fichier inexistant (`ls` 2026-08-03 : No such file) | — (référence morte) | **Supprimé** la ligne |
| C7 | `CLAUDE.md` §6 QUICK LINKS | Liens sans hiérarchie vers `docs/ROADMAP_V2.md` (périmé) ; aucun pointeur vers la doctrine canonique, la North Star ni Journey OS | La doctrine du 2026-08-03 se déclare « LA référence à citer » ; ROADMAP_V2 bannérisé (C1) | ADR doctrine + ADR north-star + `.planning/journeys/` en tête de liste | **Amendé** (1 seule ligne — diff listé intégralement dans la PR) |

## Observations sans action (consignées, pas de diff)

| Document | Constat | Pourquoi pas d'action |
|---|---|---|
| `SOT.md` | En-tête « LAST SYNCED 2026-06-13 \| Production: v0.1.0 » (version app réelle : 2.13.0). Contrats vérifiés exacts par grep : `SessionReport` (`apps/mobile/lib/models/session.dart`, `services/backend/app/schemas/session.py`), `enableMvpWedgeOnboarding` (`app/api/v1/endpoints/config.py`) existent | Contenu contractuel encore juste ; re-sync = tâche dédiée, pas une contradiction doctrinale |
| `docs/MINT_IDENTITY.md` | Fond aligné North Star, mais texte massivement sans accents (« interet », « eclaire », « Reduire la honte ») — violation règle critique n°2 | Correction = diff mécanique large, PR dédiée ; aucun biais doctrinal de fond |
| `docs/VOICE_SYSTEM.md` / `docs/DESIGN_SYSTEM.md` | Bandeaux legacy auto-référentiels (« premier éclairage » → « premier éclairage » — trace d'un remplacement mécanique) ; sinon gouvernance claire (« le code fait foi pour l'état actuel ») | Vivants et cohérents avec North Star (un chiffre dominant, air, chaleur) |
| `rules.md`, `docs/MINT_AGENT_WORKFLOW.md` | Cohérents avec la doctrine (autorité, Journey OS, preuves runtime) | Rien à neutraliser |
| `.claude/skills/mint-*` | Miroirs minces conformes (« .agents wins ») | Rien à neutraliser |
| `PERIMETERS.md` (archivé 2026-07-29, sorti de l'arbre le 2026-08-15) | Déjà bannérisé « SUPERSEDED par Journey OS » | Déjà neutralisé |
| CLAUDE.md §4 | Convention `feature/S{XX}-<slug>` vs pratique réelle `codex/journey-os-*` | Les deux coexistent via `allowed_branch_patterns` du manifest ; harmonisation = décision de workflow, pas une neutralisation |
| Worktree `/Users/julienbattaglia/Desktop/MINT-batch0-foundation.nosync` (lecture seule) | `AGENTS.md` + `docs/MINT_AGENT_WORKFLOW.md` divergent du repo principal : roster étendu (`mint-experience`, `mint-integrations-security`), 6 skills supplémentaires (`mint-journey-design`, `mint-runtime-walkthrough`, `mint-financial-calculation-contract`, `mint-consent-and-provenance`, `mint-experience-critique`, `mint-regulatory-boundary`), guards batch 1-3, handshake renuméroté (double étape 13) ; `CLAUDE.md` identique | Worktree de reconstruction sur sa propre branche — la réconciliation se fera au merge des batches ; y toucher ici créerait un conflit |
| Roster élargi — atterrissage partiel sur dev (PR #1174, 2026-08-03 17:57) | `CLAUDE.md` §3.5 liste désormais 7 agents et `docs/AGENTS/{flutter,backend}.md` citent `mint-experience` / `mint-integrations-security`, mais la table roster d'`AGENTS.md` (5 agents), la « Default route » de CLAUDE.md §3.5 et `docs/MINT_AGENT_WORKFLOW.md` §Default Roster n'ont pas suivi | Incohérence transitoire du train roster en cours (flux batch0) — l'alignement appartient à ce flux ; la corriger ici créerait un conflit avec sa prochaine PR |

## Ce qui fait foi désormais

1. `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` — doctrine
   canonique (fil rouge 6 étapes, anti-dérive v2, workflow batch A→I, runtime
   touchable, preuves CI liées au SHA, zéro-confiance symétrique). Mergée sur
   dev via PR #1173 (commit `2163209b7`) ; statut interne Proposed → Decided
   après critique croisée Codex et lecture de Julien.
2. `.planning/decisions/2026-07-31-north-star-experience.md` — expérience
   cible et chantiers D1-D5.
3. `.planning/journeys/` — board, registre d'issues, evidence map.
4. `rules.md` → `CLAUDE.md` → `AGENTS.md` → `docs/MINT_AGENT_WORKFLOW.md` —
   ordre d'autorité opérationnel inchangé.

Toute session qui rencontre une prescription contredisant ces sources doit la
traiter comme historique, citer les deux chemins et corriger la source
périmée — pas deviner (rules.md, Authority Order).
