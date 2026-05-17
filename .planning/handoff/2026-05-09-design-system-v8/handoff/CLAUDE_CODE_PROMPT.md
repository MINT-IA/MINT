# 🤖 Prompts Claude Code — version blindée

> **Pourquoi cette version.** Le premier handoff a été ignoré : Claude Code n'a pas compris la mission ou n'a pas su par où commencer. Cette version impose un **protocole strict en 3 phases** avec des **portes obligatoires** : Claude Code ne peut pas avancer sans avoir prouvé qu'il a fait l'étape précédente.
>
> **Comment l'utiliser.** Trois prompts dans l'ordre. Tu colles le n°1, tu attends sa réponse, tu valides. Puis le n°2. Puis le n°3. **Ne saute jamais une phase.**

---

## 📋 Vue d'ensemble

| Phase | Prompt | Output attendu | Durée |
|---|---|---|---|
| **1. Compréhension** | `PROMPT_1_ONBOARDING` | Note de cadrage écrite — pas de code | 30 min |
| **2. Architecture (Mission #1)** | `PROMPT_2_ARCHITECTURE` | Audit du `ScreenRegistry` + plan Vague A | 1 sprint |
| **3. Chat vivant (Mission #2)** | `PROMPT_3_CHAT_VIVANT` | Widgets + orchestration | 2-3 jours |

**Règle absolue : Phase 2 doit être validée par Julien avant Phase 3.** Architecture d'abord, design ensuite.

---

# PROMPT 1 — Onboarding & cadrage

> Colle ce prompt en premier. **Output attendu : du texte, pas du code.** Si Claude Code commence à modifier des fichiers, arrête-le et redemande la note de cadrage.

```
Tu vas travailler sur le projet MINT (app Flutter de coaching financier suisse).
Ton rôle : dev lead Flutter + project manager. Tu travailles avec Julien.

═══════════════════════════════════════════════════════════════════
PHASE 1 — COMPRÉHENSION (CETTE PHASE NE PRODUIT PAS DE CODE)
═══════════════════════════════════════════════════════════════════

ÉTAPE 1.1 — Lecture obligatoire dans cet ordre EXACT :

  1. handoff/00-README.md            (l'index)
  2. handoff/ARCHITECTURE.md         (LE document central — 3 couches,
                                      ScreenRegistry, RoutePlanner,
                                      les 6 invariants)
  3. handoff/01-vision.md            (pourquoi le chat doit MONTRER)
  4. handoff/02-chat-vivant-services.md
  5. handoff/03-components.md
  6. handoff/04-animations.md
  7. handoff/05-integration.md
  8. handoff/06-test-plan.md

  Tu peux survoler 04, 05, 06 — mais 00, ARCHITECTURE, 01, 02, 03 sont
  à lire EN ENTIER.

ÉTAPE 1.2 — Inventaire du repo. Liste-moi :

  a) Le chemin exact de app.dart (le fichier GoRouter)
  b) Le chemin exact de ScreenRegistry
  c) Le chemin exact de RoutePlanner
  d) Le chemin exact de CoachOrchestrator
  e) Le chemin exact de SequenceCoordinator
  f) Le chemin exact de AutonomousAgentService
  g) Le dossier theme (où vivent MintColors et MintTextStyles)
  h) Le dossier des widgets premium

  Si une de ces briques n'existe pas dans le repo : DIS-LE explicitement.
  Ne fabrique pas un chemin plausible. Écris "INTROUVABLE" + propose
  3 chemins candidats que Julien peut confirmer.

ÉTAPE 1.3 — Note de cadrage. Écris-moi un document de 400-600 mots
qui répond à CES 6 QUESTIONS, dans cet ordre, avec un titre par
question :

  Q1. Quel est le problème central que MINT cherche à résoudre,
      en une phrase ?

  Q2. Quelles sont les 3 couches de l'architecture, et quel est
      le rôle de chacune ? (1 phrase par couche)

  Q3. Quel est le contrat central de la couche 2, et pourquoi
      c'est lui qui tient l'architecture ?

  Q4. Cite les 6 invariants non-négociables, dans l'ordre du doc.
      Pour chacun, en UNE phrase, dis pourquoi il existe.

  Q5. Quelle est la différence entre Mission #1 (architecture) et
      Mission #2 (chat vivant) ? Pourquoi #1 vient avant #2 ?

  Q6. Liste les 5 vagues de migration (A à E) avec leur objectif
      en UNE phrase chacune.

ÉTAPE 1.4 — Questions ouvertes. Liste-moi 5 à 10 questions que
TU as, à poser à Julien avant de commencer la Phase 2. Les bonnes
questions portent sur :
  - des ambiguïtés dans le handoff
  - des décisions produit que tu n'as pas l'autorité de prendre
  - des trous d'information sur l'état réel du repo

NE COMMENCE PAS LA PHASE 2 tant que Julien n'a pas répondu.

═══════════════════════════════════════════════════════════════════
RÈGLES DE TRAVAIL POUR TOUTE LA SUITE
═══════════════════════════════════════════════════════════════════

R1. ARCHITECTURE D'ABORD. Tu ne touches à un widget qu'après que la
    Vague A (audit ScreenRegistry) soit validée par Julien.

R2. UNE ÉTAPE À LA FOIS. Tu annonces ce que tu vas faire, tu le fais,
    tu montres le diff, tu lances les tests, tu attends validation.

R3. TU NE DEVINES JAMAIS. Si une décision n'est pas dans le handoff,
    tu poses la question. Ne fabrique jamais un nom de fichier, un
    chemin, ou une signature de classe que tu n'as pas vérifié.

R4. LES CONVENTIONS DU REPO PRIMENT. Si le repo a déjà
    "CountUpAnimation" et le handoff dit "MintCountUp", tu utilises
    l'existant et tu notes la divergence dans handoff/DEVIATIONS.md.

R5. AUCUN REFACTOR HORS SCOPE. Ce handoff est une ligne droite.
    Si tu vois quelque chose à améliorer ailleurs, tu le notes dans
    handoff/BACKLOG.md — tu ne le fais pas.

R6. LES 6 INVARIANTS de ARCHITECTURE.md §7 sont sacrés. Tu ne peux
    JAMAIS produire du code qui en viole un. Si la spec semble t'y
    pousser, tu t'arrêtes et tu poses la question.

Commence maintenant par l'ÉTAPE 1.1.
```

---

# PROMPT 2 — Mission #1 : Architecture & navigation (Vague A)

> À coller **uniquement après** que Julien a validé la note de cadrage du Prompt 1. **Output attendu : un audit + un plan, pas du code applicatif.**

```
Phase 1 validée. On passe à la Mission #1 : architecture & navigation.

OBJECTIF DE CETTE PHASE : auditer l'état réel du ScreenRegistry et
produire un plan d'action chiffré pour la Vague A. Aucune modification
de code applicatif tant que ce plan n'est pas validé par Julien.

═══════════════════════════════════════════════════════════════════
PHASE 2 — VAGUE A : AUDIT DU SCREENREGISTRY
═══════════════════════════════════════════════════════════════════

Référence : handoff/ARCHITECTURE.md §3 (le contrat ScreenEntry),
§5 (delta vs l'état actuel), §6 (plan de migration, vague A).

ÉTAPE 2.1 — Inventaire des routes. Produit handoff/audit/01-routes.md
qui contient un tableau Markdown avec une ligne par route déclarée
dans app.dart :

  | Route | Scope | Écran (widget) | Présent dans ScreenRegistry ? |
  |-------|-------|----------------|-------------------------------|

  Source de vérité : le fichier app.dart (GoRouter).
  Méthode : tu lis app.dart en entier, tu listes TOUTES les routes
  (y compris redirections legacy).

  Si tu trouves moins de 30 routes ou plus de 80, tu t'arrêtes et
  tu me dis pourquoi (peut-être que app.dart n'est pas le bon fichier).

ÉTAPE 2.2 — Inventaire des ScreenEntry. Produit
handoff/audit/02-screen-entries.md avec un tableau :

  | intentTag | Route | Behavior | requiredFields | preferFromChat |
  |-----------|-------|----------|----------------|----------------|

  Source : ScreenRegistry (chemin que tu as identifié en Phase 1.2).
  Une ligne par ScreenEntry déclaré.

ÉTAPE 2.3 — Diff. Produit handoff/audit/03-gaps.md qui répond à :

  a) Combien de routes de app.dart n'ont AUCUN ScreenEntry ?
     Liste-les.

  b) Combien de ScreenEntry pointent vers une route inexistante
     dans app.dart ? Liste-les.

  c) Combien de ScreenEntry ont preferFromChat: true mais n'ont
     pas d'intentTag connu de IntentResolver ? Liste-les.

  d) Combien de routes "parcours" (mariage, naissance, divorce,
     retraite, hypothèque, premier emploi) n'utilisent pas
     SequenceCoordinator aujourd'hui ? Liste-les.

ÉTAPE 2.4 — Classification. Pour CHAQUE route sans ScreenEntry,
propose dans handoff/audit/04-proposals.md :

  | Route | Proposition |
  |-------|-------------|
  | /xxx  | (a) ajouter ScreenEntry avec behavior=B, intentTag=..., requiredFields=[...]  OU
  |       | (b) marquer "non routable depuis chat" (technique, debug, dev only)  OU
  |       | (c) à supprimer (route morte) |

  Pour chaque ligne, écris UNE phrase de justification.

ÉTAPE 2.5 — Plan d'exécution. Produit handoff/audit/05-plan.md :

  Liste ordonnée des tâches pour finir la Vague A, avec pour
  chacune :
    - Description (1 ligne)
    - Fichiers touchés (chemins exacts)
    - Tests à ajouter
    - Estimation (en heures)
    - Risques / dépendances

  Total estimé : doit tenir dans un sprint (≤ 40h).
  Si tu dépasses, tu coupes et tu mets le reste dans une "Vague A.2".

ÉTAPE 2.6 — STOP. Une fois les 5 fichiers d'audit produits,
TU T'ARRÊTES. Tu m'écris :

  "Audit Vague A terminé. 5 fichiers produits dans handoff/audit/.
   Résumé en 5 bullets : [...].
   3 décisions à prendre par Julien : [...].
   J'attends ta validation avant de toucher au code."

═══════════════════════════════════════════════════════════════════
RAPPELS CRITIQUES
═══════════════════════════════════════════════════════════════════

• Cette phase ne modifie AUCUN fichier source applicatif.
  Elle ne crée que des fichiers dans handoff/audit/.

• Si tu te surprends à éditer un .dart pendant cette phase,
  tu t'arrêtes. C'est un bug de protocole.

• Si l'inventaire prend > 2h, tu remontes le problème — peut-être
  que ScreenRegistry n'est pas centralisé comme prévu, ou que
  les routes sont éclatées sur plusieurs fichiers.

• Le ScreenRegistry est LE point de contrôle. Sans lui propre,
  rien d'autre ne tient.

Commence maintenant par l'ÉTAPE 2.1.
```

---

# PROMPT 3 — Mission #2 : Chat vivant (après validation Vague A)

> À coller **uniquement après** que Julien a validé le plan de la Vague A et que les ScreenEntry manquants ont été ajoutés. Si la Vague A n'est pas finie, ne lance pas ce prompt — le chat vivant a besoin d'un `ScreenRegistry` propre pour fonctionner.

```
Architecture stabilisée. On passe à la Mission #2 : porter le
prototype "chat vivant" en Flutter natif.

PRÉREQUIS (à confirmer avant de commencer) :
  ✓ La Vague A est terminée (ScreenRegistry à 100% de couverture)
  ✓ Tous les écrans de parcours retournent un ScreenReturn
  ✓ Aucun context.push n'est plus issu d'un écran chat sans passer
    par RoutePlanner

Si un de ces 3 points n'est pas vrai, ARRÊTE-TOI et préviens-moi.

═══════════════════════════════════════════════════════════════════
PHASE 3 — CHAT VIVANT (ordre strict, une étape à la fois)
═══════════════════════════════════════════════════════════════════

Référence visuelle : ouvre handoff/prototype/MINT - Chat vivant.html
dans un navigateur. C'est le rendu cible. Les .jsx dans
handoff/prototype/chat-vivant/ contiennent la logique — à PORTER en
Flutter, pas à copier-coller.

PROTOCOLE PAR ÉTAPE :

  1. Tu m'annonces : "Je vais faire l'étape N — voici ce que je fais
     et pourquoi."
  2. Tu fais.
  3. Tu me montres le diff.
  4. Tu lances les tests (golden + unit).
  5. Tu attends ma validation.
  6. Étape suivante.

═══════════════════════════════════════════════════════════════════
ÉTAPES (dans cet ordre EXACT — tu ne sautes RIEN)
═══════════════════════════════════════════════════════════════════

ÉTAPE 3.1 — Tokens éditoriaux Fraunces (15 min)
   Spec : handoff/03-components.md (toute fin)
   Fichiers :
     • lib/theme/mint_text_styles.dart (ajouts)
     • test/theme/mint_text_styles_test.dart
   Vérifie d'abord que google_fonts est dans pubspec.yaml.
   Vérifie d'abord que MintColors.porcelaine etc. existent déjà.

ÉTAPE 3.2 — Widgets atomiques (1-2h)
   Crée dans lib/widgets/premium/ :
     • mint_count_up.dart       (vérifie d'abord s'il existe ;
                                  s'il existe, vérifie le param "trigger")
     • mint_reveal.dart         (fade + translateY 6→0, 400ms easeOut)
     • mint_typing_dots.dart    (3 dots, pulsation décalée 150ms)
   Spec animations : handoff/04-animations.md
   Golden tests pour chaque widget.

ÉTAPE 3.3 — Niveau 1 (inline) — 2h
   Crée dans lib/widgets/chat_projection/ :
     • mint_inline_insight_card.dart   (spec §1)
     • mint_ratio_card.dart            (spec §2)
   Référence visuelle : prototype/chat-vivant/insight-card.jsx
   Tokens : MintColors.porcelaine / saugeClaire / pecheDouce /
            craie / corailDiscret / successAaa
   Golden tests pour les 4 tones.

ÉTAPE 3.4 — Niveau 2 (scène) — 3h
   Toujours dans lib/widgets/chat_projection/ :
     • mint_life_line_slider.dart      (spec §3)
     • mint_scene_rente_capital.dart   (spec §4)
     • mint_scene_rachat_lpp.dart      (spec §5)
   Gotcha LifeLineSlider : marqueur vertical à ageEpuisement +
   thumb custom — utilise SliderTheme custom OU
   GestureDetector + CustomPaint si Slider ne suffit pas.
   Golden tests : age=75, 89, 99 + variantes embedded.

ÉTAPE 3.5 — Niveau 3 (canvas) — 3h
   • mint_canvas_projection.dart     (spec §6 — le shell)
   • mint_canvas_chapitre.dart       (spec §7)
   • mint_canvas_verdict.dart
   • mint_sensibilite_widget.dart    (spec §8)
   • mint_fiscal_row.dart
   • mint_mini_card.dart
   Animation d'ouverture : slide-up 350ms easeOutCubic
   (PageRouteBuilder + SlideTransition + FadeTransition).

ÉTAPE 3.6 — Orchestration — 3-4h
   Référence : handoff/02-chat-vivant-services.md +
              handoff/05-integration.md
   • lib/services/chat_projection/scene_registry.dart
     Enregistre :
       - 'rente_vs_capital'    → MintSceneRenteCapital
       - 'rachat_lpp'          → MintSceneRachatLPP
       - 'ratio_train_de_vie'  → MintRatioCard.fromPayload
   • Étends ChatMessage avec ChatMessageKind.mintScene + .mintInsight
     + .typing
   • CoachOrchestrator émet maintenant Stream<ChatMessage> au lieu
     de String. Séquence quand intent.scenePayload existe :
       1. typing()                                — 0ms
       2. mintText(intent.leadIn)                 — après 900ms
       3. mintScene(intent.scenePayload!)         — après 600ms
       4. mintText(intent.followUpHint!) si présent — après 1200ms
   • IntentResolver retourne ResolvedIntent avec scenePayload?
   • ReturnContract + CanvasReturn :
     CoachOrchestrator.onCanvasReturn(ret) append un mintText récap.

   ⚠ INVARIANT CRITIQUE : tu NE court-circuites PAS RoutePlanner.
   Le chat vivant rend des SCÈNES INLINE, ce qui ne déclenche PAS
   de navigation. Pour les CTA "Creuser →", la logique reste :
   chat → RoutePlanner.plan(intentTag) → openScreen.

ÉTAPE 3.7 — Tests + feature flag — 2h
   • Golden test par scène
   • Test d'orchestration end-to-end (cf. handoff/06-test-plan.md)
   • FeatureFlags.chatVivant (default false en prod, true en dev)
   • Wrap l'émission de mintScene derrière le flag.
     Fallback flag-off : mintText("Pour creuser, ouvre Explorer
     → Retraite → ...")

═══════════════════════════════════════════════════════════════════
INVARIANTS ÉDITORIAUX (NON-NÉGOCIABLES)
═══════════════════════════════════════════════════════════════════

E1. AUCUN EMOJI. Jamais. Pour une puce, utiliser ▪ (U+25AA).
E2. UN SEUL chiffre-héros par vue. Les autres en displaySmall ou plus petit.
E3. Fraunces = signature éditoriale. Pour les <em>, phrases de recul,
    labels horodatés. JAMAIS en body long.
E4. CHAQUE scène a une "phrase de recul" — une ligne qui remet la
    donnée en perspective humaine. Si tu n'en mets pas, le widget
    est rejeté.
E5. Hypothèses visibles mais discrètes — micro italique, sous
    dashed border.
E6. CTA dans les scènes = NOIRS (MintColors.textPrimary fond,
    #fff texte). Le reste joue le rôle.
E7. Un canvas fermé produit TOUJOURS un récap dans le chat
    (via onCanvasReturn).
E8. Le LLM ne décide pas de la navigation (ARCHITECTURE.md §7
    invariant 1). Tu ne dévies pas de cette règle, même si la
    spec semble le suggérer.

═══════════════════════════════════════════════════════════════════
ANTI-PATTERNS À REJETER
═══════════════════════════════════════════════════════════════════

✗ Ajouter un context.push dans un widget de scène
✗ Faire calculer les chiffres par le widget (les calculs viennent
  des services métier, le widget ne fait que lire)
✗ Utiliser un emoji "pour faire vivant"
✗ Mettre un dégradé là où un aplat suffirait
✗ Ajouter une 7e couleur "parce que c'est joli"
✗ Refactorer CoachOrchestrator au-delà du strict nécessaire
✗ Inventer un nouveau ScreenBehavior (il y en a 5, point)
✗ Bypass RoutePlanner "juste pour ce cas particulier"

Commence par confirmer les 3 prérequis Vague A, puis l'ÉTAPE 3.1.
```

---

## 🔁 Que faire si Claude Code dérape

Symptômes fréquents et leur réponse :

### Il commence à coder en Phase 1
> Réponse : « Stop. Phase 1 ne produit pas de code. Reviens à l'étape 1.1 et donne-moi la note de cadrage. »

### Il invente des chemins de fichiers
> Réponse : « Tu as inventé `lib/services/coach/coach_orchestrator.dart` sans vérifier. Lance `find . -name "*orchestrator*"` et donne-moi le vrai chemin. »

### Il saute la Vague A pour aller au "joli"
> Réponse : « Mission #1 avant Mission #2. Le handoff l'écrit en gras. Reviens au Prompt 2 — l'audit ScreenRegistry. »

### Il refactore hors scope
> Réponse : « Hors scope. Note dans `handoff/BACKLOG.md` et reviens à l'étape en cours. »

### Il viole un invariant éditorial (emoji, dégradé, etc.)
> Réponse : « Tu as ajouté un emoji ligne X. Invariant E1. Retire et continue. »

### Il dit "j'ai tout fait" sans diff visible
> Réponse : « Montre le diff. Lance les tests. Pas de diff = pas de validation. »

### Il enchaîne plusieurs étapes sans pause
> Réponse : « Une étape à la fois. Reviens à l'étape N. Diff + tests + ma validation, puis seulement N+1. »

---

## 🧰 Boîte à outils — micro-prompts utiles

À utiliser entre deux grosses étapes, si besoin de précision.

### Pour vérifier qu'il a bien lu

```
Avant de continuer : redonne-moi en 3 bullets ce qu'est le contrat
ScreenEntry et pourquoi le LLM ne décide jamais de la navigation.
Si tu hésites, relis ARCHITECTURE.md §3 et §7.
```

### Pour le forcer à montrer son travail

```
Stop. Avant tout autre changement : montre-moi le diff exact des
3 derniers fichiers que tu as touchés, ainsi que le résultat de
`flutter test` sur les tests concernés. Pas de résumé — le diff brut.
```

### Pour récupérer un agent perdu

```
Reset. Tu es en train de dériver. Reviens à la dernière étape validée
par Julien. Donne-moi :
  1. Quelle était la dernière étape validée (numéro + intitulé)
  2. Quel est l'état actuel du code (diff non commité)
  3. Quelle est l'étape suivante prévue
Ne fais rien d'autre tant que je n'ai pas répondu.
```

### Pour clore une étape

```
Étape N validée. Avant de passer à N+1, écris dans
handoff/PROGRESS.md une ligne :
  - Date
  - Étape (numéro + nom)
  - Fichiers touchés (chemins)
  - Tests ajoutés
  - 1 phrase de note
Puis annonce l'étape N+1.
```

---

## 🎯 Pourquoi cette version marchera mieux

| Le précédent prompt | Cette version |
|---|---|
| 1 prompt monolithique | 3 prompts séparés par phase, avec portes |
| « Lis le handoff » | Liste ordonnée de fichiers à lire, avec quoi en tirer |
| « Pose tes questions » | 6 questions précises auxquelles répondre par écrit |
| « Une étape à la fois » | Protocole 6-points : annonce → fait → diff → tests → attente → suite |
| Invariants en bloc | Invariants numérotés (R1-R6, E1-E8) référençables |
| Pas d'anti-patterns | Liste explicite « ✗ ne fais pas X » |
| Pas de récup d'erreur | Section dédiée aux dérapages avec réponses prêtes |

L'idée centrale : **un agent n'est performant que dans le cadre d'un protocole strict.** Plus le protocole est explicite, plus l'agent reste sur les rails.
