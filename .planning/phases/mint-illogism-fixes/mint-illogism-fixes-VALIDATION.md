---
phase: mint-illogism-fixes
slug: mint-illogism-fixes
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-11
updated: 2026-06-11
---

# Phase mint-illogism-fixes — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (mobile) + Maestro 2.5.1 (device flows) + oracles Python (matrice) |
| **Config file** | `apps/mobile/pubspec.yaml` (existing — no Wave 0 install) |
| **Quick run command** | `cd apps/mobile && flutter test test/services/ test/models/` (sites touchés) |
| **Full suite command** | `cd apps/mobile && flutter analyze && flutter test` |
| **Estimated runtime** | quick ~120 s · full ~600 s |

---

## Sampling Rate

- **After every task commit:** Run quick command + l'oracle de reproduction des lignes de matrice fermées par la tâche
- **After every plan wave:** Full suite + lints (`accent_lint_fr`, `validate_arb_parity`, `check_banned_terms`) + sim walkthrough (build workaround `/tmp/mint_build_ios`)
- **Before `/gsd:verify-work`:** Full suite green + flows Maestro `bug__ILLOG01/02` au statut attendu de la vague + lignes fermées citées dans les SUMMARYs
- **Max feedback latency:** 600 s

---

## Per-Task Verification Map

> Rempli par gsd-planner 2026-06-11. Oracle = la reproduction de la ligne matrice re-run ;
> parité = `financial_parity_test.dart` ; maestro = flows régression. PT = test de parité.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-T1 | 01 | 1 | MATRIX-salarie_swiss-1, cadre_divorce_hypo-2, returning_swiss_gaps-3/-4, jeune_diplome-1 | T-ILF-01-01 | parité avoir LPP au centime | parity (RED Wave 0) | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ W0 | ⬜ pending |
| 01-T2 | 01 | 1 | MATRIX-independent_no_lpp-4, expat_us-3, frontalier-2/-5, couple_acheteurs-2 | T-ILF-01-01 | clamp 64260 + 1.25% partout | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze` | ❌ W0 | ⬜ pending |
| 02-T1 | 02 | 2 | MATRIX-salarie_swiss-4, independent_no_lpp-5, expat_us-4, frontalier-3, cadre_divorce_hypo-3, couple_acheteurs-3, returning_swiss_gaps-5, D4 | T-ILF-02-01 | un taux de conversion par cas | parity+oracle+panel | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ W0 | ⬜ pending |
| 02-T2 | 02 | 2 | MATRIX-§2-rachat | T-ILF-02-01 | impact rachat base unique | parity | `cd apps/mobile && flutter test test/services/` | ❌ W0 | ⬜ pending |
| 03-T1 | 03 | 3 | MATRIX-salarie_swiss-5, independent_no_lpp-6, expat_us-5, frontalier-4, cadre_divorce_hypo-4, jeune_diplome-3, couple_acheteurs-4, returning_swiss_gaps-6, D3, §2-retraite | T-ILF-03-01 | dénominateur NET unique | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ replacement_rate.dart | ✅ done (206bb7c02) — parité W3 18/18, analyze clean |
| 03-T2 | 03 | 3 | MATRIX-§2-marge-libre | T-ILF-03-01 | net via NetIncomeBreakdown partout | parity | `cd apps/mobile && flutter test test/services/` | ✅ groupe « Base nette » | ✅ done (b4a41718c) — services 5836/5836, analyze clean |
| 04-T1 | 04 | 4 | MATRIX-independent_no_lpp-1/-2 | T-ILF-04-01 | plafond indépendant base NET | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ groupe « Plafond 3a indépendant » (4 cas) | ✅ done (37a6221ad) — parité W4 22/22, services 5840/5840, analyze clean |
| 05-T1 | 05 | 5 | MATRIX-salarie_swiss-2/-3 | T-ILF-05-01 | isMarried transmis | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ W0 | ⬜ pending |
| 05-T2 | 05 | 5 | W1 device-proof | — | valeurs uniques à l'écran | sim walkthrough | `ls .planning/_walker/illogism-fixes/w1/*.png` | ❌ | ⬜ pending |
| 06-T1 | 06 | 6 | MATRIX-D1 | T-ILF-06-01 | q_* via SecureWizardStore, zéro log | widget | `cd apps/mobile && flutter test test/screens/` | ❌ | ⬜ pending |
| 06-T2 | 06 | 6 | MATRIX-D1 | T-ILF-06-01 | grep-gate zéro log/analytics sur q_* | widget+lint+panel | `cd apps/mobile && flutter test && python3 tools/checks/accent_lint_fr.py` | ❌ | ⬜ pending |
| 07-T1 | 07 | 7 | MATRIX-independent_no_lpp-3 | T-ILF-07-01 | prédicat LPP=0 unique | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ | ⬜ pending |
| 07-T2 | 07 | 7 | MATRIX-cadre_divorce_hypo-1 | T-ILF-07-01 | divorcé jamais estimé | parity+oracle | `cd apps/mobile && flutter test` | ❌ | ⬜ pending |
| 08-T1 | 08 | 8 | MATRIX-expat_us-1 | T-ILF-08-01 | gate FATCA global, pas de bypass | widget (redirect) | `cd apps/mobile && flutter test test/screens/fatca_gate_test.dart` | ❌ | ⬜ pending |
| 08-T2 | 08 | 8 | MATRIX-expat_us-2, frontalier-1 | T-ILF-08-02 | compute archétype-aware | parity+oracle+sim | `cd apps/mobile && flutter test && flutter analyze` | ❌ | ⬜ pending |
| 09-T1 | 09 | 7 | MATRIX-D6 (diagnostic) | T-ILF-09-01 | — | semantics (RED) | `cd apps/mobile && flutter test test/screens/rente_vs_capital_semantics_test.dart` | ❌ | ⬜ pending |
| 09-T2 | 09 | 7 | MATRIX-D6 | T-ILF-09-01 | arbre AX peuplé | semantics+maestro+panel | `maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml` | ✅ (flow RED) | ⬜ pending |
| 10-T1 | 10 | 8 | MATRIX-D5 | T-ILF-10-01 | fiction ≠ réel | widget | `cd apps/mobile && flutter test test/screens/rente_vs_capital_defaults_test.dart` | ❌ | ⬜ pending |
| 10-T2 | 10 | 8 | MATRIX-D5 / ILLOG-01 | T-ILF-10-01 | flow gate | maestro | `maestro test tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` | ✅ (flow RED) | ⬜ pending |
| 11-T1 | 11 | 9 | MATRIX-D12 | T-ILF-11-02 | une source de confiance | unit | `cd apps/mobile && flutter test test/services/` | ❌ | ⬜ pending |
| 11-T2 | 11 | 9 | MATRIX-D2, jeune_diplome-5 | T-ILF-11-01 | hero gated <50, tag estimé | widget+sim | `cd apps/mobile && flutter test test/widgets/home_hero_confidence_test.dart` | ❌ | ⬜ pending |
| 12-T1 | 12 | 10 | MATRIX-cadre_divorce_hypo-5 | T-ILF-12-01 | split borné mariage | unit+oracle | `cd apps/mobile && flutter test test/services/life_events_divorce_test.dart` | ❌ | ⬜ pending |
| 12-T2 | 12 | 10 | MATRIX-cadre_divorce_hypo-5 | T-ILF-12-02 | avoir au mariage demandé | widget+panel | `cd apps/mobile && flutter test && python3 tools/checks/accent_lint_fr.py` | ❌ | ⬜ pending |
| 13-T1 | 13 | 11 | MATRIX-returning_swiss_gaps-1, §2-AVS | T-ILF-13-01 | lacunes plumbées | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ | ⬜ pending |
| 13-T2 | 13 | 11 | MATRIX-returning_swiss_gaps-2, jeune_diplome-2 | T-ILF-13-01 | scène honnête + hypothèse | widget+sim+panel | `cd apps/mobile && flutter test && flutter analyze` | ❌ | ⬜ pending |
| 14-T1 | 14 | 12 | MATRIX-D10 (diagnostic) | T-ILF-14-01 | — | grep/diagnostic | `grep -rn "marge" apps/mobile/lib/services/budget_living_engine.dart` | ✅ | ⬜ pending |
| 14-T2 | 14 | 12 | MATRIX-D10 | T-ILF-14-01 | suggestion ≤ plafond restant | unit+oracle+sim | `cd apps/mobile && flutter test test/services/suggestion_3a_cap_test.dart` | ❌ | ⬜ pending |
| 15-T1 | 15 | 12 | MATRIX-couple_acheteurs-1 | T-ILF-15-01 | revenu ménage unique | widget+oracle+panel | `cd apps/mobile && flutter test test/screens/affordability_prefill_test.dart` | ❌ | ⬜ pending |
| 15-T2 | 15 | 12 | MATRIX-W4-citation-LCC | T-ILF-15-02 | citation vérifiée | grep+pytest | `grep -c "LCC" services/backend/app/api/v1/endpoints/lucidity.py` | ✅ | ⬜ pending |
| 16-T1 | 16 | 13 | MATRIX-D7/D8 (diagnostic) | T-ILF-16-01 | — | diagnostic | `grep -n "Provider" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart` | ✅ | ⬜ pending |
| 16-T2 | 16 | 13 | MATRIX-D7, D8 | T-ILF-16-01/-02 | source unique + CTA vivant | widget+sim+panel | `cd apps/mobile && flutter test test/screens/retirement_dashboard_profile_test.dart` | ❌ | ⬜ pending |
| 17-T1 | 17 | 14 | MATRIX-D9 | T-ILF-17-01 | hypothèses what-if étiquetées | widget+sim+panel | `cd apps/mobile && flutter test test/screens/mariage_whatif_labels_test.dart` | ❌ | ⬜ pending |
| 17-T2 | 17 | 14 | MATRIX-D11, i18n hardcode + clôture phase | T-ILF-17-02 | labels localisés | grep+maestro+sim D1-D12+panel | `cd apps/mobile && flutter gen-l10n && flutter analyze && flutter test` | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/mobile/test/services/financial_parity_test.dart` — squelette des tests de parité W1 (Plan 01 Task 1 — une quantité = tous chemins d'appel = même valeur)
- [ ] Re-run baseline des oracles de la matrice (état RED documenté avant fix — Plan 01 Task 1 commit message)
- [x] Flows Maestro `bug__ILLOG01/02` RED confirmés sur build courant (fait 2026-06-11, run ~/.maestro/tests/2026-06-11_065259)

## Couverture des 44 findings + D1-D12 (audit planner)

- **Plans 01-05 (W1)** : 27 DIVERGENT (avoir LPP, rente/conversion, remplacement, plafond 3a, économie 3a) + §2 marge-libre/rachat/AVS-composition/retraite-composition par extension de cause racine.
- **Plans 06-08 (W2)** : 10 ILLOGICAL_FOR_ARCHETYPE (D1 racine, gates LPP=0/divorcé/frontalier/FATCA).
- **Plans 09-11 (W3+ILLOG02)** : D2, D5, D6, D12, jeune_diplome-5, flows ILLOG01/02.
- **Plans 12-15 (W4)** : cadre_divorce_hypo-5, returning_swiss_gaps-1/-2, jeune_diplome-2, D10, couple_acheteurs-1, citation LCC.
- **Plans 16-17 (W5)** : D7, D8, D9, D11, i18n hardcode.
- **SOURCED (5, contrôles négatifs)** : salarie_swiss-6, cadre_divorce_hypo-6, jeune_diplome-1, jeune_diplome-4, couple_acheteurs-5 — anti-régression encodée dans les tests de parité (plans 01, 04, 15).
- **§1 doublons d'écrans** : hors scope phase (observations, pas dans les 44 — CONTEXT boundary).
