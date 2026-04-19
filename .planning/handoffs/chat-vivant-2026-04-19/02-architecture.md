# 02 — Architecture Flutter

## Les 3 services à créer

```
lib/services/chat_projection/
├── scene_registry.dart        # Map intent → ScenePayload → Widget
├── chat_projection_service.dart # Insère des scènes dans le flux chat
└── return_contract.dart       # Contexte passé du canvas au chat
```

---

## SceneRegistry

**Rôle :** connaître toutes les scènes projetables et savoir laquelle invoquer pour un intent donné.

```dart
// lib/services/chat_projection/scene_registry.dart

enum ProjectionLevel { inlineInsight, scene, canvas }

class ScenePayload {
  final String sceneId;           // 'rente_vs_capital', 'rachat_lpp', …
  final ProjectionLevel level;
  final Map<String, dynamic> seed; // paramètres initiaux (âge, capital…)
  final String? followUpHint;     // ce que MINT dit juste après la scène

  const ScenePayload({
    required this.sceneId,
    required this.level,
    required this.seed,
    this.followUpHint,
  });
}

class SceneRegistry {
  static final _registry = <String, Widget Function(ScenePayload)>{
    'rente_vs_capital': (p) => MintSceneRenteCapital(payload: p),
    'rachat_lpp': (p) => MintSceneRachatLPP(payload: p),
    'ratio_train_de_vie': (p) => MintRatioCard.fromPayload(p),
    // …
  };

  static Widget? build(ScenePayload payload) {
    final factory = _registry[payload.sceneId];
    return factory?.call(payload);
  }

  static bool has(String sceneId) => _registry.containsKey(sceneId);
}
```

**Branchement avec l'existant :** le `IntentResolver` existant produit un intent. Étendre pour qu'il puisse retourner un `ScenePayload` en plus (ou à la place) d'un texte.

---

## ChatProjectionService

**Rôle :** insérer les scènes comme des *messages* dans le flux chat, sans casser le modèle `ChatMessage` existant.

```dart
// lib/models/chat_message.dart (étendre)

enum ChatMessageKind { userText, mintText, mintScene, mintInsight, mintTyping }

class ChatMessage {
  final ChatMessageKind kind;
  final String? text;              // pour text kinds
  final ScenePayload? scene;       // pour scene/insight kinds
  final DateTime timestamp;
  final String? sessionMarker;     // "Aujourd'hui · 14:22 · Phase 1"

  const ChatMessage._({
    required this.kind,
    this.text,
    this.scene,
    required this.timestamp,
    this.sessionMarker,
  });

  factory ChatMessage.mintScene(ScenePayload scene) =>
    ChatMessage._(kind: ChatMessageKind.mintScene, scene: scene, timestamp: DateTime.now());

  // … etc
}
```

Le builder du chat (ex: `ChatListView`) branche sur `kind` :

```dart
switch (message.kind) {
  case ChatMessageKind.userText: return UserBubble(text: message.text!);
  case ChatMessageKind.mintText: return MintChatBubble(text: message.text!);
  case ChatMessageKind.mintTyping: return const MintTypingDots();
  case ChatMessageKind.mintScene:
  case ChatMessageKind.mintInsight:
    return Padding(
      padding: const EdgeInsets.only(left: 38, right: 2, bottom: 14),
      child: SceneRegistry.build(message.scene!) ?? const SizedBox.shrink(),
    );
}
```

---

## ReturnContract

**Rôle :** quand l'utilisateur ferme un canvas, passer au chat le contexte de ce qu'il a vu, pour que la prochaine réplique MINT soit informée.

```dart
// lib/services/chat_projection/return_contract.dart

class CanvasReturn {
  final String sceneId;
  final Map<String, dynamic> finalState;   // âge=85, rendement=4% …
  final List<String> insightsViewed;       // ['fiscalité', 'sensibilité']
  final Duration timeSpent;

  const CanvasReturn({
    required this.sceneId,
    required this.finalState,
    required this.insightsViewed,
    required this.timeSpent,
  });
}
```

Quand le canvas se ferme, le `CoachOrchestrator` reçoit un `CanvasReturn` et génère un `ChatMessage.mintText` contextualisé :

> "Tu as regardé à 85 ans avec 4% de rendement. Deux choses à retenir : …"

**Invariant :** un canvas fermé doit **toujours** produire une réplique MINT de récap, même courte. Jamais un retour silencieux.

---

## Flux complet (séquence)

```
User tape "rente ou capital ?"
   ↓
IntentResolver → Intent { sceneCandidate: 'rente_vs_capital', level: scene }
   ↓
CoachOrchestrator :
   1. Ajoute ChatMessage.mintText ("Ni l'un ni l'autre avant…")
   2. Ajoute ChatMessage.mintScene(payload) → SceneRegistry rend le widget
   3. Ajoute ChatMessage.mintText ("Bouge l'âge — tu vois…")
   ↓
User manipule le slider dans la scène
   → pas de trip serveur, tout est local dans le widget
   ↓
User tape "Creuser" sur la scène
   → Push MintCanvasProjection en route plein écran
   ↓
User ferme le canvas
   → CanvasReturn construit par le canvas
   → CoachOrchestrator.onCanvasReturn(return) génère mintText récap
   → Chat scrolle en bas
```

---

## Ce qu'il **ne faut pas** faire

- ❌ Mettre la logique de calcul (LPP, fiscalité) dans les widgets de scène. Ils consomment des valeurs fournies par le `payload.seed` ou par un `RetirementService` injecté.
- ❌ Faire du `Navigator.pushReplacement` depuis le canvas. Le canvas est un **modal plein écran** qui se ferme en retour — le chat reste dessous.
- ❌ Créer un `WebView` pour embarquer le HTML du prototype. Tout est porté en Flutter natif.
