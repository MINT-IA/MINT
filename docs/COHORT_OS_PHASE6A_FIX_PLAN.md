# Cohort OS Phase 6A Fix Plan

> Statut: plan immediat
> Role: corriger le point 6 proprement, PR par PR
> Scope: cohortes Phase 6A uniquement

---

## PR 1 — Corriger le bug suggestion chips

### Objectif

Fermer la contradiction metier deja live dans `suggestedPrompts()`.

### A corriger

- `rachat LPP` ne doit jamais etre suggere si `hasLpp == false`

### Fichiers

- [response_card_service.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/response_card_service.dart)
- [response_card_service_test.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/test/services/response_card_service_test.dart)

### Tests a ajouter

- profil acceleration avec LPP -> prompt rachat present ou autorise
- profil acceleration sans LPP -> prompt rachat absent
- profil consolidation sans LPP -> prompt rachat absent

### Verdict attendu

- plus aucune suggestion LPP incoherente

---

## PR 2 — Rewriter la spec Cohort OS

### Objectif

Faire de `COHORT_OS_SPEC.md` une spec executable, pas une vision pseudo-code.

### A corriger

- retirer le preambule conversationnel
- remplacer la notion de nouvelle SOT cohortes
- aligner tous les champs sur `CoachProfile` reel
- supprimer `ExplorerHubController` tant qu'il n'existe pas

### Fichiers

- [COHORT_OS_SPEC.md](/Users/julienbattaglia/Desktop/MINT/docs/COHORT_OS_SPEC.md)

### Verdict attendu

- la spec est directement utilisable par les agents

---

## PR 3 — Projection cohort produit

### Objectif

Introduire une projection produit legere basee sur `LifecyclePhaseService`.

### A livrer

- petit type `ProductCohort` ou equivalent
- mapping `LifecyclePhase -> ProductCohort`
- fonction pure, sans nouvelle SOT

### Fichiers probables

- nouveau service leger dans `apps/mobile/lib/services/`
- tests associes

### Verdict attendu

- 6 cohortes produit exploitables sans casser le lifecycle existant

---

## PR 4 — Coach context cohort-aware

### Objectif

Injecter la cohorte produit dans le contexte coach sans rigidifier le systeme.

### Fichiers

- [context_injector_service.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/coach/context_injector_service.dart)
- tests associes

### A prouver

- ton adapte
- sujets prioritaires adaptes
- sujets a ne pas pousser adaptes

---

## PR 5 — Pulse / Cap priorisation minimale

### Objectif

Prouver qu'une meme app parait differente selon la cohorte.

### Scope limite

- priorite du cap
- formulation
- ordre d'affichage minimum

### A eviter

- refonte complete du `CapEngine`

---

## PR 6 — Golden personas + assertions

### Objectif

Mettre fin aux regressions silencieuses cohort-aware.

### A livrer

- 6 personas golden
- 18 assertions minimum
- tests comportementaux sur suggestions / coach context / Pulse

### Verdict attendu

- les cohortes ne sont plus une intuition, mais un contrat teste

---

## Règles de passage

- ne pas lancer PR 3 avant fermeture de PR 1 et PR 2
- ne pas etendre Explorer avant validation PR 4 et PR 5
- ne pas generaliser les 18 journeys avant que les 6 personas soient verts

