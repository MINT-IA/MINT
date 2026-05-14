# MINT — Architecture cible

> **Contexte.** L'app fonctionne (50+ routes, 100+ services, parcours réels). Le problème n'est pas qu'il manque des briques — c'est que **trois axes d'orchestration coexistent sans hiérarchie claire** :
> - le **chat coach** (`CoachOrchestrator` + `ChatToolDispatcher`)
> - le **routing par intent** (`RoutePlanner` + `ScreenRegistry` + `ReadinessGate`)
> - les **séquences guidées** (`SequenceCoordinator` + `SequenceTemplate`)
>
> Plus un **agent autonome** (`AutonomousAgentService`) qui produit des artefacts (lettres, pré-remplissages) en parallèle.
>
> Ce document n'introduit pas de nouveaux concepts. Il **cale les rôles** des briques existantes et propose un contrat unique entre elles.

---

## 1. Les 3 couches

```
┌──────────────────────────────────────────────────────────────┐
│  COUCHE 1 — UI / SURFACES                                    │
│  • 4 onglets : Aujourd'hui • Mon argent • Coach • Explorer  │
│  • ~50 écrans (simulateurs, parcours, hubs)                  │
│  • CoachChatScreen = point d'entrée conversationnel          │
└──────────────────────────┬───────────────────────────────────┘
                           │ user input (texte / chip / CTA)
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  COUCHE 2 — ORCHESTRATEUR CONVERSATIONNEL                    │
│  Le LLM décide l'intention. Le code décide le routage.       │
│                                                              │
│  CoachOrchestrator                                           │
│   ├─ génère la réponse (SLM → BYOK → Fallback)              │
│   ├─ ChatToolDispatcher : exécute les tool-calls             │
│   └─ délègue le routage à RoutePlanner                       │
│                                                              │
│  RoutePlanner.plan(intentTag, confidence) → RouteDecision   │
│   ├─ openScreen        (data complète)                       │
│   ├─ openWithWarning   (data partielle, mode estimation)     │
│   ├─ askFirst          (champs critiques manquants)          │
│   └─ conversationOnly  (réponse inline)                      │
│                                                              │
│  SequenceCoordinator.decide(template, run, return)           │
│   pour les parcours multi-écrans (retraite, hypothèque…)    │
└─────┬────────────────────────────┬───────────────────────────┘
      │ route + prefill            │ artefact request
      ▼                            ▼
┌─────────────────────┐  ┌─────────────────────────────────────┐
│  COUCHE 3 —         │  │  COUCHE 3 — AGENT AUTONOME          │
│  MODULES MÉTIER     │  │                                     │
│                     │  │  AutonomousAgentService             │
│  • simulateurs      │  │   • génère lettres / pré-remplis    │
│  • calculateurs     │  │   • SafetyGate (11 règles)          │
│  • parcours         │  │   • requiresValidation === true     │
│  • document scan    │  │   • audit log immuable              │
│  Données : Coach-   │  │  Données : CoachProfile             │
│  Profile, Provi-    │  │                                     │
│  ders, services     │  │                                     │
└─────────────────────┘  └─────────────────────────────────────┘
```

---

## 2. Cartographie réelle → 3 couches

### Couche 1 — UI

| Brique existante | Rôle |
|---|---|
| `app.dart` (router GoRouter) | 50+ routes canoniques + redirections legacy |
| `MintShell` (StatefulShellRoute) | 4 onglets persistants |
| `CoachChatScreen` | Surface conversationnelle (Tab 2) |
| `ScopedGoRoute` + `RouteScope` | Garde auth (public / onboarding / authenticated) |

### Couche 2 — Orchestration

| Brique existante | Rôle | Statut |
|---|---|---|
| `CoachOrchestrator` | LLM tier-chain (SLM → BYOK → Fallback) + ComplianceGuard | ✅ en place |
| `ChatToolDispatcher` | Exécute les tool-calls du LLM | ✅ en place |
| `IntentRouter` | Mapping chip ARB → `goalIntentTag` + `suggestedRoute` | ✅ en place |
| `RoutePlanner` | Décide `openScreen` / `openWithWarning` / `askFirst` / `conversationOnly` | ✅ en place |
| `ScreenRegistry` | Source de vérité : route × intentTag × `ScreenBehavior` × `requiredFields` | ✅ en place |
| `ReadinessGate` | Vérifie les `requiredFields` du `CoachProfile` | ✅ en place |
| `SequenceCoordinator` | Décide étape suivante (`AdvanceAction` / `PauseAction` / `RetryAction`…) | ✅ en place |
| `SequenceTemplate` | Définition statique des parcours multi-écrans | ✅ en place |

### Couche 3 — Modules

| Brique existante | Rôle |
|---|---|
| `services/simulators/*` | Simulateurs (3a, LPP buyback, real interest…) |
| `services/financial_core/*`, `pillar_3a_*`, `lpp_deep_*`, `mortgage_service` | Moteurs métier |
| `services/factory/letter_generator_service` | Génération de lettres formelles |
| `AutonomousAgentService` | Pré-remplissages + lettres + dossier fiscal |
| `services/document_*`, `document_parser/*` | Pipeline scan → extraction → revue |
| `CoachProfile` (modèle) | État utilisateur unique, source des `dataSources` |

---

## 3. Le contrat central — `ScreenEntry`

C'est **la pièce qui tient l'architecture**. Chaque écran routable depuis le chat est déclaré dans `ScreenRegistry` avec :

```dart
ScreenEntry(
  route: '/rente-vs-capital',          // GoRouter
  intentTag: 'retirement_choice',       // sémantique LLM
  behavior: ScreenBehavior.decisionCanvas,
  requiredFields: ['age', 'canton', 'avoirLpp'],
  optionalFields: ['tauxConversion'],
  fallbackRoute: '/scan?type=lpp',
  preferFromChat: true,
  prefillFromProfile: true,
  customGate: ...,                      // optionnel, archétypes
)
```

### Les 5 `ScreenBehavior`

| Code | Nom | Exemple | Action coach |
|---|---|---|---|
| **A** | Direct Answer | « Plafond 3a 2026 ? » | Réponse inline, pas d'écran |
| **B** | Decision Canvas | Rente vs Capital | `openScreen` avec readiness check |
| **C** | Roadmap Flow | Mariage, Naissance, Divorce | Parcours via `SequenceCoordinator` |
| **D** | Capture / Utility | Scan AVS, complétion profil | `openScreen` fonctionnel |
| **E** | Conversation pure | Échange ouvert, exploration | `conversationOnly` |

> **Règle non-négociable.** Le LLM ne renvoie **jamais** un `context.push('/route')`. Il renvoie un `intentTag` + `confidence`. C'est le code (`RoutePlanner` + `ScreenRegistry` + `ReadinessGate`) qui matérialise la navigation.

---

## 4. La machine d'état — un seul flow

```
                ┌──────────────────────┐
                │  user message / CTA  │
                └──────────┬───────────┘
                           ▼
              ┌────────────────────────┐
              │  CoachOrchestrator     │
              │  .generateChat(...)    │
              │                        │
              │  SLM ──► BYOK ──► Tpl  │
              │  + ComplianceGuard     │
              └──────────┬─────────────┘
                         │ tool_call(intent, args)?
                ┌────────┴────────┐
              non                oui
                │                  │
                ▼                  ▼
    ┌───────────────────┐  ┌──────────────────────────┐
    │ texte inline +    │  │ ChatToolDispatcher       │
    │ widgets           │  │  .dispatch(toolCall)     │
    └───────────────────┘  └──────────┬───────────────┘
                                      │
                              ┌───────┴────────┐
                              ▼                ▼
                  ┌────────────────────┐  ┌──────────────────────┐
                  │ RoutePlanner.plan  │  │ AutonomousAgent      │
                  │ (intentTag, conf)  │  │  .generateTask(...)  │
                  └────────┬───────────┘  └──────────┬───────────┘
                           │                         │
              ┌────────────┼────────────┐            ▼
              ▼            ▼            ▼     ┌─────────────────┐
        openScreen   openWithWarning  askFirst│ SafetyGate      │
        / conversa-  (mode estim.)    (1-2 q.)│ (11 règles)     │
        tionOnly                              └────────┬────────┘
              │            │                           │
              ▼            ▼                           ▼
        ┌─────────────────────────┐         ┌───────────────────┐
        │  Module métier (couche  │         │  pendingValidation│
        │  3) : simulateur, par-  │         │  → user review    │
        │  cours, scan, ...       │         │  → audit log      │
        └────────┬────────────────┘         └───────────────────┘
                 │ ScreenReturn
                 ▼
        ┌─────────────────────────┐
        │ SequenceCoordinator si  │
        │ parcours multi-écrans : │
        │  Advance / Pause /      │
        │  Retry / Skip / ReEval  │
        └─────────────────────────┘
```

**Points clés :**
1. **Une seule entrée** dans la couche 2 : `CoachOrchestrator.generateChat`.
2. **Aucun écran ne pousse un autre écran via le chat** sans passer par `RoutePlanner`.
3. **Aucune action autonome** ne sort sans `SafetyGate` + `requiresValidation`.
4. **Aucun parcours multi-écrans** sans `SequenceCoordinator` (sinon les utilisateurs perdent le fil).

---

## 5. Delta vs l'état actuel

Ce qui existe et fonctionne — **ne pas refaire** :
- ✅ Routing canonique avec `ScopedGoRoute` + scopes auth
- ✅ Tier-chain SLM/BYOK/Fallback dans `CoachOrchestrator`
- ✅ `ScreenRegistry` + `RoutePlanner` + `ReadinessGate` (le triptyque est là)
- ✅ `SequenceCoordinator` avec actions sealed
- ✅ `AutonomousAgentService` avec `SafetyGate` (11 règles, audit log)
- ✅ Compliance centralisée (LSFin, LPD, FINMA)

Ce qui reste à serrer :

| # | Sujet | Action |
|---|---|---|
| 1 | **Audit du `ScreenRegistry`** | Vérifier que les 50 routes de `app.dart` ont chacune un `ScreenEntry` (ou sont explicitement non-routables depuis le chat). |
| 2 | **`preferFromChat` exhaustif** | Toute route avec `preferFromChat: true` doit avoir un `intentTag` connu de `IntentResolver` côté LLM. |
| 3 | **Intent ↔ chip ARB** | `IntentRouter` (9 chips) ne couvre que l'onboarding. Étendre pour que tout intent du LLM ait une `IntentMapping`. |
| 4 | **Sequences existantes** | Lister les parcours qui n'utilisent pas encore `SequenceCoordinator` (ex. retraite step-by-step) et les migrer. |
| 5 | **Tool-calls catalogue** | Documenter dans un seul endroit la liste des tool-calls du LLM et leur cible (RoutePlanner / AutonomousAgent / inline widget). |
| 6 | **`ScreenReturn` uniformisé** | Tous les écrans de parcours doivent retourner un `ScreenReturn` (completed / abandoned / changedInputs) — pas de `Navigator.pop` nu. |
| 7 | **Tests d'orchestration** | Test unitaire par `ScreenBehavior` × par état du `CoachProfile` → `RouteDecision` attendue. |

---

## 6. Plan de migration (par vagues)

### Vague A — Audit & cartographie (1 sprint)
- Cartographier les 50 routes : `intentTag` ? `behavior` ? `requiredFields` ?
- Compléter `ScreenRegistry` jusqu'à 100 % de couverture.
- Test : `every route in app.dart has matching ScreenEntry OR explicit exclusion`.

### Vague B — Fermer les portes latérales (1 sprint)
- Tout `context.push` issu d'un écran chat doit passer par `RoutePlanner.plan`.
- Tout retour d'écran de parcours doit produire un `ScreenReturn`.
- Lint custom : interdire `context.push` dans `services/coach/*`.

### Vague C — Sequences (1-2 sprints)
- Pour chaque parcours multi-écrans (retraite, hypothèque, mariage, divorce, premier emploi) :
  - Définir `SequenceTemplate`.
  - Brancher `SequenceCoordinator` dans le shell de parcours.
  - Mesurer : taux d'abandon par étape.

### Vague D — Agent autonome élargi (1 sprint)
- Ajouter les types manquants à `AgentTaskType` (demande EPL, attestation 3a…).
- Tableau de bord « Mes documents générés » dans Tab 1.
- Audit log exposé en debug screen.

### Vague E — Observabilité (continu)
- Métrique par `RouteDecision.action` (combien d'`askFirst` ? combien d'`openWithWarning` ?).
- Métrique par tier `CoachOrchestrator` (SLM hit rate vs BYOK vs fallback).
- Sentry breadcrumbs pour chaque transition de `SequenceRun`.

---

## 7. Invariants à protéger

1. **Le LLM ne décide pas de la navigation.** Il propose un intent. Le code décide.
2. **Aucun écran ne s'ouvre sans `ReadinessGate`.** Si `requiredFields` manquent : `askFirst` ou `openWithWarning`.
3. **Aucun artefact agent ne sort sans `SafetyGate`.** 11 règles, validation user obligatoire, audit log.
4. **Une seule source de vérité par couche** : `ScreenRegistry` (couche 2), `CoachProfile` (couche 3 état), `app.dart` (couche 1 routing).
5. **Compliance centralisée.** Toutes les sorties LLM passent par `ComplianceGuard` (LSFin art. 3/8).
6. **Privacy-first.** Tier 1 = SLM on-device (LPD art. 6). Tier cloud nécessite opt-in BYOK.

---

## 8. Glossaire (briques existantes)

- **`CoachProfile`** — modèle de l'utilisateur (revenus, prévoyance, canton, état civil…).
- **`CoachContext`** — snapshot enrichi passé aux prompts.
- **`ScreenEntry`** — déclaration d'une surface routable (`ScreenRegistry`).
- **`RouteDecision`** — résultat de `RoutePlanner.plan` (action + route + missingFields + prefill).
- **`ScreenReturn`** — résultat d'un écran de parcours (`completed` / `abandoned` / `changedInputs`).
- **`SequenceRun`** — état runtime d'une instance de parcours.
- **`SequenceTemplate`** — définition statique d'un parcours.
- **`SequenceAction`** — décision du coordinator (`AdvanceAction` / `PauseAction` / `RetryAction` / `SkipAction` / `ReEvaluateAction`).
- **`AgentTask`** — artefact généré par l'agent (lettre, pré-remplissage), toujours `pendingValidation`.
- **`SafetyResult`** — sortie de `AgentSafetyGate.validate` (passed + violations).

---

*Doc à lire en complément de `HANDOFF.md` (qui décrit le périmètre Flutter et les services métier).*
