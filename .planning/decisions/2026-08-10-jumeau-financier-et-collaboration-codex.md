---
date: 2026-08-10
status: Decided
authors: Julien (product owner), Claude (Product Leader), Codex 5.6-sol (vision co-auteur)
panel: single (validation directe Julien, conversations Codex citées)
supersedes: —
superseded_by: —
description: Le jumeau financier devient le cœur de MINT Next ; méthode storyboard-first + collaboration Claude×Codex à chaque étape remplace la cérémonie sealed-contract.
related:
  - .planning/decisions/2026-08-08-lifelong-financial-twin-and-plans.md
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
  - .planning/decisions/2026-08-06-perimetre-optimisation-fiscale-v1.md
  - .planning/decisions/2026-08-06-architecture-coach-navigateur-monstrateur.md
  - product/mint_next/BRIEF.md
---

# Le jumeau financier est le cœur de MINT Next ; storyboard-first et collaboration Claude×Codex remplacent la cérémonie sealed-contract

## TLDR

Le cœur du produit est un jumeau financier (registre de faits historisés, avec provenance, fraîcheur, propriétaire et consentement) ; aucun écran n'est terminé tant que ses données ne le rejoignent pas ; chaque Lego suit la méthode storyboard-first et un dialogue Codex borné aux trois moments (cadrage, mi-course, review), en remplacement de la cérémonie sealed-contract multi-rondes dont le coût en tokens dépassait la valeur livrée.

## Context

Semaine du 04-08.08 : la cérémonie de gouvernance (contrats RED/GREEN scellés, doubles roasts, 5 rondes de review, re-seals d'inventaire, attestations CI, essaims de sous-agents) a consommé un volume de tokens massif pour livrer trois écrans design_lab (batches 20-22) dont les faits collectés (commune, état civil, revenu, versements 3a) meurent dans l'état local de l'écran. Constat de Julien le 10.08 : ratio valeur/token indéfendable.

En parallèle, les conversations de vision avec Codex 5.6-sol ont produit la définition qui manquait : « MINT est le copilote financier personnel des personnes vivant en Suisse. Il construit progressivement une représentation fiable de leur vie financière, la maintient à jour et transforme cette connaissance en explications, simulations, arbitrages et actions. » Le cœur en est le jumeau financier. Codex conclut lui-même : « arrêter temporairement l'extension du parcours logement ; le prochain Lego doit connecter les faits déjà collectés à la bibliothèque permanente. »

L'audit Opus des trois commits Codex sur `apps/mobile/lib/screens/simulator_3a_screen.dart` (branche `codex/reconcile-mint-next-foundation-20260807` : e40b030ad, 7777daeb4, 38073f8f0) a rendu 5/10 (1 P0 : hypothèque assimilée à une crise de dette ; 7 P1), corrigé ensuite en micro-batch audité. Preuve que le 0-trust doit rester symétrique entre les deux modèles.

Cette décision converge avec trois décisions antérieures jamais reliées entre elles : profil utilisateur = wiki Karpathy avec provenance et fraîcheur (2026-05-13), coach = navigateur-monstrateur qui n'invente jamais un chiffre (2026-08-06), moteurs déterministes canoniques L1-L4 (2026-05-17).

## Decision

1. **Jumeau financier = cœur du produit — par ratification, pas par redéfinition.** Le contrat du fait, le cycle de promotion en 7 points (sauvegarde par l'unique chemin canonique, rechargement, visibilité « Ma situation », correction/suppression, au moins un consommateur réel hors écran de collecte, invalidation des dépendants, pas de transmission distante sans contrat) et l'ordre de construction sont définis par l'ADR **2026-08-08-lifelong-financial-twin-and-plans.md** (Decided, Julien + Codex, branche `codex/reconcile-mint-next-foundation-20260807`). La présente décision le ratifie côté `dev` et n'en redéfinit aucun contenu — elle ajoute le protocole de travail.
2. **Règle d'architecture.** Aucun écran n'est considéré comme terminé si les informations qu'il collecte ne rejoignent pas le jumeau et si ses résultats ne peuvent pas être retrouvés et réutilisés ailleurs (formulation canonique : ADR 2026-08-08 — « un écran qui ne satisfait pas ce cycle est un prototype non promouvable, même s'il est visuellement terminé et testé en isolation »).
3. **v0 : câbler, pas re-fonder.** La fondation existe déjà et est prouvée en runtime : phase `mint-next-user-twin-foundation-20260808` complétée (cycle logement — création, rechargement à froid ×2, édition, suppression durable — Maestro + roast indépendant P1=P2=P3=0), chemin canonique local nommé (`CoachProfileProvider.mergeAnswers → ReportPersistenceService → SecureWizardStore/wizard_answers_v2 → CoachProfile.fromWizardAnswers`), Design Lab store / `BiographyRepository` / écritures backend directes interdits comme sources de vérité. Le travail v0 restant : raccorder les faits des écrans design_lab (commune, état civil, revenu, versements 3a) au même cycle canonique, et faire atterrir la fondation sur `dev`. Les mini-plans viennent après le cycle complet des faits (ordre de construction de l'ADR 2026-08-08).
4. **Pause de l'extension logement.** Le batch23 reste gelé ; son scoping est conservé et resservira une fois les faits logement raccordés au jumeau.
5. **Méthode storyboard-first.** Chaque Lego commence par son storyboard versionné dans le repo : l'histoire courte de ce que vit l'utilisateur, découpée en beats, chaque beat mappé à un écran/état/fait/test. Le code est ensuite écrit pour raconter cette histoire, et la vérification herméneutique finale contrôle que le code raconte bien la même histoire que le storyboard. Le storyboard est le contrat — il remplace les contrats RED/GREEN scellés. Le storyboard canonique du parcours 3a existe déjà (commit `94bb94548`, branche `codex/reconcile-mint-next-foundation-20260807`) : `product/mint_next/storyboard/three_a.storyboard.json` (schéma v3 : scènes avec routes, contrats SPEC, oracles d'intention/observation, emplacements de preuve `evidence.code_refs`/`runtime_receipts` — les crochets herméneutiques) + `storyboard.contract.schema.json` + rendu HTML + garde `tools/checks/mint_next_storyboard_guard.py`. Il doit atterrir sur `dev` au cadrage n°1 ; les anciens storyboards (`docs/W17_STORYBOARD.md`, `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-*.md`) ne sont pas le storyboard MINT Next.
6. **Collaboration Claude×Codex à chaque étape.** Trois moments bornés par Lego : cadrage avant toute ligne de code (challenge de l'intention et du storyboard), arbitrage à mi-course si besoin, review finale du diff. Les rôles sont alternables : Codex code et Claude audite, ou l'inverse — jamais d'auto-notation. Le démarrage et l'arrêt d'un loop sont co-décidés : au lancement d'un loop, la question est posée à Codex ; à la fin, verdict conjoint et décision commune sur la pertinence du loop suivant. `product/mint_next/BRIEF.md` est le contexte partagé que les deux lisent à chaque session.
7. **Discipline token.** Un Lego = petite unité livrant de la valeur visible + faits dans le jumeau, budget token annoncé au cadrage — un seul ensemble cohérent de faits par Lego, jamais une tranche multi-domaines. Pas d'essaims de sous-agents ; des agents ciblés sur de petits batchs. Vérification : tests ciblés + review Codex + un audit du parcours runtime complet — pas cinq rondes ; les findings corrigés reçoivent une revalidation ciblée (le finding, pas le document entier), sans rouvrir de ronde générale.
8. **Document herméneutique.** Un rapport HTML vivant, par thème (jumeau, 3a, logement, fiscalité, coach), qui met en regard storyboard ↔ code ↔ preuve, publié comme artifact à URL stable et versionné sous `.planning/reports/`. Il fusionne avec l'obligation existante de rapport HTML par phase — un seul système de reporting, pas deux.
9. **Inventaire de remplacement et gate unique de promotion.** Remplacé pour tout travail futur : le pattern sealed-contract des batches design_lab (contrats `product/mint_next/batch*/r*-{red,green}-gate.yaml`, flips de receipts, doubles roasts multi-rondes, dispatches d'attestation CI) — aucun nouvel artefact de ce type n'est créé ; le WIP batch23 RED n'est pas complété sous ce pattern (son scoping est réutilisé). Intouchés comme évidence historique : les gates acceptés et attestations des batches ≤ 22. En vigueur jusqu'à l'arbitrage du cadrage n°1 : la machinerie d'évidence B0-B5 du SPEC Golden 3a (périmètre Codex). Le gate exécutable unique de promotion d'un Lego : (1) chaque beat du storyboard mappé à un test ou état observable (garde storyboard), (2) tests ciblés verts, (3) review finale Codex avec P1 = 0, (4) vérification herméneutique runtime du parcours (sim/Maestro) citée, (5) cycle du fait en 7 points prouvé pour tout fait collecté (ADR 2026-08-08). Les cinq, sinon pas de promotion.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  La cérémonie sealed-contract n'était pas du gaspillage : elle a attrapé 17 chiffres affichés faux et forcé une rigueur que des reviews légères laisseront passer. La supprimer pourrait faire revenir les défauts silencieux. Réponse : ce qui a attrapé les défauts, ce sont les reviews adversariales bornées (Codex, roasts) — conservées — pas la machinerie de seals, re-seals et attestations, qui n'a jamais trouvé un défaut par elle-même. Le storyboard-first garde un contrat vérifiable en réduisant le coût fixe. Second contre-argument : le storyboard peut devenir du « spec theater » (une belle histoire jamais confrontée au code). Mitigation : chaque beat doit être mappé à un test ou un état observable, et la vérification herméneutique est un gate de fin de Lego, pas une option.
- **What does this source not address ?**
  L'atterrissage sur `dev` de la fondation Codex (585 commits, ~908 fichiers depuis le 01.08 : phase jumeau complétée, SPEC Golden 3a Vertical, corpus de contrats privacy/PII/rétention/clés/menaces/AIPD, storyboard, écrans `mint_next_*` dans apps/mobile) n'est pas séquencé — c'est la sortie attendue du cadrage n°1. Le SPEC 3a embarque sa propre machinerie d'évidence (chaînes de reçus B0-B5, double reviewers, replay byte-compare) dont la lourdeur est en tension avec la discipline token de la présente décision — arbitrage à rendre au cadrage n°1, pas ici. Pas de contrat de sync cloud versionné (P1 de l'audit Opus) : tant qu'il n'existe pas, les faits du jumeau restent exclus de toute synchronisation backend. Pas de mesure chiffrée du budget token par Lego — la première itération l'étalonnera.
- **What would change this conclusion ?**
  Si deux Legos consécutifs livrés sous ce protocole présentent des régressions que la cérémonie sealed-contract aurait mécaniquement bloquées (chiffre affiché faux, écran orphelin promu), le volet gouvernance est re-litigé. Si le cadrage n°1 démontre que l'unification des deux jumeaux exige une migration lourde, la portée du v0 est re-scopée avant d'écrire du code.

## Sources

- Conversations Codex 5.6-sol (10.08.2026, transmises par Julien) : définition MINT, jumeau financier, boucle produit, mini-plans, écran « Ma situation », collecte contextuelle.
- Audit Opus 5 des commits 3a Codex : `~/.claude/plans/you-are-the-independent-virtual-ullman.md` (hors repo, chemin cité pour traçabilité).
- `.planning/decisions/2026-08-06-architecture-coach-navigateur-monstrateur.md` (coach = interface, jamais base de données).
- `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` (event log, L1-L4).
- Mémoire projet `project_user_profile_wiki.md` (profil = wiki Karpathy, 2026-05-13).

## Status & follow-up

- Implementation tracking : `product/mint_next/BRIEF.md` (contexte partagé) ; cadrage n°1 Claude×Codex : séquencer l'atterrissage de la fondation `codex/reconcile-mint-next-foundation-20260807` sur `dev` (ADR 2026-08-08, phase jumeau complétée, storyboard `94bb94548`, SPEC 3a), câbler les faits design_lab au cycle canonique, arbitrer la machinerie d'évidence B0-B5, définir le Lego 1 + budget.
- Re-litigation triggers : listés ci-dessus (régressions sous le nouveau protocole ; migration lourde révélée au cadrage n°1).
