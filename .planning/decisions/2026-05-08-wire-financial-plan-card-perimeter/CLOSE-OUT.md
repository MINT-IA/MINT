---
name: Périmètre wire-financial-plan-card — close-out
description: 5-gate audit log for the wire-FinancialPlanCard perimeter merged via PR #525 (db350b77). 3/5 gates green with citation, G1 partial (sim user-AVEC-plan not run), G2 pending Julien device. Strategic context filed alongside (Anthropic FSI synthesis + W1+W3 findings). Lefthook activation gap surfaced as separate post-TestFlight perimeter.
type: decision
date: 2026-05-08
status: Proposed
related:
  - .planning/decisions/2026-05-08-office-hours-mon-dossier/DESIGN.md
  - .planning/decisions/2026-05-08-anthropic-fsi-strategic/SYNTHESIS.md
  - .planning/decisions/2026-05-08-anthropic-fsi-strategic/W1-W3-FINDINGS.md
trigger: PR #525 merged to dev (squash) at 2026-05-08T16:05:55Z, sha db350b77
---

# Périmètre wire-financial-plan-card — close-out

## TL;DR

PR #525 squash-mergée sur `dev` à `db350b77`. **3/5 gates green avec citation, 2/5 partial or pending.** Le périmètre est en `IN-FLIGHT` jusqu'à G1 complet (sim avec plan actif) + G2 (Julien device). Status PERIMETERS.md = 🟡 IN-FLIGHT, pas encore 🟢 CLOSED.

Aucun mot de §9.1 (« shipped », « ready », « green » au sens global) n'est employé sans citation deterministe.

## Périmètre — definition

**Goal** : fermer la façade-sans-câblage W14 sur `FinancialPlanCard` + `ConfidenceScoreCard` qui étaient définis depuis Phase 26-ish mais non importés ni rendus dans `AujourdhuiScreen`. Le user qui génère un plan via le coach devait avoir une surface persistante hors-chat pour le revoir.

**Surface touchée** :
- [apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart](apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart) — wire (lignes ~105-130 post-merge)
- [apps/mobile/lib/providers/financial_plan_provider.dart](apps/mobile/lib/providers/financial_plan_provider.dart) — `_profileAttached` idempotency guard
- [apps/mobile/lib/app.dart](apps/mobile/lib/app.dart) — ProxyProvider lifecycle (`loadFromPersistence` + `attachProfileProvider`)

**Hors-périmètre (deferred)** :
- Migration `ConfidenceScoreCard` → `MintTrameConfiance.inline()` (Phase 8a Plan 08a-02 Batch C — voir doc residue)
- Câblage CommitmentDevice / PreMortemEntry / ArbitrageHistory côté mobile (0/8 archétypes câblés aujourd'hui — voir DESIGN.md post-vérif)
- Lefthook activation `accent_lint_fr.py` + `no_hardcoded_fr.py` (voir §Drapeau rouge ci-dessous)

## 5 gates — état avec évidence

### G1 — Sim walker

**État : 🟡 PARTIAL.**

| Sous-gate | État | Évidence |
|---|---|---|
| Cold launch | ✅ | Session report précédente : « Sim install + cold launch — no crash, plan section correctly hidden » (citation : `idb describe-all`) |
| User SANS plan → card hidden | ✅ | Idem |
| User AVEC plan actif → card visible avec hero/milestones/confidence/disclaimer | ❌ pas encore lancé | À faire post-merge |
| Stale state (plan > 30 j ou profile changé) → badge amber + Recalculer CTA | ❌ pas encore lancé | À faire post-merge |

**Action item next session** : sim walker scénario « génère plan via coach → switch to Aujourd'hui tab → card rendue ». ~10 min.

### G2 — Device par Julien

**État : 🟡 NOT YET.**

Pas encore confirmé sur device physique iPhone Julien. Bloquant pour close-out final.

**Action item Julien** : staging build à dispo après dev→staging merge. Vérifier visuel + interaction.

### G3 — Dev CI

**État : 🟢 GREEN.**

Évidence : `gh pr view 525 --json statusCheckRollup` sur run `25565490933` (post-push de 6ff7cbc0). **17 CheckRuns** sur le workflow CI tous SUCCESS, plus 1 Vercel StatusContext SUCCESS + 1 Vercel Preview Comments CheckRun SUCCESS = 19 entries total, toutes SUCCESS.

```
Backend tests       SUCCESS  completed 2026-05-08T16:01:21Z
CI Gate             SUCCESS  completed 2026-05-08T16:01:48Z
Flutter widgets     SUCCESS  completed 2026-05-08T16:00:01Z
Flutter services    SUCCESS  completed 2026-05-08T16:01:34Z
Flutter screens     SUCCESS  completed 2026-05-08T15:59:57Z
WCAG AA all touched SUCCESS  completed 2026-05-08T15:58:19Z
PII log gate        SUCCESS  completed 2026-05-08T15:57:32Z
... (10 autres CheckRuns CI workflow SUCCESS)
Vercel              SUCCESS  startedAt   2026-05-08T16:05:35Z
Vercel Preview      SUCCESS  startedAt   2026-05-08T15:56:34Z
```

Caveat correction post-audit : `mergeStateStatus: UNSTABLE` que j'avais snapshoté plus tôt reflétait un état antérieur où Vercel était encore PENDING. Au moment du merge (`16:05:55Z`), Vercel était passé à SUCCESS depuis ~20s (`16:05:35Z`). Donc le merge n'a PAS été completed avec un Vercel pending — j'avais mal interprété le snapshot précoce. Le doc-verifier audit a flagué cette imprécision.

### G4 — Regression tests

**État : 🟢 GREEN (côté CI).**

Évidence :
- Test 12 idempotency `5 attach calls = 1 listener` : 6/6 pass (per session report précédente, citation : `test/providers/financial_plan_provider_test.dart`)
- Job CI `Flutter widgets`, `Flutter services`, `Flutter screens` : tous SUCCESS au timestamp ci-dessus
- Job CI `Backend tests` inclut pytest backend + `--cov-fail-under=60` + diff-cover changed-lines `--fail-under=80` : SUCCESS

Caveat : aucun nouveau golden test sur Aujourd'hui (find apps/mobile/test/goldens -name "*aujourdhui*" → 0 hit). Donc pas de risque de rebaseline visuelle, mais pas de gate visuelle non plus. Si rendu casse silencieusement, on ne le voit qu'au sim run (G1).

### G5 — LSFin + accent + ARB lint

**État côté CI : 🟢 GREEN.**

Évidence (lints du job Backend tests, run local + CI) :

```
no_chiffre_choc                  : OK (zero legacy tokens)
no_legacy_confidence_render      : OK (30 allowlisted, post-fix de PR #525)
no_implicit_bloom_strategy       : OK (every MintTrameConfiance has explicit bloomStrategy)
sentence_subject_arb_lint        : OK (post-fix @coachTransparencyServer N3)
banned_terms_arb                 : OK (6 locales clean, no positive LSFin uses)
no_llm_alert                     : OK (zero co-locations)
regional_microcopy_drift         : OK (in sync)
landing_no_numbers               : OK
landing_no_financial_core        : OK
```

**État côté lefthook local : ⚠️ NON-EXÉCUTÉ.**

Drapeau rouge — voir §Drapeau rouge.

## Drapeau rouge — gap CLAUDE.md §4 vs lefthook.yml

CLAUDE.md §4 documente que `accent_lint_fr.py` + `no_hardcoded_fr.py` tournent en pre-commit local. **Faux.** [lefthook.yml](lefthook.yml) actuel n'a que 3 hooks : `memory-retention-gate`, `map-freshness-hint`, `wiki-lint`. Les 2 lints i18n sont absents. Commentaire du yml : « Phase 34 GUARD-01 will ADD bare_catch, hardcoded_fr, accent_lint, arb_parity ON TOP of this scaffold. Rails posés, lints NON-ACTIVÉS (D-04). »

Donc tous les commits récents (incluant les 5 du PR #525) **n'ont pas passé** ces 2 lints en local. Ils ne passent que via CI sur les paths CI.

L'agent précédent avait listé l'activation comme « next session ~20 min ». **Erreur d'estimation.** Baseline mesuré sur HEAD `dev` (post-merge `db350b77`) :

```
accent_lint_fr.py    : 282 violations
no_hardcoded_fr.py   : 5 034 violations
apps/mobile/Makefile : N'EXISTE PAS (l'item « make i18n-fix » n'a même pas de fichier de base)
```

Activation HARD aujourd'hui = bloque tous les commits jusqu'à fix de 5316 violations. **Sizing révisé après audit échantillonné (50 violations) : 3-5 jours, et c'est un i18n migration milestone, PAS un lint cleanup.** Initial estimate « 1-3j » était sous-évalué — voir §Sizing audit ci-dessous.

### Sizing audit (50 violations échantillonnées sur les 5034)

Audit conduit post-merge par sub-agent dédié. Sample = chaque 100e ligne du `no_hardcoded_fr.py` output. Classification :

| Catégorie | % | Exemple |
|---|---|---|
| **USER-VISIBLE** | **82%** (41/50) | `onboarding_shell_screen.dart:320` `prompt: 'Quel âge tu as ?'` |
| **CONST/INTERNAL** | **14%** (7/50) | `coach_llm_service.dart:463` `'Tu NE donnes JAMAIS de conseil financier.'` (LLM system prompt, never rendered) |
| **COMMENT** | **4%** (2/50) | `tax_declaration_parser.dart:128` `// Variante: ...` |
| **DEAD-CODE** | **0%** | (none) |

**Top 3 offender files** :
1. `apps/mobile/lib/services/coach/fallback_templates.dart` — 195 hits (coach fallback bodies, mostly user-visible)
2. `apps/mobile/lib/data/education_content.dart` — 179 hits (educational module text, all user-visible)
3. `apps/mobile/lib/services/educational_insert_service.dart` — 161 hits (insert subtitles / premier eclairage, user-visible)

**Sizing** : 82% user-visible × 5034 violations ≈ **~4 100 strings à migrer en ARB réel** (key naming + extraction × 6 langs + `gen-l10n` + call-site replacement + interpolation handling). Top-3 offenders alone = ~535 hits dont la traduction nécessite **aussi** un LSFin compliance review (banned terms). Pure allowlist/auto-fix **non viable** — le codebase est en dette i18n bien plus que ce qu'un cleanup 1-3j peut fixer.

**Reframe** : c'est un **i18n migration milestone**, pas un lint cleanup. Lefthook gating doit être différé jusqu'à migration done OR allowlist explicite des non-user-visible (LLM prompts internes principalement).

## Recommendation perimeter suivant

**À ouvrir post-TestFlight** : `MILESTONE-I18N-MIGRATION-2026-Q3` (renommé de l'initial `MVP-LINT-CLEANUP-LEFTHOOK` parce que le scope est i18n migration, pas lint cleanup).

**Étapes (révisées)** :
1. **Quick win — auto-fix accent_lint_fr** (282 violations, mostly back-end Python + simulator) : `creer→créer`, `securite→sécurité`, `specialiste→spécialiste`, `eclairage→éclairage`. Script peut proposer le fix in-place. **0.3j**.
2. **Audit complet** : classifier chaque violation no_hardcoded_fr (5034) en USER-VISIBLE / CONST/INTERNAL / COMMENT. Échantillon 50 dit 82/14/4 — extrapoler ou re-sample plus large pour précision. **0.5j**.
3. **Migrer les 3 top offenders** vers ARB en priorité (`fallback_templates`, `education_content`, `educational_insert_service` ≈ 535 hits, ~10% du total). LSFin compliance review en même temps. **1.5-2j**.
4. **Migrer le reste des user-visible** par batch de 200-300 hits (key naming pattern stable, peut être semi-automatique). **1-2j**.
5. **Allowlist** les CONST/INTERNAL (LLM system prompts) avec un exclusion-pattern dans `no_hardcoded_fr.py` (path-based ou marker comment). **0.2j**.
6. **Allowlist** les COMMENTS (`//` `///` `"""..."""`) via un ignore-pattern dans `no_hardcoded_fr.py`. **0.2j**.
7. **Activer** les 2 hooks comme HARD gates dans `lefthook.yml` (sera vert puisque les 5034 violations sont à 0 ou allowlistées). **0.1j**.
8. **Mettre à jour** CLAUDE.md §4 pour matcher la config réelle (empêcher dérive future). **0.1j**.
9. **Ajouter** `apps/mobile/Makefile` avec `i18n-fix` shortcut. **0.1j**.

**Effort total révisé** : **3-5 jours minimum**, plus probable 5-7j incluant LSFin compliance reviews + tests goldens 6 langues.

**Pas blocker TestFlight Q3** si MINT cohort initiale = FR-only swiss-native — la pipeline ship CI passe déjà sur les paths CI scope. Le gap est :
- **Local-only** sur lefthook (commits récents skippent les 2 lints en pré-commit, mais CI les bloque s'ils sont activés en CI ; aujourd'hui ils ne sont pas en CI non plus pour le job principal).
- **Multi-langue** sur user-facing strings — les 6 ARB files ne contiennent QUE le squelette, le contenu réel est codé en FR direct dans le code. MINT en pratique est FR-only en TestFlight Q3 même si les ARBs prétendent supporter 6 langues.

## Action items immédiats post-merge

| # | Action | Effort | Owner | Bloquer ? |
|---|---|---|---|---|
| 1 | **Sim walker scénario plan-actif** sur staging build (G1 complet) | ~10 min | Claude | Non, mais nécessaire pour CLOSED |
| 2 | **Pubspec patch bump** (per memory `project_testflight_ship_path`) | 2 min | Julien ou Claude | Pour TestFlight ship |
| 3 | **Merge dev → staging** → fires `testflight.yml` | 1 min | Julien | Pour TestFlight ship |
| 4 | **G2 device** par Julien sur build TestFlight | 5 min | Julien | Pour CLOSED |
| 5 | **Update PERIMETERS.md / MILESTONE-MVP-PERIMETER.md** flip à 🟢 CLOSED | 5 min | Claude | Après G1 + G2 |
| 6 | **Open perimeter MVP-LINT-CLEANUP-LEFTHOOK** | doc only, 30 min | Claude | Post-TestFlight |

## Counter-arguments and data gaps

- **Le close-out se fait avant G1 complet et G2 device** — c'est pourquoi le status est `Proposed` et pas `Decided`, et pourquoi PERIMETERS.md state reste 🟡 IN-FLIGHT. Le doc est posé maintenant pour cristalliser l'état + décider le next move pendant que les 2 gates restants se font en parallèle.
- **Aucun golden test sur Aujourd'hui** : confirme une absence de gate visuelle. Si `FinancialPlanCard` rend mal silencieusement (overflow, color contrast, RTL), on ne le voit qu'à G1 ou G2. Mitigation : à G1 capturer un screenshot Aujourd'hui-with-plan + Aujourd'hui-empty pour comparer manuel à l'intent design.
- **Le baseline lefthook 5316 violations** est mesuré 2026-05-08 sur HEAD `db350b77`. Si dev bouge avant le perimeter cleanup, le baseline devra être re-mesuré. Probablement ↑ pas ↓ (les violations s'accumulent sans gate).
- **Le « 3 IB agents structurellement applicables MINT B2C »** dans SYNTHESIS Anthropic FSI est une analogie structurelle non validée par user research. Mitigation : Phase 2-3 candidates only, valider avec M1 prototype avant commit.
- **L'« Anthropic Skill Creator Tool »** n'a pas été testé en local. La capability matrix est basée sur le webinar + press release, pas sur usage réel. Calibrer Phase 2 si on s'engage dans cette direction.
- **PR #525 a été mergé avant G1 complet** — risque assumé. La logique : le wire est conditionnel (`hasPlan` gate), donc même si la card a un bug rendu, les users sans plan (la majorité 85-95% per OH-3) ne le voient pas. Bug rendu = visible à G1 sim run avec plan, fixable en hot-patch dans un follow-up PR. Acceptable risque pour mid-week velocity.
- **Donnée manquante** : taux de DAU MINT avec plan actif multi-mois. Le 10-15% de l'OH panel est une estimation Cleo/Copilot/Monarch — pas de benchmark interne. Calibrer post-TestFlight pour décider si Phase 2 push pour Mon dossier full ou si le current wire est suffisant.

## Format claim 0-Trust (per CLAUDE.md §9.6)

```
Evidence — PR #525 merged :
  gh pr view 525 → state:MERGED, merged:2026-05-08T16:05:55Z, sha:db350b77
Evidence — CI 18/18 SUCCESS sur 6ff7cbc0 :
  gh pr view 525 statusCheckRollup, run 25565490933, CI Gate completed 16:01:48Z
Evidence — lints local exit 0 sur HEAD post-merge :
  9/9 lints du job Backend tests testés en local (no_chiffre_choc, no_legacy_confidence_render,
  no_implicit_bloom_strategy, sentence_subject_arb_lint, banned_terms_arb, no_llm_alert,
  regional_microcopy_drift, landing_no_numbers, landing_no_financial_core)
Evidence — lefthook gap :
  cat lefthook.yml | head -40 → 3 hooks (memory-retention + map-freshness + wiki-lint)
  python3 tools/checks/accent_lint_fr.py → 282 violations
  python3 tools/checks/no_hardcoded_fr.py → 5034 violations
  ls apps/mobile/Makefile → No such file or directory

Caveat — what I have NOT checked :
  - sim walker user-avec-plan (G1 complet) — pending post-merge
  - device run par Julien (G2) — pending TestFlight build
  - golden screenshots Aujourd'hui post-wire (none exist) — to capture at G1
  - Vercel preview state (web, non-blocker mobile) — still PENDING at merge time
  - whether dev→staging merge would re-trigger CI on staging branch (probable, not yet run)
```

## Approval gate

Lecture senior PM (Critical PM, anti-sycophancy) :

1. **PR #525 mergé sur dev**, état 3/5 gates green.
2. **Périmètre EN COURS jusqu'à G1 complet + G2 device.** Pas encore 🟢 CLOSED.
3. **Action immédiate Julien** : décider si on chaîne maintenant le TestFlight ship path (pubspec bump → dev→staging merge → testflight.yml fires → device run) ou si on attend une fenêtre de validation plus large.
4. **Action immédiate Claude** : préparer le sim run G1 complet pendant que Julien décide du chain.
5. **Pas d'action lefthook** dans cette fenêtre — le perimeter MVP-LINT-CLEANUP-LEFTHOOK est filé en référence pour Q3 post-TestFlight.

Le doc est filé en `Proposed` parce que les conditions de close-out (G1 + G2) ne sont pas remplies. Il bascule à `Decided` quand les 2 derniers gates sont verts avec citation.
