---
date: 2026-05-14
status: Decided
authors: Julien (decided), Claude (drafted)
panel: single
supersedes: —
superseded_by: —
description: DS v2 propagation Wave 1.5 dédiée big-bang (option a sub-agent H recommendation) — Vague 1 ink+warm+menthe+typo sur Tier 1-3 (50-80h) + Vague 2 grammaire ConfidenceBand wrap sur 29 écrans hero-number (50-65h). Lint custom ds_v2_lint_hero_unwrapped.py pour bloquer regression.
related:
  - .planning/audit/2026-05-14-ds-v2-coverage.md
  - .planning/audit/2026-05-14-handoff-vs-code-drift.md
  - .planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf
  - .planning/decisions/2026-05-14-aujourdhui-doctrine.md
  - docs/DESIGN_SYSTEM.md
---

# DS v2 propagation — Wave 1.5 dédiée big-bang

## TLDR

Sub-agent H a chiffré le drift DS v2 (PDF mai 8 canonique) sur les 108 écrans : score moyen Tier 1-3 = 47.4%, zéro écran ≥ 70%, mentheVive câblé 0%, ConfidenceBand 2.8%, EnrichmentPrompts 7.4% ; 29 écrans affichent un hero number sans wrap. Julien tranche option (a) : **Wave 1.5 dédiée big-bang propagation** entre Wave 1 (backend tools refactor) et Wave 2 (TrajectoryMap build), avec lint custom `ds_v2_lint_hero_unwrapped.py` pour bloquer regression.

## Context

Julien observation 2026-05-14 verbatim : « j'ai l'impression qu'il a pas fait sur tous les écrans. Des écrans qui sont à moitié dans le bon design et à moitié dans le mauvais. »

Sub-agent H output `.planning/audit/2026-05-14-ds-v2-coverage.md` confirme :

| Dimension DS v2 | Coverage écrans Tier 1-3 |
|---|---|
| D1 Typo `MintTextStyles.*` | 90% (Phase 92 + MVP-GOOGLEFONTS-PURGE-V1 substantially done) |
| D2 Ink `inkPrimary` warm | **1.9%** (Handoff 2 token câblé sur 2 écrans seulement) |
| D3 Surface warm `porcelaineHero / craieHandoff` | **2-4%** |
| D4 Accent `mentheVive` | **0%** (token défini `colors.dart:314` mais jamais consommé) |
| D5 Grammaire « Chiffre nu interdit » (ConfidenceBand + EnrichmentPrompts wrap) | **2.8-7.4%** |
| D6 Anti-pattern (LinearGradient, MintGlassCard) | 19 écrans avec LinearGradient à vérifier |
| **Score moyen Tier 1-3** | **47.4%** — zéro écran ≥ 70% |

3 options évaluées :
- (a) **Wave 1.5 dédiée big-bang propagation** (recommended sub-agent H) — 3-4 sem cumulé
- (b) Screen-by-screen incremental durant Wave 1/2/3 — lent, ne jamais atteindre 100%
- (c) Skip jusqu'à Wave 5+ post-TestFlight — risque identité visuelle MINT au moment du judgement journalistique

Julien tranche **(a)** le 2026-05-14.

## Decision

**Wave 1.5 = vague dédiée propagation DS v2** insérée entre Wave 1 (backend tools refactor — 3 sem) et Wave 2 (TrajectoryMap build — 2 sem + gain 5-7j de Wave 1b refined). Architecture cumulée :

```
Wave 0 (5-7 jours)  → research + ADRs + wireframes + persona guide
Wave 1 (3 sem)      → backend tools refactor Python + planner refined (gain 5-7j)
Wave 1.5 (3-4 sem)  → propagation DS v2 big-bang [CETTE DÉCISION]
Wave 2 (2 sem)      → TrajectoryMap build + 8 archetypes + golden tests
Wave 3 (3 sem)      → orchestrator + push surface + LifeEventWatchdog
Wave 4 (3 jours)    → widgets didactiques inline Coach (SHORT per sub-agent A)
```

**Wave 1.5 décomposée en 2 vagues séquentielles** :

### Vague 1 — Tokens propagation Tier 1-3 (50-80h ≈ 1.5-2 sem)

**Scope** :
- ~28 écrans Tier 1-3 (Pulse, Quick Start, Premier-Éclairage, Profile, Coach Chat, Budget, Retirement Dashboard, Rente vs Capital, Rachat LPP, Mariage, Naissance, Divorce, etc.)
- 4 dimensions à propager : Ink (legacy `primary` → `inkPrimary`), Surface warm (legacy `surface` → `porcelaineHero/craieHandoff` selon contexte), Accent mentheVive (sur 20-40 surfaces pertinentes : marker actif Trajectory, chips actifs, CTA primary), Typo (déjà à 90% — close gap 10% restants)
- Méthode : grep-and-replace ciblé per-écran + revue visuelle screen-par-screen sur sim
- Acceptance : ≥ 70% score DS v2 sur chaque écran Tier 1-3 (mesuré via `ds_v2_lint_check.py` détecté sub-agent H)

**Anti-pattern à neutraliser pendant Vague 1** :
- `LinearGradient` résiduel (19 écrans à audit per-screen) → garder 1 max par page (DS §7 pattern 7), refacto si > 1
- `MintPremiumButton` (1 occurrence résiduelle) → migration vers `FilledButton` primary
- Couleurs hardcoded `Color(0x...)` → 0 (déjà clean per Sub-agent H)

### Vague 2 — Grammaire « Chiffre nu interdit » wrapping (50-65h ≈ 1.5 sem)

**Scope** :
- 29 écrans affichant un `MintHeroNumber` / `displayLarge` / `displayHero` sans wrap ConfidenceBand + EnrichmentPrompts (per sub-agent H §3 buckets)
- Build composable `MintConfidenceWrap` widget qui prend `child: MintHeroNumber(...)` + `confidence: ConfidenceLevel.low/medium/high` + `enrichmentPrompts: List<String>` et rend le hero + ConfidenceBand + EnrichmentPrompts inline cohérents avec PDF DS v2 mai 8 page 3-4.
- Refactor screen-by-screen : remplace `Text('5\'800 CHF', style: displayLarge)` par `MintConfidenceWrap(child: MintHeroNumber('5\'800', 'CHF/mois'), confidence: ConfidenceLevel.low, enrichmentPrompts: [...])`.
- Acceptance : 0 hero number unwrapped dans Tier 1-3 ; ≥ 95% des chiffres projetés/estimés cross-corpus ont confidence + prompts visibles.

### Lint custom `ds_v2_lint_hero_unwrapped.py`

Installé en lefthook pre-commit gate (cohérent avec memory `feedback_ci_path_filter_blind_spots`). Bloque tout commit qui ajoute un `MintHeroNumber` / `displayLarge` / `displayHero` non-wrappé dans `MintConfidenceWrap` ou équivalent.

Implémentation : Python script qui grep les fichiers `.dart` modifiés + AST simple Dart (treesitter-dart ou regex tolérant) + flag toute occurrence isolée. Faux positifs documentés (ex : screen Utility ou Auth qui n'a pas de chiffre projeté à wrapper) via comment `// ds-v2-lint-ignore: utility screen no projection`.

Effet attendu : 0 régression DS v2 grammaire « chiffre nu » après Wave 1.5 close.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Anti-big-bang : option (b) screen-by-screen incremental respecte mieux Karpathy #3 « Surgical Changes ». Une Wave 1.5 big-bang = 3-4 sem de churn cosmétique sans ship feature visible — risque de fatigue Julien + sentiment « on avance pas ». Plus, si une Wave 1.5 vague échoue (lint bug, régression sim), elle bloque Wave 2 timeline. Big-bang concentre le risque.

- **What does this source not address ?**
  - Le coût du `MintConfidenceWrap` widget lui-même (Vague 2 dépend de son design) — peut-être 1-2 jours d'API design + tests avant qu'on puisse l'appliquer.
  - La régression visuelle device : 28 écrans Vague 1 × 1 walkthrough sim = ~28 × 5 min = 2.3 heures de sim review. Pas modélisé dans le coût 50-80h.
  - L'impact tests Flutter golden : changer la palette warm cassera tous les goldens screenshots qui matchent l'ancienne palette. Coût regen goldens ≈ 1-2 jours + Julien validation.
  - Dépendance avec décision Mon Argent P2 : la Vague 1 propage les tokens sur Tier 1-3 actuels (Pulse, etc.), mais si P2 supprime Mon Argent comme tab et crée Trajectoire en Wave 2, les nouveaux écrans Trajectoire doivent dès le départ être en DS v2 propagés — pas double-effort.

- **What would change this conclusion ?**
  1. Si Vague 1 dépasse 100h ou rencontre des régressions visuelles non-anticipées sur ≥ 5 écrans → pause Wave 1.5, revisit option (b) incremental.
  2. Si lint `ds_v2_lint_hero_unwrapped.py` produit > 30% faux positifs sur le baseline → revisit approach (peut-être pas un lint mécanique mais un audit Julien-validated periodic).
  3. Si tests utilisateurs Wave 0 (sub-agent G persona guide → test wireframe) montrent que la palette warm + grammaire ConfidenceBand sont PAS perçues positivement → revisit doctrine DS v2 mai 8 (très peu probable mais possibility-noted).

## Sources

- `.planning/audit/2026-05-14-ds-v2-coverage.md` (sub-agent H) — données quantitatives écran-par-écran
- `.planning/audit/2026-05-14-handoff-vs-code-drift.md` §D.ter — diagnostic « moitié design » formalisé
- `.planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf` — grammaire mai 8 canonique
- `apps/mobile/lib/theme/colors.dart` — tokens DS v2 déjà définis mais non-consommés
- `apps/mobile/lib/theme/mint_text_styles.dart` — Phase 92 + MVP-GOOGLEFONTS-PURGE-V1 (Supreme + Gambarino)
- `.planning/decisions/2026-05-14-aujourdhui-doctrine.md` — ratify principe « Chiffre nu interdit » sur Aujourd'hui
- `.planning/decisions/2026-05-14-mon-argent-p2-dissolution-trajectoire.md` — coupling Wave 2 TrajectoryMap implémentation

## Status & follow-up

- **Implementation tracking** :
  - **Wave 1.5 phase artifact stack** : créer `.planning/phases/wave-1.5-ds-v2-propagation/` avec PLAN + EXECUTION + VERIFICATION (GSD workflow pattern, memory `feedback_gsd_workflow_default`).
  - **Vague 1 PR scope** : ~28 écrans Tier 1-3, ~50-80h, 1.5-2 sem. PR splittable per Tier (Tier 1 = 6 écrans = 1 PR, Tier 2 = 6 écrans = 1 PR, Tier 3 = 6 écrans = 1 PR).
  - **Vague 2 PR scope** : `MintConfidenceWrap` widget + 29 wraps + lint custom = 50-65h, 1.5 sem. Splittable en (a) widget + lint (1 PR) puis (b) propagation 29 wraps (1-2 PRs).
  - **Acceptance globale Wave 1.5 close** : score moyen Tier 1-3 ≥ 70% (vs 47.4% baseline) — vérifié par re-run sub-agent H scan post-Wave-1.5.

- **Re-litigation triggers** :
  - Vague 1 dépasse 100h ou ≥ 5 régressions visuelles non-anticipées → revisit option (b) incremental
  - Lint custom > 30% faux positifs → revisit approach
  - User research Wave 0 (sub-agent G + test wireframe) signale rejet visuel DS v2 → revisit grammaire
  - Wave 2 timeline glisse à cause Wave 1.5 trop longue → réduire Vague 2 scope à Tier 1-2 uniquement, Vague 2 Tier 3 reportée Wave 3

---
*Decided 2026-05-14 par Julien via question explicite « DS v2 propagation scope ? » → « (a) Wave 1.5 dédiée big-bang propagation (Sub-agent H recommended) ». Drafted Claude post-PR #600 Wave 0.*
