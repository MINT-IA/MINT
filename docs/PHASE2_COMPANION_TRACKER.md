# Phase 2 "Le Compagnon" — Readiness Tracker

> MINT s'adapte à ta vie. Il se souvient et évolue.
> Check at every sprint planning.
> Last updated: 2026-03-22

---

## P3.1 — RAG Conversationnel (embed insights for semantic recall)

### What exists
- `CoachInsight` model with topic, summary, type, metadata
- `CoachMemoryService.getInsights()` returns persisted insights
- `save_insight` tool lets the LLM save decisions/goals/concerns
- pgvector HybridSearchService operational (P3-A done)
- `retrieve_memories` tool searches memory_block by substring

### What's needed
- Embed insights into pgvector (alongside education docs)
- `retrieve_memories` V2: search pgvector instead of substring match
- When LLM calls `retrieve_memories(topic="retraite")`, return the 3 most
  semantically similar insights + education docs

### Day-J checklist
```
[ ] Extend embed_corpus.py to embed CoachInsight entries (doc_type: "memory")
[ ] Add insight embedding on save_insight execution (real-time)
[ ] Update retrieve_memories handler to query pgvector
[ ] Keep substring fallback for dev/CI without pgvector
[ ] Tests: save → embed → retrieve roundtrip
```

---

## P3.2 — DecisionLog Structuré

### What exists
- `InsightType.decision` in CoachInsight model
- `metadata: Map<String, dynamic>?` can store structured data
- `save_insight` tool has `topic`, `summary`, `type` fields

### What's needed
- Enrich `save_insight` tool description to prompt the LLM to include:
  - `status`: "pending" | "confirmed" | "changed"
  - `impact_chf`: estimated annual CHF impact
  - `alternatives`: what other options were considered
- Coach context shows decisions with status in the memory block

### Day-J checklist
```
[ ] Update save_insight tool description to include structured metadata guidance
[ ] Update ContextInjectorService to show decisions distinctly (topic, date, status)
[ ] Tests: save decision → recall with metadata → coach references it
```

---

## P3.3 — "Ce qui a changé" (delta visible au retour)

### What exists
- MintUserState with `computedAt` timestamp
- CapEngine recalculates on every state change
- Confidence score tracked per session

### What's needed
- `MintStateSnapshot` — persist previous state on app background
- On resume: diff current vs previous → highlight changes
- In Pulse: "Depuis ta dernière visite: confiance +5%, marge +200 CHF"
- In Coach context: "CE QUI A CHANGÉ" block

### Day-J checklist
```
[ ] Create MintStateSnapshot model (key metrics only: confidence, monthlyFree, replacementRate, capId)
[ ] Persist snapshot on AppLifecycleState.paused
[ ] On resume: compute diff
[ ] Add "Ce qui a changé" section in Pulse (below hero, above signals)
[ ] Add "CE QUI A CHANGÉ" block in ContextInjectorService
[ ] Tests: persist → diff → display
```

---

## P3.4 — Weekly Recap AI

### What exists
- `WeeklyRecapService` (service layer complete)
- `WeeklyRecapScreen` at `/coach/weekly-recap`
- Coach memory with recent insights

### What's needed
- Wire WeeklyRecapService to generate content via LLM (not template)
- Schedule: Monday morning notification → "Ta semaine MINT"
- Content: actions taken, confidence delta, next recommended action
- Fallback: template-based when no BYOK/server key available

### Day-J checklist
```
[ ] Wire WeeklyRecapService.generate() to use LLM via backend endpoint
[ ] Create /api/v1/coach/weekly-recap endpoint (uses server API key)
[ ] Schedule Monday notification via flutter_local_notifications
[ ] Template fallback for no-LLM environments
[ ] Tests: generate → display → notification
```

---

## P3.5 — Coaching Adaptatif (fréquence pilotée par l'utilisateur)

### Concept
Au lieu de décider la fréquence des triggers pour l'utilisateur (cooldown 1/jour hardcodé),
MINT apprend à quel rythme chaque personne veut être accompagnée.

### Feedback implicite (pas de friction)
- Utilisateur **ignore** un greeting proactif → baisser la fréquence de ce trigger type
- Utilisateur **engage** (répond, clique) → maintenir/augmenter
- Utilisateur **dismiss** un recall mémoire → réduire les références passées
- Utilisateur **réagit positivement** → renforcer le recall

### Feedback explicite (léger)
- 👍/👎 discret après un proactive greeting (pas une popup)
- Slider dans les réglages : "Fréquence des rappels" (Discret → Proactif)

### Architecture cible
```dart
class CoachingPreference {
  final int intensity; // 1=discret, 3=équilibré (défaut), 5=proactif
  final Map<String, double> triggerEngagement; // score 0-1 par trigger type
}
```
- `intensity` module le cooldown ProactiveTriggerService (1→7j, 3→1j, 5→0j)
- `triggerEngagement` filtre les triggers bas-engagement même en mode proactif
- CapMemory.recentFrictionContext + NudgePersistence.getDismissedIds = déjà tracké

### Prérequis
- 100+ testeurs avec données d'engagement réelles (dismiss rate, response rate)
- Calibrer les seuils avant d'automatiser

### Day-J checklist
```
[ ] Ajouter CoachingPreference au profil (intensity + triggerEngagement)
[ ] ProactiveTriggerService lit intensity pour le cooldown
[ ] ContextInjectorService module le recall depth selon intensity
[ ] Tracker les engagements implicites (greeting ignored vs responded)
[ ] UI réglages: slider "Fréquence des rappels"
[ ] Tests: intensity 1→5 change le comportement du coach
```

---

## P4 — Phase 3 "L'Expert" Readiness

### Expert Tier
- Marketplace de spécialistes (planificateur, fiscaliste, notaire)
- AI pré-remplit le dossier → spécialiste productif dès minute 1
- Add-on 129 CHF/session
- **Prep done**: DossierPreparationService exists (S65)

### Multi-LLM Failover
- `MultiLlmService` exists (Claude primary + GPT-4o fallback)
- **Prep done**: domain field on ReasoningOutput, monitoring active
- **Day-J**: verify failover in production, add health check endpoint

### Agent Autonome Read-Only
- Form pre-fill (déclaration fiscale)
- Letter generation (caisse de pension)
- All read-only (never executes)
- **Not started**: requires agent framework extension

### B2B White-Label
- Distribution via employeurs/caisses de pension
- 5-15 CHF/employé/an
- **Not started**: requires multi-tenant architecture
