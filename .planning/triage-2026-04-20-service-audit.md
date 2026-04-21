# Audit câblage services — 2026-04-21

**Contexte:** Julien a challengé ma phrase « architecture en place (RegulatorySyncService, StreakService, ReportPersistenceService, snapshots) ». Audit systématique : chaque service est-il câblé end-to-end, ou façade-sans-câblage ?

Méthode: `grep -rn ServiceName` + vérification caller pour chaque. Façade = classe existe mais aucun consommateur externe.

---

## Résumé exécutif

| Service | Status | Verdict |
|---|---|---|
| RegulatorySyncService | ✅ Câblé | `main.dart` startup + `reg()` dans financial_core |
| StreakService | ✅ Câblé | CoachNarrativeService consomme |
| SnapshotService | ✅ Câblé | main.dart startup + updateProfile + MintStateEngine |
| ReportPersistenceService | ✅ Câblé | 56 usages, pierre angulaire persistence |
| ConfidenceScorer | ✅ Câblé | extraction_review + retirement_dashboard |
| FriComputationService | ✅ Câblé | mint_state_engine + coach_narrative |
| ComplianceGuard | ✅ Câblé | coach_chat_screen validate + sanitize |
| FeatureFlags | ✅ Câblé | slm_provider + main_web |
| Sentry / SentryNavigatorObserver | ✅ Câblé | main.dart init + app.dart observer |
| BiographyProvider | ✅ Câblé | extraction_review + privacy_control |
| SessionSnapshotService | ✅ Câblé | mint_state_engine load + computeDelta |
| **CoachCacheService (get/set)** | ⚠️ **Façade** | Classe + `invalidate()` câblé, mais `get()` et `set()` JAMAIS appelés |
| **MilestoneService** | ⚠️ **N'existe pas** | Seulement modèle `PlanMilestone` + strings l10n — pas de service |
| **AnnualRefresh trigger** | ⚠️ **Déclenche jamais** | `snapshot_service.dart:193` check `trigger == 'annual_refresh'` mais aucun caller passe cette string. Écran annual_refresh DELETED en deep-audit 2026-04-17 |
| **LifeEventsService** | ⚠️ **Sous-câblé** | 1 caller externe (divorce_simulator). 18 life events doctrine MINT mais le service n'est consommé que par 1 flow |

---

## Détails façades

### ⚠️ CoachCacheService — invalidation = théâtre

**Fichier:** `lib/services/coach/coach_cache_service.dart`

**API exposée:** `get(key, contextHash)` / `set(key, contextHash, text, ttl)` / `invalidate(trigger)`

**Callers externes:**
- `coach_profile_provider.dart:859` : `CoachCacheService.invalidate(InvalidationTrigger.profileUpdate)` (dans `updateProfile`)

**Callers de `.get()` ou `.set()`:** ZÉRO (sauf docstring exemples).

**Conséquence:** on invalide un cache que personne ne lit. Le cache n'a aucun effet. Tout l'effort de l'invalidation (déjà câblée dans updateProfile) est cosmétique. Soit un consommateur a été supprimé quelque part (Wave E-PRIME peut-être ?), soit il n'a jamais été ajouté.

**À décider (v2.9+):**
- Supprimer `CoachCacheService` entièrement (YAGNI)
- OU câbler un vrai consommateur (coach_chat_screen pour greeting cache par exemple)

---

### ⚠️ MilestoneService — n'existe pas, seulement strings l10n

**Recherche:** `find lib -iname "milestone*"` → aucun service file.

**Ce qui existe:**
- Modèle `PlanMilestone` dans `lib/models/financial_plan.dart`
- Strings l10n : `planCard_milestonesHeading`, `proactiveGoalMilestone`, `milestoneKnowledgeCurieuxDesc` (gamification), etc.

**Ce qui manque:**
- Pas de `MilestoneService.detect()` ou équivalent
- Pas de logic de trigger milestone sur changement de profil
- Le narrative quotidien inclut `milestoneMessage: null` (vu dans plist) — champ toujours null.

**Impact UX:** les jalons trimestriels / milestones affichés dans la doctrine MINT ("premier 10k épargne", "50k", "rachat LPP annuel") ne sont PAS calculés automatiquement. Seul le nom de la feature existe dans les textes.

**À décider (v2.9+):** implémenter MilestoneService ou retirer les références l10n.

---

### ⚠️ AnnualRefresh — trigger mort

**Fichier consommateur (théorique):** `snapshot_service.dart:193`

```dart
if (trigger == 'wizard_complete' || trigger == 'annual_refresh') {
  // ... behavior if annual refresh
}
```

**Callers passant `'annual_refresh'`:** ZÉRO.

**Contexte historique:** comment `app.dart:107` dit `annual_refresh_screen.dart + cockpit_detail_screen.dart DELETED (deep-audit 2026-04-17)`. L'écran qui aurait déclenché annual_refresh a été supprimé mais le check est resté orphelin dans snapshot_service.

**Impact:** aucune mise à jour annuelle automatique. L'utilisateur doit re-scanner / re-saisir chaque année sans prompting système.

**À décider (v2.9+):** soit recréer un trigger (notification annuelle + re-prompt), soit supprimer le check orphelin.

---

### ⚠️ LifeEventsService — 1 seul caller externe

**Fichier:** `lib/services/life_events_service.dart`

**Callers externes trouvés:**
- `lib/screens/divorce_simulator_screen.dart` — 1

**Contexte MINT:** les 18 life events sont la **structure fondamentale** de l'app (housing, family, tax, career, debt, retirement, divorce, birth, job loss, expat, etc.). Un seul flow consomme le service.

**Ce que ça veut dire:**
- Les autres simulateurs (EPL, rachat LPP, 3a, fiscal, etc.) n'utilisent PAS `LifeEventsService`
- Ils lisent directement `CoachProfileProvider` et calculent localement
- **Pas forcément bug** : si chaque simulateur est isolé, il fonctionne. Mais pas de hub central « tes life events en cours » pour l'utilisateur.

**À vérifier dans une session dédiée:** est-ce que `LifeEventsService` devrait être appelé depuis les 17 autres simulateurs, ou est-ce un helper spécifique à divorce ?

---

## Services wirés — confirmations par grep

### RegulatorySyncService
```
lib/main.dart:50  await RegulatorySyncService.loadFromDisk();
lib/main.dart:96  RegulatorySyncService.fetchConstants().catchError((e) { ... });
lib/constants/social_insurance.dart:28  double reg(String key, double fallback) { ... }  // SSoT pour Swiss constants
lib/services/first_job_service.dart:159-171  final acCeil = reg('ac.salary_ceiling', ...); // 5+ usages
```

### StreakService
```
lib/services/coach_narrative_service.dart:246  checkInStreak = StreakService.compute(profile).currentStreak;
lib/services/coach_narrative_service.dart:813  final streak = StreakService.compute(profile);
```

### SnapshotService
```
lib/main.dart:101  SnapshotService.loadFromBackend().catchError((e) { ... });
lib/providers/coach_profile_provider.dart:974  SnapshotService.createSnapshot(...)
lib/services/mint_state_engine.dart:248  final previousSnapshot = await SessionSnapshotService.load();
```

### addCheckIn
```
lib/widgets/coach/widget_renderer.dart:502  provider.addCheckIn(checkIn);
```
1 caller — check-in arrive UNIQUEMENT via widget rendered par coach chat. Pas de check-in scheduled ou automatique. Si user n'interagit pas avec le widget spécifique, pas de streak.

---

## Non-audités (scope hors session)

- Services backend Python (`services/backend/app/services/*`) — audit séparé si besoin
- Tests unitaires de chaque service — assume OK, pas vérifié
- Les ~10 `tools/checks/*.py` lints MINT — déjà wirés via lefthook skeleton (phase 30.5)

---

## Recommandations ordonnées

### Priorité immédiate (plumbing)
1. **Supprimer `CoachCacheService`** (ou câbler un consommateur réel) — actuellement du code mort avec invalidation théâtrale. YAGNI.
2. **Supprimer le check `annual_refresh` orphelin** dans `snapshot_service.dart:193` — ou recréer l'entry point.

### Priorité v2.9+ (feature)
3. **Implémenter `MilestoneService`** si les jalons doivent exister — actuellement uniquement décoration l10n.
4. **Auditer câblage `LifeEventsService`** vs les 17 simulateurs qui ne le consomment pas — décider : isolé par design OU manquant.

### Non-action
- Les services bien câblés n'ont pas besoin de changement immédiat.
- RegulatorySyncService / Sentry / FeatureFlags / ReportPersistenceService sont au cœur du flow.
