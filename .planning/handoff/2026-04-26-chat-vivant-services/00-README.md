# MINT — Handoff Claude Code

**Tu es project manager + dev lead sur MINT.** L'app fonctionne (50+ routes, 100+ services, parcours réels) mais souffre d'un problème central : **trois axes d'orchestration coexistent sans hiérarchie claire**. Le chat coach, le routing par intent, les séquences guidées — chacun bricole sa navigation. Résultat : les utilisateurs perdent le fil, le code dérive.

**Mission #1 (priorité absolue) : architecture & navigation.**
**Mission #2 : porter le prototype "chat vivant" sur cette base saine.**

Tout le reste (composants, animations, tests) sert ces deux missions.

---

## Ordre de lecture obligatoire

Ne commence à coder qu'après avoir lu **dans cet ordre** :

### 🏛 Niveau 0 — Cadre architectural (le plus important)

1. **[`ARCHITECTURE.md`](./ARCHITECTURE.md)** — **À LIRE EN PREMIER.** Les 3 couches, le contrat ScreenRegistry × ScreenBehavior × RouteDecision, la machine d'état, les invariants non-négociables, le plan de migration en 5 vagues. C'est le cadre dans lequel tout le reste s'inscrit.
2. **[`architecture.html`](./architecture.html)** — Schéma visuel du même contenu. Ouvre-le dans un navigateur pour fixer les idées.

### 🎯 Niveau 1 — Vision produit

3. [`01-vision.md`](./01-vision.md) — Pourquoi le chat doit *montrer* et plus seulement *raconter* (les 3 niveaux de projection).

### 🔧 Niveau 2 — Implémentation

4. [`02-chat-vivant-services.md`](./02-chat-vivant-services.md) — Services Flutter spécifiques au chat vivant (`SceneRegistry`, `ChatProjectionService`, `ReturnContract`). **Tactique.** À lire après `ARCHITECTURE.md` (qui pose le cadre stratégique).
5. [`03-components.md`](./03-components.md) — Les 5 widgets Flutter, signatures, tokens.
6. [`04-animations.md`](./04-animations.md) — Timings exacts.
7. [`05-integration.md`](./05-integration.md) — Branchement dans `CoachOrchestrator` / `RoutePlanner` existants.
8. [`06-test-plan.md`](./06-test-plan.md) — Golden tests + invariants testables.
9. [`prompts.md`](./prompts.md) — Prompts prêts-à-coller, un par composant.

---

## Mission #1 — Architecture & navigation (priorité absolue)

> Lis `ARCHITECTURE.md` en entier. La section §6 (Plan de migration) est ta feuille de route.

### Les 5 vagues de migration

| Vague | Objectif | Durée |
|---|---|---|
| **A** | Audit complet du `ScreenRegistry` — vérifier que les 50 routes de `app.dart` ont chacune un `ScreenEntry` (ou une exclusion explicite). | 1 sprint |
| **B** | Fermer les portes latérales — tout `context.push` issu du chat doit passer par `RoutePlanner`. Lint custom. Tous les écrans de parcours retournent `ScreenReturn`. | 1 sprint |
| **C** | Migrer chaque parcours multi-écrans (retraite, hypothèque, mariage, divorce, premier emploi) sur `SequenceCoordinator`. | 1-2 sprints |
| **D** | Élargir `AutonomousAgentService` (demande EPL, attestation 3a). Tableau « Mes documents générés ». Audit log exposé. | 1 sprint |
| **E** | Observabilité — métriques par `RouteDecision.action`, par tier (SLM/BYOK/fallback), par étape de `SequenceRun`. | continu |

### Les 6 invariants non-négociables

1. **Le LLM ne décide pas de la navigation.** Il propose un `intentTag`. Le code (`RoutePlanner` + `ScreenRegistry` + `ReadinessGate`) décide la route.
2. **Aucun écran ne s'ouvre sans `ReadinessGate`.** Si `requiredFields` manquent : `askFirst` ou `openWithWarning`.
3. **Aucun artefact agent ne sort sans `SafetyGate`.** 11 règles + validation user obligatoire + audit log immuable.
4. **Une seule source de vérité par couche** : `ScreenRegistry`, `CoachProfile`, `app.dart`.
5. **Compliance centralisée.** Toutes les sorties LLM passent par `ComplianceGuard` (LSFin art. 3/8).
6. **Privacy-first.** Tier 1 = SLM on-device (LPD art. 6). Cloud BYOK uniquement sur opt-in user.

### Avant de bouger une ligne de code

Pose-moi (Julien) tes questions sur :
- Le périmètre exact de la Vague A (combien d'écrans ne sont pas dans `ScreenRegistry` aujourd'hui ?).
- Les routes qui doivent rester `preferFromChat: false`.
- Les parcours multi-écrans qui ne passent pas encore par `SequenceCoordinator`.

**Ne devine jamais.** Si une décision n'est pas dans `ARCHITECTURE.md`, demande.

---

## Mission #2 — Chat vivant (après que la Vague A soit cadrée)

> Le prototype HTML `prototype/MINT — Chat vivant.html` montre l'intention. Le chat ne raconte plus, il *montre* — comme quand Claude te dessine un graphe en parlant.

### Ordre d'exécution

```
Étape 1 — Tokens (15 min)
  → Vérifier MintTextStyles.editorialLarge/Body/Display (Fraunces)
  → Vérifier MintColors.porcelaine/craie/corailDiscret/saugeClaire ✓ (déjà présents)

Étape 2 — Widgets atomiques (1-2h)
  → MintCountUp (vérifier l'existant)
  → MintRevealFade (nouveau)

Étape 3 — Projection Niveau 1 : inline (2h)
  → MintInlineInsightCard, MintRatioCard

Étape 4 — Projection Niveau 2 : scène (3h)
  → MintLifeLineSlider, MintSceneRenteCapital, MintSceneRachatLPP

Étape 5 — Projection Niveau 3 : canvas (3h)
  → MintCanvasProjection (shell), MintCanvasChapitre, MintSensibiliteWidget

Étape 6 — Orchestration (3-4h)
  → SceneRegistry — branché sur ScreenRegistry existant (cf. ARCHITECTURE.md §3)
  → ChatProjectionService — rend les scènes inline dans CoachChatScreen
  → ReturnContract — retour au chat avec ScreenReturn (cf. ARCHITECTURE.md §4)

Étape 7 — Tests + polish (2h)
  → Golden tests par scène, test d'orchestration de bout en bout
```

**Total estimé :** 2-3 jours.

### Invariants éditoriaux (chat vivant)

Tirés de `DESIGN_SYSTEM.md` + `MINT_IDENTITY.md` :

1. **Aucun emoji.** Jamais. Pour une puce, utiliser `▪`.
2. **Un seul chiffre-héros par vue.** Les autres en `displaySmall` ou plus petit.
3. **Fraunces = signature éditoriale.** Pour les `em`, phrases de recul, labels horodatés. Jamais en body long.
4. **Chaque scène a une *phrase de recul*** — une ligne qui remet la donnée en perspective humaine.
5. **Hypothèses visibles mais discrètes** — `micro` italique, sous dashed border.
6. **CTA dans les scènes** = noirs (`MintColors.textPrimary` fond, `#fff` texte). Le reste joue le rôle.

---

## Ce qui **n'est pas** dans ce handoff

- Les calculs métier (LPP, fiscalité, taux de conversion) — déjà dans `retirement_models/` et `tax_engine/`. Les widgets lisent, ne calculent pas.
- Les écrans Explorer/Aujourd'hui/Profil dans leur structure actuelle — restent tels quels jusqu'à la Vague C.
- La voix (voice-first 2028) — out of scope.

---

## Référence visuelle

- `prototype/MINT — Chat vivant.html` — ouvre dans un navigateur.
- `prototype/chat-vivant/*.jsx` — logique des composants (à porter, pas à copier tel quel).
- `prototype/captures/` — screenshots pour vérification.
- `colors_and_type.css` — tokens centralisés (déjà miroirés dans `apps/mobile/lib/theme/`).

---

## Règle d'or

**Architecture d'abord. Toujours.** Un beau widget posé sur une nav cassée ne sert à personne. Si la Vague A révèle des trous dans `ScreenRegistry`, on les bouche avant de toucher au "chat vivant". Le but, c'est une app qui *tient* — pas un démo qui brille.

Question ? Doute ? Écris à Julien. Ne devine pas.
