---
description: "Plan PM « MINT utilisable » v2.1, validé panels 3 lentilles + Codex (v1 notée 6,5/10, v2 notée 8,5/10, v2.1 intègre les 6 corrections restantes). Tranche verticale firstJob comme north star, grille de revue écran 12 dimensions, tiers de couverture A/B/C. Le train de fusion Phase 0a a été exécuté (42 PR fusionnées, dev jamais rouge)."
---

# Plan « MINT utilisable » — v2.1 (post-panel 3 lentilles + 2 passes Codex)

v1 notée 4× 6,5/10 (produit, release/QA, métier/compliance, Codex). v2 notée
8,5/10 par Codex ; v2.1 intègre ses 6 derniers points. Structure : tranche
verticale d'abord, preuves de valeur avant cartographie, Journey OS registre
unique. Le dernier point vers 10 n'est pas documentaire : c'est la preuve
TestFlight physique exécutée (G2).

## North star (critère mesurable, anti-théâtre)

Sur un install NEUF pointé staging : un utilisateur suit le parcours
**firstJob** (seul parcours complet du repo, aujourd'hui gated OFF) et atteint
un chiffre calibré étalon ESTV en ≤ N taps / ≤ T secondes (baseline mesurée au
premier walkthrough, puis figée) ; ce chiffre est IDENTIQUE dashboard ↔ coach
pour le même `inputs_hash` (tolérance d'arrondi déclarée) ; la réponse coach
porte une correspondance claim→toolCall→output (pas seulement « une trace
existe ») ; zéro cul-de-sac ni état vide non géré sur le chemin.
**Anti-critère** (régression 2026-05-07) : staging coupé → dégradation propre
(L1 offline + message), jamais un écran vide.
Preuve : flow Maestro CORE vert + `idb describe-all` final + G2 Julien device.

## Phase 0a — Assainir, périmètre VRAI (2-4 jours)

Fait vérifié : **88 PR ouvertes (47 drafts)**, pas 40. Le train #1100 n'en
couvre que 37 (V1 = 12 fusionnées le 2026-07-29, vérifié MERGED ×12).

- **G-scope** : disposition ÉCRITE pour chacune des ~76 PR restantes
  {campagne / fermer / récupérer / différer} — audit de réconciliation en
  cours (plans .planning + PR orphelines #928-#949 : une vieille PR peut
  RÉANIMER du code drainé par la campagne — flag explicite). Gel de dev sur
  la campagne pendant le train.
- **G-baseline** : snapshot des contextes de statut REQUIS de dev
  (`gh api …/branches/dev/protection`) — « vert » = tous les contextes
  requis `success`, jamais « absence de rouge » (défuse le faux-vert
  path-filter, cf. PR #439).
- **Train de fusion state-of-the-art** (mandat Julien 2026-07-29) :
  1. Un seul PR sur dev à la fois (culprit non ambigu).
  2. Rebase → push → attendre CI complète sur le NOUVEAU sha (le vert
     pré-rebase est nul) → chaque contexte requis `success` ; PR
     path-filtrée → lint concerné exécuté en local.
  3. Squash-merge → suppression de branche → CI dev verte avant le suivant.
  4. **Revert-first** : dev rouge → revert immédiat du squash, diagnostic
     hors-bande ; circuit-breaker : >1 revert dans une vague → halte.
  5. Checkpoints sémantiques : post-V3 élagage baseline #1084 (cliquet) ;
     post-#1088 rétrécissement allowlist ; post-#1099 re-parité #1097 +
     refresh fixture oracle (175k/350k devenus nœuds).
  6. **Matrice N±1 par vague** (réintégrée — régression v2 signalée par
     Codex) : à la fin de CHAQUE vague, en plus de la CI sérielle — jeu de
     tests baseline sur le cumul de dev, ET rejeu Journey OS core avec
     l'app mobile N contre le backend de la vague (N) puis contre le
     backend pré-vague (N−1) ; migrations alembic up ET down exécutées
     avec données ; rollback de vague répété une fois pour prouver qu'il
     marche. Les interactions cumulatives ne se voient pas PR par PR.
- **P0 sécurité Apple takeover (`/auth/apple/verify`)** : instruit ICI
  (ship-blocker), après lecture du log de vérification de l'audit.
- Compat schéma intercalée AVANT tout sweep : deploy backend staging →
  migrations alembic vérifiées → regen/diff OpenAPI canonique → REBUILD
  mobile contre le nouveau schéma → sweep. Verdict nullable toléré sans
  chiffre nu.
- Sortie : dev vert, campagne fusionnée, toutes les PR restantes avec
  disposition écrite, branches fusionnées supprimées, worktrees purgés.

## Phase 1' — Spec de la tranche verticale (2-3 jours, PAS de re-cartographie)

- Réutiliser l'audit existant : `ROUTE-MAP.md` (21 % routes câblées, 17
  îles, onboarding fracturé ~10 variantes), `JOURNEY-TRUTH-MATRIX.md`,
  TOP-20 — ne re-vérifier que les surfaces touchées par les fusions.
  **Journey OS = registre unique** (records/issues/preuves) ; beads = des
  pointeurs vers les IDs JOS, pas un second backlog.
- **Décisions produit à trancher ici** (panel produit) : L'onboarding
  canonique (les variantes îles supprimées/redirigées) ; activation du gate
  firstJob (OFF aujourd'hui).
- Écrire le flow Maestro firstJob CIBLE = test d'acceptation AVANT de coder.
- **Spécifier ET câbler le `MoneyTruthReceipt`** (Codex) : claimId, inputs
  normalisés, juridiction/date fiscale, base (brut/net), état civil,
  hypothèses, moteur+version, règle d'arrondi, sources, valeur/plage.
  « Même chiffre » = mêmes inputs + même définition + même moteur ⇒ même
  résultat après arrondi (un snapshot mensuel et une projection annuelle
  ont le DROIT de différer). Pas seulement une spec : le receipt est
  PERSISTÉ et PROPAGÉ — même `receipt_id`/`inputs_hash` vérifiables
  dashboard ↔ coach ↔ logs backend, assertion de bout en bout dans la
  suite golden.
- **Seuils go/no-go chiffrés AVANT la baseline** (sinon on fige une
  mauvaise performance) : ≤ 12 taps · ≤ 90 s jusqu'au premier chiffre ·
  p95 réponse coach < 2,5 s hors LLM / < 10 s avec · divergence
  claims↔outputs = 0 · crash-free du parcours > 99,5 % sur le sweep.
  La baseline mesurée ne peut que RESSERRER ces seuils, jamais les
  relâcher sans décision écrite.
- Matrice **archétype × life event** : firstJob×swiss_native (tranche) +
  au moins frontalier, independent_no_lpp, expat_us exercés une fois —
  l'éligibilité non supportée produit « données manquantes : X » nommé,
  jamais un cul-de-sac muet.
- Sortie : SPEC de tranche + flow Maestro cible + receipt spec + décisions
  onboarding/gate actées (Journey OS).

## Phase 2' — Construire la tranche firstJob (1-2 semaines)

- firstJob end-to-end : activation du gate, onboarding canonique → dashboard
  chiffré → complétion → coach. Y compris état-vide, erreur-réseau, install
  neuf avec Keychain résiduel (piège anon quota connu).
- Un périmètre à la fois, 5 gates, design panel avant push d'écran,
  Codex/adversarial sur chaque diff.
- **Fixture de parité income mobile↔backend** (manquante aujourd'hui — la
  parité n'existe que pour capital/RvC) : 8 nœuds étalon × cantons
  échantillon × 2 états civils, tolérance déclarée. Bloquant pour la suite.
- **Drainer les 6 tables grandfathered restantes** vers l'étalon (Gap
  métier n°1) — `coaching_engine::CANTON_MARGINAL_TAX_RATES` d'abord (émet
  des CHF nus sur `/coaching/tips` monté), puis rachat_echelonne, first_job
  onboarding, divorce, minimal_profile, church_tax — allowlist rétrécie à
  chaque PR.
- Tests : Patrol = invariants hermétiques par PR **après l'avoir câblé**
  (aujourd'hui non branché en CI — le câblage est un livrable, pas un
  acquis) ; Maestro = smoke e2e boîte-noire pré-ship. Walker : détecteur
  PNG-dupliqué sha256 = échec dur ; tiering CORE (signal) vs QUARANTAINE
  (S001/S003/S004, informatif) ; version Maestro pinnée.
- Sortie : north star atteint sur sim (preuves citées), G2 device Julien.

## Phase 3' — Coach conforme (3-5 jours)

- **Vérité d'abord** : citer la valeur de `COACH_CITATION_GATE_ENABLED` sur
  Railway staging (défaut False — si OFF, l'activer dans sa propre PR +
  rejouer les fixtures byte-identity).
- Observabilité : la trace interne est strippée avant l'app → assertion
  CÔTÉ SERVEUR (harnais pytest rejouant N couples profil×question sur
  staging, capture du tour brut + breadcrumbs `coach.*_gate.fired`).
- Critère mécanique 8 points (panel métier) : zéro chiffre nu
  (regex `\d` ∩ trace, mapping claim→toolCallId→output field, un seul
  retry puis fallback déterministe SANS nombre) · citations monde clos
  résolues · verb gate · termes bannis · parité écran (receipt) · source+
  millésime estampillés · fraîcheur/temporel · projections en Bas/Moyen/
  Haut + confidence.
- Contenu statique : INVENTAIRE EXHAUSTIF des chiffres statiques
  user-facing (scan mécanique `\d` sur `education_inserts/*.md` + clés ARB
  chiffrées + fallback_templates dart), chacun tracé à l'étalon ou marqué
  d'une source datée, et un GATE MÉCANIQUE BLOQUANT qui refuse tout
  nouveau chiffre statique non sourcé (même patron que le lint
  prescriptions : baseline-cliquet).
- Sortie : suite golden coach (4 archétypes minimum) verte sur staging.

## Phase 3.5 — Surface de conformité AFFICHÉE (3-5 jours)

Chiffre tracé ≠ chiffre conforme. Tout nombre user-facing porte : source +
millésime visibles, `EnhancedConfidence` + bande d'incertitude rendus
(l'infra existe, à câbler), disclaimer LSFin, projections en scénarios —
jamais un point-promesse. Sortie : gate « pas de chiffre nu affiché ».

## Phase 4' — Ship TestFlight contre sa VRAIE cible (2-3 jours)

- Les builds release épinglent PROD d'abord (`api_service.dart` — fait
  vérifié) : avant G2 → smoke prod read-only, compat schéma prod,
  inventaire des flags prod, **assertion du `baseUrl` effectivement
  résolu dans le binaire**, `STAGING_API_URL` vérifiée si build staging.
- pubspec bump (déclencheur mécanique du path-filter testflight.yml),
  dev→staging = MERGE (pas squash). Entitlements isolés en PR dédiée.
- Kill switch par nouvelle voie + métriques (échec par parcours, taux de
  re-prompt coach, divergence claims↔outputs, p95, coût LLM) + rollback
  testé.
- Sortie : build TestFlight validé G2 par Julien sur device.

## Grille écran-par-écran 6D (mandat Julien 2026-07-29 — gate par écran)

« Tests verts ≠ écran juste. » Chaque écran passe une revue 6 dimensions
avec preuve par dimension, consignée Journey OS ; Codex passe sur chaque
CLUSTER d'écrans (écran + widgets + services nourriciers) :
1. **Route** — atteignable, back-nav, pas d'île, pas de dead-onTap.
2. **Calculs** — chaque chiffre tracé (étalon/financial_core/receipt),
   zéro littéral numérique user-facing, parité coach↔écran.
3. **Texte** — i18n 6 langues, accents, LSFin, zéro prescription.
4. **Logique** — états vide/chargement/erreur-réseau, gating archétype
   (« données manquantes : X » nommé, jamais de cul-de-sac muet).
5. **Doublons** — variantes d'écrans résolues vers un canonique, widgets
   morts retirés, façades démasquées.
6. **Métier & lois** — articles cités justes (CC/LPP/LIFD/LAVS),
   disclaimers, scénarios Bas/Moyen/Haut.
7. **Accessibilité** — VoiceOver/semantics labels, tailles dynamiques,
   contrastes, cibles tactiles : l'app est pour les 18-99 ans, un
   utilisateur de 75 ans malvoyant doit pouvoir s'en servir (bead jx6).
8. **Performance** — budget par écran : rendu sans jank, cold start,
   latence des calculs ; le « toilet test 20 s » de MINT_IDENTITY est un
   BUDGET, pas une métaphore.
9. **Design system** — tokens MintColors exclusifs, typo/espacements
   cohérents, dark mode, états visuels ; la cohérence visuelle EST un
   signal de confiance pour une app financière.
10. **Lucidité** — la dimension signature : l'écran fait-il PROGRESSER la
   compréhension ? confidence + bande d'incertitude rendues, « pourquoi ce
   chiffre » accessible, enrichmentPrompts, divulgation progressive —
   jamais un chiffre qui impressionne sans expliquer.
11. **Temps & fraîcheur** — l'app vit avec l'utilisateur : millésimes
   affichés, données périmées SIGNALÉES (pas silencieuses), refresh
   annuel des constantes câblé, transitions de vie (âge, mariage,
   canton) reflétées sans état fantôme.
12. **Privacy** — nLPD par écran : données sensibles masquables,
   télémétrie sans PII, rien de financier dans les logs/breadcrumbs.
Un écran n'est « fait » que 12/12 avec preuves. Registre maître en
construction (inventaire statique lancé le 2026-07-29) ; la tranche
firstJob passe en premier, le reste par tranches. Les dimensions 7-12
ont chacune un outil d'attaque : semantics scanner + VoiceOver humain
(7), DevTools timeline + budgets (8), lints prefer-mint-* durcis (9),
revue produit par écran (10), gate fraîcheur étendu aux surfaces (11),
scan Sentry/logs (12).

## Tiers de couverture (gates explicites, pas des intentions)

- **Tier A** = la tranche firstJob complète (north star) — gate de RELEASE :
  rien ne ship sans Tier A vert.
- **Tier B** = smoke sans cul-de-sac sur les 18 life events × l'onboarding
  canonique — gate de NON-RÉGRESSION, exécuté à chaque vague de ship
  (Maestro CORE), pas « une fois ».
- **Tier C** = profondeur chiffrée (receipt + parité + oracle) sur les
  events ACTIFS — gate PAR PR touchant une surface fiscale.
- **Personas** : la matrice archétype × event n'est pas « exercée une
  fois » : frontalier, independent_no_lpp, expat_us entrent dans Tier B
  (smoke) et le premier archétype non-swiss_native entre dans Tier A dès
  la 2e tranche.

## Boucle suivante

firstJob livré (Tier A) → Tier B verrouillé → tranche suivante par valeur
(données audit), même machinerie.

## Transversal

1 unité = 1 branche = 1 PR supprimée à la fusion · rapport HTML par phase ·
0-trust intégral (contre-vérification des agents, sondes avant croyance) ·
Codex borné 330 s sur chaque livrable · mermaid tenus par PR (cartes de la
tranche, pas de cartographie totale) · Journey OS seul registre.

## Risques assumés

Device physique = Julien seul (G2) · non-monotonie marginale VS + zone
sous-15k = documentées, unités séparées · 47 drafts = disposition en Phase
0a (réconciliation en cours) · Patrol non câblé tant que son câblage n'est
pas livré.
