---
description: "Synthèse de l'état des lieux 2026-06-12 (6 experts + recherche web) : MINT souffre de 3 fautes structurelles (claims non groundés, état utilisateur split-brain, sprawl de surfaces) — plan de refondation en 4 milestones, avec corrections stratégiques au framing fondateur. Statut : Proposed."
status: Proposed
date: 2026-06-12
inputs: .planning/phases/mint-etat-des-lieux-20260612/01..06 + walkthrough W1-cadre-50 + MATRIX-illogismes-2026-06-09
---

# Refondation « Lucidity Spine » — décision de synthèse

## Contexte déclencheur

Session manuelle fondateur (2026-06-12) + walkthrough persona W1 : coach inverse la définition d'un rachat LPP (« retirer ton capital »), taux de remplacement 28 % vs 69 % entre /home et /retraite, deux profils utilisateur non synchronisés dans la même session, écran register sur l'ancien design, arbre a11y vide sur 6 écrans. Verdict fondateur : « tu ne regardes pas la logique de l'application ». État des lieux complet commandé (code + docs + web), avec challenge explicite du framing fondateur.

## Diagnostic — 3 fautes structurelles (pas 44 bugs)

**F1 — Aucun grounding au niveau des CLAIMS.** Toute la pile de garde (citation gate, hallucination detector, ComplianceGuard) n'inspecte que les NOMBRES ; une définition inversée sans chiffre traverse tout (01 §1). Pire : les gates sophistiqués (dual-LLM, citation gate) sont feature-flaggés OFF en prod, et le `coach_reasoner` (risques+hypothèses+sources par recommandation, ~80 % du contrat VZ) n'a aucun appelant production — façade-sans-câblage (01 §2,7). Aucun outil `explain_concept`, `tool_choice` hardcodé `auto` sur la surface authentifiée (04 §2).

**F2 — État utilisateur split-brain.** ≥7 représentations, 2 stores physiques (blob JSON backend écrit par `save_fact` vs CoachProfile dérivé du wizard local), réconciliés par un merge lossy de 200 LOC. L'architecture event-log DÉCIDÉE (ADR 2026-05-17) est ~80 % construite, ~0 % cutover (`FF_FACT_EVENT_DUAL_WRITE` OFF) (02 §1-5). Le « 50 ans vs 48 » et le « 28 % vs 69 % » en découlent mécaniquement.

**F3 — Sprawl de surfaces.** 104+ fichiers écrans, 150-324 routes, ~50 simulateurs/life-events en destinations séparées ; le coach est l'onglet 3 sur 4 — une destination, pas la couche d'orchestration ; chat anonyme et onglet Coach sont des surfaces déconnectées sans mémoire partagée (03 §2-3).

## Corrections au framing fondateur (le challenge demandé)

1. **« Centraliser toute la vie financière » comme wedge = pitch de cimetière** (Mint 2024, Liiva CH 2024). La centralisation est un SOUS-PRODUIT de la victoire sur des décisions précises, jamais le titre (06 §9).
2. **« On sera supérieurs à VZ, on a la technologie » sous-estime le moat de VZ** : confiance + absorption de responsabilité, pas le logiciel. Le north star réaliste et différenciant : « VZ-correct facts, zéro claim non groundé » — out-VERIFY VZ, pas out-judge (01 §10, 06 §10).
3. **18 life events à parité = la plus grande faiblesse stratégique.** Profondeur sur 3 events (prévoyance decision-support à bandes de confiance ; cross-border/FATCA/frontalier ; affordability logement×fiscalité), la largeur reste dans la conversation générative (03 §5, 06 §8).
4. **Conversational-first est risqué pour le 35-55 suisse** (BofA a retiré le bouton chat d'Erica ; Revolut AIR = couche par swipe, pas destination). Cible : surface-first / coach-as-layer (03 §4,6).
5. **« Écrans magnifiques générés » = catalogue de composants MINT curés remplis de payloads groundés et schema-validés** (le pattern `widget_renderer` existant est LE bon) — jamais de layouts générés par le LLM, sinon chaque écran généré redevient une surface non gardée (04 §7,10).
6. **Tension LSFin non résolue, la plus dangereuse** : le prompt revendique « narrateur, pas conseiller » pendant que `coach_reasoner`/`get_couple_optimization` calculent et CLASSENT des leviers personnalisés — substance over label (01 §9, 05 §4). Doit être tranché par le fondateur, pas par silence.

## Décision (Proposed)

**4 milestones séquencés, la boucle persona-walkthrough comme gate permanent de chaque milestone :**

- **M1 — Grounded Coach (~2-3 sem)** : registre wiki de concepts suisses curés + outil `explain_concept` à `tool_choice` forcé sur intent ; claim-checker déterministe (top ~50 assertions, détection d'inversions — fixture `rachat-inversion` RED en CI d'abord) ; `show_fact_card` gated (content/source validés) ; activer-ou-supprimer les gates dark ; câbler `coach_reasoner` ; fix `save_fact` → retour mobile (quick-fix split-brain) ; corrections domaine (réf. femme AVS 64.5 en 2026, prose EPL/79b post-arrêts TF 02.2026). **Invariant au choix compliance — réduit l'exposition dans tous les mondes.**
- **M2 — One Spine (~3 sem, chemin minimal d'abord)** : cutover event-log (dual-write ON, un endpoint d'écriture, une shape de lecture, `CoachProfile.fromCanonical`) ; tuer `_mergeFinancialFieldsFromRemote`, `safeReplacementRate` (dénominateur NET déjà locké), `MinimalProfileResult`, legacy `Profile`. Le chemin complet 6-9 sem se fait par itérations derrière le minimal.
- **M3 — Five Surfaces (~3-4 sem)** : IA cible « Aujourd'hui / Coach-layer / Mon argent / Plans / Profil&Confiance » ; ~50 écrans simulateurs/life-events fondus dans la palette d'artefacts du coach ; register redesign inclus ; a11y réparée par construction ; instrumentation usage AVANT suppression définitive d'écrans (gap 03 §10).
- **M4 — Depth Wedge** : les 3 events au niveau VZ-beating, boucle document (certificat LPP → spine → recalc → nouvel éclairage d'arbitrage), budget évolutif.
- **Docs** : PRODUCT-SPINE.md créé comme north star (squelette dans 05), ROADMAP_V2 dégradé en historique (headers mensongers corrigés), SOT+IDENTITY patchés — PR quick-wins immédiat.

**Plafond compliance — TRANCHÉ par le fondateur 2026-06-12 : périmètre ÉDUCATION STRICTE, bulletproof.** Conséquences opérationnelles : toutes les sorties d'arbitrage sont formulées en comparaisons de scénarios éducatives avec hypothèses explicites (jamais en recommandations personnalisées classées) ; le code est aligné sur ce périmètre (reframe des sorties `coach_reasoner`/`get_couple_optimization`, gardes prescriptives bloquantes, cohérence prompt↔code) — workstream prioritaire intégré à M1. Le reste du plan : délégation complète au Product Leader (« je te laisse suivre le meilleur plan possible »).

## Counter-arguments and data gaps

### Counter-arguments

- **« Encore une refondation »** : MINT a déjà eu des pivots ; le risque de refondation perpétuelle est réel. Mitigation : M1 est petit, mesurable (fixture RED→GREEN en CI), livré avant toute décision M3 ; la boucle persona est le juge, pas l'esthétique du plan.
- **Cutover spine pendant que l'app vit** : risque de régression massif. Mitigation : dual-write + strangler-fig déjà décidés (ADR 05-17), l'infra existe à 80 % ; le walkthrough persona re-run à chaque vague.
- **Tuer 50 écrans peut détruire de la valeur invisible** (SEO interne, parcours FATCA/frontalier conformes) : d'où instrumentation d'usage et revue compliance AVANT suppression (03 §10).
- **Le claim-checker déterministe ne couvrira jamais tout le langage naturel** : vrai — il couvre la classe « inversions/définitions du top-50 » ; le reste passe par tool-forcing + eval continue, pas par l'illusion d'un filtre parfait.

### Data gaps

- Aucune analytics d'usage MINT propre (quel écran est réellement utilisé) — préalable au kill-list M3.
- Pas de test modéré utilisateurs suisses 35-55 — à faire avant de figer l'IA M3.
- Position FINMA précise « is-it-advice » pour un moteur d'arbitrage non-exécutant — à clarifier pour M4 (06 §data-gaps).
- AUM/économics VZ digitaux exacts non publics.
