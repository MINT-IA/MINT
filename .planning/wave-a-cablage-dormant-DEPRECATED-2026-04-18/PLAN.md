# PLAN — Wave A : Câblage dormant + prerequis P0

**Branche** : `feature/wave-a-cablage-dormant`
**Base** : `dev` @ `a0dd5d31` (Merge PR #352)
**Durée estimée** : 4-6h
**PR cible** : `feature/wave-a-cablage-dormant` → `dev` (merge-commit)

## Goal

Transformer MINT d'app-musée à compagnon quotidien qui aiguille. Les moteurs (notifications, cap engine, mémoire événementielle) existent et sont dormants. On les câble sans ajouter de feature.

## Non-goals

- Pas d'ajout de feature nouvelle
- Pas de refonte architecturale
- Pas de Home tab réarrangé (= Wave B)
- Pas de scan-to-coach handoff (= Wave C)
- Pas de FRI sorti du shadow mode (= Wave D)
- Pas de fix bulk resolveCanton (= Wave E)

## Rationale des 7 commits

### Analyse pré-commit : prerequisites P0 Panel 7 à intégrer

Certains findings Panel 7 sont **prerequisites** pour Wave A/B/C/D :
- **P0 #2 save_fact PII log** — bloque Wave C qui étend save_fact usage → doit être corrigé AVANT Wave C → on fait en Wave A
- **P0 #7 profile.age == 0 sentinel** — bloque Wave B CapEngine sur home (CapEngine consomme age) → on fait en Wave A
- **P0 #10 double weekly_recap_service** — Wave B branche weekly recap, doit savoir lequel → on fait en Wave A

Les autres P0 Panel 7 restent pour Wave E (cleanup systémique).

## Les 7 commits atomiques

### Commit A1 — Scan LPP → CoachInsight event save

**Finding** : Panel simulation 3 mois — `document_impact_screen.dart` n'appelle pas `CoachMemoryService.saveInsight`, donc coach ne peut JAMAIS dire "tu as scanné ton certificat il y a 3 semaines".

**Scope** :
- Après succès du scan + appel `_fetchPremierEclairage()`, sauvegarder un `CoachInsight` avec :
  - `topic: 'scan'`
  - `type: 'event'` (nouveau enum ou existant ?)
  - `summary: 'Certificat LPP ${caisse} scanné — avoir ${avoir} CHF'`
  - `date: DateTime.now()`
- Event ajouté à `CoachMemoryService` persistence (SharedPreferences FIFO 50 insights)

**Fichiers touchés** :
- `apps/mobile/lib/screens/document_scan/document_impact_screen.dart`
- `apps/mobile/lib/services/memory/coach_memory_service.dart` (vérif enum type existant)

**Tests** :
- `test/screens/document_scan/document_impact_event_save_test.dart` (nouveau) — widget test scan → verify saveInsight called with correct topic+type
- `test/services/memory/coach_memory_event_test.dart` — roundtrip event type

**Gate commit A1** : scan mocké → CoachInsight event persisté → retrieve_memories injecté dans system prompt contient "scan LPP CPE avoir 70377 CHF"

---

### Commit A2 — `scheduleCoachingReminders(profile)` wired on profile-ready

**Finding** : Panel daily-loop — `NotificationService.scheduleCoachingReminders` est définie (895 lignes infra) mais **zéro caller production**. API dormante.

**Scope** :
- Trouver hook point : `coach_chat_screen.dart:252 _markOnboardingCompletedIfNeeded()` semble le bon endroit (onboarding complet = profile suffisamment peuplé)
- Vérifier consent avant scheduling (déjà fait dans la méthode elle-même via `ConsentManager`)
- Appeler `NotificationService().scheduleCoachingReminders(profile: profile)` après onboarding complete
- Aussi appeler sur app resume si profile a changé substantiellement (nouveaux faits save_fact) → `lifecycle observer` OU post-scan completion
- Respecter idempotence (cancelAll + re-schedule)

**Fichiers touchés** :
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (hook post-onboarding)
- `apps/mobile/lib/app.dart` (lifecycle observer if needed)

**Tests** :
- `test/services/notification_scheduling_wiring_test.dart` — verify scheduleCoachingReminders called post-onboarding
- Mock `NotificationService` pour tests Widget (singleton injection)

**Gate commit A2** : onboarding complete → `NotificationService.scheduleCoachingReminders` appelée avec profile → 4 triggers (monthly checkin, 3a deadlines, tax deadlines, weekly recap) schedulés.

---

### Commit A3 — `scheduleRetentionNotifications` fix + J+30 dedup

**Findings** :
- Panel simulation — `scheduleRetentionNotifications(taxSaving3a)` skipped silently si `taxSaving3a == null` (notification_service.dart:635)
- Panel simulation — J+30 "Scanne ton certificat LPP" nag même si déjà scanné (notification_service.dart:655)

**Scope** :
- `scheduleRetentionNotifications` appelée à la fin onboarding avec vraie valeur `taxSaving3a` (calculée depuis profile : `0.25 * (pilier3aPlafondAvecLpp - profile.pillar3aAnnual ?? 0)`)
- Si `taxSaving3a <= 0` → skip J+7 (message n'a pas de sens) avec log explicite
- J+30 nag : check si `profile.prevoyance.avoirLppTotal != null && scanLppDone` (via CoachInsight topic='scan') → skip nag

**Fichiers touchés** :
- `apps/mobile/lib/services/notification_service.dart`
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (appel scheduleRetentionNotifications post-onboarding avec vraie valeur)

**Tests** :
- `test/services/notification_scheduling_retention_test.dart` — cases : profile sans scan → J+30 nag fires ; profile avec scan CoachInsight → J+30 skipped ; taxSaving3a=0 → J+7 skipped (log) ; taxSaving3a=1000 → J+7 fires

**Gate commit A3** : Julien J+7 reçoit "Tu laisses CHF 1'314 au fisc" (si 3a pas au max), Julien J+30 NE reçoit PAS nag scan (déjà fait J+0).

---

### Commit A4 — Post-J+30 cliff tué — weekly `scheduleCheckinReminder` auto

**Finding** : Panel simulation — post-J+30 zéro notification planifiée. `scheduleCheckinReminder` existe (notification_service.dart:343) mais jamais auto-called.

**Scope** :
- `scheduleCheckinReminder` appelée chaque app resume si utilisateur n'a pas check-in ce mois
- Alternativement : ajouter `_scheduleWeeklyEngagementPing` dans `scheduleCoachingReminders` qui fire chaque lundi 19h avec body référençant **dernier premier_eclairage caché** du profile
- Body localisé (6 langues ARB)

**Fichiers touchés** :
- `apps/mobile/lib/services/notification_service.dart` (nouveau méthode privée + appel)
- `apps/mobile/lib/l10n/app_*.arb` (nouvelles clés `weeklyEngagementTitle` / `weeklyEngagementBody`)
- `apps/mobile/lib/app.dart` (WidgetsBindingObserver.didChangeAppLifecycleState.resumed)

**Tests** :
- `test/services/notification_weekly_engagement_test.dart` — fires chaque lundi 19h si profile + pas check-in courant

**Gate commit A4** : Julien J+45, J+60, J+75, J+90 reçoit 1 notif/semaine lundi 19h avec référence à son dernier insight. Plus jamais de cliff.

---

### Commit A5 — `save_fact` PII log redaction (Panel 7 P0 #2)

**Finding** : `services/backend/app/api/v1/endpoints/coach_chat.py:1365` log `coerced` = raw value (salaire, avoir LPP, canton). Violation CLAUDE.md §6.7 (no log PII).

**Scope** :
- Définir `_REDACTED_FACT_KEYS = {'incomeNetMonthly', 'incomeGrossMonthly', 'incomeNetYearly', 'incomeGrossYearly', 'selfEmployedNetIncome', 'annualBonus', 'avoirLpp', 'avoirLppObligatoire', 'avoirLppSurobligatoire', 'lppBuybackMax', 'pillar3aBalance', 'totalSavings', 'wealthEstimate', 'totalDebt', 'spouseIncomeNetMonthly'}`
- Remplacer log par :
  ```python
  logged_value = "[REDACTED]" if fact_key in _REDACTED_FACT_KEYS else coerced
  logger.info("save_fact: user=%s key=%s value=%s conf=%s", user_id_hash, fact_key, logged_value, fact_conf)
  ```
- Retour LLM inchangé (LLM doit voir la valeur pour raisonner) : `f"Fait enregistré : {fact_key} = {coerced}"`

**Fichiers touchés** :
- `services/backend/app/api/v1/endpoints/coach_chat.py:1365`

**Tests** :
- `services/backend/tests/test_save_fact_pii_redaction.py` — cases : `incomeNetMonthly=7600` → log n'affiche PAS "7600" → affiche "[REDACTED]" ; `canton='VS'` → log affiche "VS" (non sensible) ; `householdType='couple'` → log affiche "couple"

**Gate commit A5** : grep sur les logs de test après test suite complète → 0 hit sur valeurs salaire/LPP/savings.

---

### Commit A6 — `profile.age == 0` sentinel guards (Panel 7 P0 #7)

**Finding** : `models/coach_profile.dart:1651,1657` clamp invalid birthYear à 0. 5 écrans consomment `profile.age` sans guard : `libre_passage_screen.dart:52`, `provider_comparator_screen.dart:49`, `rachat_echelonne_screen.dart:186`, `independant_screen.dart:68`, `ijm_screen.dart:45`.

**Scope** :
- Ajouter getter `CoachProfile.ageOrNull` qui retourne `int?` (null si 0 ou invalid)
- 5 consumers migrés vers `ageOrNull`
- Si `ageOrNull == null` → soit prompt utilisateur via `ask_user_input(field: 'birthYear')`, soit bannière "Âge inconnu — simulation en mode estimation" + fallback age=40
- Décision par écran :
  - `libre_passage_screen` : bloquant (libre passage dépend fortement de l'âge)
  - `provider_comparator_screen` : non-bloquant (estimation)
  - `rachat_echelonne_screen` : bloquant
  - `independant_screen` : non-bloquant (estimation)
  - `ijm_screen` : bloquant (invalidité assurance)

**Fichiers touchés** :
- `apps/mobile/lib/models/coach_profile.dart` (getter ageOrNull)
- `apps/mobile/lib/screens/libre_passage_screen.dart` — fichier pas trouvé en grep? **Vérifier**, peut-être déjà refactoré
- `apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart:49`
- `apps/mobile/lib/screens/rachat_echelonne_screen.dart:186` (vérifier path)
- `apps/mobile/lib/screens/independant_screen.dart:68`
- `apps/mobile/lib/screens/ijm_screen.dart:45`

**Tests** :
- `test/models/coach_profile_age_null_test.dart` — `ageOrNull` retourne null si birthYear invalid / 0 / missing
- Par écran, widget test : profile sans birthYear → bannière "âge inconnu" visible OU CTA ask_user_input

**Gate commit A6** : `flutter analyze` 0 err, tests passants, device smoke iPhone 17 Pro : 5 écrans ouverts sans âge → bannière explicite, pas de math silencieux avec age=0.

---

### Commit A7 — Consolidation `weekly_recap_service.dart` (Panel 7 P0 #10)

**Finding** : 2 fichiers `weekly_recap_service.dart` (`services/recap/` + `services/coach/`). Undefined behavior si agents importent le mauvais.

**Scope** :
- Audit des 2 fichiers : lequel est la vraie implementation, lequel est stale ?
- Grep consumers de chacun
- Decision : garder celui avec plus de consumers, déprécier l'autre avec `@Deprecated` + re-export, ou carrément merge-into-one
- Choisir path canonique : probable `services/recap/` (structure dédiée)
- Supprimer l'autre si 0 consumer, sinon migrer les imports

**Fichiers touchés** :
- `apps/mobile/lib/services/recap/weekly_recap_service.dart` OU `apps/mobile/lib/services/coach/weekly_recap_service.dart` (delete one)
- `apps/mobile/lib/services/recap/recap_formatter.dart:11` (import)
- `apps/mobile/lib/services/recap/ai_recap_narrator.dart:14` (import)
- Tests associés

**Tests** :
- tests existants doivent continuer à passer après consolidation
- Nouveau test : `test/services/recap/weekly_recap_single_source_test.dart` — assert qu'il n'y a qu'un fichier `weekly_recap_service.dart` dans lib/

**Gate commit A7** : `flutter analyze` 0 err, tests recap passants, `find apps/mobile/lib -name "weekly_recap*.dart"` retourne exactement 1 résultat.

---

## Gates mécaniques sortie Wave A

1. `cd apps/mobile && flutter analyze` → 0 error, pas plus d'info que baseline (152)
2. `cd apps/mobile && flutter test` tests touchés → 100% green
3. `cd apps/mobile && flutter test` smoke intégration sur tous tests services → 0 régression vs baseline 6509 pass
4. `cd services/backend && python3 -m pytest tests/ -q` → 5964+ pass, 0 fail
5. ARB 6 langs parity vérifiée : `tools/checks/arb_parity.sh` ou manuel (clés fr == en == de == es == it == pt)
6. CI sur branche → 10/10 green
7. Banned terms scan (compliance_guard.py + mobile guard) → 0 hit
8. Sentinel values / magic numbers introduits → 0 (sauf déjà acceptés avec source légale)
9. Nouveaux `catch (_)` silencieux → 0
10. **Device walkthrough iPhone 17 Pro sim** :
    - App resume J+1 → notification fires (simulée via time-travel ou mock)
    - Scan LPP → CoachInsight event visible dans storage
    - Coach message J+1 mentionne le scan d'hier
    - 5 écrans sans âge → bannière "âge inconnu" visible
11. MEMORY.md handoff mis à jour

## Risques identifiés

| Risque | Mitigation |
|---|---|
| `NotificationService.scheduleCoachingReminders` appelle `cancelAll()` — peut supprimer notifs legitimate d'une autre source | Vérifier qu'aucune autre source ne schedule des notifs ; logger avant cancelAll ; tests |
| Consent check gate (ConsentManager.isConsentGiven) peut silencieusement skip scheduling | Log explicite quand consent=false ; Sentry breadcrumb |
| ARB 6 langs ajoutés (A4 weekly engagement keys) — traduction manuelle auto peut dériver en qualité | Template FR d'abord, translations par RegionalVoiceService ou translator en commit séparé si temps ; minimum : clés valides même si traduction approximative |
| `CoachMemoryService.saveInsight` sync ou async ? | Vérifier en lisant le code |
| `profile.age` getter peut être used dans des endroits non listés | `grep -rn "profile.age" apps/mobile/lib/` exhaustif dans commit A6 ; ajouter guards là où nécessaire |
| weekly_recap double consolidation peut casser des imports non détectés | `flutter analyze` + tests exhaustifs |
| save_fact redaction — liste `_REDACTED_FACT_KEYS` incomplète | Auditer chaque key de l'enum dans coach_tools.py `save_fact.input_schema.properties.key.enum` (40+ keys) — par défaut REDACT sauf allowlist explicite (canton, commune, employmentStatus, etc.) |

## Verification plan (goal-backward)

**Goal Wave A** : Julien ouvre MINT J+1, reçoit une notification, tape dessus, coach dit "Bonjour Julien, hier tu as scanné ton certificat LPP CPE avec 70'377 CHF d'avoir. Tu veux regarder ton rachat potentiel ?"

Chaque commit contribue :
- A1 ⇒ coach peut citer le scan (event memory existe)
- A2 ⇒ notification J+1 fire (scheduling wired)
- A3 ⇒ notification a bon content (pas null, pas nag redondant)
- A4 ⇒ Julien reste engagé au-delà J+30
- A5 ⇒ compliance (pas de leak PII dans logs)
- A6 ⇒ simulateurs âge-aware pas de silent fail
- A7 ⇒ pas d'ambiguïté sur quelle weekly recap service

Si tous les commits shipped ET tous les gates green ET device walkthrough réussi → goal atteint.

## Après Wave A

- Merge → dev via merge-commit (audit trail préservé)
- MEMORY.md handoff : "Wave A shipped, 7 commits, X tests added, CI 10/10. Next: Wave B — Home Aujourd'hui orchestrateur."
- Démarrer Wave B immédiatement avec même discipline.
