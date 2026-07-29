---
date: 2026-07-24
status: Proposed
authors: Claude (autorité produit déléguée par Julien 2026-07-24) + panel 6 rôles + validation Codex gpt-5.6-sol
panel: 6-pers (juriste, privacy/nLPD, product life-events, platform/enforcement, journaliste red-team, lead-synthèse) + validation adversariale Codex CLI
supersedes: —
superseded_by: —
description: "Campagne A→C→B post-audit : garantir le contenu servi vs sources officielles, câbler le gate anti-faux-droit, puis compléter les parcours de vie. Séquence A d'abord."
related:
  - .planning/audit-etat-des-lieux-2026-07/CONSTANTS-AUDIT.md
  - services/backend/app/services/regulatory/registry.py
---

# Campagne « contenu officiel garanti » : A (vérité servie) → C (gate anti-régression) → B (parcours de vie)

## TLDR

Le pilier fiscal v2 a fermé le risque « les chiffres sont-ils justes ? » ; l'audit visait plus loin — **le contenu servi et les docs publics contiennent du droit faux qu'aucun gate n'attrape**. On corrige le contenu (A), on câble le gate qui empêche la régression (C), puis on complète les parcours de vie (B). Séquence A d'abord parce que c'est le risque réputationnel/journaliste et le cœur du mandat fondateur : « aider l'utilisateur à choisir seul en garantissant les vraies sources officielles ».

## Context

Autorité déléguée (Julien, 2026-07-24, verbatim) : « je te donne à toi et à des agents experts l'autorité pour faire l'arbitrage produit et décider de la suite à donner », objectif MINT = « application de lucidité financière qui aide l'utilisateur à faire des choix tout seul sur la base de ses propres données et en garantissant les vraies sources officielles ».

Panel de 6 rôles convoqué, puis **chaque rapport validé adversarialement par Codex** (gpt-5.6-sol, CLI read-only local — vérifie le code, marque INVÉRIFIABLE-WEB les valeurs officielles, celles-ci croisées par les agents à WebSearch). Les 4 verdicts Codex = FAIL, mais FAIL = raffinement (sur-affirmations attrapées), pas invalidation : le fond est confirmé partout.

**Findings confirmés (agent web + Codex code) :**
- Corpus éducatif factuellement faux : ~8-12 fiches portent des valeurs 2024 périmées (`88'200` au lieu de `90'720`, `61'740` = chimère de deux millésimes). 715 citations d'articles de loi, aucune vérifiée par un gate.
- Strings ARB servies directement à l'écran, fausses : `communityChallenge03Desc:8906` (« versement 3a jusqu'en mars » — règle inventée, préjudice = perte de déduction), `dataTransparencyScanDetail:11017` + `bankImportTransparency:11004` (« notre serveur suisse » alors que Railway US), `renteVsCapitalEplTooltip:3134` (art. 79b possiblement inversé — à trancher web).
- `mariage_service.py` : « pénalité du mariage » calculée avec `DEDUCTION_DOUBLE_ACTIVITE = 2'800` (fausse) + barèmes IFD 2024 + multiplicateurs cantonaux heuristiques → **migration vers le moteur fiscal v2**, pas patch de constantes (correction Codex).
- Docs privacy auto-contradictoires : 3 identités du responsable, Sentry Berlin vs US, `APP_STORE_PRIVACY_LABELS.md` « Data Not Collected » intenable (profil financier sync serveur).
- Enforcement décoratif : 4 jobs définis mais absents du `needs` de `ci-gate` (`pg-integration`, `truth-in-crypto`, `screen-registry-parity`, `screen-registry-three-way-parity`) ; path-filter CI n'inclut pas `education/**` (PR education-only → gate vert sans scan) ; seul le contexte `"CI Gate"` est required par la protection de branche.

**Tranché en direct (0-trust) :** l'ingester RAG (`ingester.py:68 glob("*.md")`) est **non récursif** — seules les ~40 fiches top-level sont ingérées ; les 121 fiches imbriquées (`concepts/`, `cantons/`, `faq/`) ont une ingestion incertaine. Les strings ARB, elles, sont servies de façon certaine (UI directe).

## Decision

**Cluster A — vérité servie (priorité, cœur du mandat).**
1. Corriger les strings ARB fausses servies directement à l'écran, contre valeurs vérifiées.
2. Corriger les fiches éducatives périmées contre le registre réglementaire (source de vérité web-vérifiée 2026-07-23) — les deux copies jumelles.
3. Migrer `mariage_service.py` vers le moteur fiscal v2 (pas patcher les constantes).
4. Aligner les docs privacy sur le flux réel du code (identité unique, retrait/rétention exacts, App Store labels) — sans revendiquer SCC/DPF/région non vérifiables.

**Cluster C — gate anti-régression (avec A).**
5. Câbler le gate `education-facts` : manifest de faits épinglés au registre + checker stdlib (valeur périmée = FAIL, article hors whitelist = warn→hard à deadline auto-armée), parité des copies jumelles, preuve de dents native (rouge jour 1 sur le corpus actuel).
6. Raccrocher les 4 jobs orphelins au `needs` de `ci-gate` + path-filter `education/**` + étendre le verrou d'agrégation.

**Cluster B — parcours de vie (après A/C, arbitrages product rendus).**
7. W0 : dégrader les 4 façades émotionnelles en orientation honnête sans chiffre. W1 : triade Travail (firstJob/newJob/jobLoss) complète avec preuve runtime. Puis famille, logement, succession.
8. Write-back conjoint (`-mla`) : snapshot-hydration, consentement bilatéral, payload minimal nLPD — schéma exact à contractualiser (trou Codex).
9. Échelle 44 (`-9fl`) : paliers officiels exacts, l'interpolation disparaît — liste de consommateurs à recorriger (inclure `minimal_profile_service`, retirer `disability_gap_service`, correction Codex).

**Discipline d'exécution :** chaque bead suit le cycle re-prove → RED → fix → gate → PR → **revue Codex adversariale** → merge squash. Toute valeur de compliance provient de la table vérifiée du juriste (avec source URL), jamais inventée.

## Counter-arguments and data gaps

- **Vue opposée la plus forte (steel-man) :** « B (produit) avant A (contenu) — un contenu juste sur une app dont 0 parcours de vie n'est complet en prod ne convertit personne ; le risque journaliste est théorique tant que l'app n'a pas d'utilisateurs. » Réponse : le mandat fondateur met explicitement « sources officielles garanties » au cœur ; et A est peu coûteux (strings + valeurs registre) alors que B est le plus gros chantier qui attend de toute façon des arbitrages. On ne retarde pas B, on le fait après un socle de vérité que le gate C protège.
- **Ce que Codex n'a PAS pu trancher (INVÉRIFIABLE-WEB, data gaps) :** les valeurs officielles 2026 exactes (déléguées au juriste-v2 en cours, avec sources) ; le sens juridique de l'art. 79b après EPL (rapport et registre divergent) ; la région Railway réelle en prod et le statut Swiss-US DPF d'Anthropic/Sentry (contractuel/runtime) ; le sous-ensemble du corpus réellement servi au coach (ingestion runtime staging).
- **Ce que le panel n'a pas couvert :** D4 (redesign) reposait sur une prémisse FAUSSE — Codex prouve que les tokens Handoff 2 sont déjà portés (`colors.dart:50-89`, `mint_text_styles.dart:25-26`) ; D4 est **retiré du plan tel quel** et à réécrire depuis un inventaire d'adoption réel, jamais en swap global.
- **Risque d'exécution :** corriger une string de compliance sans la table vérifiée = remplacer un faux par un non-vérifié. Mitigation : les fixes contenu attendent le juriste-v2 ; seuls les fixes code-confirmés (serveur suisse → sans géo, jobs ci-gate) et registry-confirmés (millésimes) partent avant.
