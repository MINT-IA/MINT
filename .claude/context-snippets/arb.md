## 📋 ARB parity reminder (CLAUDE.md triplet #1 i18n)

Tu édites un fichier `.arb`. Checklist obligatoire :

- **6 langues** : fr (template), en, de, es, it, pt. Ajoute la nouvelle clé aux SIX fichiers `apps/mobile/lib/l10n/app_*.arb`, **à la FIN** (avant le `}`).
- **Regenerate** : `cd apps/mobile && flutter gen-l10n` après édition.
- **Diacritiques FR mandatory** : `é è ê ô ù ç à` — un `e` ASCII à la place de `é` = bug. `creer → créer`, `eclairage → éclairage`, `decouvrir → découvrir`.
- **Espace insécable** (`\u00a0`) avant `!`, `?`, `:`, `;`, `%` en FR.
- **Jamais de string hardcodée** dans un widget Dart : toujours `AppLocalizations.of(context)!.key`.
- **Lints** : `tools/checks/accent_lint_fr.py` + `tools/checks/no_hardcoded_fr.py` (early-ship 30.5).

Drift fréquent : ajouter la clé à `app_fr.arb` seulement, oublier les 5 autres → ARB parity CI fail.

Détail : `docs/AGENTS/flutter.md §3 i18n`.
