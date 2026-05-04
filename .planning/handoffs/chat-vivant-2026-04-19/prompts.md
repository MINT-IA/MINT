# Prompts prêts-à-coller pour Claude Code

Copie-colle chaque prompt dans Claude Code, dans l'ordre. Chaque prompt suppose que tu es dans le repo Flutter et que `handoff/` est accessible.

---

## Prompt 0 — Onboarding

```
Lis handoff/00-README.md puis handoff/01-vision.md.
Ensuite, lis handoff/02-architecture.md et handoff/03-components.md.
Résume-moi en 5 bullets ce que tu as compris de la direction "chat vivant" avant qu'on commence à coder.
```

---

## Prompt 1 — Tokens éditoriaux

```
Ajoute les 3 text styles Fraunces à lib/theme/mint_text_styles.dart :
editorialDisplay (32pt w500), editorialLarge (22pt w400), editorialBody (17pt w400).

La spec exacte est dans handoff/03-components.md à la toute fin.
Utilise GoogleFonts.fraunces — vérifie que google_fonts est déjà dans pubspec.yaml.
Ajoute les tests associés dans test/theme/mint_text_styles_test.dart si un fichier similaire existe.
```

---

## Prompt 2 — MintCountUp + MintReveal + MintTypingDots

```
Dans lib/widgets/premium/ :
1. Vérifie si mint_count_up.dart existe. Si oui, vérifie qu'il supporte un paramètre "trigger" pour relancer l'animation ; sinon ajoute-le.
2. Si absent, crée mint_count_up.dart selon la spec dans handoff/04-animations.md.
3. Crée mint_reveal.dart — fade + translateY 6px → 0 sur 400ms easeOut, avec paramètre delay.
4. Crée mint_typing_dots.dart — 3 dots qui pulsent en décalage 150ms (spec handoff/04).

Pour chaque nouveau widget, ajoute un golden test dans test/widgets/premium/.
```

---

## Prompt 3 — MintInlineInsightCard + MintRatioCard

```
Crée lib/widgets/chat_projection/mint_inline_insight_card.dart selon la spec handoff/03-components.md §1.
Crée aussi mint_ratio_card.dart §2.

Référence visuelle : handoff/prototype/chat-vivant/insight-card.jsx.
Ouvre handoff/prototype/MINT — Chat vivant.html pour voir le rendu cible si tu as un doute sur l'apparence.

Tokens à utiliser : MintColors.porcelaine / saugeClaire / pecheDouce / craie / corailDiscret / successAaa.
Typo : MintTextStyles.editorialLarge (nouveau) pour la headline, labelMedium pour l'eyebrow.

Ajoute golden tests pour les 4 tones (porcelaine, sauge, peche, craie) de MintInlineInsightCard.
```

---

## Prompt 4 — MintLifeLineSlider

```
Crée lib/widgets/chat_projection/mint_life_line_slider.dart selon la spec handoff/03-components.md §3.

Référence visuelle : handoff/prototype/chat-vivant/scene-rente-capital.jsx, fonction LifeLine.

Gotchas :
- Le fill change de couleur selon age > ageEpuisement (retirementLpp sinon retirement3a)
- Marqueur vertical à l'ageEpuisement avec label "capital épuisé" dessous
- Thumb custom (cercle 16×16 blanc, border 2px de la couleur fill)

Utilise Slider avec SliderTheme custom, ou re-implémente avec GestureDetector + CustomPaint si Slider ne permet pas le marqueur custom. Golden tests pour age=75, 89, 99.
```

---

## Prompt 5 — MintSceneRenteCapital

```
Crée lib/widgets/chat_projection/mint_scene_rente_capital.dart selon handoff/03-components.md §4.

Référence : handoff/prototype/chat-vivant/scene-rente-capital.jsx.

Structure exacte dans la spec. Points d'attention :
- Le calcul ageEpuisement est itératif (boucle year-by-year) — garde-le dans le widget, pas dans un service
- MintSceneColumn est un sous-widget interne (highlighted / not)
- CountUp sur les deux chiffres avec trigger = amount.round() / 1000
- Si variant == inline, CTA "Creuser" en bas ; sinon pas de CTA
- Phrase de recul en Fraunces em sur fond craie

Golden tests : états age=75, 89, 99 + variant embedded (sans CTA).
```

---

## Prompt 6 — MintSceneRachatLPP

```
Crée lib/widgets/chat_projection/mint_scene_rachat_lpp.dart selon handoff/03-components.md §5.
Référence : handoff/prototype/chat-vivant/scene-rachat-lpp.jsx.

Points d'attention :
- 2 chiffres count-up : economieTotale (successAaa) et renteAddMensuelle (retirementLpp)
- Slider corailDiscret, step 5000, range 20k-150k
- Phrase de recul : "Coût réel net : X CHF. Le reste, c'est l'État qui finance."

Golden tests : montants 20k, 60k (default), 150k.
```

---

## Prompt 7 — MintCanvasProjection + chapitres

```
Crée lib/widgets/chat_projection/mint_canvas_projection.dart selon handoff/03-components.md §6-7.
Référence : handoff/prototype/chat-vivant/canvas-rente-capital.jsx.

Components à créer dans le même dossier :
- mint_canvas_chapitre.dart (section éditoriale)
- mint_canvas_verdict.dart (carte noire finale)
- mint_sensibilite_widget.dart (§8)
- mint_fiscal_row.dart (utilisé dans chapitre 02)
- mint_mini_card.dart (utilisé dans chapitre 03)

Animation slide-up 350ms easeOutCubic à l'ouverture. PageRouteBuilder avec SlideTransition + FadeTransition.

Golden tests : canvas à l'état initial (chapitre 01 en haut), scrollé au verdict.
```

---

## Prompt 8 — SceneRegistry + ChatMessage étendu

```
Crée lib/services/chat_projection/scene_registry.dart selon handoff/02-architecture.md.

Enregistre les scenes :
- 'rente_vs_capital' → MintSceneRenteCapital
- 'rachat_lpp' → MintSceneRachatLPP
- 'ratio_train_de_vie' → MintRatioCard.fromPayload

Étends lib/models/chat_message.dart pour supporter ChatMessageKind.mintScene et .mintInsight, avec un champ ScenePayload? scene.

Ajoute des constructeurs factory : ChatMessage.mintScene(payload), ChatMessage.mintInsight(payload), ChatMessage.typing().

Tests : round-trip sérialisation (sceneId + seed + finalState).
```

---

## Prompt 9 — Orchestration chat

```
Modifie CoachOrchestrator (trouve-le dans lib/services/coach/ ou similaire) pour émettre un Stream<ChatMessage> au lieu d'un String.

Séquence à produire quand intent.scenePayload existe :
1. ChatMessage.typing()
2. ChatMessage.mintText(intent.leadIn) — après 900ms
3. ChatMessage.mintScene(intent.scenePayload!) — après 600ms
4. ChatMessage.mintText(intent.followUpHint!) si présent — après 1200ms

Étends IntentResolver pour retourner ResolvedIntent avec scenePayload optionnel.

Ajoute ReturnContract + CanvasReturn selon handoff/02-architecture.md.
Implémente CoachOrchestrator.onCanvasReturn(ret) qui append un ChatMessage.mintText récap.

Tests d'orchestration dans handoff/06-test-plan.md.
```

---

## Prompt 10 — Feature flag + rollout

```
Ajoute FeatureFlags.chatVivant (default false en prod, true en dev).

Dans CoachOrchestrator, wrap l'émission de mintScene derrière le flag. Fallback si flag off : ChatMessage.mintText("Pour creuser, ouvre Explorer → Retraite → ...").

Pousse la PR avec titre "feat(chat): projections vivantes — niveau 1-3" et lien vers handoff/01-vision.md dans la description.
```

---

## Comment gérer les écarts

Si Claude Code te dit "je ne trouve pas le fichier X" ou "cette signature ne correspond pas à l'existant" :
1. **Ne pas forcer.** Les conventions réelles du repo priment sur le handoff.
2. Lui demander de proposer l'adaptation, la valider, puis continuer.
3. Si un composant du DS existe déjà avec un nom différent (ex: `CountUpAnimation` au lieu de `MintCountUp`), **l'utiliser** et noter la divergence dans un `handoff/DEVIATIONS.md`.

Si Claude Code propose un ajout hors scope (ex: "je pourrais aussi refactorer X"), **dire non** et continuer. Ce handoff est une ligne droite.
