# MINT — Debug Perimeters (live audit log)

> **SUPERSEDED par Journey OS (`.planning/journeys/`)** — figé au 2026-05-07,
> conservé pour l'historique. Ne jamais relire ce fichier comme état courant :
> les statuts P1-P3 « PROVISIONALLY READY » / P4 IN_FLIGHT / P5-P7 PENDING
> datent du 2026-05-07. Le gate G6 (calc-correctness) reste vivant via
> `.github/workflows/calc-rigor.yml` + `tools/checks/g6_path_check.py`.
> Réconciliation plans 2026-07-29.

**Started:** 2026-05-07
**Doctrine:** 1 perimeter active at a time. No phase GSD theater. No spec docs. This file IS the artifact.

## Exit gates (each perimeter)

| Gate | Verification | Required proof |
|---|---|---|
| G1 | Sim walker auto (idb) | log path / screenshot dir |
| G2 | Sim-driven device-equivalent walk (idb auto, full release-mode flow) | log path + final-state assertion summary |
| G3 | CI green on dev | sha + date |
| G4 | Regression tests still green | run id |
| G5 | LSFin + accent + ARB lint green | lint outputs |
| G6 | Calc-correctness CI (calc_diff + property + ESTV) | run id of `.github/workflows/calc-rigor.yml` |

A perimeter is **CLOSED** only when all 5 gates are green. Until G2, status = « PROVISIONALLY READY ».

> **G6 scoping (Phase 92.5 / CALC-04, D-18)** — G6 applies ONLY aux périmètres / PRs touchant `apps/mobile/lib/services/financial_core/**`, `services/backend/app/services/**`, ou `services/backend/app/constants/social_insurance.py`. Other perimeters remain on G1–G5 unchanged. The `paths:` filter in `.github/workflows/calc-rigor.yml` mechanically gates trigger ; `tools/checks/g6_path_check.py` is the deterministic CLI decider used by GSD verifier integration. Hard-block from day 1 (D-19) — no warn-only ramp-up.
>
> **G6 doctrine** — Mobile `financial_core/` is canonical (ADR-20260223). When differential disagrees, the default presumption is Backend Python drift. Failure comments (D-20) frame asymmetrically: « Mobile (canonical): X, Backend (under test): Y ». Full Backend port deferred to backlog 999.4 / Phase 92.6.

---

## P1 — Cold launch & landing
**ACTION CŒUR:** open the app, read the pitch, tap « Parle à Mint » without confusion.
**EXIT:** beta sheet → landing → CTA tap → anon chat opens. No inappropriate menu entry surfaced.
**BUGS LIÉS:** W-12 BYOK exposed (out-of-scope per project_byok_scope.md), W-15 « Ce que MINT sait » fail-load on local mode, **A02 anon chat lockout on missing `messagesRemaining`** (P0, found by P1 panel adversarial QA 2026-05-07).
**PRs MERGED:** #509 (savoir-plus Safari leak removed), #515 (BYOK menu hidden), #516 (biography Keychain fallback) ✅
**PRs OPEN:** #518 (A02 anon chat lockout fix) — awaiting CI
**STATUS:** 🟡 PROVISIONALLY READY (G1 ✅) — closing on #518 CI green for full P1 closure.
**GATE LOG:**
- 2026-05-07 17:41: G1 sim walker — drawer → « Ce que MINT sait de toi » screen renders with shield icon + « Aucune donnée pour l'instant » + helper « Scanne un document ou discute avec le coach pour que MINT commence à te connaître. ». No error state. Screenshot evidence: `verify-05-privacy.png`. W-15 empty-state behavior confirmed.
- 2026-05-07 19:00: 5-auditor expert panel run on P1 (UX / a11y / adversarial QA / engineering wiring / compliance + brand). Reports under `.planning/decisions/p1-audit-2026-05-07/`. Result: 1 P0 new bug surfaced (A02), 4 P1/P2 deferred (A01 hit-test guard, A03 disclosure race, A04 SE overflow, A06 SocketException copy) — auditor recommendation: ship A02 alone, others ride post-TestFlight wave.
- 2026-05-07 19:30: A02 fix shipped — PR #518. `syncAnonymousRemainingFromResponse` helper gates the local count update behind `is int`; absent / malformed payloads no longer write `count = 3 - 0 = 3` and lock the user out. Regression test: 5 cases (present, present-zero rate-limit, absent, absent→present catch-up, non-int). Adjacent service tests still 21/21 green.

### P1 follow-ups (post-TestFlight wave)
- A01: wrap `landing_screen.dart` interactive `FadeTransition` subtrees in `IgnorePointer` while opacity < 1.0
- A03: gate `landing_screen.dart` CTA `onPressed` until `mint_beta_disclosure_seen` flag is set
- A04: wrap landing `Column` in `SingleChildScrollView` for iPhone SE + AAA dynamic type
- A06: add `on SocketException` clause to `coach_chat_api_service.dart` anon path

## P2 — Premier contact (anon chat surprise)
**ACTION CŒUR:** type a prompt with a number, get an answer that anchors against that number, feel « this listens to me ».
**EXIT:** « je gagne 7500 CHF, achat Lausanne 800k » → reply uses 33% rule with user's CHF, no « salaire pas envoyé » framing.
**BUGS LIÉS:** W-03 anon PII scrub ✅ #507, W-09 auth coach footer ✅ #513, W-10 ordre-de-grandeur rule ✅ (auth: #510, anon: #520), W-14 user-message anchor ✅ (auth: #514, anon: #520), **anon-prompt accent compliance** ✅ #520, **anon `intent` prompt-injection vector** ✅ #520.
**PRs MERGED:** #507, #510, #513, #514
**PRs OPEN:** #520 (anon-prompt parity + injection guard) — awaiting CI
**STATUS:** 🟡 PROVISIONALLY READY (G1 ✅) — closing on #520 CI green for full P2 closure.
**GATE LOG:**
- 2026-05-07 17:13: G1 sim walker — auth coach response footer post-fix reads « Réponse via l'API Claude (clé serveur MINT). Ton message est partagé tel quel pour personnaliser la réponse. ». Replaces previous misleading « Ton salaire exact n'est PAS envoyé ». LSFin disclaimer « Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). » still rendered above. Screenshot evidence: `p2-01-after-fix.png`.
- 2026-05-07 19:30: 5-auditor expert panel run on P2. Reports under `.planning/decisions/p2-audit-2026-05-07/`. Convergent finding (UX + compliance + adversarial): the anon discovery prompt was minimal-by-design (T-13-05) but missed the compliance rules that #510 / #514 added on the auth coach. Plus a P0 prompt-injection vector via the `intent` query param.
- 2026-05-07 20:00: Fix shipped — PR #520 ports anon prompt to parity (user-message anchor rule + ordre-de-grandeur + LSFin banned-term enumeration + PII-echo guard + accents 100 % FR), and adds a Pydantic `field_validator` on `intent` (strips `\n\r«»`, caps at 120 chars). 11 new regression tests; adjacent anon-chat suite still 32/32 green.

### P2 follow-ups (post-TestFlight wave)
- a11y P0: chat bubbles need `Semantics(liveRegion: true)` + send `IconButton` `tooltip` (panel auditor 02 — VoiceOver users get silent coach replies)
- typing-indicator unannounced + animates regardless of Reduce Motion
- conversion prompt double `Future.delayed` lacks `mounted` guard (glitchy on slow sim)
- audit-hash `clean_message_for_audit` is dead code on anon endpoint (no Phase 93-01 hook wired)

## P3 — Construction de profil
**ACTION CŒUR:** create an account OR stay in local, fill 5-6 fields (age, canton, archetype, salary), see the profile rendered.
**EXIT:** Mon profil shows 5+ fields, no network error, back button works.
**BUGS LIÉS:** W-07 register back ✅ #508, W-14 « APERÇU FINANCIER » → « MON PROFIL » naming ✅ #517, W-15 mode local empty states ✅ (logged in P1), **W-05 register-screen retirement-first framing** ✅ #521 (CLAUDE.md TOP rule #3 violation), **A03 DOB under-18/over-99** ✅ #521.
**PRs MERGED:** #508, #515 (BYOK menu hidden — partial), #516 (biography Keychain fallback), #517 (MON PROFIL header)
**PRs OPEN:** #521 (W-05 brand fix + A03 DOB validator) — awaiting CI
**STATUS:** 🟡 PROVISIONALLY READY (G1 ✅) — closing on #521 CI green for full P3 closure.
**GATE LOG:**
- 2026-05-07 17:40: G1 sim walker — drawer → tap entry → screen renders with header « MON PROFIL » (no longer « APERÇU FINANCIER »). Empty state: hanger icon + « Aucun profil renseigné » + dark-pill CTA « + Commencer le diagnostic ». W-14 fix confirmed. Screenshot evidence: `verify-04-mon-profil.png`.
- 2026-05-07 20:30: 3-auditor lighter panel run on P3 (engineering wiring / adversarial QA / a11y+compliance+brand combined). Reports under `.planning/decisions/p3-audit-2026-05-07/`. 3 P0 surfaced by adversarial QA (email case-collision, Mon profil empty-state collapse, DOB year-only validator) plus compliance auditor caught W-05 still shipping retirement-first in 6 locales.
- 2026-05-07 21:00: PR #521 ships W-05 (rewrite `authBenefitProjections` × 6 locales: « Projections financières adaptées à tes choix de vie (logement, fiscalité, prévoyance, famille…) ») + A03 DOB fix (`yearsBetween` month/day-aware + picker firstDate now-99 / lastDate now-18). 13 new regression tests (7 DOB + 6 ARB headline). VOICE-14 @meta level fix on `coachTransparencyServer` cherry-picked from #520.

### P3 follow-ups (post-TestFlight wave per panel auditors)
- A01 (P0 data integrity): email case-collision creates duplicate accounts — needs backend `field_validator` lowercase + frontend `.toLowerCase()` + one-shot `UPDATE users SET email = LOWER(email)` migration
- A02 (P0 UX): Mon profil empty state collapses loading + error + truly-empty into single `profile == null` check (`financial_summary_screen.dart:49`); fresh launch flashes empty CTA during async load
- BYOK leak (#515 incomplete): `settings_sheet.dart:43-48` + `coach_chat_screen.dart:1948` still expose entry unconditionally
- a11y double-Semantics on auth fields, login `'Se connecter'` hardcoded breaks i18n in 5 locales

## P4 — PDF Upload ← ACTIVE (Julien blocker, iPhone repro 2026-05-07)
**ACTION CŒUR:** photograph or upload a LPP certificate PDF, see 15 fields extracted, validate.
**EXIT:** select PDF on iOS → upload progresses → 15 fields rendered → confidence +27 → CoachProfile updated → Mon argent reflects new data.
**BUGS LIÉS:** Julien iPhone repro (2026-05-07): « les PDF ne se uploadent pas ». W-11 accents on chips (« prevoyance », « Declaration »).
**PRs:** #512 fix/p4-consent-local-fallback (open, awaiting CI)
**STATUS:** 🟡 IN_FLIGHT — root cause fixed (consent gate Keychain `PlatformException(-34018)` was uncaught in mode local → silent picker fail). PR #512 ships local-mode SharedPreferences-backed consent fallback. Sim walker confirms: tap galerie → ConsentSheet appears → Accepter → iOS Files picker opens. The « Utiliser un exemple de test » path = hardcoded mock (Julien correction 2026-05-07), not real extraction.
**GATE LOG:**
- 2026-05-07 16:40: P4 opened. iPhone walk Julien: PDF upload silent fail. Diagnostic launched via sim walker on staging build.
- 2026-05-07 16:42: G1 sim walker — repro: tap « Depuis la galerie » → no UI change, no error, no log. Confirmed Julien iPhone bug.
- 2026-05-07 16:50: Root cause via debug-print injection — `_authHeaders` Keychain read raises `PlatformException(-34018)` on fresh sim, ConsentService catch only handled `ApiException`, exception silently swallowed.
- 2026-05-07 16:55: Fix applied — `_LocalConsentStore` SharedPreferences-backed, `list()`/`grant()` catch `PlatformException` Keychain codes, fall back to local. Sim walker: ConsentSheet appears + iOS Files picker opens after Accepter.
- 2026-05-07 17:00: G4 — 7/7 unit tests pass; flutter analyze clean. PR #512 opened.

### P4 follow-ups (NOT in #512, separate scope)
- Push real `cpe_plan_maxi_julien.pdf` into sim Files for full extraction round-trip (G2 deep gate). Sim limitation: « On My iPhone » provider is empty by default; need to either declare `UIFileSharingEnabled` on Runner.app + drop PDF in Documents, OR use iCloud Drive provider.
- W-11 accents on Scanner chips (« prevoyance » → « prévoyance », « Declaration » → « Déclaration ») — separate ARB-only PR.
- Refactor `ApiService` to accept injectable `http.Client` for proper unit-test of 401 → fallback path. Tracked here as a Phase 95+ test infra evolution.

## P5 — Mon argent (Cap + benchmarks)
**ACTION CŒUR:** see a useful chiffré summary (projected capital, fiscal margin, canton benchmark gap).
**EXIT:** post-upload → Mon argent shows values aligned with profile + ConfidenceBadge.
**STATUS:** ⚪ PENDING (gated on P4)
**GATE LOG:** —

## P6 — Coach authentifié end-to-end
**ACTION CŒUR:** ask a complex question, coach answers with memory of previous turn, tone adjustable.
**EXIT:** logged-in coach → persona toggle accessible from menu → tone changes the answer → memory persists cross-session.
**BUGS LIÉS:** W-13 persona toggle inaccessible (Phase 91-01 façade) — `/settings/coach-tone` route exists but no menu entry.
**STATUS:** ⚪ PENDING
**GATE LOG:** —

## P7 — Explorer 18 life events
**ACTION CŒUR:** drill-down a life event (e.g. Logement → simulator achat) without dead-end.
**EXIT:** 6 cards Explorer → tap each → screen renders with ConfidenceBadge, no crash.
**STATUS:** ⚪ PENDING
**GATE LOG:** —

---

## Active perimeter pointer

**Currently active: P4 — PDF Upload (awaiting #512 CI green = G3, then G2 deep round-trip + G5 lint)**

Status as of 2026-05-07 21:00:
- P1 🟡 PROVISIONALLY READY (G1 ✅, A02 fix #518 awaiting CI; W-12 BYOK out-of-scope)
- P2 🟡 PROVISIONALLY READY (G1 ✅, anon prompt parity + injection guard #520 awaiting CI)
- P3 🟡 PROVISIONALLY READY (G1 ✅, W-05 brand fix + A03 DOB validator #521 awaiting CI)
- P4 🟡 IN_FLIGHT — PR #512 awaiting CI; sim walker confirms galerie → ConsentSheet → Files picker chain
- P5/P6/P7 ⚪ PENDING

PRs opened this session (4):
- #518 fix(anon-chat) prevent permanent lockout when 200 OK drops `messagesRemaining` (P1-A02)
- #519 docs PERIMETERS audit log + 2026-05-07 sim verification round
- #520 fix(anon-chat) port auth-coach compliance rules + guard `intent` against prompt injection (P2)
- #521 fix(p3) W-05 register-screen brand framing + A03 DOB validator (under-18 guard)

Next-up sequence (when P4 closes):
- P4 → P5 (gated post-PDF round-trip) → P6 (W-13 persona toggle wiring) → P7 (Explorer drill-downs)

Outstanding G2/G3/G5 sweeps for P1/P2/P3 batch when device walker schedule allows. P1+P2+P3 device-equivalent G2 walker can be folded into a single pass since they share the cold-launch → drawer → coach → profile chain.

This sequence is updated only when an active perimeter closes (G1-G5 all green) or when Julien explicitly re-orders.
