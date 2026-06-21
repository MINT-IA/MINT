# Mint Cleanup / Account Lifecycle Handoff Prompt

Use this prompt in a fresh session. Do not start another product matrix before
this cleanup is complete.

```text
Tu reprends MINT dans:
WORKTREE=/Users/julienbattaglia/Desktop/MINT.nosync
BRANCH=qa/runtime-navigation-spine-20260602
BASE_COMMIT=3d289b6b04256eb9cc9f0bad723b2ac85ad823ba

Objectif unique:
Fermer proprement le chantier d'hygiène repo/planning/review avant de reprendre
Mint 2.0 account lifecycle. Le but n'est PAS d'ajouter une nouvelle matrice:
le but est de classer, fermer, archiver et rendre le prochain travail atomique.

Préflight obligatoire, avant toute mutation:
- pwd
- git rev-parse --show-toplevel
- git symbolic-ref --short HEAD
- git rev-parse HEAD
- git status --short
- git diff --shortstat
- git worktree list
- du -sh . .git .claude .claude/worktrees .planning apps services tools 2>/dev/null || true

Assertions STOP après préflight:
- Si `git rev-parse --show-toplevel` n'est pas exactement `WORKTREE`, STOP.
- Si `git symbolic-ref --short HEAD` n'est pas exactement `BRANCH`, STOP.
- Si `git rev-parse HEAD` n'est ni `BASE_COMMIT` ni un descendant direct de
  `BASE_COMMIT`, STOP et reporte HEAD/BASE/status. Ne pas merge/rebase/pull.
- Si le worktree contient des changements non listés dans l'état connu ci-dessous,
  STOP et reporte la différence. Ne pas supposer qu'ils sont sûrs.
- Si `git worktree list` montre des worktrees inattendus ou dirty/locked dans un
  état non documenté, STOP et reporte. Ne pas nettoyer.

Contraintes:
- Aucun reset, stash, pull, rebase, restore, checkout destructif, switch,
  `git clean`, `rm -rf`, ou nettoyage manuel de worktree.
- Aucun `git add .`.
- Aucun push/merge.
- Ne pas exécuter dans un autre worktree.
- Ne pas supprimer `.claude/worktrees` à la main.
- Ne pas déplacer manuellement `.claude/worktrees` avec `mv`; utiliser seulement
  des commandes `git worktree` après preuve et GO explicite.
- Ne pas archiver de phase sans preuve de statut.
- Ne pas ouvrir de nouvelle phase/matrice produit pendant ce cleanup.
- Tout staging doit être explicite par fichier.

Contexte sauvegardé dans Engram:
- "Mint lifecycle routing Slice A"
- "Mint account lifecycle Slice 0"
- "Mint planning and Claude review hygiene audit"
- "Cleanup should run in fresh session"

Engram obligatoire en début de session:
- Appeler `mem_context(project="mint")`.
- Appeler `mem_search(project="mint", query="Mint lifecycle routing Slice A")`.
- Appeler `mem_search(project="mint", query="Mint planning and Claude review hygiene audit")`.
- Appeler `mem_get_observation` pour les IDs correspondants, notamment si trouvés:
  - #2241 `Mint first experience lifecycle matrix reviewed`
  - #2243 `Mint lifecycle routing Slice A`
  - #2245 `Mint planning and Claude review hygiene audit`
  - #2247 `Cleanup should run in fresh session`
- Si Engram est indisponible:
  - suspendre les étapes qui dépendent d'Engram;
  - continuer uniquement avec ce prompt comme contexte de fallback;
  - exiger des preuves locales file:line pour toute classification;
  - ne rien classifier/archiver si la preuve locale manque.
- Lire les résultats avant de classifier ou modifier quoi que ce soit.

État connu au moment du handoff:
- HEAD: 3d289b6b04256eb9cc9f0bad723b2ac85ad823ba
- Branch: qa/runtime-navigation-spine-20260602
- Worktree dirty: environ 43 fichiers modifiés, ~3679 insertions, ~2322 deletions,
  plus des fichiers non suivis.
- Repo ~16G.
- `.claude/worktrees` ~5.8G, 11 worktrees locked, plus gros ~2.1G:
  `.claude/worktrees/codex-mint-diagnostic-onboarding-v1-route`.
- `.planning/phases` contient 76 dossiers; beaucoup ont `SUMMARY.md`.
- `.planning/milestones` n'a que `v2.0-phases` et `v2.1-phases`.
- `.planning/STATE.md` est stale: il pointe encore sur Core Journey Truth,
  pas sur le chantier account lifecycle / hygiene actuel.
- Le worktree courant est `qa/runtime-navigation-spine-20260602`, alors que des
  travaux Mint2 récents ont aussi vécu dans `/Users/julienbattaglia/Desktop/MINT.foundation-clean.nosync`
  sur `feature/S11-mint2-profile-value-ledger`. Ne mélange pas les worktrees.

Travail déjà réalisé dans cette session précédente:
1. Matrice active:
   `.planning/phases/mint-first-experience-account-lifecycle/EXECUTABLE_MATRIX.md`
   avec statut `agent-reviewed-claude-timeout-ready-for-slice-0`.
2. Claude Max:
   `.planning/phases/mint-first-experience-account-lifecycle/CLAUDE_MAX_REVIEW.md`
   documente deux timeouts sans verdict substantiel.
3. Backend Apple auth:
   `services/backend/app/api/v1/endpoints/auth.py`
   vérifie Apple JWKS/RS256/aud/iss/exp/iat/nonce.
   Test: `services/backend/tests/test_auth_apple.py`.
4. Mobile lifecycle:
   `apps/mobile/lib/models/auth_lifecycle_state.dart`
   `apps/mobile/lib/providers/auth_provider.dart`
   `apps/mobile/lib/app.dart`
   Tests:
   - `apps/mobile/test/navigation/account_lifecycle_public_entry_redirect_test.dart`
   - `apps/mobile/test/navigation/home_gate_contract_test.dart`
   - lifecycle tests in `apps/mobile/test/providers/auth_provider_test.dart`
5. Tests verts précédents:
   Ces résultats sont une preuve historique de contexte, pas une vérification
   courante. Toute session qui modifie les fichiers doit relancer ses propres
   checks ciblés.
   - `flutter test test/navigation/account_lifecycle_public_entry_redirect_test.dart`
   - `flutter test test/navigation/home_gate_contract_test.dart`
   - `flutter test test/providers/auth_provider_test.dart --plain-name "lifecycle"`
   - `flutter analyze`
   - `git diff --check` (CRLF warnings connus sur localizations générées)
   - backend targeted Apple auth tests / ruff / pytest étaient verts avant la compaction.

Cause Claude Max lenteur / review hygiene:
- Claude minimal n'est pas lent; le blocage vient de l'enveloppe MINT.
- `~/.claude/settings.json` force `claude-opus-4-8[1m]` + `effortLevel: xhigh`.
- `.claude/settings.json` active Agent Teams et de nombreux hooks.
- `.planning/config.json` utilise `model_profile: quality`, `cross_ai_timeout: 600`,
  `subagent_timeout: 600000`.
- Le diff courant est trop gros pour une review fréquente.
- `.claude/worktrees` peut ralentir les scans filesystem.
- `tools/claude_review.sh` existe déjà et doit être le chemin standard:
  Sonnet par défaut, diff borné à 12KB, tools désactivés, pas de session persistence,
  JSON output.
- Claude Max Opus/xhigh est réservé aux reviews profondes de PR propres,
  diff atomique, timeout minimum 30 minutes.

Plan d'exécution attendu:

Étape 1 — Inventory sans mutation:
- Lire AGENTS.md, CLAUDE.md, docs/MINT_AGENT_WORKFLOW.md si présent.
- Lire `.planning/STATE.md`, `.planning/MILESTONES.md`, `.planning/config.json`.
- Inventorier `.planning/phases`:
  - dossier
  - présence SUMMARY/DONE/VALIDATION/PLAN/CONTEXT/EXECUTABLE_MATRIX
  - statut inféré: active, executed, superseded, abandoned/unknown
  - raison courte
- Inventorier `.claude/worktrees`:
  - path
  - taille
  - branch
  - HEAD
  - locked/unlocked
  - dirty/clean si accessible
  - statut attendu/inattendu par rapport au handoff
- Inventorier le diff dirty en lots:
  - lifecycle/auth
  - backend auth/apple
  - planning/handoff
  - l10n/generated
  - anonymous/chat/auth UI préexistants
  - tooling/config

Étape 2 — Produire un manifeste avant patch:
Créer `.planning/handoffs/mint-cleanup-2026-06-21/CLEANUP_MANIFEST.md`
avec:
- Current git/worktree state.
- Active matrix ledger:
  - `mint-first-experience-account-lifecycle`: Slice 0 done à vérifier par
    file:line ou Engram avant classification finale; Slice A partial/done à
    vérifier de la même façon; classer `active/partial` si la preuve manque.
    Reste attendu: Apple sub/revoke, delete/relaunch, Maestro/network-spy.
- Phase classification table.
- Worktree classification table.
- Proposed commits, chacun atomique.
- Explicit files allowed per commit.
- Risks and STOP conditions.

STOP ici et reporte le manifeste si une classification est ambiguë.

Seuils mécaniques de classification:
- `active`: dossier explicitement désigné comme chantier courant dans
  `.planning/STATE.md`, dans ce prompt, ou dans le manifeste.
- `executed`: preuve file:line ou Engram explicite, présence d'un `SUMMARY.md`
  ou `*-SUMMARY.md` de phase, et aucun
  marqueur évident `BLOCKED`, `STOP`, `TODO unresolved`, `pending operational gate`
  non reporté dans le manifeste.
- `superseded`: dossier remplacé par un chantier plus récent avec référence
  explicite dans le manifeste.
- `archive-candidate`: `executed` + destination d'archive claire.
- `unknown`: tout le reste. Les dossiers `unknown` ne bougent pas.
- Si `Slice A partial/done` ne peut pas être prouvé par file:line ou Engram,
  le classer `active/partial`, pas `executed`.

Étape 3 — Patch minimal seulement après manifeste:
Autorisé:
- Mettre à jour `.planning/STATE.md` pour refléter le chantier actif réel:
  `mint-first-experience-account-lifecycle` / cleanup.
- Ajouter un registre planning si utile:
  `.planning/PHASE_REGISTRY.md` ou
  `.planning/handoffs/mint-cleanup-2026-06-21/CLEANUP_MANIFEST.md`.
- Ne pas déplacer/archiver de phase dans ce premier commit cleanup. Reporter
  seulement les candidats éventuels dans le manifeste; tout mouvement demande
  une passe séparée avec preuves file:line, Review Agent, Claude ciblé et GO
  explicite.

Interdit dans ce premier cleanup:
- supprimer `.claude/worktrees`;
- déplacer 76 dossiers d'un coup;
- modifier du code produit;
- mélanger cleanup planning et lifecycle/auth implementation;
- corriger des tests non liés.

Étape 4 — Review Agent obligatoire:
Avant commit, préparer une review ciblée:

Review Agent prompt:
You are reviewing a repository/planning hygiene cleanup for MINT.
Scope only:
- `.planning/STATE.md`
- `.planning/handoffs/mint-cleanup-2026-06-21/*`
- any phase registry/archive manifest touched in this cleanup
Do not review the full repo. Do not review product code unless changed in this cleanup.
Check:
- no destructive git guidance;
- no accidental product scope;
- phase classification is evidence-based;
- active matrix closure is clear;
- Claude review policy is practical and bounded;
- proposed commits are atomic and reversible;
- no instruction says to use `git add .`, reset, stash, blind delete, or full-repo Claude Max.
Output:
- Critical findings
- Important findings
- Minor findings
- Ready/Not ready for cleanup commit

Claude targeted review:
Précheck:
- `test -f tools/claude_review.sh`
- Si le script existe mais n'est pas exécutable, utiliser `bash tools/claude_review.sh`.
- Si le script est absent ou échoue avant d'appeler Claude, documenter la sortie
  exacte et ne pas élargir le scope.

Use:
`MINT_CLAUDE_MODEL=sonnet MINT_CLAUDE_TIMEOUT=900 MINT_CLAUDE_MAX_BYTES=12000 tools/claude_review.sh -- .planning/handoffs/mint-cleanup-2026-06-21 .planning/STATE.md`

If Claude review returns empty/times out:
- capture exact command, timeout, stderr/stdout summary;
- do not retry with a larger scope;
- proceed only with local Review Agent/self-review if the diff is tiny and tests/checks pass.

GO gate:
- Après Review Agent + Claude targeted review + vérifications, STOP.
- Reporter les résultats et attendre un GO explicite utilisateur avant tout commit.

Étape 5 — Verification:
Mandatory:
- `git diff --check`
- `git status --short`
- targeted review command above, or documented failure
- no product tests required unless product code changed

Optional if code touched by mistake:
- STOP and report before continuing.

Commit policy:
- No commit unless user explicitly says GO in the new session.
- If committing, use explicit staging only.
- Suggested commit message if only planning/hygiene docs changed:
  `chore(planning): close mint cleanup handoff`

Final expected:
- HEAD/branch/status before and after.
- What was classified.
- What was changed.
- What remains open.
- Claude targeted review result.
- Review Agent result.
- GO/NO-GO for resuming account lifecycle + Maestro.
- Clarifier explicitement que ce GO/NO-GO n'est pas une autorisation de commit,
  push, merge, clean ou suppression; ces actions demandent un GO utilisateur
  séparé et explicite.
```

## Review Agent Micro-Prompt

Use this only to review the handoff prompt above, not the whole repo:

```text
You are a Review Agent. Review only:
`.planning/handoffs/mint-cleanup-2026-06-21/PROMPT.md`

Assess whether this prompt is safe and executable for a fresh cleanup session.

Context:
- MINT repo is dirty and large.
- Current problem is planning/review/worktree hygiene, not product feature work.
- Claude Max has timed out because reviews were too broad; routine reviews must use
  `tools/claude_review.sh` with Sonnet, explicit paths, tools disabled, and bounded diff.

Check for:
1. Clear preflight and STOP conditions.
2. No destructive operations.
3. No blind deletion of `.claude/worktrees`.
4. No `git add .`.
5. No accidental full-repo Claude Max review.
6. Correct separation between cleanup, lifecycle/auth implementation, and Maestro work.
7. Enough context to continue from Engram and local files without reopening a new matrix.

Return:
- Critical findings
- Important findings
- Minor findings
- Verdict: ready / ready with fixes / not ready
```
