# CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY — MINT

> Statut: document stratégique / architecture technique
> Horizon: S57+ (Phase 2 "Le Compagnon")
> Portée: couche d'orchestration entre le chat Coach et les 109 surfaces MINT
> Prérequis: Claude tool calling opérationnel (S56), BudgetSnapshot, CapEngine V1, 4-tab shell
> Source de vérité: oui, pour l'orchestration chat-to-screen
> Compagnons: `MINT_UX_GRAAL_MASTERPLAN.md`, `NAVIGATION_GRAAL_V10.md`, `BLUEPRINT_COACH_AI_LAYER.md`
> Ne couvre pas: design system, voix, contenu éducatif détaillé

---

## 1. Diagnostic

### Ce qui existe
- 109 surfaces actives (105 screens + 4 shell/tabs)
- Routing riche dans `app.dart` : routes canoniques + redirects legacy + deep links + query params
- Chat avec widget_renderer, response_card_widget, smart_shortcuts, lightning_menu
- Claude tool calling (10 tools dont `show_*` et `ask_user_input`)
- `initialPrompt` et `CapCoachBridge.pendingPrompt` pour le pré-routage

### Ce qui manque
- Une **couche unique d'intention** : aujourd'hui, le routage est fragmenté entre mots-clés hardcodés, `context.push` dispersés, cards, chips, hubs, shortcuts
- Une **couche de readiness** : aucun écran ne déclare ses prérequis de données
- Un **registre central des surfaces** : les infos sont réparties entre `app.dart`, hubs, `SCREEN_BOARD_101.md`, et `context.push` éparpillés
- Un **contrat de retour** : le coach ouvre des écrans mais ne sait pas ce qui s'y est passé

### Le vrai problème
MINT sait naviguer. MINT ne sait pas encore **décider proprement quand ouvrir quoi**.

---

## 2. Architecture cible

### Formule

```text
message utilisateur
  → IntentResolver (LLM)
  → RoutePlanner (readiness check)
  → meilleure surface (ou réponse inline)
  → ReturnContract
  → boucle vivante
```

### 5 composants

| Composant | Rôle | Implémentation |
|-----------|------|----------------|
| **IntentResolver** | Extraire l'intention du message | Tool Claude `resolve_intent` |
| **ScreenRegistry** | Carte officielle des 109 surfaces | Fichier de données Dart `const Map` |
| **ReadinessGate** | Vérifier si les données suffisent | Fonction pure par surface |
| **RoutePlanner** | Décider : inline / ouvrir / pré-question | Tool Claude `route_to_screen` |
| **ReturnContract** | Boucle retour écran → coach → Aujourd'hui | Callback standardisé |

### Principe fondamental

**Le LLM décide de l'intention. Le code décide du routage.**

Le LLM ne doit jamais retourner un `context.push('/route')` brut. Il retourne un `intent` + `confidence`, et le `RoutePlanner` côté Flutter consulte le `ScreenRegistry` et le `ReadinessGate` pour décider de l'action.

---

## 3. Les 5 comportements de surface

Chaque surface MINT appartient à exactement UN comportement d'orchestration :

### A — Direct Answer (réponse inline dans le chat)
Le chat répond avec un widget inline sans ouvrir d'écran.
- Budget rapide, score confiance, comparaison simple, fait éducatif
- Widgets : `ChatGaugeCard`, `ChatFactCard`, `ChatComparisonCard`
- Exemples : "C'est quoi mon score ?", "Combien me reste-t-il ce mois ?"

### B — Decision Canvas (écran de décision)
Il faut ouvrir un écran de simulation/arbitrage.
- Rente vs capital, comparaison emploi, simulateur 3a, franchise LAMal
- Prérequis : données minimales satisfaites
- Exemples : "Rente ou capital ?", "Je compare deux offres d'emploi"

### C — Roadmap Flow (parcours de vie)
Il faut ouvrir un flow d'impact/checklist pour un événement de vie.
- Divorce, naissance, chômage, premier emploi, achat immobilier
- Prérequis : identification de l'événement
- Exemples : "Je viens de divorcer", "On attend un bébé"

### D — Capture / Utility (donnée manquante)
Il manque de la donnée ou un document pour avancer.
- Scanner un certificat, compléter le profil, importer des données
- Déclenchement : readiness gate échoue pour une surface B ou C
- Exemples : "Je n'ai pas mon certificat LPP", "Mes données sont incomplètes"

### E — Conversation pure (pas de surface)
La question n'appelle pas de surface financière.
- Explication conceptuelle, clarification, question hors périmètre
- Le coach répond en texte, éventuellement avec un fait éducatif
- Exemples : "C'est quoi la LPP ?", "Merci", "Comment ça marche ?"

---

## 4. Screen Registry

### Structure par surface

```dart
class ScreenEntry {
  final String route;
  final String intentTag;         // tag sémantique pour le matching LLM
  final ScreenBehavior behavior;  // A/B/C/D/E
  final List<String> requiredFields;  // champs CoachProfile nécessaires
  final List<String> optionalFields;  // champs qui améliorent l'expérience
  final String? fallbackRoute;    // si readiness échoue, où rediriger
  final bool preferFromChat;      // le coach peut-il ouvrir cet écran ?
  final bool prefillFromProfile;  // pré-remplir les inputs depuis CoachProfile ?
}
```

### Exemples d'entrées

| Route | Intent tag | Behavior | Required | Fallback |
|-------|-----------|----------|----------|----------|
| `/rente-vs-capital` | `retirement_choice` | B | `salaireBrut`, `age` | `/coach?prompt=retraite` |
| `/divorce` | `life_event_divorce` | C | `civilStatus=marié` | (aucun) |
| `/budget` | `budget_overview` | B | `netIncome` | `/onboarding/quick-start` |
| `/invalidite` | `disability_gap` | B | `employmentStatus` | ask_user_input |
| `/3a-deep/staggered-withdrawal` | `tax_optimization_3a` | B | `age`, `canton` | `/coach?prompt=3a` |
| `/fiscal` | `cantonal_comparison` | B | `canton`, `netIncome` | ask_user_input |
| `/naissance` | `life_event_birth` | C | — | (aucun) |
| `/mortgage/affordability` | `housing_purchase` | B | `salaireBrut`, `canton` | ask_user_input |
| `/frontalier` | `cross_border` | C | `employmentStatus` | (aucun) |
| `/independant` | `self_employment` | C | — | (aucun) |

---

## 5. Readiness Gate

### Principe
Avant d'ouvrir une surface, le planner vérifie si l'utilisateur a les données suffisantes.

### 3 niveaux de readiness

| Niveau | Condition | Action |
|--------|-----------|--------|
| **Ready** | Tous les `requiredFields` présents | Ouvrir directement |
| **Partial** | Certains `requiredFields` manquants mais l'écran peut fonctionner en estimation | Ouvrir avec bandeau "estimation" + CTA enrichissement |
| **Blocked** | Donnée critique manquante sans laquelle l'écran n'a pas de sens | Poser 1-2 questions via `ask_user_input` puis router |

### Exemples

- `rente vs capital` sans certificat LPP :
  → `Partial` — ouvrir en mode estimation large, bandeau "Plus précis avec ton certificat LPP"
- `rachat LPP` sans `rachatMaximum` :
  → `Blocked` — "Pour chiffrer un rachat, j'ai besoin de ton rachat maximum. Tu as ton certificat LPP ?"
- `budget` avec profil incomplet :
  → `Partial` — ouvrir avec CTA enrichissement
- `invalidité` sans statut pro :
  → `Blocked` — poser 1 question "Tu es salarié·e ou indépendant·e ?"

---

## 6. Route Planner (tool Claude)

### Implémentation : tool `route_to_screen`

Le tool est déclaré côté backend dans `coach_tools.py` :

```json
{
  "name": "route_to_screen",
  "description": "Décide si et comment ouvrir un écran MINT depuis le chat. Vérifie la readiness et retourne l'action optimale.",
  "input_schema": {
    "type": "object",
    "properties": {
      "intent": { "type": "string", "description": "L'intention identifiée (ex: retirement_choice, life_event_divorce, budget_overview)" },
      "confidence": { "type": "number", "description": "Confiance dans l'intention (0-1)" }
    },
    "required": ["intent", "confidence"]
  }
}
```

### Logique côté Flutter

```dart
class RoutePlanner {
  final ScreenRegistry registry;
  final CoachProfile profile;
  final CapMemory capMemory;
  final BudgetSnapshot? snapshot;

  RouteDecision plan(String intent, double confidence) {
    final entry = registry.findByIntent(intent);
    if (entry == null) return RouteDecision.conversationOnly();

    final readiness = _checkReadiness(entry, profile);

    switch (readiness) {
      case ReadinessLevel.ready:
        return RouteDecision.openScreen(entry.route, prefill: _prefill(entry));
      case ReadinessLevel.partial:
        return RouteDecision.openWithWarning(entry.route, missingFields: readiness.missing);
      case ReadinessLevel.blocked:
        return RouteDecision.askFirst(readiness.missingCritical);
    }
  }
}
```

---

## 7. Return Contract

### Principe
Quand l'utilisateur revient d'un écran, le coach doit savoir ce qui s'est passé.

### Structure

```dart
class ScreenReturn {
  final String route;
  final ScreenOutcome outcome;  // completed, abandoned, changedInputs
  final Map<String, dynamic>? updatedFields;
  final double? confidenceDelta;
  final String? nextCapSuggestion;
}

enum ScreenOutcome { completed, abandoned, changedInputs }
```

### Boucle vivante

```text
Écran terminé (completed)
  → CapMemory.markCompleted(cap)
  → BudgetSnapshot.recompute()
  → Coach contextualise : "Ton taux de remplacement est passé à X%."

Écran abandonné (abandoned)
  → CapMemory.markAbandoned(cap)
  → Coach propose alternative ou revient plus tard

Données modifiées (changedInputs)
  → CoachProfile.update(fields)
  → Recalcul confiance + projections
  → Coach signale l'impact du changement
```

---

## 8. Pré-routage en 3 niveaux

### Niveau A — Répondre sans quitter le chat
Si la question peut être clarifiée avec un widget inline.
- "C'est quoi mon score ?" → `show_score_gauge`
- "Combien me reste-t-il ?" → `show_budget_snapshot`
- "C'est quoi la LPP ?" → texte éducatif + `show_fact_card`

### Niveau B — Ouvrir une surface directement
Si l'intention est claire et la donnée suffisante.
- "Je veux comparer rente et capital" → `/rente-vs-capital`
- "Mon budget" → `/budget`
- "Je viens de divorcer" → `/divorce`

### Niveau C — Poser une ou deux questions avant de router
Si la bonne surface dépend d'un manque critique.
- "J'ai peur pour ma retraite" → readiness check → si OK, `/retraite` ; sinon, `ask_user_input(salary)` puis route
- "Je veux payer moins d'impôts" → profil riche ? `/fiscal` ou `/3a` ; sinon, question d'aiguillage

---

## 9. Cartographie des surfaces par comportement

### A — Direct Answer (~10 surfaces)
Score confiance, budget snapshot, fait éducatif, comparaison rapide

### B — Decision Canvas (~15 surfaces)
`rente_vs_capital`, `job_comparison`, `simulator_3a`, `affordability`, `lamal_franchise`, `fiscal_comparator`, `staggered_withdrawal`, `real_return`, `provider_comparator`, `dividende_vs_salaire`, `saron_vs_fixed`, `epl_combined`, `amortization`, `compound_interest`, `simulator_leasing`

### C — Roadmap Flow (~14 surfaces)
`divorce`, `naissance`, `unemployment`, `first_job`, `mariage`, `concubinage`, `housing_sale`, `donation`, `deces_proche`, `expat`, `frontalier`, `independant`, `demenagement_cantonal`, `disability_gap`

### D — Capture / Utility (~9 surfaces)
`document_scan`, `documents`, `profile`, `avs_guide`, `household`, `open_banking_hub`, `consent`, `byok_settings`, `slm_settings`

### E — Conversation pure
Pas de surface dédiée — texte + éventuellement `show_fact_card`

### Non routables depuis le chat
`landing`, `register`, `login`, `admin_*`, `achievements`, shell tabs

---

## 10. Plan d'implémentation

### Phase 1 — ScreenRegistry + ReadinessGate (S57)
1. Créer `lib/services/navigation/screen_registry.dart`
2. Créer `lib/services/navigation/readiness_gate.dart`
3. Enregistrer les 109 surfaces avec `intentTag`, `behavior`, `requiredFields`
4. Tests unitaires : chaque surface a un intent tag unique, readiness testée

### Phase 2 — RoutePlanner + tool Claude (S58)
1. Créer `lib/services/navigation/route_planner.dart`
2. Ajouter le tool `route_to_screen` dans `coach_tools.py` (backend)
3. Connecter dans `coach_chat_screen.dart` via `widget_renderer.dart`
4. Tests end-to-end : message → intent → readiness → route

### Phase 3 — ReturnContract (S58)
1. Créer `lib/models/screen_return.dart`
2. Implémenter le callback retour sur les surfaces B et C Top 10
3. Connecter à `CapMemory.markCompleted/markAbandoned`
4. Tests : completed → confiance monte, abandoned → coach propose alternative

### Phase 4 — Itération (S59+)
1. Affiner les intent tags avec des données réelles
2. Ajouter le retour contract aux surfaces restantes
3. Optimiser la readiness avec le feedback utilisateur

---

## 11. Règles non-négociables

1. **Le LLM décide de l'intention, le code décide du routage.** Le LLM ne retourne jamais un `context.push('/route')` brut.
2. **Chaque surface déclare ses prérequis.** Pas d'écran sans `requiredFields` dans le registre.
3. **Le contrat de retour nourrit CapMemory.** Sans retour, pas de boucle vivante.
4. **Explorer reste autonome.** L'orchestration ne remplace pas la navigation directe depuis les hubs.
5. **Fallback sans LLM.** Si Claude est down, le ScreenRegistry + ReadinessGate fonctionnent seuls.
6. **ZERO hardcoding.** Tous les labels, descriptions et messages passent par i18n (ARB files).
7. **Le chat ne force pas l'ouverture.** Le coach propose, l'utilisateur décide. Pas de `context.push` automatique sans action utilisateur.
