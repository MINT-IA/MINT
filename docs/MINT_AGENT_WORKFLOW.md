# MINT Agent Workflow

Document repo-local pour ne plus re-prompter la doctrine agents à chaque session. Il complète `AGENTS.md` et `CLAUDE.md`; il ne les remplace pas.

## 1. Purpose / principe non négociable

MINT avance par flux utilisateur prouvé, pas par architecture décorative.

Avant toute affirmation d'état final : l'utilisateur ouvre l'app, fait une action précise, voit un résultat précis, et ce résultat est défendable.

Pour toute surface financière :
- aucun chiffre visible sans provenance ;
- aucun calcul hors source canonique ;
- aucun élargissement avant un parcours robuste sur iPhone 13 mini ;
- aucun chat utilisé pour masquer un flux de base illisible ;
- aucune conclusion d'agent sans preuve fraîche.

Tout chiffre visible porte au minimum : valeur ou fourchette, unité, hypothèses, sources, confiance/readiness, champs manquants, version du calcul ou des constantes.

## 2. Source of truth hierarchy

Ordre d'autorité pour l'intention produit, la doctrine et les contraintes :
1. `rules.md`, si présent.
2. `CLAUDE.md`.
3. `AGENTS.md`.
4. `.planning/ACTIVE_CONTEXT.md` et `.planning/ACTIVE_CONTEXT.json`.
5. `.planning/STATE.md`.
6. `.planning/decisions/*.md` et `.planning/phases/*/CONTEXT.md`.
7. Docs de domaine : `docs/calculator-graph.md`, `docs/data-flow.md`, `docs/coach-tool-routing.md`, `docs/ROUTE_POLICY.md`.
8. Code source actuel, tests et scripts, pour le comportement observable.
9. Skills et commandes : `.agents/skills/*`, `.claude/skills/*`, `.claude/commands/gsd/*`.
10. Rosters : `.claude/agents/*.md`; `.codex/agents/*.toml` seulement si ce
   dossier existe dans le checkout. Sinon les agents Codex sont fournis par la
   session et doivent être découverts via les outils disponibles, pas inventés
   comme fichiers repo.
11. Engram MCP, projet `mint`, comme mémoire de décisions et découvertes.

Engram évite de redécouvrir. Il ne surpasse jamais le repo.
Si doc et code divergent, ne pas choisir par intuition : citer les deux chemins, ouvrir un finding, puis corriger la source fautive.

Autorisation d'outillage : quand l'objectif courant est autorisé, les agents
peuvent utiliser sans redemande les outils nécessaires à la preuve et à la
livraison : Engram MCP, skills locales, checks repo, commandes GitHub de lecture
ou de PR, pushes de branches feature, panels de spécialistes, Maestro, `simctl`,
`idb`, xcodebuildmcp / Build iOS Apps si exposés. Les exceptions restent celles
de `rules.md` : branches protégées, merge, opérations Git destructrices,
données réelles, claims juridiques/compliance, nouvelles sources financières
réglementées.

Claude Max est advisory. L'utiliser si un CLI/session local ou un artefact
d'audit frais est disponible et utile au risque du travail. Son absence ne
bloque pas sauf gate explicite de Julien; dans ce cas, dire clairement
`Claude Max indisponible` au lieu de substituer un panel local.

Accès skills : les agents ont l'autorisation explicite et autonome de lire et
d'utiliser tous les skills nécessaires lorsque les chemins existent et sont
lisibles : `.agents/skills`, `.claude/skills`, `.codex/skills`,
`~/.codex/skills`, `~/.agents/skills`, et les caches de plugins exposés par la
session. Ne pas redemander une permission par skill. Ne pas déclarer un repo de
skills inaccessible sans avoir testé le chemin concret. Si un chemin est
illisible, citer le chemin exact et utiliser le fallback local le plus adapté.

Cette autorisation ne change pas l'autorité produit : un skill est méthode et
outillage, jamais source produit supérieure au worktree approuvé, aux règles
checked-in, au code courant, aux tests locaux et aux preuves runtime.

Current phase pointer lives in `.planning/ACTIVE_CONTEXT.md`,
`.planning/ACTIVE_CONTEXT.json`, and `.planning/STATE.md`. As of 2026-06-14,
product code is frozen until `.planning/phases/mint-karpathy-rules-infra-20260614/`
has installed Spec -> Verifier -> Environment guardrails, then Mint 2.0 continues through
`.planning/phases/mint-2-0-first-experience-rente-capital/`.

Sources de calcul :
- L1 chiffrer mobile : `apps/mobile/lib/services/financial_core/`.
- L2-L4 comparer, éclairer, invariants : `services/backend/app/services/`.
- Frontière : `services/backend/app/models/lucidity/_payload.py`.
- Constantes réglementaires backend : `services/backend/app/services/regulatory/registry.py`.

Vérifier le roster actif :

```bash
find .claude/agents -maxdepth 1 -type f | sort
test -d .codex/agents && find .codex/agents -maxdepth 1 -type f | sort || true
```

## 3. Stable agent roster by responsibility

| Responsabilité | Agents / outils de référence |
|---|---|
| Stratégie, recherche, contexte | `context-manager`, `product-manager`, `business-analyst`, `ux-researcher`, `market-researcher`, `competitive-analyst`, `search-specialist` |
| Documentation | `technical-writer`, `docs-architect`, `api-documenter`, `tutorial-engineer` |
| Planification | GSD, `gsd-planner`, `gsd-plan-checker`, `gsd-nyquist-auditor` |
| Flutter | `flutter-expert`, `frontend-developer`, `mobile-developer`, skill `mint-flutter-dev` |
| Backend | `backend-architect`, `fastapi-pro`, `python-pro`, skill `mint-backend-dev` |
| IA coach | `ai-engineer`, `prompt-engineer`, `llm-architect`, `nlp-engineer`, `ai-writing-auditor` |
| Données | `database-architect`, `database-optimizer`, `postgres-pro`, `sql-pro` |
| Sécurité / conformité | `security-auditor`, `backend-security-coder`, `frontend-security-coder`, `mobile-security-coder`, `threat-modeling-expert` |
| Review | Codex review, `code-reviewer`, `architect-review`, `qa-expert`, `test-automator` |
| Runtime | `gsd-verifier`, `gsd-ui-checker`, `ui-visual-validator`, `ui-ux-tester`, Codex Build iOS Apps / xcodebuildmcp si disponible, Maestro |
| Release | `git-workflow-manager`, `devops-troubleshooter`, `observability-engineer`, `performance-engineer` |

Périmètres : Flutter reste dans `apps/mobile/`; backend reste dans `services/backend/`, `tools/openapi/`, `SOT.md`; documentation reste dans les fichiers demandés. Le roster Claude sous `.claude/agents/*.md` est repo-local. Un miroir Codex sous `.codex/agents/*.toml` est valide seulement s'il existe dans le checkout; sinon Codex utilise les agents exposés par la session.

## 4. Standard phase lifecycle

1. Restore context.

```bash
git status --short --branch
MEM="$HOME/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/MEMORY.md"
test -f "$MEM" && sed -n '1,220p' "$MEM" || echo "MEMORY.md introuvable: fallback Engram MCP + repo docs"
sed -n '1,220p' CLAUDE.md
sed -n '1,260p' AGENTS.md
sed -n '1,220p' .planning/ACTIVE_CONTEXT.md
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
```

Puis `mem_context(project="mint")` et
`mem_search(query="<zone touchée>", project="mint")`. `mem_current_project`
peut aider au diagnostic, mais le protocole de reprise ne dépend pas de lui.
Si la mémoire curateur est absente, ne pas stopper automatiquement : continuer
avec Engram MCP et les règles checked-in, puis noter le trou dans le rapport.

2. Lire le doc de domaine avant code : coach -> `docs/coach-tool-routing.md`; profil/scan/budget -> `docs/data-flow.md`; calcul -> `docs/calculator-graph.md`; route -> `apps/mobile/lib/routes/route_metadata.dart`; i18n -> `apps/mobile/lib/l10n/app_*.arb`.

3. Ouvrir une phase GSD.

```bash
/gsd:plan-phase <slug>
/gsd:execute-phase <slug>
/gsd:verify-work <slug>
```

Équivalents Codex skills : `$gsd-plan-phase <slug>`, `$gsd-execute-phase <slug>`, `$gsd-verify-work <slug>`.

4. Spec -> Verifier -> Environment avant implémentation :
   - `SPEC.md` définit promesse utilisateur, non-goals, forbidden outputs,
     provenance, fixtures et critères d'acceptation ;
   - `VERIFICATION.md` liste les commandes et preuves fraîches requises ;
  - `rules.md`, hooks, CI, Engram et simulateur forment l'environnement.
   - `python3 tools/checks/verify_phase_acceptance.py` exécute le bloc
     `verify` du `SPEC.md` actif et produit le verdict déterministe de base.
   Ensuite seulement : test rouge ou contrat d'entrée/sortie, golden I/O pour
   tout chemin LLM, flag ou kill switch, callsites listés avec `rg`, source
   canonique du calcul nommée.

5. Implémentation par Claude : tâches courtes, atomiques, vérifiables. Utiliser `subagent-driven-development` si les tâches sont indépendantes : un sous-agent frais par tâche, revue spec, revue qualité, correction avant tâche suivante.

6. Codex review.

```bash
git diff --stat
git diff -- docs apps/mobile services/backend tools/openapi SOT.md
git diff --check
```

Codex cherche bugs, régressions, chiffres nus, i18n manquante, calcul hors source canonique, ARB désynchronisés, façade sans câblage, tests faibles, claims non prouvés.

7. Claude red-team : reprendre uniquement les findings acceptés. Un finding = une correction. Pas de refactor opportuniste, pas de nouvelle surface, test du bug avant correction quand possible.

8. Runtime gate.

```bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT/apps/mobile"
flutter analyze
flutter test
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1
cd "$ROOT"
bash tools/simulator/maestro_env.sh --version
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/<flow>.yaml
```

9. Engram/session summary, puis git seulement après diff relu et gates citables.

Guards de workflow à citer avant tout commit infra :

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
python3 tools/checks/verify_phase_acceptance.py
```

## 5. Claude CLI invocation protocol

Version locale vérifiée : `claude --version` retourne `2.1.170 (Claude Code)`.

Settings utilisateur : `~/.claude/settings.json` définit `model: claude-opus-4-8[1m]`; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` est actif; Engram MCP est autorisé. `.planning/config.json` contient les clés top-level `cross_ai_timeout=600` et `subagent_timeout=600000`.

Inspection : `claude --version`, `claude --help`, `claude mcp list`.

Session interactive : `ROOT="$(git rev-parse --show-toplevel)" && cd "$ROOT" && claude --permission-mode acceptEdits`.

Tâche bornée non interactive :

```bash
claude -p \
  --output-format stream-json \
  --permission-mode acceptEdits \
  --effort xhigh \
  --append-system-prompt "Respecte CLAUDE.md, AGENTS.md et le périmètre demandé." \
  "Tâche: <objectif borné>. Retourne diff résumé, commandes lancées, risques."
```

Agent explicite :

```bash
claude -p --agent code-reviewer --output-format json \
  --permission-mode acceptEdits \
  --allowedTools Read,Grep,Glob,Bash \
  "Review le diff courant contre origin/dev. Findings seulement, avec fichiers/lignes."
```

Reprise : `claude --continue`, `claude --resume <session-id>`, `claude --resume <session-id> --fork-session`.

Règle long-run :
- pas d'exécution longue sans `timeout`, log ou `stream-json` ;
- ne pas relancer le même prompt long en parallèle ;
- si la limite est dépassée : arrêter, collecter logs, `git status`, puis réduire ou reprendre ;
- éviter `--bare` sauf diagnostic, car il saute la découverte automatique de `CLAUDE.md`, hooks, plugins et mémoire ;
- préférer `--permission-mode acceptEdits` avec `--allowedTools` pour les reviews et lectures ;
- ne pas utiliser `dontAsk` sans allowlist stricte ;
- réserver `--dangerously-skip-permissions` aux worktrees jetables, jamais au repo de travail.

## 6. Engram protocol

Source of truth for detailed Engram policy: `docs/AGENTS/ENGRAM.md`.

Début de session : `mem_context(project="mint")`, puis
`mem_search(query="<fichier ou sujet>", project="mint")`.

Pendant review : citer l'`obs_id` si une mémoire antérieure éclaire le finding.

Fin de tâche substantielle : `mem_save(project="mint", type="<type accepté par le MCP>", title="<titre court>", topic_key="<zone>:<sous-zone>:<sujet>", content="**What**: ...\n**Why**: ...\n**Where**: ...\n**Learned**: ...")`. Types usuels : `decision`, `architecture`, `bugfix`, `pattern`, `discovery`, `config`, `learning`.

Pour une décision ou architecture, inclure raison, alternatives et conditions de remise en question. Ne jamais finir un rapport par un reçu `mem_save`. Préférer les outils MCP `mem_*` au CLI Engram local.

## 7. Simulator / Maestro / device gates

Le simulateur est un gate produit. Avant toute affirmation de disponibilité d'un flux mobile : build iOS simulateur, lancement, navigation réelle jusqu'à la surface changée, capture ou snapshot final, Maestro flow si le flux doit rester stable, artefacts sous `.planning/` ou `evidence/` si utiles.

Commandes utiles :

```bash
bash tools/simulator/maestro_env.sh --version
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/<flow>.yaml
bash tools/simulator/walker_premier_eclairage.sh --archetype julien_swiss --no-dry-run
python3 tools/checks/maestro_locator_audit.py
timeout 30s xcrun simctl list devices
```

Côté Codex, si le plugin Build iOS Apps expose xcodebuildmcp : appeler `session_show_defaults`, puis `build_run_sim`, puis `snapshot_ui` / `tap` / `type_text` / `wait_for_ui`. Côté Claude, vérifier d'abord `claude mcp list`; si xcodebuildmcp est absent, utiliser Maestro, `idb`, `simctl` et screenshots, sans prétendre avoir utilisé xcodebuildmcp. Si iPhone 13 mini est indisponible, noter le simulateur utilisé et garder le gate iPhone 13 mini ouvert.

Ne pas lancer `flutter clean` pour contourner un build iOS local. Ne pas supprimer `apps/mobile/ios/Podfile.lock`.

## 8. Git / branch policy

Politique repo : branche feature depuis `dev` (`feature/SXX-<slug>` ou slug GSD explicite), PR feature vers `dev` en squash, `dev` vers `staging`, puis `staging` vers `main`. Pas de force push sur `dev`, `staging`, `main`. `git pull --rebase` par défaut. Commits atomiques et réversibles.

Avant modification : `git status --short --branch`.

Avant commit : `git diff --stat`, `git diff --check`, `git diff --shortstat origin/dev...HEAD`.

Si le diff dépasse 300 lignes hors fichiers générés nécessaires, scinder. Ne jamais revert des changements non faits par toi sans demande explicite.

## 9. What must be refused

Refuser ou renvoyer à clarification :
- 30 à 50 scénarios markdown sans flux exécutable ;
- chiffre financier sans provenance complète ;
- calcul recodé hors source canonique ;
- service, route, widget ou doc sans consommateur réel ;
- abstraction pour deux duplications ;
- fallback silencieux qui masque une dérive ;
- promesse financière ou fiscale ;
- texte utilisateur hors ARB ;
- français sans accents ;
- chemin LLM sans golden I/O ou eval ;
- claim d'état final sans preuve fraîche ;
- PR trop large sans découpage ;
- modification cross-stack par un agent hors périmètre ;
- conclusion juridique publique ou formulation exploitable comme aveu.

Outils mécaniques : `check_banned_terms(text)`, `check_accent_patterns(text)`, `validate_arb_parity()`, `get_swiss_constants(category)`.

## 10. Mint 2.0 first phase application

Décision produit courante : trois axes visibles, une seule porte live.

| Axe | Statut | Autorisé | Refusé |
|---|---|---|---|
| `2e pilier : rente ou capital` | Live | chiffrage, provenance, readiness, hypothèses, champs manquants, version, tests, Maestro | chiffre nu, recommandation produit, calcul copié dans la couche scénario |
| `Logement : 2e / 3e pilier` | Signalétique | explication, notification, suivi | chiffres, simulation, collecte non utilisée, promesse de décision |
| `3a et rachats : impact fiscal` | Signalétique | explication prudente, données manquantes, notification | avantage fiscal promis, langage de promesse fiscale, montant fiscal sans moteur et sources |

Slug de référence : `/gsd:plan-phase mint-2-0-first-experience-rente-capital`.

Contrat utilisateur : l'utilisateur ouvre l'app, voit trois axes, entre par `2e pilier : rente ou capital`, fournit le minimum requis ou voit ce qui manque, reçoit un résultat chiffré seulement si le calcul est défendable, voit sources/hypothèses/readiness/version, puis revient aux deux autres axes comme signalétiques sans faux chiffre.

Gate minimal rapide, pas équivalent à la suite complète :

```bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT/apps/mobile"
flutter analyze
flutter test test/services/financial_core/ test/screens/
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss
cd "$ROOT"
APP_PATH="$ROOT/apps/mobile/build/ios/iphonesimulator/Runner.app"
xcrun simctl uninstall booted ch.mint.app >/dev/null 2>&1 || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted ch.mint.app
```

Gate d'entrée Mint 2.0 à créer avant de clore Slice 2 :

```bash
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml
```

Contrat de ce flow : `launchApp: { clearState: true }` -> trois axes visibles -> tap `2e pilier : rente ou capital` -> pas d'account gate -> résultat ou réponse missing-fields avec provenance/readiness.

Régressions de surface existante, utiles mais insuffisantes pour valider l'entrée Mint 2.0 :

```bash
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_disclaimer_runtime.yaml
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_runtime_visual.yaml
```

Les flows row17 deeplinkent `/rente-vs-capital`; ils ne prouvent ni landing, ni trois axes, ni absence d'account gate, ni fresh install. La phase reste ouverte tant que le flux live n'est pas prouvé depuis l'entrée et que les deux axes signalétiques peuvent être distingués d'un calcul actif.
