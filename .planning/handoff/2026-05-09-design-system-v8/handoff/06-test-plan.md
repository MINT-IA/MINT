# 06 — Plan de tests

## Golden tests (un par composant visuel)

Chaque widget de scène a un golden test qui verrouille le rendu visuel. Utiliser `golden_toolkit` (déjà dans le projet).

### Fichiers à créer

```
test/widgets/chat_projection/
├── mint_inline_insight_card_test.dart
├── mint_ratio_card_test.dart
├── mint_scene_rente_capital_test.dart
├── mint_scene_rachat_lpp_test.dart
├── mint_life_line_slider_test.dart
└── mint_canvas_projection_test.dart
```

### Template golden

```dart
testGoldens('MintSceneRenteCapital — état initial (âge 89, avantage rente)', (tester) async {
  await tester.pumpWidgetBuilder(
    MintSceneRenteCapital(
      payload: ScenePayload(
        sceneId: 'rente_vs_capital',
        level: ProjectionLevel.scene,
        seed: {
          'capitalBrut': 520000,
          'tauxConversion': 0.048,
          'impotCapital': 0.18,
          'rendementReel': 0.025,
        },
      ),
    ),
    surfaceSize: const Size(354, 560),
  );
  await screenMatchesGolden(tester, 'scene_rente_capital_age_89');
});
```

### États à capturer par scène

**MintSceneRenteCapital** :
- âge 75 (avantage capital, épuisement non atteint)
- âge 89 (avantage rente, default)
- âge 99 (avantage rente large)

**MintSceneRachatLPP** :
- montant 20k (min)
- montant 60k (default)
- montant 150k (max)

**MintCanvasProjection** :
- état initial, chapitre 01 visible
- scrollé jusqu'au verdict

---

## Tests d'orchestration

```dart
test('user demande rente ou capital → chat émet text + scene + text', () async {
  final orchestrator = CoachOrchestrator(…);
  final messages = await orchestrator.respondTo('rente ou capital ?').toList();

  expect(messages[0].kind, ChatMessageKind.mintTyping);
  expect(messages[1].kind, ChatMessageKind.mintText);
  expect(messages[2].kind, ChatMessageKind.mintScene);
  expect(messages[2].scene!.sceneId, 'rente_vs_capital');
  expect(messages[3].kind, ChatMessageKind.mintText);
});

test('canvas fermé → chat reçoit un récap', () async {
  final orchestrator = CoachOrchestrator(…);
  orchestrator.onCanvasReturn(CanvasReturn(
    sceneId: 'rente_vs_capital',
    finalState: {'ageVie': 85, 'rendement': 4.0},
    insightsViewed: ['fiscalité'],
    timeSpent: const Duration(seconds: 30),
  ));

  final last = orchestrator.chatController.messages.last;
  expect(last.kind, ChatMessageKind.mintText);
  expect(last.text, contains('85 ans'));
  expect(last.text, contains('4%'));
});
```

---

## Invariants testables

Écrire des tests qui vérifient ces règles en parcourant les widgets rendus :

```dart
test('aucun emoji dans les scènes', () async {
  final widgets = [MintSceneRenteCapital(…), MintSceneRachatLPP(…)];
  for (final w in widgets) {
    final texts = await _extractAllTexts(w);
    for (final t in texts) {
      expect(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true).hasMatch(t),
        isFalse, reason: 'Emoji détecté dans: "$t"');
    }
  }
});

test('Fraunces utilisé pour les signatures', () async {
  // Vérifier que MintTextStyles.editorialLarge() utilise bien Fraunces
  final style = MintTextStyles.editorialLarge();
  expect(style.fontFamily, contains('Fraunces'));
});

test('CTA scène est noir (textPrimary), pas coloré', () async {
  // Rendre une scène, trouver le FilledButton du CTA "Creuser"
  // Vérifier sa backgroundColor
});
```

---

## Accessibilité

```dart
test('MintSceneRenteCapital — tous les sliders ont un label sémantique', (tester) async {
  await tester.pumpWidget(…);
  final sliders = find.byType(Slider);
  for (final s in sliders.evaluate()) {
    final semantics = tester.getSemantics(find.byWidget(s.widget));
    expect(semantics.label, isNotEmpty);
  }
});
```

Contrastes : les tokens AAA (`textSecondaryAaa`, `textMutedAaa`, etc.) sont déjà testés dans `test/theme/aaa_tokens_contrast_test.dart` — rien à ajouter.
