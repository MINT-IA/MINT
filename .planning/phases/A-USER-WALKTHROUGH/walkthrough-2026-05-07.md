# Device Walkthrough — 2026-05-07

**Sim:** iPhone 17 Pro (B03E429D-0422-4357-B754-536637D979F9), booted
**Build:** ch.mint.app from `apps/mobile/build/ios/iphonesimulator/Runner.app`
**Backend:** https://mint-staging.up.railway.app (verified UP via `/api/v1/health`)
**Driver:** idb (logical points) + xcrun simctl (screenshots)
**Branch:** feat/phase-A-e2e-unblock @ 2238237a

## Bugs observed

### BUG-W2026-01 — debug build hits localhost (not staging)
**Severity:** P0 walker UX (blocks anonymous chat end-to-end)
**Repro:** Build with `flutter build ios --simulator --debug --no-codesign` →
install → tap "Parle à Mint" → tap a chip → tap send → app shows
"Pas de réseau. Vérifie ta connexion et réessaie."
**Root cause:** [api_service.dart:106-114](apps/mobile/lib/services/api_service.dart#L106-L114)
restricts staging/prod URL candidates to `kReleaseMode`. Debug builds only
have `http://localhost:8888/api/v1` in the candidate list. App logs:
`Connection refused, address = localhost, port = 61309`.
**Fix options:**
- (a) build with `--release --no-codesign` (what real testers will run)
- (b) build with `--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`
- (c) docs change: walker.sh and the device-walkthrough memory reference must
  call this out so future agents don't waste a debug-build iteration
**Status:** retrying with release build (background bgb1b5ac4)

### BUG-W2026-02 — beta disclosure « En savoir plus » → opens Safari + Welcome to Safari Start Page
**Severity:** P2 onboarding hygiene (kicks user out of app)
**Repro:** Cold launch → beta disclosure sheet → tap « En savoir plus »
**Observed:** Safari opens at `mint.ch` start page (no actual destination article).
**Risk:** journalist/tester perception — onboarding sheet should not boot users
into an external browser, especially with no guarantee the destination loads.
**Fix:** either (a) make « En savoir plus » open an in-app modal with the
detail copy, or (b) point the link to a real article before launch, or
(c) drop the link until there's content.
**Status:** noted, fix deferred to bug-fix loop after happy-path walkthrough.

### BUG-W2026-03 — anon-chat PII scrub blocks user salary from LLM ✅ FIXED
**Severity:** P0 personalization (defeats the point of an anon chat that "écoute")
**Status:** PR #507 (`fix/anon-chat-strip-pii-from-llm-input`) opened against `dev` — branch `913a5d78`.
**Root cause:** `services/backend/app/api/v1/endpoints/anonymous_chat.py:299` applied `_scrub_pii(body.message)` and passed the scrubbed text to `orchestrator.query(question=...)`. So « 7500 CHF » → « [***] » before the LLM saw it. The scrub belongs on the audit-log hash (Phase 93-01 OAR-G art. 24, 10y retention) and any future Sentry / Anthropic log surface, NOT on the live LLM input.
**Fix:** pass `body.message` (raw) to the orchestrator; keep `_scrub_pii(body.message)` as `clean_message_for_audit`. 2 regression tests added.

### BUG-W2026-04 — RESCINDED (false positive)
The back arrow was scrolled out of view temporarily (the chat list scrolls including the header in this layout), not unmounted. Verified via `idb ui describe-all` after re-opening anon chat — Button « Retour » @ y=90 is reliably present. No fix needed.

### BUG-W2026-05 — Register screen retirement-first framing (CLAUDE.md règle 3)
**Severity:** P3 brand/positioning
**Repro:** Login → « Créer un compte » → register screen.
**Observed:** « Pourquoi créer un compte ? » bullets list:
  1. « Projections AVS/LPP alignées à ta situation »
  2. « Coach personnalisé avec ton prénom »
  3. « Sauvegarde cloud + synchronisation multi-appareils »
**Why it's a bug:** CLAUDE.md règle 3 says MINT ≠ retirement app, 18 life events equally weighted. The first bullet is AVS/LPP — pure retraite. The 18 life events should at minimum NOT lead with retraite. Suggest reword: « Projections financières alignées à ta situation (AVS/LPP, achat immobilier, fiscalité, charges courantes…) ».
**Fix:** ARB strings under `apps/mobile/lib/l10n/app_*.arb` for the register screen. 6-locale parity.

### BUG-W2026-06 — idb / iOS first-tap eats first chars in TextField (test infra, not product)
**Severity:** test-infra only — does NOT happen for human users.
**Repro:** `idb ui tap` on a TextField immediately followed by `idb ui text "Walker..."` → first ~3 chars dropped. Email field showed `kthrough+...` instead of `walkthrough+...`.
**Workaround:** `sleep 0.3` after the tap, OR re-tap to confirm focus before typing. Document in walker.sh next time it's edited.
**Status:** noted, no source-code change needed.

### Observations (not bugs, design feedback)
- Landing has lots of vertical white space between MINT logo and the « Voir clair, décider seul. » hero. Intentional? Could feel sparse to a first-time tester.
- Anonymous chat empty-state: 3 chips visible, third (« Je veux y voir clair ») is clipped on the right edge of the iPhone 17 Pro screen.
- Chip behavior: tapping a chip prefills the input field but does NOT auto-send. Could be intentional (Cleo lets you edit before sending), but worth noting in usability tests — some users expect the chip to send directly.

### BUG-W2026-07 — Register screen has no persistent top-bar / back button
**Severity:** P1 navigation (user typing into form has no obvious way to back out without scrolling 9 fields down)
**Repro:** Login screen → tap « Créer un compte » → register screen.
**Observed:**
- No `AppBar` / no top-left back arrow / no swipe-from-edge back gesture.
- Only the « Retour » button at the very bottom of the page (after email + prénom + DOB + password + confirm + 4 checkboxes + 2 CTAs).
- iOS edge-swipe-back also disabled (testing confirmed).
- accessibility tree exposes `Button "Retour"` at frame `(0,0)` — placed but invisible / off-canvas.
**Fix candidate:** add a leading `IconButton(Icons.arrow_back, onTap: context.pop)` in the register screen `AppBar` (or `Scaffold.appBar`). Match the pattern used by other auth screens.

### BUG-W2026-08 — Anon chat history (client-side) keeps the scrubbed `[***]` marker
**Severity:** P2 UX (user sees their own message redacted in the timeline)
**Repro:** Anon chat → type « Je gagne 7500 CHF par mois… » → send → go home → see « MAI 2026 → Conversation: Je gagne [***] par mois et je veux acheter un a… »
**Side-effect of:** BUG-W2026-03 (now fixed in PR #507) — the client stores whatever the backend echoes back in the response payload. If the backend now keeps the raw text in the response message (which it does post-fix), this should auto-resolve. Verify after #507 merges to staging.

### BUG-W2026-09 — Auth coach footer claims « salaire exact PAS envoyé » while user typed it
**Severity:** P1 product tension (privacy vs personalisation)
**Repro:** Coach tab (mode local) → type « Mon salaire est 9500 CHF. Suis-je en mesure d'acheter un appartement Lausanne pour 850000 CHF? » → send.
**Observed:**
- Footer reads: « Réponse via ton API Claude. Ton salaire exact n'est PAS envoyé — seuls ton âge, canton et archetype sont partagés. »
- Coach response says « semble que l'information n'ait pas été transmise correctement. Mais voici un angle mort surprenant : à Lausanne, la règle tacite veut qu'on ne dépasse pas 33%... » then back-calculates 6'600 CHF brut/mois needed and says « partage ton salaire mensuel brut et je te traduis ce que ça signifie concrètement ».
- The user just typed « 9500 CHF » in plaintext yet the coach pretends it didn't see it.
**Why it's a product call, not just a bug:** the privacy-by-default framing is intentional (« seuls ton âge, canton et archetype »). But the UX is dissonant when the user shares a number in the chat box. Three options:
  - (a) Tell the LLM to use in-message numbers even though they're not in the structured profile (relax the privacy framing for the in-conversation surface)
  - (b) Show an upfront warning when the user types a CHF amount: « Ton chiffre reste sur ton appareil. Si tu veux qu'on le prenne en compte pour cette réponse, coche : [partager pour cette session uniquement] »
  - (c) Display the disclaimer BEFORE the user types, not after.
**Status:** product call required from Julien — not in the autonomous-fix wave.

### BUG-W2026-10 — Auth coach response: Lausanne median rent claim « 2'200 CHF pour 3,5 pièces » uncited
**Severity:** P2 banned-terms-adjacent / data hygiene
**Repro:** see W-09 reproducer.
**Observed quote:** « la médiane des loyers pour un 3,5 pièces tourne autour de 2'200 CHF ». No citation, no qualifier (« ordre de grandeur »), no source. The system prompt at `anonymous_chat.py:144` requires « Si tu cites un chiffre Suisse non present ci-dessus (taux d'imposition cantonal, prelevement anticipe, etc.), encadre-le explicitement comme « ordre de grandeur » et n'avance jamais une valeur exacte sans la qualifier. ». This was an auth coach response, not anon — different prompt, but same compliance principle.
**Verify:** `services/backend/app/services/coach/claude_coach_service.py` system prompt — does it carry the same « ordre de grandeur » rule? If not, port it.

### Observations from authenticated coach + tabs
- ✅ « Aujourd'hui » dashboard surfaces hero card « Parle-moi de toi → Ouvrir le coach », gamified timeline (« Première conversation ✓ → Engagement en cours → Ton avenir financier »), and conversation history. Solid empty-state.
- ✅ « Mon argent » : 2 cards (Ton budget ce mois → Commencer / Ton point de départ → Scanner). Clean. No retirement framing.
- ✅ « Coach » empty state: « Salut. Moi c'est Mint. Je te connais. Je vois ce qui vient. Je te guide. Par quoi on commence ? » + 4 humanized chips. Excellent.
- ✅ « Explorer » : 6+ cards in 2×N grid covering Retraite & Prévoyance / Famille / Travail & Statut / Logement / Fiscalité / Patrimoine & Succession (+ Santé scrolled). 18-life-events surface honored — « Retraite » is ONE of six, not THE central card.

## Bug ledger snapshot (P-prio sorted)

| ID | Severity | Status | Where | One-liner |
|----|----------|--------|-------|-----------|
| W-01 | P0 walker UX | Workaround applied | walker doc | Debug build → localhost; fix = `--dart-define=API_BASE_URL=…` |
| W-03 | P0 product | ✅ Fixed PR #507 | `anonymous_chat.py` | PII scrub was eating user salary before LLM |
| W-09 | P1 product | Awaiting Julien decision | `claude_coach_service.py` | Auth coach claims « salaire pas envoyé » while user typed it |
| W-07 | P1 nav | To fix | register_screen.dart | No persistent back button |
| W-10 | P2 compliance | To verify | `claude_coach_service.py` | Uncited Swiss median quote |
| W-08 | P2 UX | Auto-resolve via #507 | client storage | History shows `[***]` |
| W-02 | P2 onboarding | To fix or drop | beta disclosure sheet | « En savoir plus » → Safari mint.ch start page |
| W-05 | P3 brand | To fix | register_screen ARBs | « AVS/LPP » first bullet → retirement-first framing |
| W-04 | n/a | RESCINDED | — | back-arrow scrolls with content, not removed |
| W-06 | n/a | Test infra only | walker.sh / idb | First-tap drops first chars in TextField |

## Next: parallel fix wave
- W-07 + W-05 + W-02 fixable in parallel (3 dedicated branches).
- W-09 needs Julien product call.
- W-10 needs read of auth coach system prompt before deciding.

---

## Verification round — 2026-05-07 17:13–17:41 (post-fix sim sweep)

After PRs #507 / #508 / #509 / #510 / #512 landed and the W-09 footer copy + W-14 header rename shipped, ran a sim sweep to confirm exit clauses on P1, P2, P3, P4. All four perimeters now provisionally ready (G1 closed); G2/G3/G5 batched for the next device walker pass.

| Perimeter | Bug verified | Evidence | Outcome |
|---|---|---|---|
| P2 | W-09 auth coach footer copy | `screenshots/2026-05-07/p2-01-after-fix.png` | ✅ Footer reads « Réponse via l'API Claude (clé serveur MINT). Ton message est partagé tel quel pour personnaliser la réponse. ». LSFin disclaimer rendered above. No more « salaire pas envoyé » dissonance. |
| P3 | W-14 « APERÇU FINANCIER » → « MON PROFIL » | `screenshots/2026-05-07/verify-04-mon-profil.png` | ✅ Header reads « MON PROFIL ». Empty state: hanger icon + « Aucun profil renseigné » + CTA « + Commencer le diagnostic ». |
| P1 | W-15 « Ce que MINT sait de toi » empty state | `screenshots/2026-05-07/verify-05-privacy.png` | ✅ Shield icon + « Aucune donnée pour l'instant » + helper « Scanne un document ou discute avec le coach pour que MINT commence à te connaître. ». No error state. |
| P4 | Galerie consent flow | `screenshots/2026-05-07/p4-11-after-accepter.png` | ✅ Tap galerie → ConsentSheet appears → Accepter → iOS Files picker opens (Recents tab, « No Recents » empty state). Picker chain restored post-PR #512. |

### Outstanding gates for the 4 verified perimeters
- **G2** (device-equivalent walker) — fold P1 + P2 + P3 into a single cold-launch → drawer → coach → profile pass.
- **G3** (CI green on dev) — P4 #512 in-flight; P1/P2/P3 PRs already merged on dev.
- **G5** (LSFin + accent + ARB lint) — needs a final sweep on the W-09 footer ARB strings + W-14 header strings × 6 locales.

### Operational note (image budget)
The Codex session that started this walkthrough crashed at 17:41 on the « many-image dimension limit ». Hardened `feedback_screenshot_budget.md` 2026-05-07 to enforce ≤3 PNG reads per session and prefer `idb ui describe-all` for text/state verification. PNGs are still captured to disk under `.planning/phases/A-USER-WALKTHROUGH/screenshots/2026-05-07/` for audit, just not Read back into context unless one of the 4 trigger conditions fires.
