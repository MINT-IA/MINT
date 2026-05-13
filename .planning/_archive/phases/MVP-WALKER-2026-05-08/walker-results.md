---
name: MVP Walker — 2026-05-08 (sim, staging)
description: End-to-end walker on iPhone 17 Pro sim against Railway staging. Étape 1 unblocked by saveToken keychain-fallback fix; 3/6 PASS, 2/6 PARTIAL, 1/6 FAIL.
date: 2026-05-08
target_sim: iPhone 17 Pro (B03E429D-0422-4357-B754-536637D979F9)
target_staging: https://mint-staging.up.railway.app
build_branch: chore/zero-trust-protocol-claude-md (= origin/dev content + saveToken keychain-fallback fix)
runner_app_mtime: 2026-05-08 06:13:28 (App.framework/App, after fix rebuild)
test_user_email: julien-test+walker-fix-1778213659@gmail.com
---

# MVP Walker — 2026-05-08

## TL;DR — honest verdict

**Le flux MVP marche-t-il bout-en-bout, oui ou non ?**

**Partiellement.** Aujourd'hui, après le fix « saveToken keychain fallback », un nouvel utilisateur peut s'inscrire, voir ses tabs, paramétrer son budget, scanner son LPP (fixture-test), et son profil se remplit. **Mais le coach ne charge pas dans son prompt les données LPP/budget que l'utilisateur vient d'importer**, et le wiki « Ce que MINT sait de toi » ne surface que 2 des ~16 facts capturés.

| Étape | Verdict | Citation clé |
|---|---|---|
| 1. Register | PASS (après fix) | sim redirect to /coach/chat + staging HTTP 409 on probe-after-tap |
| 2. Onboarding via coach | PARTIAL | Mon profil rendered avec projection (CHF 4'576/mois manquant, Confiance 57%) ; iOS auto-correct mangé l'input |
| 3. Budget setup | PASS | « Revenus 5'202 CHF · Dépenses 2'431 CHF · Reste 2'771 CHF » + recommandation 3a |
| 4. PDF upload (test fixture) | PASS | « Confiance : 41 % → 70 % (+29 points) » + 14 fields confirmed (Avoir 143'287.50, Salaire 72'540…) |
| 5. Wiki « Ce que MINT sait de toi » | PARTIAL | Page rendue, mais « 2 données » seulement (Julien + 40 ans) — LPP/budget/canton/salaire absents du wiki |
| 6. Coach uses data | **FAIL** | Coach répond « Je ne peux pas te donner de chiffre sans ton certificat LPP. Scanne ton certificat dans MINT » — alors que l'user a juste importé le fixture LPP 3 min plus tôt |

**MVP working signal** : 4/6 features actionnables ; 2 blockers visibles dans les responses coach.

## Pre-flight

| Check | Result | Citation |
|---|---|---|
| Sim booted | OK | iPhone 17 Pro Booted |
| Staging UP | OK | `curl /api/v1/health` → `{"status":"ok"}` HTTP 200 |
| Build (after Tahoe-xattr fix) | OK | `✓ Built build/ios/iphonesimulator/Runner.app` ; App.framework mtime 2026-05-08 06:13:28 |
| Install + launch | OK | `ch.mint.app: 9208` |

### Build workaround (macOS Tahoe `.nosync`)

Repository sits in `MINT.nosync` (iCloud-friendly mount). macOS Tahoe / Sequoia stamps `com.apple.FinderInfo` and `com.apple.fileprovider.fpfs#P` xattrs on framework directories. Flutter's `_signFramework` in `flutter_tools/lib/src/build_system/targets/ios.dart:920–942` calls `xattr -cr` then `codesign --force` but iCloud daemon re-applies xattrs faster than the strip→codesign window.

Fix that worked on this rig :
```bash
find apps/mobile/build/ios/Debug-iphonesimulator -type d -name '*.framework' \
  -exec xattr -d com.apple.FinderInfo {} \; \
  -exec xattr -d 'com.apple.fileprovider.fpfs#P' {} \;
flutter build ios --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=SENTRY_DSN=
```

(Worth porting into `tools/simulator/walker.sh` and into the iOS `Strip xattrs before codesign` build phase as a follow-up — out of scope for this perimeter.)

## Étape 1 — Register — PASS

### Walk + citations
1. Tap « Je comprends, on y va » (beta disclosure dismiss) ✓
2. Landing → « J'ai déjà un compte » → login screen ✓
3. Tap « Créer un compte » → register form ✓
4. Fill: `julien-test+walker-fix-1778213659@gmail.com` / `Julien` / `15.06.1985` / `T3st-Walker-2026` / CGU + 18+ ✓
5. Tap « Créer mon compte » → app **redirected to /coach/chat** (tab bar visible: Aujourd'hui, Mon argent, Coach, Explorer)

**Backend confirmation :**
```
curl -s -X POST .../auth/register -d '{"email":"julien-test+walker-fix-1778213659...","password":"...","display_name":"Julien"}'
→ HTTP 409 {"detail":"Un utilisateur avec cet email existe déjà"}
```
(probe-after-tap: 409 confirms the SIM submission successfully created the user on staging the first time.)

### Root cause of the prior session blocker

`AuthService.saveToken` (`apps/mobile/lib/services/auth_service.dart:30–55`) was throwing `PlatformException` from `flutter_secure_storage` on the iOS simulator — Keychain under `KeychainAccessibility.first_unlock` is unreliable on a sim without a passcode. The exception propagated to `AuthProvider.register`'s catch block (`auth_provider.dart:220–225`), `_toUserFriendlyAuthError(e)` (line 782) matched no pattern, fell through to `AuthError.genericError` → ARB `authErrorGeneric` → « Action impossible pour le moment ». User stuck on register screen with an orphan account on staging.

Forensic citation: SharedPreferences plist after submit was missing every key written by `register_screen.dart:95–100` (`accepted_cgu_v1`, `consent_notifications`, `q_birth_year`, `q_firstname`) — proves `register_screen` line 79 `if (mounted && success)` was never entered, i.e. `AuthProvider.register()` returned `false`. The only synchronous-throwing operation between `ApiService.register` (HTTP 201) and `return true` in that method body is `AuthService.saveToken`.

### Fix shipped

`apps/mobile/lib/services/auth_service.dart`:
- Added in-memory cache (`_memToken`, `_memRefreshToken`, `_memUserId`, `_memUserEmail`, `_memDisplayName`) populated by `saveToken` *before* the keychain write attempt.
- `saveToken` keychain writes wrapped in try/catch; failure logs (debug only) and uses memory fallback.
- `getToken` / `getUserId` / `getUserEmail` / `getDisplayName` / `getRefreshToken` read memory first, fall back to keychain (with try/catch on read).
- `_performRefresh` populates memory before writing to keychain.
- `logout` clears memory cache then attempts keychain delete (try/catch).
- `@visibleForTesting resetMemoryCacheForTest()` for test isolation.

Mirrors PR #516's « graceful Keychain fallback » pattern (commit `3d7a7559`, biography service).

### Tests

- `test/services/auth_service_test.dart` — added group « keychain failure fallback » with 4 regression tests (saveToken doesn't throw; getToken returns memory; everything-fails returns null; logout clears memory). All 27 tests in the file pass.
- Existing test setUps updated with `AuthService.resetMemoryCacheForTest()` call so static state doesn't leak across tests.

## Étape 2 — Onboarding via coach — PARTIAL

After register the app routes to `/coach/chat` (per `register_screen.dart:119`, KILL-05). There is no dedicated onboarding form for canton/archetype/salaire — onboarding is conversational via the coach (matches `MILESTONE-MVP-PERIMETER.md` Feature #1 "Anon chat remembers"). « Mon profil → Commencer le diagnostic » also routes to `/coach/chat`.

### Citation: coach extracted enough to populate Mon profil
After typing « J'ai 40 ans, salaire 8500 brut, Lausanne, Vaud, salarie, achat appart dans 3 ans » (mangled by iOS auto-correct to « J'ai 40 and, saltire 8500 brut, Lausanne, Vaud, salarie, a hat apart dans 3 ans »), drawer → Mon profil renders:
- « À la retraite, il te manquera CHF 4'576 /mois »
- « Confiance 57 % »
- « Aujourd'hui 4'576/mois → Retraite 0/mois »

So the financial_core projection ran on at least *some* extracted facts. The drawer header also displays « Julien · 40 ans », which proves the firstName + birthYear writes from `register_screen:84-92` (`q_firstname`, `q_birth_year`, `q_date_of_birth`) reached SharedPreferences and the profile.

### Walker tooling issue (not an app bug)
`idb ui text` triggers iOS keyboard auto-correct on the simulator: « ans » → « and », « salaire » → « saltire », « achat appart » → « a hat apart ». Workarounds: disable autocorrect on the sim (`xcrun simctl ... textInput.autoCorrection`), use clipboard-paste (`pbcopy` → `Cmd+V` via `cliclick`), or programmatically set the field via Flutter test driver.

## Étape 3 — Budget setup — PASS

Walk: `Mon argent` tab → tap « Commencer » on « Ton budget ce mois » card → 7-form opens → defaults pre-filled (Loyer 1500, Assurance maladie 440, Total fixe 1940 CHF/mois) → tap « Enregistrer ».

After save, Mon argent dashboard shows:
- « Ton budget ce mois. Revenus 5'202 CHF. Dépenses 2'431 CHF. Reste 2'771 CHF. »
- « 💡 Bon mois. Tu pourrais verser 693 CHF en 3a. »

Net revenue computation (5'202) ≈ 8'500 brut × 0.612 — plausible for VD with full deductions. 3a-affordability advice tracks the « Reste 2'771 ».

## Étape 4 — PDF upload (test fixture) — PASS

Walk: `Mon argent` → « Scanner » → defaults to « Certificat de prevoyance LPP » → « Utiliser un exemple de test ».

### Fixture rendered
Header: « 14 champs détectés. Confiance extraction : 87 % »

Fields visible (all 14):
| Field | Value | Confidence |
|---|---|---|
| Avoir de vieillesse total | CHF 143'287.50 | 87% |
| Part obligatoire | CHF 98'400 | 87% |
| Part surobligatoire | CHF 44'887.50 | 87% |
| Salaire assuré | CHF 72'540 | 87% |
| Taux de bonification | 15.00 % | 85% |
| Taux de conversion (obligatoire) | 6.80 % | 85% |
| Taux de conversion (surobligatoire) | 5.20 % | 85% |
| Rente de vieillesse projetée | CHF 31'450 | 87% |
| Capital projeté à 65 ans | CHF 485'200 | 87% |
| Prestation d'invalidité | CHF 36'800 | 87% |
| Prestation de décès | CHF 220'500 | 87% |
| Lacune de rachat (rachat possible) | CHF 45'000 | 87% |
| Cotisation employé (mensuelle) | CHF 452.50 | 87% |
| Cotisation employeur (mensuelle) | CHF 543 | 87% |

Tap « Confirmer et enrichir mon profil » → success screen: « Confiance : 41 % → 70 % (+29 points) » + « Champs mis à jour ». Mon argent dashboard updates: « Ton point de départ. Net 143'288 CHF. 33 % des donnees connu » → confirms LPP avoir flowed into the patrimoine aggregate.

### Note
- Julien's spec said « 15 fields » in the fixture confirmation; UI says « 14 champs détectés ». Off-by-one — flag for ARB / fixture audit.
- The « Utiliser un exemple de test » path is explicitly a hardcoded mock (per Julien's prompt). Real OCR/Vision parse not exercised this round.

## Étape 5 — Wiki « Ce que MINT sait de toi » — PARTIAL

Drawer → « Ce que MINT sait de toi » page rendered with header « 2 données | 100 % à jour » and only:
- « Mon profil → Julien »
- « 40 ans »

**Missing entirely from wiki**:
- Canton (Vaud) — extracted by coach
- Salaire — set in budget setup (5'202 CHF/mois net)
- All 14 LPP fields just confirmed via fixture upload (Avoir 143'287.50, Salaire 72'540, Lacune 45'000, etc.)
- Budget categories (Loyer 1500, Assurance maladie 440)

The Mon argent dashboard, Mon profil, and the financial_core projections all *use* this data — but the wiki doesn't surface it. Hypothesis: wiki page reads from a narrower facts store (e.g. only `q_firstname` + `q_birth_year`) instead of joining the full ProfileAggregator + budget + LPP enrichment outputs. Worth grepping `Ce que MINT sait de toi` screen + its data source for the gap.

## Étape 6 — Coach uses data — **FAIL**

After Étapes 2-5 above, sent to coach: « Combien je peux racheter en LPP ».

Citation — full coach response :
> « Je ne peux pas te donner de chiffre sans ton certificat LPP. »
> Lists 4 missing fields: « Ton salaire envisageable actuel », « Tes années de cotisation manquantes », « Les bonifications d'âge cumulées depuis tes 25 ans », « Tes rachats déjà effectués »
> « Ce chiffre figure sur ton certificat LPP annuel… »
> « Scanne ton certificat LPP dans MINT (onglet Documents) — l'a[utomatique]… »
> « Tu as ton certificat LPP sous la main ? »

**Yet the user just imported the LPP fixture 3 minutes earlier**, with explicit values for all 4 fields the coach claims to be missing:
- « salaire envisageable » → `Salaire assuré CHF 72'540`
- « années de cotisation » / « lacunes » → `Lacune de rachat (rachat possible) CHF 45'000`
- « bonifications d'âge » → `Taux de bonification 15.00 %`
- « rachats déjà effectués » → covered by `Avoir de vieillesse total CHF 143'287.50` + `Part surobligatoire CHF 44'887.50`

This is a load-bearing MVP failure. The « Real data ingestion » axis from `MILESTONE-MVP-PERIMETER.md §1` is what's broken in user-visible terms — the data is captured but the coach prompt doesn't carry it.

### Probable failure surface
The coach context builder (likely `services/coach/coach_context_*.dart` or its backend equivalent in `services/backend/app/services/coach/`) is reading the coach-side memory store, which is different from where the LPP enrichment writes. Cross-store fact propagation is the missing piece.

This is **out-of-scope for the saveToken-fix PR** but must be the next perimeter — without it, no « end-to-end real-data MVP » is possible. Recommend opening it as a sibling phase: `MVP-COACH-CONTEXT-LPP-WIRING-2026-05-08`.

## Open follow-ups (not blockers for this PR)

1. **Coach context drops fresh LPP/budget data** (Étape 6) — load-bearing. Open as next perimeter.
2. **Wiki shows only 2 facts** (Étape 5) — surfaces only `q_firstname` + birth_year ; missing canton, salary, LPP fields, budget categories.
3. **iOS sim auto-correct mangling walker text** — walker tooling issue (turn off auto-correct in sim, or paste via clipboard).
4. **`ApiService.register` 409 surface as generic « Action impossible »** in *one* of my probe attempts (retry path) — `_toUserFriendlyAuthError` mapping should fire on `AuthError.emailAlreadyUsed` based on « existe déjà » substring; check that the `ApiException`'s message preserves that substring.
5. **Fixture says « 15 fields » in spec vs « 14 champs détectés » in UI** — off-by-one in fixture or spec.
6. **macOS Tahoe `.nosync` xattr workaround needs porting** into `tools/simulator/walker.sh` so D-01 of the 14-day plan actually runs unattended.

## Sim/staging artifacts

Users created on staging this session (orphan accounts, `email_verified: false`) :
- `julien-test+walker-2026-05-08-fresh-001@gmail.com` (curl)
- `julien-test+walker-2026-05-08-fresh-002@gmail.com` (sim, pre-fix)
- `julien-test+walker-2026-05-08-fresh-003@gmail.com` (curl)
- `julien-test+walker-2026-05-08-fresh-009@gmail.com` (curl)
- `julien-test+walker-212051@gmail.com` (sim, pre-fix)
- `julien-test+keychain-1778181807@gmail.com` (sim, pre-fix)
- `julien-test+walker-fix-1778213659@gmail.com` (sim, **post-fix**, full walker)

Cleanup deferred to Julien's call.

## What worked, what didn't

| Component | Status | Citation |
|---|---|---|
| iOS sim build (after xattr workaround) | OK | `✓ Built build/ios/iphonesimulator/Runner.app` |
| Sim install + cold launch | OK | `ch.mint.app: 9208` (PID returned) |
| Beta disclosure dismiss | OK | button gone after tap |
| Landing → Login → Register | OK | screens render in sequence |
| Register form rendering + validation | OK | DOB picker, password complexity, CGU/18+ wired |
| `idb ui text` typing (ASCII) | Flaky | iOS auto-correct mangles longer messages |
| `idb ui key-sequence` backspace | Flaky | One sequence call hit `('Request was not sent',)` companion error pre-fix |
| `POST /auth/register` (server) | OK | HTTP 201 + JWT |
| Front-end post-register flow (after fix) | OK | redirect to `/coach/chat`, drawer accessible |
| Budget setup save | OK | dashboard updated immediately |
| LPP test-fixture import | OK | 14 fields confirmed; confidence +29 |
| Coach response on first message | Personalized | references LPP / 3a |
| Coach response on later messages | **Generic / data-blind** | doesn't reference imported LPP avoir, requests user re-scan |
| Wiki « Ce que MINT sait de toi » coverage | Sparse | 2/16 facts |
