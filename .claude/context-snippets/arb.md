## 📋 ARB parity reminder (CLAUDE.md triplet #1 i18n)

Tu édites un fichier `.arb`. Checklist obligatoire :

- **6 langues** : fr (template), en, de, es, it, pt. Ajoute la nouvelle clé aux SIX fichiers `apps/mobile/lib/l10n/app_*.arb`, **à la FIN** (avant le `}`).
- **Regenerate** : `cd apps/mobile && flutter gen-l10n` après édition.
- **Diacritiques FR mandatory** : `é è ê ô ù ç à` — un `e` ASCII à la place de `é` = bug. `creer → créer`, `eclairage → éclairage`, `decouvrir → découvrir`.
- **Espace insécable** (`\u00a0`) avant `!`, `?`, `:`, `;`, `%` en FR.
- **Jamais de string hardcodée** dans un widget Dart : toujours `AppLocalizations.of(context)!.key`.
- **Lefthook gates HARD (post PR #551, 2026-05-10)** : si tu touches un `.arb`, deux gates BLOQUENT le commit :
  - `banned_terms_arb_gate` — refuse termes LSFin (`garanti`/`guaranteed`/`garantiert`/...) en contexte positif.
  - `arb_parity_gate` — refuse drift de clés vs FR référence sur les 5 autres locales.
- **Lints existants mais NON wired pre-commit** (deferred Phase 34) : `accent_lint_fr.py` (282 violations existantes), `no_hardcoded_fr.py` (5034). Tournent en CI sur les paths CI ; pas en local. Pour t'auto-vérifier : `python3 tools/checks/accent_lint_fr.py --file <ton_fichier>`.

Drift fréquent : ajouter la clé à `app_fr.arb` seulement, oublier les 5 autres → `arb_parity_gate` bloque le commit (rejet immédiat, pas CI).

Détail : `docs/AGENTS/flutter.md §3 i18n`.
