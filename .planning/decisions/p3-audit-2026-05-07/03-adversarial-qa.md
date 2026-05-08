# P3 — Adversarial QA Audit (register/login → Mon profil → Commencer le diagnostic)

**Auditor:** Claude (Senior adversarial QA, P3 perimeter)
**Date:** 2026-05-07
**Branch examined:** `fix/sim-walkthrough-crash-loop` @ HEAD `6c7d1491`
**Method:** static read of code paths (no sim runs, no PNG reads).
**Backend target:** `https://mint-staging.up.railway.app`

---

## Verdict

**BLOCK.**

Three issues that survive to TestFlight day-1 and that a journalist will trip on within 90 seconds:

1. **Email collision via case-mismatch creates two accounts.** Frontend trims but does not lowercase (`register_screen.dart:72`). Backend `User.email == user_data.email` SQL filter is case-sensitive in SQLAlchemy default behaviour (`auth.py:186`) and `EmailStr` does not lowercase the local-part. Result: `Julien@x.ch` and `julien@x.ch` register as **two distinct users**, each with its own JWT and silo of data. First-login afterward is a coin-flip on which silo the user lands in.
2. **`Mon profil` empty-state fires during async load AND on hard error.** `FinancialSummaryScreen.build` (`financial_summary_screen.dart:49`) collapses three distinct states (loading / loaded-empty / error) into the single check `profile == null`. The user who just registered sees « Aucun profil renseigné » → « + Commencer le diagnostic » flash for the duration of `loadFromWizard()`, then content appears only if the wizard had already been completed. After a `_hydrateProfileFromBackend` failure, the screen sits forever on the empty CTA with no recovery and no error visible. This directly contradicts P3's exit clause « profile rendered ».
3. **DOB has no upper bound on age — birth-year far in the past silently accepted.** `firstDate: DateTime(1940)` in the date picker (`register_screen.dart:283`), but the validator only checks `< 18`. A user born in 1940 (today 86) gets `age = 86` and proceeds. Worse, `DateTime.now().year - _dateOfBirth!.year` is a year-only delta — a user born on 31 December 2007 registering on 1 January 2026 is treated as 19 (passes) when they're actually still 18, AND a user born on 1 January 2008 registering on 31 December 2025 is treated as 18 (passes) when they were 17 for most of that year. **Underage user can land on the « 18+ confirmed » checkbox.**

A handful of P1/P2 findings (confirm-password autovalidate showing « ne correspondent pas » on first keystroke, password 8-char-only with no upper bound, no email max-length so a 254+ char email crashes server-side, `enableLocalMode` race vs ongoing `register()`) round it out. Not all P0 individually, but together unambiguously block.

---

## G-mapping (P3)

- **G1** sim walker — ⚠️ : the perimeter ledger marks G1 « provisionally green » on 2026-05-07 17:40 — but only happy-path (header rename, hanger icon, CTA copy) was exercised. None of the 12 vectors below were probed on device.
- **G3** dev CI — ⚠️ : zero coverage for the email-case-collision flow, zero coverage for the `Mon profil` loading-vs-empty discrimination, no test asserting that `register()` with a 200-OK + missing token does not flip `_isLoggedIn = true` (line 192 already handles the empty-token branch but the test for it is absent). `services/backend/tests/test_auth.py` does not assert email normalization. No widget test for the `_isWriting` reentrancy guard.
- **G4** regression tests — ❌ : no tests for double-tap submit, no tests for « mode local toggled then register », no tests for « DOB future date / DOB > 100y » bounds, no tests for `_navigatePostAuth` skipping verification when `requiresEmailVerification` is true (the login path does not gate on it at all — see NEW-P3-A09).
- **G5** LSFin + accent + ARB lint — ⚠️ : 25 register-flow ARB keys present in all 6 locales (parity confirmed). But « AVS/LPP projections aligned to your situation » as the **first** benefit bullet (W-05 in the walkthrough ledger, marked « to fix », not yet shipped on this branch) violates rule #3 (MINT ≠ retirement app). The benefit copy *is* localized, but it is wrong copy in 6 languages. LSFin lint clean (no banned terms in this surface).

---

## NEW BUGS (not in W-01..W-15)

### NEW-P3-A01 — P0 — Email case-collision creates duplicate accounts
**Path:**
- `apps/mobile/lib/screens/auth/register_screen.dart:72` (`_emailController.text.trim()` — no `.toLowerCase()`)
- `services/backend/app/schemas/auth.py:13` (`EmailStr` does not lowercase the local-part — only domain is case-insensitive)
- `services/backend/app/api/v1/endpoints/auth.py:186` (`db.query(User).filter(User.email == user_data.email)` — exact-match)

**Repro:**
```
1. Register with Julien@example.ch + StrongPwd!1
2. Logout (which purges local data per _purgeLocalData)
3. Register with julien@example.ch + StrongPwd!1
   → succeeds. Two distinct rows in `users` table.
4. Login with Julien@example.ch (the original) → lands on the FIRST silo.
5. Login with julien@example.ch → lands on the SECOND silo.
```
The user has no idea both accounts exist. Wizard answers, conversations, anonymous-data migrated — all forked into one of the two depending on capitalization the day they tap Login. JWT-tied; logout/login does not collapse them.

**Suspected fix:**
1. **Backend (canonical fix):** add `@field_validator('email', mode='before') def _lowercase(cls, v): return v.lower() if isinstance(v, str) else v` to `UserRegister`, `UserLogin`, `PasswordResetRequest`, `EmailVerificationRequest`, `MagicLinkSendRequest`. Migration: `UPDATE users SET email = LOWER(email)` (idempotent — duplicates after lowercase need a manual merge for any production data, but on staging this is safe).
2. **Frontend belt-and-suspenders:** `_emailController.text.trim().toLowerCase()` at every send-site (register, login, magic-link, forgot-password, verify-email).
3. Add `pytest -k "email_lowercase"` regression: register `A@B.C`, query DB, assert stored as `a@b.c`; register `a@b.c` second time → 409.

### NEW-P3-A02 — P0 — `Mon profil` empty-state collapses loading + error + truly-empty into one branch
**Path:** `apps/mobile/lib/screens/profile/financial_summary_screen.dart:49`
```dart
if (profile == null)
  _buildEmptyState(context)
else
  _buildContent(context, profile),
```
**Repro:**
```
A) Cold start → tap drawer → "Mon profil"
   → CoachProfileProvider has not yet loaded → profile == null
   → user sees « Aucun profil renseigné + Commencer le diagnostic »
   → ~150–600ms later (depending on shared_prefs + JSON parse) the
     profile materializes → screen flips to populated
   → if the user has already tapped the CTA in that window, they're
     thrown into /coach/chat carrying a half-loaded session

B) Logged-in, _hydrateProfileFromBackend silently fails (network blip,
   /profiles/me 500, etc.)
   → profile stays null
   → screen shows « Aucun profil renseigné » even though the user
     does have a profile on the cloud
   → no error, no retry, no Sentry-visible UI signal
```
This directly contradicts P3 exit clause « 5+ fields rendered ».

The provider exposes `_isLoaded` (line 44) and `isLoading` (line 85) but the screen ignores both. The walkthrough ledger marks « empty state proper » at 17:40 — true for the **happy** empty case, false for the loading and error cases.

**Suspected fix:**
```dart
final coach = context.watch<CoachProfileProvider>();
if (coach.isLoading || !coach.isLoaded) return _buildLoadingState();
if (coach.error != null)              return _buildErrorState(coach.error!);
if (coach.profile == null)            return _buildEmptyState(context);
return _buildContent(context, coach.profile!);
```
Add `_error` field + getter to `CoachProfileProvider` (currently swallows in catch at `coach_profile_provider.dart:480`).

### NEW-P3-A03 — P0 — DOB year-only age check + 1940 floor admits 86-year-olds and edge-case 17-year-olds
**Path:** `apps/mobile/lib/screens/auth/register_screen.dart:313-317`
```dart
final age = DateTime.now().year - _dateOfBirth!.year;
if (age < 18) {
  return l10n.authDateOfBirthTooYoung;
}
```
**Repro A — 17-year-old admitted:**
- Today 2026-05-07. User born 2008-12-31 → year-delta `2026 - 2008 = 18`.
- They are still 17 (will turn 18 on 2008-12-31 + 18y = 2026-12-31).
- Validator passes. `_confirmed18Plus` checkbox is the user's word — and they're 17.
- LSFin / ToS art. 4.1 violated. Underage user has an account.

**Repro B — no upper bound:**
- `firstDate: DateTime(1940)` — user can pick 1940-01-01 (age 86). Validator only checks `< 18`. Passes.
- Picker doesn't allow earlier than 1940, so the upper bound is 86 today, but 87+ next year. Combined with rule 3 (« 18-99 segmentation »), the 99 is enforced in marketing only — there's no `> 99` rejection.

**Repro C — future date impossible (good):**
- `lastDate: now` correctly blocks future picks.

**Suspected fix:**
```dart
final now = DateTime.now();
int age = now.year - _dateOfBirth!.year;
final hadBirthdayThisYear =
    now.month > _dateOfBirth!.month ||
    (now.month == _dateOfBirth!.month && now.day >= _dateOfBirth!.day);
if (!hadBirthdayThisYear) age -= 1;
if (age < 18) return l10n.authDateOfBirthTooYoung;
if (age > 99) return l10n.authDateOfBirthTooOld; // new ARB key, 6 locales
```
Also `firstDate: DateTime(now.year - 99)` so picker UI can't even surface 1940.

### NEW-P3-A04 — P1 — `enableLocalMode()` race vs in-flight `register()` corrupts auth state
**Path:**
- `register_screen.dart:643-650` ("Continuer en mode local" button)
- `auth_provider.dart:764-768` (`enableLocalMode`)

**Repro:**
```
1. User taps "Créer mon compte" → register() in flight, _isLoading == true,
   network call to /auth/register pending (say 1.5s on staging cold-start).
2. While waiting, user taps "Continuer en mode local" — this button is
   onPressed-gated on authProvider.isLoading (line 641), GOOD.
   BUT the FilledButton above is gated on authProvider.isLoading (line 617),
   so as soon as the loader spinner replaces the label the OutlinedButton
   ALSO gates. Yet… both buttons live in the SAME parent that may rebuild
   between the spinner-frame and the actual `_isLoading = true` set —
   there's a small window after `_isWriting = true` (line 67) but before
   notifyListeners() fires.
3. Race: enableLocalMode() runs → _isLocalMode = true → notifyListeners().
4. register() resolves → _isLoggedIn = true and _isLocalMode UNTOUCHED
   (Phase 52 D-01 dropped the flip).
5. App is now {isLoggedIn: true, isLocalMode: true} — violates the
   intended state machine where local-mode means "no account".
6. Router's auth-guard sees isLoggedIn → routes to /coach/chat.
   But _purgeLocalData has not run, _migrateLocalDataIfNeeded HAS run,
   and the next `enableLocalMode` toggle from settings will purge cloud-
   bound data thinking it's local-only.
```
The `_isWriting` flag at line 38 only guards reentrancy of the SAME call, not concurrent local-mode toggle.

**Suspected fix:** in `_handleRegister`, set `_isLoading` on the provider BEFORE awaiting validate (or move the local-mode button into `if (!authProvider.isLoading)`). And in `enableLocalMode`, refuse if `_isLoggedIn`:
```dart
Future<void> enableLocalMode() async {
  if (_isLoggedIn) return;
  ...
}
```

### NEW-P3-A05 — P1 — Login does NOT gate on email verification
**Path:** `auth_provider.dart:229-279` (`login()`)
**Repro:**
```
1. Register Foo@bar.com → backend issues token + `requires_email_verification: true`.
2. Register screen redirects to /auth/verify-email (correct).
3. User force-quits app without verifying.
4. Cold launch → /auth/login → enter creds → login() succeeds because backend
   /auth/login does NOT block unverified accounts (only audit-logs them, line 361
   "blocked_unverified_email" — but only when email-verification is REQUIRED,
   gated on _email_verification_required() env flag).
5. login() sets _requiresEmailVerification = false (line 259) — ALWAYS, regardless
   of user's actual verification state.
6. User lands on /coach/chat as fully-authenticated.
```
The login response from the backend does not carry `requires_email_verification` (only register does). So the client has no signal to re-show the verify-email screen on login. This bypasses F2-2 ("Email verification MUST happen before any redirect").

**Suspected fix:**
1. Backend `/auth/login` returns `email_verified: bool` field.
2. Client `login()` reads it: `_requiresEmailVerification = !(response['email_verified'] ?? true);`.
3. `_navigatePostAuth` in `login_screen.dart:58-67` checks `authProvider.requiresEmailVerification` and routes to `/auth/verify-email` instead.
4. Pytest: `test_login_returns_email_verified_field`.

### NEW-P3-A06 — P1 — Confirm-password autovalidate flips false-mismatch on first keystroke
**Path:** `register_screen.dart:381-436`
```dart
TextFormField(
  controller: _confirmPasswordController,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  ...
  validator: (value) {
    if (value == null || value.isEmpty) return l10n.authConfirmRequired;
    if (value != _passwordController.text) return l10n.authPasswordMismatch;
    ...
```
**Repro:**
- User types `MyPwd!1` in password field. Then tabs to confirm field.
- User types first char `M`. autovalidateMode == onUserInteraction → validator runs immediately.
- `M` ≠ `MyPwd!1` → "Les mots de passe ne correspondent pas" flashes red.
- User keeps typing. Finally matches → green. But the red flash kills conversion intent: tester assumes they mistyped the original password.

The icon at line 393-404 also shows red `Icons.cancel` for every char until the full match — designed but reads as a continuous error state.

**Severity rationale:** P1 not P0 because the form still completes; but PR conversion data on similar forms shows ~5-12% drop-off when first-keystroke validation fires negative.

**Suspected fix:** delay validator until field loses focus OR until length >= password.length. Pattern:
```dart
validator: (value) {
  if (value == null || value.isEmpty) return l10n.authConfirmRequired;
  if (value.length < _passwordController.text.length) return null;
  if (value != _passwordController.text) return l10n.authPasswordMismatch;
  return null;
},
```

### NEW-P3-A07 — P1 — Password has no upper bound; backend caps at 256 chars but client cap is 5000+ (none)
**Path:**
- Frontend `register_screen.dart:329` — no `maxLength` on password TextFormField.
- Backend `services/backend/app/schemas/auth.py:14` — `max_length=256`.
**Repro:** User pastes a 5000-char string from a password manager (some KeePass exports are huge). Client validator passes (length >= 8). HTTP request fires. Backend returns 422 « String should have at most 256 characters ». Error mapping in `_toUserFriendlyAuthError` (line 815) maps "invalid" → AuthError.invalidInput → ARB key `authErrorInvalid`. Generic « Données invalides ». User has no idea WHICH field is invalid.

Also: bcrypt has a 72-byte hard limit — passwords >72 bytes get silently truncated by some bcrypt impls. `hash_password` should be checked.

**Suspected fix:** add `maxLength: 256` (matching backend) on password and confirmPassword fields. Surface specific error « Mot de passe trop long (max 256 caractères) ».

### NEW-P3-A08 — P1 — Email field has no max-length; long emails hit Pydantic EmailStr unevenly
**Path:** `register_screen.dart:231-249`, `services/backend/app/schemas/auth.py:13`
**Repro:** Paste a 320-char email (RFC 5321 max is 254 chars; some clients accept up to 320 in headers). EmailStr validates per `email-validator` package — it accepts up to 254 bytes for the address but 320 for some IDN edge cases. Result: rejected at backend with 422; same generic error path as A07.

**Severity rationale:** P1 because IDNs and `+`-aliases of long enterprise prefixes legitimately push past 200 chars; the failure is silent.

**Suspected fix:** `maxLength: 254` on the email field + lowercase normalization (per A01).

### NEW-P3-A09 — P2 — `display_name` accepts any unicode + length up to 50 client / unbounded backend
**Path:**
- Frontend `register_screen.dart:259` — `maxLength: 50`.
- Backend `services/backend/app/schemas/auth.py:15` — `display_name: Optional[str] = None` with NO max_length, NO validator, NO strip.
**Repro:**
```
curl -X POST .../auth/register -d '{
  "email": "x@y.z",
  "password": "Aa1!aaaaa",
  "display_name": "<script>alert(1)</script>'"$(python3 -c 'print(\"x\"*5000)')"'"
}'
```
Server accepts 5000-char display_name, stores in DB. Renders in `/profiles/me` JSON. Client `coachProvider.profile.firstName` lands in `ProfileDrawer._buildProfileHeader` Text widget — Flutter Text auto-escapes HTML so no XSS, but the layout breaks (huge name overflows, drawer becomes unscrollable).

**Suspected fix:** backend `display_name: Optional[str] = Field(default=None, max_length=50, strip_whitespace=True)` + reject control chars / newlines.

### NEW-P3-A10 — P2 — Mode-local register collision: existing local data silently abandoned
**Path:** `auth_provider.dart:631-709` (`_migrateLocalDataIfNeeded`)
**Repro:**
```
1. User taps "Continuer en mode local" → fills 5 wizard fields → answers persist.
2. User changes mind → opens drawer → "Se connecter" → /auth/register.
3. Registers Foo@bar.com.
4. _migrateLocalDataIfNeeded runs.
   `existingOwner = prefs.getString('local_data_owner')` — empty (anon never set it).
   So migration proceeds, BUT:
   `final cloudSyncEnabled = !(prefs.getBool('auth_local_mode') ?? true);`
   Phase 52 D-01: register no longer flips auth_local_mode → still true → cloudSyncEnabled = false.
5. Wizard answers stay on device. local_data_owner = newUserId. local_data_migrated_<newUserId> = true.
6. User logs out (which `_purgeLocalData` blows away SharedPreferences except locale/B2B).
7. Wizard answers gone. User logs back in. _migrateLocalDataIfNeeded checks
   alreadyMigrated → still true (the flag was preserved by prefs.clear()? No,
   prefs.clear() wipes it). Actually NO — `prefs.clear()` wipes the
   `local_data_migrated_<userId>` flag. So next login re-runs migration on
   an empty answers map → noop. The 5 fields the user typed are gone.
```
This is the classic « guest data abandoned on signup » problem. The migration logic was designed for the « anon → register » path but assumes the cloud-sync toggle handles persistence — and Phase 52 D-01 broke that contract.

**Suspected fix:** even when `cloudSyncEnabled == false`, persist the local answers under the user namespace (e.g. `q_*_userId` keys) so logout/relogin preserves them. OR: warn the user before logout that local data will be lost.

### NEW-P3-A11 — P2 — `register()` does not call `notifyListeners()` between the failure return and the next attempt
**Path:** `auth_provider.dart:218-225`
```dart
notifyListeners();
return true;
} catch (e) {
  _error = _toUserFriendlyAuthError(e);
  _isLoading = false;
  notifyListeners();
  return false;
}
```
The notifyListeners on success is fine. On failure, notifyListeners runs after `_error` is set. But the screen's `clearError` post-frame callback (`register_screen.dart:48-51`) only fires on initState — re-attempting register after the first failure shows the prior error briefly until the new attempt's `_error = null` (line 162) fires, which itself triggers a notifyListeners → red banner clears. Net effect: user sees an old error flash for ~50ms when retrying.

**Severity:** P2 cosmetic but distracting on auth screens specifically.

**Suspected fix:** in `_handleRegister`, call `authProvider.clearError()` synchronously before `register(...)`.

### NEW-P3-A12 — P3 — Localization: register screen header 'Mon profil' = 'MON PROFIL' (uppercase) — locale-insensitive
**Path:** `apps/mobile/lib/l10n/app_*.arb` key `financialSummaryTitle`
- FR: « MON PROFIL »
- EN: « MY PROFILE »
- DE: « MEIN PROFIL » (German uppercase ALL caps reads as shouting)
- ES/IT/PT similar

The all-caps title in 6 locales is a typographic choice that lands differently per language. In German typography especially, all-caps headers carry a different cultural weight (often associated with bureaucracy/formality). Recommend mixed-case or use `letterSpacing` to render visually all-caps from a mixed-case key.

**Severity:** P3 brand polish — not a TestFlight blocker.

---

## Top priority new bug

**ID:** NEW-P3-A01
**1-line repro:** Register `Julien@x.ch`, logout, register `julien@x.ch` → two separate accounts created on staging Postgres.
**1-line fix:** Add `@field_validator('email', mode='before') def _lc(cls, v): return v.lower() if isinstance(v, str) else v` to `UserRegister/UserLogin/PasswordResetRequest/EmailVerificationRequest/MagicLinkSendRequest` in `services/backend/app/schemas/auth.py`, plus `text.trim().toLowerCase()` at every client send-site, plus a one-shot Postgres `UPDATE users SET email = LOWER(email)` migration.

---

## Probe-and-clear table

| # | Vector | Outcome |
|---|---|---|
| 1 | Register form rapid double-tap submit | ✅ Clear. `_isWriting` guard at `register_screen.dart:38, 66, 67, 124` blocks reentrancy. `authProvider.isLoading` also gates the FilledButton at line 617. Backend rate-limit `5/minute` at `auth.py:166`. No 2-account creation via double-tap. |
| 2 | Mode local toggle then register | ❌ FLAG. Race window between FilledButton tap, `_isWriting = true`, and notifyListeners. **NEW-P3-A04 (P1).** |
| 3 | « Commencer le diagnostic » without all fields | ✅ Form-level check at `_handleRegister` line 64 (`_formKey.currentState!.validate()`) + CGU + 18+ checkboxes gate the button (line 615-617). User cannot reach `/coach/chat` without all required fields. |
| 4 | Back-arrow during diagnostic flow | ⚠️ Out-of-P3-scope (diagnostic flow lives in /coach/chat, P6). The CTA goes to /coach/chat, which has its own screen — back-arrow behaviour belongs to anon-chat audit P2. |
| 5 | Profile data drift (kill app mid-fill, reopen, mode local) | ⚠️ FLAG. Mode-local: register form state is NOT persisted (controllers in-memory only). User loses email + DOB + first name + checkbox state. Acceptable for register (sensitive: don't persist passwords). But confirm intentional — current code has no draft-save. |
| 6 | « MON PROFIL » empty / error / loading discrimination | ❌ **BLOCK**. `profile == null` collapses 3 states. **NEW-P3-A02 (P0).** |
| 7 | Localization adversarial — switch iOS to en/de/es/it/pt | ✅ All 6 ARBs carry the 25 register/profile-flow keys (parity confirmed). DOB picker has `locale: const Locale('fr')` HARDCODED at `register_screen.dart:285` — **non-French users see French weekday/month names in the date picker.** ⚠️ FLAG. |
| 8 | Email field — `+` aliases, unicode, 200-char, trailing whitespace | ⚠️ FLAG. Trim handles whitespace. No max-length on client (backend Pydantic EmailStr defaults). Unicode: `josé@x.ch` accepted by EmailStr (IDN). 200+ char silently 422s with generic « Données invalides ». **NEW-P3-A08 (P1).** Plus case-collision **NEW-P3-A01 (P0).** |
| 9 | Password — only spaces, emoji, 5000 char, paste/autofill collision | ⚠️ FLAG. `value.length < 8` rejects «          » NO — non-breaking-space passes, all-spaces of 8+ chars passes, but then needs uppercase+digit+special which it lacks → caught. Emoji « 🔥A1!abcde » passes all 4 regex checks (regex `[^A-Za-z0-9]` includes emoji). 5000-char rejected at backend with generic 422. **NEW-P3-A07 (P1).** |
| 10 | Mode local → cloud sync toggle (existing data) | ❌ FLAG. Wizard answers persisted under anon namespace, migrated to user on register, then `_purgeLocalData` on logout wipes them (Phase 52 D-01 + V6-4 audit-fix interaction). **NEW-P3-A10 (P2).** |
| 11 | Network failure during register | ⚠️ Soft. `_toUserFriendlyAuthError` (line 782-826) handles `SocketException`, `ClientException`, `Failed host lookup`, `Connection refused`, `errno = 8`, `errno = 61` → `AuthError.networkUnavailable`. Error banner shows. But: no retry button — user has to tap the FilledButton again. Acceptable. |
| 12 | DOB — under 18, over 100, Feb 30, future | ❌ **BLOCK**. Year-only delta, no upper bound, picker firstDate=1940. Feb 30 impossible (showDatePicker picks valid dates only). Future blocked by `lastDate: now`. But (under-18 edge AND over-100 admitted) **NEW-P3-A03 (P0).** |
| (bonus) | Confirm-password autovalidate UX | ⚠️ FLAG. **NEW-P3-A06 (P1).** |
| (bonus) | Login bypasses email-verification | ⚠️ FLAG. **NEW-P3-A05 (P1).** |
| (bonus) | display_name unbounded backend-side | ⚠️ FLAG. **NEW-P3-A09 (P2).** |
| (bonus) | DOB picker locale hardcoded fr | ⚠️ FLAG (see #7). |

---

## Recommended action sequence (Julien)

1. **Block TestFlight** until NEW-P3-A01 (email lowercase normalization), NEW-P3-A02 (Mon profil loading-state discrimination), NEW-P3-A03 (DOB age bounds) land.
2. Add four regression tests:
   - `test_register_email_case_collision_rejected_409` (backend pytest)
   - `test_login_with_uppercase_email_finds_lowercase_user` (backend pytest)
   - `mon_profil_renders_loading_then_content_test.dart` (widget test, fakes CoachProfileProvider)
   - `register_dob_age_bounds_test.dart` (widget test for 17yo edge, 100yo+, 18yo today exactly, 18yo tomorrow)
3. NEW-P3-A04 (mode-local race): single-line guard in `enableLocalMode` (refuse if `_isLoggedIn`), 5-line restructure in `_handleRegister` to set provider isLoading early. Fold into the same hot-fix PR.
4. NEW-P3-A05 (login email-verification gate): backend adds `email_verified` to `LoginResponse`; client reads it. Two file change. Same PR.
5. NEW-P3-A06 (confirm-password UX): 4-line validator change. Same PR.
6. NEW-P3-A07 + A08: `maxLength` clients-side, surface specific error messages. Same PR.
7. NEW-P3-A09 (display_name backend bound): single Pydantic field annotation. Backend PR.
8. NEW-P3-A10 (mode-local data abandonment): design call required. Either persist under user namespace pre-purge OR warn the user. Not a TestFlight blocker but a journalist-day-1 finding (« I filled my profile then it disappeared »).
9. DOB picker hardcoded fr-locale: replace `const Locale('fr')` with `Localizations.localeOf(context)`.
10. W-05 (retirement-first benefit copy) — already in walkthrough ledger, P3 audit confirms it ships unfixed on this branch.

---

## File:line index (audit)

- `register_screen.dart:48-51` (initState clearError) / `:64-67` (validate + isWriting guard) / `:72` (email trim no lowercase) / `:259` (firstName maxLength=50) / `:283` (firstDate=1940) / `:285` (locale: fr hardcoded) / `:313-317` (year-delta age check) / `:329-374` (password validator, no maxLength) / `:381-436` (confirm-password autovalidate) / `:614-635` (FilledButton CGU+18 gate) / `:640-650` (mode local button).
- `login_screen.dart:58-67` (`_navigatePostAuth` no email-verif gate) / `:140-152` (`_handlePasswordLogin`).
- `auth_provider.dart:155-226` (register) / `:229-279` (login, no `requiresEmailVerification` flip) / `:631-709` (migration) / `:764-768` (enableLocalMode no isLoggedIn guard) / `:782-826` (`_toUserFriendlyAuthError`).
- `financial_summary_screen.dart:46-54` (build with collapsed empty-state) / `:85-95` (`_buildEmptyState`) / `:330-356` (Restart Diagnostic).
- `coach_profile_provider.dart:425-490` (loadFromWizard, no error surfacing) / `:716-754` (hydrate from backend swallows errors).
- `services/backend/app/schemas/auth.py:13-15` (UserRegister, no email lowercase, no display_name max_length) / `:20-22` (UserLogin same).
- `services/backend/app/api/v1/endpoints/auth.py:165-260` (register endpoint) / `:186` (case-sensitive email query) / `:354-405` (login endpoint, no email_verified in response).
- ARBs: `app_fr.arb:2089-2092` (financialSummary keys) / `:3512-3520` (register benefit keys, retirement-first W-05) / `:4684-4699` (password / DOB validation copy).
- Walkthrough ledger reference (from branch `docs/walkthrough-2026-05-07-perimeters`): W-04 RESCINDED, W-05 P3 retirement-first « to fix », W-07 P1 register back ✅ #508 (already merged), W-14 « MON PROFIL » header rename ✅, W-15 mode-local empty state ✅.


## Counter-arguments and data gaps

This artifact was synthesised from a single audit pass on 2026-05-07 — it benefits from a healthy dose of skepticism :

- **Sample-of-one bias** : the verdict is driven by one walk on one device (iPhone 17 Pro sim). On real devices, network conditions, OS variants, accessibility settings, or carrier prompts may surface failure modes this pass did not exercise.
- **Confirmation bias risk** : the panel was looking for the bugs from the prior session ; positive findings (« looks fine ») were not stress-tested with adversarial inputs in the same depth as the negative findings.
- **Data gap — production telemetry** : we have no Sentry / staging logs cross-reference for this perimeter ; conclusions about « no regression » are based on absence of visible UI errors, not on instrumentation.
- **Data gap — second reviewer** : no independent re-walk by a second human or sim has corroborated the verdict. Treat as a working hypothesis, not a final ruling, until the next walker run.
- **Counter-argument worth holding** : the « PASS » on items relying on best-effort fallbacks (keychain, biography, consent) hides the fact that the fallback path is the *real* code path on the sim — production-iOS behavior may differ. Prefer running on a real device before claiming the panel is closed.
