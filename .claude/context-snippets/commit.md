## 🔖 Commit hygiene reminder (CLAUDE.md §5 DEV RULES)

Avant de committer :

- **Branche** : `feature/S{XX}-<slug>` depuis `dev`. **JAMAIS** direct sur `main`/`staging`. **JAMAIS** force push. Toujours `--rebase` on pull.
- **Format** : conventional commits — `feat(scope): ...`, `fix(scope): ...`, `docs(scope): ...`.
- **Pre-commit gate (réel post PR #551, 2026-05-10)** : lefthook runs HARD = `memory-retention-gate`, `wiki-lint` (sur `.planning/**/*.md`), `banned-terms-arb-gate` (sur `*.arb`), `arb-parity-gate` (sur `*.arb`). SOFT-warn = 5 design lints `prefer-mint-*`. HINT = `map-freshness-hint`. **PAS en lefthook** (deferred Phase 34 GUARD-* restant) : `accent_lint_fr.py` (282 violations existantes), `no_hardcoded_fr.py` (5034), `no_bare_catch.py` (script absent). Mesure replay 2026-05-10 : block-rate 0/50 pour les 2 actifs ; 46-52% pour les 2 deferred.
- **No bare catches** : `catch (e) {}` ou `except Exception:` sans log/rethrow = forbidden.
- **Bypass** : `LEFTHOOK_BYPASS=1 git commit` (grep-able, GUARD-07). **JAMAIS** `--no-verify`.
- **Sign-off** : `Co-Authored-By: Claude <noreply@anthropic.com>` si agent-drafted.
- **PR flow** : feature → dev (squash), dev → staging (merge), staging → main (merge).

Détail : `rules.md` + `docs/CICD_ARCHITECTURE.md`.
