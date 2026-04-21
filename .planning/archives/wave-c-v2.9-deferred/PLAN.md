# Wave C PLAN — Scan handoff coach + suggestion chips life events

Base dev : f35ec8ff (post Wave E-PRIME merge)
Branche : `feature/wave-c-scan-handoff-coach`
Estimation : 4-6h, 5 commits atomiques + 1 PR

## Goal

Transformer le scan d'un acte isolé à un point d'entrée vers conversation
contextuelle. Étendre le regex suggestion-chip pour couvrir les 18 life events.
Robustifier la memory injection. Permettre le skip landing post-onboarding.
Décider du minimal onboarding.

Pas de feature nouvelle — câbler ce qui existe déjà.

## Commits cibles (dépendances & scope)

### C1 — Post-scan auto-handoff coach (1h30-2h, central)

**État actuel** (code existant) :
- `document_impact_screen.dart` récupère `ExtractionResult` post-scan
- Wave A A1 : appelle `CoachMemoryService.saveEvent()` pour persist l'event localement
- CTA bas d'écran : "Continuer" → retour generalist (landing ou home)

**Wave C modif** :
- `document_impact_screen.dart` bottom CTA : remplacer "Continuer" par
  "En parler à Mint" (ou équivalent anti-cliché, ARB key à créer)
- Tap → `context.go('/coach/chat', extra: CoachEntryPayload(source: scanResult, topic: 'scan_<doc_type>'))`
- `coach_chat_screen.dart:_consumeCapCoachBridge` ou équivalent consume l'entry payload
- Entry payload → injecte contexte système prompt : "On a lu ton certificat CPE. Voici ce que ça change pour toi."
- Opener contextuel remplace silent opener générique si entry_payload présent

**Fichiers touchés** :
- `lib/screens/document_scan/document_impact_screen.dart` (CTA + navigation)
- `lib/screens/coach/coach_chat_screen.dart` (entry payload consume)
- `lib/models/coach_entry_payload.dart` (ajouter source `scanResult` enum)
- `lib/l10n/*.arb` (6 langs — clé CTA + opener template)

**Risques** :
- Collision avec CapCoachBridge existant (même mécanisme)
- Opener contextuel doit respecter doctrine silent (pas intrusif)
- Si scan fournit données ambiguës, opener ne doit pas affirmer ce que MINT n'a pas compris

### C2 — Suggestion-chip regex étendu 18 life events (1h, isolé)

**État actuel** : `coach_chat_screen._extractRouteChips(richCalls)` utilise un
regex limité qui matche quelques intents explicites (check RoutePlanner chips
déjà supportés).

**Wave C modif** :
- Identifier le fichier qui héberge `_extractRouteChips` ou equivalent
- Étendre la regex/mapping pour tous les 18 life events (naissance, divorce, mariage, emploi, perte emploi, retraite, donation, déménagement canton, déménagement pays, invalidité, indépendant, EPL, décès proche, concubinage, first job, new job, housing sale, inheritance)
- Chaque life event → intent tag qui matche `ROUTE_TO_SCREEN_INTENT_TAGS` (coach_tools.py)
- Attention : Panel B a identifié 7 intent tags orphelins — Wave E main les règle. Wave C **n'ajoute pas de nouveaux** intents orphelins.

**Fichiers touchés** :
- `lib/screens/coach/coach_chat_screen.dart` ou `lib/services/coach/chat_tool_dispatcher.dart`
- Tests : `test/services/coach/` si existants pour ce dispatcher

### C3 — Memory retry back-off (30min, robustesse)

**État actuel** : `CoachMemoryService.fetchMemoryBlock()` (ou nom similaire) a
un timeout 2s puis fallback silencieux.

**Wave C modif** :
- Ajouter retry 1× avec back-off 500ms entre timeout initial et fallback
- Log (debugPrint) retry attempt pour debug device
- Pas de user-facing UI sur retry (silent par nature)

**Fichiers touchés** :
- `lib/services/memory/coach_memory_service.dart` ou équivalent
- Test : ajouter test unitaire retry logic

### C4 — Landing skip si onboarded (30min, UX)

**État actuel** : `app.dart` router `initialLocation: '/landing'` fixe. Un
user post-onboarding qui relance l'app voit landing re-wordmarked.

**Wave C modif** :
- Router lit `CoachProfileProvider.isOnboarded` (ou équivalent — vérifier
  exact nom du flag). Si true → `initialLocation: '/home'`
- Redirect GoRouter si user tape `/landing` alors que onboarded → `/home`

**Fichiers touchés** :
- `lib/app.dart` (router config)
- Test : au moins un widget test cold-start-with-profile

### C5 — Onboarding minimal questionnaire OR ADR (décision)

Du ROADMAP : "Onboarding questionnaire minimal 3 inputs (age, canton, revenu) avant landing CTA OU ADR si confirme no-onboarding"

**Approche proposée** : ADR no-onboarding.

Raisonnement :
- Doctrine lucidité (2026-04-12) + chat-silent doctrine : l'onboarding
  traditionnel (formulaire) est anti-doctrine. MINT doit extraire les facts
  via conversation + scan, pas par questionnaire imposé
- Wave A A2 triad gate (birthYear + canton + salary) fonctionne déjà via
  save_fact dans le chat
- Forcer 3 inputs avant landing CTA ajouterait friction + redondance

**Livrable C5** : `decisions/ADR-20260419-no-formal-onboarding.md`
documentant la décision :
- Pourquoi : doctrine lucidité + chat-silent + triad via save_fact
- How : landing → coach chat → save_fact silent capture → triad complète
  → `isOnboarded` flip
- Alternatives rejetées : 3-input questionnaire (friction), wizard (inverse
  doctrine), progressive disclosure (déjà fait via chat)

**Fichiers touchés** : 1 ADR markdown

## Hors scope (déférés)

- 7 intent tags orphelins route_to_screen (Panel B — Wave E main)
- Alignment `life_event_unemployment` backend vs `life_event_job_loss` Flutter (Wave E main)
- Commentaire menteur `coach_profile_provider.dart:183` (Wave E main)

## Gates de sortie Wave C

- [ ] flutter analyze : 0 errors, baseline issues pre-existing
- [ ] flutter test : toucher tests ne fait baisser pass count que par suppression explicite
- [ ] ARB 6 langs parity maintenue
- [ ] Tests ajoutés pour C1, C2, C3 (pas C4 C5 si ADR seul)
- [ ] Device walkthrough iPhone 17 Pro : scan → tap "En parler à Mint" →
      coach opener contextuel rendu + life event chip visible si coach
      mentionne un life event
- [ ] ADR C5 écrit et référencé dans PROJECT structure

## Risques & mitigations

| Risque | Impact | Mitigation |
|---|---|---|
| Collision C1 avec CapCoachBridge | entry_payload consommé 2x | Unifier les 2 mécanismes en 1 path (CapCoachBridge existant) |
| Opener contextuel trop agressif | Anti-silent doctrine | Garder ton conditionnel ("On a lu X, tu veux en parler ?") + opt-out visible |
| C2 regex casse parsing existant | Chips disparaissent | Parser tests exhaustifs + regex anchored (pas greedy) |
| C3 retry masque bug réseau profond | Observabilité baisse | Log debugPrint + Sentry breadcrumb sur retry |
| C4 router condition race au cold-start | Flash landing puis home | Router redirect depuis `async` provider init — tester un cold-start avec SharedPreferences mock |
| C5 ADR contesté par contrarien | Blocage Wave | Panel review PLAN identifie alternatives + doc les tradeoffs |

## Ordre d'exécution

1. C5 d'abord (ADR only, décision upstream)
2. C2 (isolé, pas de dépendance)
3. C3 (isolé)
4. C1 (dépend de clarté sur entry_payload mechanism — check CapCoachBridge)
5. C4 (dépend de confirmer isOnboarded flag)

Chaque commit atomique. Total 5 commits + 1 PR.
