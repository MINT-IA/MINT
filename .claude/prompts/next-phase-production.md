# MINT Next Phase — Production Excellence Sprint

> Ce qui reste entre MINT et le niveau "VZ dans la poche".
> Chaque item est classé par impact utilisateur réel — pas par difficulté technique.
> P0 = sans ça, l'architecture est incomplète. P1 = sans ça, l'UX est incomplète.

---

## ÉTAT DES LIEUX — Ce qui est FAIT (ne pas refaire)

```
FAIT ✅ — Architecture unifiée
  MintUserState + MintStateEngine + MintStateProvider
  BudgetSnapshot inconditionnel dans le state
  CapSequence (3 goals, 23 steps)
  CrossPillarCalculator (6 analyses VZ-grade, 35 tests)
  Goal Selection UI (7 goals, bottom sheet)

FAIT ✅ — Coach agentic
  Agent loop V2 (tool_use → execute → re-call LLM, max 5 iter, 8k token budget)
  13 tools (4 catégories NAVIGATE/READ/WRITE/SEARCH)
  retrieve_memories tool LLM-callable
  4 data lookup tools (budget/retirement/cross-pillar/cap)
  StructuredReasoningService (5 détecteurs déterministes)
  DataDrivenOpenerService (6 types) + PrecomputedInsightsService (batch cache)
  PII whitelist + memory scrub + prompt injection armor

FAIT ✅ — Orchestration
  ScreenRegistry 109 entries
  ReadinessGate 5 custom gates
  ReturnContract V2 + ScreenCompletionTracker (10 screens)
  4 tabs deep-linkables

FAIT ✅ — RAG production
  pgvector HybridSearchService (vector 0.7 + keyword FTS 0.3)
  embed_corpus.py (103 docs, idempotent, $0.001)
  Chaîne 3 niveaux (pgvector → ChromaDB → FaqService)

FAIT ✅ — Voix & UX
  TTS activé (flutter_tts)
  VoiceStateMachine (4 états, 290 tests)
  MintCountUp (révélation 5 temps)
  Swiss-calm micro-animations
  Regional voice (26 cantons), Lifecycle tone (7 phases)
```

---

## CONTEXT — Fichiers critiques à lire

```
# State layer (tout passe par là)
apps/mobile/lib/models/mint_user_state.dart
apps/mobile/lib/services/mint_state_engine.dart
apps/mobile/lib/providers/mint_state_provider.dart

# Coach pipeline (le coeur agentic)
services/backend/app/api/v1/endpoints/coach_chat.py
services/backend/app/services/coach/coach_tools.py
services/backend/app/services/coach/structured_reasoning.py
services/backend/app/services/coach/context_injector_service.dart (Flutter)

# Financial core (ne JAMAIS recalculer hors de là)
apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart
apps/mobile/lib/services/financial_core/financial_core.dart
apps/mobile/lib/services/budget_living_engine.dart
apps/mobile/lib/services/retirement_projection_service.dart

# Screens consumers
apps/mobile/lib/screens/pulse/pulse_screen.dart
apps/mobile/lib/screens/coach/coach_chat_screen.dart
apps/mobile/lib/screens/main_tabs/dossier_tab.dart
apps/mobile/lib/screens/budget/budget_screen.dart

# RAG pipeline
services/backend/app/services/rag/retriever.py
services/backend/app/services/rag/hybrid_search_service.py
services/backend/app/services/rag/orchestrator.py

# Rules (NON-NEGOTIABLE)
CLAUDE.md
rules.md
```

---

## P0-A — ASYNC RETRIEVER FIX (10 minutes, bloque la prod pgvector)

### Problème
`MintRetriever.retrieve()` est sync mais appelle `HybridSearchService.search()` qui est async.
Le bridge actuel utilise `asyncio.get_event_loop()` + `ThreadPoolExecutor` — anti-pattern
qui peut deadlock dans le context async FastAPI.

### Fix
Rendre `MintRetriever.retrieve` async. L'orchestrator l'appelle déjà depuis un context async.

```python
# retriever.py — AVANT
def retrieve(self, query, ...):
    # ugly async bridge with get_event_loop
    ...

# retriever.py — APRÈS
async def retrieve(self, query, ...):
    if self._hybrid:
        try:
            hybrid_results = await self._hybrid.search(query, n_results=n_results)
            if hybrid_results:
                return [...]
        except Exception as exc:
            logger.warning("pgvector failed, falling back: %s", exc)

    # ChromaDB fallback (sync — acceptable, it's local)
    return self._chromadb_retrieve(query, ...)
```

Mettre à jour `RAGOrchestrator.query()` : `retrieved = await self.retriever.retrieve(...)`.

### Tests
- Les 4 pre-existing test failures du retriever doivent être fixés dans la foulée.
- Vérifier que le fallback ChromaDB fonctionne toujours.

---

## P0-B — PROFILE CONTEXT ENRICHI (15 lignes Flutter, débloque les data lookup tools)

### Problème
Les 4 data lookup tools backend (`get_budget_status`, `get_retirement_projection`,
`get_cross_pillar_analysis`, `get_cap_status`) existent et fonctionnent. Mais Flutter
ne sérialise pas les données de `MintUserState` dans le `profile_context` envoyé à l'API.
Résultat : les tools retournent "données non disponibles".

### Fix
Dans `coach_chat_screen.dart`, quand on construit le body API :

```dart
// Dans _sendMessage() ou _buildApiRequest()
final mintState = context.read<MintStateProvider>().state;
final profileContext = {
  // Champs existants (age, canton, etc.)
  ...existingProfileContext,

  // Budget (consommé par get_budget_status)
  'monthly_income': mintState?.budgetSnapshot?.present.monthlyNet,
  'monthly_expenses': mintState?.budgetSnapshot?.present.monthlyCharges,
  'months_liquidity': _computeMonthsLiquidity(mintState),

  // Retraite (consommé par get_retirement_projection)
  'replacement_ratio': mintState?.replacementRate != null
      ? mintState!.replacementRate! / 100.0  // backend attend 0-1, pas 0-100
      : null,
  'monthly_retirement_income': mintState?.budgetGap?.totalRevenusMensuel,
  'lpp_capital': mintState?.profile.prevoyance.avoirLppTotal,
  'avs_rente': mintState?.budgetGap?.avsMensuel != null
      ? mintState!.budgetGap!.avsMensuel * 12  // backend attend annuel
      : null,

  // Cross-pillar (consommé par get_cross_pillar_analysis)
  'annual_3a_contribution': mintState?.profile.total3aMensuel != null
      ? mintState!.profile.total3aMensuel * 12
      : null,
  'lpp_buyback_max': mintState?.profile.prevoyance.lacuneRachatRestante,
  'tax_saving_potential': _estimateTaxSaving(mintState),

  // Cap (consommé par get_cap_status)
  'cap_id': mintState?.currentCap?.id,
  'cap_headline': mintState?.currentCap?.headline,
  'sequence_completed': mintState?.capSequencePlan?.completedCount,
  'sequence_total': mintState?.capSequencePlan?.totalCount,

  // Confidence
  'confidence_score': mintState?.confidenceScore,
  'fri_total': mintState?.friScore,
};
```

### Contraintes
- Tous ces champs sont dans `_PROFILE_SAFE_FIELDS` du backend (vérifier et ajouter si manquants).
- `replacement_ratio` : le backend attend un ratio 0-1 (pas un pourcentage 0-100).
- `avs_rente` : le backend attend un montant annuel.
- Ne PAS envoyer de PII (IBAN, nom complet, employeur, NPA).

### Tests
- Vérifier que chaque champ arrive dans le profile_context du backend.
- Vérifier que les 4 data lookup tools retournent des données non-vides.
- Test avec profil vide → tools retournent "non disponible" gracieusement.

---

## P0-C — BUDGET A/B/GAP VISIBLE SUR PULSE (le "Deux Vies")

### Problème
Le dominant number montre `monthlyFree` (Budget A marge). Mais l'utilisateur ne voit pas :
- Budget B (revenu retraite projeté)
- Le Gap (A - B) comme tension visible
- Les impacts cap (rachat LPP → +X CHF/mois, 3a → +Y CHF/mois)

### Ce qu'il faut
Dans `_buildSecondarySignals()` de `pulse_screen.dart`, ajouter 2 signaux conditionnels :

```dart
// Signal: Budget B (retirement income) — ONLY when stage == fullGapVisible
final snapshot = mintState?.budgetSnapshot;
if (snapshot != null && snapshot.hasFullGap) {
  final retirementNet = snapshot.retirement!.monthlyNet;
  final gap = snapshot.gap!.monthlyGap;
  final replacementRate = snapshot.gap!.replacementRate;

  signals.add(_SecondarySignal(
    icon: Icons.trending_down,
    label: l.pulseRetirementIncome,  // "Revenu retraite estimé"
    value: '${formatChf(retirementNet)} CHF/mois',
    subtitle: l.pulseReplacementRate(replacementRate.round().toString()),
    // "Taux de remplacement : {rate}%"
    color: replacementRate >= 80 ? MintColors.success : MintColors.warning,
  ));
}

// Signal: Top cap impact — ONLY when capImpacts is non-empty
if (snapshot != null && snapshot.capImpacts.isNotEmpty) {
  final topCap = snapshot.capImpacts.first;
  signals.add(_SecondarySignal(
    icon: Icons.lightbulb_outline,
    label: l.pulseCapImpact,  // "Levier identifié"
    value: '+${formatChf(topCap.monthlyDelta)} CHF/mois',
    subtitle: l.pulseCapImpactLabel(topCap.capId),
    // "Rachat LPP" ou "3a max"
    color: MintColors.accentPrimary,
    onTap: () => context.go('/coach/chat?prompt=${topCap.capId}'),
  ));
}
```

### GATE PAR BudgetStage (CRITIQUE)
- `fullGapVisible` → afficher A / B / Gap / impacts cap
- `emergingRetirement` → afficher seulement A + message "enrichis ton profil"
- `presentOnly` → afficher seulement monthlyFree, pas de retraite

Ne JAMAIS afficher un gap retraite quand le profil est vide. C'est le piège UX #1.

### ARB keys (6 langues)
- `pulseRetirementIncome` / `pulseReplacementRate` / `pulseCapImpact` / `pulseCapImpactLabel`

### Tests
- Profile complet → 2 signaux retraite + cap impact visibles
- Profile vide (presentOnly) → aucun signal retraite
- Profile partiel (emergingRetirement) → message enrichissement, pas de gap
- Cap impacts vide → pas de signal levier

---

## P0-D — BUDGET SNAPSHOT DANS LE CONTEXTE CLAUDE

### Problème
Le coach ne sait pas que l'utilisateur a 800 CHF de marge libre ou un gap retraite de 35%.
Le `ContextInjectorService` n'injecte pas le BudgetSnapshot dans le memory block.

### Fix
Dans `context_injector_service.dart`, ajouter un bloc `BUDGET VIVANT` :

```dart
// Après le bloc PLAN EN COURS
if (mintState?.budgetSnapshot != null) {
  final snap = mintState!.budgetSnapshot!;
  final lines = <String>['BUDGET VIVANT :'];
  lines.add('Marge libre : CHF ${snap.present.monthlyFree.round()}/mois');
  lines.add('Charges fixes : CHF ${snap.present.monthlyCharges.round()}/mois');

  if (snap.hasFullGap) {
    lines.add('Revenu retraite estimé : CHF ${snap.retirement!.monthlyNet.round()}/mois');
    lines.add('Taux de remplacement : ${snap.gap!.replacementRate.round()}%');
    lines.add('Écart mensuel : CHF ${snap.gap!.monthlyGap.round()}/mois');
  }
  if (snap.capImpacts.isNotEmpty) {
    for (final cap in snap.capImpacts.take(2)) {
      lines.add('Levier : ${cap.capId} → +CHF ${cap.monthlyDelta.round()}/mois');
    }
  }
  budgetBlock = lines.join('\n');
}
```

Le coach peut alors dire : "Avec CHF 800 de marge libre, un versement 3a de CHF 605/mois
reste tenable — et te fait économiser CHF 1'800 d'impôts par an."

### Tests
- Profile avec budget → memory block contient "BUDGET VIVANT"
- Profile sans budget → pas de bloc budget
- fullGapVisible → contient "Taux de remplacement" et "Écart mensuel"
- Cap impacts → contient "Levier"

---

## P1-A — COUPLE OPTIMIZER (le killer feature — premier au monde)

### Problème
Le `CrossPillarCalculator` analyse un profil individuel. Mais les décisions suisses
sont des décisions de ménage :
- AVS plafonnée à 150% pour les mariés (LAVS art. 35)
- LPP split au divorce
- Rachat optimal : qui rachète en premier ? (celui avec le taux marginal le plus élevé)
- 3a optimal : qui verse en premier ? (même logique fiscale)
- Fiscalité commune vs séparée selon le canton

### Ce qu'il faut
Un service `CoupleOptimizer` dans `financial_core/` :

```dart
class CoupleOptimizer {
  CoupleOptimizer._();

  /// Compare 2 scénarios : "Julien d'abord" vs "Lauren d'abord"
  /// pour le rachat LPP et le versement 3a.
  ///
  /// Retourne le scénario optimal en termes d'économie fiscale COUPLE.
  static CoupleOptimizationResult optimize({
    required CoachProfile mainUser,
    required ConjointProfile conjoint,
  }) { ... }
}
```

### Analyses à implémenter

1. **Qui rachète son LPP en premier ?**
   - Calcul : `estimateTaxSaving(income_A, rachat_A, canton)` vs `estimateTaxSaving(income_B, rachat_B, canton)`
   - Celui dont le taux marginal est le plus élevé rachète d'abord (plus grande économie par CHF investi)
   - Sortie : `{winner: 'conjoint', saving_delta: 2400, reason: 'taux marginal supérieur'}`

2. **Qui verse son 3a en premier ?**
   - Même logique : le taux marginal le plus élevé en premier
   - FATCA : si le conjoint est US → il ne peut PAS verser de 3a (canContribute3a = false)
   - Sortie : `{winner: 'main_user', saving_delta: 600}`

3. **AVS couple plafonné** (LAVS art. 35)
   - Rentes individuelles × 2 > 150% rente max → plafonnement
   - Montrer le delta entre "2 × individuel" et "plafonné"
   - Sortie : `{cap_applied: true, monthly_reduction: 380}`

4. **Fiscalité commune optimal**
   - Certains cantons sont plus avantageux pour les couples (quotient familial)
   - Comparer : impôt couple actuel vs 2 × impôt individuel (comme si séparés)
   - Sortie : `{marriage_penalty: true|false, annual_delta: -1200|+800}`

### Contraintes
- Utilise `RetirementTaxCalculator.estimateTaxSaving()` pour TOUS les calculs fiscaux
- Utilise `AvsCalculator.computeCouple()` pour le plafonnement AVS
- FATCA-aware : `conjoint.canContribute3a` vérifié
- Chaque résultat a un `tradeOff` (LSFin — jamais présenter comme optimal)
- Golden couple : Julien + Lauren testé

### Tests (minimum 15)
- Julien + Lauren : LPP rachat optimal = Julien (taux marginal VS supérieur)
- Lauren FATCA : 3a optimal = Julien seul (Lauren bloquée)
- AVS couple plafonné à 150% pour revenus élevés
- AVS couple non plafonné pour revenus modestes
- Marriage penalty test : GE (penalty connue) vs VD (bonus connu)
- Conjoint null → retour vide gracieux
- Même revenu → pas de préférence d'ordre (delta = 0)

---

## P1-B — STT (Speech-to-Text) — Compléter la voice loop

### Problème
TTS activé. STT = stub. La voice loop (image 3 Cleo) est à moitié.

### Ce qu'il faut
1. Ajouter `speech_to_text: ^7.0.0` au pubspec.yaml
2. `PlatformVoiceBackend.isSttAvailable()` → probe le channel speech_to_text
3. `PlatformVoiceBackend.listen()` → démarre l'écoute, retourne le texte transcrit
4. `VoiceInputButton` existe déjà — wirer avec le vrai backend
5. Dans `coach_chat_screen.dart` : bouton micro → écoute → texte dans le champ → envoi

### Contraintes
- Locale : `fr-CH` par défaut, `de-CH` / `it-CH` selon la locale de l'app
- Le micro doit avoir un indicateur visuel (pulsation calme, pas agressive)
- Timeout : 30 secondes max d'écoute
- Pas de streaming du transcript — attend la fin, affiche le texte, l'utilisateur confirme
- Permission micro : demandée au premier tap, pas au lancement

### Tests
- STT button visible quand available
- STT button caché quand non available
- Tap → VoiceService.listen called
- Résultat → texte inséré dans le champ
- Timeout → arrêt gracieux
- Permission refusée → message d'erreur friendly

---

## P1-C — RETOUR CONTRACT V3 — Screens qui émettent pour de vrai

### Problème
10 screens appellent `ScreenCompletionTracker.markCompleted()` mais aucun ne produit
un vrai `ScreenReturn` avec `updatedFields` et `confidenceDelta`. Le tracker est un
proxy temporel — pas un contrat réel.

### Ce qu'il faut
Pour les 5 screens les plus critiques, émettre un `ScreenReturn` réel :

1. **rente_vs_capital_screen** : `changedInputs` avec le mode choisi (rente/capital/mixte)
2. **simulator_3a_screen** : `completed` avec le montant simulé
3. **rachat_echelonne_screen** : `completed` avec le montant échelonné choisi
4. **budget_screen** : `changedInputs` avec les charges modifiées
5. **affordability_screen** : `completed` avec le prix max accessible

Chaque screen doit :
- Appeler `ScreenReturn.completed(route: '/xxx', updatedFields: {...}, confidenceDelta: 0.05)`
- Le `confidenceDelta` dépend de ce que l'utilisateur a fait (simuler = +0.02, scanner = +0.10)
- Les `updatedFields` alimentent le profil via `CoachProfileProvider.mergeAnswers()`

---

## P2 — DOSSIER ACTIF (miroir → outil)

### Problème
Le Dossier affiche les données mais ne permet pas de les corriger.
"LPP : CHF 70'377" devrait avoir un bouton "Corriger" → data-block en édition.

### Ce qu'il faut
- Chaque donnée affichée dans `_DataSection` a un `onTap` vers le data-block correspondant
- Un bouton "Scanner mon certificat LPP" quand `avoirLppTotal == null`
- Un bouton "Ajouter mon conjoint" quand `conjoint == null`
- Après modification → `forceRecompute()` pour mettre à jour MintUserState

---

## EXECUTION RULES

- Lire TOUS les fichiers référencés AVANT d'écrire du code
- `flutter analyze` = 0 issues après chaque commit
- `flutter test` + `pytest` green
- Minimum tests spécifiés par feature
- ALL user-facing strings dans les 6 ARB files
- JAMAIS de calcul financier hors `financial_core/`
- JAMAIS de PII dans les logs, le context, ou les embeddings
- `git add` fichiers spécifiques, jamais `git add .`
- Commits conventionnels : `feat:`, `fix:`, `refactor:`

## PRIORITY ORDER

```
P0-A  Async retriever     → 10 min, bloque pgvector prod
P0-B  Profile context     → 15 lignes, débloque 4 tools
P0-C  Budget A/B/Gap      → Pulse montre enfin "Deux Vies"
P0-D  Budget dans Claude  → Coach raisonne sur les vrais chiffres
P1-A  CoupleOptimizer     → Premier au monde, killer feature
P1-B  STT                 → Voice loop complète
P1-C  ReturnContract V3   → Boucle coach → écran → retour fermée
P2    Dossier actif       → Miroir → outil de correction
```
