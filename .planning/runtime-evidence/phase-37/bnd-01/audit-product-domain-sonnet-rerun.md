Now I have everything needed for a complete verdict.

---

## Product/domain verdict: PASS

---

### What this diff does

| Area | Change |
|---|---|
| i18n (6 locales) | `sim3aDebtLockedTitle` / `sim3aDebtStrategyMessage` softened from debt-specific to generic financial-stability framing |
| `simulator_3a_screen.dart` | Null-profile branch upgraded from dead-end text to `MintEmptyState` with CTA → `/coach/chat` |
| `recommendation_card.dart` | **Deleted** (dead, never wired to a live screen) |
| `buyback_widget.dart` | **Deleted** (dead, separate from the live `/rachat-lpp` + `rachat_echelonne_screen.dart` flow) |
| Tests | Aligned to the deletions; added emergency-fund-only crisis test; replaced null-profile crash-guard with navigation path test |

---

### P0 findings

None.

---

### P1 findings

None introduced by this diff.

> **Note — pre-existing, not in scope of this diff:**
> `pilier3aPlafondAvecLpp = 7258.0` (`social_insurance.dart:311`) and `lppDeductionCoordination = 26460.0` (`social_insurance.dart:57`) are 2025 values. As of July 2026 in the audit context, both AVS-indexed thresholds may be stale. Neither is touched here, but any screen that computed savings against these in production since January 2026 would show wrong figures if the 2026 adjustment changed them. Recommend a constant-freshness pass as a separate story.

---

### P2 findings

**P2-1** — `safe_mode_gate_test.dart`, test group now numbered "GROUP 2" / "GROUP 3" (renumbered after RecommendationCard removal). No functional impact, but group numbers in test output will silently shift if CI parses them. Pure cosmetic.

**P2-2** — `INTERACTION_COVERAGE_AUDIT.md`: `/pilier-3a` remains in the **uncovered** registry (ref count +1 reflects the new CTA in `simulator_3a_screen.dart`). Not introduced here, but the route is now referenced in 28+ places with no declared interaction-registry node. Worth registering.

**P2-3** — `app_pt.arb`: "A regra dos 5 contas" (line unchanged, pre-existing) — Portuguese grammar: _contas_ is feminine, correct form is _das 5 contas_, not _dos 5 contas_. Pre-existing, not introduced here.

---

### Swiss domain review

| Domain | Status |
|---|---|
| **AVS** | Not touched |
| **LPP / buyback** | `BuybackWidget` deleted but `/rachat-lpp` route and `rachat_echelonne_screen.dart` remain. Deletion removes a dead widget; live LPP flow unaffected |
| **3a** | Calculator logic, ceiling constants, canton-aware marginal rate untouched. Copy change is accuracy-neutral |
| **Tax / fiscal** | No canton logic, rate tables, or disclaimer changed |
| **Mortgage** | Not touched |
| **Insurance** | Not touched |
| **Succession / donation** | Not touched |
| **Safe-mode trigger semantics** | **Confirmed correct** — Signal C at `coach_profile.dart:3357-3378` (`monthsLiquidity < 3` → crisis) makes the old "Priorité au désendettement" copy **factually wrong** for zero-savings users with no consumer debt. The new generic framing is the accurate description |
| **FinSA / LSFin compliance** | Unchanged disclaimer in all locales; no advice language introduced |

---

### MINT product logic review

The diff moves toward the ledger → DataQuest → scenario → dossier spine:

- **Null-profile state** now routes to `/coach/chat` (DataQuest entry) instead of silently failing — correct product model behaviour. Users who have no profile see a clear diagnostic path.
- **Safe-mode copy precision** prevents the app from giving a false implicit instruction ("repay debt") to a user whose real problem is an insufficient emergency fund — a distinct Swiss financial situation.
- **Dead-widget removal** removes two facades that had no ledger read-back or dossier write: `RecommendationCard` and `BuybackWidget` were rendering static shells without wiring to the data ledger or any scenario return path. Their deletion reduces facade-without-wiring surface area.

No new scenarios, routes, or financial conclusions are added. The 3a simulator product logic, tax calculations, and specialist-handoff disclaimer are all unchanged.
