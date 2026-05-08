# P2 — UX / Conversation-design audit (anon chat surprise)

**Date:** 2026-05-07
**Auditor:** Senior UX / conversation designer (panel role 1/n)
**Scope:** P2 perimeter — anon chat number-anchoring + « listens to me » feel
**Branch read:** `docs/walkthrough-perimeters-2026-05-07` (1 commit ahead of `origin/dev`, no code drift)
**Method:** static read of code + ARB + recent diffs (#507 / #510 / #513 / #514). No PNG reads (Julien screenshot budget). No code edits.

---

## Verdict

**FLAG.** P2 is provisionally ready against G1 (sim walker on #514 evidence) but the
audit surfaces one P0 prompt-coverage gap, two P2 conversation-design issues and
two P3 polish notes. None blocks TestFlight ship-path; the P0 should ship before
P2 is declared CLOSED.

## G-mapping (P2 perimeter gates)

| Gate | Status | Note |
|---|---|---|
| G1 sim walker | ⚠️ | Walker evidence in `PERIMETERS.md` confirms footer copy + 33% framing for the **authenticated** coach (covered by #513 + #514). No equivalent walker run logged for the **anon** path with a CHF amount post-#507; that's where the exit clause actually lives. |
| G3 dev CI | ✅ | All four PRs (#507, #510, #513, #514) green and merged on `origin/dev` per `git log`. |
| G4 regression | ✅ | 4 dedicated tests in `test_claude_coach_user_message_numbers_rule.py`; 5 tests in `coach_transparency_server_parity_test.dart`. No regression flagged. |
| G5 LSFin + accent + ARB lint | ⚠️ | Footer copy ARB key `coachTransparencyServer` parity verified across 6 locales by #513's parity test. **However**, the anon system prompt at `anonymous_chat.py:101-133` is unaccented ASCII (« decouverte », « personnalisee », « rassurant ») — the prompt itself isn't user-facing so accent_lint_fr.py rightly skips it, but it sets a tone-prior that the LLM will partially mirror. |

---

## Findings

### F-01 (P0) — #514's anchor rule lives in the **authenticated** coach prompt only; the **anon** prompt does NOT instruct the LLM to anchor on user-typed numbers.

**Path:** `services/backend/app/api/v1/endpoints/anonymous_chat.py:84-135`
**What I expected:** an explicit rule in `build_discovery_system_prompt()` that says « les chiffres tapés par l'utilisateur dans le message courant DOIVENT ancrer la réponse ; ne jamais répondre "je ne peux pas voir ton salaire" ou "l'information n'a pas été transmise correctement" ».
**What I found:** the discovery prompt's only data-related lines are :

> « Tu ne sais rien sur elle. Tu ne disposes d'aucune donnee personnelle. »

This is the exact framing that caused W-09 in the auth coach: the LLM reads « tu ne disposes d'aucune donnée » and concludes that user-typed CHF amounts are also off-limits. PR #514 patched **`claude_coach_service.py`** (auth path) but left `anonymous_chat.py` unchanged. The P2 perimeter exit clause — « je gagne 7500 CHF, achat Lausanne 800k → reply uses 33% rule with user's CHF » — runs through **anon chat**, not auth coach.

**Evidence the gap is real:** PR #507's PII-scrub fix (commit `49a45fd6`) explicitly comments:
> « The LLM responded « je ne peux pas voir ton salaire (il apparaît masqué) » when the user had just stated « Je gagne 7500 CHF » in plain text. »

Even after #507 stops the pre-LLM scrub, the prompt itself still primes the LLM to ignore in-message numbers because line 105 negates personal-data possession in absolute terms.

**Severity:** P0 — without this rule, the P2 EXIT clause can still fail intermittently on Sonnet/Haiku stochasticity. The auth-coach test suite would not catch it (different prompt builder). This is the single most material flaw in the perimeter.

**Top fix:** port the 9-line `_BIOGRAPHY_AWARENESS` clarifier from #514 into `build_discovery_system_prompt()` *before* the rule list, plus add 2 regression tests in `services/backend/tests/api/test_anonymous_chat.py` mirroring `test_claude_coach_user_message_numbers_rule.py`.

---

### F-02 (P1) — Empty-state opener does not nudge toward giving a number.

**Path:** `apps/mobile/lib/l10n/app_fr.arb:11348` + chips at `:11352-11361`
**Current copy:**
- Opener: « Salut. Dis-moi ce qui te trotte en tête côté finances en ce moment — un projet, une question, un truc flou. »
- Chip 1: « J'ai un projet d'achat »
- Chip 2: « Je change de boulot »
- Chip 3: « Je veux y voir clair »

The exit clause — « anchor against the user's CHF » — only fires if the user *types a number*. None of the 3 chips primes for that, and the opener stays at the « projet / question / flou » abstraction layer. Cleo's design DNA (per Cleo 3.0 launch coverage, [businesswire 2025-07-29](https://www.businesswire.com/news/home/20250729690058/en/Cleo-Becomes-the-First-AI-Money-Coach-That-Speaks-Thinks-and-Remembers)) leans on memory + life-context capture; one of the three chips should bias toward « I have X CHF / I earn X » so the surprise-with-the-number moment fires more often than 1/n sessions.

**Severity:** P2 — this is a conversion / retention lever, not a correctness bug. Adding a fourth chip (4th would clip on iPhone 17 Pro per W-2026 observation lines 64-66) is risky; replacing chip 3 (« Je veux y voir clair » is genericity-bait) with « Je gagne X par mois, est-ce assez pour acheter ? » is the move.

---

### F-03 (P2) — Footer transparency copy is brand-aligned but jargon-leaks « API Claude ».

**Path:** `apps/mobile/lib/l10n/app_fr.arb:10483` (ARB key `coachTransparencyServer`)
**Current copy:** « Réponse via l'API Claude (clé serveur MINT). Ton message est partagé tel quel pour personnaliser la réponse. »

What works:
- ✅ Honest (matches #513's exit clause).
- ✅ Replaces the misleading « salaire pas envoyé ».
- ✅ Tutoie matches MINT voice.

What's brittle:
- « API Claude » is leaky brand exposure — most users have no idea what that means; the few who do will know it's Anthropic and may form a privacy posture from the brand alone.
- « clé serveur MINT » is internal jargon. The user doesn't pay for it, doesn't see it, and doesn't choose it. It's housekeeping noise. (The auditable answer to « who pays for this? » belongs in the legal page, not the chat footer.)
- « partagé tel quel » lands harsh on a calm/precis/fin/rassurant brand voice — the word « tel quel » sounds defensive.

**Severity:** P2 — the footer is functional, just not yet the polished version. Suggest:
> « Réponse générée par MINT en utilisant ton message tel que tu l'as écrit, pour personnaliser la lecture. »
or even shorter:
> « Réponse personnalisée à partir de ton message. »

This audit is read-only; copy revision belongs in a follow-up perimeter polish PR.

---

### F-04 (P2) — Conversion prompt timing is brittle on rate-limit boundary; the 800ms + 600ms hardcoded delays + auth-gate sequence can stack visually.

**Path:** `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:269-287`
**Code path:** when `messagesRemaining == 0`, the screen waits 800ms, appends the conversion bubble, persists, waits another 600ms, then calls `_showAuthGate()`.

What's good:
- ✅ Conversion copy (`anonymousChatConversionPrompt`: « On a déjà découvert 3 choses ensemble. Si tu veux que je m'en souvienne… ») is paced and hooks on memory — exactly the right brand mechanism. Aligns with Cleo 3.0's memory-as-feature framing.
- ✅ Delay before bottom sheet lets the user actually read the conversion prompt.

What's brittle:
- The conversion prompt is rendered as an assistant bubble **after** a real coach reply on turn 3. The user sees: turn-3 coach reply → 800ms blank → conversion bubble → 600ms blank → auth-gate sheet. On a slow simulator + screen reader, that 1.4s stack reads as glitchy. A single visual anchor (e.g. dimming the message list while the bottom sheet animates in, instead of two scheduled `Future.delayed`s) would feel more intentional.
- No `mounted` guard between the two delays — the second `if (mounted)` only gates the gate-show, not the persist. Edge case: user backs out during the 800ms window → conversion bubble persists into the conversation history. Not a crash, just stale state on next cold-restore.

**Severity:** P2 — UX polish, not a correctness bug. Track but don't block.

---

### F-05 (P3) — Error-state copy is good but the « unknown » bucket still routes to the generic ARB fallback.

**Path:** `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:226-243` + `app_fr.arb:11384-11399`
The `errorType` switch maps `network`, `service`, `session` to dedicated ARBs and falls through to `anonymousChatError` (« Je rencontre un problème technique. Réessaie dans un instant. »). That's correct and brand-aligned. **Minor:** the dispatcher in `coach_chat_api_service.dart:236-244` maps HTTP 400 (« invalid session ») to errorType `'session'` and HTTP 503/5xx to `'service'` — but a 401 (e.g. auth gate misfires from a stale session header) would land in `unknown`. Not a blocker, but worth a unit test.

**Severity:** P3 — defensive polish.

---

## Top fix

**Port #514's user-message-anchor rule from `claude_coach_service.py` into `anonymous_chat.py:build_discovery_system_prompt()` + add 2 regression tests; the P2 EXIT clause runs through anon chat, not auth coach.**

(28 words.)

---

## Cleo / Charlie / Bridgit benchmark notes

Single WebSearch reference per audit constraint. Cleo 3.0 (launched 2025-07-29, [Yahoo Finance](https://finance.yahoo.com/news/cleo-becomes-first-ai-money-130000784.html)) emphasizes:
- Memory-of-conversation as the conversion lever (matches MINT's `anonymousChatConversionPrompt` mechanism — strong alignment).
- Voice + emoji + persona-driven warmth (MINT explicitly avoids emoji and persona-comedy per brand voice; intentional differentiation, not a gap).
- Hyper-personalization « considers behavioral patterns + life goals + financial data » — MINT mirrors this through the 18 life events + archetype × stress matrix; the anon chat is the **wedge** into that engine, so number-anchoring on first contact is the high-leverage moment Cleo capitalizes on most aggressively. F-01 is a direct gap against that benchmark.

---

## What's NOT broken (confirmed by static read)

- ✅ PII scrub correctly moved off the LLM input in `anonymous_chat.py:252` (#507 verified at the source).
- ✅ Empty input: `_sendMessage()` early-returns on `trimmed.isEmpty` (line 190).
- ✅ Send-flow latency: 30s timeout + ClientException + TimeoutException all map to `network` errorType.
- ✅ Conversion prompt is exactly once per session (3rd response gate) and persists to `ConversationStore` so cold-restore brings it back.
- ✅ Cold-open opener fade-in is animation-controller-backed, not a setState loop.
- ✅ Chips visibility predicate (`_messages.length <= 1 && !_isAuthGateLocked`) is correct — they hide as soon as user sends, no auto-send.
- ✅ Auth-gate dismissal locks input but preserves conversation (panel §4 spec).
- ✅ ARB parity for the anon chat surface (12 keys, all 6 locales — implied by #513 parity test machinery; not directly re-verified here).

---

## Sources

- [Cleo Becomes the First AI Money Coach That Speaks, Thinks and Remembers — businesswire 2025-07-29](https://www.businesswire.com/news/home/20250729690058/en/Cleo-Becomes-the-First-AI-Money-Coach-That-Speaks-Thinks-and-Remembers)


## Counter-arguments and data gaps

This artifact was synthesised from a single audit pass on 2026-05-07 — it benefits from a healthy dose of skepticism :

- **Sample-of-one bias** : the verdict is driven by one walk on one device (iPhone 17 Pro sim). On real devices, network conditions, OS variants, accessibility settings, or carrier prompts may surface failure modes this pass did not exercise.
- **Confirmation bias risk** : the panel was looking for the bugs from the prior session ; positive findings (« looks fine ») were not stress-tested with adversarial inputs in the same depth as the negative findings.
- **Data gap — production telemetry** : we have no Sentry / staging logs cross-reference for this perimeter ; conclusions about « no regression » are based on absence of visible UI errors, not on instrumentation.
- **Data gap — second reviewer** : no independent re-walk by a second human or sim has corroborated the verdict. Treat as a working hypothesis, not a final ruling, until the next walker run.
- **Counter-argument worth holding** : the « PASS » on items relying on best-effort fallbacks (keychain, biography, consent) hides the fact that the fallback path is the *real* code path on the sim — production-iOS behavior may differ. Prefer running on a real device before claiming the panel is closed.
