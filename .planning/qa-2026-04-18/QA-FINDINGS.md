# QA device walkthrough — 2026-04-18 (iPhone 17 Pro sim, staging)

Cold-start through core flows: landing → coach → budget → scan → simulator → tabs.

## FIXED IN-SESSION

| # | Finding | Commit |
|---|---------|--------|
| 1 | Coach tab opened with random piquant greeting ("Tu sais combien tu vas toucher à la retraite ? Personne sait") | `f874405d` kill random greeting |
| 2 | Offline fallback text retirement-biased ("Explorer tes simulateurs (3a, LPP, retraite)") | `d9b9bf30`-ish kill retirement bias fallback |
| 3 | Doctrine document — Coach home experience (expert panel, 5 voices) | `f874405d` docs(coach-home) |
| 4 | Push→go systemic RSoD class killed (session earlier) | `43dd8609` |
| 5 | SafeMode wired end-to-end (session earlier) | 3 commits on PR #352 |

## VERIFIED WORKING

- **Coach open** (empty profile): silent opener renders "Tu veux en parler ?" + tone chips (Doux / Direct / Sans filtre). No retirement framing.
- **Scan flow**: "Utiliser un exemple de test" extracts 14 fields from LPP certificate with 87% confidence. Per-field modification buttons present. Confirmation screen shows 42 → 71% confidence gain + field integration.
- **Rachat LPP simulator** (`/rachat-lpp`): computes 3 rachats échelonnés CHF 26'667 chacun, économie fiscale CHF 16'869 total. LPP art. 79b al. 3 disclaimer displayed correctly (blocage EPL 3 ans). Éducatif disclaimer LSFin in place.
- **Tab navigation**: rapid tab cycling (4 tabs × 2 cycles) does not crash. No Navigator.dart GlobalKey assertion reproduces.
- **Budget CTA** (Mon Argent → Commencer → Commencer la saisie): lands on Coach with topic=budget (no RSoD).
- **Explorer hub architecture**: 7 hubs listed, drill-down pattern. Shell tab bar hidden on hub screens (parentNavigatorKey root) — intentional.

## FINDINGS FOR NEXT ITERATION

### P1 — Silent opener remains retirement-centric

`coach_chat_screen.dart:510` `_computeKeyNumber()` priorities:
1. `proj.tauxRemplacementBase` — headline "Taux de remplacement à la retraite"
2. `FinancialFitnessService.calculate(profile).global` — headline "Score de santé financière" ✅ (only neutral one)
3. `proj.base.capitalFinal` — headline "Capital projeté à la retraite"

2 of 3 priorities use retirement-framed headlines. Recommended:
- Reorder: FRI score first (neutral); retirement priorities as fallback.
- Rename headlines to neutral: "Ton taux de remplacement" (no "à la retraite"), "Capital projeté" (no "à la retraite").
- Consider priority 0: surface most-recent enrichment as a bare fact (panel proposal 2 "Header canton · mois").

Requires swiss-brain copy review. Not blocking.

### P1 — Backend system prompt bias source

`services/backend/app/services/coach/claude_coach_service.py` contains 52 mentions of `retraite / retirement / LPP / 3a / pilier`. This is the structural reason the coach's own responses lean retirement even when the user asks a generic question. Partial context-keyboard (lifecycle_awareness, life_event_catalog) exists but the bulk is still retirement-oriented.

Queued as P1 for S57 — needs swiss-brain to:
1. Reclassify each mention as "fiscal optim" (OK per founder guidance 2026-04-18: LPP/3a = Swiss optim levers) vs "retirement lifecycle framing" (not OK).
2. Keep fiscal optim mentions intact; rephrase retirement-lifecycle ones.

### P2 — Coach misses enrichment acknowledgment

User uploads LPP cert → confidence jumps 42→71% → Coach tab open: silent ("Tu veux en parler ?"). No "J'ai vu ton certificat LPP" or similar. Closes a feedback loop poorly.

Recommended: Priority 0 in `_computeKeyNumber` that reads `_profile.prevoyance.avoirLppTotal` and surfaces "Avoir LPP : CHF X" when it's non-zero and recent. Panel doctrine (anti-shame) says: fact-only, no injunction. Add new ARB key `coachSilentOpenerLppAvoir` in 6 langs.

~1h of work.

### P2 — Local-mode has no real coach

Without login + without BYOK + SLM disabled-in-build → coach always falls back to offline message. Local-mode user cannot actually converse with the coach. Product gap: either (a) expose SLM as user-opt-in, (b) make anonymous /coach/chat more permissive, (c) surface a clear message to the user "pour vraiment parler au coach, connecte-toi ou ajoute ta clé Claude dans Paramètres IA".

Recommended: implement (c) as an immediate UX improvement. (a) and (b) are larger infra decisions.

### P2 — Default chips surface on any "3a/pilier/LPP" keyword match

`_inferSuggestedActions` regex matches the coach's own reply text. If the coach says "3a" anywhere in its response (e.g. in a privacy banner or generic listing), 3 chips surface. Per founder guidance 2026-04-18: mentioning 3a/LPP is LEGITIMATE when context = tax optim. But the regex doesn't distinguish "3a as fiscal tool" vs "3a as retirement pillar".

Recommended: tighten regex to require BOTH a topic keyword AND a contextual cue (e.g. "optim", "déduction", "impôt", "économies"). Flag for swiss-brain.

### P3 — UX typographic rendering

Hub title renders "Retraite & Prevoyance" without the é accent on "Prévoyance" despite ARB being correct ("Retraite & Prévoyance"). Suspected font subsetting issue. Cosmetic. Flag for design pass.

### P3 — "Cockpit" still labeled across 4 CTAs

4 widgets push `/coach/cockpit` which zombie-redirects to `/retraite`. Label "cockpit" is obsolete (Wire Spec V2). Safe (root nav, no RSoD) but semantic drift.

Files: `widgets/coach/smart_shortcuts.dart:48`, `widgets/coach/trajectory_card.dart:54`, `widgets/coach/early_retirement_comparison.dart:202`, `screens/coach/retirement_dashboard_screen.dart:507`.

## WALKTHROUGH METHOD NOTES

- `idb ui describe-all` + Python JSON parse = works great for AX tree, captures most text content.
- Screenshot reserved for decision points (when AX tree is sparse — e.g., custom painted widgets in simulators).
- `idb ui text` struggles with non-ASCII (ç typed as c, typos introduced by sim autocorrect). Keep input messages ASCII-only + short for QA scripts.

## Test suite delta this session

- Flutter tests: 43 → 15 failing (9 closed via direct fix, rest provider fallback pattern). Remaining 15 = goldens (need visual review) + coach_chat network timeouts (need HTTP mocks).
- Backend tests: 5848 → 5925 passing (+77 from SafeMode work), 0 failures.
- `flutter analyze`: 0 errors, 157 info (down from 160 baseline).
