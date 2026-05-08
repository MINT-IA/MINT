---
name: MVP-ONBOARDING-V2-AUTH-FIRST — perimeter STUB
description: 6-step OTP-style onboarding pour user authenticated landing direct sur /coach/chat (le trou architectural identifié par O5 panel adversarial QA). Aligné MINT v2 PDF (italique Gambarino, eyebrow numéroté, 1 idée / micro-step, anti-promiscuous sub). Effort ~2 j post MVP-FONTS-TOKENS-V2.
type: decision
date: 2026-05-08
status: STUB (à ouvrir post MVP-FONTS-TOKENS-V2 livré)
related:
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md
  - .planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md
sources:
  - MINT Design System.pdf (5 pages, identité v2 verrouillée)
  - 6-agent panel synthesis 2026-05-08 (a39705af9 / a6f345199 / a26e15301 / abb4b4669 / ad1459c2e / aeee85dbf)
  - PR #529 hotfix bundle B1-B6 mergé (foundation post-login coach plumbed correctly)
---

# MVP-ONBOARDING-V2-AUTH-FIRST — STUB

## Goal

Fermer le trou architectural identifié par O5 (adversarial QA panel) :
> Le `/onb` 8-step shell est `RouteScope.public` (anon path). Quand un user authentifié atterrit sur `/coach/chat` direct (post magic-link / login), il tombe sur un coach vide avec free-text greeting → archetype default empty → FATCA bypass + token waste + UX cassé.

Solution : 6 micro-steps OTP-style onboarding sous `apps/mobile/lib/screens/onboarding/auth_first/`, chacun aligné MINT v2 grammar (1 idée / écran, italique Gambarino, eyebrow numéroté, sub anti-promiscuous, CTA simple).

## Séquence onboarding (locked per panel synthesis)

| # | Eyebrow | Hero italique Gambarino | Sub Supreme | Input | Saved field |
|---|---|---|---|---|---|
| **01** | INTENTION | « Qu'est-ce qui t'amène ? » | « Une raison qui t'a fait télécharger MINT. » | 6 chips life-event | `primaryFocus` |
| **02** | PROFIL | « Tu es né quand ? » | « Pour calibrer ton plan. Rien d'autre. » | 4-digit OTP picker | `birthYear` |
| **03** | PROFIL | « Tu vis où ? » | « Pour les règles fiscales et la LPP. » | Canton picker (26) | `canton` |
| **04** | PROFIL | « Tu fais quoi ? » | « Pour adapter le coach à ta situation. » | 3 chips + conditionnel nationalité/permis | `employmentStatus` + `nationality` + `residencePermit` |
| **05** | PROFIL | « Combien tu gagnes (à peu près) ? » | « Une fourchette suffit. On affinera ensemble. » | 5 brackets (<4k / 4-7k / 7-10k / 10-15k / >15k CHF/mois) | `incomeBracket` |
| **06** | ÉCLAIRAGE | « Voilà ce qu'on voit. » | « Premier chiffre. Confiance basse, à clarifier. » | Premier Éclairage card | `firstInsightShown: true` |

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — 8 archetype scenarios par O5 | Maestro `walker_archetype_compound.yaml` |
| G2 | device par Julien sur TestFlight v2.13.0+ | confirmation device |
| G3 | dev CI — flutter analyze + 5 nouveaux widget tests + golden tests par step | run green |
| G4 | regression — promptfoo `archetype_detection_freetext.yaml` + `fatca_3a_no_recommendation.yaml` (per O5 #1+#5) | promptfoo CI |
| G5 | LSFin/accent/ARB — 30 nouvelles ARB keys × 6 langs + banned-terms lint | banned_terms_arb.py + sentence_subject_arb_lint.py exit 0 |

## Architecture

**Path** : `apps/mobile/lib/screens/onboarding/auth_first/` (nouveau dossier, distinct de `mvp_wedge/` qui est anon `/onb`)

**Routes** (GoRouter — ajout dans `app.dart` routes block) :
- `/onboarding/intent` → step 01
- `/onboarding/profil/age` → step 02
- `/onboarding/profil/canton` → step 03
- `/onboarding/profil/statut` → step 04
- `/onboarding/profil/revenu` → step 05
- `/onboarding/eclairage` → step 06

**Redirect** : `app.dart:283-301` ajout `if (isLoggedIn && !coachProfile.hasMinimumViableFacts) return '/onboarding/intent'`. `hasMinimumViableFacts` = nouveau getter sur `CoachProfile` = (intent != null && birthYear != null && canton != null).

**Reuse maximal** :
- `_AgePicker` ([apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:348-385](apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart))
- canton list ([:391-418](apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart))
- `_RevenueStep` slider — ADAPTER en 5 brackets (per O4 LSFin)
- `updateFromSmartFlow()` ([coach_profile_provider.dart:688](apps/mobile/lib/providers/coach_profile_provider.dart)) — déjà calcule archetype
- `FinancialPlanProvider` (B5 wire shipped via PR #525)
- `EnhancedConfidence` 4-axis ([SOT.md:82-92, 111](SOT.md))
- `MintTrameConfiance` ([widgets/trust/mint_trame_confiance.dart](apps/mobile/lib/widgets/trust/mint_trame_confiance.dart))
- **Tokens MINT v2** : `MintColors.mentheVive` (post MVP-FONTS-TOKENS-V2) + `MintTextStyles.displayGambarinoItalic*`

## Tâches breakdown (sub-perimeters atomic)

| # | Action | Effort |
|---|---|---|
| O1 | Create `apps/mobile/lib/screens/onboarding/auth_first/intent_screen.dart` (step 01) | 0.3j |
| O2 | `birthyear_screen.dart` (step 02) — 4-digit OTP picker (Gambarino italic match canvas) | 0.3j |
| O3 | `canton_screen.dart` (step 03) — canton picker reuse | 0.2j |
| O4 | `statut_screen.dart` (step 04) — 3 chips + conditional nationalité/permis reveal | 0.4j |
| O5 | `revenu_screen.dart` (step 05) — 5 brackets + skip lever | 0.3j |
| O6 | `eclairage_screen.dart` (step 06) — Premier Éclairage card avec EnhancedConfidence + MintTrameConfiance | 0.5j |
| O7 | New ARB keys (~30) × 6 langs (fr/en/de/es/it/pt) | 0.3j |
| O8 | Add 6 routes to `app.dart` GoRouter | 0.1j |
| O9 | Add post-login redirect to `app.dart:283-301` | 0.1j |
| O10 | Add `CoachProfile.hasMinimumViableFacts` getter | 0.1j |
| O11 | Add `incomeBracket` enum + extension to `CoachProfile` (FATCA-safe vs exact CHF) | 0.2j |
| O12 | 5 widget tests (1 per step) | 0.3j |
| O13 | Maestro walker_archetype_compound.yaml fixture (8 archetypes) | 0.3j |
| O14 | promptfoo archetype_detection_freetext.yaml + fatca_3a_no_recommendation.yaml | 0.3j |
| O15 | Sim run + Julien G2 device | 0.2j |

**Total estimé** : ~2.0-2.5 j post MVP-FONTS-TOKENS-V2 livré.

## Acceptance criteria (5 gates pass)

- ✅ G1 : sim walker passe les 8 archetype scenarios (per O5 #2)
- ✅ G2 : Julien teste sur device — onboarding ressenti « clean, clair, économise tokens » (vs avant)
- ✅ G3 : flutter analyze 0 issue + diff-cover ≥ 80% sur les 6 nouveaux screens
- ✅ G4 : promptfoo + Maestro CI green
- ✅ G5 : ARB parity 6/6 + banned_terms_arb 0 hit + sentence_subject_arb_lint passing

## Counter-arguments and data gaps

- **Risk 1** : 6 steps trop long ? Mitigation O2 + O6 : skip lever sur step 04+05, steps 01-03 obligatoires (3 questions minimum). Drop-off measurable post-launch via analytics.
- **Risk 2** : Step 06 Premier Éclairage = un LLM call cher dès le bout d'onboarding. Mitigation O3 : 1 turn cost ~$0.064 once profile populated, vs 5 turns × $0.064 = $0.32 actuellement → still net saving.
- **Risk 3** : Step 04 conditional reveal nationalité/permis casse « 1 idée / écran » règle. Mitigation : reveal animée smooth (200-300ms) signale au user que c'est une 2e étape liée, pas un nouveau screen.
- **Risk 4** : `incomeBracket` (5 buckets) au lieu d'exact CHF perd 50% de la précision. Mitigation : O4 LSFin contraint, on ne peut PAS demander exact en onboarding. Coach demande affinement post-Premier-Éclairage si user veut plus de précision.
- **Risk 5** : Goldens 6 langs × 6 screens × portrait/landscape × dark/light = 144 golden tests. Volume budget non chiffré.
- **Data gap** : Pas de A/B test prévu entre 6-step structuré vs current free-text. Mitigation : retention metrics post-launch (D1/D7/D30) sur cohort all-new vs cohort grandfathered.

## Dependencies

- **PR #529 mergé** (hotfix B1-B6) — provides clean coach foundation post-login
- **MVP-FONTS-TOKENS-V2 livré** — fournit Gambarino italic + Menthe-vive + dark palette nécessaires aux 6 screens

## Approval gate

À ouvrir comme PR séparée post-MVP-FONTS-TOKENS-V2. **Pas avant.**
