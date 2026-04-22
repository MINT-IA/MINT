# Phase 34: Agent Guardrails mécaniques - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning
**Mode:** discuss --auto (Claude picked recommended defaults from REQUIREMENTS.md + ROADMAP + codebase maps)

<domain>
## Phase Boundary

Livrer **lefthook 2.1.5 pre-commit parallel <5s** avec **5 lints mécaniques actifs** qui bloquent toute régression accent / hardcoded-FR / bare-catch / ARB drift, que le commit vienne d'un humain ou d'un agent. Convention `LEFTHOOK_BYPASS=1` remplace `--no-verify` (grep-able, audité hebdomadairement). 10 gates grep-style `tools/checks/*.py` migrent de CI vers lefthook-first — CI garde les heavies (full test suites, readability, WCAG, PII, contracts, migrations).

**Dans le scope** : GUARD-01 → GUARD-08 (8 requirements), lefthook full config + 4 nouveaux lints (`no_bare_catch.py`, `no_hardcoded_fr.py`, `arb_parity.py`, `proof_of_read.py`), CI reshuffle, bypass audit.

**Hors du scope** (déférés) : FIX-05 (migration 388 bare-catches → 0, Phase 36), FIX-07 (fix accents résiduels, Phase 36), migration des codebase maps `.planning/codebase/*.md` à proof-of-read (Phase 36 DIFF-04 via PreToolUse).

</domain>

<decisions>
## Implementation Decisions

### Lefthook structure (GUARD-01)
- **D-01** : **Un seul `lefthook.yml` à la racine**, sections logiques par tag (`[memory]`, `[i18n]`, `[safety]`, `[maps]`). Pas de `lefthook-local.yml` template. Skeleton 30.5 (`memory-retention-gate` + `map-freshness-hint`) préservé, les 5 nouveaux lints s'ajoutent par-dessus.
- **D-02** : **`parallel: true`** activé (Phase 30.5 D-04 notait `parallel: false until phase 34 — race conditions on .git/index.lock`). Budget <5s absolu mesuré sur M-series Mac avec diff typique (5 Dart + 3 Python staged). Mesure via `LEFTHOOK_PROFILE=1 time git commit --allow-empty -m 'perf'` capturé dans SUMMARY.
- **D-03** : **Scope changed-files only** via `glob:` filter par commande (`*.dart`, `*.py`, `*_fr.arb`, etc.). Pas de full-repo scan dans aucun hook.
- **D-04** : Installation via `brew install lefthook` + `lefthook install` post-clone documenté dans `CONTRIBUTING.md`. Version pin `min_version: 2.1.5`. Pas de `pre-push`, pas de `commit-msg` dans cette phase (reste pre-commit only).
- **D-27 (amends D-04, per Plan 34-05 + RESEARCH Open Question 1)** : la scope D-04 « pre-commit only » est étendue à **un seul `commit-msg` block** dédié à GUARD-06 proof-of-read. Raison : le `Read:` trailer n'existe pas encore au moment du pre-commit (git n'a pas encore ouvert `COMMIT_EDITMSG`). Tous les autres lints (GUARD-01..05, GUARD-07, GUARD-08) restent pre-commit. Validé par Plan 34-05 Task 2A + SUMMARY.

### GUARD-02 — no_bare_catch lint (Dart + Python)
- **D-05** : **Regex-first** (pas AST). Patterns détectés :
  - Dart : `}\s*catch\s*\(\s*(e|_)\s*\)\s*\{[\s\n]*\}` (bare) + `}\s*catch\s*\(\s*e\s*\)\s*\{[\s\n]*\}` sans `log`/`Sentry`/`rethrow`/`debugPrint` dans le body (1-line check).
  - Python : `except\s+Exception\s*:\s*$` + `except\s*:\s*$` + `except\s+\w+\s*:\s*pass` sans `logger.`/`raise`/`sentry_sdk.`/`log.` dans les 5 lignes suivantes.
- **D-06** : **Exceptions documentées en dur** :
  - `apps/mobile/test/**`, `apps/mobile/integration_test/**`, `services/backend/tests/**` — exempté (tests mockent souvent).
  - Dart streams `async *` (le `catch (e)` dans un generator est idiomatique) — détecté par `grep -B 10 "async \*"` en amont.
  - Opt-in inline override : commentaire `// lefthook-allow:bare-catch: <reason>` juste au-dessus (1 ligne). Reason obligatoire (>3 mots).
- **D-07** : **Rollout mode** : `GUARD-02` est **active from day 1** (pas de warm-up). Les 388 bare-catches existants restent in-place — le lint ne scan que les **lignes ajoutées** au diff (via `git diff --staged --unified=0` + line-range check). FIX-05 Phase 36 converge à 0 par batch. Cette séparation = GUARD-02 ACTIVE avant FIX-05 start (success_criteria #2) sans moving target.

### GUARD-03 — no_hardcoded_fr lint (Dart widgets)
- **D-08** : **Scope restreint** à `apps/mobile/lib/widgets/**`, `apps/mobile/lib/screens/**`, `apps/mobile/lib/features/**`. Exclus : `lib/l10n/`, `lib/models/`, `lib/services/`, `test/`, `integration_test/`. Le i18n total (services compris, ~120 strings D4) reste Phase 36 FIX-06 scope.
- **D-09** : **Patterns FR détectés** : `Text\(['"]([A-Z][a-z]+.{5,})['"]\)`, `Text\(['"].*[éèêàôùç].*['"]\)`, `title:\s*['"][A-Z][a-z]+`, `label:\s*['"][A-Z][a-z]+`. Whitelist short technical strings : `['"][A-Z]{2,5}['"]` (acronymes), numéros `['"]\d+['"]`.
- **D-10** : Opt-in override : `// lefthook-allow:hardcoded-fr: <reason>` (ex : `debug-only`, `error-fallback`).

### GUARD-04 — accent_lint_fr (déjà existant, à activer)
- **D-11** : **Réutilise `tools/checks/accent_lint_fr.py` existant** (présent depuis Phase 30.5 pour CTX-02 drift rate). 14 patterns CLAUDE.md §2 : `creer`, `decouvrir`, `eclairage`, `securite`, `liberer`, `preter`, `realiser`, `deja`, `recu`, `elaborer`, `regler`, `prevoyance`, `reperer`, `cle`.
- **D-12** : **Scope** : `.dart`, `.py`, `app_fr.arb` (PAS les autres ARB — en/de/es/it/pt n'ont pas d'accents à enforcer). Fail hard sur match. Pas d'opt-in override (accent = bug par décret CLAUDE.md).

### GUARD-05 — arb_parity (6 ARB keyset)
- **D-13** : **Définition drift** : l'union des clés des 6 ARB (fr, en, de, es, it, pt) doit être identique à chaque keyset individuel. **Missing key anywhere = fail**. Extra key anywhere = fail. Placeholder type mismatch (ex : `{name}` vs `{name, number}`) = fail.
- **D-14** : Script `tools/checks/arb_parity.py` (nouveau, Phase 34). Utilise `json.load()` sur les 6 fichiers. Pas de dep ICU/intl (Python natif). Output `FAIL: key 'xxx' missing in {de, es}` avec diff lisible.
- **D-15** : **Grandfathering** : les clés orphelines côté Dart (1864 dead ARB keys per CONCERNS T5) ne sont PAS le scope de ce lint. GUARD-05 check parité cross-langue uniquement. Dead-key cleanup = déferré v2.9.

### GUARD-06 — proof_of_read (fallback léger, pas AST)
- **D-16** : **Convention commit footer** : `Read: .planning/phases/<phase>/<padded>-READ.md` présent dans commit message pour tout commit d'agent. Détecté par regex sur `git log -1 --format=%B`. Flag agent commits via `Co-Authored-By: Claude*`.
- **D-17** : **`tools/checks/proof_of_read.py`** (nouveau). Vérifie : (1) commit a `Co-Authored-By: Claude`, (2) message contient `Read:` trailer, (3) le fichier référencé existe sur disque. Fail sinon. Humain (no Claude trailer) : bypass automatique.
- **D-18** : **READ.md format** : liste bullet des fichiers consultés avec 1-ligne rationale par fichier. Convention : `- <path> — <why read>`. Pas de timestamp, pas de hash (simplicité).
- **D-19** : DIFF-04 (PreToolUse hook via Claude Agent SDK) reste déferré Phase 36 — GUARD-06 est le fallback explicite.

### GUARD-07 — bypass convention + audit
- **D-20** : **`--no-verify` devient interdit par convention** (pas techniquement bloqué — lefthook ne peut pas override git). Documentation CONTRIBUTING.md statue : "Utilisez `LEFTHOOK_BYPASS=1 git commit` pour bypass légitime, jamais `--no-verify`".
- **D-21** : **Audit CI post-merge** : nouveau job `.github/workflows/bypass-audit.yml` tourne sur schedule weekly (Monday 09:00 UTC) + post-merge to `dev`. Lit `git log --since="7 days ago"` sur `dev`, grep `LEFTHOOK_BYPASS=1` dans commit bodies + `--no-verify` marker si détectable. Alerte via GitHub issue auto-créée (`bypass-audit` label) si >3/week.
- **D-22** : Seuil 3/week retenu (success_criteria #4). Escalation manuelle — pas de bot auto-fix.

### GUARD-08 — CI thinning (10 checks migrent vers lefthook-first)
- **D-23** : **Migration plan** (liste exhaustive, 10 checks) :
  - **Vers lefthook** (fast, <1s chacun, ≤5s total) : `accent_lint_fr.py`, `no_hardcoded_fr.py` (nouveau), `no_bare_catch.py` (nouveau), `arb_parity.py` (nouveau), `proof_of_read.py` (nouveau), `memory_retention.py` (déjà), `no_chiffre_choc.py`, `landing_no_financial_core.py`, `landing_no_numbers.py`, `route_registry_parity.py`.
  - **Restent CI** (heavy) : `flutter test` full suite, `pytest -q` full backend suite, `flutter analyze`, `dart format --set-exit-if-changed`, `wcag_aa_all_touched.py`, readability gate (Flesch-Kincaid), PII scanner (si existe), contracts audit (OpenAPI), migrations check (Alembic).
  - **Supprimés de CI** (dupliqués par lefthook-first) : toutes les invocations explicites des 10 migrés ci-dessus dans `.github/workflows/*.yml`. Cible : -~2min CI time (success_criteria #5).
- **D-24** : **Double-run protection** : CI conserve un single job `lefthook-ci` qui exécute `lefthook run pre-commit --all-files --force` sur PR range. Catch les bypass + les commits d'un worktree avec lefthook pas installé. Pas de duplication lint-par-lint.

### Test strategy
- **D-25** : **Self-test script** : réutilise/étend `tools/checks/lefthook_self_test.sh` déjà présent. Ajoute 5 cas FAIL (un par nouveau lint) + 5 cas PASS. Run en CI comme smoke test.
- **D-26** : **Benchmark** : script `tools/checks/lefthook_benchmark.sh` (nouveau) mesure `lefthook run pre-commit` sur diff synthétique 5 Dart + 3 Python staged. P95 <5s. Run weekly comme regression guard.

### Claude's Discretion
- Structure interne des nouveaux scripts Python (`no_bare_catch.py`, `no_hardcoded_fr.py`, `arb_parity.py`, `proof_of_read.py`) : style argparse, logging, format d'erreurs — Claude flexible.
- Lefthook tags exactes (`[safety]`, `[i18n]`, etc.) — peut réorganiser pour lisibilité.
- Détail du self-test scenarios (fixtures, naming) — Claude flexible.
- Format de l'issue GitHub auto-créée par `bypass-audit.yml` — template simple laissé à Claude.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 34 spec + dependencies
- `.planning/ROADMAP.md` §Phase 34 — goal, 5 success criteria, budget 1.5 sem
- `.planning/REQUIREMENTS.md` §GUARD-01..08 — 8 requirements mappés 1:1, plus v2.8 coverage table (line 337-345)
- `.planning/phases/30.5-context-sanity/30.5-CONTEXT.md` §D-04 — skeleton lefthook scope, pose les rails, Phase 34 complète

### Kill-policy + autonomous profile
- `decisions/ADR-20260419-v2.8-kill-policy.md` — REQ table-stake unmet = feature KILLED via flag, pas v2.9 stabilisation
- `decisions/ADR-20260419-autonomous-profile-tiered.md` §L1 — Phase 34 profile L1 (meta/dev-tooling) : `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute, 0 UI simulator

### Compliance + banned terms (contexte pour no_hardcoded_fr)
- `CLAUDE.md` §🚨 TOP — 5 rules critiques (banned terms LSFin, accents 100%, i18n required)
- `CLAUDE.md` §2 — 14 patterns accents
- `docs/AGENTS/swiss-brain.md` §1 — full LSFin banned terms list

### Prior infra
- `lefthook.yml` (racine) — skeleton 30.5, 2 commandes actives (memory-retention-gate + map-freshness-hint)
- `tools/checks/accent_lint_fr.py` — lint déjà existant, GUARD-04 = activation
- `tools/checks/memory_retention.py` — pattern de référence pour nouveaux lints Python
- `tools/checks/route_registry_parity.py` — pattern pour multi-file parity check (utile pour arb_parity.py)
- `.planning/codebase/CONCERNS.md` §T5 — 1864 dead ARB keys (grandfathered hors GUARD-05 scope)

### CI workflow files
- `.github/workflows/` — localisation des 10 invocations à supprimer (CI thinning GUARD-08)
- `CONTRIBUTING.md` — documentation LEFTHOOK_BYPASS à ajouter (GUARD-07 D-20)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`lefthook.yml` skeleton** — 30.5 scaffold avec `min_version: 2.1.5`, `skip: [merge, rebase]`, 2 commandes de référence. **D-01** : on ajoute par-dessus, on ne recrée pas.
- **`tools/checks/accent_lint_fr.py`** — lint complet, 14 patterns, prêt pour GUARD-04 (D-11). Zéro code neuf pour ce requirement.
- **`tools/checks/memory_retention.py`** — pattern Python exemplaire (argparse, exit codes 0/1, structured errors). À copier pour les 4 nouveaux lints.
- **`tools/checks/route_registry_parity.py` + `.planning/codebase/` patterns** — modèle pour `arb_parity.py` (multi-file JSON diff).
- **`tools/checks/lefthook_self_test.sh`** — smoke test structure, à étendre (D-25) pas à recréer.

### Established Patterns
- **Python lints exit codes** : 0 = pass, 1 = fail avec stderr message. Pas de codes custom. (pattern `memory_retention.py`)
- **Lefthook glob scoping** : toujours `glob: "*.{dart,py}"` ou similar, jamais full-repo. (pattern skeleton)
- **Lint naming** : `tools/checks/<noun>_<modifier>.py` (ex : `no_hardcoded_fr.py`, `accent_lint_fr.py`). Snake_case, descriptif.
- **Commit trailers** : projet utilise déjà `Co-Authored-By: Claude*` (per `MEMORY.md` + mint-commit skill) — GUARD-06 D-16 hook sur ce trailer existant.
- **CLAUDE.md discipline** : 14 accent patterns canoniques déjà listés (§2) — D-11 source of truth scellée.

### Integration Points
- **`lefthook.yml` pre-commit** — l'unique point d'ajout, 5 nouvelles commandes par-dessus les 2 existantes (total 7 commandes pre-commit).
- **`.github/workflows/*.yml`** — 10 jobs/steps à retirer (GUARD-08 D-23). Créer 2 nouveaux : `lefthook-ci.yml` (D-24) et `bypass-audit.yml` (D-21).
- **`CONTRIBUTING.md`** — nouvelle section "Pre-commit hooks" expliquant install + bypass convention (GUARD-07 D-20).
- **`tools/checks/`** — 4 nouveaux scripts : `no_bare_catch.py`, `no_hardcoded_fr.py`, `arb_parity.py`, `proof_of_read.py`. Un script par PR recommandé (review granularity).

### Duplicates to watch (iCloud sync artifacts)
- `tools/checks/` contient des fichiers " 2.py" et " 3.py" dupliqués (iCloud Drive). **NOT canonical**. Ignorer. Si nettoyage nécessaire, file en backlog (hors scope Phase 34).
- `.lefthook/route_registry_parity 2.sh` et ` 3.sh` idem.

</code_context>

<specifics>
## Specific Ideas

- **Budget <5s absolu strict** — success_criteria #1 mesuré sur M-series Mac. Si on dépasse, priorité est de **paralléliser davantage** (parallel: true per tag) avant de sacrifier un lint. Si toujours >5s → déplacer un lint à CI (violating the thinning spirit mais préservant le DX feedback).
- **GUARD-02 diff-only** (D-07) est la décision la plus importante — elle découple Phase 34 de Phase 36 FIX-05. Sans ça, Phase 34 blockerait sur 388 fixes de bare-catches. Avec ça, Phase 34 ship standalone, Phase 36 converge progressivement.
- **Pas de reliance sur AST Dart/Python** — D-05, D-09 : regex-first. Raisons : (1) pas de dep tree-sitter, (2) debug/review facile, (3) performance stable <1s. Trade-off accepté : false positives possibles, opt-in override inline.
- **`LEFTHOOK_BYPASS=1` est la seule convention officielle** (D-20). `--no-verify` reste techniquement fonctionnel mais **jamais documenté comme option**. Agents doivent apprendre `LEFTHOOK_BYPASS` via CLAUDE.md §4 Dev rules (à ajouter Phase 34 DOC task).

</specifics>

<deferred>
## Deferred Ideas

- **FIX-05 migration des 388 bare-catches → 0** — Phase 36 explicite. Backend 56 d'abord (pattern simple), mobile 332 batched 20/PR. Hors scope.
- **FIX-07 fix accents résiduels** — Phase 36. GUARD-04 prevents régression, FIX-07 convergence.
- **FIX-06 MintShell ARB parity 6 langs audit** — Phase 36. GUARD-05 est le gate, FIX-06 fait l'audit complet initial.
- **DIFF-04 PreToolUse proof-of-read via Claude Agent SDK** — Phase 36 (ou v2.9). GUARD-06 est le fallback léger explicite en attendant.
- **Cleanup des 1864 dead ARB keys** — déferré v2.9. GUARD-05 check parité cross-langue seulement, pas orphelin côté Dart.
- **Cleanup des " 2.py" / " 3.py" iCloud duplicates** — backlog. Risque nul sur Phase 34.
- **Pre-push hooks, commit-msg hooks, post-checkout hooks** — hors scope Phase 34. Si utile, ouvrir phase v2.9.
- **Lefthook en-CI via `lefthook run pre-commit --all-files` sur un worktree dockerisé** — considéré (D-24 retient une version light), version complète = v2.9.
- **Migration vers Husky / pre-commit (Python)** — écarté, lefthook est le choix acté (kill-policy ADR : 1 outil, pas de multi).
- **Proof-of-read via SHA hash des fichiers lus** — écarté D-18 (complexité hors phase). Fallback texte suffisant.

### Reviewed Todos (not folded)
None — no pending todos matched Phase 34 scope at match-phase time.

</deferred>

---

*Phase: 34-agent-guardrails-m-caniques*
*Context gathered: 2026-04-22 (discuss --auto, Claude picked recommended defaults)*
*Decisions: 26 locked (D-01 → D-26), 0 open gray areas — requirements GUARD-01..08 sont prescriptifs*
*Next step: `/gsd-plan-phase 34 --auto`*
