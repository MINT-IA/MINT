# MINT Chat Vivant — Handoff pour Claude Code

**Cible :** migrer le prototype HTML `handoff/prototype/MINT — Chat vivant.html` vers des widgets Flutter natifs dans `apps/mobile/lib/`.

**L'idée en une phrase :** le chat MINT ne *raconte* plus, il *montre* — comme quand Claude te dessine un graphe en parlant. Trois niveaux de projection dans la conversation : insight inline, scène interactive, canvas plein écran.

---

## Comment lire ce package

Lis **dans l'ordre** :

1. [`01-vision.md`](./01-vision.md) — Pourquoi cette direction, les 3 niveaux de projection, les invariants éditoriaux.
2. [`02-architecture.md`](./02-architecture.md) — Services Flutter à créer (SceneRegistry, ChatProjectionService, ReturnContract).
3. [`03-components.md`](./03-components.md) — Les 5 widgets Flutter à construire, un par un, avec signatures, tokens, mapping vers le prototype.
4. [`04-animations.md`](./04-animations.md) — Timings exacts (count-up, reveal, slide-up canvas) et mapping vers `flutter/animation`.
5. [`05-integration.md`](./05-integration.md) — Comment brancher dans `CoachOrchestrator` / `IntentResolver` existants.
6. [`06-test-plan.md`](./06-test-plan.md) — Golden tests + invariants testables.
7. [`prompts.md`](./prompts.md) — Prompts prêts-à-coller dans Claude Code, un par composant.

**Référence visuelle :** `prototype/MINT — Chat vivant.html` — ouvre-le dans un navigateur pour voir l'intention. Les fichiers JSX dans `prototype/chat-vivant/` contiennent la logique de chaque composant (à porter, pas à copier tel quel).

**Captures :** `prototype/captures/` contient des screenshots pour vérification visuelle rapide.

---

## Ordre d'exécution recommandé

```
Étape 1 — Tokens (15 min)
  → Ajouter MintTextStyles.editorialLarge/Body/Display (Fraunces)
  → Vérifier MintColors.porcelaine/craie/corailDiscret/saugeClaire existent déjà ✓

Étape 2 — Widgets atomiques (1-2h)
  → MintCountUp (probablement déjà existant, à vérifier)
  → MintRevealFade (nouveau)

Étape 3 — Projection Niveau 1 : inline (2h)
  → MintInlineInsightCard
  → MintRatioCard

Étape 4 — Projection Niveau 2 : scène (3h)
  → MintLifeLineSlider (atomique)
  → MintSceneRenteCapital
  → MintSceneRachatLPP

Étape 5 — Projection Niveau 3 : canvas (3h)
  → MintCanvasProjection (shell plein écran)
  → MintCanvasChapitre (section éditoriale)
  → MintSensibiliteWidget

Étape 6 — Orchestration (3-4h)
  → SceneRegistry (map intent → scene widget)
  → ChatProjectionService (rend les scènes dans le flux chat)
  → Branchement IntentResolver → SceneRegistry
  → ReturnContract (retour au chat après canvas)

Étape 7 — Tests + polish (2h)
  → Golden tests pour chaque scène
  → Test d'orchestration (chat → scène → canvas → retour)
```

**Total estimé :** 2-3 jours d'ingénieur Flutter concentré.

---

## Invariants non-négociables

Tirés de `DESIGN_SYSTEM.md` + `MINT_IDENTITY.md` déjà dans le repo :

1. **Aucun emoji.** Jamais. Si tu es tenté, utilise un puce géométrique (`▪`) ou rien.
2. **Un seul chiffre-héros par vue.** Les autres chiffres sont en `displaySmall` ou plus petit.
3. **Fraunces = signature éditoriale.** Utilisée pour les `em`, les phrases de recul, les labels "Aujourd'hui · 14:22". Jamais en body long.
4. **Chaque scène a une *phrase de recul*** — une ligne qui remet la donnée en perspective humaine, en porcelaine/craie.
5. **Hypothèses visibles mais discrètes** — en `micro` italique, sous une dashed border.
6. **Les CTA dans les scènes** sont noirs (`MintColors.textPrimary` → fond, `#fff` texte), pas colorés. Le reste joue le rôle.

---

## Ce qui **n'est pas** dans ce handoff

- Le backend (calculs LPP, taux de conversion, fiscalité par canton) — il existe déjà dans `retirement_models/` et `tax_engine/`. Les widgets lisent des valeurs, ne les calculent pas.
- Les écrans Explorer/Aujourd'hui/Profil — ils restent tels quels. Seule la conversation évolue.
- La voix (voice-first 2028) — out of scope pour cette étape.

---

## Question ? Doute ?

Relis `01-vision.md` puis `03-components.md`. Si ça ne suffit pas, écris à Julien. **Ne devine pas** un token ou un comportement : tout est spec'é.
