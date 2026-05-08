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

Évidence : `gh pr view 525 --json statusCheckRollup` sur run `25565490933` (post-push de 6ff7cbc0). 18 CheckRuns SUCCESS dont :

```
Backend tests       SUCCESS  completed 2026-05-08T16:01:21Z
CI Gate             SUCCESS  completed 2026-05-08T16:01:48Z
Flutter widgets     SUCCESS  completed 2026-05-08T16:00:01Z
Flutter services    SUCCESS  completed 2026-05-08T16:01:34Z
Flutter screens     SUCCESS  completed 2026-05-08T15:59:57Z
WCAG AA all touched SUCCESS  completed 2026-05-08T15:58:19Z
PII log gate        SUCCESS  completed 2026-05-08T15:57:32Z
... (11 autres SUCCESS)
```

Caveat : 1 StatusContext `Vercel` à `state: PENDING` (web preview, non-blocker pour mobile). `mergeStateStatus: UNSTABLE` reflétait uniquement ce Vercel pending — pas un blocker mécanique.

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

Activation HARD aujourd'hui = bloque tous les commits jusqu'à fix de 5316 violations. **C'est un perimeter de 1-3j, pas un quick win.**

**Note plus large** : 5 034 strings FR hardcodées dans le mobile est aussi un signal CLAUDE.md NEVER #1 (i18n required). Beaucoup sont probablement dans des `//` `///` commentaires (non user-visibles) — un échantillonnage rapide le confirme. Mais quel % réellement user-visible nécessite un audit avant de chiffrer le cleanup.

## Recommendation perimeter suivant

**À ouvrir post-TestFlight** : `MVP-LINT-CLEANUP-LEFTHOOK-2026-Q3` perimeter dédié.

**Étapes** :
1. Audit échantillonné : sur 100 violations no_hardcoded_fr aléatoires, quel % est dans des commentaires vs dans des strings user-visibles ?
2. Auto-fix `accent_lint_fr.py` 282 violations (mostly `creer→créer`, `securite→sécurité`, `specialiste→spécialiste`, `eclairage→éclairage`) — script propose le fix in-place
3. Migrer les vrais hardcoded user-visibles vers ARB (Phase 26 i18n protocol)
4. Allowlist les `//` commentaires (low-priority bypass)
5. Activer les 2 hooks comme HARD gates dans `lefthook.yml`
6. Mettre à jour CLAUDE.md §4 pour matcher la config réelle (et empêcher la dérive future)
7. Ajouter `apps/mobile/Makefile` avec `i18n-fix` shortcut (`make i18n-fix` → invoque le skill `autoresearch-i18n`)

**Effort total** : 1-3 j selon résultat de l'étape 1.

**Pas blocker TestFlight** — la pipeline ship CI passe déjà sur les paths CI scope. Le gap est local-only.

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
