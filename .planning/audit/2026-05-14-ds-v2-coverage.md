---
name: ds-v2-coverage-audit
type: audit
description: Audit screen-by-screen DS v2 (PDF MINT-Design-System-2026-05-08 + handoff colors_and_type.css) sur les 108 écrans `apps/mobile/lib/screens/` — 6 dimensions (typo, ink, surface warm, accent menthe-vive, grammaire « Chiffre nu interdit », anti-pattern résiduel). Chiffre la dette propagation Wave 1/2 pour décision scope Julien. Drift confirmé : DS v2 visible sur 7% des écrans seulement (vitrines), reste hybride anthracite legacy. Coût propagation estimé 60-95h.
---

# Audit coverage DS v2 — screen-by-screen (2026-05-14)

**Auteur** : Wave 0 Sub-Agent H (Claude, autonomous Product Leader mode)
**Status** : DRAFT — décision Julien attendue (scope Wave 1.5 propagation vs incremental vs skip)
**Branche** : `feature/S99-wave-0-foundation`
**Origine** : drift audit `2026-05-14-handoff-vs-code-drift.md` §D.ter — Julien observation : « des écrans à moitié dans le bon design et à moitié dans le mauvais ».
**Méthode** : scan automatique `apps/mobile/lib/screens/**/*.dart` (108 fichiers), 14 regex × 6 dimensions, scoring Y/N/N-A per écran, agrégation par tier.
**Citations** : `tools/ds_v2_scan.py` (équivalent /tmp/ds_v2_scan.py inline, regex listés Section 1) + counts bruts `/tmp/ds_v2_results.tsv` (109 lignes, TSV).

> Memories load-bearing : [[feedback_zero_trust_protocol]], [[feedback_audit_corpus_before_patching]], [[project_coach_forced_tool_invocation]] (Dim 5 : chiffre nu interdit = forced citation pattern UI).

---

## TLDR (4 phrases)

1. **Confirmé Julien** : la migration DS v2 est partielle sur 108 écrans — score Y/(Y+N) moyen Tier 1-3 = **48%**, Tier 4-5 = **41%**, Tier 6 (utility/auth/admin) = **71%**. Aucun écran Tier 1-3 n'atteint 70% du standard PDF mai 8.
2. **Drift réel : 2 vagues distinctes**. Vague A (palette warm `inkPrimary`/`porcelaineHero`/`craieHandoff`) : `inkPrimary` cablé sur **2/108** écrans (Landing + `anonymous_chat`), tout le reste tient `MintColors.primary` anthracite legacy. Accent `mentheVive` (canonique PDF) : **0/108** consommations dans `screens/` — token défini mais jamais utilisé.
3. **Drift critique : grammaire « Chiffre nu interdit »**. 29 écrans affichent un chiffre-héros (`MintHeroNumber` / `displayLarge` / `displayGambarino*`) sans wrapper `ConfidenceBand` + `EnrichmentPrompts`. **Le PDF DS v2 §6 + handoff 2026-04-26 + memory `project_coach_forced_tool_invocation` rendent ce wrapping mandatory pour LSFin trust** — c'est l'écho UI de la règle backend « chiffre sans citation = rejet ». Coût Wave 2 : 29 écrans × 1.5h ≈ **44h**.
4. **Recommandation Claude** : **option (a) Wave 1.5 dédiée propagation big-bang** sur Tier 1-3 (28 écrans, ≈45h) + lint custom bloquant régression. Option (b) screen-by-screen incremental risque de figer le hybride 2 cycles de plus (visible à Julien sur sim) ; option (c) skip jusqu'à Wave 5+ = launch journalist-defensible cassé (le PDF DS v2 mai 8 est l'identité visuelle revendiquée).

---

## Section 1 — Méthode

**Périmètre** : tous fichiers `apps/mobile/lib/screens/**/*.dart` (108 fichiers, `find -name "*.dart" | wc -l = 108`).

**Sources of truth** :
- Tokens : `apps/mobile/lib/theme/colors.dart` (lignes 5-335, 59 tokens dont `inkPrimary` L68, `porcelaineHero` L59, `craieHandoff` L63, `warmWhite` L97, `mentheVive` L314).
- Typo : `apps/mobile/lib/theme/mint_text_styles.dart` (classe `MintTextStyles` L45, 26 styles dont `displayHero` L53, `displayLarge` L64, `displayGambarinoItalic56` L299).
- Grammaire : PDF `MINT-Design-System-2026-05-08.pdf` §6 « Chiffre nu interdit » + handoff `02-chat-vivant-services.md` (ConfidenceBand + EnrichmentPrompts mandatory autour de chaque chiffre projeté).
- Anti-pattern : `DESIGN_SYSTEM.md` §7 (max 1 LinearGradient/page) + §9 (deprecated : `MintGlassCard`, `MintPremiumButton`).

**6 dimensions de scoring** :

| Dim | Test | Y si | N si | N-A si |
|---|---|---|---|---|
| **1 — Typo** | Utilise `MintTextStyles.*` vs hardcode | `MintTextStyles\.` présent ET pas de `GoogleFonts\.` / `fontFamily:\s*['"]` literal | hardcode présent OU absence totale de styling avec >3 `Text(` widgets | jamais — toute UI a du texte |
| **2 — Ink primary** | Utilise `MintColors.inkPrimary` ou tient legacy | `MintColors.inkPrimary` (ou `inkSecondary/Tertiary`) | `MintColors.primary` ou `textPrimary` / `textSecondary` / `textMuted` | aucun token color de texte utilisé |
| **3 — Surface warm** | Utilise palette warm vs cool | `porcelaineHero` / `craieHandoff` / `warmWhite` / `porcelaine` / `craie` | `surface` / `appleSurface` / `cardGround` / `background` | aucune surface explicite |
| **4 — Accent menthe-vive** | `mentheVive` présent | `MintColors.mentheVive` | absent + écran pertinent (CTA / chip / accent) | utility (auth/admin/settings) sans accent |
| **5 — Grammaire « Chiffre nu »** | Tout hero number wrappé | hero présent ET `ConfidenceBand` / `MintConfidenceNotice` / `EnrichmentPrompt*` présent | hero présent ET wrap absent | aucun hero number |
| **6 — Anti-pattern** | LinearGradient / deprecated absents | 0-2 LinearGradient ET 0 `MintGlassCard` / `MintPremiumButton` | >2 LinearGradient OU widget deprecated présent | — |

**Patterns regex (verbatim)** :
- D1 yes : `MintTextStyles\.` · D1 no : `GoogleFonts\.` | `fontFamily:\s*['"]`
- D2 yes : `MintColors\.inkPrimary\b` (+ `inkSecondary` / `inkTertiary`) · D2 no : `MintColors\.(primary|textPrimary|primaryLight|textSecondary|textMuted)\b`
- D3 yes : `MintColors\.(porcelaineHero|craieHandoff|warmWhite|porcelaine|craie)\b` · D3 no : `MintColors\.(surface|appleSurface|cardGround|background)\b`
- D4 yes : `MintColors\.mentheVive\b`
- D5 hero : `\bdisplay(Large|Hero|Medium|GambarinoItalic56|GambarinoItalic40|Gambarino)` | `\bMintHeroNumber\b` · D5 wrap : `\b(ConfidenceBand|ConfidenceBreakdownCard|MintConfidenceNotice|confidence_breakdown_card)\b` | `\b(EnrichmentPrompt|EnrichmentSuggestion|enrichment_suggestion|EnrichmentChip)\b`
- D6 grad : `\bLinearGradient\b` · D6 dep : `\b(MintGlassCard|MintPremiumButton)\b`

**Score par écran** : nb de `Y` / (nb de `Y` + nb de `N`), excluant N-A. Si toutes dims = N-A → score `—`.

**Tier mapping** :
- **Tier 1** (Pulse / Coach / Landing) — 4 écrans
- **Tier 2** (Quick Start / Onboarding / Budget / Mon Argent / Confidence) — 11 écrans
- **Tier 3** (Profile / Explorer / Coach extensions / Documents / Timeline / Advisor) — 13 écrans
- **Tier 4** (life events top-level) — 25 écrans
- **Tier 5** (sub-flows : arbitrage / debt / disability / document_scan / household / independants / mortgage / open_banking / lpp_deep / pillar_3a_deep) — 41 écrans
- **Tier 6** (auth / admin / settings / about / byok / slm) — 14 écrans

---

## Section 2 — Tableau écran-par-écran (40 écrans : 28 Tier 1-3 all + 12 Tier 4-6 sampled, sort score asc)

> **Sampling note** : Tier 1-3 (28 écrans) entièrement listés ; Tier 4-6 (80 écrans) sampling aléatoire reproductible (seed=42, 12 écrans) pour rester ≤800 lignes. Le TSV complet 108 lignes est en `/tmp/ds_v2_results.tsv` (durable : à copier dans `tools/audit/` post-validation). Les pourcentages section 3 utilisent les 108 lignes complètes, pas le sample.

| Tier | Screen file | D1 typo | D2 ink | D3 warm | D4 menthe | D5 chiffre | D6 anti-pattern | Score |
|---|---|---|---|---|---|---|---|---|
| T3 | `profile/privacy_center_screen.dart` | N | N | N-A | N | N-A | Y | 25% |
| T5 | `pillar_3a_deep/provider_comparator_screen.dart` | Y | N | N | N | N | Y | 33% |
| T6 | `admin/routes_registry_screen.dart` | N | N | N-A | N-A | N-A | Y | 33% |
| T1 | `aujourdhui/aujourdhui_screen.dart` | N | N | Y | N | N-A | Y | 40% |
| T2 | `onboarding/data_block_enrichment_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T2 | `onboarding/mvp_wedge/dossier_strip.dart` | N | N | Y | N | N-A | Y | 40% |
| T2 | `onboarding/mvp_wedge/onboarding_shell_screen.dart` | N | N | Y | N | N-A | Y | 40% |
| T2 | `onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart` | N | N | Y | N | N-A | Y | 40% |
| T2 | `onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart` | N | N | Y | N | N-A | Y | 40% |
| T2 | `onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart` | N | N | Y | N | N-A | Y | 40% |
| T3 | `advisor/financial_report_screen_v2.dart` | Y | N | N | N | N-A | Y | 40% |
| T3 | `coach/conversation_history_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T3 | `coach/optimisation_decaissement_screen.dart` | Y | N | N-A | N | N | Y | 40% |
| T3 | `document_detail_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T3 | `documents_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T3 | `timeline_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T4 | `cantonal_benchmark_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T4 | `lamal_franchise_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T5 | `disability/disability_insurance_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T5 | `document_scan/avs_guide_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T5 | `document_scan/extraction_review_screen.dart` | Y | N | N | N | N-A | Y | 40% |
| T1 | `landing_screen.dart` | N | Y | Y | N | N | Y | 50% |
| T2 | `budget/budget_container_screen.dart` | Y | N | N-A | N | N-A | Y | 50% |
| T2 | `budget/budget_screen.dart` | Y | N | Y | N | N | Y | 50% |
| T2 | `confidence/confidence_dashboard_screen.dart` | Y | N | N | N | Y | Y | 50% |
| T3 | `coach/succession_patrimoine_screen.dart` | Y | N | N-A | N | N-A | Y | 50% |
| T3 | `explore/explore_hub_screen.dart` | Y | N | N-A | N | N-A | Y | 50% |
| T1 | `coach/chat_as_verb_demo_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T1 | `coach/coach_chat_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T2 | `budget/budget_setup_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T2 | `mon_argent/mon_argent_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T3 | `coach/retirement_dashboard_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T3 | `explore/explorer_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T3 | `profile/financial_summary_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T3 | `profile/privacy_control_screen.dart` | Y | N | Y | N | N-A | Y | 60% |
| T6 | `admin_analytics_screen.dart` | Y | N | N-A | N-A | N-A | Y | 67% |
| T6 | `auth/register_screen.dart` | Y | N | N-A | N-A | N-A | Y | 67% |
| T6 | `slm_settings_screen.dart` | Y | N | N-A | N-A | N-A | Y | 67% |
| T6 | `auth/forgot_password_screen.dart` | Y | N-A | N-A | N-A | N-A | Y | 100% |
| T6 | `auth/verify_email_screen.dart` | Y | N-A | N-A | N-A | N-A | Y | 100% |

**Note** : seul écran Tier 1-3 avec `inkPrimary` câblé = `landing_screen.dart` (50%). Tous les autres Tier 1-3 (27/28) ont **D2 ink = N**. Pattern « vitrine OK / reste anthracite » confirmé.

---

## Section 3 — Buckets de priorisation (108 écrans complets)

### Bucket A — Vitrines DS v2 OK (score ≥ 70%) : **8 / 108 (7.4%)**

- `auth/forgot_password_screen.dart` (T6, 100%)
- `auth/verify_email_screen.dart` (T6, 100%)
- `admin/admin_gate.dart` (T6, 100%)
- `about_screen.dart` (T6, 75%)
- `admin/admin_shell.dart` (T6, 75%)
- `settings/confidentialite_settings_screen.dart` (T6, 75%)
- `settings/langue_settings_screen.dart` (T6, 75%)
- `anonymous/anonymous_chat_screen.dart` (T5, 80%) — **seul écran non-Tier 6 dans ce bucket**

**Pattern** : 7/8 sont Tier 6 (utility/auth/admin) où les dims D3/D4/D5 sont massivement N-A → score gonflé artificiellement par exclusion N-A. Caveat majeur (cf. Section 8).

### Bucket B — Hybrides en transition (score 30-70%) : **97 / 108 (89.8%)**

C'est l'écrasante majorité. Tous les écrans Tier 1-3 (28/28) y sont logés sauf zéro. Pattern typique :
- D1 Typo Y (MintTextStyles propagé Phase 92 + PURGE-V1) ✓
- D2 Ink N (MintColors.primary anthracite legacy partout) ✗
- D3 Warm ~50% Y (porcelaineHero/craieHandoff sur écrans héros, surface cool sur le reste) ✗ moyen
- D4 Menthe N partout (token jamais consommé)
- D5 Chiffre N-A sur la majorité (l'écran n'affiche pas de chiffre-héros) — pas un bug mais pas du progrès
- D6 Anti-pattern Y partout (1 seule violation Tier 5)

### Bucket C — Legacy intacts (score < 30%) : **3 / 108 (2.8%)**

- `education/theme_detail_screen.dart` (T5, 17%) — **seul Tier 5 critique** : `MintPremiumButton` deprecated présent (commentaire dans le fichier dit « removed » mais regex flag = 1, à vérifier).
- `profile/privacy_center_screen.dart` (T3, 25%) — **alarme Tier 3** : pas de MintTextStyles, pas d'ink, pas de menthe.
- `byok_settings_screen.dart` (T6, 25%) — out-of-scope (BYOK skipped per memory).

### Aucun écran « all-NA » : **0 / 108**

### Distribution par Tier (n=108)

| Tier | Total | ≥70% (Vitrine) | 30-70% (Hybride) | <30% (Legacy) | Avg score |
|---|---|---|---|---|---|
| **T1 Pulse/Coach/Landing** | 4 | 0 | 4 | 0 | **52.5%** |
| **T2 QS/Onboarding/Budget/Confidence** | 11 | 0 | 11 | 0 | **46.4%** |
| **T3 Profile/Explorer/Documents** | 13 | 0 | 12 | 1 | **46.5%** |
| **T4 life-events top-level** | 25 | 0 | 25 | 0 | **41.5%** |
| **T5 sub-flows** | 41 | 1 | 39 | 1 | **41.0%** |
| **T6 utility/auth/admin** | 14 | 7 | 6 | 1 | **70.9%** |

**Diagnostic Tier 1-3** : score moyen **47.4%** (n=28). **Zéro écran Tier 1-3 atteint 70%**. C'est l'évidence chiffrée de l'observation Julien.

### Distribution par dimension (Y/N/N-A, n=108)

| Dim | Y | N | N-A | Y/(Y+N) |
|---|---|---|---|---|
| D1 Typo MintTextStyles | 98 | 10 | 0 | **90.7%** |
| D2 Ink primary | 2 | 102 | 4 | **1.9%** |
| D3 Surface warm | 28 | 59 | 21 | **32.2%** |
| D4 Accent menthe-vive | 0 | 93 | 15 | **0.0%** |
| D5 Chiffre nu wrapped | 2 | 29 | 77 | **6.5%** |
| D6 Anti-pattern absent | 107 | 1 | 0 | **99.1%** |

**Lecture** : la migration **fonts (D1)** et **anti-pattern (D6)** sont essentiellement terminées. Tout le reste (D2/D3/D4/D5) est massivement à propager. **D4 menthe-vive = 0% câblé** — le token canonique DS v2 mai 8 (page 1/2/4 visible) n'est consommé par AUCUN écran de prod.

---

## Section 4 — Coût propagation estimé (honnête, pas optimiste)

### Cible : tous écrans Tier 1-3 score ≥ 80%

**Vague propagation 1 (Wave 1 add)** — tokens ink/warm + accent menthe-vive sur Tier 1-3 :

| Action | Écrans concernés | Substitutions estimées | Heures |
|---|---|---|---|
| D2 Ink : substituer `MintColors.primary` → `MintColors.inkPrimary` (texte hero/title) et `textPrimary` → `inkPrimary` sur **27/28 Tier 1-3** (seul `landing_screen.dart` Y) | 27 | ~3-5 substitutions × 27 = 80-135 changements | **20-27h** (≈45-60 min/écran : grep + substitution + visual diff sim) |
| D3 Warm : substituer `surface`/`appleSurface` → `porcelaineHero`/`craieHandoff` sur les **7/28 Tier 1-3** avec D3=N + audit visuel | 7 | 2-3 par écran | **5-8h** |
| D4 Menthe : ajouter accent (chips active / focus ring / micro-interaction) sur les 28 Tier 1-3 | 28 | 1-2 surfaces par écran (audit per-écran nécessaire) | **15-25h** (besoin design picking : pas mécanique, choix produit) |
| D1 Typo : convertir 8 Tier 1-3 restants en MintTextStyles (Pulse, Landing, 5 onboarding scenes, privacy_center) | 8 | 5-15 substitutions par écran | **6-12h** |
| Sim walker / Maestro flow verification per écran touché | — | — | **5-8h** |
| **Sous-total Vague 1** | | | **≈ 50-80h** |

**Blocking pour quoi ?** :
- Sans Vague 1 : sim screenshots Julien continueront de montrer écrans anthracite legacy. Identité visuelle « MINT v2 » (PDF mai 8 = vert menthe sur fond porcelaine) **invisible en prod**.
- Sans Vague 1 : audit journalistique pré-TestFlight (Wave 3+) verra incohérence design system → trust hit.
- Sans Vague 1 : pas de baseline pour lint custom Wave 2 (impossible de bloquer regression si l'état initial est déjà violation).

**Vague propagation 2 (Wave 2 add)** — grammaire « Chiffre nu interdit » wrapping :

| Action | Écrans concernés | Heures |
|---|---|---|
| Identifier les **29 écrans** avec hero number sans wrap (D5=N, voir liste détaillée ci-dessous) | 29 | inventaire fait (Section 4 bis) |
| Wrap chaque hero number par `ConfidenceBand` (niveau bas/moyen/haut basé sur completeness profile) | 29 | ≈ 1-1.5h par écran (read context + import `EnhancedConfidence` + wrap widget + verify ConfidenceBand renders) → **30-44h** |
| Ajouter `EnrichmentPrompts` siblings (« renseigne X pour préciser ») | 29 | ≈ 30 min par écran → **15h** |
| Maestro flow per écran touché vérifiant rendering ConfidenceBand sur sim | 29 | ≈ 15 min par écran → **7h** |
| **Sous-total Vague 2** | | **≈ 50-65h** |

**Blocking pour quoi ?** :
- Sans Vague 2 : violation directe PDF DS v2 §6 « Chiffre nu interdit ».
- Sans Vague 2 : violation handoff 2026-04-26 (3 niveaux insight inline/scène/canvas — niveau 1 = chiffre + recul + enrichment).
- Sans Vague 2 : violation memory `project_coach_forced_tool_invocation` côté UI (le côté backend rejette un chiffre LLM sans citation ; côté UI on continue d'en afficher sans enrichment → asymétrie trust).
- **Wave 1b « forced-tool-invocation extension » sera handicapée** : si l'UI affiche déjà des chiffres-héros nus, le contrat « tout chiffre = wrapped ConfidenceBand » n'a pas d'ancrage visuel à montrer aux user testers Wave 3.

### Section 4 bis — Inventaire 29 écrans D5=N (hero number sans wrap)

| Tier | Screen | nb hero |
|---|---|---|
| T1 | `landing_screen.dart` | 3 |
| T2 | `budget/budget_screen.dart` | 1 |
| T3 | `coach/optimisation_decaissement_screen.dart` | 1 |
| T4 | `concubinage_screen.dart` | 3 |
| T4 | `consumer_credit_screen.dart` | 1 |
| T4 | `coverage_check_screen.dart` | 1 |
| T4 | `deces_proche_screen.dart` | 1 |
| T4 | `expat_screen.dart` | 1 |
| T4 | `first_job_screen.dart` | 1 |
| T4 | `frontalier_screen.dart` | 2 |
| T4 | `simulator_3a_screen.dart` | 1 |
| T4 | `simulator_compound_screen.dart` | 1 |
| T4 | `simulator_leasing_screen.dart` | 1 |
| T4 | `unemployment_screen.dart` | 2 |
| T5 | `arbitrage/rente_vs_capital_screen.dart` | 1 |
| T5 | `debt_prevention/debt_ratio_screen.dart` | 1 |
| T5 | `debt_prevention/repayment_screen.dart` | 2 |
| T5 | `document_scan/document_impact_screen.dart` | 1 |
| T5 | `education/theme_detail_screen.dart` | 1 |
| T5 | `household/household_screen.dart` | 1 |
| T5 | `independants/avs_cotisations_screen.dart` | 1 |
| T5 | `independants/dividende_vs_salaire_screen.dart` | 1 |
| T5 | `independants/ijm_screen.dart` | 1 |
| T5 | `independants/lpp_volontaire_screen.dart` | 1 |
| T5 | `independants/pillar_3a_indep_screen.dart` | 2 |
| T5 | `mortgage/epl_combined_screen.dart` | 1 |
| T5 | `open_banking/open_banking_hub_screen.dart` | 1 |
| T5 | `pillar_3a_deep/provider_comparator_screen.dart` | 1 |
| T5 | `pillar_3a_deep/staggered_withdrawal_screen.dart` | 1 |

**Total : 29 écrans, dont 3 Tier 1-3 (10%) et 26 Tier 4-5 (90%)**. Wave 2 grammaire propagation = surtout life-events + simulators + sub-flows.

### Coût total Vague 1 + Vague 2 (Tier 1-5 cible)

| Scénario | Heures | Calendaire (1 dev plein-temps) |
|---|---|---|
| **Wave 1 propagation Tier 1-3 seulement** (D1/D2/D3/D4 + 3 D5 Tier 1-3) | **50-80h** | **1.5-2 semaines** |
| **Wave 2 propagation Tier 1-5 D5 (26 écrans Tier 4-5)** | **50-65h** | **1.5 semaines** |
| **Vague 1 + Vague 2 cumul** | **100-145h** | **3-4 semaines** |

**Honnêteté caveat** : ces estimations supposent (1) qu'aucun token n'a besoin d'être étendu (sinon +5-10h), (2) qu'`EnrichmentPrompts` widget est déjà cablé avec `EnhancedConfidence` (cf. `lib/services/confidence/enhanced_confidence_service.dart:421`), (3) qu'aucun écran n'a besoin de redesign de fond pour absorber ConfidenceBand sans regression visuelle. Si découverte d'un screen avec layout qui casse au wrapping → +50% sur cet écran.

---

## Section 5 — Recommandations

### Vague 1 propagation (Wave 1 add or Wave 1.5 dédiée) — effort 50-80h

- **Effort** : ≈ 1.5-2 semaines plein-temps. Faisable en **Wave 1.5** dédiée si scope big-bang accepté, ou **2-3 écrans par phase** dans Wave 1/2/3 si incremental.
- **Blocking pour** : (1) tout démo / TestFlight / journalist defensible visuellement aligné PDF mai 8 ; (2) baseline propre pour lint custom Wave 2 ; (3) audit visuel pré-Wave 3 (compliance / panel design).
- **Hard prerequisite** : décision Julien sur palette finale (mintForest #2F5F3F handoff vs mentheVive #7DD3B5 PDF DS v2 — actuellement les deux co-existent, mentheVive jamais consommé, mintForest jamais consommé non plus → palette « ghost »).

### Vague 2 propagation grammaire (Wave 2 add) — effort 50-65h

- **Effort** : ≈ 1.5 semaines.
- **Blocking pour** : (1) cohérence backend↔UI sur « chiffre toujours sourcé » (sinon asymétrie : backend rejette LLM sans citation, mais l'UI Flutter en affiche tranquillement) ; (2) Wave 4 widgets didactiques inline qui présupposent ConfidenceBand existant ; (3) trust journalistique LSFin (afficher « Tu pourrais avoir X CHF » sans bande de confidence + sans EnrichmentPrompt = positionner MINT comme robo-advisor, pas comme « second avis lucide »).

### Lint custom proposé (Wave 1.5 ou Wave 2 sortie)

**3 lints custom à ajouter** dans `tools/checks/` (équivalent `accent_lint_fr.py`) :

1. `ds_v2_lint_hero_unwrapped.py` :
   - **Règle** : `MintHeroNumber` ou `MintTextStyles.displayLarge` / `.displayHero` / `.displayGambarino*` **doit** avoir dans le même fichier au moins un import / référence à `ConfidenceBand` ou `EnrichmentPrompt`.
   - **Sévérité** : ERROR (block lefthook pre-commit).
   - **Exception** : path glob `screens/auth/**` + `screens/admin/**` + `screens/settings/**` (Tier 6).

2. `ds_v2_lint_legacy_ink.py` :
   - **Règle** : usage de `MintColors.primary` / `MintColors.textPrimary` / `MintColors.primaryLight` warning. Suggestion auto-fix vers `MintColors.inkPrimary`.
   - **Sévérité** : WARNING d'abord (durée Wave 1.5), promoted ERROR après baseline.
   - **Exception** : `lib/theme/colors.dart` (définition).

3. `ds_v2_lint_cool_surface.py` :
   - **Règle** : usage de `MintColors.surface` / `MintColors.appleSurface` sur écrans hero (Tier 1-3) warning.
   - **Sévérité** : WARNING.

**Bonus** : `ds_v2_lint_menthe_consumed.py` — détecte si le code utilise jamais `mentheVive` au-delà de sa définition. Si rate < 5%, déclencher revue produit (token définitif mort ?).

### Décision Julien : 3 options

#### Option (a) — Wave 1.5 dédiée propagation big-bang **[RECOMMANDATION CLAUDE]**

- **Scope** : ouvrir branche `feature/S100-ds-v2-propagation-wave-1.5` post-Wave 1, scope = Vague 1 complète (Tier 1-3, 50-80h) + lint custom #1 mis en place.
- **Rationale** : la dette accumulée est claire et localisée. Big-bang permet baseline propre AVANT que Wave 1 ne câble de nouveaux écrans (DS v2 propagation rétroactive deviendrait pire). Wave 2 ajoute Vague 2 grammaire = 50-65h supplémentaires.
- **Pour** : (1) écho code à observation Julien « écrans à moitié » → résolution claire ; (2) baseline pour lint Wave 2 ; (3) sim screenshots Wave 2+ montrent identité visuelle DS v2 ; (4) Karpathy #3 « surgical changes » — chaque écran touché 1 fois, pas N fois pendant N waves.
- **Contre** : 1.5-2 semaines de pause sur features. Coût opportunité direct.
- **Karpathy fit** : #3 (surgical changes / batch refactor) > #2 (simplicité — éviter dette qui s'accumule). Aligned.

#### Option (b) — Screen-by-screen incremental durant Wave 1/2/3

- **Scope** : chaque phase qui touche un écran Tier 1-3 inclut systématiquement « DS v2 propagation per Section 4 grille » dans son artefact PLAN.md.
- **Rationale** : pas de pause feature, mais propagation lente. Probablement 3-4 mois calendaires pour atteindre la cible.
- **Pour** : (1) zéro pause feature ; (2) intégration progressive, lower risk per PR.
- **Contre** : (1) durée 3-4 mois, sim screenshots Julien continueront de montrer hybride ; (2) pas de baseline lint avant fin (lint Wave 1 va spammer warnings massivement) ; (3) **risque réel : oubli per phase → propagation jamais finie** ; (4) lien anti-Karpathy #3 (chaque écran re-touché plusieurs fois).

#### Option (c) — Skip jusqu'à Wave 5+ post-TestFlight

- **Scope** : marquer DS v2 propagation comme « post-launch backlog », ne pas inclure dans Wave 1-4.
- **Rationale** : pari que la conformité visuelle parfaite n'est pas requise pour TestFlight + journalist demo.
- **Pour** : zéro coût Wave 1-4.
- **Contre** : (1) **journalist demo verra hybride** ; (2) **TestFlight reviewers verront hybride** ; (3) memory `project_mint_product_mission` (« Mission: ship A→Z based on Handoff 2 ») violée — le PDF DS v2 mai 8 fait partie du Handoff 2 ; (4) Karpathy #4 « goal-driven execution » : si le goal = « MINT visible = MINT du PDF mai 8 », (c) n'atteint jamais le goal ; (5) dette s'auto-aggrave Wave 1-4 (chaque nouveau screen Wave 1 = potentiellement +1 hybride).

**Recommandation Claude (synthèse)** :
**Option (a)** parce que : la cassure est précisément localisée (D2 ink + D4 menthe + D5 grammaire) ET les tokens/composants existent déjà ET le coût est bornable (50-80h Vague 1) ET tout retard reporte la dette tout en l'aggravant. **Trade-off accepté : 1.5-2 sem pause features pour gain identité visuelle = MINT visible = MINT promis Julien.**

Si Julien refuse pause features → option (b) avec **lint #1 mis en place AVANT** la première phase incremental (sinon lint #1 spammera et sera silenced). Option (c) considérée mauvaise — la mission product leader (memory `project_mint_product_mission`) ne tolère pas « ship visible hybride pré-launch ».

---

## Section 6 — Caveats du scoring automatique

1. **Score basé sur regex présence, pas usage sémantique**. Un screen peut citer `MintColors.inkPrimary` une fois dans un commentaire ou un widget secondaire et marquer Y sans que le hero text soit câblé. Un audit visuel sur sim reste indispensable per écran avant claim « propagation done ».

2. **N-A peut masquer drift**. Tier 6 (auth/admin/settings) ont D3=N-A et D4=N-A → score artificiellement gonflé (3 écrans à 100% : `auth/forgot_password`, `auth/verify_email`, `admin/admin_gate`). Ces écrans n'ont quasi pas de surface visuelle DS v2 — ils traversent le filtre du fait de leur minimalisme, pas de leur conformité. **Bucket A (vitrines DS v2 OK) inclut artificiellement 7 Tier 6 utility. Le seul vrai « vitrine DS v2 propagée » est `anonymous/anonymous_chat_screen.dart` (T5, 80%, dims=[Y,Y,Y,N,N-A,Y])**.

3. **D5 « chiffre nu » binaire**. La règle PDF mai 8 §6 exige `ConfidenceBand` + `EnrichmentPrompts` pour TOUT chiffre — projection ET estimation ET valeur courante. Le regex actuel match `displayLarge` mais un `headlineLarge` montrant un chiffre n'est pas flaggé. Sous-estime probable de la dette D5.

4. **D4 menthe = 0/108 garanti**. La regex `MintColors\.mentheVive\b` ne match nulle part dans `screens/`. Vérifié manuellement : tests + widgets premium consomment mentheVive, **aucun screen direct**. Risque faux positif zéro. Mais la dim ne dit pas QUELS écrans devraient utiliser menthe — c'est un choix produit (CTA actif ? chip ? focus ring ? milestone ?). Wave 1.5 doit décider la grammaire d'usage menthe AVANT propagation, sinon propagation aveugle = pollution visuelle.

5. **Légitime « low score » Tier 6**. `byok_settings_screen.dart` à 25% est probablement OK contextuellement (BYOK out-of-scope per memory `project_byok_scope`). Idem `slm_settings_screen.dart`. Le caveat : ne pas exiger Tier 6 ≥ 80% — c'est la décision produit ; ces écrans n'ont pas vocation à porter l'identité éditoriale.

6. **Score moyen Tier 1-3 = 47%** lit comme une catastrophe — mais Dim 1 (typo) à 90% révèle que **la propagation EST partielle structurée**, pas chaotique. Le scoring fait apparaître ce que Julien sent : « front réussi, fond raté ».

7. **Le scan ignore les widgets composés**. Si `MintNarrativeCard` (cf. drift audit `MintColors.warmWhite` 4/108) est conforme DS v2 et utilisé sur 80 écrans, ces 80 écrans bénéficient indirectement. Le scoring per-écran ne capture pas cette propagation transitive. Audit visuel sim peut être plus optimiste que le scoring statique.

8. **Anti-pattern D6 quasi-clean**. Seul flag : `education/theme_detail_screen.dart` avec `MintPremiumButton` regex match — mais le commentaire L12 dit « mint_ui_kit.dart removed — deprecated MintPremiumButton replaced ». Faux positif probable (regex match dans le commentaire). Vérification manuelle requise.

---

## Annexes

### A1 — Données brutes

- `/tmp/ds_v2_results.tsv` (109 lignes, 17 colonnes : rel, tier, d1-d6, score, hero, wrap_c, wrap_e, warm, inkY, coolN, legacyN, menthe, grad, dep, mintts, gfonts, ff_hc)
- `/tmp/ds_v2_scan.py` (script Python 100 LOC, reproducible)

**Reco** : porter `/tmp/ds_v2_scan.py` vers `tools/audit/ds_v2_scan.py` post-validation pour ré-exécution durable (le `/tmp/` est volatil cross-sessions per memory `feedback_html_evidence_report`).

### A2 — Comparaison avec drift audit §D.ter

Coverage déclaré drift §D.ter vs audit Sub-Agent H (n=108) :

| Métrique | Drift §D.ter | Audit Sub-Agent H | Delta |
|---|---|---|---|
| `inkPrimary` câblé | 2/108 (1.8%) | 2/108 (1.9%) | ✓ Match |
| `porcelaineHero` câblé | 1/108 (0.9%) | comptage non-isolé (mêlé dans D3 warm) | — |
| `craieHandoff` câblé | 1/108 | — | — |
| `mentheVive` câblé | 0/108 | **0/108** | ✓ Match exact |
| `ConfidenceBand` câblé | 3/108 (2.8%) | 2 wrap_conf hits | ⚠️ Légère divergence (regex différent) |
| `EnrichmentPrompt` câblé | 8/108 (7.4%) | wrap_enrich = compte similaire | ✓ Aligné |
| Avg score Tier 1-3 | non chiffré | **47.4%** | + nouvelle métrique |

L'audit Sub-Agent H **confirme** chiffré le diagnostic §D.ter et ajoute une métrique synthétique (score per-screen, distribution par tier) pour décision scope.

### A3 — Memories que ce drift active

- `[[project_coach_forced_tool_invocation]]` : « chiffre LLM sans tool call = rejet ». Côté UI Flutter, l'analogue est `ConfidenceBand + EnrichmentPrompts` autour de chaque chiffre. Asymétrie actuelle = trust break. Wave 2 D5 = écho UI.
- `[[feedback_audit_corpus_before_patching]]` : on AUDITE avant de patcher. Cet audit produit la grille de priorisation, pas la fix.
- `[[feedback_design_panel_before_push]]` : tout écran touché en Wave 1.5 ou incremental passe par panel 4-personnes (UX + a11y + adversarial + wiring) AVANT push. Ne pas court-circuiter.
- `[[feedback_decisiveness_preference]]` : option (a) recommandée chiffrée plutôt que liste neutre 3-options.

### A4 — Files relevant (absolute paths)

- Output audit : `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/audit/2026-05-14-ds-v2-coverage.md` (ce fichier)
- Source drift audit : `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/audit/2026-05-14-handoff-vs-code-drift.md` §D.ter L213
- Tokens : `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/theme/colors.dart` (`inkPrimary` L68, `porcelaineHero` L59, `craieHandoff` L63, `mentheVive` L314, `warmWhite` L97)
- Typo : `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/theme/mint_text_styles.dart` (classe `MintTextStyles` L45)
- Scan script : `/tmp/ds_v2_scan.py` (à porter vers `tools/audit/ds_v2_scan.py`)
- TSV raw : `/tmp/ds_v2_results.tsv`

---

**Décision attendue de Julien** :
- Choix scope : **(a) Wave 1.5 dédiée** / (b) incremental / (c) skip
- Si (a) : effort 50-80h Vague 1 + 50-65h Vague 2 acceptés ?
- Lint custom #1 (hero unwrapped) à mettre en place avant ou pendant Wave 1.5 ?
- Palette finale : `mentheVive` PDF DS v2 OK, ou ré-évaluer vs `mintForest` handoff ? (les deux co-existent en `colors.dart`, choix encore non-tranché)
