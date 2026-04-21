# SafeMode — Compliance Rules (authoritative)

**Author:** swiss-brain · **Date:** 2026-04-18 · **Scope:** `claude/fix-app-navigation-zkVRx`
**Supersedes:** SPEC.md §2-§7 where language differs. This file wins on doctrine, SPEC wins on wiring layout.

Legal frame: **LSFin art. 3** (qualité de l'information financière — information exacte, claire, non trompeuse), **LPD art. 6** (principes de traitement, proportionnalité), **FINMA Circ. 2017/2** (comportement sur le marché — devoir de diligence), **ASB — Directives sur l'examen des crédits hypothécaires 2014** (affordability 1/3 du revenu brut, taux théorique 5%), **LCC (Loi sur le crédit à la consommation) art. 32 & 36** (examen de la capacité de remboursement — repère de référence pour la notion de crédit "toxique"). Article numbers inline below are normative; everything else is doctrine.

---

## 1. SafeMode activation rule (authoritative)

SafeMode is **ACTIVE** when **ANY** of the three signals below is true on the live profile. Evaluation is OR, not AND — one signal is enough.

### Signal A — Consumer debt stress (binary)
Any one of:
- `q_late_payments_6m == 'yes'`
- `q_creditcard_minimum_or_overdraft == 'often'`
- `q_has_consumer_credit == 'yes'`
- `q_has_consumer_debt == 'yes'`

Rationale: a single late-payment or revolving-credit-minimum signal is, by itself, sufficient evidence of cash-flow stress. LCC art. 36 treats a consumer credit as problematic the moment repayment capacity is marginal. We do not wait for a ratio to tip.

### Signal B — Consumer debt-to-income ratio
`(leasing_monthly + credit_conso_monthly + autres_dettes_monthly) / revenu_net_mensuel > 0.33`

**Change vs SPEC §2: threshold is 0.33, not 0.30.**

- **Source:** ASB 2014 affordability rule adapts the 1/3 (≈ 33.3%) ceiling as the Swiss-standard debt-service envelope. FINMA reiterates it in 2019 mortgage self-regulation review. There is no Swiss source for 0.30; 0.30 was SPEC-invented.
- **Effect:** aligns SafeMode trigger with the same number the mortgage-affordability calculator already uses elsewhere in `apps/mobile/lib/services/financial_core/`. Doctrine consistency > SPEC defaults.
- **Tolerance:** ratio > 0.33 triggers. 0.30–0.33 is a "warning zone" — NOT SafeMode, but the coach should acknowledge tightness if the user raises 3a/LPP optim. Recommended UX follow-up (not this session): a yellow-band state distinct from SafeMode red.

**Structural (mortgage) debt is EXCLUDED from the numerator.** Hypothèque is adossée à un actif (LAMal terminology aside, this is simply the ASB principle: mortgage service is assessed against the full affordability formula, not dumped into consumer-debt ratio). **Exception:** if `mortgage_monthly > 0.33 × revenu_brut_mensuel` (ASB affordability breach), count **only the excess** above the 0.33 cap as structural overhang contributing to the ratio. Users whose mortgage alone breaks affordability ARE in crisis even without consumer debt.

### Signal C — Emergency-fund shortfall
Any one of:
- `months_liquidity < 3` (computed from `depenses.epargneLiquide / charges_mensuelles`)
- `q_emergency_fund in {'no', 'less_1month'}`

**3 months is correct.** Swiss reference: SECO 2023 household finance survey + academic consensus (Kruger/Rinaldi, IFZ Lucerne 2022) both converge on 3 months of charges as the minimum resilience buffer for a salarié suisse. US literature says 3–6; Swiss applies 3 because the safety net (AC 70/80% indemnités chômage, AI, APG) is denser. Do not weaken to 2 months.

### Edge cases (MANDATORY rulings)

**E1 — Retiree with zero salary income.** Ratio denominator undefined. **Rule:** substitute `revenu_net_mensuel` with `rente_avs + rente_lpp + retraits_3a_mensualisés + rentes_privées`. If total monthly rente < 2'000 CHF and consumer debt > 0, activate SafeMode regardless of ratio.

**E2 — Couple, only one spouse in crisis.** **Rule:** gate on the **profile owner's** signals, not the household aggregate. Thomas's `isInDebtCrisis=true` does NOT block Julie's 3a rachat simulator when Julie is the authenticated user. Rationale: LPP is individual (LPP art. 13 — l'avoir de vieillesse appartient à la personne assurée), 3a is individual (OPP3 art. 1), and LIFD tax is joint only for declaration purposes — the underlying pillars stay personal. Gating Julie on Thomas's debt would be paternalistic AND factually wrong (Julie's LPP rachat cannot be seized for Thomas's credit conso — LP art. 39 protects prévoyance).

**Caveat:** if the household is declared `couple` AND the shared debt is `hypothèque` that fails ASB affordability on combined income, BOTH profiles enter SafeMode. Shared structural debt = shared crisis.

**E3 — Indépendant, irregular income.** Use **trailing-12-month average net income** if available, else `revenu_net_declared_yearly / 12`. Never zero-divide.

**E4 — Full-time student with parental support, no income.** Do not force SafeMode via division-by-zero. If `revenu_net_mensuel == 0` AND no consumer debt signal A AND no housing → SafeMode **inactive** (there's nothing to optimize anyway; gate is vacuous).

**E5 — Toxic debt already in negotiation (désendettement plan underway).** `q_has_debt_plan == 'yes'` does NOT deactivate SafeMode. Being in a plan is progress, not resolution. Exit SafeMode only when signals A/B/C all clear.

---

## 2. System prompt block (FR) — to inject when `ctx.has_debt is True`

**Placement:** after `_ARCHETYPE_CATALOG`, **before** `_TOOL_ROUTING_RULES`. This position guarantees the model reads "no optim advice" before it reads "here is how to route to optim screens".

**Shippable text (175 words, imperative, Claude-to-Claude register matching existing `_LIFE_EVENT_CATALOG` style):**

```
## MODE PROTECTION — DÉSENDETTEMENT PRIORITAIRE (ACTIF)

La personne porte une dette de consommation toxique, un ratio dette/revenu
supérieur à 33%, ou un matelas de trésorerie inférieur à 3 mois. Tant que
ce mode est actif, les règles suivantes sont NON-NÉGOCIABLES :

1. JAMAIS d'optimisation 3a, rachat LPP, comparateur de placement, stratégie
   fiscale d'optimisation, ni allocation d'actifs — même éducative, même
   conditionnelle. Ces surfaces sont verrouillées côté app ; en parler
   créerait une dissonance visible.

2. Si la personne demande explicitement "comment optimiser mon 3a" ou
   "faut-il que je rachète ma LPP" : réponds que ces décisions sont mises
   en pause le temps de stabiliser la situation. Explique l'ordre
   (stabiliser d'abord, optimiser ensuite). Ne justifie pas par un calcul
   de rendement — l'ordre est doctrinal, pas arithmétique.

3. Priorité N°1 : comprendre la dette (type, taux effectif, charge
   mensuelle, échéances). Priorité N°2 : reconstituer une trésorerie de
   3 mois de charges.

4. Redirige vers /debt/repayment si la personne insiste sur un sujet
   d'optimisation. Tu peux parler budget, dette, trésorerie, assurances
   de base (LAMal, IJM). Tu ne parles pas placement.

5. Ne dis JAMAIS "tu devrais" — dis "l'ordre recommandé est". Pas de
   honte, pas de reproche. La personne a déjà fait le travail difficile
   en disant la vérité sur sa situation.
```

**Why these 5 rules and not more / less:**
- Rule 1 covers the explicit block surface (LSFin art. 3 — information de qualité = pas de recommandation d'optim incohérente avec l'écran).
- Rule 2 addresses the prescriptive-advice trap: LSFin forbids implicit advice disguised as education. "Voici pourquoi tu ne devrais PAS racheter ta LPP maintenant, voici le calcul" is still advice.
- Rule 3 anchors the positive priority — compliance is not only "don't", it's also "redirect to legitimate priority".
- Rule 4 is the behavioral escape valve (user insists → route to `/debt/repayment` not generic shutdown).
- Rule 5 enforces anti-shame doctrine (core MINT feedback memory `feedback_anti_shame_situated_learning.md`). SafeMode without anti-shame becomes punitive.

**No LAMal addition.** Debt médicale is covered by Rule 4's "assurances de base (LAMal, IJM)" opening. Explicit LAMal-debt handling belongs to a future phase (`debtCrisis` life event refinement).

**No LIFD échelonnement clause.** Écouter la demande de plan de paiement fiscal est légitime mais sort de SafeMode — c'est un flow spécifique `tax_payment_plan` qui n'existe pas encore. Ne pas préempter.

---

## 3. Audit checklist for `AgentSafetyGate`

Current state (verified in `apps/mobile/lib/services/agent/autonomous_agent_service.dart:270-274`):
```dart
static const List<AgentTaskType> _safeModeBlockedTypes = [
  AgentTaskType.threeAFormPreFill,
  AgentTaskType.fiscalDossierPrep,
];
```

### Task types to add to `_safeModeBlockedTypes`
- **`AgentTaskType.lppCertificateRequest`** — requesting a caisse-de-pension certificate in SafeMode is benign in itself, but 95% of the time the next step is a rachat decision. The letter template auto-generates a line "en vue d'évaluer un rachat". Block until SafeMode clears.
- **`AgentTaskType.taxDeclarationPreFill`** — block. Tax-declaration pre-fill in SafeMode risks surfacing a "tu peux déduire 7'258 CHF en 3a" hint inline, which is exactly the optim advice Rule 1 forbids. The user CAN still file manually; MINT just doesn't auto-compose the dossier.
- **`AgentTaskType.avsExtractRequest`** — KEEP ALLOWED. Requesting an AVS CI extract is a protective action (check contribution gaps) independent of optim. No block.
- **`AgentTaskType.caisseLetterGeneration`** — conditional: block if the letter purpose field contains `rachat`, `retrait_anticipé`, `EPL`, `versement_volontaire`. Allow for `demande_certificat_simple`, `changement_adresse`, `demande_avoir_libre_passage`.

**Final `_safeModeBlockedTypes` after this session:**
```dart
static const List<AgentTaskType> _safeModeBlockedTypes = [
  AgentTaskType.threeAFormPreFill,
  AgentTaskType.fiscalDossierPrep,
  AgentTaskType.lppCertificateRequest,
  AgentTaskType.taxDeclarationPreFill,
];
// caisseLetterGeneration: conditional block — requires purpose-field check
// (new validation rule 12 in AgentSafetyGate.validate).
```

### Non-blocked task types — MUST add contextual disclaimer when `isSafeMode=true`
For `avsExtractRequest` and the allowed `caisseLetterGeneration` subset, the generated `disclaimer` field must append:

> "Ta situation d'endettement a été prise en compte. Cette démarche reste neutre — elle ne modifie rien à ton plan de désendettement."

Added as a new validation rule 12 in `AgentSafetyGate.validate()`: when `isSafeMode && task.type in _safeModeAllowedWithNote`, the disclaimer MUST contain the FR substring `'plan de désendettement'`. Missing → violation.

### Test matrix for the gate
| Test | Task type | isSafeMode | Expected |
|---|---|---|---|
| 1 | `threeAFormPreFill` | true | FAIL with "blocked in safe mode" |
| 2 | `threeAFormPreFill` | false | PASS |
| 3 | `lppCertificateRequest` | true | FAIL (NEW) |
| 4 | `lppCertificateRequest` | false | PASS |
| 5 | `taxDeclarationPreFill` | true | FAIL (NEW) |
| 6 | `avsExtractRequest` | true, disclaimer w/ "plan de désendettement" | PASS |
| 7 | `avsExtractRequest` | true, disclaimer WITHOUT the substring | FAIL with "SafeMode disclaimer missing contextual note" |
| 8 | `caisseLetterGeneration` w/ purpose=`rachat` | true | FAIL |
| 9 | `caisseLetterGeneration` w/ purpose=`changement_adresse` | true | PASS with disclaimer note |
| 10 | Any blocked type | both isSafeMode values tested to prove the flag is WIRED (not defaulted to false) | caller-passes-flag contract verified |

Test 10 is the critical joint test per MINT audit doctrine `feedback_audit_inter_layer_contracts.md` Check B: green tests on the gate prove NOTHING if no caller ever passes `isSafeMode: true`. The test must assert an actual caller (`AutonomousAgentService.generateTask`) forwards the flag from `CoachProfile.isInDebtCrisis`.

---

## 4. UI bandeau copy — FR (existing keys review)

Re-read `apps/mobile/lib/l10n/app_fr.arb` at the 9 keys. Verdict per key:

| Key | Current FR | Ruling |
|---|---|---|
| `safeModeTitle` | "Concentration Prioritaire" | ✅ KEEP. Not banned, not shaming, non-prescriptive. Capitalization is mid-weight — acceptable in current MINT typographic style. |
| `safeModeMessage` | "Pour ta sécurité financière, nous désactivons les optimisations avancées tant qu'un signal de dette est actif. La priorité est de construire ta sécurité." | ⚠️ **CHANGE.** Issues: (a) "nous désactivons" breaks voice — MINT is "tu" and singular-voice, not corporate "nous". (b) "ta sécurité" repeated twice, second instance reads flat. **Proposed:** `"Tant qu'un signal de dette est actif, les optimisations avancées sont en pause. Priorité : stabiliser ta trésorerie. Le reste attendra."` |
| `safeModeCta` | "Voir mon plan de désendettement" | ✅ KEEP. Clear, action-oriented, non-prescriptive. |
| `sim3aDebtLockedTitle` | "Priorité au désendettement" | ✅ KEEP. |
| `sim3aDebtLockedMessage` | "En mode protection, les recommandations d'action 3a sont désactivées. La priorité est de stabiliser ta situation financière avant de verser dans le 3a." | ✅ KEEP. |
| `sim3aDebtStrategyTitle` | "Stratégie bloquée" | ⚠️ **CHANGE.** "Bloquée" + "Stratégie" reads like a videogame penalty. **Proposed:** `"Stratégie en pause"`. |
| `sim3aDebtStrategyMessage` | "Les stratégies d'investissement 3a sont désactivées tant que tu as des dettes actives. Rembourser tes dettes est un rendement plus élevé que tout placement." | ⚠️ **CHANGE.** Last sentence reads prescriptive ("est un rendement plus élevé") and arithmetic-justifies the block, which System Prompt Rule 2 forbids. **Proposed:** `"Les stratégies d'investissement 3a sont en pause tant que tes dettes actives pèsent sur ton budget. Ordre recommandé : stabiliser d'abord, placer ensuite."` |
| `reportSafeMode3a` | "Le comparateur 3a est désactivée tant que tu as des dettes actives. Rembourser tes dettes est prioritaire avant toute épargne 3a." | ⚠️ **CHANGE.** Typo `désactivée` (should be `désactivé` — comparateur masculine). Also same prescriptive issue. **Proposed:** `"Le comparateur 3a est en pause tant que tes dettes actives pèsent sur ton budget. Priorité : stabiliser ta trésorerie."` |
| `reportSafeModeLpp` | "Rachat LPP bloqué" | ⚠️ **CHANGE.** Same tone issue. **Proposed:** `"Rachat LPP en pause"`. |
| `reportSafeModeLppMessage` | "Le rachat LPP est désactivé en mode protection. Rembourser tes dettes avant de bloquer de la liquidité dans la prévoyance." | ⚠️ **CHANGE.** Second sentence is an imperative ("Rembourser") without subject — reads prescriptive. **Proposed:** `"Le rachat LPP est en pause en mode protection. L'ordre recommandé : rembourser les dettes avant de bloquer de la liquidité dans la prévoyance."` |
| `reportSafeModePriority` | "Priorité au désendettement" | ✅ KEEP. |
| `reportSafeModeActions` | "Tes actions prioritaires sont remplacées par un plan de désendettement. Stabilise ta situation avant d'explorer les recommandations." | ✅ KEEP. |
| `portfolioSafeModeBody` | "Les conseils d'allocation sont désactivés en mode protection. Ta priorité est de réduire tes dettes avant de rééquilibrer ton patrimoine." | ⚠️ **CHANGE.** "Ta priorité est de" → prescriptive. **Proposed:** `"Les conseils d'allocation sont en pause en mode protection. Ordre recommandé : réduire tes dettes avant de rééquilibrer ton patrimoine."` |
| `portfolioSafeModeLocked` | "Priorité au désendettement" | ✅ KEEP. |

### Pattern to enforce across all SafeMode copy (authoritative)
1. "désactivé(e)" → **"en pause"** (framing: temporary, not punitive)
2. "bloqué" → **"en pause"** (same rationale)
3. "tu dois" / "rembourser tes dettes avant" (bare imperative) → **"l'ordre recommandé est"** / **"ordre recommandé : ..."**
4. "nous désactivons" → passive or direct ("est en pause" / "les optimisations sont en pause")
5. Keep "priorité" — it's a noun, not a command.
6. Banned terms sweep: no instances of `garanti`, `certain`, `assuré` (as adj), `sans risque`, `optimal`, `meilleur`, `parfait`, `conseiller` — verified none present.
7. i18n debt: the 3 FR strings hardcoded in `widgets/common/safe_mode_gate.dart` (lines 93, 115, 120-121, 142) MUST move to ARB keys. Block the PR merge if left hardcoded — violates MINT doctrine `feedback_no_hardcoding_ever.md`.

---

## 5. Test matrix — mandatory pre-landing

### Backend (`services/backend/`)
1. `tests/coach/test_coach_context_has_debt.py`
   - `build_coach_context(has_debt=True)` → `ctx.has_debt is True`
   - `build_coach_context()` default → `ctx.has_debt is False`
   - `build_coach_context(has_debt=None)` → `ctx.has_debt is False` (defensive)
2. `tests/coach/test_claude_coach_safe_mode_prompt.py`
   - `ctx.has_debt=True` → prompt contains `"MODE PROTECTION"` AND all 5 rule headers (`"1.", "2.", "3.", "4.", "5."` in SafeMode section scope)
   - `ctx.has_debt=True` → prompt contains `"/debt/repayment"`
   - `ctx.has_debt=False` → prompt does NOT contain `"MODE PROTECTION"`
   - `ctx.has_debt=True` → `MODE PROTECTION` appears **before** `ROUTING RULES` in the prompt string (offset assertion — order is doctrinal)
   - `ctx.has_debt=True` → `"- Mode protection désendettement : ACTIF"` appears in `_build_context_section` output
3. `tests/coach/test_coach_chat_profile_sanitize.py`
   - POST `/coach/chat` with `profile_context.has_debt=True` → `_PROFILE_SAFE_FIELDS` whitelist survives the value, downstream `ctx.has_debt is True`
   - POST with `profile_context.has_debt="true"` (string) → coerced to bool `True`
   - POST with `profile_context.has_debt=1` (int) → coerced to bool `True`
   - POST without `has_debt` field → default `False` (no key injection error)
4. `tests/coach/test_safe_mode_banned_topics.py` (adversarial — MUST land with this feature)
   - Golden prompt fixture: "comment optimiser mon 3a" with `has_debt=True` in system → run ComplianceGuard on a simulated response that advises 3a → guard flags optim-in-safemode violation.
   - Requires a new compliance rule in `compliance_guard.py`: if `ctx.has_debt` AND response contains `{3a, LPP, rachat, optim*, comparateur, allocation}` within 80 tokens of `{devrais, recommande, suggère, conseille}` → violation.

### Mobile (`apps/mobile/`)
1. `test/models/coach_profile_safe_mode_test.dart`
   - Consumer credit yes + 31% ratio → `isInDebtCrisis=true`
   - Consumer credit yes + 10% ratio (but signal A alone) → `isInDebtCrisis=true`
   - No consumer debt + 34% ratio (structural only) + mortgage excess → `isInDebtCrisis=true`
   - No consumer debt + 34% ratio but hypothèque within ASB → `isInDebtCrisis=false`
   - Emergency fund "less_1month" + no debt → `isInDebtCrisis=true`
   - Emergency fund `months_liquidity=3.1` + no debt + no signals → `isInDebtCrisis=false`
   - Retiree (zero salary, 2'400 CHF rente AVS+LPP, consumer credit yes) → `isInDebtCrisis=true`
   - Student (zero income, no debt, parental support) → `isInDebtCrisis=false` (E4)
   - Couple owner Julie, spouse Thomas in crisis, Julie has no debt → Julie's `isInDebtCrisis=false` (E2)
   - Couple with shared hypothèque failing ASB → both profiles' `isInDebtCrisis=true` (E2 caveat)
2. `test/widgets/safe_mode_gate_test.dart` (EXTEND)
   - pumpScreen(profile_in_crisis, route: `/simulator/3a`) → bandeau rendered with `safeModeTitle` text
   - pumpScreen(profile_not_in_crisis, route: `/simulator/3a`) → child rendered, no bandeau
   - 9 routes listed in SPEC §6 — one widget test each (parametrized)
3. `test/services/coach_chat_api_service_safe_mode_payload_test.dart`
   - `chat()` with `CoachProfile.isInDebtCrisis=true` → posted JSON body's `profile_context.has_debt == true`
   - `chat()` with `isInDebtCrisis=false` → `has_debt == false` (NOT omitted — always sent to be explicit)
4. `test/services/agent/autonomous_agent_safe_mode_test.dart` (EXTEND)
   - All 10 rows of §3 test matrix above
5. `test/golden/julien_lauren_safe_mode_test.dart` (NEW)
   - Julien + injected consumer credit CHF 500/mo → `isInDebtCrisis=true`
   - Lauren alone (no consumer debt, healthy ratio) → `isInDebtCrisis=false` even when Julien is in crisis (E2)

### End-to-end device walkthrough (acceptance criteria)
Per MINT doctrine `feedback_tests_green_app_broken.md` — tests green is insufficient. Creator must walk the device cold-start.

1. Install build targeting staging (`--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`).
2. Create fake profile "Thomas": revenu 5'000 net/mo, consumer credit 400/mo, leasing 300/mo (ratio 14% alone but signal A trips).
3. Navigate to `/simulator/3a` → **MUST see** bandeau "Concentration Prioritaire" + CTA "Voir mon plan de désendettement" above the result section. Result section hidden.
4. Tap "Pourquoi est-ce bloqué ?" → bottom sheet with reasons.
5. Tap CTA → routed to `/debt/repayment`.
6. Open Coach tab. Type: "est-ce que je devrais racheter ma LPP ?"
7. Response MUST:
   - Mention that the rachat is "en pause" or similar non-prescriptive phrasing.
   - Redirect to debt plan (mention /debt/repayment or equivalent surface).
   - NOT contain any CHF amount related to rachat.
   - NOT contain the word "optimisation" in a positive framing.
8. Repeat walkthrough for Lauren profile (healthy) — no bandeau, no coach redirect.
9. Walkthrough for Julie-owner-with-Thomas-spouse-in-crisis — Julie's simulator 3a works normally (E2 test).
10. Screenshot evidence attached to PR #352 (per `feedback_screenshot_discipline.md` — 1 screenshot per decision point, not every screen).

### Pre-merge gates (non-negotiable)
- `flutter analyze` → 0 issues
- `flutter test` → no NEW failures vs 43 pre-existing baseline
- `pytest tests/ -q` → all green
- ARB file 6-lang coherence check: all new/changed FR keys mirrored in EN/DE/ES/IT/PT (extract to all 6, no hardcoding, diacritics preserved)
- `tools/checks/no_chiffre_choc.py` → PASS (residual legacy-term check, unrelated but always runs)

---

## 6. Risks / open questions

1. **FLAG FOR HUMAN — `compliance_guard.py` new rule (test matrix §4).** I'm mandating a guard-side check that a response containing 3a/LPP/rachat advice when `ctx.has_debt=True` is flagged as a violation. This is defensive (belt-and-suspenders with the system prompt), but it requires the guard to receive `ctx.has_debt` — today `ComplianceGuard` may not have access to the full CoachContext. Verify the wiring before implementing this test; if guard signature needs extension, surface it as a scope question.

2. **FLAG — Ratio threshold change 0.30 → 0.33.** SPEC said 0.30. I'm overriding to 0.33 based on ASB 2014. If the team prefers staying at 0.30 for belt-and-suspenders conservatism, that is defensible — but then the doctrine note (§1 Signal B rationale) must document that 0.30 is intentional over-protection, not a Swiss legal number. Choose one.

3. **FLAG — Couple mode (E2).** My ruling is that Julie's individual pillars are not gated by Thomas's debt. This is LPP/OPP3 correct but may feel UX-wrong to a founder who wants a couple-in-crisis household to be fully locked down. If the founder disagrees, we need a separate ADR — not a SafeMode adjustment — because gating Julie's LPP rachat on Thomas's debt creates a new doctrine (household liability crossing individual pillar boundaries) that contradicts LP art. 39. I would not ship that without ADR.

4. **FLAG — Exit criteria for SafeMode.** Nothing in SPEC says how a user EXITS SafeMode. Rule E5 says "signals A/B/C all clear" but there's no event-driven re-evaluation trigger. Today `isInDebtCrisis` is computed on-demand from profile state, which means exit is implicit. Acceptable for v1 but: is there a "you're out of SafeMode" notification? If not, flag as future UX (not blocker).

5. **FLAG — Onboarding case.** A user who hasn't filled wizard yet has `wizardAnswers == null`. `isInDebtCrisis` defaults to `false`. This means a brand-new user who in reality IS in debt crisis gets full optim advice during the first session until they fill wizard. Consider: should onboarding include a single `has_debt_signal` fast-track question that pre-populates Signal A, so coach is gated from turn 1? I'd recommend yes but it's out of scope for this wiring session — flag for S57 onboarding sprint.

6. **FLAG — `epl_screen.dart` and `libre_passage_screen.dart`.** SPEC §6 gates these "for consistency" even though they're withdrawals not optimizations. I agree for EPL (triggers LIFD art. 38 tax, LPP art. 30c 3-year block — genuinely bad in crisis). I agree for libre passage (once you withdraw, you lose the 3-year purchase benefit). But surface the educational disclaimer: "Ces retraits restent possibles en cas de procédure de désendettement formelle — parle à un·e spécialiste." That's the Swiss reality (LP art. 5 — versement en espèces possible si entreprise indépendante OR endettement; courts have ruled this applies in surendettement formel). Don't lock the door completely — lock the UI but leave one sentence of escape route for the edge case.

7. **OPEN — i18n debt in `safe_mode_gate.dart`.** 3 hardcoded FR strings identified. Must be fixed in this session or the PR is doctrine-blocked per `feedback_no_hardcoding_ever.md`. Not a compliance blocker but a merge blocker.

---

## Sign-off

This document is authoritative for SafeMode wire-up on branch `claude/fix-app-navigation-zkVRx`. Any deviation from §1 (activation rule), §2 (system prompt), §3 (gate blocked types), §4 (copy) requires either an ADR or a re-review by swiss-brain.

Status: **GREEN-LIGHT to implement** with 3 open questions above (ratio 0.33 vs 0.30 confirmation, compliance-guard wiring reality check, hardcoded-FR cleanup). Nothing below is optional.
