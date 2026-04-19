# SafeMode Auto-Trigger — Wire End-to-End (2026-04-18)

**Branch:** `claude/fix-app-navigation-zkVRx` — PR #352 base=dev.
**Goal:** Wire `WizardService.isSafeModeActive` / `CoachProfile.isInDebtCrisis` through the full coach stack so that a surendetté user cannot receive 3a/LPP optimisation advice. Priority = debt reduction.

## 1. Doctrine (NON-NEGOTIABLE)

From `rules.md` §SafeMode and `CLAUDE.md` §Coach & Arbitrage Rules:

> **Safe Mode**: If toxic debt detected → disable optimizations (3a/LPP), priority = debt reduction.

## 2. Activation rule (authoritative)

SafeMode is active when **ANY** of the following is true on the live profile:

| Signal | Threshold | Source |
|---|---|---|
| Consumer debt stress | `has_late_payments_6m = yes` OR `credit_card_minimum_or_overdraft = often` OR `has_consumer_credit = yes` OR `has_consumer_debt = yes` | Wizard answers |
| Debt-to-income ratio | `(consumer_debt_monthly + leasing_monthly + mortgage_monthly_excess) / net_monthly_income > 0.30` | DetteProfile + revenus |
| Emergency-fund shortfall | `months_liquidity < 3` OR `emergency_fund_answer in {no, less_1month}` | ProfileModel + wizard |

**Consumer debt only for ratio.** Structural debt (`hypotheque` backed by real estate) does NOT contribute to the 0.30 ratio — only `creditConsommation + leasing + autresDettes` are counted. This matches the existing doctrine that hypothèque = adossée à un actif.

## 3. Contract points (the 3 wire-ups)

### A. Mobile: aggregate flag on CoachProfile

New getter `CoachProfile.isInDebtCrisis` → `bool`:
- Computes the three signals above directly from `dettes`, `revenus`, `depenses.epargneLiquide`, and any wizard answers stored on `wizardAnswers` / `inline` map.
- Pure, no side effect, cacheable.
- Supersedes ad-hoc `profile?.hasDebt ?? false` in existing SafeModeGate call-sites.

### B. Mobile → Backend: `has_debt` flag in `/coach/chat` payload

- `CoachChatApiService.chat()` must forward `has_debt: profile.isInDebtCrisis` as part of `profile_context` (top-level), alongside existing `age`, `canton`, etc.
- The orchestrator sites that build `profileContext` (coach_orchestrator.dart:440, 671, 807) must include `has_debt`.
- Backend whitelist `_PROFILE_SAFE_FIELDS` adds `has_debt`.

### C. Backend: inject SafeMode block into system prompt + block optim tools

- `CoachContext` dataclass: add `has_debt: bool = False`.
- `build_coach_context(has_debt=False, ...)` new param.
- `claude_coach_service.py`:
  - Add `_SAFE_MODE_PROTOCOL` constant (copy below).
  - Inject into system prompt **when `ctx.has_debt is True`**, as a hard instruction block.
  - Appears BEFORE `_TOOL_ROUTING_RULES`.
- `_build_context_section` adds a `"- Mode protection désendettement : ACTIF"` line when `has_debt`.

Safe-mode prompt block (FR, swiss-brain refines):

```
## MODE PROTECTION — DÉSENDETTEMENT PRIORITAIRE (ACTIF)

La personne a un endettement toxique ou une absence de fonds d'urgence.
Règles NON-NÉGOCIABLES tant que ce mode est actif :

1. NE PROPOSE JAMAIS d'optimisation 3a, de rachat LPP, de comparateur de
   placement, ou de stratégie fiscale d'optimisation. Ces sujets sont bloqués
   côté app ; en parler serait incohérent avec ce que la personne voit.

2. Si la personne demande "comment optimiser mon 3a" / "faut-il racheter ma
   LPP" / similaire : réponds que ces optimisations sont mises en pause tant
   que le désendettement n'est pas stabilisé. Ne justifie pas avec des
   chiffres — explique l'ordre : stabiliser d'abord, optimiser ensuite.

3. Priorité N°1 : comprendre la dette (type, taux, charge mensuelle), puis
   reconstituer un matelas de trésorerie équivalent à 3 mois de charges.

4. Aucun conseil de placement, d'investissement ou de produit financier.
   Même éducatif. Même conditionnel.

5. Si la personne insiste pour parler 3a/LPP : redirige vers le plan de
   désendettement (route /debt/repayment côté app).
```

## 4. Audit + rate rules for AgentSafetyGate (mobile side)

`AgentSafetyGate.validate(task, isSafeMode=…)` déjà en place. Aucune nouvelle logique — juste s'assurer que **les call-sites passent `isSafeMode: profile.isInDebtCrisis`**. En production il n'y a actuellement aucun call-site ; mais si/quand un simulateur déclenchera `generateTask`, le flag devra être forwardé.

> swiss-brain : confirme que les règles 1–5 ci-dessus sont compatibles LSFin art. 3, LPD art. 6, et ne créent pas de conseil prescriptif déguisé. Suggère des ajouts éventuels (LAMal pour dette médicale, échelonnement LIFD si pertinent).

## 5. UI bandeau (exists + extend)

Existing SafeModeGate already renders a locked card with:
- `safeModeTitle` → "Concentration Prioritaire"
- `safeModeMessage` → "Pour ta sécurité financière, nous désactivons les optimisations avancées…"
- `safeModeCta` → "Voir mon plan de désendettement"
- Route: `/debt/repayment`

Extend it to:
- 9 screens listed in §6 currently unwrapped.
- Use `profile.isInDebtCrisis` (not `hasDebt`) as the gate input everywhere.

## 6. Screens to gate (new wrapping required)

From deep-audit mapping (Explore 2026-04-18):

| File | Why | Gate around |
|---|---|---|
| `screens/pillar_3a_deep/retroactive_3a_screen.dart` | Retroactive 3a catchup | Result + CTA section |
| `screens/pillar_3a_deep/provider_comparator_screen.dart` | 3a provider optimizer | Comparison table |
| `screens/pillar_3a_deep/real_return_screen.dart` | Tax-deferred return calc | Result section |
| `screens/pillar_3a_deep/staggered_withdrawal_screen.dart` | 3a withdrawal sequencing | Sequencing block |
| `screens/lpp_deep/rachat_echelonne_screen.dart` | LPP rachat optim | Rachat table |
| `screens/lpp_deep/epl_screen.dart` | EPL (not optim per se but withdrawal planning) | EPL result |
| `screens/lpp_deep/libre_passage_screen.dart` | LP optim | LP result |
| `screens/independants/pillar_3a_indep_screen.dart` | Indep 3a strategy | Plafond/strategy section |
| `screens/independants/lpp_volontaire_screen.dart` | Voluntary LPP | Contribution planning |

**Exception:** `epl_screen.dart` and `libre_passage_screen.dart` — discuss: these are RETRAITS, not additions. Still block in SafeMode because (a) early LPP withdrawal while in crisis is rarely optimal and (b) EPL triggers capital-withdrawal tax. Keep gated for consistency.

## 7. Tests (MANDATORY)

### Backend

1. `test_coach_context_has_debt.py`:
   - `build_coach_context(has_debt=True)` → `ctx.has_debt is True`
   - `build_coach_context()` → default False
2. `test_claude_coach_safe_mode_prompt.py`:
   - `build_system_prompt(ctx=ctx_with_has_debt=True)` contains "MODE PROTECTION" and the 5 rules.
   - `build_system_prompt(ctx=ctx_with_has_debt=False)` does NOT contain "MODE PROTECTION".
3. `test_coach_chat_profile_sanitize.py`:
   - POST `/coach/chat` with `profile_context.has_debt=True` → safe field survives sanitization, ctx has_debt True.

### Mobile

1. `coach_profile_safe_mode_test.dart`:
   - Consumer debt > 30% ratio → `isInDebtCrisis = true`
   - Emergency fund < 3 months → `isInDebtCrisis = true`
   - `q_has_consumer_credit = yes` → `isInDebtCrisis = true`
   - Hypothèque seule (pas de conso) → `isInDebtCrisis = false`
   - Pas de dette ni d'alerte trésorerie → `isInDebtCrisis = false`
2. Extend `safe_mode_gate_test.dart`:
   - `pumpScreen(profile_in_crisis, route: '/simulator/3a')` → bandeau présent
3. `coach_chat_api_service_safe_mode_payload_test.dart`:
   - chat() called with CoachProfile.isInDebtCrisis true → body.profile_context.has_debt is true

## 8. Exit criteria (session success)

1. [ ] swiss-brain spec output checked into `.planning/safemode-2026-04-18/RULES.md`
2. [ ] Backend tests green: `pytest tests/ -q`
3. [ ] Flutter tests green: `flutter test` (no new failures vs 43 pre-existing)
4. [ ] `flutter analyze` — 0 issues
5. [ ] ARB 6 langs coherent — no hardcoded FR (reuse existing safe-mode keys)
6. [ ] Device walkthrough: fake Thomas profile → nav to /simulator/3a → bandeau "Concentration Prioritaire" + CTA "Voir mon plan de désendettement" visible
7. [ ] Atomic commits squashed per concern, pushed on `claude/fix-app-navigation-zkVRx`
8. [ ] Memory updated: `session_2026_04_18_safemode.md`
9. [ ] PR #352 commented with what shipped
