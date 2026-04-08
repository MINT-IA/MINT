# Wave 11 — Fix Prompts (7 agents)

> Ce document contient les 7 prompts chirurgicaux pour fermer TOUS les findings de la Wave 11.
> Chaque prompt est autonome et peut être lancé indépendamment via un agent.
>
> **Ordre recommandé** : 1 → 2 → 3 → 7 (ces 4 touchent des fichiers différents, lançables en parallèle)
> puis 4 → 5 → 6 (dépendent de fichiers potentiellement modifiés par 1-3).
>
> **Convention de branches** : chaque prompt crée sa propre feature branch depuis `dev`.
> Merger chaque branche via PR squash → dev.
>
> **IMPORTANT** : Les prompts 1, 2, 3 ont DEJA ETE EXECUTES et leurs fixes sont sur dev.
> Ne relancer que les prompts 4, 5, 6, 7.

---

## PROMPT 1 — Deep links + Localization (2 P0, 3 P1, 2 P2) ✅ DONE

```
You are a senior Flutter/Dart engineer fixing EXACTLY these bugs. Follow instructions precisely. Do NOT add features, do NOT refactor surrounding code. Fix ONLY what's listed.

## CONTEXT
- Branch: `dev` (verify with `git branch --show-current`)
- Create feature branch: `git checkout -b feature/S62-w11-deeplinks-l10n`
- Run `flutter analyze` and `flutter test` BEFORE and AFTER changes

## FIXES REQUIRED

### FIX 1: German placeholder {gapCapital} missing (P0 — CRASH)
**File:** `apps/mobile/lib/l10n/app_de.arb`
**Bug:** Key `agirScenarioBriefSummary` is missing `{gapCapital}` placeholder in German. French version has it.
**Action:**
1. Read the French version of this key in `app_fr.arb`
2. Find the same key in `app_de.arb`
3. Add the missing `{gapCapital}` placeholder in the German translation at the logical position (matching the French structure)
4. Run `flutter gen-l10n` to verify no error

### FIX 2: German plural rule syntax error (P0)
**File:** `apps/mobile/lib/l10n/app_de.arb`
**Bug:** Key `householdMemberCount` has wrong plural syntax. Current: `aktive{count, plural, =1{s} other{}}` — the `=1{s}` is wrong for German adjective declension.
**Action:**
1. Find `householdMemberCount` in `app_de.arb`
2. Fix the ICU plural to: `{count} aktive{count, plural, =1{s} other{}} Mitglied{count, plural, =1{} other{er}}`
   - "1 aktives Mitglied" (singular neuter)
   - "2 aktive Mitglieder" (plural)
3. Run `flutter gen-l10n` to verify

### FIX 3: Date format hardcoded to fr_CH (P1)
**File:** `apps/mobile/lib/screens/main_tabs/dossier_tab.dart`
**Bug:** Line ~506 uses `DateFormat('d MMMM', 'fr_CH')` — hardcoded French locale.
**Action:**
1. Find the hardcoded `'fr_CH'` in DateFormat calls in this file
2. Replace with locale from context: `DateFormat('d MMMM', Localizations.localeOf(context).toString())`
3. Search the ENTIRE `apps/mobile/lib/` for OTHER hardcoded `'fr_CH'` in DateFormat calls
4. Fix ALL occurrences the same way

### FIX 4: Date format MM.yyyy not locale-aware (P1)
**File:** `apps/mobile/lib/widgets/profile/dettes_drawer_content.dart`
**Bug:** Line ~80 uses `DateFormat('MM.yyyy')` without locale parameter.
**Action:** Add locale parameter: `DateFormat('MM.yyyy', Localizations.localeOf(context).toString())`

### FIX 5: Deep link prompt parameter unvalidated (P1)
**File:** `apps/mobile/lib/app.dart`
**Bug:** `/coach/chat` route accepts `prompt` query parameter without length limit or sanitization.
**Action:** In the GoRoute builder for `/coach/chat`, add validation:
```dart
final rawPrompt = state.uri.queryParameters['prompt'];
final prompt = (rawPrompt != null && rawPrompt.length <= 500) ? rawPrompt : null;
final rawConvId = state.uri.queryParameters['conversationId'];
final conversationId = (rawConvId != null && RegExp(r'^[a-zA-Z0-9\-]{1,64}$').hasMatch(rawConvId)) ? rawConvId : null;
```

### FIX 6: Android exported=true without deep-link filter (P1)
**File:** `apps/mobile/android/app/src/main/AndroidManifest.xml`
**Bug:** MainActivity has `android:exported="true"` but no VIEW intent filter for deep links.
**Action:** This is required for LAUNCHER. No change needed — the current config is correct for a launcher activity. Mark as WONTFIX with comment.

### FIX 7: CHF formatter not locale-aware (P2)
**File:** `apps/mobile/lib/utils/chf_formatter.dart`
**Bug:** Always uses Swiss apostrophe format `1'234` regardless of locale.
**Action:** This is intentional — MINT is a Swiss app. Add a comment at the top of the file:
```dart
/// CHF amounts are ALWAYS formatted in Swiss style (1'234.00) regardless of
/// locale, because CHF is a Swiss currency and Swiss formatting is the standard.
/// This is intentional per CLAUDE.md §7 (Design System).
```

### VALIDATION
After ALL fixes:
1. `flutter gen-l10n` — must succeed with 0 errors
2. `flutter analyze` — must have 0 errors
3. `flutter test` — all tests must pass
4. `git add` only the modified files
5. `git commit` with message: "fix(l10n+deeplinks): W11 — German placeholders, date locale, prompt validation"
```

---

## PROMPT 2 — Crash recovery + data safety (2 P0, 5 P1) ✅ DONE

```
You are a senior Flutter/Dart + Python engineer fixing EXACTLY these crash recovery bugs. Follow instructions precisely. Do NOT refactor. Fix ONLY what's listed.

## CONTEXT
- Branch: create `feature/S62-w11-crash-recovery`
- Run tests BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Conversation JSON corruption after crash (P0)
**File:** `apps/mobile/lib/services/coach/conversation_store.dart`
**Bug:** `saveConversation()` writes to SharedPreferences non-atomically. If crash mid-write, JSON is corrupted and `loadConversation()` silently returns `[]` — entire history lost.
**Action:**
1. In `saveConversation()`, write to a TEMP key first, then rename:
```dart
Future<void> saveConversation(String conversationId, List<ChatMessage> messages) async {
  final prefs = await SharedPreferences.getInstance();
  final key = '$_messagesPrefix$conversationId';
  final tempKey = '${key}_tmp';
  final json = jsonEncode(messages.map((m) => m.toJson()).toList());
  await prefs.setString(tempKey, json);
  await prefs.setString(key, json);
  await prefs.remove(tempKey);
}
```
2. In `loadConversation()`, add recovery from temp key:
```dart
Future<List<ChatMessage>> loadConversation(String conversationId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = '$_messagesPrefix$conversationId';
  final tempKey = '${key}_tmp';
  var raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) {
    raw = prefs.getString(tempKey);
  }
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _messageFromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('[ConversationStore] Corrupted conversation $conversationId: $e');
    return [];
  }
}
```

### FIX 2: ConversationMeta DateTime.parse crash on malformed dates (P1)
**File:** `apps/mobile/lib/services/coach/conversation_store.dart`
**Bug:** `ConversationMeta.fromJson()` uses `DateTime.parse()` which crashes on malformed dates.
**Action:** Replace with `DateTime.tryParse()` + fallback:
```dart
createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? '') ?? DateTime.now(),
```

### FIX 3: IAP purchase not auto-recovered on app resume (P0)
**File:** `apps/mobile/lib/screens/main_navigation_shell.dart`
**Bug:** If app crashes during IAP purchase, `restoreAndSync()` is NOT called on app resume.
**Action:** In `didChangeAppLifecycleState()`, add IAP restore on resume:
```dart
if (state == AppLifecycleState.resumed) {
  try {
    if (IosIapService.isSupportedPlatform) {
      IosIapService.restoreAndSync();
    }
  } catch (_) {}
}
```

### FIX 4: Auth logout SharedPreferences race (P1)
**File:** `apps/mobile/lib/providers/auth_provider.dart`
**Bug:** In `_purgeLocalData()`, `prefs.clear()` then `prefs.setString()` has a crash window.
**Action:** Save preserved values BEFORE clear, restore AFTER.

### FIX 5: GoalA.fromJson crash on missing 'label' (P1)
**File:** `apps/mobile/lib/models/coach_profile.dart`
**Action:** `label: (json['label'] as String?) ?? '',`
Do the same for `GoalB.fromJson()`.

### FIX 6: PlannedMonthlyContribution.fromJson crash on missing fields (P1)
**File:** `apps/mobile/lib/models/coach_profile.dart`
**Action:**
```dart
id: (json['id'] as String?) ?? 'legacy_${DateTime.now().millisecondsSinceEpoch}',
label: (json['label'] as String?) ?? '',
category: (json['category'] as String?) ?? 'other',
```

### FIX 7: Conversation keys not user-prefixed (P1)
**File:** `apps/mobile/lib/services/coach/conversation_store.dart`
**Action:** Add user prefix mechanism and call from AuthProvider on login/logout.

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — all pass
3. `git commit`: "fix(crash-recovery): W11 — atomic saves, IAP restore, auth purge safety, fromJson fallbacks"
```

---

## PROMPT 3 — Notifications + SDK privacy (2 P1, 2 P2, 2 docs) ✅ DONE

```
You are a senior Flutter/Dart engineer fixing EXACTLY these notification and privacy bugs. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w11-notifications-privacy`

## FIXES REQUIRED

### FIX 1: PII visible on lock screen via BigTextStyleInformation (P1 — nLPD)
**File:** `apps/mobile/lib/services/notification_service.dart`
**Action:** Replace BigTextStyleInformation with DefaultStyleInformation + visibility: NotificationVisibility.private

### FIX 2: Notifications lost if app killed before firing (P1)
**Action:** Persist scheduled deadlines to SharedPreferences. Add checkMissedDeadlines() on app resume.

### FIX 3: Weekly recap Monday calculation edge case (P2)
**Action:** Fix Monday calculation: `if (daysUntilMonday == 0) daysUntilMonday = 7;`

### FIX 4: No granular notification opt-out (P2)
**Action:** Add TODO comment only.

### FIX 5: Speech-to-text audio disclosure missing (P1 — nLPD)
**Action:** Add hasShownDisclosure()/markDisclosureShown() + consent dialog before first STT use. Add i18n keys to all 6 ARB files.

### FIX 6: Notification deep links without auth guard (P2)
**Action:** Already protected by GoRouter. Add comment only.

### VALIDATION
1. `flutter gen-l10n` — 0 errors
2. `flutter analyze` — 0 errors
3. `flutter test` — all pass
4. `git commit`: "fix(notifications+privacy): W11 — lock screen PII, missed deadlines, voice disclosure"
```

---

## PROMPT 4 — Multi-device sync + logout safety (2 P0, 3 P1, 1 P2)

```
You are a senior Flutter/Dart + Python engineer fixing EXACTLY these multi-device sync bugs. Fix ONLY what's listed. Do NOT refactor.

## CONTEXT
- Create branch: `feature/S62-w11-multi-device`
- Run flutter analyze + flutter test BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: Profile sync last-write-wins = data loss (P0)
**File:** `services/backend/app/api/v1/endpoints/sync.py`
**Bug:** localDataVersion is a static integer (default 1). Both devices send version=1, whichever syncs last wins silently.
**Action:**
1. Replace version integer with ISO 8601 timestamp comparison
2. In `claim_local_data()`, change the staleness check from:
   `if existing_version >= body.local_data_version: return`
   To:
   ```python
   if existing_meta.get('updatedAt') and body.updated_at:
       existing_ts = datetime.fromisoformat(existing_meta['updatedAt'])
       incoming_ts = datetime.fromisoformat(body.updated_at)
       if existing_ts >= incoming_ts:
           return ClaimLocalDataResponse(status="stale", ...)
   ```
3. Add `updated_at: Optional[str] = None` field to ClaimLocalDataRequest schema
4. On Flutter side, send `DateTime.now().toUtc().toIso8601String()` as `updated_at` in the sync payload
5. Log conflicts: `logger.info("Sync conflict: existing=%s incoming=%s user=%s", existing_ts, incoming_ts, user_id)`

### FIX 2: Logout purge irréversible (P0)
**File:** `apps/mobile/lib/providers/auth_provider.dart`
**Bug:** `_purgeLocalData()` destroys ALL local data without backup to backend.
**Action:**
1. Before `prefs.clear()`, log the purge for observability:
```dart
try {
  final store = ConversationStore();
  final conversations = await store.listConversations();
  debugPrint('[Auth] Purging ${conversations.length} conversations (not backed up)');
} catch (_) {}
```
2. Add TODO for Phase 2:
```dart
// TODO(P2): Implement cloud backup of conversations/check-ins before purge
```

### FIX 3: Subscription stale cross-device (P1)
**File:** `apps/mobile/lib/providers/subscription_provider.dart`
**Bug:** `refreshIfStale()` uses 1-hour threshold.
**Action:** Reduce threshold from 1 hour to 15 minutes:
```dart
if (DateTime.now().difference(_lastRefresh).inMinutes >= 15) {
  await refreshFromBackend();
}
```

### FIX 4: Check-in data not synced between devices (P1)
**Action:** Add TODO only:
```dart
// TODO(P2): Sync monthly check-ins to backend for cross-device access
```

### FIX 5: New device login shows empty state (P1)
**File:** `apps/mobile/lib/providers/auth_provider.dart`
**Bug:** After login, app does NOT call `GET /profiles/me` to hydrate local state.
**Action:** In the login success flow, after `_migrateLocalDataIfNeeded()`, add:
```dart
try {
  final profileData = await ApiService.get('/profiles/me');
  if (profileData.isNotEmpty && profileData.containsKey('data')) {
    final data = profileData['data'] as Map<String, dynamic>?;
    if (data != null) {
      final prefs = await SharedPreferences.getInstance();
      if (data['birthYear'] != null) await prefs.setInt('q_birth_year', data['birthYear'] as int);
      if (data['canton'] != null) await prefs.setString('q_canton', data['canton'] as String);
      if (data['incomeGrossYearly'] != null) {
        await prefs.setDouble('q_gross_salary', (data['incomeGrossYearly'] as num).toDouble() / 12);
      }
    }
  }
} catch (_) {}
```

### FIX 6: CAP memory not synced between devices (P2)
**Action:** Add TODO comment only in `cap_memory_store.dart`:
```dart
// TODO(P3): Sync CapMemory to backend for cross-device continuity
```

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — all pass
3. `pytest tests/ -q` — all pass (if sync.py modified)
4. `git commit`: "fix(multi-device): W11 — timestamp sync, subscription refresh, new device hydration"
```

---

## PROMPT 5 — Financial reports (4 P1, 1 P2)

```
You are a senior Flutter/Dart engineer fixing EXACTLY these financial report bugs. Fix ONLY what's listed.

## CONTEXT
- Create branch: `feature/S62-w11-reports`
- Run flutter analyze + flutter test BEFORE and AFTER

## FIXES REQUIRED

### FIX 1: CHF rounding loses centimes (P1)
**File:** `apps/mobile/lib/utils/chf_formatter.dart`
**Bug:** `formatChf()` uses `.round()` which discards centimes.
**Action:** Add a new function `formatChfPrecise()`:
```dart
/// Format CHF with centimes precision (e.g., "4'280.50").
/// Use for tax reports and PDF export where centime accuracy matters.
String formatChfPrecise(double value) {
  if (!value.isFinite) return '—';
  final parts = value.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final formatted = intPart.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  return "${value < 0 ? '-' : ''}$formatted.$decPart";
}
```
Use `formatChfPrecise()` in `pdf_service.dart` for tax amounts. Keep existing `formatChf()` for UI.

### FIX 2: Confidence score always 0 in reports (P1)
**File:** `apps/mobile/lib/services/financial_report_service.dart`
**Bug:** `confidenceScore` defaults to 0, never computed.
**Action:** After computing the report profile, calculate confidence:
```dart
final scorer = ConfidenceScorer();
final confidenceResult = scorer.score(profile);
// In FinancialReport constructor:
confidenceScore: confidenceResult.global,
enrichmentPrompts: confidenceResult.enrichmentPrompts,
```

### FIX 3: Couple report uses same age/salary for spouse (P1)
**File:** `apps/mobile/lib/services/financial_report_service.dart`
**Bug:** Spouse AVS uses user's age and salary.
**Action:** Read conjoint data from profile:
```dart
final conjointAge = profile.conjoint?.age ?? profile.age;
final conjointSalary = (profile.conjoint?.salaireBrutMensuel ?? grossMonthlySalary) * 12;
```

### FIX 4: Report not versioned with constants snapshot (P1)
**File:** `apps/mobile/lib/services/financial_report_service.dart`
**Action:** Populate `simulationAssumptions`:
```dart
simulationAssumptions: {
  'constants_version': RegulatorySyncService.lastSyncDate?.toIso8601String() ?? 'fallback',
  'lpp_conversion_rate': SocialInsurance.lppTauxConversion,
  'avs_max_monthly': SocialInsurance.avsRenteMaxMensuelle,
  'pillar3a_max': SocialInsurance.pilier3aPlafondAvecLpp,
},
```

### FIX 5: No data collection timestamp in report (P2)
**Action:** Add field: `dataCollectedAt: await ReportPersistenceService.getLastAnswerTimestamp(),`

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — all pass
3. `git commit`: "fix(reports): W11 — centime precision, confidence score, couple data, versioning"
```

---

## PROMPT 6 — Test coverage critical gaps (4 P0, 2 P1)

```
You are a senior Python test engineer. Write MINIMAL but EFFECTIVE tests for the 6 most critical untested services. Each test file must have at least 5 test cases covering happy path + edge cases.

## CONTEXT
- Create branch: `feature/S62-w11-test-coverage`
- Backend tests in `services/backend/tests/`
- Run `pytest tests/ -q` BEFORE and AFTER

## IMPORTANT
- Read the actual service files FIRST to understand the API/functions before writing tests
- Use existing test fixtures and conftest.py patterns from the codebase
- Each test must be independent (no shared state between tests)

## TESTS REQUIRED

### TEST 1: audit_service.py (P0 — regulatory)
**File:** `services/backend/tests/test_audit_service.py`
1. `log_audit_event()` creates event with correct fields
2. `log_audit_event()` with missing optional fields doesn't crash
3. Event type enum includes all expected values
4. Query audit events by user_id returns correct results
5. Audit events are NOT deleted when user account is anonymized

### TEST 2: divorce_simulator (P0 — legal compliance)
**File:** `services/backend/tests/test_divorce_simulator.py`
1. LPP splitting: 50% of LPP accumulated during marriage
2. AVS splitting: income averaged over marriage years
3. Edge case: marriage duration = 0 years
4. Edge case: one spouse has 0 LPP
5. Edge case: both spouses have identical LPP amounts

### TEST 3: succession_simulator (P0 — legal compliance)
**File:** `services/backend/tests/test_succession_simulator.py`
1. Reserves héréditaires: spouse gets 50%, children share remaining 50% (CC art. 471)
2. No children: spouse gets 75%, parents get 25%
3. Concubinage: partner gets 0% by law
4. Edge case: 1 child (gets 50% reserve)
5. Edge case: 5+ children (equal share of 50%)

### TEST 4: donation_service (P0)
**File:** `services/backend/tests/test_donation_service.py`
1. Tax deduction capped at 20% of net income (LIFD art. 33a)
2. Donation of 0 CHF returns 0 deduction
3. Donation exceeding 20% cap returns capped amount
4. Canton-specific deduction rules (GE vs ZH)
5. Edge case: negative income + donation

### TEST 5: auth_security_service (P1)
**File:** `services/backend/tests/test_auth_security_service.py`
1. 10 failed logins triggers lockout (15 min)
2. Lockout expires after 15 minutes
3. Successful login resets failure counter
4. Password reset token is single-use
5. Token hash prevents plaintext storage

### TEST 6: coverage_checklist_service (P1)
**File:** `services/backend/tests/test_coverage_checklist_service.py`
1. Full coverage profile returns all items checked
2. Missing disability insurance flagged
3. Missing death coverage flagged
4. Independent without LPP shows increased 3a recommendation
5. Edge case: retiree doesn't need employment-related coverage

### VALIDATION
1. `pytest tests/ -q` — all existing + new tests pass
2. `git commit`: "test(coverage): W11 — audit, divorce, succession, donation, auth_security, coverage_checklist"
```

---

## PROMPT 7 — Privacy Policy + nLPD compliance (3 P0, 1 P2)

```
You are a Swiss legal compliance expert updating the MINT app's Privacy Policy and consent flow. Make ONLY the changes listed.

## CONTEXT
- Create branch: `feature/S62-w11-nlpd-compliance`

## FIXES REQUIRED

### FIX 1: Privacy Policy lists no processors (P0 — nLPD violation)
**File:** `legal/PRIVACY.md` (or `PRIVACY.md` at root)
**Bug:** Section 7.3 says "En Phase 1, nous n'utilisons aucun sous-traitant" — this is FALSE.
**Action:** Replace section 7.3 with:

```markdown
### 7.3 Sous-traitants techniques

En Phase 1, nous utilisons les sous-traitants suivants :

**Sentry.io** (Sentry GmbH, Berlin, Allemagne)
- Données : journaux d'erreurs applicatives (aucune donnée personnelle — sendDefaultPii=false)
- Durée de conservation : 30 jours
- Base légale : intérêt légitime (débogage, stabilité de l'application)

**Railway.app** (Railway Corp., San Francisco, États-Unis)
- Données : profils utilisateurs, scénarios, snapshots (chiffrés en transit TLS 1.3)
- Durée : tant que le compte est actif
- Base légale : exécution du contrat
- Garanties : Standard Contractual Clauses (SCC)

**Anthropic / OpenAI** (États-Unis) — uniquement si tu actives BYOK
- Données : contexte coaching anonymisé (âge, canton, archetype, score FRI — jamais ton salaire exact)
- Durée : par requête (pas stocké par MINT)
- Base légale : consentement explicite (byokDataSharing)
- Tu utilises ta propre clé API — MINT n'est pas responsable du traitement par le fournisseur LLM

**Apple / Google** — uniquement si tu utilises la reconnaissance vocale
- Données : flux audio vocal (envoyé au moteur de reconnaissance native)
- Durée : par requête
- Base légale : consentement explicite (activation vocale)

**Google Fonts** (Google LLC, États-Unis)
- Données : adresse IP (lors du téléchargement initial des polices)
- Durée : ponctuel (polices mises en cache localement)
- Base légale : intérêt légitime (affichage typographique)
```

### FIX 2: Cross-border transfers not documented (P0)
**Same file:** Find the sentence "aucune donnée personnelle n'est transférée hors de Suisse" and replace with:

```markdown
Tes données sont hébergées sur Railway (États-Unis). Les transferts vers les États-Unis sont protégés par des Standard Contractual Clauses (SCC). En Phase 2, nous prévoyons un hébergement en Suisse.
```

### FIX 3: Consent timing — show BEFORE data collection (P0)
**File:** `apps/mobile/lib/screens/onboarding/smart_onboarding_screen.dart`
**Bug:** Consent prompt appears AFTER user starts entering data in Step 1.
**Action:**
1. In `initState()`, check consent and show sheet IMMEDIATELY:
```dart
@override
void initState() {
  super.initState();
  // FIX-W11-nLPD: Show consent BEFORE any data collection
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_onboardingConsent != true) {
      _showOnboardingConsentSheet();
    }
  });
}
```
2. Remove the consent check from `_onInputChanged()` (it's now in initState)
3. Block navigation to Step 1 questions until consent is given

### FIX 4: google_fonts CDN disclosure (P2)
**Action:** Already included in FIX 1 above (Google Fonts entry in section 7.3).

### VALIDATION
1. Read the updated PRIVACY.md to verify all sections are coherent
2. `flutter analyze` — 0 errors (if Dart files modified)
3. `flutter test` — all pass
4. `git commit`: "fix(nlpd): W11 — Privacy Policy processors, cross-border, consent timing"
```

---

## CHECKLIST DE LANCEMENT

| # | Prompt | Branch | Status | Parallélisable avec |
|---|--------|--------|--------|---------------------|
| 1 | Deep links + l10n | `feature/S62-w11-deeplinks-l10n` | ✅ DONE | — |
| 2 | Crash recovery | `feature/S62-w11-crash-recovery` | ✅ DONE | — |
| 3 | Notifications + privacy | `feature/S62-w11-notifications-privacy` | ✅ DONE | — |
| 4 | Multi-device sync | `feature/S62-w11-multi-device` | TODO | 5, 6 |
| 5 | Financial reports | `feature/S62-w11-reports` | TODO | 4, 6 |
| 6 | Test coverage | `feature/S62-w11-test-coverage` | TODO | 4, 5 |
| 7 | nLPD compliance | `feature/S62-w11-nlpd-compliance` | TODO | 4, 5, 6 |

**Prompts 4, 5, 6, 7 sont lançables en parallèle** (fichiers indépendants).
