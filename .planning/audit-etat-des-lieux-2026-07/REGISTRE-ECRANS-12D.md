---
description: "Registre écran-par-écran MINT : 108 écrans × 12 dimensions (route/calculs/texte/logique/doublons/métier-lois + a11y/perf/design-system/lucidité/temps/privacy), pré-rempli statiquement sur dev@5199757 (2026-07-29). Comptes clés : 353 littéraux numériques sur 54 écrans, 268 strings FR hardcodées sur 41 écrans, 110 citations de lois sur 21 écrans, 2 orphelins réels. Tranche firstJob = premier lot revue complète ; 14 lots Codex avec nourriciers. Base des passes Codex de la Phase 2 runtime."
---

# REGISTRE ÉCRAN-PAR-ÉCRAN — 12 DIMENSIONS (statique)

- **SHA figé** : `dev@51997578823191afa6dbf8f69524bc429fae5980` (2026-07-29 13:13 +0200, merge PR #1090) — snapshot extrait par `git archive`, worktree principal non touché.
- **Méthode** : parse à pile d'imbrication de `apps/mobile/lib/app.dart` (158 GoRoute), extraction des redirects par bloc, croisement ScreenRegistry (142 entrées `route:`), grep littéral `context.go/push` sur screens+widgets+services+providers, métriques par fichier (regex — voir « Limites »).
- **Statuts** : `ok` = rien détecté statiquement · `défaut` = défaut statique cité `path:ligne` · `RT` = à-vérifier-runtime (donnée dynamique, Phase 2).

## 0. Synthèse chiffrée

| Compte | Valeur |
|---|---|
| Fichiers sous `lib/screens/**` | 126 (dont 108 écrans, 18 support/scènes/widgets) |
| Routes GoRouter déclarées | 158 |
| — routes-écrans réelles (builder) | 110 |
| — alias redirects (canonicalisation) | 48 (47 littéraux + `/household/accept` dynamique → /couple/accept) |
| — îles-routes restantes | 6 (`/auth/verify` deeplink + 5 debug/admin/e2e volontaires) |
| Écrans-îles (classe sans chemin) | 9 dont **2 orphelins réels** (AnonymousChatScreen, DocumentStreamResultScreen) + 7 debug/admin volontaires |
| Littéraux numériques user-facing flaggés | **353 sites** sur 54 écrans |
| Strings FR hardcodées (vs AppLocalizations) | **268 sites** sur 41 écrans |
| Termes bannis LSFin en copy user | 0 (cross-vérifié grep) — baseline lint prescriptif dev = vide (0 entrée) |
| onTap/onPressed morts | 1 sites |
| Écrans sans AUCUN state L/E/V | 14 |
| Citations de lois en dur (revue swiss-brain) | **110 sites** sur 21 écrans |
| Clusters doublons | 9 (dont 2 résolus par redirects : C1 onboarding, C2 rente-vs-capital) |
| D7 A11y — écrans interactifs (≥5 taps) avec 0 Semantics | 1 + 5 sites cible-tactile suspects |
| D8 Perf — signaux statiques (listes non virtualisées, shrinkWrap, Image.network) | **98 sites** sur 51 écrans |
| D9 Design system — sites prefer_mint_* dans screens/ (lints exécutés) | **97 sites** sur 31 écrans (fontSize 55, CTA 35, radius 3, color 2, fonts 2) — net-new vs baseline dev : 0 |
| D10 Lucidité — écrans chiffrés SANS appareil de confiance/enrichment | **43 écrans** |
| D11 Temps — écrans chiffrés sans millésime/source datée visible | **67 écrans** (à confirmer runtime) |
| D12 Privacy — print/debugPrint en écrans (dont interpolation non-exception en contexte sensible) | 42 sites, dont **1 écrans à risque** |

**Delta vs ROUTE-MAP 2026-07-23** : la campagne navigation a bien tourné — 17 îles → 6 (toutes volontaires sauf deeplink `/auth/verify` à vérifier), ~10 variantes onboarding → 1 shell canonique `/onb` + 9 redirects avec breadcrumb `legacyRedirectHit`, 4 routes rente-vs-capital → 1 canonique + 3 redirects. La table des routes reste à 158 (47 alias conservés volontairement pour compat deeplinks).

## 1. Tableau maître (126 fichiers × 12 dimensions)

Nav : 🟢 câblée/tab · 🟡 registre/séquence-seulement · 🔴 île · 🟠 sans-route-mais-instancié · ⚙️ fichier support (revu avec son écran hôte).
Calc : `défaut(n)` = n littéraux numériques flaggés · `DÉFAUT` = littéraux + calcul local sans financial_core · `RT` = chiffres servis par service (runtime).
Texte : `défaut(n)` = n strings FR hardcodées (l10n = nb refs AppLocalizations). Log : présence Loading/Erreur/Vide + taps morts.
A11y : sem = refs Semantics, int = sites interactifs. Perf : signaux statiques. DS : sites prefer_mint_*. Lucid : appareil confiance si chiffres. Temps : millésime visible si chiffres. Priv : print/log.

| Fichier (`apps/mobile/lib/`) | Route(s) | Nav | Calc | Texte (l10n) | Log | Dbl | Lois | A11y | Perf | DS | Lucid | Temps | Priv |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| screens/about_screen.dart | /about | 🟢 | ok | ok (0) | ··· | — | — | ok(0sem) | ok | défaut(2) | — | — | ok |
| screens/admin/admin_gate.dart | — | ⚙️ | RT | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/admin/admin_shell.dart | /admin/debug-spine<br>/admin/routes | 🔴 | ok | défaut(1) (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/admin/mint_debug_spine_screen.dart | — | 🔴  | ok | défaut(6) (0) | LE· | — | — | ok(1sem) | défaut(1) | ok | — | — | ok |
| screens/admin/mint_debug_tools_gate.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/admin/routes_registry_screen.dart | — | 🔴  | RT | défaut(4) (0) | ··V | — | — | ok(1sem) | ok | défaut(2) | défaut(0) | RT(0) | ok |
| screens/admin_analytics_screen.dart | /profile/admin-analytics | 🟡 | RT | défaut(2) (11) | LEV | — | — | ok(2sem) | ok | défaut(1) | défaut(0) | RT(0) | ok |
| screens/admin_observability_screen.dart | /profile/admin-observability | 🟡 | défaut | défaut(3) (13) | LEV | — | — | ok(2sem) | défaut(2) | défaut(3) | défaut(0) | RT(0) | ok |
| screens/advisor/financial_report_screen_v2.dart | /rapport | 🟡 | ok | ok (0) | ·EV | — | 2 | ok(6sem) | défaut(1) | ok | — | — | ok |
| screens/anonymous/anonymous_chat_screen.dart | — | 🔴  | défaut | défaut(1) (0) | LEV | C3-chat | — | ok(1sem) | défaut(1) | ok | défaut(0) | RT(0) | warn(1) |
| screens/arbitrage/allocation_annuelle_screen.dart | /arbitrage/allocation-annuelle | 🟡 | défaut | ok (0) | ·E· | — | — | ok(6sem) | ok | ok | RT(25) | RT(0) | ok |
| screens/arbitrage/arbitrage_bilan_screen.dart | /arbitrage/bilan | 🟢 | RT | défaut(1) (0) | ··V | — | — | ok(4sem) | défaut(4) | ok | RT(17) | RT(0) | ok |
| screens/arbitrage/location_vs_propriete_screen.dart | /arbitrage/location-vs-propriete | 🟡 | défaut | ok (0) | ··· | — | — | ok(1sem) | ok | ok | RT(29) | RT(0) | ok |
| screens/arbitrage/rente_vs_capital_screen.dart | /retraite/rente-vs-capital | 🟢 | RT | défaut(1) (0) | LEV | — | — | défaut(2cible) | ok | ok | RT(41) | RT(0) | défaut(1) |
| screens/aujourdhui/aujourdhui_screen.dart | /home | 🟢 | RT | ok (5) | L·V | C4-dashboards | — | ok(0sem) | ok | ok | RT(33) | RT(0) | ok |
| screens/auth/auth_platform.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/auth/auth_redirect.dart | — | ⚙️ | ok | ok (0) | ··V | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/auth/forgot_password_screen.dart | /auth/forgot-password | 🟢 | ok | ok (24) | LEV | — | — | ok(7sem) | ok | défaut(1) | — | — | ok |
| screens/auth/login_screen.dart | /auth/login | 🟢 | ok | défaut(1) (26) | LEV | — | — | ok(7sem) | ok | ok | — | — | ok |
| screens/auth/register_screen.dart | /auth/register | 🟢 | ok | défaut(1) (61) | LEV | — | — | ok(10sem) | ok | ok | — | — | ok |
| screens/auth/verify_email_screen.dart | /auth/verify-email | 🟢 | ok | ok (14) | LEV | — | — | ok(3sem) | ok | ok | — | — | ok |
| screens/bank_import_screen.dart | /bank-import | 🟢 | ok | ok (0) | LEV | — | — | ok(1sem) | ok | défaut(19) | — | — | ok |
| screens/budget/budget_container_screen.dart | /budget | 🟢 | ok | ok (0) | L·V | C7-budget | — | ok(2sem) | ok | ok | — | — | ok |
| screens/budget/budget_screen.dart | — | 🟠  | défaut | ok (0) | LEV | C7-budget | — | ok(13sem) | défaut(1) | ok | RT(1) | RT(0) | ok |
| screens/budget/budget_setup_screen.dart | /budget/setup | 🟢 | défaut | ok (0) | LEV | C7-budget | — | ok(6sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/byok_settings_screen.dart | /profile/byok | 🟢 | ok | ok (0) | LEV | — | — | ok(8sem) | ok | défaut(7) | — | — | ok |
| screens/cantonal_benchmark_screen.dart | /cantonal-benchmark | 🟡 | ok | défaut(1) (0) | LE· | — | — | ok(3sem) | défaut(1) | ok | — | — | ok |
| screens/coach/chat_as_verb_demo_screen.dart | /debug/chat-as-verb | 🔴 | défaut | défaut(4) (0) | ··· | C3-chat | — | ok(0sem) | défaut(1) | ok | défaut(0) | ok(1) | ok |
| screens/coach/coach_archetype_guard.dart | — | ⚙️ | RT | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/coach/coach_chat_screen.dart | /coach/chat | 🟢 | RT | défaut(14) (9) | LEV | C3-chat | 6 | ok(5sem) | ok | ok | RT(7) | RT(0) | warn(19) |
| screens/coach/conversation_history_screen.dart | /coach/history | 🟡 | ok | ok (9) | LEV | — | — | ok(4sem) | ok | ok | — | — | ok |
| screens/coach/optimisation_decaissement_screen.dart | /decaissement | 🟡 | ok | ok (0) | ·E· | — | — | ok(2sem) | défaut(1) | défaut(3) | — | — | ok |
| screens/coach/retirement_dashboard_screen.dart | /retraite | 🟢 | RT | défaut(7) (0) | LEV | C4-dashboards | 7 | ok(11sem) | défaut(3) | ok | RT(57) | RT(0) | warn(4) |
| screens/coach/succession_patrimoine_screen.dart | /succession | 🟡 | défaut | défaut(3) (0) | ··· | — | — | ok(2sem) | ok | défaut(1) | défaut(0) | RT(0) | ok |
| screens/concubinage_screen.dart | /concubinage | 🟡 | défaut | ok (0) | LEV | — | — | ok(4sem) | défaut(4) | ok | défaut(0) | RT(0) | ok |
| screens/confidence/confidence_dashboard_screen.dart | /confidence | 🟡 | ok | ok (0) | ·E· dead×1 | C4-dashboards | — | ok(1sem) | défaut(3) | ok | — | — | ok |
| screens/consumer_credit_screen.dart | /simulator/credit | 🟡 | DÉFAUT | défaut(3) (0) | ·E· | — | — | ok(1sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/coverage_check_screen.dart | /assurances/coverage | 🟡 | ok | ok (0) | LEV | — | — | ok(1sem) | défaut(2) | ok | — | — | ok |
| screens/debt_prevention/debt_ratio_screen.dart | /debt/ratio | 🟡 | défaut | ok (0) | ·E· | — | — | ok(3sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/debt_prevention/help_resources_screen.dart | /debt/help | 🟡 | défaut | ok (0) | ·E· | — | — | ok(1sem) | ok | défaut(5) | défaut(0) | RT(0) | ok |
| screens/debt_prevention/repayment_screen.dart | /debt/repayment | 🟢 | défaut | ok (0) | ·EV | — | — | ok(8sem) | défaut(1) | ok | RT(2) | RT(0) | ok |
| screens/debt_risk_check_screen.dart | /check/debt | 🟡 | ok | ok (0) | ·E· | — | — | ok(1sem) | défaut(1) | défaut(3) | — | — | ok |
| screens/debug/debug_budget_bootstrap_screen.dart | /__e2e/budget-direct-inputs | 🔴 | ok | ok (0) | L·· | — | 1 | ok(1sem) | ok | ok | — | — | ok |
| screens/debug/debug_mint2_account_claim_screen.dart | /__e2e/row23-independent-no-lpp-profile | 🔴 | ok | ok (0) | L·· | — | — | ok(2sem) | ok | ok | — | — | ok |
| screens/debug/debug_profile_bootstrap_screen.dart | — | 🔴  | ok | défaut(1) (0) | LE· | — | — | ok(1sem) | ok | ok | — | — | ok |
| screens/deces_proche_screen.dart | /life-event/deces-proche | 🟡 | défaut | ok (0) | ·EV | — | — | ok(2sem) | défaut(3) | ok | défaut(0) | RT(0) | ok |
| screens/demenagement_cantonal_screen.dart | /life-event/demenagement-cantonal | 🟡 | défaut | ok (0) | ·EV | — | — | ok(6sem) | défaut(1) | ok | RT(3) | RT(0) | ok |
| screens/disability/disability_gap_screen.dart | /invalidite | 🟡 | défaut | défaut(3) (0) | ·E· | — | 3 | ok(2sem) | ok | défaut(1) | RT(1) | RT(0) | ok |
| screens/disability/disability_insurance_screen.dart | /disability/insurance | 🟡 | défaut | défaut(14) (0) | ··V | C5-disability | 6 | ok(1sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/disability/disability_self_employed_screen.dart | /disability/self-employed | 🟡 | défaut | ok (0) | ··· | C5-disability | — | ok(1sem) | ok | défaut(1) | RT(1) | RT(0) | ok |
| screens/divorce_simulator_screen.dart | /divorce | 🟡 | défaut | ok (0) | ·EV | — | — | ok(7sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/document_detail_screen.dart | /documents/:id | 🟡 | ok | ok (0) | ·EV | — | — | ok(1sem) | ok | défaut(4) | — | — | ok |
| screens/document_scan/avs_guide_screen.dart | /scan/avs-guide | 🟡 | ok | ok (0) | L·· | — | — | ok(2sem) | défaut(1) | défaut(3) | — | — | ok |
| screens/document_scan/document_impact_screen.dart | /scan/impact | 🟢 | RT | défaut(8) (6) | LEV | — | 2 | ok(1sem) | défaut(3) | défaut(1) | RT(42) | RT(0) | warn(2) |
| screens/document_scan/document_scan_screen.dart | /scan | 🟢 | défaut | défaut(21) (0) | LEV | C8-document-scan | 2 | ok(2sem) | ok | ok | RT(36) | RT(0) | warn(14) |
| screens/document_scan/document_stream_result_screen.dart | — | 🔴  | RT | défaut(1) (0) | ··· | C8-document-scan | — | ok(0sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/document_scan/extraction_review_screen.dart | /scan/review | 🟢 | RT | défaut(1) (0) | ·EV | — | 4 | ok(1sem) | défaut(2) | défaut(4) | RT(44) | RT(0) | ok |
| screens/documents_screen.dart | /documents | 🟢 | ok | ok (0) | LEV | — | — | ok(5sem) | défaut(2) | défaut(6) | — | — | ok |
| screens/donation_screen.dart | /life-event/donation | 🟡 | défaut | défaut(10) (0) | ·EV | — | 1 | ok(6sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/education/comprendre_hub_screen.dart | /education/hub | 🟢 | ok | ok (0) | ··· | — | — | ok(1sem) | ok | ok | — | — | ok |
| screens/education/theme_detail_screen.dart | /education/theme/:id | 🟡 | ok | ok (0) | ·E· | — | — | ok(1sem) | défaut(2) | défaut(2) | — | — | ok |
| screens/expat_screen.dart | /expatriation | 🟡 | défaut | défaut(32) (0) | LEV | — | 22 | ok(7sem) | défaut(5) | ok | défaut(0) | RT(0) | ok |
| screens/explore/explore_hub_screen.dart | /explore/famille<br>/explore/fiscalite<br>/explore/logement<br>/explore/patrimoine<br>/explore/retraite<br>/explore/sante<br>/explore/travail | 🟡 | ok | ok (0) | ··· | C9-explore-hub | — | ok(0sem) | ok | défaut(1) | — | — | ok |
| screens/explore/explorer_screen.dart | /explore | 🟢 | ok | ok (0) | ··· | C9-explore-hub | — | ok(1sem) | ok | défaut(1) | — | — | ok |
| screens/first_job_screen.dart | /first-job | 🟡 | DÉFAUT | défaut(6) (19) | ·EV | — | 8 | ok(5sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/fiscal_comparator_screen.dart | /fiscal | 🟢 | défaut | ok (0) | LEV | — | — | ok(1sem) | défaut(4) | ok | RT(2) | RT(0) | ok |
| screens/frontalier_screen.dart | /segments/frontalier | 🟡 | défaut | ok (0) | LE· | — | 3 | ok(10sem) | défaut(3) | ok | défaut(0) | RT(0) | ok |
| screens/gender_gap_screen.dart | /segments/gender-gap | 🟡 | défaut | ok (0) | LEV | — | — | ok(4sem) | défaut(1) | ok | RT(1) | RT(0) | ok |
| screens/household/accept_invitation_screen.dart | /couple/accept | 🟡 | ok | ok (0) | LEV | — | — | ok(1sem) | ok | défaut(3) | — | — | ok |
| screens/household/household_screen.dart | /couple | 🟢 | RT | ok (0) | LEV | — | — | ok(1sem) | défaut(2) | ok | défaut(0) | RT(0) | ok |
| screens/housing_sale_screen.dart | /life-event/housing-sale | 🟡 | défaut | défaut(3) (0) | ·E· | — | 1 | ok(2sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/independant_screen.dart | /segments/independant | 🟡 | défaut | défaut(13) (0) | ·EV | — | 13 | ok(6sem) | défaut(3) | défaut(2) | défaut(0) | RT(0) | ok |
| screens/independants/avs_cotisations_screen.dart | /independants/avs | 🟡 | DÉFAUT | ok (0) | LE· | — | — | ok(4sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/independants/dividende_vs_salaire_screen.dart | /independants/dividende-salaire | 🟡 | DÉFAUT | défaut(45) (0) | ·EV | — | 6 | ok(3sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/independants/ijm_screen.dart | /independants/ijm | 🟡 | DÉFAUT | ok (0) | ·E· | — | — | ok(1sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/independants/lpp_volontaire_screen.dart | /independants/lpp-volontaire | 🟡 | DÉFAUT | ok (0) | L·· | — | — | ok(5sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/independants/pillar_3a_indep_screen.dart | /independants/3a | 🟡 | DÉFAUT | ok (0) | L·· | — | — | ok(4sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/job_comparison_screen.dart | /simulator/job-comparison | 🟡 | défaut | défaut(1) (0) | ·E· | — | — | ok(8sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/lamal_franchise_screen.dart | /assurances/lamal | 🟡 | défaut | ok (0) | ··V | — | 1 | ok(3sem) | défaut(3) | ok | défaut(0) | RT(0) | ok |
| screens/landing_screen.dart | / | 🟢 | ok | ok (10) | ··· | — | — | ok(6sem) | ok | ok | — | — | ok |
| screens/lpp_deep/epl_screen.dart | /epl | 🟡 | défaut | ok (0) | ·E· | — | — | ok(2sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/lpp_deep/libre_passage_screen.dart | /libre-passage | 🟡 | défaut | défaut(7) (0) | ·E· | — | 3 | ok(2sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/lpp_deep/rachat_echelonne_screen.dart | /rachat-lpp | 🟡 | défaut | défaut(8) (0) | ·E· | — | 3 | ok(6sem) | ok | ok | RT(2) | RT(0) | ok |
| screens/mariage_screen.dart | /mariage | 🟡 | défaut | ok (0) | LEV | — | — | ok(6sem) | défaut(6) | ok | RT(4) | RT(0) | ok |
| screens/mon_argent/mon_argent_screen.dart | /mon-argent | 🟢 | ok | défaut(1) (57) | LE· | C4-dashboards | — | défaut(2cible) | ok | ok | — | — | ok |
| screens/mortgage/affordability_screen.dart | /hypotheque | 🟡 | défaut | défaut(1) (0) | ·E· | — | — | ok(4sem) | ok | ok | RT(3) | RT(0) | ok |
| screens/mortgage/amortization_screen.dart | /mortgage/amortization | 🟡 | défaut | défaut(1) (0) | ·EV | — | — | ok(1sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/mortgage/epl_combined_screen.dart | /mortgage/epl-combined | 🟡 | défaut | ok (0) | ·EV | C6-epl | — | ok(3sem) | défaut(1) | défaut(2) | défaut(0) | RT(0) | ok |
| screens/mortgage/imputed_rental_screen.dart | /mortgage/imputed-rental | 🟡 | défaut | ok (0) | ·E· | — | — | ok(3sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/mortgage/saron_vs_fixed_screen.dart | /mortgage/saron-vs-fixed | 🟡 | défaut | ok (0) | ·EV | — | — | ok(2sem) | défaut(1) | défaut(2) | défaut(0) | RT(0) | ok |
| screens/naissance_screen.dart | /naissance | 🟡 | défaut | ok (0) | LEV | — | — | ok(5sem) | défaut(6) | ok | défaut(0) | RT(0) | ok |
| screens/onboarding/data_block_enrichment_screen.dart | /data-block/:type | 🟡 | RT | ok (0) | LEV | C1-onboarding | 15 | ok(2sem) | défaut(1) | ok | RT(11) | RT(0) | ok |
| screens/onboarding/mvp_wedge/discrete_adjust_control.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(9sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/dossier_strip.dart | — | ⚙️ | ok | défaut(2) (0) | ··V | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/onboarding_provider.dart | — | ⚙️ | RT | défaut(3) (0) | ··V | — | 1 | ok(0sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/onboarding_shell_screen.dart | /onb | 🟢 | défaut | défaut(29) (64) | ·E· | C1-onboarding | 1 | ok(13sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart | — | ⚙️ | défaut | défaut(6) (3) | ··· | — | 2 | ok(0sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart | — | ⚙️ | défaut | défaut(6) (3) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart | — | ⚙️ | ok | défaut(1) (0) | ·E· | — | — | ok(2sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart | — | ⚙️ | défaut | ok (0) | ··· | — | 6 | ok(4sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart | — | ⚙️ | défaut | défaut(7) (7) | ··· | — | 1 | ok(0sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(3sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart | — | 🟠  | ok | ok (0) | ··· | — | — | ok(4sem) | ok | ok | — | — | ok |
| screens/onboarding/mvp_wedge/widgets/onboarding_choice_button.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/open_banking/consent_screen.dart | /open-banking/consents | 🟡 | ok | ok (0) | ·E· | — | — | ok(1sem) | défaut(2) | défaut(5) | — | — | ok |
| screens/open_banking/open_banking_hub_screen.dart | /open-banking | 🟡 | ok | ok (0) | LE· | — | — | ok(1sem) | défaut(1) | ok | — | — | ok |
| screens/open_banking/transaction_list_screen.dart | /open-banking/transactions | 🟡 | défaut | ok (0) | ·EV | — | — | ok(2sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/pillar_3a_deep/provider_comparator_screen.dart | /3a-deep/comparator | 🟡 | ok | ok (0) | ·EV | — | — | ok(1sem) | ok | défaut(4) | — | — | ok |
| screens/pillar_3a_deep/real_return_screen.dart | /3a-deep/real-return | 🟡 | RT | ok (0) | LE· | — | — | ok(3sem) | défaut(1) | ok | défaut(0) | RT(0) | ok |
| screens/pillar_3a_deep/retroactive_3a_screen.dart | /3a-retroactif | 🟡 | défaut | défaut(3) (0) | ·EV | — | — | défaut(1cible) | ok | ok | RT(1) | RT(0) | ok |
| screens/pillar_3a_deep/staggered_withdrawal_screen.dart | /3a-deep/staggered-withdrawal | 🟡 | défaut | ok (0) | ·EV | — | — | ok(1sem) | ok | ok | RT(1) | RT(0) | ok |
| screens/profile/financial_summary_screen.dart | /profile/bilan | 🟢 | RT | défaut(1) (1) | ·EV | C4-dashboards | — | ok(12sem) | ok | ok | RT(8) | RT(0) | warn(1) |
| screens/profile/privacy_center_screen.dart | /profile/privacy | 🟢 | ok | ok (0) | ·EV | — | — | défaut(0sem/7int) | défaut(1) | ok | — | — | ok |
| screens/profile/privacy_control_screen.dart | /profile/privacy-control | 🟡 | ok | défaut(3) (0) | LEV | — | — | ok(3sem) | défaut(4) | ok | — | — | ok |
| screens/settings/confidentialite_settings_screen.dart | /settings/confidentialite | 🟢 | ok | ok (0) | ··· | — | — | ok(2sem) | défaut(1) | ok | — | — | ok |
| screens/settings/langue_settings_screen.dart | /settings/langue | 🟡 | ok | ok (0) | ··· | — | — | ok(0sem) | ok | défaut(1) | — | — | ok |
| screens/simulator_3a_screen.dart | /pilier-3a | 🟢 | défaut | défaut(1) (0) | ·E· | — | — | ok(1sem) | ok | ok | RT(2) | RT(0) | ok |
| screens/simulator_compound_screen.dart | /simulator/compound | 🟡 | DÉFAUT | défaut(1) (0) | ·E· | — | — | ok(1sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/simulator_leasing_screen.dart | /simulator/leasing | 🟡 | DÉFAUT | ok (0) | ·E· | — | — | ok(1sem) | ok | ok | défaut(0) | RT(0) | ok |
| screens/slm_settings_screen.dart | /profile/slm | 🟡 | défaut | ok (64) | LE· | — | — | ok(6sem) | défaut(1) | défaut(5) | défaut(0) | RT(0) | ok |
| screens/timeline_screen.dart | /timeline | 🟡 | ok | ok (0) | ·E· | — | — | ok(2sem) | ok | défaut(1) | — | — | ok |
| screens/unemployment_screen.dart | /unemployment | 🟡 | DÉFAUT | ok (26) | ·E· | — | — | ok(8sem) | défaut(1) | défaut(1) | défaut(0) | RT(0) | ok |
| screens/waitlist/waitlist_args.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/waitlist/waitlist_screen.dart | /waitlist | 🟢 | ok | ok (0) | ·E· | — | — | ok(0sem) | ok | ok | — | — | ok |
| screens/waitlist/widgets/waitlist_form.dart | — | ⚙️ | ok | ok (0) | LE· | — | — | ok(2sem) | ok | ok | — | — | ok |
| screens/waitlist/widgets/waitlist_success.dart | — | ⚙️ | ok | ok (0) | ··· | — | — | ok(0sem) | ok | ok | — | — | ok |

## 2. Annexe défauts — références path:ligne

Sites cités = premiers de chaque fichier (échantillon plafonné) ; le compte entre parenthèses est le total exact. Chemins relatifs à la racine repo.

### screens/expat_screen.dart — score 37
- **Calculs** (10 sites) :
  - `apps/mobile/lib/screens/expat_screen.dart:1375` — Chaque ann\u00e9e manquante r\u00e9duit ta rente AVS de ~2.3
  - `apps/mobile/lib/screens/expat_screen.dart:1376` — 10 ans = \u221223% \u00e0 vie.
  - `apps/mobile/lib/screens/expat_screen.dart:81` — [const] 80000 :: double _pillar3aBalance = 80000;
  - `apps/mobile/lib/screens/expat_screen.dart:82` — [const] 250000 :: double _lppBalance = 250000;
  - `apps/mobile/lib/screens/expat_screen.dart:271` — [const] 500000 :: final valid = v > 0 && v <= 500000;
  - `apps/mobile/lib/screens/expat_screen.dart:308` — [const] 20000.0 :: income >= 20000.0 &&
  - `apps/mobile/lib/screens/expat_screen.dart:862` — [const] 20000 :: min: 20000,
  - `apps/mobile/lib/screens/expat_screen.dart:991` — [const] 250000 :: min: 250000,
  - `apps/mobile/lib/screens/expat_screen.dart:1007` — [const] 500000 :: min: 500000,
  - `apps/mobile/lib/screens/expat_screen.dart:1559` — [const] 500000 :: max: 500000,
- **Texte** (32 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/expat_screen.dart:1314` — « 3\u00e8me pilier 3a \u2014 cl\u00f4ture ou gel »
  - `apps/mobile/lib/screens/expat_screen.dart:1318` — « Contacte ta banque pour planifier la cl\u00f4ture ou le transfert du 3 »
  - `apps/mobile/lib/screens/expat_screen.dart:1321` — « Un 3a non g\u00e9r\u00e9 avant le d\u00e9part peut bloquer des fonds p »
  - `apps/mobile/lib/screens/expat_screen.dart:1324` — « LPP \u2014 libre passage »
  - `apps/mobile/lib/screens/expat_screen.dart:1328` — « Demande le transfert de ton avoir LPP sur un compte de libre passage o »
- **Métier/lois** (22 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/expat_screen.dart:523` — « lpp »
  - `apps/mobile/lib/screens/expat_screen.dart:1314` — « 3\u00e8me pilier 3a \u2014 cl\u00f4ture ou gel »
  - `apps/mobile/lib/screens/expat_screen.dart:1319` — « OPP3 art. 1 »
  - `apps/mobile/lib/screens/expat_screen.dart:1324` — « LPP \u2014 libre passage »
  - `apps/mobile/lib/screens/expat_screen.dart:1328` — « Demande le transfert de ton avoir LPP sur un compte de libre passage o »
  - `apps/mobile/lib/screens/expat_screen.dart:1329` — « LPP art. 5 + LFLP art. 4 »
- **Perf** (5 signaux) :
  - `apps/mobile/lib/screens/expat_screen.dart:743` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/expat_screen.dart:1258` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/expat_screen.dart:1903` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/expat_screen.dart:1674` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/expat_screen.dart:1785` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/expat_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/independants/dividende_vs_salaire_screen.dart — score 37
- **Calculs** (7 sites) :
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:137` — est imposé à 50% (participation qualifiante) et échappe 
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:233` — par rapport à 100% salaire
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:270` — Si la part salaire est inférieure à ~60% du bénéfice, 
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:328` — Charge si 100% salaire
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:485` — Les cotisations AVS (environ 12.5% au total) ne s\'appliquen
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:33` — [const] 200000 :: double _benefice = 200000;
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:162` — [const] 500000 :: max: 500000,
- **Calculs** : 7 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Texte** (45 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:135` — « Si tu possèdes une SA ou Sàrl, tu peux te verser une  »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:136` — « combinaison de salaire et de dividendes. Le dividende  »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:137` — « est imposé à 50% (participation qualifiante) et échappe  »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:138` — « aux cotisations AVS. Trouve le split le plus adapte. »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:231` — « Le split adapté te fait économiser  »
- **Métier/lois** (6 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:138` — « aux cotisations AVS. Trouve le split le plus adapte. »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:273` — « Cela entraîne des cotisations AVS rétroactives. »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:484` — « AVS uniquement sur le salaire »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:485` — « Les cotisations AVS (environ 12.5% au total) ne s\'appliquent  »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:600` — « Outil éducatif — ne constitue pas un conseil financier (LSFin). »
  - `apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart:605` — « Sources\u00a0: LIFD art.\u00a018, 20, 33\u00a0; CO art.\u00a0660 »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/onboarding/mvp_wedge/onboarding_shell_screen.dart — score 33
- **Calculs** (6 sites) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:1215` — 63% — c\u2019est, en moyenne, ce que tu gardes à 65 ans.
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:1219` — Ta capacité d\u2019emprunt tient sur trois chiffres : apport
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:828` — [const] 1900 :: firstDate: DateTime(1900),
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:998` — [const] 15000 :: const _kMaxNet = 15000;
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:1009` — [const] 7000 :: int _value = 7000;
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:1147` — [const] 30000 :: (n != null && n >= 500 && n < 30000) ? n : null);
- **Texte** (29 strings hardcodées, 64 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:542` — « Mint 2 axis handoff persistence failed »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:816` — « Choisir ma date »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:836` — « Choisis ta vraie date de naissance. »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:850` — « Quelle est ta date de naissance ? »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:903` — « Appenzell RI »
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:1562` — « Je peux chiffrer un rachat LPP aussi, quand tu veux. »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/document_scan/document_scan_screen.dart — score 31
- **Calculs** (5 sites) :
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:74` — [const] 1024 :: static const _maxFileSizeBytes = 4 * 1024 * 1024;
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:74` — [const] 1024 :: static const _maxFileSizeBytes = 4 * 1024 * 1024;
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:77` — [const] 1024 :: static const _visionCompressThresholdBytes = 2 * 1024 * 1024
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:77` — [const] 1024 :: static const _visionCompressThresholdBytes = 2 * 1024 * 1024
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:1330` — [const] 1920 :: const maxDimension = 1920;
- **Texte** (21 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:508` — « [DocumentScan] Scanner error: ${e.code} »
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:512` — « [DocumentScan] Unexpected scanner error: $e »
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:594` — « [DocumentScan] Import error: $e »
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:765` — « Claude Vision API »
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:775` — « [DocumentScan] Vision error: code=${e.code} msg=${e.message} »
- **Métier/lois** (2 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:1482` — « Extraction backend Docling (LPP) »
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:1563` — « Extraction backend Docling (LPP) »
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (warn, 14 sites print/log) :
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:508` — debugPrint('[DocumentScan] Scanner error: ${e.code}');
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:512` — debugPrint('[DocumentScan] Unexpected scanner error: $e');
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:594` — debugPrint('[DocumentScan] Import error: $e');
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:774` — debugPrint(
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:793` — debugPrint('[DocumentScan] Vision extraction timed out');
  - `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:799` — debugPrint('[DocumentScan] Vision extraction failed: $e');

### screens/independant_screen.dart — score 31
- **Calculs** (10 sites) :
  - `apps/mobile/lib/screens/independant_screen.dart:42` — [const] 80000 :: double _revenuNet = 80000;
  - `apps/mobile/lib/screens/independant_screen.dart:170` — [const] 8500 :: fiveYearGain: 8500,
  - `apps/mobile/lib/screens/independant_screen.dart:179` — [const] 1200 :: fiveYearGain: 1200,
  - `apps/mobile/lib/screens/independant_screen.dart:187` — [const] 12000 :: fiveYearGain: 12000,
  - `apps/mobile/lib/screens/independant_screen.dart:463` — [const] 20000 :: min: 20000,
  - `apps/mobile/lib/screens/independant_screen.dart:464` — [const] 200000 :: max: 200000,
  - `apps/mobile/lib/screens/independant_screen.dart:1035` — [const] 20000 :: annualDeduction: 20000,
  - `apps/mobile/lib/screens/independant_screen.dart:1036` — [const] 20000 :: taxSaving: 20000 * 0.25,
  - `apps/mobile/lib/screens/independant_screen.dart:1051` — [const] 3600 :: annualDeduction: 3600,
  - `apps/mobile/lib/screens/independant_screen.dart:1052` — [const] 3600 :: taxSaving: 3600 * 0.25,
- **Texte** (13 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/independant_screen.dart:166` — « Fondation de libre passage »
  - `apps/mobile/lib/screens/independant_screen.dart:169` — « Place ton avoir en libre passage avec un rendement correct. »
  - `apps/mobile/lib/screens/independant_screen.dart:172` — « LFLP art. 4 »
  - `apps/mobile/lib/screens/independant_screen.dart:175` — « Institution suppl\u00e9tive »
  - `apps/mobile/lib/screens/independant_screen.dart:178` — « Transfert automatique apr\u00e8s 6 mois \u2014 rendement minimal. »
- **Métier/lois** (13 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/independant_screen.dart:172` — « LFLP art. 4 »
  - `apps/mobile/lib/screens/independant_screen.dart:180` — « OPP2 art. 10 »
  - `apps/mobile/lib/screens/independant_screen.dart:183` — « Nouvelle caisse LPP »
  - `apps/mobile/lib/screens/independant_screen.dart:186` — « Tu t\'affilies volontairement \u00e0 une caisse LPP. »
  - `apps/mobile/lib/screens/independant_screen.dart:188` — « LPP art. 44 »
  - `apps/mobile/lib/screens/independant_screen.dart:302` — « AVS »
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/independant_screen.dart:377` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/independant_screen.dart:604` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/independant_screen.dart:901` — spread .map( dans un children (liste non virtualisée)
- **Design system** (2 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/independant_screen.dart:338` — [text_style] fontSize: 20
  - `apps/mobile/lib/screens/independant_screen.dart:410` — [text_style] fontSize: 16
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/independant_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/disability/disability_insurance_screen.dart — score 27
- **Calculs** (16 sites) :
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:60` — 80% salaire — 720 jours (assurance collective)
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:63` — ⚠️ Aucune couverture — hors période employeur, c\'est 0 CHF
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:71` — Rente ≈ 40% salaire coordonné (LPP art. 23)
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:72` — Sous le seuil LPP ${_fmtChf(lppSeuilEntree)} CHF/an — pas de
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:100` — Max ${_fmtChf(aiRenteEntiere)} CHF/mois — délai décision ~14
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:30` — [const] 8333 :: double _grossMonthly = 8333;
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:31` — [const] 30000 :: double _savings = 30000;
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:45` — [const] 2000.0 :: if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:45` — [const] 25000.0 :: if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:47` — [const] 500000.0 :: if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
- **Texte** (14 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:60` — « 80% salaire — 720 jours (assurance collective) »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:62` — « Assurance privée personnelle (vérifie les conditions) »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:63` — « ⚠️ Aucune couverture — hors période employeur, c\'est 0 CHF »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:71` — « Rente ≈ 40% salaire coordonné (LPP art. 23) »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:72` — « Sous le seuil LPP ${_fmtChf(lppSeuilEntree)} CHF/an — pas de couvertur »
- **Métier/lois** (6 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:71` — « Rente ≈ 40% salaire coordonné (LPP art. 23) »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:72` — « Sous le seuil LPP ${_fmtChf(lppSeuilEntree)} CHF/an — pas de couvertur »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:94` — « LAMal art. 67-77 »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:101` — « LAI art. 28 »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:105` — « LPP invalidité »
  - `apps/mobile/lib/screens/disability/disability_insurance_screen.dart:108` — « LPP art. 23-26 »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/disability/disability_insurance_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/first_job_screen.dart — score 24
- **Calculs** (14 sites) :
  - `apps/mobile/lib/screens/first_job_screen.dart:50` — [const] 5000 :: double _salaire = 5000;
  - `apps/mobile/lib/screens/first_job_screen.dart:233` — [const] 2000.0 :: final inRange = raw >= 2000.0 && raw <= 15000.0;
  - `apps/mobile/lib/screens/first_job_screen.dart:233` — [const] 15000.0 :: final inRange = raw >= 2000.0 && raw <= 15000.0;
  - `apps/mobile/lib/screens/first_job_screen.dart:655` — [const] 2000 :: min: 2000,
  - `apps/mobile/lib/screens/first_job_screen.dart:656` — [const] 15000 :: max: 15000,
  - `apps/mobile/lib/screens/first_job_screen.dart:1387` — [const] 6500.0 :: const median = 6500.0;
  - `apps/mobile/lib/screens/first_job_screen.dart:1390` — [const] 5000.0 :: 5000.0
  - `apps/mobile/lib/screens/first_job_screen.dart:1391` — [const] 5000.0 :: : 5000.0;
  - `apps/mobile/lib/screens/first_job_screen.dart:1392` — [const] 2000.0 :: final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);
  - `apps/mobile/lib/screens/first_job_screen.dart:1392` — [const] 15000.0 :: final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);
- **Calculs** : 4 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Texte** (6 strings hardcodées, 19 refs l10n) :
  - `apps/mobile/lib/screens/first_job_screen.dart:495` — « LAVS art. 5 »
  - `apps/mobile/lib/screens/first_job_screen.dart:506` — « LPP art. 16 »
  - `apps/mobile/lib/screens/first_job_screen.dart:518` — « LIFD art. 83 »
  - `apps/mobile/lib/screens/first_job_screen.dart:540` — « LPP art. 3 — libre passage »
  - `apps/mobile/lib/screens/first_job_screen.dart:549` — « OLP art. 3 — d\u00e9lai de transfert »
- **Métier/lois** (8 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/first_job_screen.dart:495` — « LAVS art. 5 »
  - `apps/mobile/lib/screens/first_job_screen.dart:506` — « LPP art. 16 »
  - `apps/mobile/lib/screens/first_job_screen.dart:518` — « LIFD art. 83 »
  - `apps/mobile/lib/screens/first_job_screen.dart:540` — « LPP art. 3 — libre passage »
  - `apps/mobile/lib/screens/first_job_screen.dart:549` — « OLP art. 3 — d\u00e9lai de transfert »
  - `apps/mobile/lib/screens/first_job_screen.dart:557` — « LAMal art. 3 »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/first_job_screen.dart:969` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/first_job_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/anonymous/anonymous_chat_screen.dart — score 21
- **Route** : île/orphelin — `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` classes ['AnonymousChatScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Calculs** (11 sites) :
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:467` — [const] 1800 :: avsMonthlyRente: 1800,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:468` — [const] 18000 :: lppAnnualRente: 18000,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:469` — [const] 1500 :: lppMonthlyRente: 1500,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:470` — [const] 3300 :: totalMonthlyRetirement: 3300,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:472` — [const] 3300 :: replacementRate: 3300 / (salary > 0 ? salary : 1),
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:473` — [const] 3300 :: retirementGapMonthly: salary > 3300 ? salary - 3300 : 0,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:473` — [const] 3300 :: retirementGapMonthly: salary > 3300 ? salary - 3300 : 0,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:474` — [const] 1800 :: taxSaving3a: 1800,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:476` — [const] 8000 :: currentSavings: 8000,
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:486` — [const] 35000 :: existingLpp: 35000,
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:538` — « [AnonymousChat] Eager persist failed: $e »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:925` — shrinkWrap:true (liste imbriquée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (warn, 1 sites print/log) :
  - `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:538` — debugPrint('[AnonymousChat] Eager persist failed: $e');

### screens/slm_settings_screen.dart — score 19
- **Calculs** (14 sites) :
  - `apps/mobile/lib/screens/slm_settings_screen.dart:595` — [const] 1024 :: final totalGo = SlmDownloadService.instance.expectedSizeByte
  - `apps/mobile/lib/screens/slm_settings_screen.dart:595` — [const] 1024 :: final totalGo = SlmDownloadService.instance.expectedSizeByte
  - `apps/mobile/lib/screens/slm_settings_screen.dart:595` — [const] 1024 :: final totalGo = SlmDownloadService.instance.expectedSizeByte
  - `apps/mobile/lib/screens/slm_settings_screen.dart:596` — [const] 1024 :: if (downloaded < 1024 * 1024) {
  - `apps/mobile/lib/screens/slm_settings_screen.dart:596` — [const] 1024 :: if (downloaded < 1024 * 1024) {
  - `apps/mobile/lib/screens/slm_settings_screen.dart:597` — [const] 1024 :: return '${(downloaded / 1024).toStringAsFixed(0)} Ko / '
  - `apps/mobile/lib/screens/slm_settings_screen.dart:600` — [const] 1024 :: if (downloaded < 1024 * 1024 * 1024) {
  - `apps/mobile/lib/screens/slm_settings_screen.dart:600` — [const] 1024 :: if (downloaded < 1024 * 1024 * 1024) {
  - `apps/mobile/lib/screens/slm_settings_screen.dart:600` — [const] 1024 :: if (downloaded < 1024 * 1024 * 1024) {
  - `apps/mobile/lib/screens/slm_settings_screen.dart:601` — [const] 1024 :: return '${(downloaded / (1024 * 1024)).toStringAsFixed(0)} M
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/slm_settings_screen.dart:60` — ListView(children:) non virtualisée
- **Design system** (5 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/slm_settings_screen.dart:524` — [cta] TextButton(
  - `apps/mobile/lib/screens/slm_settings_screen.dart:528` — [cta] FilledButton(
  - `apps/mobile/lib/screens/slm_settings_screen.dart:574` — [cta] TextButton(
  - `apps/mobile/lib/screens/slm_settings_screen.dart:578` — [cta] TextButton(
  - `apps/mobile/lib/screens/slm_settings_screen.dart:356` — [text_style] fontSize: 15
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/slm_settings_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/unemployment_screen.dart — score 19
- **Calculs** (5 sites) :
  - `apps/mobile/lib/screens/unemployment_screen.dart:38` — [const] 6000 :: double _gainAssure = 6000;
  - `apps/mobile/lib/screens/unemployment_screen.dart:59` — [const] 1500.0 :: ? (p.revenuBrutAnnuel / 12).clamp(1500.0, 12646.0)
  - `apps/mobile/lib/screens/unemployment_screen.dart:59` — [const] 12646.0 :: ? (p.revenuBrutAnnuel / 12).clamp(1500.0, 12646.0)
  - `apps/mobile/lib/screens/unemployment_screen.dart:60` — [const] 6000.0 :: : 6000.0;
  - `apps/mobile/lib/screens/unemployment_screen.dart:210` — [const] 12350 :: max: 12350,
- **Calculs** : 9 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/unemployment_screen.dart:895` — spread .map( dans un children (liste non virtualisée)
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/unemployment_screen.dart:654` — [text_style] fontSize: 12
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/unemployment_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/consumer_credit_screen.dart — score 18
- **Calculs** (4 sites) :
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:105` — [const] 2000 :: balance: 2000,
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:112` — [const] 8000 :: balance: 8000,
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:119` — [const] 1200 :: balance: 1200,
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:176` — [const] 50000 :: max: 50000,
- **Calculs** : 7 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:103` — « Carte de crédit »
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:110` — « Crédit conso »
  - `apps/mobile/lib/screens/consumer_credit_screen.dart:117` — « BNPL (paiement différé) »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/consumer_credit_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/donation_screen.dart — score 18
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/donation_screen.dart:68` — [const] 500000 :: double _valeurImmobiliere = 500000;
  - `apps/mobile/lib/screens/donation_screen.dart:71` — [const] 800000 :: double _fortuneTotaleDonateur = 800000;
- **Texte** (10 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/donation_screen.dart:105` — « Espèces / Liquidités »
  - `apps/mobile/lib/screens/donation_screen.dart:107` — « Titres / Valeurs mobilières »
  - `apps/mobile/lib/screens/donation_screen.dart:120` — « Participation aux acquêts »
  - `apps/mobile/lib/screens/donation_screen.dart:121` — « Communauté de biens »
  - `apps/mobile/lib/screens/donation_screen.dart:122` — « Séparation de biens »
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/donation_screen.dart:1410` — « personnalisé au sens de la LSFin. Consulte un·e spécialiste  »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/donation_screen.dart:1223` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/donation_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/independants/lpp_volontaire_screen.dart — score 18
- **Calculs** (7 sites) :
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:520` — 7%
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:521` — 10%
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:522` — 15%
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:523` — 18%
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:36` — [const] 80000 :: double _revenuNet = 80000;
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:85` — [const] 250000.0 :: _revenuNet = net.clamp(0.0, 250000.0);
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:227` — [const] 250000 :: max: 250000,
- **Calculs** : 7 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart:547` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/lpp_deep/rachat_echelonne_screen.dart — score 18
- **Calculs** (23 sites) :
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:471` — CHF\u00a00
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:1142` — 100-150k
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:41` — [const] 200000 :: double _avoirActuel = 200000;
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:42` — [const] 80000 :: double _rachatMax = 80000;
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:43` — [const] 120000 :: double _revenu = 120000;
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:409` — [const] 4000 :: monthlyIncomeAt65: 4000,
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:411` — [const] 3400 :: RetirementAgeScenario(age: 60, monthlyIncome: 3400, deltaPer
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:411` — [const] 18000 :: RetirementAgeScenario(age: 60, monthlyIncome: 3400, deltaPer
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:412` — [const] 3600 :: RetirementAgeScenario(age: 62, monthlyIncome: 3600, deltaPer
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:412` — [const] 12000 :: RetirementAgeScenario(age: 62, monthlyIncome: 3600, deltaPer
- **Texte** (8 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:70` — « Bâle-Ville »
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:71` — « Bâle-Campagne »
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:71` — « Appenzell RE »
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:72` — « Appenzell RI »
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:74` — « Neuchâtel »
- **Métier/lois** (3 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:138` — « /rachat-lpp »
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:148` — « /rachat-lpp »
  - `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:307` — « /rachat-lpp »
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/coach/chat_as_verb_demo_screen.dart — score 17
- **Route** : île/orphelin — `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` classes ['ChatAsVerbDemoScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:50` — Marge fiscale 2026
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:50` — [const] 2026 :: title: 'Marge fiscale 2026',
- **Texte** (4 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:50` — « Marge fiscale 2026 »
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:51` — « Ce qu\'il te reste à déduire cette année. »
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:58` — « Coût hypothèque mensuel »
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:59` — « Charge actuelle et bande de sensibilité au taux. »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:40` — ListView(children:) non virtualisée
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart`).

### screens/concubinage_screen.dart — score 17
- **Calculs** (8 sites) :
  - `apps/mobile/lib/screens/concubinage_screen.dart:1035` — CHF 0
  - `apps/mobile/lib/screens/concubinage_screen.dart:127` — [const] 20000 :: if (provided.contains('salary') && gross >= 20000 && gross <
  - `apps/mobile/lib/screens/concubinage_screen.dart:127` — [const] 300000 :: if (provided.contains('salary') && gross >= 20000 && gross <
  - `apps/mobile/lib/screens/concubinage_screen.dart:137` — [const] 20000 :: if (partnerAnnual >= 20000 && partnerAnnual <= 300000) {
  - `apps/mobile/lib/screens/concubinage_screen.dart:137` — [const] 300000 :: if (partnerAnnual >= 20000 && partnerAnnual <= 300000) {
  - `apps/mobile/lib/screens/concubinage_screen.dart:527` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/concubinage_screen.dart:539` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/concubinage_screen.dart:924` — [const] 8000 :: max: 8000,
- **Perf** (4 signaux) :
  - `apps/mobile/lib/screens/concubinage_screen.dart:376` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/concubinage_screen.dart:880` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/concubinage_screen.dart:1188` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/concubinage_screen.dart:1264` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/concubinage_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/housing_sale_screen.dart — score 17
- **Calculs** (15 sites) :
  - `apps/mobile/lib/screens/housing_sale_screen.dart:54` — [const] 800000 :: double _prixAchat = 800000;
  - `apps/mobile/lib/screens/housing_sale_screen.dart:56` — [const] 2015 :: int _anneeAchat = 2015;
  - `apps/mobile/lib/screens/housing_sale_screen.dart:57` — [const] 50000 :: double _investissementsValorisants = 50000;
  - `apps/mobile/lib/screens/housing_sale_screen.dart:58` — [const] 30000 :: double _fraisAcquisition = 30000;
  - `apps/mobile/lib/screens/housing_sale_screen.dart:59` — [const] 600000 :: double _hypothequeRestante = 600000;
  - `apps/mobile/lib/screens/housing_sale_screen.dart:63` — [const] 900000 :: double _prixRemploi = 900000;
  - `apps/mobile/lib/screens/housing_sale_screen.dart:88` — [const] 2025 :: anneeVente: 2025,
  - `apps/mobile/lib/screens/housing_sale_screen.dart:201` — [const] 2025 :: saleDate: DateTime(2025, 1, 1),
  - `apps/mobile/lib/screens/housing_sale_screen.dart:313` — [const] 1980 :: minValue: 1980,
  - `apps/mobile/lib/screens/housing_sale_screen.dart:314` — [const] 2025 :: maxValue: 2025,
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/housing_sale_screen.dart:904` — « Cet outil éducatif fournit des estimations indicatives et  »
  - `apps/mobile/lib/screens/housing_sale_screen.dart:905` — « ne constitue pas un conseil fiscal, juridique ou immobilier  »
  - `apps/mobile/lib/screens/housing_sale_screen.dart:906` — « personnalisé au sens de la LSFin. Consulte un·e spécialiste  »
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/housing_sale_screen.dart:906` — « personnalisé au sens de la LSFin. Consulte un·e spécialiste  »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/housing_sale_screen.dart:720` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/housing_sale_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/independants/avs_cotisations_screen.dart — score 17
- **Calculs** (5 sites) :
  - `apps/mobile/lib/screens/independants/avs_cotisations_screen.dart:323` — 5.37\u00a0%
  - `apps/mobile/lib/screens/independants/avs_cotisations_screen.dart:326` — 10.0\u00a0%
  - `apps/mobile/lib/screens/independants/avs_cotisations_screen.dart:21` — [const] 80000 :: double _revenuNet = 80000;
  - `apps/mobile/lib/screens/independants/avs_cotisations_screen.dart:124` — [const] 250000 :: max: 250000,
  - `apps/mobile/lib/screens/independants/avs_cotisations_screen.dart:282` — [const] 60500 :: final position = (_revenuNet / 60500).clamp(0.0, 1.0);
- **Calculs** : 5 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/independants/avs_cotisations_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/naissance_screen.dart — score 17
- **Calculs** (14 sites) :
  - `apps/mobile/lib/screens/naissance_screen.dart:59` — [const] 6000 :: double _salaireMensuel = 6000;
  - `apps/mobile/lib/screens/naissance_screen.dart:69` — [const] 80000 :: double _revenuImpact = 80000;
  - `apps/mobile/lib/screens/naissance_screen.dart:71` — [const] 1500 :: double _fraisGarde = 1500;
  - `apps/mobile/lib/screens/naissance_screen.dart:218` — [const] 2000.0 :: v >= 2000.0 &&
  - `apps/mobile/lib/screens/naissance_screen.dart:219` — [const] 15000.0 :: v <= 15000.0;
  - `apps/mobile/lib/screens/naissance_screen.dart:287` — [const] 30000.0 :: annual >= 30000.0 &&
  - `apps/mobile/lib/screens/naissance_screen.dart:288` — [const] 200000.0 :: annual <= 200000.0;
  - `apps/mobile/lib/screens/naissance_screen.dart:770` — [const] 2000 :: min: 2000,
  - `apps/mobile/lib/screens/naissance_screen.dart:771` — [const] 15000 :: max: 15000,
  - `apps/mobile/lib/screens/naissance_screen.dart:1245` — [const] 30000 :: min: 30000,
- **Perf** (6 signaux) :
  - `apps/mobile/lib/screens/naissance_screen.dart:664` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/naissance_screen.dart:945` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/naissance_screen.dart:1207` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/naissance_screen.dart:1583` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/naissance_screen.dart:1090` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/naissance_screen.dart:1650` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/naissance_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/frontalier_screen.dart — score 16
- **Calculs** (7 sites) :
  - `apps/mobile/lib/screens/frontalier_screen.dart:751` — 120
  - `apps/mobile/lib/screens/frontalier_screen.dart:40` — [const] 7000 :: double _taxSalary = 7000;
  - `apps/mobile/lib/screens/frontalier_screen.dart:51` — [const] 7000 :: double _chargesSalary = 7000;
  - `apps/mobile/lib/screens/frontalier_screen.dart:271` — [const] 3000 :: min: 3000,
  - `apps/mobile/lib/screens/frontalier_screen.dart:272` — [const] 25000 :: max: 25000,
  - `apps/mobile/lib/screens/frontalier_screen.dart:1019` — [const] 3000 :: min: 3000,
  - `apps/mobile/lib/screens/frontalier_screen.dart:1020` — [const] 25000 :: max: 25000,
- **Métier/lois** (3 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/frontalier_screen.dart:1111` — « AVS/AI/APG »
  - `apps/mobile/lib/screens/frontalier_screen.dart:1113` — « LPP (est.) »
  - `apps/mobile/lib/screens/frontalier_screen.dart:1113` — « lpp »
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/frontalier_screen.dart:167` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/frontalier_screen.dart:594` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/frontalier_screen.dart:960` — ListView(children:) non virtualisée
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/frontalier_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/lpp_deep/libre_passage_screen.dart — score 16
- **Calculs** (3 sites) :
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:164` — Sécurité maximale, taux fixe 1-2%. Idéal si tu reprends un e
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:35` — [const] 150000 :: double _avoir = 150000;
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:299` — [const] 500000 :: max: 500000,
- **Texte** (7 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:161` — « Compte libre passage »
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:164` — « Sécurité maximale, taux fixe 1-2%. Idéal si tu reprends un emploi rapi »
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:166` — « LFLP art. 3 — délai 6 mois »
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:172` — « Protection décès et invalidité incluse. Rendement moyen lié aux taux t »
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:177` — « Fonds de placement »
- **Métier/lois** (3 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:166` — « LFLP art. 3 — délai 6 mois »
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:174` — « OPP2 art. 10 »
  - `apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart:183` — « LFLP art. 4 »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/mortgage/epl_combined_screen.dart — score 16
- **Calculs** (11 sites) :
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:30` — [const] 60000 :: double _avoir3a = 60000;
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:31` — [const] 200000 :: double _avoirLpp = 200000;
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:32` — [const] 900000 :: double _prixCible = 900000;
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:57` — [const] 500000 :: _epargneCash = profile.patrimoine.epargneLiquide.clamp(0, 50
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:61` — [const] 300000 :: _avoir3a = profile.prevoyance.totalEpargne3a.clamp(0, 300000
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:66` — [const] 500000 :: _avoirLpp = lpp.clamp(0, 500000);
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:71` — [const] 200000 :: _prixCible = propertyValue.clamp(200000, 3000000);
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:332` — [const] 200000 :: min: 200000,
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:345` — [const] 500000 :: max: 500000,
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:357` — [const] 300000 :: max: 300000,
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:100` — ListView(children:) non virtualisée
- **Design system** (2 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:250` — [radius] BorderRadius.circular(3)
  - `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:766` — [text_style] fontSize: 13
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/mortgage/epl_combined_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart — score 16
- **Calculs** (8 sites) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:124` — CHF 10\u2019000
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:126` — CHF 10\u2019000
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:154` — Hypothèses\u00a0: règle des 33\u202f%, stress test 5\u202f%,
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:155` — minimum 20\u202f%. Source\u00a0: FINMA Circ. 2017/3, ORFP.
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:40` — [const] 80000 :: double _apport = 80000;
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:130` — [const] 20000 :: canDecrement: _apport > 20000,
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:131` — [const] 500000 :: canIncrement: _apport < 500000,
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:155` — [const] 2017 :: 'minimum 20\u202f%. Source\u00a0: FINMA Circ. 2017/3, ORFP.'
- **Texte** (6 strings hardcodées, 3 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:74` — « SCENE · CE QUE TU PEUX VISER »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:84` — « C\u2019est ta marge réelle, avant l\u2019émotion de la visite. »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:143` — « Charge mensuelle max\u00a0: environ CHF ${_fmt(chargeMensuelleMax)}  »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:144` — « (intérêts + amortissement + charges). »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:154` — « Hypothèses\u00a0: règle des 33\u202f%, stress test 5\u202f%, apport  »

### screens/coach/coach_chat_screen.dart — score 15
- **Texte** (14 strings hardcodées, 9 refs l10n) :
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:528` — « [coach_chat] sequence dispatch fallback: $e »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:548` — « L'utilisateur vient de terminer une simulation  »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:571` — « \u00c9tape suivante : ${action.progressLabel}. »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:596` — « Tu as termin\u00e9 cette s\u00e9quence guid\u00e9e. »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:799` — « [CoachChat] precomputed insight surfacing failed: $e »
- **Métier/lois** (6 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:1641` — « Plafond 3a avec LPP »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:1642` — « OPP3 art. 7 »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:2128` — « /rachat-lpp »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:2129` — « /rachat-lpp »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:2153` — « lpp »
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:2154` — « /rachat-lpp »
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (warn, 19 sites print/log) :
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:299` — debugPrint(
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:316` — debugPrint(
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:339` — debugPrint(
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:528` — debugPrint('[coach_chat] sequence dispatch fallback: $e');
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:799` — debugPrint('[CoachChat] precomputed insight surfacing failed
  - `apps/mobile/lib/screens/coach/coach_chat_screen.dart:843` — debugPrint(

### screens/job_comparison_screen.dart — score 15
- **Calculs** (12 sites) :
  - `apps/mobile/lib/screens/job_comparison_screen.dart:62` — [const] 85000 :: double _currentSalaireBrut = 85000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:65` — [const] 120000 :: double _currentAvoirVieillesse = 120000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:67` — [const] 200000 :: double _currentCapitalDeces = 200000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:68` — [const] 80000 :: double _currentRachatMax = 80000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:72` — [const] 95000 :: double _newSalaireBrut = 95000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:75` — [const] 120000 :: double _newAvoirVieillesse = 120000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:77` — [const] 150000 :: double _newCapitalDeces = 150000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:78` — [const] 40000 :: double _newRachatMax = 40000;
  - `apps/mobile/lib/screens/job_comparison_screen.dart:533` — [const] 40000 :: min: 40000,
  - `apps/mobile/lib/screens/job_comparison_screen.dart:534` — [const] 250000 :: max: 250000,
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/job_comparison_screen.dart:633` — « ${opt.toInt()}% part employeur »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/job_comparison_screen.dart:1001` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/job_comparison_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/admin/routes_registry_screen.dart — score 14
- **Route** : île/orphelin — `apps/mobile/lib/screens/admin/routes_registry_screen.dart` classes ['RoutesRegistryScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Texte** (4 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/admin/routes_registry_screen.dart:82` — « Registry not generated. Run tools/mint-routes reconcile. »
  - `apps/mobile/lib/screens/admin/routes_registry_screen.dart:98` — « Routes owned by ${owner.name}, ${routes.length} entries »
  - `apps/mobile/lib/screens/admin/routes_registry_screen.dart:137` — « Live health status: use `./tools/mint-routes health` terminal.\n »
  - `apps/mobile/lib/screens/admin/routes_registry_screen.dart:138` — « This screen shows static schema + local FeatureFlags state only. »
- **Design system** (2 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/admin/routes_registry_screen.dart:119` — [text_style] fontSize: 11
  - `apps/mobile/lib/screens/admin/routes_registry_screen.dart:140` — [text_style] fontSize: 11
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/admin/routes_registry_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/deces_proche_screen.dart — score 14
- **Calculs** (4 sites) :
  - `apps/mobile/lib/screens/deces_proche_screen.dart:50` — [const] 500000 :: double _fortuneDefunt = 500000;
  - `apps/mobile/lib/screens/deces_proche_screen.dart:51` — [const] 200000 :: double _lppDefunt = 200000;
  - `apps/mobile/lib/screens/deces_proche_screen.dart:52` — [const] 50000 :: double _pilier3aDefunt = 50000;
  - `apps/mobile/lib/screens/deces_proche_screen.dart:416` — [const] 500000 :: max: 500000,
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/deces_proche_screen.dart:301` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/deces_proche_screen.dart:481` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/deces_proche_screen.dart:623` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/deces_proche_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/disability/disability_gap_screen.dart — score 14
- **Calculs** (8 sites) :
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:36` — [const] 8333 :: double _grossMonthly = 8333;
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:38` — [const] 30000 :: double _savings = 30000;
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:52` — [const] 2000.0 :: if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:52` — [const] 25000.0 :: if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:61` — [const] 500000.0 :: if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:389` — [const] 2000 :: min: 2000,
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:390` — [const] 25000 :: max: 25000,
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:410` — [const] 200000 :: max: 200000,
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:204` — « LAMal art. 67-77 »
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:211` — « LAI art. 28 »
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:218` — « LPP art. 23-26 »
- **Métier/lois** (3 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:204` — « LAMal art. 67-77 »
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:211` — « LAI art. 28 »
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:218` — « LPP art. 23-26 »
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/disability/disability_gap_screen.dart:466` — [cta] OutlinedButton(
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/divorce_simulator_screen.dart — score 14
- **Calculs** (12 sites) :
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:157` — [const] 20000 :: if (provided.contains('salary') && gross >= 20000 && gross <
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:157` — [const] 300000 :: if (provided.contains('salary') && gross >= 20000 && gross <
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:165` — [const] 500000 :: lpp <= 500000 &&
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:171` — [const] 200000 :: if (p3a > 0 && p3a <= 200000) {
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:668` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:680` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:758` — [const] 500000 :: max: 500000,
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:770` — [const] 500000 :: max: 500000,
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:782` — [const] 500000 :: max: 500000,
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:794` — [const] 500000 :: max: 500000,
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/divorce_simulator_screen.dart:1274` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/divorce_simulator_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/fiscal_comparator_screen.dart — score 14
- **Calculs** (7 sites) :
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:289` — [const] 5000 :: nextCapSuggestion: maxSavings > 5000 ? 'demenagement' : null
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:397` — [const] 30000 :: min: 30000,
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:398` — [const] 500000 :: max: 500000,
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:403` — [const] 5000 :: _revenuBrut = (v / 5000).round() * 5000.0;
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:403` — [const] 5000.0 :: _revenuBrut = (v / 5000).round() * 5000.0;
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:1114` — [const] 3000 :: movingFees: 3000,
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:1136` — [const] 3000 :: monthlyAfter: 3000 / 24,
- **Perf** (4 signaux) :
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:364` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:916` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:1002` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/fiscal_comparator_screen.dart:1510` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/mariage_screen.dart — score 14
- **Calculs** (10 sites) :
  - `apps/mobile/lib/screens/mariage_screen.dart:60` — [const] 80000 :: double _revenu1 = 80000;
  - `apps/mobile/lib/screens/mariage_screen.dart:61` — [const] 60000 :: double _revenu2 = 60000;
  - `apps/mobile/lib/screens/mariage_screen.dart:68` — [const] 200000 :: double _patrimoine1 = 200000;
  - `apps/mobile/lib/screens/mariage_screen.dart:72` — [const] 2500 :: double _renteLpp = 2500;
  - `apps/mobile/lib/screens/mariage_screen.dart:220` — [const] 300000.0 :: annual <= 300000.0;
  - `apps/mobile/lib/screens/mariage_screen.dart:239` — [const] 300000.0 :: final valid = hasConjoint && annual > 0 && annual <= 300000.
  - `apps/mobile/lib/screens/mariage_screen.dart:292` — [const] 8000.0 :: final valid = rente > 0 && rente <= 8000.0;
  - `apps/mobile/lib/screens/mariage_screen.dart:713` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/mariage_screen.dart:730` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/mariage_screen.dart:1205` — [const] 8000 :: max: 8000,
- **Perf** (6 signaux) :
  - `apps/mobile/lib/screens/mariage_screen.dart:589` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/mariage_screen.dart:903` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/mariage_screen.dart:1186` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/mariage_screen.dart:1498` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/mariage_screen.dart:1459` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/mariage_screen.dart:1571` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/mortgage/imputed_rental_screen.dart — score 14
- **Calculs** (8 sites) :
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:28` — [const] 900000 :: double _valeurVenale = 900000;
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:29` — [const] 15000 :: double _interetsAnnuels = 15000;
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:30` — [const] 3000 :: double _fraisEntretien = 3000;
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:59` — [const] 200000 :: _valeurVenale = propertyValue.clamp(200000, 3000000);
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:77` — [const] 80000 :: _interetsAnnuels = (mortgage * rate / 100).clamp(0, 80000);
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:364` — [const] 200000 :: min: 200000,
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:377` — [const] 80000 :: max: 80000,
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:389` — [const] 30000 :: max: 30000,
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart:102` — ListView(children:) non virtualisée
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart — score 14
- **Calculs** (4 sites) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:145` — VERSEMENT 3A · CHF ${formatChf(_versement)}
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:75` — [const] 3000 :: double _versement = 3000;
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:83` — [const] 60000 :: if (grossAnnual < 60000) {
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:85` — [const] 180000 :: } else if (grossAnnual > 180000) {
- **Texte** (6 strings hardcodées, 3 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:112` — « SCENE · TON LEVIER DIRECT »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:118` — « Ce versement peut diminuer ton revenu imposable.  »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:119` — « L’impact réel dépend du canton, du revenu et de ton statut LPP. »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:183` — « Marge maximale salarié\u202fLPP\u00a0:  »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:194` — « Hypothèse\u00a0: taux marginal moyen canton \u00b7 revenu.\u00a0 »
- **Métier/lois** (2 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:119` — « L’impact réel dépend du canton, du revenu et de ton statut LPP. »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:185` — « (OPP3 art. 7 al. 1 lit. a). »

### screens/admin_observability_screen.dart — score 13
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/admin_observability_screen.dart:266` — ] ?? 0).toString()}%
- **Texte** (3 strings hardcodées, 13 refs l10n) :
  - `apps/mobile/lib/screens/admin_observability_screen.dart:233` — « Locked now »
  - `apps/mobile/lib/screens/admin_observability_screen.dart:234` — « Sub active »
  - `apps/mobile/lib/screens/admin_observability_screen.dart:269` — « Avg step »
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/admin_observability_screen.dart:137` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/admin_observability_screen.dart:164` — ListView(children:) non virtualisée
- **Design system** (3 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/admin_observability_screen.dart:185` — [cta] FilledButton(
  - `apps/mobile/lib/screens/admin_observability_screen.dart:255` — [radius] BorderRadius.circular(99)
  - `apps/mobile/lib/screens/admin_observability_screen.dart:324` — [text_style] fontSize: 12
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/admin_observability_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/budget/budget_setup_screen.dart — score 13
- **Calculs** (6 sites) :
  - `apps/mobile/lib/screens/budget/budget_setup_screen.dart:62` — [const] 6000 :: static const _placeholderIncome = '6000';
  - `apps/mobile/lib/screens/budget/budget_setup_screen.dart:63` — [const] 2400 :: static const _placeholderHousing = '2400';
  - `apps/mobile/lib/screens/budget/budget_setup_screen.dart:70` — [const] 100000.0 :: static const _maxMonthlyIncome = 100000.0;
  - `apps/mobile/lib/screens/budget/budget_setup_screen.dart:71` — [const] 20000.0 :: static const _maxMonthlyHousing = 20000.0;
  - `apps/mobile/lib/screens/budget/budget_setup_screen.dart:72` — [const] 3000.0 :: static const _maxMonthlyLamal = 3000.0;
  - `apps/mobile/lib/screens/budget/budget_setup_screen.dart:73` — [const] 10000.0 :: static const _maxMonthlyOtherCharge = 10000.0;
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/budget/budget_setup_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/coach/succession_patrimoine_screen.dart — score 13
- **Calculs** (3 sites) :
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:64` — [const] 500000 :: patrimoine: 500000,
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:71` — [const] 500000 :: totalPatrimoine: 500000,
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:72` — [const] 50000 :: donationAmount: 50000,
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:136` — « J+1 à J+7 »
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:148` — « J+8 à J+30 »
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:161` — « J+31 à J+365 »
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart:301` — [radius] BorderRadius.circular(9)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/debt_prevention/debt_ratio_screen.dart — score 13
- **Calculs** (9 sites) :
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:280` — < 15%
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:282` — 15-30%
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:284` — > 30%
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:327` — [const] 2000 :: min: 2000,
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:328` — [const] 20000 :: max: 20000,
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:416` — [const] 5000 :: max: 5000,
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:429` — [const] 3000 :: max: 3000,
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:1052` — [const] 0800 :: telephone: '0800 40 40 40',
  - `apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart:1061` — [const] 0800 :: telephone: '0800 708 708',
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/document_scan/document_impact_screen.dart — score 13
- **Texte** (8 strings hardcodées, 6 refs l10n) :
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:146` — « [document_impact] saveEvent failed: $e »
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:150` — « [document_impact] _persistScanEvent threw: $e\n$st »
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:217` — « montant non précisé »
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:218` — « montant non précisé »
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:226` — « ~$withSep CHF »
- **Métier/lois** (2 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:712` — « certificat LPP »
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:713` — « extrait AVS »
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:585` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:620` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:658` — spread .map( dans un children (liste non virtualisée)
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:506` — [text_style] fontSize: 12
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (warn, 2 sites print/log) :
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:146` — debugPrint('[document_impact] saveEvent failed: $e');
  - `apps/mobile/lib/screens/document_scan/document_impact_screen.dart:150` — debugPrint('[document_impact] _persistScanEvent threw: $e\n$

### screens/lpp_deep/epl_screen.dart — score 13
- **Calculs** (6 sites) :
  - `apps/mobile/lib/screens/lpp_deep/epl_screen.dart:44` — [const] 300000 :: double _avoirTotal = 300000;
  - `apps/mobile/lib/screens/lpp_deep/epl_screen.dart:144` — [const] 20000 :: _montantSouhaite = fonds.toDouble().clamp(20000, 500000);
  - `apps/mobile/lib/screens/lpp_deep/epl_screen.dart:144` — [const] 500000 :: _montantSouhaite = fonds.toDouble().clamp(20000, 500000);
  - `apps/mobile/lib/screens/lpp_deep/epl_screen.dart:383` — [const] 800000 :: max: 800000,
  - `apps/mobile/lib/screens/lpp_deep/epl_screen.dart:406` — [const] 20000 :: min: 20000,
  - `apps/mobile/lib/screens/lpp_deep/epl_screen.dart:407` — [const] 500000 :: max: 500000,
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/lpp_deep/epl_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/admin/mint_debug_spine_screen.dart — score 12
- **Route** : île/orphelin — `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart` classes ['MintDebugSpineScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Texte** (6 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart:52` — « Reset failed. No raw local data was rendered. »
  - `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart:73` — « Debug spine »
  - `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart:78` — « Redacted local-state inspector. Counts and flags only; no raw  »
  - `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart:79` — « profile values. Reset clears profile stores; secure-purge flags  »
  - `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart:118` — « Reset profile stores »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart:69` — ListView(children:) non virtualisée

### screens/debt_prevention/help_resources_screen.dart — score 12
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart:59` — [const] 0800 :: telephone: '0800 40 40 40',
  - `apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart:70` — [const] 0800 :: telephone: '0800 708 708',
- **Design system** (5 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart:187` — [text_style] fontSize: 13
  - `apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart:211` — [text_style] fontSize: 12
  - `apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart:257` — [text_style] fontSize: 13
  - `apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart:304` — [text_style] fontSize: 14
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/mortgage/saron_vs_fixed_screen.dart — score 12
- **Calculs** (3 sites) :
  - `apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart:31` — [const] 800000 :: double _montantHypothecaire = 800000;
  - `apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart:56` — [const] 200000 :: _montantHypothecaire = mortgage.clamp(200000, 2000000);
  - `apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart:216` — [const] 200000 :: min: 200000,
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart:80` — ListView(children:) non virtualisée
- **Design system** (2 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart:488` — [text_style] fontSize: 10
  - `apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart:502` — [text_style] fontSize: 10
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/coach/retirement_dashboard_screen.dart — score 11
- **Texte** (7 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:172` — « RetirementDashboard: projection error: $e »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:230` — « RetirementDashboard: narrative error: $e »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:243` — « RetirementDashboard: tips error: $e »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:305` — « déclaration »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:626` — « Taux de conversion »
- **Métier/lois** (7 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:476` — « avs »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:479` — « lpp »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:598` — « CHF\u00a0${avs.round()} »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:603` — « CHF\u00a0${lpp.round()} »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:1086` — « lpp »
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:1087` — « avs »
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:924` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:930` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:1019` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (warn, 4 sites print/log) :
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:172` — debugPrint('RetirementDashboard: projection error: $e');
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:230` — debugPrint('RetirementDashboard: narrative error: $e');
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:243` — debugPrint('RetirementDashboard: tips error: $e');
  - `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:762` — debugPrint('RetirementDashboard: retry projection error: $e'

### screens/demenagement_cantonal_screen.dart — score 11
- **Calculs** (6 sites) :
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:72` — [const] 120000 :: double _revenuBrut = 120000;
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:176` — [const] 30000.0 :: annual >= 30000.0 &&
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:177` — [const] 500000.0 :: annual <= 500000.0;
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:700` — [const] 1500.0 :: const loyerMoyen = 1500.0;
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:853` — [const] 30000 :: min: 30000,
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:854` — [const] 500000 :: max: 500000,
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/demenagement_cantonal_screen.dart:912` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/disability/disability_self_employed_screen.dart — score 11
- **Calculs** (5 sites) :
  - `apps/mobile/lib/screens/disability/disability_self_employed_screen.dart:31` — [const] 8000 :: double _monthlyRevenue = 8000;
  - `apps/mobile/lib/screens/disability/disability_self_employed_screen.dart:44` — [const] 2000.0 :: if (salary > 0) _monthlyRevenue = salary.clamp(2000.0, 25000
  - `apps/mobile/lib/screens/disability/disability_self_employed_screen.dart:44` — [const] 25000.0 :: if (salary > 0) _monthlyRevenue = salary.clamp(2000.0, 25000
  - `apps/mobile/lib/screens/disability/disability_self_employed_screen.dart:163` — [const] 2000 :: min: 2000,
  - `apps/mobile/lib/screens/disability/disability_self_employed_screen.dart:164` — [const] 25000 :: max: 25000,
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/disability/disability_self_employed_screen.dart:212` — [text_style] fontSize: 16
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/independants/ijm_screen.dart — score 11
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/independants/ijm_screen.dart:22` — [const] 6000 :: double _revenuMensuel = 6000;
  - `apps/mobile/lib/screens/independants/ijm_screen.dart:42` — [const] 20000 :: _revenuMensuel = profile.salaireBrutMensuel.clamp(0, 20000);
- **Calculs** : 7 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/independants/ijm_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/independants/pillar_3a_indep_screen.dart — score 11
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/independants/pillar_3a_indep_screen.dart:90` — [const] 300000.0 :: _revenuNet = net.clamp(0.0, 300000.0);
  - `apps/mobile/lib/screens/independants/pillar_3a_indep_screen.dart:292` — [const] 300000 :: max: 300000,
- **Calculs** : 7 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/independants/pillar_3a_indep_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/mortgage/affordability_screen.dart — score 11
- **Calculs** (10 sites) :
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:269` — [const] 120000 :: double _revenuBrut = 120000;
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:270` — [const] 800000 :: double _prixAchat = 800000;
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:272` — [const] 50000 :: double _avoir3a = 50000;
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:273` — [const] 200000 :: double _avoirLpp = 200000;
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:539` — [const] 50000 :: min: 50000,
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:540` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:553` — [const] 200000 :: min: 200000,
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:568` — [const] 500000 :: max: 500000,
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:609` — [const] 300000 :: max: 300000,
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:621` — [const] 500000 :: max: 500000,
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/mortgage/affordability_screen.dart:692` — « Depuis ton profil MINT »
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/mortgage/amortization_screen.dart — score 11
- **Calculs** (3 sites) :
  - `apps/mobile/lib/screens/mortgage/amortization_screen.dart:31` — [const] 700000 :: double _montantHypothecaire = 700000;
  - `apps/mobile/lib/screens/mortgage/amortization_screen.dart:58` — [const] 200000 :: _montantHypothecaire = mortgage.clamp(200000, 2000000);
  - `apps/mobile/lib/screens/mortgage/amortization_screen.dart:317` — [const] 200000 :: min: 200000,
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/mortgage/amortization_screen.dart:344` — « $_dureeAns ans »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/mortgage/amortization_screen.dart:95` — ListView(children:) non virtualisée
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/mortgage/amortization_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/simulator_leasing_screen.dart — score 11
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/simulator_leasing_screen.dart:48` — [const] 1500 :: _monthlyPayment = leasingDebt.clamp(100, 1500);
  - `apps/mobile/lib/screens/simulator_leasing_screen.dart:139` — [const] 1500 :: max: 1500,
- **Calculs** : 7 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/simulator_leasing_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/arbitrage/allocation_annuelle_screen.dart — score 10
- **Calculs** (5 sites) :
  - `apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart:756` — CHF\u00A0${value < 0 ? 
  - `apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart:43` — [const] 7000 :: final _montantCtrl = TextEditingController(text: '7000');
  - `apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart:44` — [const] 50000 :: final _potentielRachatCtrl = TextEditingController(text: '50
  - `apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart:153` — [const] 7000 :: double.tryParse(_montantCtrl.text.replaceAll("'", '')) ?? 70
  - `apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart:156` — [const] 50000 :: 50000)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/arbitrage/location_vs_propriete_screen.dart — score 10
- **Calculs** (13 sites) :
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:722` — CHF\u00A0${value < 0 ? 
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:42` — [const] 200000 :: final _capitalCtrl = TextEditingController(text: '200000');
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:43` — [const] 2000 :: final _loyerCtrl = TextEditingController(text: '2000');
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:44` — [const] 800000 :: final _prixBienCtrl = TextEditingController(text: '800000');
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:139` — [const] 200000 :: double.tryParse(_capitalCtrl.text.replaceAll("'", '')) ?? 20
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:140` — [const] 2000 :: final loyer = double.tryParse(_loyerCtrl.text.replaceAll("'"
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:142` — [const] 800000 :: double.tryParse(_prixBienCtrl.text.replaceAll("'", '')) ?? 8
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:324` — [const] 800000 :: 800000,
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:327` — [const] 200000 :: 200000,
  - `apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart:330` — [const] 2000 :: 2000,
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/simulator_compound_screen.dart — score 10
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/simulator_compound_screen.dart:158` — [const] 5000 :: max: 5000,
- **Calculs** : 8 expressions de calcul locales SANS import financial_core (NEVER #3 / règle 4 — vérifier si L1 dupliqué).
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/simulator_compound_screen.dart:125` — « intérêt composé »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/simulator_compound_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/document_scan/document_stream_result_screen.dart — score 9
- **Route** : île/orphelin — `apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart` classes ['DocumentStreamResultScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart:45` — « Lecture du document »
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart — score 9
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:231` — Hypothèse\u00a0: rendement moyen 1,5 à 3,5\u202f%. 
- **Texte** (7 strings hardcodées, 7 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:136` — « SCENE · TA RETRAITE PROJETEE »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:146` — « À ton âge et ton revenu, voici ce qui arrive\u00a0si tu ne bouges rien »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:186` — « ÂGE D\u2019ESPÉRANCE DE VIE · ${_ageEsperance.toInt()} ans »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:220` — « Cumulé entre 65 et ${_ageEsperance.toInt()} ans\u00a0:  »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:221` — « environ CHF ${_fmt(cumulTotal)}. »
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:232` — « Source\u00a0: AVS art. 33ter LAVS, LPP art. 14-16. »

### screens/lamal_franchise_screen.dart — score 8
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/lamal_franchise_screen.dart:31` — [const] 2000 :: double _depensesSante = 2000;
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/lamal_franchise_screen.dart:39` — « lamal »
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/lamal_franchise_screen.dart:389` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/lamal_franchise_screen.dart:519` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/lamal_franchise_screen.dart:574` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/lamal_franchise_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/arbitrage/rente_vs_capital_screen.dart — score 7
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:1321` — « Depuis ton profil MINT »
- **A11y/cible** : `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:1283` — visualDensity: VisualDensity.compact,
- **A11y/cible** : `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:1693` — visualDensity: VisualDensity.compact,
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (défaut, 1 sites print/log) :
  - `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:2220` — INTERPOLÉ debugPrint('[MINT_E2E_ROUTE_STATE] $routeLabel');

### screens/debt_prevention/repayment_screen.dart — score 7
- **Calculs** (3 sites) :
  - `apps/mobile/lib/screens/debt_prevention/repayment_screen.dart:512` — [const] 3000 :: max: 3000,
  - `apps/mobile/lib/screens/debt_prevention/repayment_screen.dart:711` — [const] 5000 :: montant: 5000,
  - `apps/mobile/lib/screens/debt_prevention/repayment_screen.dart:724` — [const] 5000 :: max: 5000,
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/debt_prevention/repayment_screen.dart:1027` — shrinkWrap:true (liste imbriquée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/document_scan/extraction_review_screen.dart — score 7
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:346` — « [non fourni par l\'extraction] »
- **Métier/lois** (4 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:790` — « Lpp »
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:799` — « avs »
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:799` — « Avs »
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:799` — « AVS »
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:101` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:482` — spread .map( dans un children (liste non virtualisée)
- **Design system** (4 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:573` — [cta] TextButton(
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:580` — [cta] FilledButton(
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:625` — [cta] TextButton(
  - `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:629` — [cta] FilledButton(
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/documents_screen.dart — score 7
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/documents_screen.dart:849` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/documents_screen.dart:257` — shrinkWrap:true (liste imbriquée)
- **Design system** (6 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/documents_screen.dart:665` — [cta] FilledButton(
  - `apps/mobile/lib/screens/documents_screen.dart:772` — [cta] FilledButton(
  - `apps/mobile/lib/screens/documents_screen.dart:1209` — [cta] TextButton(
  - `apps/mobile/lib/screens/documents_screen.dart:1213` — [cta] FilledButton(
  - `apps/mobile/lib/screens/documents_screen.dart:204` — [text_style] fontSize: 24

### screens/open_banking/consent_screen.dart — score 7
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/open_banking/consent_screen.dart:94` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/open_banking/consent_screen.dart:554` — spread .map( dans un children (liste non virtualisée)
- **Design system** (5 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/open_banking/consent_screen.dart:476` — [cta] TextButton(
  - `apps/mobile/lib/screens/open_banking/consent_screen.dart:701` — [cta] OutlinedButton(
  - `apps/mobile/lib/screens/open_banking/consent_screen.dart:714` — [cta] FilledButton(
  - `apps/mobile/lib/screens/open_banking/consent_screen.dart:814` — [cta] OutlinedButton(

### screens/profile/privacy_control_screen.dart — score 7
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:264` — « Données financières »
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:271` — « Événements de vie »
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:278` — « Décisions »
- **Perf** (4 signaux) :
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:245` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:447` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:307` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/profile/privacy_control_screen.dart:459` — spread .map( dans un children (liste non virtualisée)

### screens/simulator_3a_screen.dart — score 7
- **Calculs** (3 sites) :
  - `apps/mobile/lib/screens/simulator_3a_screen.dart:215` — [const] 1900 :: if (birthYear != null && birthYear >= 1900) {
  - `apps/mobile/lib/screens/simulator_3a_screen.dart:229` — [const] 150000 :: if (annualIncome > 150000) {
  - `apps/mobile/lib/screens/simulator_3a_screen.dart:233` — [const] 60000 :: } else if (annualIncome > 60000) {
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/simulator_3a_screen.dart:517` — « Depuis ton profil MINT »
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/admin/admin_shell.dart — score 6
- **Route** : île/orphelin — `apps/mobile/lib/screens/admin/admin_shell.dart` classes ['AdminShell'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/admin/admin_shell.dart:23` — « MINT Admin »

### screens/admin_analytics_screen.dart — score 6
- **Texte** (2 strings hardcodées, 11 refs l10n) :
  - `apps/mobile/lib/screens/admin_analytics_screen.dart:203` — « Rafraîchir »
  - `apps/mobile/lib/screens/admin_analytics_screen.dart:315` — « ${(rate as num).toStringAsFixed(0)}% »
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/admin_analytics_screen.dart:318` — [text_style] fontSize: 12
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/admin_analytics_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/confidence/confidence_dashboard_screen.dart — score 6
- **Logique/dead-tap** : `apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart:349` onTap/onPressed vide.
- **Perf** (3 signaux) :
  - `apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart:262` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart:333` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart:435` — spread .map( dans un children (liste non virtualisée)

### screens/debug/debug_profile_bootstrap_screen.dart — score 6
- **Route** : île/orphelin — `apps/mobile/lib/screens/debug/debug_profile_bootstrap_screen.dart` classes ['DebugProfileBootstrapScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/debug/debug_profile_bootstrap_screen.dart:101` — « monthly net: ${result.monthlyNetIncome!.round()} »

### screens/open_banking/transaction_list_screen.dart — score 6
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/open_banking/transaction_list_screen.dart:495` — ] ?? 0).toStringAsFixed(1)}\u00a0%
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/open_banking/transaction_list_screen.dart:153` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/open_banking/transaction_list_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/pillar_3a_deep/retroactive_3a_screen.dart — score 6
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart:39` — [const] 2025 :: final yearsSince2025 = DateTime.now().year - 2025;
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart:408` — « Depuis ton profil MINT »
  - `apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart:717` — « Le rattrapage te fait \u00e9conomiser  »
  - `apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart:718` — « CHF\u00a0${formatChf(difference)} de plus en imp\u00f4ts\u00a0! »
- **A11y/cible** : `apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart:388` — visualDensity: VisualDensity.compact,
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/arbitrage/arbitrage_bilan_screen.dart — score 5
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart:591` — « Débloquer : ${locked.title} »
- **Perf** (4 signaux) :
  - `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart:140` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart:147` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart:162` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart:253` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/bank_import_screen.dart — score 5
- **Design system** (19 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/bank_import_screen.dart:727` — [cta] FilledButton(
  - `apps/mobile/lib/screens/bank_import_screen.dart:209` — [text_style] fontSize: 14
  - `apps/mobile/lib/screens/bank_import_screen.dart:266` — [text_style] fontSize: 15
  - `apps/mobile/lib/screens/bank_import_screen.dart:296` — [text_style] fontSize: 14
  - `apps/mobile/lib/screens/bank_import_screen.dart:332` — [text_style] fontSize: 14

### screens/budget/budget_screen.dart — score 5
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/budget/budget_screen.dart:1212` — 100%
  - `apps/mobile/lib/screens/budget/budget_screen.dart:1283` — 0%
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/budget/budget_screen.dart:781` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/byok_settings_screen.dart — score 5
- **Design system** (7 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/byok_settings_screen.dart:346` — [cta] FilledButton(
  - `apps/mobile/lib/screens/byok_settings_screen.dart:519` — [cta] TextButton(
  - `apps/mobile/lib/screens/byok_settings_screen.dart:523` — [cta] FilledButton(
  - `apps/mobile/lib/screens/byok_settings_screen.dart:234` — [fonts] fontFamily: '
  - `apps/mobile/lib/screens/byok_settings_screen.dart:245` — [fonts] fontFamily: '
  - `apps/mobile/lib/screens/byok_settings_screen.dart:233` — [text_style] fontSize: 14
  - `apps/mobile/lib/screens/byok_settings_screen.dart:246` — [text_style] fontSize: 14

### screens/debug/debug_budget_bootstrap_screen.dart — score 5
- **Route** : île/orphelin — `apps/mobile/lib/screens/debug/debug_budget_bootstrap_screen.dart` classes ['DebugBudgetBootstrapScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/debug/debug_budget_bootstrap_screen.dart:76` — « lamal=${inputs.healthInsurance.round()} »

### screens/debug/debug_mint2_account_claim_screen.dart — score 5
- **Route** : île/orphelin — `apps/mobile/lib/screens/debug/debug_mint2_account_claim_screen.dart` classes ['DebugMint2AccountClaimScreen'] — aucun chemin (ni route builder, ni redirect, ni référence externe).

### screens/household/household_screen.dart — score 5
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/household/household_screen.dart:144` — ListView(children:) non virtualisée
  - `apps/mobile/lib/screens/household/household_screen.dart:293` — spread .map( dans un children (liste non virtualisée)
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/household/household_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/coach/optimisation_decaissement_screen.dart — score 4
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/coach/optimisation_decaissement_screen.dart:295` — spread .map( dans un children (liste non virtualisée)
- **Design system** (3 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/coach/optimisation_decaissement_screen.dart:210` — [text_style] fontSize: 40
  - `apps/mobile/lib/screens/coach/optimisation_decaissement_screen.dart:311` — [text_style] fontSize: 12
  - `apps/mobile/lib/screens/coach/optimisation_decaissement_screen.dart:356` — [text_style] fontSize: 14

### screens/debt_risk_check_screen.dart — score 4
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/debt_risk_check_screen.dart:275` — spread .map( dans un children (liste non virtualisée)
- **Design system** (3 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/debt_risk_check_screen.dart:126` — [cta] FilledButton(
  - `apps/mobile/lib/screens/debt_risk_check_screen.dart:292` — [cta] OutlinedButton(
  - `apps/mobile/lib/screens/debt_risk_check_screen.dart:347` — [cta] OutlinedButton(

### screens/document_detail_screen.dart — score 4
- **Design system** (4 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/document_detail_screen.dart:275` — [cta] FilledButton(
  - `apps/mobile/lib/screens/document_detail_screen.dart:510` — [cta] TextButton(
  - `apps/mobile/lib/screens/document_detail_screen.dart:514` — [cta] FilledButton(
  - `apps/mobile/lib/screens/document_detail_screen.dart:343` — [text_style] fontSize: 16

### screens/document_scan/avs_guide_screen.dart — score 4
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/document_scan/avs_guide_screen.dart:214` — spread .map( dans un children (liste non virtualisée)
- **Design system** (3 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/document_scan/avs_guide_screen.dart:163` — [text_style] fontSize: 15
  - `apps/mobile/lib/screens/document_scan/avs_guide_screen.dart:249` — [text_style] fontSize: 15
  - `apps/mobile/lib/screens/document_scan/avs_guide_screen.dart:370` — [text_style] fontSize: 15

### screens/education/theme_detail_screen.dart — score 4
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/education/theme_detail_screen.dart:330` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/education/theme_detail_screen.dart:416` — spread .map( dans un children (liste non virtualisée)
- **Design system** (2 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/education/theme_detail_screen.dart:205` — [cta] FilledButton(
  - `apps/mobile/lib/screens/education/theme_detail_screen.dart:671` — [cta] FilledButton(

### screens/pillar_3a_deep/provider_comparator_screen.dart — score 4
- **Design system** (4 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart:269` — [text_style] fontSize: 12
  - `apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart:374` — [text_style] fontSize: 9
  - `apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart:392` — [text_style] fontSize: 12
  - `apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart:402` — [text_style] fontSize: 12

### screens/pillar_3a_deep/real_return_screen.dart — score 4
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/pillar_3a_deep/real_return_screen.dart:141` — ListView(children:) non virtualisée
- **Lucidité** : écran chiffré, 0 référence confiance/enrichment/incertitude (`apps/mobile/lib/screens/pillar_3a_deep/real_return_screen.dart`).
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/pillar_3a_deep/staggered_withdrawal_screen.dart — score 4
- **Calculs** (2 sites) :
  - `apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart:40` — [const] 300000 :: double _avoirTotal = 300000;
  - `apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart:43` — [const] 120000 :: double _revenuImposable = 120000;
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/profile/privacy_center_screen.dart — score 4
- **A11y** : 7 sites interactifs, 0 référence Semantics dans `apps/mobile/lib/screens/profile/privacy_center_screen.dart`.
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/profile/privacy_center_screen.dart:147` — ListView(children:) non virtualisée

### screens/gender_gap_screen.dart — score 3
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/gender_gap_screen.dart:114` — [const] 20000 :: if (provided.contains('salary') && revenu >= 20000 && revenu
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/gender_gap_screen.dart:883` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/household/accept_invitation_screen.dart — score 3
- **Design system** (3 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/household/accept_invitation_screen.dart:123` — [cta] FilledButton(
  - `apps/mobile/lib/screens/household/accept_invitation_screen.dart:186` — [cta] FilledButton(
  - `apps/mobile/lib/screens/household/accept_invitation_screen.dart:98` — [text_style] fontSize: 28

### screens/mon_argent/mon_argent_screen.dart — score 3
- **Texte** (1 strings hardcodées, 57 refs l10n) :
  - `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart:67` — « prévoyance »
- **A11y/cible** : `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart:409` — materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
- **A11y/cible** : `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart:410` — visualDensity: VisualDensity.compact,

### screens/onboarding/mvp_wedge/onboarding_provider.dart — score 3
- **Texte** (3 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart:289` — « Date de naissance »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart:361` — « Revenu net mensuel »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart:374` — « Revenu net mensuel »
- **Métier/lois** (1 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart:505` — « lpp.entry_threshold »

### screens/about_screen.dart — score 2
- **Design system** (2 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/about_screen.dart:69` — [text_style] fontSize: 48
  - `apps/mobile/lib/screens/about_screen.dart:149` — [text_style] fontSize: 15

### screens/cantonal_benchmark_screen.dart — score 2
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/cantonal_benchmark_screen.dart:107` — « Une erreur est survenue. Réessaie plus tard. »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/cantonal_benchmark_screen.dart:256` — spread .map( dans un children (liste non virtualisée)

### screens/coverage_check_screen.dart — score 2
- **Perf** (2 signaux) :
  - `apps/mobile/lib/screens/coverage_check_screen.dart:547` — spread .map( dans un children (liste non virtualisée)
  - `apps/mobile/lib/screens/coverage_check_screen.dart:683` — spread .map( dans un children (liste non virtualisée)

### screens/onboarding/mvp_wedge/dossier_strip.dart — score 2
- **Texte** (2 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/dossier_strip.dart:61` — « TON DOSSIER »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/dossier_strip.dart:72` — « Il se remplit tour par tour. »

### screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart — score 2
- **Calculs** (1 sites) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:232` — [const] 1950 :: _parsedNumber = (n >= 1950 && n <= currentYear) ? n : null;
- **Métier/lois** (6 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:125` — « onboarding-avs-no-gaps »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:129` — « onboarding-avs-lived-abroad »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:135` — « onboarding-avs-arrived-late »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:138` — « onboarding-avs-unknown »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:210` — « onboarding-avs-number-field »
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart:249` — « onboarding-avs-continue »

### screens/profile/financial_summary_screen.dart — score 2
- **Texte** (1 strings hardcodées, 1 refs l10n) :
  - `apps/mobile/lib/screens/profile/financial_summary_screen.dart:80` — « [FinancialSummary] restart diagnostic reset step failed:  »
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.
- **Privacy** (warn, 1 sites print/log) :
  - `apps/mobile/lib/screens/profile/financial_summary_screen.dart:79` — debugPrint(

### screens/advisor/financial_report_screen_v2.dart — score 1
- **Métier/lois** (2 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart:37` — « /rachat-lpp »
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart:40` — « /assurances/lamal »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart:544` — spread .map( dans un children (liste non virtualisée)

### screens/auth/forgot_password_screen.dart — score 1
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/auth/forgot_password_screen.dart:247` — [cta] FilledButton(

### screens/auth/login_screen.dart — score 1
- **Texte** (1 strings hardcodées, 26 refs l10n) :
  - `apps/mobile/lib/screens/auth/login_screen.dart:177` — « Apple Sign-In failed »

### screens/auth/register_screen.dart — score 1
- **Texte** (1 strings hardcodées, 61 refs l10n) :
  - `apps/mobile/lib/screens/auth/register_screen.dart:394` — « MINT_E2E_REGISTER_DOB must use YYYY-MM-DD format. »

### screens/explore/explore_hub_screen.dart — score 1
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/explore/explore_hub_screen.dart:24` — [color_token] Colors.white

### screens/explore/explorer_screen.dart — score 1
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/explore/explorer_screen.dart:21` — [color_token] Colors.white

### screens/onboarding/data_block_enrichment_screen.dart — score 1
- **Métier/lois** (15 citations — revue mint-swiss-brain, non tranché ici) :
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:32` — « lpp »
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:33` — « avs »
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:566` — « lpp »
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:566` — « lpp »
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:567` — « avs »
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:567` — « avs »
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:503` — spread .map( dans un children (liste non virtualisée)
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

### screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart — score 1
- **Texte** (1 strings hardcodées, 0 refs l10n) :
  - `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart:106` — « CoachCivilStatus changed — update MintSceneEtatCivil options. »

### screens/open_banking/open_banking_hub_screen.dart — score 1
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/open_banking/open_banking_hub_screen.dart:53` — spread .map( dans un children (liste non virtualisée)

### screens/settings/confidentialite_settings_screen.dart — score 1
- **Perf** (1 signaux) :
  - `apps/mobile/lib/screens/settings/confidentialite_settings_screen.dart:60` — ListView(children:) non virtualisée

### screens/settings/langue_settings_screen.dart — score 1
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/settings/langue_settings_screen.dart:59` — [text_style] fontSize: 24

### screens/timeline_screen.dart — score 1
- **Design system** (1 sites prefer_mint_*) :
  - `apps/mobile/lib/screens/timeline_screen.dart:353` — [text_style] fontSize: 24

### screens/aujourdhui/aujourdhui_screen.dart — score 0
- **Temps** : chiffres sans millésime/source datée détectée — à confirmer runtime.

## 3. Clusters / doublons

### C1-onboarding
- Canonique candidate : `screens/onboarding/mvp_wedge/onboarding_shell_screen.dart (/onb)`
- Membres : `screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`, `screens/onboarding/data_block_enrichment_screen.dart`
- RÉSOLU côté routes : les 9 variantes /onboarding/* sont des redirects vers /onb (+ /onboarding/enrichment → /profile/bilan). Écrans variantes supprimés du code. Restant : 6 scènes mvp_wedge (fichiers support) à revoir avec le shell.

### C2-rente-vs-capital
- Canonique candidate : `screens/coach/rente_vs_capital_screen.dart (/retraite/rente-vs-capital)`
- RÉSOLU : /rente-vs-capital, /arbitrage/rente-vs-capital, /simulator/rente-capital redirigent vers la canonique.

### C3-chat
- Canonique candidate : `screens/coach/coach_chat_screen.dart (/coach/chat, Tab2)`
- Membres : `screens/coach/coach_chat_screen.dart`, `screens/anonymous/anonymous_chat_screen.dart`, `screens/coach/chat_as_verb_demo_screen.dart`
- AnonymousChatScreen = classe orpheline (route /anonymous/chat → redirect /onb) — candidate SUPPRESSION. ChatAsVerbDemoScreen = île debug volontaire.

### C4-dashboards
- Canonique candidate : `screens/aujourdhui/aujourdhui_screen.dart (/home, Tab0)`
- Membres : `screens/aujourdhui/aujourdhui_screen.dart`, `screens/mon_argent/mon_argent_screen.dart`, `screens/coach/retirement_dashboard_screen.dart`, `screens/confidence/confidence_dashboard_screen.dart`, `screens/profile/financial_summary_screen.dart`
- 5 surfaces « dashboard » subsistent : Tab0 Aujourd'hui (canonique home), Mon argent (Tab1), Retraite (/retraite), Confidence (/confidence, 🟡) et Bilan (/profile/bilan). Chevauchement Confidence↔Bilan à trancher (tous deux affichent complétude/patrimoine).

### C5-disability
- Canonique candidate : `screens/disability_gap_screen.dart? (/invalidite) — à trancher`
- Membres : `screens/disability/disability_insurance_screen.dart`, `screens/disability/disability_self_employed_screen.dart`
- 3 écrans invalidité distincts ; /disability/gap et /simulator/disability-gap redirigent déjà vers /invalidite. Frontière lacune vs assurance vs indépendant à valider produit.

### C6-epl
- Canonique candidate : `screens/mortgage/epl_screen.dart (/epl)`
- Membres : `screens/mortgage/epl_combined_screen.dart`
- /lpp-deep/epl → /epl (résolu). EplCombinedScreen (/mortgage/epl-combined) reste un 2e écran EPL+hypothèque — fusion ou différenciation claire à trancher.

### C7-budget
- Canonique candidate : `screens/budget/budget_container_screen.dart (/budget)`
- Membres : `screens/budget/budget_screen.dart`, `screens/budget/budget_setup_screen.dart`
- BudgetScreen est hébergé par le container (pattern container/content, pas un doublon) mais n'a plus de route directe ; vérifier que le contenu ne dérive pas du container.

### C8-document-scan
- Canonique candidate : `screens/document_scan/document_scan_screen.dart (/scan)`
- Membres : `screens/document_scan/document_stream_result_screen.dart`
- /document-scan → /scan (résolu). DocumentStreamResultScreen = orphelin complet (0 réf) — candidate SUPPRESSION (déjà repéré par ROUTE-MAP 2026-07-23, toujours présent).

### C9-explore-hub
- Canonique candidate : `screens/explore/explorer_screen.dart (/explore, Tab3)`
- Membres : `screens/explore/explore_hub_screen.dart`
- 1 classe ExploreHubScreen servie sur 7 routes /explore/<domaine> — hub-and-spoke voulu, pas un doublon. Vérifier contenu par domaine au runtime.

### Alias redirects par cible (47)

- `/coach/chat` ← /advisor, /advisor/plan-30-days, /advisor/wizard, /ask-mint, /coach/agir, /coach/checkin, /tools
- `/couple` ← /household
- `/decaissement` ← /arbitrage/calendrier-retraits, /coach/decaissement
- `/divorce` ← /life-event/divorce
- `/epl` ← /lpp-deep/epl
- `/home` ← /achievements, /coach/refresh, /portfolio, /score-reveal
- `/hypotheque` ← /mortgage/affordability
- `/invalidite` ← /disability/gap, /simulator/disability-gap
- `/libre-passage` ← /lpp-deep/libre-passage
- `/onb` ← /anonymous/chat, /onboarding/intent, /onboarding/minimal, /onboarding/plan, /onboarding/premier-eclairage, /onboarding/promise, /onboarding/quick, /onboarding/quick-start, /onboarding/smart, /start
- `/pilier-3a` ← /simulator/3a
- `/profile/bilan` ← /onboarding/enrichment
- `/rachat-lpp` ← /arbitrage/rachat-vs-marche, /lpp-deep/rachat
- `/rapport` ← /report, /report/v2
- `/retraite` ← /coach/cockpit, /coach/dashboard, /retirement, /retirement/projection
- `/retraite/rente-vs-capital` ← /arbitrage/rente-vs-capital, /rente-vs-capital, /simulator/rente-capital
- `/scan` ← /document-scan
- `/scan/avs-guide` ← /document-scan/avs-guide
- `/succession` ← /coach/succession, /life-event/succession

## 4. Tranche firstJob (premier lot revue complète 6/6)

Parcours : Landing `/` → Onboarding `/onb` → Dashboard `/home` (Tab0) → FirstJob `/first-job` → Coach `/coach/chat` (Tab2).
⚠️ `/first-job` est 🟡 registre-seulement : aucun bouton visible n'y mène — la revue runtime doit valider l'entrée réelle (coach route_to_screen ou Explore).

### screens/landing_screen.dart
- Routes ['/'] · Nav 🟢 · Calc ok (0 flags) · Texte ok · Log ··· · Lois 0
- 12D : A11y ok(6sem) · Perf ok · DS ok · Lucid — · Temps — · Priv ok
- Nourriciers (1) : `lib/widgets/beta/beta_program_disclosure_sheet.dart`

### screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
- Routes ['/onb'] · Nav 🟢 · Calc défaut (6 flags) · Texte défaut(29) · Log ·E· · Lois 1
- 12D : A11y ok(13sem) · Perf ok · DS ok · Lucid défaut(0) · Temps RT(0) · Priv ok
- Nourriciers (6) : `lib/models/onboarding_intent.dart`, `lib/providers/auth_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/feature_flags.dart`, `lib/services/profile_migration_service.dart`, `lib/widgets/premium/mint_surface.dart`

### screens/aujourdhui/aujourdhui_screen.dart
- Routes ['/home'] · Nav 🟢 · Calc RT (0 flags) · Texte ok · Log L·V · Lois 0
- 12D : A11y ok(0sem) · Perf ok · DS ok · Lucid RT(33) · Temps RT(0) · Priv ok
- Nourriciers (13) : `lib/models/financial_plan.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/financial_plan_provider.dart`, `lib/providers/timeline_provider.dart`, `lib/services/financial_core/confidence_scorer.dart`, `lib/widgets/aujourdhui/cap_du_jour_banner.dart`, `lib/widgets/aujourdhui/commitments_and_checkins_card.dart`, `lib/widgets/home/confidence_score_card.dart`, `lib/widgets/home/financial_plan_card.dart`, `lib/widgets/tension/cleo_loop_indicator.dart`, `lib/widgets/tension/tension_card_widget.dart`, `lib/widgets/timeline/month_header_widget.dart`, `lib/widgets/timeline/timeline_node_widget.dart`

### screens/first_job_screen.dart
- Routes ['/first-job'] · Nav 🟡 · Calc DÉFAUT (14 flags) · Texte défaut(6) · Log ·EV · Lois 8
- 12D : A11y ok(5sem) · Perf défaut(1) · DS ok · Lucid défaut(0) · Temps RT(0) · Priv ok
- Nourriciers (17) : `lib/constants/social_insurance.dart`, `lib/models/screen_return.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/first_job_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/screen_completion_tracker.dart`, `lib/widgets/coach/budget_503020_widget.dart`, `lib/widgets/coach/career_timelapse_widget.dart`, `lib/widgets/coach/first_salary_film_widget.dart`, `lib/widgets/coach/job_change_checklist_widget.dart`, `lib/widgets/coach/payslip_xray_widget.dart`, `lib/widgets/educational/salary_breakdown_widget.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_narrative_card.dart`, `lib/widgets/premium/mint_premium_slider.dart`, `lib/widgets/premium/mint_surface.dart`, `lib/widgets/situation/situation_gate.dart`

### screens/coach/coach_chat_screen.dart
- Routes ['/coach/chat'] · Nav 🟢 · Calc RT (0 flags) · Texte défaut(14) · Log LEV · Lois 6
- 12D : A11y ok(5sem) · Perf ok · DS ok · Lucid RT(7) · Temps RT(0) · Priv warn(19)
- Nourriciers (55) : `lib/domain/budget/budget_inputs.dart`, `lib/models/coach_entry_payload.dart`, `lib/models/coach_insight.dart`, `lib/models/coach_profile.dart`, `lib/models/mint_user_state.dart`, `lib/models/response_card.dart`, `lib/models/screen_return.dart`, `lib/providers/auth_provider.dart`, `lib/providers/budget/budget_provider.dart`, `lib/providers/byok_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/mint_state_provider.dart`, `lib/services/analytics_service.dart`, `lib/services/budget_living_engine.dart`, `lib/services/cap_memory_store.dart`, `lib/services/chat/fact_extraction_fallback.dart`, `lib/services/coach/chat_tool_dispatcher.dart`, `lib/services/coach/coach_chat_api_service.dart`, `lib/services/coach/coach_context_profile_mapper.dart`, `lib/services/coach/coach_models.dart`, `lib/services/coach/coach_orchestrator.dart`, `lib/services/coach/compliance_guard.dart`, `lib/services/coach/context_injector_service.dart`, `lib/services/coach/conversation_store.dart`, `lib/services/coach/local_fallback_service.dart`, `lib/services/coach/precomputed_insights_service.dart`, `lib/services/coach/proactive_trigger_service.dart`, `lib/services/coach/tool_call_parser.dart`, `lib/services/coach_llm_service.dart`, `lib/services/consent/consent_service.dart`, `lib/services/data_spine/coach_context_packet_adapter.dart`, `lib/services/data_spine/coach_packet_insight_presenter.dart`, `lib/services/feature_flags.dart`, `lib/services/financial_fitness_service.dart`, `lib/services/forecaster_service.dart`, `lib/services/memory/coach_memory_service.dart`, `lib/services/navigation/mint_nav.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/pdf_service.dart`, `lib/services/rag_service.dart`, `lib/services/report_persistence_service.dart`, `lib/services/response_card_service.dart`, `lib/services/screen_completion_tracker.dart`, `lib/services/sequence/sequence_chat_handler.dart`, `lib/services/sequence/sequence_coordinator.dart`, `lib/services/telemetry/gate_decision_telemetry.dart`, `lib/widgets/coach/chat_drawer_host.dart`, `lib/widgets/coach/coach_app_bar.dart`, `lib/widgets/coach/coach_input_bar.dart`, `lib/widgets/coach/coach_loading_indicator.dart`, `lib/widgets/coach/coach_message_bubble.dart`, `lib/widgets/coach/coach_packet_insight_card.dart`, `lib/widgets/coach/lightning_menu.dart`, `lib/widgets/coach/response_card_widget.dart`, `lib/widgets/pulse/cap_card.dart`

Fichiers support onboarding à inclure : `screens/onboarding/mvp_wedge/{onboarding_provider,dossier_strip,discrete_adjust_control}.dart`, `scenes/*.dart` (6 scènes + us_tax_person_screen), `widgets/onboarding_choice_button.dart`.

## 5. Découpage Codex (passes de revue par lot)

### LOT-1 firstJob (priorité 1)
- Écrans : `screens/landing_screen.dart`, `screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`, `screens/aujourdhui/aujourdhui_screen.dart`, `screens/first_job_screen.dart`, `screens/coach/coach_chat_screen.dart`
- Nourriciers à joindre (83) : `lib/constants/social_insurance.dart`, `lib/domain/budget/budget_inputs.dart`, `lib/models/coach_entry_payload.dart`, `lib/models/coach_insight.dart`, `lib/models/coach_profile.dart`, `lib/models/financial_plan.dart`, `lib/models/mint_user_state.dart`, `lib/models/onboarding_intent.dart`, `lib/models/response_card.dart`, `lib/models/screen_return.dart`, `lib/providers/auth_provider.dart`, `lib/providers/budget/budget_provider.dart`, `lib/providers/byok_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/financial_plan_provider.dart`, `lib/providers/mint_state_provider.dart`, `lib/providers/timeline_provider.dart`, `lib/services/analytics_service.dart`, `lib/services/budget_living_engine.dart`, `lib/services/cap_memory_store.dart`, `lib/services/chat/fact_extraction_fallback.dart`, `lib/services/coach/chat_tool_dispatcher.dart`, `lib/services/coach/coach_chat_api_service.dart`, `lib/services/coach/coach_context_profile_mapper.dart`, `lib/services/coach/coach_models.dart` …

### LOT-2 onboarding-support
- Écrans : `screens/onboarding/mvp_wedge/discrete_adjust_control.dart`, `screens/onboarding/mvp_wedge/dossier_strip.dart`, `screens/onboarding/mvp_wedge/onboarding_provider.dart`, `screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart`, `screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart`, `screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart`, `screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart`, `screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart`, `screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart`, `screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart`, `screens/onboarding/mvp_wedge/widgets/onboarding_choice_button.dart`, `screens/onboarding/data_block_enrichment_screen.dart`
- Nourriciers à joindre (17) : `lib/constants/social_insurance.dart`, `lib/models/coach_profile.dart`, `lib/models/onboarding_intent.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/slm_provider.dart`, `lib/services/cross_validation_service.dart`, `lib/services/feature_flags.dart`, `lib/services/financial_core/avs_calculator.dart`, `lib/services/financial_core/confidence_scorer.dart`, `lib/services/financial_core/lpp_calculator.dart`, `lib/services/income_converter.dart`, `lib/services/navigation/mint_nav.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/profile_migration_service.dart`, `lib/services/report_persistence_service.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_surface.dart`

### LOT-3 argent/budget
- Écrans : `screens/mon_argent/mon_argent_screen.dart`, `screens/budget/budget_container_screen.dart`, `screens/budget/budget_screen.dart`, `screens/budget/budget_setup_screen.dart`, `screens/profile/financial_summary_screen.dart`, `screens/bank_import_screen.dart`, `screens/open_banking/open_banking_hub_screen.dart`, `screens/open_banking/consent_screen.dart`, `screens/open_banking/transaction_list_screen.dart`
- Nourriciers à joindre (53) : `lib/domain/budget/budget_inputs.dart`, `lib/domain/budget/budget_plan.dart`, `lib/domain/budget/present_budget_builder.dart`, `lib/models/budget_snapshot.dart`, `lib/models/cap_decision.dart`, `lib/models/coach_profile.dart`, `lib/models/data_spine_snapshot.dart`, `lib/models/screen_return.dart`, `lib/providers/auth_provider.dart`, `lib/providers/budget/budget_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/mint_state_provider.dart`, `lib/services/budget_living_engine.dart`, `lib/services/cap_engine.dart`, `lib/services/cap_memory_store.dart`, `lib/services/coach/conversation_store.dart`, `lib/services/coach/precomputed_insights_service.dart`, `lib/services/document_service.dart`, `lib/services/e2e_runtime_flags.dart`, `lib/services/feature_flags.dart`, `lib/services/financial_core/lpp_calculator.dart`, `lib/services/financial_core/pillar3a_room_calculator.dart`, `lib/services/financial_core/tax_calculator.dart`, `lib/services/memory/coach_memory_service.dart`, `lib/services/mon_argent/coach_whisper_service.dart` …

### LOT-4 retraite/prévoyance
- Écrans : `screens/coach/retirement_dashboard_screen.dart`, `screens/arbitrage/rente_vs_capital_screen.dart`, `screens/coach/optimisation_decaissement_screen.dart`, `screens/simulator_3a_screen.dart`, `screens/lpp_deep/rachat_echelonne_screen.dart`, `screens/lpp_deep/libre_passage_screen.dart`, `screens/lpp_deep/epl_screen.dart`
- Nourriciers à joindre (55) : `lib/constants/social_insurance.dart`, `lib/domain/calculators.dart`, `lib/models/coach_profile.dart`, `lib/models/profile.dart`, `lib/models/screen_return.dart`, `lib/providers/byok_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/profile_provider.dart`, `lib/services/api_service.dart`, `lib/services/coach_llm_service.dart`, `lib/services/coach_narrative_service.dart`, `lib/services/coaching_service.dart`, `lib/services/dashboard_curator_service.dart`, `lib/services/e2e_runtime_flags.dart`, `lib/services/financial_core/arbitrage_engine.dart`, `lib/services/financial_core/arbitrage_models.dart`, `lib/services/financial_core/confidence_scorer.dart`, `lib/services/financial_core/financial_core.dart`, `lib/services/financial_core/tax_calculator.dart`, `lib/services/financial_fitness_service.dart`, `lib/services/forecaster_service.dart`, `lib/services/lpp_deep_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/reengagement_engine.dart`, `lib/services/report_persistence_service.dart` …

### LOT-5 3a-deep/arbitrages
- Écrans : `screens/pillar_3a_deep/provider_comparator_screen.dart`, `screens/pillar_3a_deep/real_return_screen.dart`, `screens/pillar_3a_deep/staggered_withdrawal_screen.dart`, `screens/pillar_3a_deep/retroactive_3a_screen.dart`, `screens/arbitrage/allocation_annuelle_screen.dart`, `screens/arbitrage/location_vs_propriete_screen.dart`, `screens/arbitrage/arbitrage_bilan_screen.dart`
- Nourriciers à joindre (28) : `lib/constants/social_insurance.dart`, `lib/models/coach_profile.dart`, `lib/models/screen_return.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/arbitrage_summary_service.dart`, `lib/services/financial_core/arbitrage_engine.dart`, `lib/services/financial_core/arbitrage_models.dart`, `lib/services/financial_core/confidence_scorer.dart`, `lib/services/financial_core/tax_calculator.dart`, `lib/services/lpp_deep_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/pillar_3a_deep_service.dart`, `lib/services/retroactive_3a_calculator.dart`, `lib/services/screen_completion_tracker.dart`, `lib/widgets/arbitrage/arbitrage_tornado_section.dart`, `lib/widgets/arbitrage/breakeven_indicator_widget.dart`, `lib/widgets/arbitrage/hypothesis_editor_widget.dart`, `lib/widgets/arbitrage/trajectory_comparison_chart.dart`, `lib/widgets/coach/indicatif_banner.dart`, `lib/widgets/coach/rent_vs_buy_scoreboard_widget.dart`, `lib/widgets/common/mint_empty_state.dart`, `lib/widgets/common/safe_mode_gate.dart`, `lib/widgets/precision/smart_default_indicator.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_narrative_card.dart` …

### LOT-6 indépendants
- Écrans : `screens/independants/avs_cotisations_screen.dart`, `screens/independants/dividende_vs_salaire_screen.dart`, `screens/independants/ijm_screen.dart`, `screens/independants/lpp_volontaire_screen.dart`, `screens/independants/pillar_3a_indep_screen.dart`, `screens/independant_screen.dart`
- Nourriciers à joindre (19) : `lib/constants/social_insurance.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/independants_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/segments_service.dart`, `lib/widgets/coach/double_price_freedom_widget.dart`, `lib/widgets/coach/fiscal_superpower_widget.dart`, `lib/widgets/coach/lpp_rescue_widget.dart`, `lib/widgets/coach/lpp_vs_3a_decision_tree.dart`, `lib/widgets/coach/ninety_day_plan_widget.dart`, `lib/widgets/coach/true_hourly_rate_widget.dart`, `lib/widgets/common/safe_mode_gate.dart`, `lib/widgets/premium/mint_amount_field.dart`, `lib/widgets/premium/mint_count_up.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_hero_number.dart`, `lib/widgets/premium/mint_picker_tile.dart`, `lib/widgets/premium/mint_premium_slider.dart`, `lib/widgets/premium/mint_surface.dart`

### LOT-7 logement/hypothèque
- Écrans : `screens/mortgage/affordability_screen.dart`, `screens/mortgage/amortization_screen.dart`, `screens/mortgage/epl_combined_screen.dart`, `screens/mortgage/imputed_rental_screen.dart`, `screens/mortgage/saron_vs_fixed_screen.dart`, `screens/housing_sale_screen.dart`
- Nourriciers à joindre (27) : `lib/constants/social_insurance.dart`, `lib/models/coach_profile.dart`, `lib/models/screen_return.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/financial_core/tax_calculator.dart`, `lib/services/housing_sale_service.dart`, `lib/services/lpp_deep_service.dart`, `lib/services/mortgage_service.dart`, `lib/services/report_persistence_service.dart`, `lib/services/screen_completion_tracker.dart`, `lib/widgets/coach/mortgage_journey_widget.dart`, `lib/widgets/coach/net_proceeds_widget.dart`, `lib/widgets/coach/remploi_countdown_widget.dart`, `lib/widgets/collapsible_section.dart`, `lib/widgets/couple/conjoint_missing_hint.dart`, `lib/widgets/precision/smart_default_indicator.dart`, `lib/widgets/premium/mint_amount_field.dart`, `lib/widgets/premium/mint_confidence_notice.dart`, `lib/widgets/premium/mint_count_up.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_narrative_card.dart`, `lib/widgets/premium/mint_picker_tile.dart`, `lib/widgets/premium/mint_premium_slider.dart`, `lib/widgets/premium/mint_result_hero_card.dart`, `lib/widgets/premium/mint_signal_row.dart` …

### LOT-8 life-events/fiscal
- Écrans : `screens/mariage_screen.dart`, `screens/naissance_screen.dart`, `screens/concubinage_screen.dart`, `screens/divorce_simulator_screen.dart`, `screens/deces_proche_screen.dart`, `screens/donation_screen.dart`, `screens/coach/succession_patrimoine_screen.dart`, `screens/demenagement_cantonal_screen.dart`, `screens/fiscal_comparator_screen.dart`, `screens/cantonal_benchmark_screen.dart`, `screens/first_job_screen.dart`
- Nourriciers à joindre (51) : `lib/constants/social_insurance.dart`, `lib/models/coach_profile.dart`, `lib/models/screen_return.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/cantonal_benchmark_service.dart`, `lib/services/donation_service.dart`, `lib/services/family_service.dart`, `lib/services/financial_core/financial_core.dart`, `lib/services/financial_core/lpp_calculator.dart`, `lib/services/first_job_service.dart`, `lib/services/fiscal_service.dart`, `lib/services/life_events_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/screen_completion_tracker.dart`, `lib/services/wealth_tax_service.dart`, `lib/widgets/coach/avancement_hoirie_widget.dart`, `lib/widgets/coach/baby_cost_widget.dart`, `lib/widgets/coach/budget_503020_widget.dart`, `lib/widgets/coach/budget_bebe_widget.dart`, `lib/widgets/coach/career_timelapse_widget.dart`, `lib/widgets/coach/clause_3a_widget.dart`, `lib/widgets/coach/couple_narrative_timeline.dart`, `lib/widgets/coach/death_urgency_guide_widget.dart`, `lib/widgets/coach/divorce_film_widget.dart`, `lib/widgets/coach/edu_shared_widgets.dart` …

### LOT-9 segments/risques
- Écrans : `screens/expat_screen.dart`, `screens/frontalier_screen.dart`, `screens/gender_gap_screen.dart`, `screens/unemployment_screen.dart`, `screens/disability/disability_gap_screen.dart`, `screens/disability/disability_insurance_screen.dart`, `screens/disability/disability_self_employed_screen.dart`, `screens/coverage_check_screen.dart`, `screens/lamal_franchise_screen.dart`
- Nourriciers à joindre (37) : `lib/constants/social_insurance.dart`, `lib/models/screen_return.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/assurances_service.dart`, `lib/services/expat_service.dart`, `lib/services/family_service.dart`, `lib/services/financial_core/income_tax_model_v2.dart`, `lib/services/fiscal_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/report_persistence_service.dart`, `lib/services/screen_completion_tracker.dart`, `lib/services/segments_service.dart`, `lib/services/unemployment_service.dart`, `lib/widgets/coach/avs_gap_widget.dart`, `lib/widgets/coach/crash_test_budget_widget.dart`, `lib/widgets/coach/disability_cliff_widget.dart`, `lib/widgets/coach/disability_countdown_widget.dart`, `lib/widgets/coach/disability_red_screen_widget.dart`, `lib/widgets/coach/disability_reset_widget.dart`, `lib/widgets/coach/disability_scorecard_widget.dart`, `lib/widgets/coach/edu_shared_widgets.dart`, `lib/widgets/coach/expat_countdown_widget.dart`, `lib/widgets/coach/expat_rights_loss_widget.dart`, `lib/widgets/coach/franchise_cost_widget.dart`, `lib/widgets/coach/top_cantons_widget.dart` …

### LOT-10 dettes/simulateurs
- Écrans : `screens/debt_risk_check_screen.dart`, `screens/debt_prevention/debt_ratio_screen.dart`, `screens/debt_prevention/help_resources_screen.dart`, `screens/debt_prevention/repayment_screen.dart`, `screens/consumer_credit_screen.dart`, `screens/simulator_leasing_screen.dart`, `screens/simulator_compound_screen.dart`, `screens/job_comparison_screen.dart`
- Nourriciers à joindre (25) : `lib/constants/social_insurance.dart`, `lib/domain/calculators.dart`, `lib/models/coach_profile.dart`, `lib/models/screen_return.dart`, `lib/providers/coach_profile_provider.dart`, `lib/services/debt_prevention_service.dart`, `lib/services/job_comparison_service.dart`, `lib/services/lpp_deep_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/report_persistence_service.dart`, `lib/services/screen_completion_tracker.dart`, `lib/widgets/coach/debt_repayment_widget.dart`, `lib/widgets/coach/debt_survival_widget.dart`, `lib/widgets/coach/job_change_comparison_widget.dart`, `lib/widgets/coach/leasing_cost_widget.dart`, `lib/widgets/common/debt_tools_nav.dart`, `lib/widgets/info_tooltip.dart`, `lib/widgets/premium/mint_amount_field.dart`, `lib/widgets/premium/mint_count_up.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_hero_number.dart`, `lib/widgets/premium/mint_picker_tile.dart`, `lib/widgets/premium/mint_premium_slider.dart`, `lib/widgets/premium/mint_surface.dart`, `lib/widgets/simulators/simulator_card.dart`

### LOT-11 documents/scan
- Écrans : `screens/document_scan/avs_guide_screen.dart`, `screens/document_scan/document_impact_screen.dart`, `screens/document_scan/document_scan_screen.dart`, `screens/document_scan/document_stream_result_screen.dart`, `screens/document_scan/extraction_review_screen.dart`, `screens/documents_screen.dart`, `screens/document_detail_screen.dart`
- Nourriciers à joindre (31) : `lib/models/document_event.dart`, `lib/models/screen_return.dart`, `lib/providers/biography_provider.dart`, `lib/providers/byok_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/document_provider.dart`, `lib/providers/subscription_provider.dart`, `lib/services/biography/biography_fact.dart`, `lib/services/commitment_service.dart`, `lib/services/consent/consent_service.dart`, `lib/services/document_parser/avs_extract_parser.dart`, `lib/services/document_parser/document_models.dart`, `lib/services/document_parser/lpp_certificate_parser.dart`, `lib/services/document_parser/salary_certificate_parser.dart`, `lib/services/document_parser/tax_declaration_parser.dart`, `lib/services/document_service.dart`, `lib/services/document_understanding_result.dart`, `lib/services/exif_scrub.dart`, `lib/services/financial_core/confidence_scorer.dart`, `lib/services/local_image_classifier.dart`, `lib/services/memory/coach_memory_service.dart`, `lib/services/native_document_scanner.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/rag_service.dart`, `lib/services/screen_completion_tracker.dart` …

### LOT-12 profil/settings/auth
- Écrans : `screens/auth/auth_platform.dart`, `screens/auth/auth_redirect.dart`, `screens/auth/forgot_password_screen.dart`, `screens/auth/login_screen.dart`, `screens/auth/register_screen.dart`, `screens/auth/verify_email_screen.dart`, `screens/household/accept_invitation_screen.dart`, `screens/household/household_screen.dart`, `screens/profile/financial_summary_screen.dart`, `screens/profile/privacy_center_screen.dart`, `screens/profile/privacy_control_screen.dart`, `screens/settings/confidentialite_settings_screen.dart`, `screens/settings/langue_settings_screen.dart`, `screens/byok_settings_screen.dart`, `screens/slm_settings_screen.dart`, `screens/admin_analytics_screen.dart`, `screens/admin_observability_screen.dart`, `screens/coach/conversation_history_screen.dart`
- Nourriciers à joindre (46) : `lib/models/coach_profile.dart`, `lib/providers/auth_provider.dart`, `lib/providers/biography_provider.dart`, `lib/providers/byok_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/household_provider.dart`, `lib/providers/locale_provider.dart`, `lib/providers/slm_provider.dart`, `lib/providers/subscription_provider.dart`, `lib/services/account_handoff_service.dart`, `lib/services/api_service.dart`, `lib/services/apple_sign_in_service.dart`, `lib/services/biography/biography_fact.dart`, `lib/services/cap_memory_store.dart`, `lib/services/coach/conversation_store.dart`, `lib/services/coach/precomputed_insights_service.dart`, `lib/services/consent/consent_service.dart`, `lib/services/dob_age_calculator.dart`, `lib/services/feature_flags.dart`, `lib/services/financial_core/lpp_calculator.dart`, `lib/services/financial_core/tax_calculator.dart`, `lib/services/memory/coach_memory_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/report_persistence_service.dart`, `lib/services/slm/slm_download_service.dart` …

### LOT-13 hubs/éducation/rapport
- Écrans : `screens/explore/explorer_screen.dart`, `screens/explore/explore_hub_screen.dart`, `screens/education/comprendre_hub_screen.dart`, `screens/education/theme_detail_screen.dart`, `screens/advisor/financial_report_screen_v2.dart`, `screens/confidence/confidence_dashboard_screen.dart`, `screens/timeline_screen.dart`
- Nourriciers à joindre (16) : `lib/models/budget_snapshot.dart`, `lib/models/circle_score.dart`, `lib/models/financial_report.dart`, `lib/providers/budget/budget_provider.dart`, `lib/providers/mint_state_provider.dart`, `lib/services/confidence/enhanced_confidence_service.dart`, `lib/services/e2e_runtime_flags.dart`, `lib/services/financial_report_service.dart`, `lib/services/navigation/mint_nav.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/pdf_service.dart`, `lib/widgets/common/mint_empty_state.dart`, `lib/widgets/confidence/confidence_breakdown_chart.dart`, `lib/widgets/mint_shell.dart`, `lib/widgets/premium/mint_entrance.dart`, `lib/widgets/premium/mint_surface.dart`

### LOT-14 nettoyage (orphelins+debug)
- Écrans : `screens/anonymous/anonymous_chat_screen.dart`, `screens/document_scan/document_stream_result_screen.dart`, `screens/admin/admin_shell.dart`, `screens/admin/mint_debug_spine_screen.dart`, `screens/admin/routes_registry_screen.dart`, `screens/coach/chat_as_verb_demo_screen.dart`, `screens/debug/debug_budget_bootstrap_screen.dart`, `screens/debug/debug_mint2_account_claim_screen.dart`, `screens/debug/debug_profile_bootstrap_screen.dart`, `screens/waitlist/waitlist_screen.dart`, `screens/about_screen.dart`
- Nourriciers à joindre (32) : `lib/domain/budget/budget_inputs.dart`, `lib/models/document_event.dart`, `lib/models/minimal_profile_models.dart`, `lib/models/serialized_card_context.dart`, `lib/providers/auth_provider.dart`, `lib/providers/coach_profile_provider.dart`, `lib/providers/waitlist_provider.dart`, `lib/services/account_handoff_service.dart`, `lib/services/anonymous_session_service.dart`, `lib/services/auth_service.dart`, `lib/services/coach/chat_tool_dispatcher.dart`, `lib/services/coach/coach_chat_api_service.dart`, `lib/services/coach/coach_profile_seeds.dart`, `lib/services/coach/conversation_store.dart`, `lib/services/coach/eclairage_models.dart`, `lib/services/coach_llm_service.dart`, `lib/services/commitment_service.dart`, `lib/services/debug/mint_debug_spine_service.dart`, `lib/services/debug_profile_bootstrap_service.dart`, `lib/services/document_understanding_result.dart`, `lib/services/feature_flags.dart`, `lib/services/install_lifecycle_service.dart`, `lib/services/navigation/safe_pop.dart`, `lib/services/premier_eclairage_selector.dart`, `lib/services/report_persistence_service.dart` …

## 6. Top-10 écrans les plus défectueux (score statique 12D)

| # | Écran | Score | Défauts |
|---|---|---|---|
| 1 | screens/expat_screen.dart | 37 | num-littéraux, hardcodé-FR, perf, lucidité-0, sans-millésime |
| 2 | screens/independants/dividende_vs_salaire_screen.dart | 37 | num-littéraux, hardcodé-FR, calc-local-sans-core, lucidité-0, sans-millésime |
| 3 | screens/onboarding/mvp_wedge/onboarding_shell_screen.dart | 33 | num-littéraux, hardcodé-FR, lucidité-0, sans-millésime |
| 4 | screens/document_scan/document_scan_screen.dart | 31 | num-littéraux, hardcodé-FR, sans-millésime, print-debug |
| 5 | screens/independant_screen.dart | 31 | num-littéraux, hardcodé-FR, perf, ds-drift, lucidité-0, sans-millésime |
| 6 | screens/disability/disability_insurance_screen.dart | 27 | num-littéraux, hardcodé-FR, lucidité-0, sans-millésime |
| 7 | screens/first_job_screen.dart | 24 | num-littéraux, hardcodé-FR, calc-local-sans-core, perf, lucidité-0, sans-millésime |
| 8 | screens/anonymous/anonymous_chat_screen.dart | 21 | route, num-littéraux, hardcodé-FR, perf, lucidité-0, sans-millésime, print-debug |
| 9 | screens/slm_settings_screen.dart | 19 | num-littéraux, perf, ds-drift, lucidité-0, sans-millésime |
| 10 | screens/unemployment_screen.dart | 19 | num-littéraux, calc-local-sans-core, perf, ds-drift, lucidité-0, sans-millésime |

## 7. Limites de la passe statique

- Heuristiques regex : les comptes hardcodé/numérique sont des planchers-indicateurs, pas des verdicts ; chaque site cité doit être relu en passe Codex (faux positifs possibles : clés, labels de debug, formats).
- 66+ navigations non-littérales (variables) non résolues arête-par-arête — passent par ScreenRegistry (🟡).
- La justesse des articles de loi cités (dimension 6) n'est PAS tranchée ici — file d'attente mint-swiss-brain.
- D7 cibles tactiles : seuls `MaterialTapTargetSize.shrinkWrap`, `VisualDensity.compact` et `iconSize<20` sont détectés ; les `Container(width:36)` tappables (ex. `debt_ratio_screen.dart:574`) échappent au scan — passe Codex/design requise.
- D8 : `setState` appelé DANS build() non résolu statiquement (comptes setState fournis en données brutes) ; jank réel = profil runtime.
- D9 : lints `prefer_mint_*` exécutés depuis le sha figé (baselines régénérées pour inventaire complet) ; le drift majeur vit dans `lib/widgets/**` (355 fontSize au total lib/ vs 55 dans screens/) — les nourriciers des lots Codex portent donc l'essentiel de la dette DS.
- D10/D11 : « affiche un chiffre » approximé par (littéraux numériques OU financial_core OU api_service) ; l'appareil de confiance peut vivre dans un widget nourricier (ex. `confidence_score_card`) — vérifier par lot avant verdict.
- D12 : scan du fichier écran seul ; les services nourriciers (logs backend, Sentry breadcrumbs) sont à couvrir dans la passe Codex par lot.
- Runtime (Phase 2) requis pour : états L/E/V réels, contenus servis par backend/financial_core (`RT`), atteignabilité effective des 🟡.
