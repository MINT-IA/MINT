# 05 — Intégration dans le chat existant

## Point d'entrée : `CoachOrchestrator`

Le fichier existant (`lib/services/coach/coach_orchestrator.dart` ou équivalent) reçoit un message utilisateur et produit une réponse. Étendre pour émettre une séquence de `ChatMessage` au lieu d'un seul texte.

```dart
// Avant
Future<String> respondTo(String userMessage) async { … }

// Après
Stream<ChatMessage> respondTo(String userMessage) async* {
  final intent = await _intentResolver.resolve(userMessage);

  // 1. Typing
  yield ChatMessage.typing();

  // 2. Réplique d'entame (texte court qui amène la scène)
  yield ChatMessage.mintText(intent.leadIn);

  // 3. Scène projetée si applicable
  if (intent.scenePayload != null && SceneRegistry.has(intent.scenePayload!.sceneId)) {
    yield ChatMessage.mintScene(intent.scenePayload!);
    if (intent.followUpHint != null) {
      yield ChatMessage.mintText(intent.followUpHint!);
    }
  }
}
```

---

## IntentResolver — extension

Le resolver existant matche une phrase vers un intent. Étendre le schema d'intent :

```dart
class ResolvedIntent {
  final String leadIn;              // "Ni l'un ni l'autre avant qu'on regarde…"
  final ScenePayload? scenePayload; // null si pas de scène applicable
  final String? followUpHint;        // "Bouge l'âge — tu vois comment…"
  final List<ChatAction> actions;    // chips optionnels "Creuser" / "Plus tard"
}
```

Mapping à ajouter :

| Intent | sceneId | ProjectionLevel | seed par défaut |
|---|---|---|---|
| `retirement.rente_vs_capital` | `rente_vs_capital` | scene | `{capitalBrut, tauxConversion: 0.048, impotCapital: 0.18}` |
| `retirement.rachat_lpp` | `rachat_lpp` | scene | `{tauxMarginal, anneesEchelon: 4}` |
| `retirement.ratio_train_de_vie` | `ratio_train_de_vie` | inlineInsight | `{numerator, denominator}` |

Le seed provient du profil utilisateur (`ProfileService.current`), pas de valeurs hardcodées.

---

## Canvas — intégration

Le CTA "Creuser" dans une scène → push le canvas :

```dart
void _openCanvas() {
  Navigator.of(context).push(MintCanvasRoute(
    sceneId: 'rente_vs_capital',
    initialState: {...currentSliderState},
    onReturn: (CanvasReturn ret) {
      // Le chat reçoit le retour et génère un récap
      context.read<CoachOrchestrator>().onCanvasReturn(ret);
    },
  ));
}
```

Dans `CoachOrchestrator.onCanvasReturn` :

```dart
void onCanvasReturn(CanvasReturn ret) {
  final recap = _recapBuilder.build(ret);
  _chatController.append(ChatMessage.mintText(recap));
}
```

Le `RecapBuilder` est simple : lookup de templates par `sceneId`, interpolation du `finalState`.

```dart
// Exemple pour rente_vs_capital
"Tu as regardé à ${ret.finalState['ageVie']} ans avec ${ret.finalState['rendement']}% de rendement. "
"La rente ${ret.finalState['ageVie'] > 87 ? 'garde l'avantage' : 'perd face au capital placé'}."
```

---

## Persistance

Les scènes doivent survivre à un cold-start de l'app :
- `ChatMessage.scene` sérialise `sceneId + seed + finalState` uniquement (pas le widget)
- À la réhydratation, `SceneRegistry.build()` reconstruit le widget depuis le payload
- Le state de slider (âge, rendement) peut être stocké dans le payload ou ré-initialisé au seed — à décider selon l'UX voulue (la V1 peut ré-initialiser)

---

## Feature flag

Mettre l'ensemble derrière `FeatureFlags.chatVivant` — permet de rollback instantanément si un intent produit un payload cassé.

```dart
if (FeatureFlags.chatVivant && intent.scenePayload != null) {
  yield ChatMessage.mintScene(intent.scenePayload!);
} else {
  // Fallback : texte seul avec lien vers l'écran Explorer
  yield ChatMessage.mintText("Pour creuser, ouvre Explorer → Retraite → ${intent.fallbackScreen}");
}
```
