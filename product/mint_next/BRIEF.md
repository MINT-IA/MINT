# BRIEF — contexte partagé Claude×Codex pour MINT Next

> Ce fichier est lu par Claude ET Codex au début de chaque session de travail.
> Il dit : la vision, les décisions qui tiennent, l'état courant, le Lego en cours.
> Il est mis à jour à chaque fin de Lego. Source d'autorité en cas de conflit :
> `CLAUDE.md` > ADRs `.planning/decisions/` > ce BRIEF > mémoire de session.

## 1. Vision (décidée 2026-08-10)

MINT est le copilote financier personnel des personnes vivant en Suisse. Il
construit progressivement une représentation fiable de leur vie financière
(le **jumeau financier**), la maintient à jour et la transforme en
explications simples, simulations, arbitrages et actions concrètes.

- Le **jumeau financier** est le cœur : des faits historisés portant valeur,
  propriétaire, source, date, année fiscale, statut confirmé/estimé,
  consentement. Une donnée extraite reste une proposition jusqu'à confirmation.
- Le **coach** est une interface vers cette intelligence, jamais la base de
  données ni le calculateur (ADR 2026-08-06 navigateur-monstrateur).
- Les **calculs** viennent des moteurs déterministes (L1 mobile
  `financial_core`, L2-L4 backend) ; le coach les explique.
- Quatre surfaces cibles : Aujourd'hui · Coach · Ma situation · Explorer.
- Mini-plans (objectif → trajectoire → écart → adaptation) : actés, après le jumeau.

**Règle d'architecture absolue** : aucun écran n'est terminé si les
informations qu'il collecte ne rejoignent pas le jumeau et si ses résultats
ne peuvent pas être retrouvés et réutilisés ailleurs.

Source produit canonique : ADR `2026-08-08-lifelong-financial-twin-and-plans.md`
(Decided, Julien + Codex — contrat du fait, cycle de promotion en 7 points,
ordre de construction), ratifiée par l'ADR `2026-08-10` qui ajoute le
protocole de travail.

## 2. Méthode de travail (décidée 2026-08-10)

1. **Storyboard-first** : chaque Lego commence par son storyboard versionné
   (l'histoire utilisateur en beats ; chaque beat mappé à un écran/état/fait/test).
   Le code doit raconter la même histoire ; la vérification herméneutique de
   fin de Lego le contrôle. Le storyboard est le contrat.
2. **Trois moments Codex par Lego** : cadrage avant le code · arbitrage
   mi-course si besoin · review finale du diff. Rôles alternables (l'un code,
   l'autre audite — jamais d'auto-notation). Les sessions de cadrage et de
   review sont bornées et read-only ; seul l'implémenteur désigné du Lego
   écrit du code. **Accès total Codex (acté par Julien 2026-08-11)** : le
   repo entier, la mémoire persistante Claude
   (`~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/`),
   Engram (`~/.engram/engram.db`), CLAUDE.md et ce BRIEF — chaque session
   Codex reçoit ces chemins dans son prompt.
3. **Loops co-décidés** : au lancement d'un loop, question à Codex ; à la fin,
   verdict conjoint + décision commune sur le loop suivant.
4. **Discipline token** : un Lego = valeur visible + faits dans le jumeau,
   budget annoncé au cadrage, pas d'essaims d'agents, une seule ronde de
   review + un audit runtime complet ; les findings corrigés reçoivent une
   revalidation ciblée (le finding, pas le document), sans ronde générale.
5. **0-trust symétrique** : tests ciblés verts ≠ parcours qui marche ;
   citations mécaniques exigées des deux côtés ; aucun hook contourné
   (`--no-verify` interdit).
6. **Rapport herméneutique HTML** : pages par thème, storyboard ↔ code ↔
   preuve, sous `.planning/reports/`, artifact à URL stable.
7. **Qualité d'écran (exigence Julien 2026-08-10)** : chaque écran doit être
   logique dans le parcours, sans doublon de texte ni d'information entre
   écrans, avec un aiguillage clair de l'utilisateur (d'où je viens, où je
   vais, pourquoi). Les règles métier sont vérifiées ensemble (Claude×Codex),
   avec recherche internet sur sources officielles quand le métier l'exige.
8. **Loops** : un seul loop à la fois, court, portant un Lego nommé + budget
   token + critère de sortie. Avant de relancer un loop : question à Codex —
   est-ce le bon moment, est-ce le bon loop ?

## 2bis. Critères d'exigence FinTech mobile (Claude, expert, 2026-08-10)

Barre de qualité propre à une app financière suisse — chaque Lego les
respecte, la vérification herméneutique les contrôle :

1. **Un chiffre = un moteur.** Tout montant affiché est traçable à un moteur
   déterministe (jamais calculé dans un widget), avec une règle d'arrondi
   unique et déclarée (rappen-native ; jamais un excédent positif affiché
   « 0 CHF »). Deux chiffres contradictoires visibles en même temps = défaut
   bloquant.
2. **Quatre états par écran, avant le code.** Chargement / vide / erreur /
   données. L'état vide est honnête (« je ne sais pas encore » + la donnée
   qui débloquerait), jamais un écran mort. Un échec de lecture ne se déguise
   jamais en « aucune donnée » (leçon P1 audit Opus).
3. **Fraîcheur et incertitude visibles.** Toute projection porte ses
   hypothèses, sa fourchette et la date/source de ses données — un chiffre nu
   sans contexte n'est pas livrable.
4. **Réversibilité totale.** Tout fait ou plan écrit est corrigeable et
   supprimable dès sa première version — un écran qui écrit sans offrir
   l'annulation n'est pas terminé. Zéro dark pattern, zéro culpabilisation
   (pas de streak, pas de faux score de complétude).
5. **Accessibilité prouvée.** Cibles tactiles ≥ 44 pt, textScaler 2.0 sans
   overflow en 320×700, parcours lecteur d'écran complet, focus restauré
   après chaque sheet — testé, pas déclaré.
6. **Données sensibles sous contrôle.** Aucun fait financier dans les logs.
   Trois consentements distincts, jamais confondus : la confirmation explicite
   du fait par l'utilisateur vaut consentement de persistance locale ; une
   modification exige une nouvelle confirmation ; la transmission distante
   exige un contrat versionné ET un consentement séparé (inexistants à ce
   jour → faits hors sync cloud). Suppression = suppression réelle.
7. **Sobriété d'attention.** MINT recalcule souvent mais ne parle que
   lorsqu'un événement mérite l'attention — pas de notification quotidienne,
   pas d'urgence artificielle (« occasion, pas alarme »).
8. **Beauté et fidélité design.** Chaque écran est composé depuis l'autorité
   design (`docs/brand/mint-v2/tokens.jsx`, révision approuvée du storyboard),
   passe une revue design avant push, et vise un rendu soigné dont on est
   fier — jamais un formulaire fonctionnel. La beauté est un critère de
   sortie du Lego, pas un vernis final.

**Anti-gaspillage** : ces critères s'appliquent au Lego en cours, pas en
audit permanent de tout le repo. Un token dépensé doit servir l'écran livré.

## 3. Contraintes non négociables

- Termes LSFin bannis (« garanti », « sans risque »…) ; scénarios, jamais de
  recommandations personnalisées ; pas de promesse de rendement.
- Accents FR 100 % ; i18n 6 langues via ARB ; pas de strings en dur.
- MINT ≠ app retraite : 18 événements de vie, cadrage générique.
- L1 = mobile `financial_core` canonique ; L2-L4 = backend canonique ;
  jamais de calcul réimplémenté à travers la frontière.
- Faits du jumeau exclus de toute sync cloud tant qu'aucun contrat de sync
  versionné n'existe.

## 4. État courant (10.08.2026)

- **Design lab** (batches 20-22, attestés @ dc6231946) : écrans commune,
  état civil, revenu, versements 3a — faits encore prisonniers de l'état
  local des écrans. À raccorder au jumeau.
- **Fondation Codex** (`codex/reconcile-mint-next-foundation-20260807`,
  585 commits / ~908 fichiers depuis le 01.08) — le socle MINT Next :
  - **ADR produit Decided** `2026-08-08-lifelong-financial-twin-and-plans.md`
    (Julien + Codex) : contrat du fait, cycle de promotion en 7 points, ordre
    de construction. C'est la « product truth » — l'ADR 2026-08-10 la ratifie.
  - **Phase jumeau COMPLÉTÉE** `mint-next-user-twin-foundation-20260808` :
    cycle logement prouvé en runtime (création, 2 relances à froid, édition,
    suppression durable — Maestro, roast indépendant P1=P2=P3=0). Chemin
    canonique local : transaction coordonnée `CoachProfileProvider.saveHousingFact`
    (drain purge en attente → snapshot → `SecureWizardStore.writeCanonicalHousing`
    = seule autorité → cache `ReportPersistenceService`) →
    `CoachProfile.fromWizardAnswers`. INTERDITS comme sources de vérité :
    Design Lab store, `BiographyRepository`, écritures backend `FactEvent`.
  - **SPEC Golden 3a Vertical** `mint-next-vertical01-3a-20260802`
    (pre_activation, flag OFF) : machine à états fail-closed (35 transitions),
    contrat `FactRecord`/`Plan3aRecord`, contrat de calcul fail-closed,
    persona gelée Lausanne/VD/2026, B0a provenance acceptée, contrats RED
    B1-B4 définis. Sa machinerie d'évidence B0-B5 (chaînes de reçus, double
    reviewers) est en tension avec la discipline token — arbitrage cadrage n°1.
  - **Corpus de contrats** : privacy, anti-PII, rétention/export/suppression,
    cycle de vie des clés, threat model, AIPD, kill switch fail-closed.
  - **Écrans réels** dans apps/mobile : `aujourdhui_screen.dart`,
    `mint_next_housing_screen.dart`, `mint_next_3a_handoff_screen.dart`,
    modèles `mint_next_housing_fact.dart` / `mint_next_3a_tax_boundary.dart`,
    route gates, ARB 6 langues.
  - Commits « save 3a plan to financial twin » + « my situation » +
    « smart 3a account capture » sur `simulator_3a_screen.dart` (audit Opus
    5/10 → P0 corrigé en micro-batch, staged, bloqué `journey_os_check`).
  - Le **storyboard canonique 3a** (commit `94bb94548`) :
  `product/mint_next/storyboard/three_a.storyboard.json` (schéma v3, 9 scènes,
  happy path + 3 branches, oracles, emplacements de preuve herméneutiques) +
  `storyboard.contract.schema.json` + rendu HTML + garde
  `tools/checks/mint_next_storyboard_guard.py`, ainsi que le SPEC de phase
  `.planning/phases/mint-next-vertical01-3a-20260802/SPEC.md` qui contient
  déjà le contrat du jumeau (`FactRecord`, `Plan3aRecord`, navigation
  canonique). Les anciens storyboards (`docs/W17_STORYBOARD.md`,
  `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-*.md`) ne font pas foi.
  Audit Opus 5/10 → P0 (hypothèque ≠ crise de dette) corrigé en micro-batch
  audité, staged, bloqué par `journey_os_check` (régularisation whitelist
  inline dans `tools/checks/journey_os_check.py`, commit dédié, pas de
  `--no-verify`). Capture détaillée 3a : reste désactivée
  (`FF_MINT_NEXT_3A_PRODUCT_HANDOFF=false`) jusqu'au cycle edit/delete +
  vérité des totaux + contrat cloud.
- **Logement** : extension en pause (batch23 gelé, scoping conservé).
- **Backend fiscal** : chaîne mariée + plafonds 3a par affiliation +
  économie d'impôt canonique mergés (#1214).

## 5. Lego en cours

**Cadrage n°1 — EXÉCUTÉ (2026-08-11) : les 3 PR de l'atterrissage sont
mergées sur dev** — PR A #1217 (vérité produit, SPEC amendé sans B0-B5,
storyboard re-pinné, design mint-v2), PR B #1218 (fondation canonique du
jumeau, cycle logement prouvé, 474/474 tests après réconciliation des gates
dev jamais exécutés sur la branche — dont un deadlock inter-zones flutter_test
résolu par le pattern Completer.isCompleted), PR C #1219 (shell 3a minimal,
flag OFF, recâblage ACCEPT Codex zéro finding). Décision d'origine :
1. **Atterrissage reconstruit en 3 PR depuis dev** (jamais un merge des
   585 commits — gardes historiques trop entrelacés) :
   **PR A** vérité produit zéro runtime (ADR 2026-08-08, storyboard + schéma +
   garde autonome, SPEC 3a AMENDÉ sans cérémonie B0-B5, contrats substantiels
   faits/plans/calcul/privacy/anti-PII/clés/rétention/threat-model/AIPD) ·
   **PR B** fondation canonique prouvée (modèle fait logement, chemin
   canonique, « Ma situation », flags OFF, 6 langues, tests + preuve runtime,
   garde générique du cycle des faits) · **PR C** shell 3a minimal (routes et
   écrans `mint_next_*` réellement appelés, flag OFF, contrats de calcul
   fail-closed, gate unique + CI minimal). Règle : aucun workflow n'atterrit
   sans ses gardes/tests/fixtures dans la même PR.
2. **design_lab = laboratoire, jamais writer canonique** ; portage écran par
   écran dans apps/mobile, aucun adaptateur design_lab → jumeau.
3. **Cérémonie B0-B5 abandonnée par Codex** (symétrique). Minimum conservé :
   contrats substantiels + tests déterministes, provenance/version des
   sources officielles, preuve liée au SHA promu, runtime Maestro du parcours
   réel, review indépendante P1=0, gate unique 5 conditions. Reçus acceptés =
   historiques, ni prolongés ni rejoués.
4. **Lego 1 confirmé** : domicile fiscal (voir ci-dessous), implémenteur
   Claude, reviewer Codex, plafond 80k tokens (cible 50-60k), arrêt et
   recadrage avant dépassement. Aucun autre fait dans ce Lego.
Verdict complet : scratchpad session `codex-cadrage1.md`.

**Lego 1 (CONFIRMÉ au cadrage n°1)** : UN seul ensemble cohérent de faits —
le **domicile fiscal** (commune + canton, code BFS) — à travers le cycle
canonique complet en 7 points : sauvegarde par le chemin canonique,
rechargement après relance, visibilité « Ma situation », correction et
suppression, un consommateur réel hors écran de collecte (l'éclairage 3a lit
le fait), invalidation des dépendants à la correction, zéro transmission.
Sortie obligatoire : cycle 7 points + gate unique 5 conditions complets.
Prérequis : PR A et PR B de l'atterrissage (le chemin canonique et la garde
du cycle doivent être sur dev avant d'y câbler un nouveau fait). Les autres
faits (état civil, revenu, versements 3a — le logement étant déjà fait)
suivent **un ensemble par Lego**.

**Lego 2 — LIVRÉ (2026-08-11, PR #1224)** : état civil, premier fait 100 %
scellé (la valeur EST le fait, tombstone dominant l'alias legacy), 6 cartes
sans présélection, consommateur fiscal 3a v3 (imposition commune mariage +
partenariat enregistré vs séparée — 2 parseurs legacy corrigés qui
assimilaient le partenariat au concubinage), writers partagés routés par la
transaction canonique. Gate 5/5, reçu runtime 37c707aec à portée explicite.
Prochains faits candidats (un par Lego, cadrage Codex requis) : revenu,
versements 3a.

## 5bis. Pistes produit (veille, ne sautent pas la file des Legos)

- **Perception vs réalité** (money dysmorphia : 43 % des Gen Z/millennials se
  sentent « en retard » malgré des situations objectivement saines — Credit
  Karma 2024) : candidat d'axe pour un futur éclairage « où j'en suis
  vraiment » — MINT montre l'écart entre ressenti et chiffres, sans jugement.
  S'appuie sur les faits du jumeau, donc après les Legos de faits.
- **Phrase loud-budgeting partageable** (loud budgeting : ~42 % des Gen Z
  assument de dire non pour raisons budgétaires) : une future carte
  « décision » pourrait produire une phrase sobre et partageable
  (« Ce mois-ci, je choisis X plutôt que Y ») — jamais de montant exposé par
  défaut, contrat de données inchangé.

## 6bis. Journal des cadrages

| Date | Cadrage | Verdict |
|---|---|---|
| 2026-08-10 | n°1 — atterrissage 3 PR, design_lab = labo, fin B0-B5, Lego 1 domicile | CONVERGÉ |
| 2026-08-11 | n°2 — Lego 2 état civil Q0-Q5 (chemin scellé, partenariat≠concubinage) | LOOP: GO |
| 2026-08-11 | n°3 — Lego 3 revenu Q0-Q5 : clés possédées + projection legacy (pas de migration des writers), montant+période, contexte fiscal 3a v4 fail-closed LPP, cap 100k checkpoint 70k | LOOP: GO |
| 2026-08-11 | n°4 — ordre tranché : affiliation LPP d'abord (Lego 4 court, tri-état jamais absence=false, fiscal v5 symbolique sans CHF), versements 3a en Lego 5 ; cap 55k checkpoint 35k | LOOP: GO AFFILIATION LPP |

## 6ter. Journal des Legos

| Date | Lego | Reviews Codex | État |
|---|---|---|---|
| 2026-08-10/11 | Atterrissage fondation (PR A #1217, PR B #1218, PR C #1219) | A : REJET→ACCEPT P1=0 · B : K-PARTIEL + ACCEPT · C : ACCEPT 0 finding | MERGÉ sur dev, flag OFF |
| 2026-08-11 | Lego 1 — domicile fiscal (#1221 + #1222) | LOOP: GO · REJET 3P1→ACCEPT P1=0 · diagnostic runtime Codex | PROMU 5/5 — reçu runtime a28085268750, flag OFF |
| 2026-08-11 | Lego 2 — état civil (#1224) | LOOP: GO (cadrage Q0-Q5) · REJET 4P1 (3 corrigés, 1 réfuté sur pièces) → ACCEPT · PROMOTION REJET 2P1 → ACCEPT P1=0 | PROMU 5/5 — reçu runtime 37c707aec à portée explicite (proof_scope), flag OFF |
| 2026-08-11 | Lego 3 — revenu (#1226) | LOOP: GO (Q0-Q5 : clés possédées + projection) · 3× REJET→ACCEPT (watermark tombstone, validation stricte, parsing lexical) · PROMOTION ACCEPT P1=0 | PROMU 5/5 — reçu runtime 8e1c6b418, anti-double-×12 prouvé, budget consommant la projection au runtime (capture 03), flag OFF |
| 2026-08-11 | Lego 4 — affiliation LPP (#1228) | LOOP: GO AFFILIATION LPP (ordre tranché avant versements) · REJET→ACCEPT (masquage corrupt ×3 faits, unavailable≠corrupt validé) · PROMOTION ACCEPT P1=0 | PROMU 5/5 — reçu runtime b4ff3fa2c au PREMIER run (harnais 9→3→1), tri-état prouvé (suppression = inconnu), plafond 3a déterminable (fiscal v5), flag OFF |

Note budget (honnêteté) : le loop « doctrine + cadrage » annoncé ~150k tokens
a très largement dépassé son budget — la réconciliation des gates dev jamais
exécutés sur la branche fondation (8 jobs CI rouges, deadlock inter-zones)
n'était pas anticipée. Leçon : tout atterrissage de branche longue doit
budgéter une phase de réconciliation CI explicite.
Lego 1 : le cap 80k a aussi été dépassé — le gate runtime (11 itérations de
harnais sim, diagnostic Codex) coûte cher la première fois ; le harnais est
maintenant réutilisable, les prochains faits l'amortissent.
Lego 2 : cap 60k dépassé ~3× — le PREMIER fait 100 % scellé a révélé 5
verrous de harnais successifs (Keychain sim flaky sur app re-signée, stash
non persistant, purge en boucle à chaque boot, session perdue → portail
d'accueil, gel des tests widget par path_provider), chacun prouvé à la
console avant correction. Acquis durables : stash e2e persistant +
session stashée + purges tolérantes -34018 + capture console permanente
dans le runner — les prochains faits scellés (revenu, 3a) héritent de
tout. Leçon : un fait scellé de bout en bout ≠ un fait wizard ; budgéter
le premier de chaque catégorie comme une phase d'infrastructure.
Lego 3 : l'amortissement est réel — 3 runs harnais (clavier numérique,
flake leg-01 des sims neufs) contre 9 au Lego 2, dans le cap 100k.
Les reviews Codex par tranche (4 REJET→ACCEPT) restent le meilleur
rapport coût/défauts : watermark tombstone et parsing lexical sont des
défauts réels que les tests nominaux ne voyaient pas.
Lego 4 : dans le cap 55k, runtime au premier run — le pattern Lego est
industrialisé de bout en bout. Note pour le Lego 5 (versements) et le
moteur attesté : l'année fiscale du plafond devient bloquante dès
l'arrivée des CHF (learning Codex).

## 6. Journal des Legos

| Date | Lego | Storyboard | Verdict Codex | Verdict Claude | Herméneutique |
|---|---|---|---|---|---|
| — | (aucun livré sous ce protocole) | — | — | — | — |
