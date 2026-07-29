# Phase mint-illogism-fixes — Context

> **Statut : CLOS 2026-07-29** — supersedé par la campagne étalon fiscal (#1060-#1100, recalibrage ESTV). Le résidu VoiceOver est déjà tracké (bead `jx6`). Réconciliation plans 2026-07-29.

**Gathered:** 2026-06-11
**Status:** Ready for planning
**Source:** Express path — input contract = `.planning/reports/MATRIX-illogismes-2026-06-09.md` (44 findings confirmés par agent adverse, 8 archétypes, classes DIVERGENT 27 / ILLOGICAL_FOR_ARCHETYPE 10 / SOURCED 5 / WRONG 2, + annexe device D1-D12). La matrice tient lieu de PRD : chaque ligne porte input → output MINT → attendu → source `file:line` → reproduction (oracle déterministe).

<domain>
## Phase Boundary

Fermer les 5 causes racines des illogismes user-facing de MINT (calculs divergents, hypothèses d'archétype silencieuses, estimations déguisées en faits, erreurs de domaine, surfaces muettes a11y) — **mobile Flutter + onboarding UX uniquement**. Le backend L2-L4 n'est PAS touché (pas de chevauchement avec `mint-data-architecture-v1-02-deploy`). Pas de nouvelle feature au-delà des 2-3 questions d'onboarding nécessaires à la vérité d'archétype.

Milestone parent : Core Journey Truth / Prod Ready (la matrice EST du journey-truth).
</domain>

<decisions>
## Implementation Decisions (locked — dérivées de la matrice + session 2026-06-09/11)

### W1 — Source unique (ferme ~27 DIVERGENT)
- `financial_core` est LA source canonique L1 (CLAUDE.md NEVER #3). Toute quantité financière affichée doit être calculée par UN moteur.
- Supprimer/déléguer les implémentations inline divergentes :
  - Avoir LPP estimé : `coach_profile.dart:3577` (`_estimateLppAvoir` — pas de clamp 64'260, intérêt 1% hardcodé) ET `minimal_profile_service.dart:196` (`_estimateLppBalance`) → délèguent à `LppCalculator` (clamp `lpp.max_coordinated_salary=64260`, intérêt `lpp.min_interest_rate=1.25%`, support `arrivalAge`). Écarts mesurés : +15.4% à +105% selon revenu.
  - Rente LPP mensuelle : `mariage_screen.dart:94` (0.068 hardcodé), `response_card_service.dart:776` (0.058), `financial_summary_screen.dart:127`, `independants_service.dart:599` → tous via `LppCalculator.adjustedConversionRate` (lpp_calculator.dart:43-52, applique aussi la réduction LPP art.13 al.2). Spread mesuré : 250-347 CHF/mois sur le même avoir. Corriger aussi le commentaire périmé `response_card_service.dart:779` (« conservative 5.4% » vs 0.058 réel).
  - Taux de remplacement : UNE définition (dénominateur NET courant — sens économique pour l'utilisateur) partout : `minimal_profile_service.dart:128-130` (brut), `response_card_service.dart:784-790` (net), `budget_living_engine.dart:253-254` (MIXTE incohérent : numérateur net / dénominateur brut — bug dans une seule formule). Écarts mesurés : 10-20 pts.
  - Plafond 3a indépendant : base = revenu professionnel NET (OPP3 art.7 al.2) partout : `tax_calculator.dart:548` + `minimal_profile_service.dart:135-152` utilisent le BRUT (faux, +25%) ; `independants_service.dart:412` (net) est la référence.
  - Économie d'impôt 3a : `minimal_profile_service.dart:136-141` doit passer `isMarried`/`children` (la fonction l'accepte, l'appelant l'omet — surestimation +17.6% pour un marié). `response_card_service.dart:674-678` le fait déjà.
- Gate de parité : test unitaire qui calcule chaque quantité par tous les chemins d'appel restants et assert l'égalité (anti-régression de la classe entière).

### W2 — Vérité d'archétype à l'onboarding (ferme ~10 ILLOGICAL_FOR_ARCHETYPE)
- Ajouter à l'onboarding (`/onb`, OnboardingShellScreen) : statut d'emploi (salarié / indépendant / sans activité) + état civil (le modèle existe : `CoachCivilStatus` incl. `divorce`) + lacunes AVS (années à l'étranger — le champ `q_avs_lacunes_status` existe). Le schéma backend supporte déjà tout (SOT §1 : `employmentStatus`, `selfEmployedNetIncome`, `has2ndPillar`, `spouseIncomeNetMonthly`).
- Gates en aval :
  - Indépendant sans LPP → LPP=0 ENFORCED dans les DEUX moteurs de profil (`minimal_profile_service.dart:67-74` gate sur employmentStatus ; `coach_profile.dart:2786,2853-2859` gate sur q_has_pension_fund — unifier le prédicat). Plafond 3a → 36'288 base nette.
  - Divorcé → INTERDIT d'estimer la LPP par âge×salaire (partage CC art.122 = path-dependent). Fallback : « valeur réelle requise — scanne ton certificat » + confiance dégradée.
  - Frontalier → 3a déductible gated sur statut quasi-résident (le hub `segments_service.dart:494-520` le fait déjà ; le chemin générique `minimal_profile_service.dart:146-153` + `coach_profile.dart:2087-2095` `canContribute3a` ne le font pas).
  - FATCA/expat_us → gate GLOBAL (redirect GoRouter `app.dart:234-317`), pas point-defense sur `/coach/chat` seulement (`coach_chat_screen.dart:1828-1864` est aujourd'hui le seul site) ; `/profile/bilan` + `/mon-argent` actuellement non gatés. `minimal_profile_service.compute()` doit recevoir l'archétype (aujourd'hui aucune branche FATCA → plafond 3a 7'258 émis pour un US person alors que `canContribute3a==false`).
- Tant que statut/état civil inconnus : pas de chiffre archétype-dépendant en vedette — demander ou étiqueter « hypothèse : salarié ».

### W3 — Discipline estimé-vs-connu (SOT §5)
- SOT §5 Confidence Gate APPLIQUÉ : combined <50 → affichage FRI gated ; <70 → bandes d'incertitude obligatoires. Violation device-prouvée : home hero « 43'691 Avoir LPP » nu avec Fiabilité 44% (D2).
- Toute valeur issue d'un estimateur porte le tag « estimé » sur TOUTES les surfaces (Mon Argent>Prévoyance le fait ; /home ne le fait pas).
- Un hero number ne peut JAMAIS venir d'un estimateur — états : connu (certificat/saisie) / estimé (étiqueté, pousse vers le scan) / inconnu (demande).
- Tuer les défauts fiction : `rente_vs_capital_screen.dart:62-66` (age '50', salaire '100000', LPP '350000' ; mode certificat 500000/150000/37000) → état vide explicite ou valeur profil taguée. Les défauts contournent aujourd'hui `ProfileDataSource` (hasEstimates seulement sur prefill réel). Device-prouvé : indépendant sans LPP → « Capital estimé à 65 ans ~812'886 » sur fiction (D5).
- Incohérence de fiabilité inter-surfaces à résoudre : « 44% » (Mon Argent) vs « 50% » (RvC) vs « 30% » (Marc avec vraies données) — A_REPRODUIRE le mécanisme, mais une seule source de confiance par profil.

### W4 — Corrections de domaine
- Split divorce : `life_events_service.dart:114-130` splitte l'avoir TOTAL → ne splitter QUE la part acquise pendant le mariage (CC art.122 / LFLP art.22a) ; demander « avoir au mariage » ; ne PAS pré-remplir avec l'estimation inflatée (`divorce_simulator_screen.dart:86-87`).
- GapFactor AVS : `returning_swiss_gaps` voit la rente MAX 2'520 malgré lacunes (attendu ~1'260 pour arrivalAge=43) — le gapFactor doit refléter les lacunes dans le minimal profile ET la scène onboarding (`MintSceneRenteTrouee`). Pour le jeune (25 ans), gapFactor=1.0 silencieux = carrière parfaite assumée → l'étiqueter comme hypothèse.
- Suggestion 3a (« tu pourrais verser X CHF en 3a ») : plafonner au plafond légal annuel restant (device-prouvé : 1462-1541/mois ≈ 2.4× le plafond 7'258, D10).
- Affordability : deux routes vers le même écran donnent deux revenus de ménage (`affordability_screen.dart:64-67` profil compte les 2 conjoints vs route coach-prefill `:115-121`) — unifier.
- Citation légale fausse « LCC art. 28 » (`services/backend/app/api/v1/endpoints/lucidity.py:46` → FINMA/ASB) — SEULE exception backend autorisée de la phase (one-liner doc).

### W5 — UX/a11y
- ILLOG-02 (P1) : `RenteVsCapitalScreen` arbre AX vide (pixels OK, Semantics absent) — triangulé Maestro+idb+screenshot, reproduit froid+chaud. Fix Semantics ; gate = flow `bug__ILLOG02__rvc_ax_tree_empty.yaml` GREEN.
- Fiction defaults gate = flow `bug__ILLOG01__rvc_fiction_defaults.yaml` GREEN (gated par ILLOG02).
- CTA mort : « Commencer — 2 min » (tableau retraite, état vide) → home coach sans formulaire ni question (D8) ; le tableau ne lit pas le profil que /home lit (D7 : « 43'691 » vs « 4 infos suffisent » même minute).
- Conjoint fictif : `mariage_screen` invente « Revenu 2 : 60'000 » + « Pénalité +1'407/an » pour profil sans état civil (D9) → outil what-if doit étiqueter ses hypothèses éditables.
- Clés brutes en labels a11y : « coach-context-point-de-depart », « ouvrir-profil-drawer » (D11).
- Hardcodé i18n : « Document non disponible » `app.dart:1210`.

### Claude's Discretion
- Découpage en plans/vagues exécutables, taille des PR (petites, 1 cause racine par PR max), choix des widgets pour les questions d'onboarding (suivre MintUI kit + `mint-flutter-dev`), formulation FR des nouveaux strings (via ARB 6 langues, accents, termes bannis).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Contrat d'entrée (le PRD de cette phase)
- `.planning/reports/MATRIX-illogismes-2026-06-09.md` — les 44 findings + annexe device D1-D12 ; chaque ligne = critère d'acceptation avec oracle de reproduction.

### Constitution produit
- `SOT.md` — §1 schéma Profile (les champs existent déjà), §4 ProfileDataSource (estimated=0.25), §5 invariants (Confidence Gate, Source Tracking, Precision Warning).
- `docs/MINT_IDENTITY.md` — moteur 4-couches, toilet test, phrases interdites.
- `CLAUDE.md` — NEVER #3 (pas de calcul dupliqué), #7 (jamais présumer l'archétype), #9 (confiance obligatoire), §9 0-TRUST.

### Code canonique (la cible W1)
- `apps/mobile/lib/services/financial_core/lpp_calculator.dart` — `computeSalaireCoordonne` (:201-205), `adjustedConversionRate` (:43-52), `projectToRetirement`.
- `apps/mobile/lib/services/financial_core/tax_calculator.dart` — `estimate3aTaxImpact` (:535, accepte isMarried), plafonds (:546-549).
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart` — `EnhancedConfidence` 4-axes.
- `apps/mobile/lib/constants/social_insurance.dart` — constantes registry (:63 coordMax, :74/:79 taux conversion, :92 intérêt min, :351/:354/:357 plafonds 3a).

### Sites divergents à éliminer (W1)
- `apps/mobile/lib/models/coach_profile.dart:3577-3591, 2786, 2850-2859, 2087-2095`
- `apps/mobile/lib/services/minimal_profile_service.dart:57-74, 128-152, 196-209`
- `apps/mobile/lib/services/response_card_service.dart:674-678, 776-790`
- `apps/mobile/lib/services/budget_living_engine.dart:253-254`
- `apps/mobile/lib/screens/mariage_screen.dart:94` · `apps/mobile/lib/screens/financial_summary_screen.dart:127` · `apps/mobile/lib/services/independants_service.dart:412, 599`
- `apps/mobile/lib/services/life_events_service.dart:114-130` · `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:62-66, 180-215`

### Gates mécaniques
- `tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` + `bug__ILLOG02__rvc_ax_tree_empty.yaml` (OPEN-RED → doivent passer GREEN) + `_INDEX.md`.
- Oracles de reproduction de la matrice (chaque ligne en cite un — re-runnables).
- Suites : `flutter analyze` + `flutter test` + `accent_lint_fr` + `validate_arb_parity` + `check_banned_terms`.
- Device-proof sim : build via workaround `ln -s /tmp/mint_build_ios apps/mobile/build` (codesign .nosync, engram obs #1595).

### Mémoire engram (compounding)
- obs #1597 (2 estimateurs LPP), #1598 (LPP inestimable en hero), #1601 (violations SOT §5 device), #1603 (taux conversion device-prouvés), #1604 (fiction RvC root-cause), #1605 (ILLOG-02 + flows).
</canonical_refs>

<specifics>
## Specific Ideas
- Ordre des vagues = ordre de levier : W1 → W2 → W3 → W4 → W5. W1 d'abord parce que W2-W4 s'appuient sur des moteurs unifiés.
- Chaque PR ferme des lignes de matrice NOMMÉES (ex. « ferme salarie_swiss-2, independent_no_lpp-4 ») — la matrice est le tracker.
- Petites PR : jamais plus d'une cause racine par PR ; feature→dev squash.
</specifics>

<deferred>
## Deferred Ideas
- Backend L2-L4 (comparer/éclairer/invariants) — hors scope, appartient à mint-data-architecture.
- Coach temporal-gate false-refusal (« cette année » → « Je n'ai pas cette donnée », engram obs #1592) — backend, phase séparée.
- Sanitizer garble (« possible dans ce scénario », compliance_guard.py:171) — backend, phase séparée.
- Frontalier GE/Bâle inversés dans le contenu coach (obs #1594 P1-C) — backend/prompt, phase séparée.
- « Plan suivi » manquant (moteur sans cockpit, obs #1595) — feature produit, décision Julien.
- pgvector/RAG, TestFlight gates (CJT-013/015) — autres chantiers.
</deferred>

---

*Phase: mint-illogism-fixes*
*Context gathered: 2026-06-11 via express path (matrice adversarialement vérifiée en guise de PRD)*
