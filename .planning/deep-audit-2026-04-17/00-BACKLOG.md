# Deep-Audit Backlog — 2026-04-17

Status after this session. Six parallel expert agents audited the codebase. Findings triaged to P0/P1/P2, P0s that could be fixed in-session were fixed; the rest are here.

## Fixed this session (atomic commits on `claude/fix-app-navigation-zkVRx`)

| Commit | Fix |
|---|---|
| `46166424` | Sentry `RuntimeError: Event loop is closed` — transient AsyncAnthropic close in LLMRouter |
| `c2717cdb` | Coach `/chat` emits camelCase JSON (tool_calls, tokensUsed, responseMeta silent-drop bug) |
| `d5891521` | 30+ Portuguese diacritic fixes across ARB + 6 audit reports to disk |
| `e18cb0b1` | Delete 6 orphan screens (~1.1k LOC dead code) |
| `c034e1e4` | ComplianceGuard: gerund bypass (garantissant / assurant / promettant) |
| `f74b129c` | Coach system prompt learns 18 life events + 8 archetypes (FATCA etc.) |

## Deferred P0s (next session, ranked by impact)

### P0 — SafeMode auto-trigger on debt/income > 0.30

**Source:** Persona-journey audit (Thomas, divorce + debtCrisis).
**Current state:** `WizardService.isSafeModeActive()` exists at `apps/mobile/lib/services/wizard_service.dart:47` and is called only from `financial_report_screen_v2.dart` + `report_builder.dart`. It is NOT wired to the coach mode selection. `AgentSafetyGate.validate(task, isSafeMode=...)` exists but nothing passes `isSafeMode=true`.
**What to do:**
1. Add `CoachProfile.isInDebtCrisis` getter: `debts.totalDettes / (revenus.netAnnuel) > 0.30` OR emergency-fund shortfall.
2. In `CoachContextBuilder` (or equivalent), when `isInDebtCrisis` is true, force `ComponentType.chatSafeMode` + disable any optimisation suggestion tools.
3. Pass `isSafeMode=ctx.isInDebtCrisis` through `AgentSafetyGate.validate`.
4. Test: Thomas persona walks in with debt ratio 0.45 → coach should refuse a 3a-optimisation suggestion and pivot to debt-reduction.
**Effort:** S-M (4-6 hours). No new dependencies.

### P0 — EU-CH pension coordination for returning_swiss + expat_eu

**Source:** Persona-journey audit (Elena, returning_swiss, retirement).
**Current state:** `AVSCalculator.contributionYears` counts only Swiss years; UE period totalisation (ALCP bilateral treaty) not modelled. Projection under-estimated by ~25% for anyone with EU career history.
**What to do:**
1. Extend `AvsCalculator` with `totalisationYears(euYears: Map<Country, int>)` — compute equivalent AVS years based on ALCP coordination.
2. Add `CoachProfile.internationalCareerYears` field (country → years) + ARB strings.
3. Surface in retirement projection with clear "dont X années reconnues via ALCP" footnote.
**Effort:** M-L (2-3 days).

### P0 — FATCA/PFIC framework for expat_us

**Source:** Persona-journey audit (Lauren, expat_us, newJob). Coach now _mentions_ FATCA via the new archetype catalog (commit `f74b129c`), but no dedicated screen or workflow.
**What to do:**
1. Add `expat_us_context.md` to RAG corpus with FATCA + PFIC + double-taxation + "most 3a providers reject US persons" facts.
2. Add `_US_PERSON_CONTEXT` constant in `claude_coach_service.py`, injected when `ctx.archetype == expat_us`.
3. Add UI warning on 3a-related screens when archetype == expat_us.
**Effort:** M (1-2 days).

## Deferred P1s

### Daily greeting + budget snapshot (Cleo gap #1)
Cap du jour is designed but unimplemented. `CoachNarrativeService` produces greetings but no circular-budget-remaining widget.
**Effort:** ~2 weeks (full Cleo-style home feed).

### Embedded action buttons in insight cards (Cleo gap #2)
Currently insights force nav away to separate screens. Should surface transfers/subscription caps/goal setters inline.
**Effort:** ~2 weeks.

### Memory visibility in home feed (Cleo gap #3)
Coach memory exists server-side (`ConversationMemoryService`) but doesn't flow back into Aujourd'hui. User doesn't see "Your chat led to this new plan."
**Effort:** ~2 weeks.

### Banned terms compliance in DE/EN/ES/IT/PT (multi-language audit P1)
Current guard is FR-only. Non-French coach responses could emit "guaranteed / garantiert / garantizado" and pass the guard.
**Effort:** S (~1 day for pattern extension + tests).

### Vector memory activation in production (2028 vision)
pgvector + `HybridSearchService` wired but disabled. Flip on + wire into `orchestrator.py`.
**Effort:** 1-2 weeks including infra.

### 6-month cashflow forecaster (2028 vision)
Extend `ForecasterService` with near-term cashflow projection + shortfall nudge.
**Effort:** 2-3 weeks.

## Deferred P2s

- Unhandled `screen=` query value silently swallowed in GoRouter redirect (add log + default).
- Regional voice covers canton law only at tone level, not tax/regime specifics.
- Tool-calling: 28 tools declared, only 3 mentioned in system prompt — other 25 are declared-but-unlearned.
- Autoresearch 10 veille agents vision doc vs reality: zero agents shipped. Not a P0 (ambitious vaporware vs urgent bug), but document the gap.
- Response quality monitor not wired to production logs.

## Risk summary for 2028 scale

1. Per-request AsyncAnthropic: partial mitigation landed (transient-close). Full fix = singleton + connection pool.
2. No vector DB durability: memory lost on uninstall.
3. Single-process coach: heavy calcs block chat.
4. No background ambient worker: users offline miss alerts.
5. Compliance drift risk: monitor exists but not wired.

## Source audit reports

- `01-nav-graph.md` — orphans, redirects, shell tabs (P0 = 6 dead files, now fixed)
- `02-persona-journeys.md` — 10 Swiss personas × 10 life events (3 broken, see above)
- `03-cleo-gap.md` — 25 Cleo patterns mapped to MINT (10 gaps ranked)
- `04-coach-context.md` — system prompt + compliance + tool calling (3 P0s, 2 fixed)
- `05-2028-vision-gap.md` — what's shipped vs. promised vs. vaporware
- `06-multi-language.md` — 6 locales × ARB parity + regional voice
