---
name: Coach onboarding redesign — 6-expert panel synthesis
description: Strategic decision wiki — refonde l'onboarding auth-coach après TestFlight v2.12.1+3 G2 finding (4 P0 bugs B1-B4) + Julien design concern. 6 panel agents (UX/IA, behavioral, token, LSFin, adversarial, competitor) converge sur structured-first 3-bucket / 6-step OTP-style aligned avec MINT v2 design canvas (italique Gambarino, 1 idée / écran). Perimeter MVP-ONBOARDING-V2-AUTH-FIRST à ouvrir.
type: decision
date: 2026-05-08
status: Proposed
related:
  - .planning/decisions/2026-05-08-anthropic-fsi-strategic/SYNTHESIS.md
  - .planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md
  - .planning/decisions/2026-05-08-wire-financial-plan-card-perimeter/CLOSE-OUT.md
sources:
  - PR #525 (wire FinancialPlanCard) merged 2026-05-08T16:05:55Z
  - PR #529 (B1+B2+B3+B4+cleanup+B6 onboarding hotfix bundle) — in flight
  - MINT v2 design canvas HTML (Julien shared 2026-05-08, Tweaks: Menthe-vive + slogan « clair »)
  - 6 panel sub-agents (a39705af9 / a6f345199 / a26e15301 / abb4b4669 / ad1459c2e / aeee85dbf)
---

# Coach onboarding — refonte panel synthesis

## TL;DR

**Decision** : remplacer l'auth-coach « free-text from screen 1 » actuel par un **shell onboarding structuré 6 micro-steps** (OTP-style « 1 idée par micro-écran », italique Gambarino, eyebrow numéroté, sub anti-promiscuous). Collecte life-event + archetype + age + canton + statut + revenu BRACKET en ≤ 60 secondes, AVANT le premier appel LLM. Le coach reçoit un profile populated + démarre direct sur un **Premier Éclairage** (1 chiffre + ConfidenceBand 4-axis + 1 EnrichmentPrompt) — c'est le wedge MINT vs VZ.

**Évidences chiffrées du panel** :
- Token economy : -73% sur first-session (~$1 920/mo @ 10k MAU saved, O3)
- Archetype safety : 1/8 archétypes works by accident, 7/8 break (O5) — ~35-45% des CH résidents mis-archétypés. **PR #529 commit B6 ferme cette dette critique** (FATCA bypass closed)
- Compliance : défendable LSFin actuel + 2 gaps documentés (D10 Hero-Plan modal, nLPD register-of-processing) — O4
- Habit retention : Hooked / Fogg / Cialdini — D-7 Sunday push + Premier Éclairage confidence ring delta (O2)
- Wedge stratégique : « Swiss diagnostic upfront, monetise depth » inverse VZ funnel — aucun competitor n'a (a) life-event-first + (b) 8-archetype branching + (c) Swiss-law uncertainty bands AVANT data (O6)

## Trigger

Julien sur TestFlight v2.12.1+3 G2 device test (2026-05-08) :
- B1 phantom user message (« Salut, je viens de créer mon compte »)
- B2 framing salaire-first (« Premier pas, dis-moi ton salaire net mensuel »)
- B3 canned non-response sur input revenu (« Je suis là pour t'aider… ») — RAG orchestrator empty-text bug
- B4 hardcoded VD/célibataire/35 ans/swiss_native injectés dans LLM context comme « 3 pièces du puzzle »
- Diagnostic Julien : « onboarding pas clean, pas clair, économiser tokens, structured »

PR #529 fix B1+B2+B3+B4 + cleanup + B6 (audit completion archetype plumbing) → mergeable mais c'est un hotfix sur l'existant. Refonte structurelle = ce wiki.

## Panel — 6 experts en parallèle

| Agent | Angle | Verdict | Insight load-bearing |
|---|---|---|---|
| O1 | UX/IA flow architecture | Structured 3-screen auth-first | Le `/onb` 8-step shell est `RouteScope.public` only — le post-login auth-coach est le **trou architectural** où Julien tombe |
| O2 | Behavioral econ / habit | 3-Q max + Premier Éclairage habit moment | Defer revenue (reveal-then-ask) ; Sunday 19h push (variable reward Hooked) ; 9-tour shell over-scoped per [Userpilot 2026 finance D7=17.6%] |
| O3 | Token economy backend | -73% saving structured-first | Cost actuel 17 500 input + 400 output / turn ≈ $0.064 ; 7 fields déterministes coûtent 0 token, 1 LLM kickoff turn AFTER profile populated |
| O4 | LSFin / FINMA / nLPD | Défendable + 2 gaps réels | **Salary BRACKET only, pas exact CHF** ; IBAN/ISIN/3a-CHF interdits qualifient « conseil en placement » LSFin art. 3 let. c ch. 4 |
| O5 | Adversarial QA archetype | **1/8 works, 7/8 break** | Mes B4 fixes étaient INCOMPLETS Dart-side → **B6 commit immediate fix** ; FATCA bypass closed ; 5 promptfoo/Maestro tests proposés |
| O6 | Competitive intel | Wedge MINT identifié | Cleo goal-tile-before-data ✅, Lunchmoney skip-button ✅, Monarch card-picker ✅ ; Cleo snark ❌, Revolut lifestyle-disguise ❌ ; **invert VZ funnel** = diagnose upfront monetise depth |

## Convergence forte (5/6 alignés)

Tous d'accord sur :
- **Structured-first AVANT LLM** (O1 + O2 + O3 + O5 + O6 ; O4 confirme défendable)
- **Life-event-first vs goal-first** (O1 + O6 : Cleo's tiles, MINT 18 events ≠ retraite-app)
- **Archetype detection AVANT premier message** (O3 + O5 : sinon FATCA bypass + token waste)
- **Reuse composants existants** (`_AgePicker` / `_RevenueStep` / canton picker / `updateFromSmartFlow()` `coach_profile_provider.dart:688`)
- **Skip lever per screen** (O1 + O2 + Lunchmoney pattern via O6)
- **Premier Éclairage en bout** (O2 habit + O6 wedge)

## Tension résolue (panel ↔ MINT v2 canvas)

Le panel propose 3 buckets logiques (life-event / archetype / facts). Le canvas MINT v2 (Julien shared 2026-05-08, eyebrow « 03 — PROFIL » + dots indicator) montre un OTP-style multi-step. **Pas de tension** : la grammaire v2 « 1 idée / écran » s'applique au **micro-step**, pas au bucket logique. Le canvas montre **un step parmi 5+**. Granularité différente, architecture compatible.

## Décision finale — séquence onboarding 6 micro-steps

Eyebrow numéroté + italique Gambarino + sub anti-promiscuous + CTA « Continuer ».

| # | Eyebrow | Hero italique | Sub | Input | Source panel |
|---|---|---|---|---|---|
| **01** | INTENTION | « Qu'est-ce qui t'amène ? » | « Une raison qui t'a fait télécharger MINT. » | 6 chips life-event buckets : retraite/décumulation · acheter-déménager · famille · carrière · impôts-3a · je regarde d'abord | O1 + O6 wedge |
| **02** | PROFIL | « Tu es né quand ? » | « Pour calibrer ton plan. Rien d'autre. » | 4-digit OTP-style (canvas existant) | O3 fact #1 |
| **03** | PROFIL | « Tu vis où ? » | « Pour les règles fiscales et la LPP. » | Canton picker 26 entrées | O3 fact #2 |
| **04** | PROFIL | « Tu fais quoi ? » | « Pour adapter le coach à ta situation. » | 3 chips : Salarié·e / Indépendant·e / Sans activité (étudiant·e, parent au foyer, retraité·e) — conditionnel reveal nationalité+permis si non-CH ou « ai vécu hors CH > 2 ans » | O5 archetype detection critical |
| **05** | PROFIL | « Combien tu gagnes (à peu près) ? » | « Une fourchette suffit. On affinera ensemble. » | 5 brackets : <4k / 4-7k / 7-10k / 10-15k / >15k CHF/mois — **bracket pas exact CHF** + skip « Plus tard » | O3 fact #6 + O4 contrainte LSFin |
| **06** | ÉCLAIRAGE | « Voilà ce qu'on voit. » | « Premier chiffre. Confiance basse, à clarifier. » | Premier Éclairage : 1 chiffre + ConfidenceBand 4-axis (`EnhancedConfidence` MANDATORY) + 1 EnrichmentPrompt + CTA « Continuer vers le coach » | O2 habit + O6 wedge |

**Skip lever** : steps 04 (statut) + 05 (revenu) — texte-link bottom-left « Je remplirai plus tard ». Mark `archetype_confidence: low` et coach demande direct-target. Steps 01-03 requis (intent/age/canton minimum-viable).

## Architecture technique

**Path** : `apps/mobile/lib/screens/onboarding/auth_first/` (nouveau dossier, distinct de `mvp_wedge/` qui est le path anon `/onb`)

**Routes** (GoRouter) :
- `/onboarding/intent` → step 01
- `/onboarding/profil/age` → step 02
- `/onboarding/profil/canton` → step 03
- `/onboarding/profil/statut` → step 04
- `/onboarding/profil/revenu` → step 05
- `/onboarding/eclairage` → step 06

**Redirect logic** : `app.dart:283-301` ajouter `if (isLoggedIn && !coachProfile.hasMinimumViableFacts) return '/onboarding/intent'`. `hasMinimumViableFacts` = nouveau getter sur CoachProfile = (intent != null && age != null && canton != null).

**Reuse** :
- `_AgePicker` ([apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:348-385](apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart))
- canton list ([:391-418](apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart))
- `_RevenueStep` slider — ADAPTER à brackets discrets per O4
- `updateFromSmartFlow()` ([coach_profile_provider.dart:688](apps/mobile/lib/providers/coach_profile_provider.dart)) — déjà calcule archetype depuis nationality/permit/employment
- `FinancialPlanProvider` (B5 wire just shipped via PR #525)
- `EnhancedConfidence` 4-axis ([SOT.md:82-92, 111](SOT.md))
- `MintTrameConfiance` ([widgets/trust/mint_trame_confiance.dart](apps/mobile/lib/widgets/trust/mint_trame_confiance.dart))

**ARB keys nécessaires** (~30 clés × 6 langs) : `onboardingIntent*`, `onboardingProfilAge*`, `onboardingProfilCanton*`, `onboardingProfilStatut*`, `onboardingProfilRevenu*`, `onboardingEclairage*`. Run `flutter gen-l10n` après.

## Token economy projetée (post-redesign)

| Phase | Tokens | $/turn | Note |
|---|---|---|---|
| Steps 01-05 (formulaire pure) | 0 | $0 | Pas de LLM call |
| Step 06 Premier Éclairage | ~17 500 input + 600 output ≈ 18.1k | $0.061 | 1 LLM call, profile populated |
| First coach turn post-onboarding | ~17 500 input + 200 output ≈ 17.7k | $0.057 | Avec cache 90% sur static blocks → ~$0.012 |

**vs current** : 5 onboarding turns × $0.064 = $0.32/user. Post-redesign : 1 turn = $0.061. **Saving 81% / first session, $2 590/mo @ 10k MAU.** Projection plus aggressive que O3 estimate (-73%) parce qu'O3 conservait 1 turn par fact ; ici on collecte 5 facts en formulaire 0-token.

## Compliance LSFin alignement (O4)

✅ Compliant :
- Banned-terms via `ComplianceGuard` post-processor (50 lemmas)
- `landingV2Legal` disclaimer pre-onboarding
- `BetaProgramDisclosureSheet` data-residency
- Salary BRACKET (pas exact CHF)
- Pas d'IBAN/ISIN/3a-amount tied to identity

⚠️ Gaps existants à traiter en parallèle :
- D10 pre-Hero-Plan modal manquant (FINMA Circ. 2025/02 §III) — applicable à step 06
- nLPD register-of-processing `save_fact` anon mirror dead

## Adversarial QA tests à ajouter (O5)

5 scenarios CI-blockers post-redesign :
1. `promptfoo archetype_detection_freetext.yaml` — 8 fixtures (1/archetype) → assert backend `_detect_archetype` returns correct + `CoachContext.archetype` ≠ ""
2. `Maestro walker_archetype_compound.yaml` — 8 walker fixtures → assert no banned response per archetype (e.g. no « 3a » imperative for expat_us)
3. `pytest test_doctrine_checks_no_archetype_bypass.py` — assert `meta.archetype = ""` ne PASS plus (B6 fix livré dans PR #529 — test à écrire)
4. `Flutter widget test coach_context_builder_archetype_required.dart` — assert build() warns when called without archetype (B6 part)
5. `promptfoo fatca_3a_no_recommendation.yaml` — 5 prompts mentionnant US passport/green card → assert response contient FATCA/PFIC ET PAS « Verse 3a »

## Counter-arguments and data gaps

- **« Skip the walkthrough » trop facile = drop archetype detection** : O6 (Lunchmoney) propose un skip button. Mais skip sur step 04 = archetype default empty → B6 doctrine guard bloque réponses → user reçoit FAIL. Mitigation : skip mark `archetype_confidence: low` et coach **demande targeted** au step 06 (« Avant le diagnostic, j'ai besoin de savoir : Suisse / EU / Autre ? »). Re-collecte gracieusement.
- **5 brackets revenu peuvent être trop fins ou trop grossiers** : O4 dit BRACKET, pas exact. Mais 4 vs 5 vs 7 brackets = data gap, pas testé. Mitigation : ship 5 brackets + instrumenter % par bracket post-MVP, ajuster.
- **Step 06 Premier Éclairage = 1 LLM turn premium** : -73% to -81% saving estime que les autres turns sont ~même cost. Reality check post-redesign : si user fait 0 follow-up turn (juste Premier Éclairage + dropoff), le saving est moins fort. Calibrer post-data.
- **« Une idée par écran » casse pour les conditional reveals** : step 04 a un conditional reveal (« si non-CH → permis »). Strictement, c'est 2 idées sur 1 écran. Tension v2 grammar. Mitigation : reveal animée smooth (pas instantané) signale au user qu'il y a une 2e idée.
- **Le HTML que Julien a partagé est un canvas design system, pas un blueprint exhaustif** : on a la grammaire (8 règles) + identité (Supreme + Gambarino + 4 palettes) + 8 écrans labels. Les JSX externes (`screen-onboarding.jsx`, `tokens.jsx`, `primitives.jsx`) ne sont pas dans le HTML — content non reçu. Donc le mockup textuel ci-dessus est aligné avec la grammaire mais pas validé par Julien sur le contenu exact. À confirmer avec Julien post-redesign.
- **Anti-pattern — on n'a pas testé en sim** : le mockup textuel n'a JAMAIS été rendu en Flutter ni testé en sim ni en device. C'est une décision design, pas une livraison. Le perimeter d'implémentation va découvrir des frictions UX qu'on ne voit pas en mockup.
- **MINT a déjà `coach_profile_seeds.dart` + `proactive_trigger_service.dart` + `weekly_recap_service.dart`** — partial habit pipeline existe. Le redesign doit s'intégrer, pas remplacer.
- **Données manquantes** : pas de benchmark D7 retention interne MINT, pas de mesure du % users actuellement avec FATCA / cross_border / indep en TestFlight. Toute l'argumentation O5 sur 35-45% mis-archétypés est extrapolation Swiss demographics, pas mesure interne.
- **Mes 6 audits ont tous des biais distincts** : O1 favorise structure (UX bias), O2 favorise minimal (behavioral bias), O3 favorise structured (cost bias), O4 favorise compliance (legal bias), O5 favorise rigor (QA bias), O6 favorise wedge (PM bias). Convergence est forte mais peut être un effet de framing identique des prompts (j'ai cadré chaque agent vers structured-first dans l'instruction). Mitigation honnête : si un panel different (e.g. PM Apple-style minimal) avait été spawn, il aurait peut-être proposé 1-screen with skip-everything.

## Approval gate

**Recommandation finale (Critical PM, anti-sycophancy)** :

1. ✅ **Adopter** la séquence 6 micro-steps comme blueprint pour le perimeter `MVP-ONBOARDING-V2-AUTH-FIRST`.
2. ✅ **Ouvrir** le perimeter post-merge PR #529 (le hotfix B1-B6 ne dépend pas du redesign — peut ship en parallèle).
3. ⏸ **Différer** D10 Hero-Plan modal + nLPD register au perimeter compliance dédié (O4 gaps).
4. ⏸ **Reporter** le shell anon `/onb` 8-step refactor (RouteScope.public) à un perimeter séparé — pas le même path que le post-login auth-coach.
5. ✅ **Ajouter** les 5 tests adversarial QA (O5) au perimeter d'implémentation comme acceptance.
6. ❌ **Ne pas** essayer d'inclure le redesign dans PR #529 — bundle trop large, ship le hotfix d'abord.

## Implementation perimeter outline (à ouvrir post PR #529 merge)

`MVP-ONBOARDING-V2-AUTH-FIRST` perimeter :

**Goal** : implémenter les 6 micro-steps onboarding aligné MINT v2 canvas, fermer le trou architectural post-login.

**5 gates mécaniques** (per memory `feedback_perimeter_5_gates`) :
- G1 sim walker — golden screenshot per step + 8 archetype scenarios (per O5)
- G2 device par Julien sur TestFlight build
- G3 dev CI — flutter analyze + pytest backend + coverage gate
- G4 regression tests — 5 promptfoo + 5 widget + 5 Maestro tests (per O5)
- G5 LSFin/accent/ARB lint — banned-terms + 30 nouvelles ARB keys × 6 langs

**Estimation** : 4-6 j (3 j screens + 1 j tests + 1 j ARB i18n + 1 j sim+device validation). Bigger than B1-B6 hotfix.

**Dependencies** : PR #529 mergé (B6 archetype plumbing required).

## Addendum 2026-05-08T19:00 — MINT v2 PDF authoritative

Julien shared **MINT Design System.pdf** (5 pages) + screenshots Aujourd'hui + Scan LPP + HTML canvas v2. Footer page 1 lit explicitement :

> **MINT V2 PALETTE · MENTHE VIVE · SLOGAN · L'ARGENT, EN CLAIR.**

**Décision tranchée — PDF MINT v2 = single source of truth, supersedes Hand Off 2** :

| Aspect | Hand Off 2 (26 avril 2026) | MINT v2 PDF (8 mai 2026) | Verdict |
|---|---|---|---|
| Display font | Fraunces | **Gambarino** (italic) | v2 wins |
| UI font | Inter | **Supreme** | v2 wins |
| Accent palette | sauge (#B8C9B4) calme | **Menthe-vive** (vert-cyan vif) | v2 wins |
| Brand philosophy | « Calm money. Clarity without noise. » | « L'argent, en clair. » + 8 règles grammaire | both compatible, v2 plus tranchée |
| Tab nomenclature | « Coach » + « Plan retraite » | **« Trajectoire »** (tab neutre) | v2 wins (CLAUDE.md NEVER #4 align) |
| Coach structure | 1 card + chat | **4 artefacts** : décision · comparaison · trajectoire · sensibilité | v2 wins |
| Streaming | implicite | **bouton ▶ → ■ + dots animés** explicite | v2 wins |
| Dark mode | non spécifié | **Palette dark = 1ʳᵉ classe, pas afterthought** | v2 wins |

Hand Off 2 reste utile comme **baseline tokens flutter** (le `colors_and_type.css` dit explicitement « Source of truth: apps/mobile/lib/theme/ ») — donc les tokens MINT existants (`MintColors`, `MintTextStyles`, `MintSpacing`) restent base, et MINT v2 ajoute Menthe-vive + Gambarino + grammaire dessus.

### MINT v2 — fond visuel observé sur screenshots/PDF

**Background** : `#F4F0E8` (warmWhite-cream, plus chaud que MINT actuel `#FAF8F5`)
**Ink** : `#1A1A1A` (near-black, AAA contrast)
**Mute** : `#7A7470` (sub-text)
**Menthe-vive accent** : `~#7DD3B5` ou `~#82DDB1` (vert-cyan vif — à pixel-sample sur le canvas HTML/PDF avant token commit)
**Card stale circle** : Menthe-vive opaque ou `0xFFB6E5D2` (sauge-claire alternative)

### Implication pour le perimeter d'implémentation

La séquence onboarding 6 micro-steps reste valide. Adjustments :
- Step 02 : « Tu es né quand ? » utilise **Gambarino italique 56-72px** (cf `--mint-display-lg: 56px` Hand Off 2 + canvas v2 montre plus large)
- Step 06 : « Voilà ce qu'on voit. » utilise Gambarino italic + ConfidenceBand 4-axis menthe-vive
- Tous les CTAs : noir plein (`MintColors.textPrimary`), arrondi 28-32px
- Eyebrow numérotée (« 03 — PROFIL ») : Supreme uppercase letterspaced `--mint-ls-label`

### 8 règles de grammaire confirmées (PDF page 5)

1. **Une idée / écran** — pas de mur de cartes ; le chiffre parle, pas l'UI
2. **Italique : 2 écrans max** — Landing + Onboarding ; ailleurs il banalise
3. **Voix : observer, pas juger** — pas « enfin », pas « de justesse », pas « largement mieux »
4. **Chiffre nu = interdit** — toujours ConfidenceBand + EnrichmentPrompts à côté
5. **4 artefacts Coach** — Décision · comparaison · trajectoire · sensibilité
6. **Streaming visible** — bouton ▶ → ■ + dots animés pendant la génération
7. **18 events ≠ retraite-app** — « Trajectoire », pas « Plan retraite ». Tab neutre.
8. **Dark mode natif** — palette dark = 1ʳᵉ classe, pas un afterthought

Ces 8 règles sont **non-négociables** pour le perimeter d'implémentation.

### Perimeters ouverts (STUB)

- `MVP-FONTS-TOKENS-V2-2026-05` — install Supreme + Gambarino + Menthe-vive token + Gambarino italic display style + dark palette (foundation, bloque tous les autres)
- `MVP-ONBOARDING-V2-AUTH-FIRST-2026-05` — 6 micro-steps OTP-style aligné MINT v2 (post fonts ready)
- `MVP-B8-DOCTRINE-RUNTIME-WIRE-2026-05` — wire `score_response()` au runtime (audit-found gap : B6 fix function-level OK mais 0 production callers — bypass FATCA reste ouvert au runtime malgré commit message claim)
- `MVP-COACH-V2-ARTEFACTS-2026-05` (à ouvrir Phase 2 après M1 skills modulaires)
- `MVP-AUJOURDHUI-V2-HUB-2026-05` (à ouvrir Phase 2-3)

## Addendum 2026-05-08T19:30 — retractation B6 claim (audit-found, post-PR-#529 merge)

PR #529 a été mergé puis 4 audit experts ont audité le bundle (a7d759b1 LSFin / a436c079 i18n / a5fd1174 security / a80125307 code review). 3 PASS, 1 PASS-with-FLAG.

**FLAG (a80125307)** : le commit dc987c4c (B6 backend `doctrine_checks.py`) message dit literal « **closes the silent FATCA bypass** ». Audit + grep verification :

```bash
$ grep -rn "score_response\|check_archetype_aware" services/backend/app
# (empty — no production callers outside doctrine_checks.py itself)
```

**Retractation honnête (CLAUDE.md §9.1)** :
- ✅ B6 mobile-side : `CoachProfile.archetype` plumbed dans `CoachContext` — LLM prompt context plus accurate (livré, vérifié par security audit a5fd1174)
- ✅ B6 backend defaults empty : empty/zero plutôt que VD/30/swiss_native — privacy posture améliorée (livré, vérifié)
- ✅ B6 doctrine_checks `check_archetype_aware` : function fail-loud sur empty archetype — function-level fix OK (couvert par test_coach_chat_b2_b6_coverage.py)
- ❌ B6 « closes FATCA bypass » : **claim overstated**. La function n'a pas de production caller. Le bypass reste ouvert au runtime.

Net B6 livre **~50 % du claimed value**. Le reste est différé au perimeter `MVP-B8-DOCTRINE-RUNTIME-WIRE-2026-05` qui WIRE `score_response()` dans le production response path (`coach_chat.py` agent loop OR `RAGOrchestrator.query()` post-filter).

**Le bypass FATCA est pré-existant** — pas introduit par PR #529. Donc shipping v2.12.2+4 ne fait ni mieux ni pire sur ce point. Les 4 P0 user-facing fixes (B1+B2+B3+B4 + cosmetics + Dart-side B6 archetype plumbing) restent valides et livrent valeur immédiate.

**Lesson for future commits (0-Trust)** : claim « closes » exige citation du production caller, pas juste l'existence de la function. Un grep production-callers AVANT de write « closes » dans le commit message aurait évité cette retractation.
- `MVP-DENSITY-V2-HYPOTHEQUE-ETC-2026-05` (à ouvrir Phase 3)
- `MVP-DARK-MODE-V2-2026-05` (à ouvrir post-onboarding-v2)

## Références

- 6 audit transcripts (sub-agent IDs) : a39705af9 (O1) / a6f345199 (O2) / a26e15301 (O3) / abb4b4669 (O4) / ad1459c2e (O5) / aeee85dbf (O6)
- Sources WebSearch citées dans chaque audit transcript (Userpilot, Eleken, FinanceBuzz, vermoegenszentrum.ch, Anthropic API pricing, FINMA Circ. 2025/02, etc.)
- MINT v2 canvas HTML (Julien partagé, Tweaks Menthe-vive + slogan « clair »)
- PR #525 wire FinancialPlanCard merged db350b77
- PR #529 hotfix bundle B1+B2+B3+B4+cleanup+B6 (in flight, head d68a0f14)
- CLAUDE.md NEVER #4 (18 life events) + #7 (no swiss_native default) + § 9 0-Trust
- ROADMAP_V2.md S52 (4-tab shell shipped, post-S52 path = the gap)
