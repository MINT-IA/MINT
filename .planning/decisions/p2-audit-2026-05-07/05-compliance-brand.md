# P2 — Premier contact (anon chat surprise) — Compliance + Brand audit

**Date:** 2026-05-07
**Auditor:** Senior Swiss compliance + brand-positioning lens (LSFin/FINMA + post-2026-04-12 lucidité pivot)
**Scope:** P2 perimeter only (anonymous chat surface — landing CTA → chips/opener → 3 turns → conversion gate)
**Inputs read:**
- `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` (842 lines)
- `services/backend/app/api/v1/endpoints/anonymous_chat.py` (310 lines)
- `services/backend/app/services/coach/anonymous_eclairage_prompt.py` (59 lines)
- `services/backend/app/services/coach/claude_coach_service.py` (lines 520–600 — auth coach side, used by W-09 footer + W-10 ordre-de-grandeur cross-reference)
- ARB parity sweep: `app_{fr,en,de,es,it,pt}.arb` for 14 P2 keys + 2 transparency keys (29/29 each locale)
- `docs/AGENTS/swiss-brain.md` §1 banned terms · §11 voice
- `docs/VOICE_SYSTEM.md` §1–4 pillars + tone matrix
- `tools/checks/banned_terms_arb.py` and `tools/checks/accent_lint_fr.py` runs

---

## Verdict: FLAG

P2 user-facing copy ships clean. Compliance/brand violations are confined to **backend Python source**: ASCII-stripped accents inside the anon system prompt + 4 HTTPException `detail` strings exposed to the user verbatim. No P0 banned-term hit, no retirement-first framing, no PII echo guard MISSING — but an explicit echo guard SHOULD be added since the P2 prompt now sees raw salary post-#507. ARB parity 6/6 locales for the #513 footer copy.

## G-mapping (P2)

| Gate | Status | Notes |
|---|---|---|
| **G1** sim walker | ✅ | Walker confirmed footer reads `coachTransparencyServer` post-#510 (PERIMETERS log 17:13). |
| **G3** CI dev | ⚠️ | Not directly tested here; #507 / #510 were merged to dev per perimeter log. |
| **G4** regression tests | ⚠️ | `pytest -q services/backend` not run in this audit (read-only scope). Recommend adversarial test for echo-guard before TestFlight. |
| **G5** LSFin + accent + ARB lint | ❌ | `tools/checks/banned_terms_arb.py` PASS (6 locales clean, 0 hits on 16 P2 keys). `tools/checks/accent_lint_fr.py` FAIL — 282 violations repo-wide; **for P2 surfaces specifically:** zero ARB violations, but ≥30 backend Python violations on the anon system prompt strings + 1 in HTTPException detail. ARB parity 6/6 ✅. |

---

## Findings table

| # | Dimension | Path:line | Violation | Severity |
|---|---|---|---|---|
| F1 | Accent (FR) — backend prompt | `services/backend/app/api/v1/endpoints/anonymous_chat.py:102-135` | The entire `build_discovery_system_prompt()` is ASCII-stripped: `decouverte`, `donnee`, `Reponds`, `precis`, `Regles`, `Tutoie`, `specifique`, `Reponse`, `recommandation`, `certitude`, `comparaison sociale`, `prescriptif`, `eclairage`, `point de depart`, `concrete`, `traduction`, `surprenante`. The LLM receives accent-broken French as its system prompt, increasing risk of accent-broken output. CLAUDE.md TOP-rule #2 (« ASCII = bug ») applies to source-of-truth files that drive user-facing output. | **P1** |
| F2 | Accent (FR) — error detail | `anonymous_chat.py:239` | `"Limite atteinte. Cree un compte pour continuer."` — `Cree` instead of `Crée`. This is sent verbatim to the client as the `detail` of a 429 HTTP exception (user-visible if the front maps `detail` to a toast). | **P1** |
| F3 | Accent (FR) — error detail | `anonymous_chat.py:216` | `"Session anonyme requise. Envoie le header X-Anonymous-Session."` — surfaces an internal header name to a French-speaking user. Not a banned-term issue but breaks voice (technical leak). | P2 |
| F4 | PII echo guard MISSING in anon prompt | `anonymous_chat.py:120-133` (rules block) | Post-#507 the LLM now sees raw user message including unredacted salary/IBAN/AVS-like patterns. The prompt lists 7 negative rules (no product, no return promise, etc.) but does NOT instruct the LLM to **avoid echoing back the PII verbatim** in its reply. Risk: model writes « Avec ton IBAN CH93… tu peux… » or repeats « tu gagnes 7'500 CHF » in the response, which then ends up in the audit-log hash via the response side. The auth coach prompt (`claude_coach_service.py:786 comment`) acknowledges privacy but the anon prompt has no operational rule. | **P1** |
| F5 | Ordre-de-grandeur rule MISSING in anon prompt | `anonymous_chat.py:120-133` | The auth coach prompt (`claude_coach_service.py:543-553`) carries the panel-locked ordre-de-grandeur rule (rule #6), explicitly listing « médiane de loyer cantonal/communal », « taux d'imposition », « médiane salariale ». The anon prompt has none. Probe « la médiane des loyers à Lausanne est 2'200 CHF » would pass through unqualified. PERIMETERS log marks W-10 `✅ #510` for **the auth coach** — the fix never landed on the anon coach. This is the same compliance principle the panel locked, only the anon surface was forgotten. | **P0** |
| F6 | LSFin disclaimer BREVITY in anon prompt | `anonymous_chat.py:120-133` | The anon prompt does not require the response itself to mention the LSFin educational-purpose disclaimer. The disclaimer is only rendered above the input bar (UI surface). For an anon user about to read 3 turns and bounce, having the model add « (à titre indicatif) » at least once would close the loop. Currently the rule « jamais de promesse de rendement » exists but no positive instruction. | P2 |
| F7 | Banned-term **list** not literal in anon prompt | `anonymous_chat.py:120-133` | Auth prompt explicitly lists « garanti », « certain », « assuré », « sans risque », « optimal », « meilleur », « parfait » (claude_coach_service.py:532-534). Anon prompt only says « jamais de langage absolu ou prescriptif » + « jamais de promesse de rendement ». A model jail-broken via intent injection could produce « optimal » without violating the abstract rule. Port the literal banned-term list. | **P1** |
| F8 | Brand framing — chips & opener | `app_fr.arb:11348-11361` | ✅ PASS. Opener « Salut. Dis-moi ce qui te trotte en tête côté finances en ce moment — un projet, une question, un truc flou. » is generic. Chips « J'ai un projet d'achat / Je change de boulot / Je veux y voir clair » map to housing/career/general — NO retirement-first chip. Honors CLAUDE.md TOP-rule #3. | — |
| F9 | Brand framing — system prompt | `anonymous_chat.py:102-107` | ✅ PASS. System prompt frames MINT as « compagnon de lucidité financière suisse » (with accent caveat F1). No retirement-first language. Aligns with 2026-04-12 pivot. | — |
| F10 | Voice alignment — opener tone | `app_fr.arb:11348` | ✅ PASS against VOICE_SYSTEM.md §1: tutoiement, calme, court (1 phrase + 3 examples), pas de jargon, pas d'urgence. « truc flou » = informel mais pas familier. | — |
| F11 | Voice alignment — error states | `app_fr.arb:11384-11397` | ⚠️ « Je rencontre un problème technique » + « Je suis temporairement indisponible » use first-person Mint voice. Solid. « Session expirée. Ferme et rouvre l'app pour continuer. » breaks voice (technical/imperative). VOICE_SYSTEM tone-matrix « Erreur technique » prescribes « Quelque chose n'a pas marché. On réessaie ? » — softer. | P2 |
| F12 | Banned-term scan — auth coach footer #513 | `app_fr.arb:10482-10483`, all 6 locales | ✅ PASS. `coachTransparencyServer` (« Réponse via l'API Claude (clé serveur MINT). Ton message est partagé tel quel pour personnaliser la réponse. ») clean of all 8 banned-term roots. ARB parity 6/6. | — |
| F13 | Banned-term scan — anon chat ARB keys | 14 P2 keys × 6 locales | ✅ PASS. `banned_terms_arb.py` reports 0 hits. Manual sweep: 0/16 keys hit `garanti, optimal, meilleur, assuré, sans risque, parfait, certain, rendement garanti`. | — |
| F14 | Brand framing — `anonymousChatLsfinDisclaimer` | `app_fr.arb:11364` | ✅ « Information générale, pas un conseil financier personnalisé. » — clean LSFin minimal-surface. Matches swiss-brain.md §2 spirit. | — |
| F15 | PII pattern coverage | `anonymous_chat.py:65-69` | The `\b\d{4,7}\s*(?:CHF|francs?)\b` pattern is solid for « 7500 CHF » but misses « 7'500 CHF » with apostrophe-thousand-separator (Swiss format). Verified: regex returns `[]` on `7'500 CHF`. Audit-log hash will contain unredacted Swiss-formatted salaries. Note: this is a defense-in-depth log issue, NOT a live LLM input issue (input is intentionally raw post-#507). | **P1** |
| F16 | Eclairage payload — banned terms | `anonymous_eclairage_prompt.py:29-38` | ✅ PASS. « Marge fiscale 3a non utilisée » + body uses « ~ », « selon ton canton et ton taux marginal » (conditional). No banned terms. CHF range cited as range, not exact. | — |
| F17 | Eclairage card — only 1 kind in anon prod | `anonymous_chat.py:295-298` | ⚠️ Brand: only `fiscal_margin_3a` ever surfaces for anon users. While 3a is event-neutral (any salaried adult), repeated demos will all see the same insight = monoculture risk. Not a compliance bug — flagged for product. | P2 |
| F18 | « Niveau de maîtrise » detection in anon | `anonymous_chat.py` (whole file) | ⚠️ The anon prompt has no instruction to default to « novice » register. VOICE_SYSTEM §2 axe-2 says « En cas de doute, écrire pour l'autonome. » but for a first-touch unauthenticated user, novice is closer to truth. Minor framing miss. | P2 |

---

## Severity rollup

- **P0 (ship-blocker):** 1 — F5 (anon ordre-de-grandeur rule MISSING; W-10 fix never ported to anon surface).
- **P1 (high):** 4 — F1 (accent-stripped anon system prompt), F2 (« Cree un compte » 429 detail), F4 (PII echo guard absent), F7 (literal banned-term list absent), F15 (PII regex misses Swiss apostrophe-format).
- **P2 (low):** 5 — F3, F6, F11, F17, F18.

## Top fix (≤30 words)

Patch `anonymous_chat.py:102-135` to (1) restore accents, (2) add literal banned-term list, (3) port the ordre-de-grandeur rule from `claude_coach_service.py:543-553`, (4) add « ne reproduis jamais textuellement les chiffres CHF/IBAN/AVS de l'utilisateur dans ta réponse » PII-echo rule. Single file, ~25 lines.

## What is GREEN and worth preserving

- ARB parity 6/6 across all 14 P2 keys + 2 transparency keys (29/29 line count match per locale).
- `banned_terms_arb.py` clean.
- Chips are 18-life-events generic, NOT retirement-first.
- `coachTransparencyServer` (#513) copy reads clean and honest.
- `anonymous_eclairage_prompt.py` LSFin-aware (range, not exact; conditional language).
- Voice opener (« Salut. Dis-moi ce qui te trotte en tête… ») nails VOICE_SYSTEM §1 + §2 « Découverte ».

## What is NOT validated in this audit (out of scope, tracked)

- G2 device-equivalent walker (folded with P1+P3 batch per perimeter log).
- Live LLM probe with adversarial inputs (« la médiane des loyers à Lausanne est 2'200 CHF » → does the response qualify?). Recommend running `autoresearch-compliance-hardener` skill against the anon endpoint after F5/F7 fixes land.
- 282 repo-wide accent_lint violations (only the ~30 inside `anonymous_chat.py` system prompt are P2-scope; the rest are pre-existing in unemployment, document_scan, etc., out of perimeter).
- `coachTransparencyBYOK` is still in the codebase per `app_fr.arb:10482` even though `project_byok_scope.md` marks BYOK out-of-scope. Cosmetic dead string, not a P2 blocker.

## Recommendation to perimeter owner

P2 should NOT be marked CLOSED until F5 + F7 land (single PR, can fold F1+F2+F4 into the same diff). Once shipped:
- run `pytest services/backend/tests/test_anonymous_chat.py -q` (G4)
- run `python3 tools/checks/accent_lint_fr.py | grep anonymous_chat.py` → 0 lines (G5 partial)
- re-run sim walker probe with « la médiane des loyers à Lausanne est 2'200 CHF » prompt → expect « ordre de grandeur » in reply (G1 deep)

Estimate: 30-45 min implementation + 1 CI cycle.


## Counter-arguments and data gaps

This artifact was synthesised from a single audit pass on 2026-05-07 — it benefits from a healthy dose of skepticism :

- **Sample-of-one bias** : the verdict is driven by one walk on one device (iPhone 17 Pro sim). On real devices, network conditions, OS variants, accessibility settings, or carrier prompts may surface failure modes this pass did not exercise.
- **Confirmation bias risk** : the panel was looking for the bugs from the prior session ; positive findings (« looks fine ») were not stress-tested with adversarial inputs in the same depth as the negative findings.
- **Data gap — production telemetry** : we have no Sentry / staging logs cross-reference for this perimeter ; conclusions about « no regression » are based on absence of visible UI errors, not on instrumentation.
- **Data gap — second reviewer** : no independent re-walk by a second human or sim has corroborated the verdict. Treat as a working hypothesis, not a final ruling, until the next walker run.
- **Counter-argument worth holding** : the « PASS » on items relying on best-effort fallbacks (keychain, biography, consent) hides the fact that the fallback path is the *real* code path on the sim — production-iOS behavior may differ. Prefer running on a real device before claiming the panel is closed.
