## 🔖 Commit hygiene reminder (CLAUDE.md §5 DEV RULES)

Avant de committer :

- **Branche** : `feature/S{XX}-<slug>` depuis `dev`. **JAMAIS** direct sur `main`/`staging`. **JAMAIS** force push. Toujours `--rebase` on pull.
- **Format** : conventional commits — `feat(scope): ...`, `fix(scope): ...`, `docs(scope): ...`.
- **Pre-commit gate** : lefthook runs `memory-retention-gate`, `accent_lint_fr.py`, `no_hardcoded_fr.py`. Phase 34 → `no_bare_catch.py` (GUARD-02).
- **No bare catches** : `catch (e) {}` ou `except Exception:` sans log/rethrow = forbidden.
- **Bypass** : `LEFTHOOK_BYPASS=1 git commit` (grep-able, GUARD-07). **JAMAIS** `--no-verify`.
- **Sign-off** : `Co-Authored-By: Claude <noreply@anthropic.com>` si agent-drafted.
- **PR flow** : feature → dev (squash), dev → staging (merge), staging → main (merge).

Détail : `rules.md` + `docs/CICD_ARCHITECTURE.md`.
