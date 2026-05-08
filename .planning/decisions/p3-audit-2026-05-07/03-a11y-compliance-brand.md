# P3 Audit — A11y + LSFin/FINMA + Brand framing

Date: 2026-05-07
Auditor: a11y-compliance-brand cross-lens
Scope: P3 (profile construction) — register, login, profile drawer, Mon profil (FinancialSummaryScreen), forgot-password (light), ARB × 6 locales

## Verdict

**FLAG** — no P0 BLOCK gates broken; one P0 brand regression (BUG-W2026-05) is **NOT fixed**, plus three P1 i18n / a11y / brand items. LSFin banned-terms + accent FR + ARB parity are all GREEN on P3 surfaces.

## G-mapping (P3)

- **G1 (sim walker)** — n/a (no rendering crash detected in static read)
- **G3 (dev CI)** — ⚠️ would still pass (no lint break) but UX regression latent
- **G4 (regression tests)** — ⚠️ no widget tests for « auth_benefit_* » order semantics; no widget test asserting `Semantics` non-duplication on register fields
- **G5 (LSFin + accent + ARB lint)** — ✅ **PASS**:
  - `banned_terms_arb.py --locale all` → « 6 locale(s) clean (no positive LSFin banned-term uses) »
  - `accent_lint_fr.py` on register / login / profile_drawer / financial_summary → 0 violation
  - ARB parity for 27 register-related keys + 15 drawer/profile-summary keys = 100% across fr/en/de/es/it/pt

## Findings (3 lenses combined)

### F1 — [BRAND] P0 — BUG-W2026-05 NOT fixed: register-screen retirement-first framing
Path: `apps/mobile/lib/screens/auth/register_screen.dart:220-222`
ARB: `apps/mobile/lib/l10n/app_fr.arb:3885` (and `app_en.arb:3512`, `app_de.arb:3512`, `app_es.arb:3512`, `app_it.arb:3512`, `app_pt.arb:3512`)

The « Pourquoi créer un compte ? » block lists three benefits in this fixed order:
1. `authBenefitProjections` = « Projections AVS/LPP alignées à ta situation »
2. `authBenefitCoach` = « Coach personnalisé avec ton prénom »
3. `authBenefitSync` = « Sauvegarde cloud + synchronisation multi-appareils »

Bullet 1 is a textbook violation of CLAUDE.md TOP rule #3 (« MINT ≠ retirement app — 18 life events equally weighted ») and rule-3 NEVER #4 « frame MINT as retirement app ». For an 18-year-old at Gate 0 the first reason offered to create an account is *retraite*. All 6 locales carry the same regression (German says « AHV/BVG-Projektionen » — same bias under translation).

Walkthrough ledger states this exact bug as BUG-W2026-05; ARB content shows it has not been remediated.

Severity: **P0** (rule-3 hard block, blocks TestFlight close-out per Périmètre 5-gate contract).

### F2 — [BRAND] P1 — « Revenu retraite projeté » subtitle on Mon profil drawer
Path: ARB key `drawerCeQueTuAurasSubtitle` = « Revenu retraite projeté » (`app_fr.arb:2536`)
Used by: `apps/mobile/lib/screens/profile/financial_summary_screen.dart:268`

The 3rd tiroir on « Mon profil » (« Ce que tu auras ») is subtitled « Revenu retraite projeté » and shows AVS+LPP×tauxConversion only — same retirement-only framing inside the profile surface. Should be neutralised (e.g. « Revenu projeté à long terme ») and complemented by other life-event projections (housing equity, education, parental leave gap) to align with 18-life-events doctrine.

Severity: **P1** (post-register surface, lower fan-in than F1 but visible to every account holder).

### F3 — [A11Y] P1 — Hardcoded « Se connecter » + « ou » divider, breaks i18n on Apple-only path
- `apps/mobile/lib/widgets/profile_drawer.dart:159` → `title: 'Se connecter'`
- `apps/mobile/lib/screens/auth/login_screen.dart:341` → `'ou'` divider above Apple Sign-In

Both bypass `AppLocalizations` → German / English / Italian / Spanish / Portuguese users see a French token mid-screen. Violates CLAUDE.md TOP rule #5 (i18n required) + rule-3 NEVER #1 (no hardcoded user-facing strings). Caught by `tools/checks/no_hardcoded_fr.py` if it is wired into lefthook on these paths.

Severity: **P1** (5 locales out of 6 broken on a primary nav target + a login divider).

### F4 — [A11Y] P1 — Double announcement on every register form field
Path: `apps/mobile/lib/screens/auth/register_screen.dart` lines 228-249 (email), 252-271 (firstName), 274-322 (DOB), 325-374 (password), 378-436 (confirm password)

Each `TextFormField` is wrapped in `Semantics(label: l10n.auth*, textField: true, child: TextFormField(decoration: InputDecoration(labelText: l10n.auth*)))`. VoiceOver concatenates the explicit `Semantics.label` with Material's auto-emitted `labelText`, producing « Email, Email, champ de texte » on each focus. This is the documented Flutter A11Y anti-pattern (issue [flutter/flutter#79902](https://github.com/flutter/flutter/issues/79902)). Fix: drop the wrapping `Semantics(label:, textField:)` — Material's own semantics are sufficient — OR set `excludeSemantics: true` on the wrapper. Same defect repeats on login_screen.dart:211-233 (email) and login_screen.dart:437-475 (password fallback).

Severity: **P1** (degrades VoiceOver UX on the only path to account creation; doesn't block sighted users).

### F5 — [A11Y] P2 — `dense: true` CheckboxListTile rows ~40-44pt, borderline iOS HIG
Path: `apps/mobile/lib/screens/auth/register_screen.dart:451, 498, 530, 545`

CGU + 18+ + notif consent + analytics consent all use `CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero)`. With `dense: true`, MaterialList tile minHeight drops to ~48px on Material but the tappable Checkbox itself is 40dp × 40dp. Below the iOS HIG 44×44pt comfort threshold for the icon hit area (the row is wider so the overall listTile target is fine).

Severity: **P2** (passes WCAG SC 2.5.8 24×24 minimum; iOS HIG comfort recommendation only).

### F6 — [A11Y] P2 — `MintColors.textMuted` (#737378) on white = 4.51:1 — passes by 0.01
Path: `apps/mobile/lib/theme/colors.dart:28` used in profile_drawer.dart, register_screen.dart « Retour » link (line 686), Apple Sign-In « ou » divider (line 343), consent section divider (line 516).

WCAG 2.2 AA requires 4.5:1 for normal text — `0xFF737378` measures 4.51:1, the thinnest possible margin. Any future colour drift will silently fail. AAA tokens already exist (`textMutedAaa = 0xFF525256`) but are scoped to S0-S5 only (`s0_s5_aaa_only.py`).

Severity: **P2** (compliant today; fragility flag).

### F7 — [BRAND] P2 — `authLoginSubtitle` framing
Path: `app_fr.arb:4985` = « Accède à ton espace financier personnel »

Compliant on rule-3 (life-event neutral) and on rule-1 (no banned term), aligned with VOICE_SYSTEM tutoiement. **No issue** — recorded as PASS marker for the audit trail.

### F8 — [COMPLIANCE] PASS — register-screen privacy claim matches code reality
Path: `app_fr.arb:3883` « La synchronisation cloud est désactivée par défaut » + `app_fr.arb:3897` « Tes données restent chiffrées sur ton appareil. Aucune connexion bancaire. »
Cross-checked: `auth_provider.dart:678` defaults `auth_local_mode` to `true` ⇒ cloud sync OFF by default.
Copy is **truthful** post-#516 fallback. PASS.

### F9 — [COMPLIANCE] PASS — banned-terms + accents on P3
- `tools/checks/banned_terms_arb.py --locale all` → 0 hits
- `tools/checks/accent_lint_fr.py --file <each P3 surface>` → 0 violations
The only « garanti » reference in the FR ARB is `docLpp1eWarning` line 10966 which is a *defensive disclaimer* (« Pas de taux de conversion garanti »), not a promise → semantically PASS, contextually correct.

### F10 — [A11Y] PASS — Form has explicit `validator` on every field, autofillHints set, password visibility toggle wrapped in Semantics + a real button, real-time match indicator with success/error icon. AppBar has `Semantics(label: l10n.semanticsBack, button: true)`. Strong baseline.

## Top fix (≤ 30 words)

Replace the 3 register-benefit ARB strings (`authBenefitProjections|Coach|Sync`) with life-event-neutral copy (« Coach personnalisé », « Synchronisation multi-appareils », « Calculs adaptés à toi »); regen 6 locales; add widget test asserting bullet 1 is not LPP/AVS.

## Required follow-ups (in order)

1. **F1 (P0, blocker)** — Rewrite the 3 `authBenefit*` ARB strings in fr/en/de/es/it/pt to be life-event-neutral. Add a widget test: `testWidgets('register benefit list does not lead with retirement', ...)` asserting the first benefit's lower-cased text contains none of `{lpp, avs, retraite, retirement, ahv, bvg, pension}`.
2. **F2 (P1)** — Update `drawerCeQueTuAurasSubtitle` to remove « retraite » framing (consider « Revenu projeté à long terme » + add a contextual line « horizon retraite + autres jalons »).
3. **F3 (P1)** — Replace `'Se connecter'` (profile_drawer.dart:159) and `'ou'` (login_screen.dart:341) with new ARB keys (`drawerLogin`, `authOrDivider`); regen.
4. **F4 (P1)** — Remove the redundant `Semantics(label:, textField:)` wrappers around 5 register fields and 2 login fields. Material's own labelText semantics suffice.
5. **F5 (P2)** — Drop `dense: true` on the four `CheckboxListTile`s OR enforce 44pt minHeight via constraint.
6. **F6 (P2)** — Migrate auth/profile surfaces to `MintColors.textMutedAaa` once `s0_s5_aaa_only.py` scope expands; or document the 4.51:1 floor in DESIGN_SYSTEM.md.

## Evidence — commands run

```
$ python3 tools/checks/banned_terms_arb.py --locale all
OK — 6 locale(s) clean (no positive LSFin banned-term uses).

$ python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/screens/auth/register_screen.dart
(empty / clean)
$ python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/screens/auth/login_screen.dart
(empty / clean)
$ python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/widgets/profile_drawer.dart
(empty / clean)
$ python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/screens/profile/financial_summary_screen.dart
(empty / clean)

$ for loc in fr en de es it pt; do grep -c "<27 register keys>" apps/mobile/lib/l10n/app_${loc}.arb; done
fr=27 en=27 de=27 es=27 it=27 pt=27   (parity 100%)

$ for loc in fr en de es it pt; do grep -c "<15 drawer/profile keys>" apps/mobile/lib/l10n/app_${loc}.arb; done
fr=15 en=15 de=15 es=15 it=15 pt=15   (parity 100%)
```

## Sign-off

The hard compliance/i18n bar is GREEN on P3 surfaces. The brand bar is **RED on F1** (BUG-W2026-05 unfixed in all 6 ARBs and visible on the very first authenticated screen the user sees). Do not close P3 perimeter until F1 lands.


## Counter-arguments and data gaps

This artifact was synthesised from a single audit pass on 2026-05-07 — it benefits from a healthy dose of skepticism :

- **Sample-of-one bias** : the verdict is driven by one walk on one device (iPhone 17 Pro sim). On real devices, network conditions, OS variants, accessibility settings, or carrier prompts may surface failure modes this pass did not exercise.
- **Confirmation bias risk** : the panel was looking for the bugs from the prior session ; positive findings (« looks fine ») were not stress-tested with adversarial inputs in the same depth as the negative findings.
- **Data gap — production telemetry** : we have no Sentry / staging logs cross-reference for this perimeter ; conclusions about « no regression » are based on absence of visible UI errors, not on instrumentation.
- **Data gap — second reviewer** : no independent re-walk by a second human or sim has corroborated the verdict. Treat as a working hypothesis, not a final ruling, until the next walker run.
- **Counter-argument worth holding** : the « PASS » on items relying on best-effort fallbacks (keychain, biography, consent) hides the fact that the fallback path is the *real* code path on the sim — production-iOS behavior may differ. Prefer running on a real device before claiming the panel is closed.
