# Phase 56 — Tool Utilization Audit

> Statut : **Ready (dépend Phase 55 mergé)**
> Auteur : Claude (Product Leader)
> Date : 2026-05-03
> Durée estimée : 6 heures effectives, fenêtre 2 jours
> Goal : mesurer et réduire l'écart entre **outils installés** (~180+ skills/lints/scripts) et **outils réellement utilisés** (~10-15% selon Julien). Appliquer la discipline 14 du kit.

## Contexte

Julien a identifié explicitement (2026-05-03) : « on a des superpowers déjà installés mais on ne sait pas les utiliser, on n'utilise jamais vraiment que 10% de tous les super outils qu'on a ».

C'est la version meta du surface-debt audit (Phase 55) : 9/27 lints non wirés = même pattern, scope agent/skill.

Inventaire actuel estimé MINT :
- `obra/superpowers` : ~14 skills auto-trigger
- `gstack` : ~23 skills (CEO, designer, eng-mgr, QA, CSO, release...)
- GSD framework : ~80 skills (`gsd-*`)
- MINT-specific : `mint-flutter-dev`, `mint-backend-dev`, `mint-swiss-compliance`, `mint-test-suite`, `mint-commit`, `mint-review-pr`, `mint-office-hours`, `mint-retro`, `mint-phase-audit`, `mint-audit-complet` (~10)
- Autoresearch : `autoresearch-*` (~10)
- Tools/checks : 27 scripts
- Walker / scripts : ~10
- MCP servers (`mint-tools`, `claude_ai_Gmail`, `claude_ai_Google_Calendar`, `claude_ai_Google_Drive`)

**Total : ~180 outils discoverable. Utilisation réelle estimée : 15-25.**

## Architecture sprint

3 PRs sériels, 6h total :

```
PR-1 (Census)              PR-2 (Wire census in workflow)   PR-3 (Retire + promote)
   ↓                              ↓                              ↓
Run tool-census, log         Add tool-census to               Retire dormant skills,
inventory, classify          session-start protocol +         promote frequent patterns
each tool                    /census slash command            to MINT specialists
(2h)                         (2h)                             (2h)
```

## PR-1 — Census + classification (2h)

### Task 1.1 — Bootstrap tool-census in MINT (30 min)
- Run `bash tooling/claude-code-discipline-kit/bin/bootstrap.sh --apply --force` (force OK car CLAUDE.md déjà patché section 7 manuellement)
- Vérifier `bin/tool-census.sh` installé en MINT root
- Vérifier `tools/checks/lint_status_audit.py` installé

### Task 1.2 — Run full census + persist (1h)
- `bash bin/tool-census.sh --json > .planning/audits/2026-05-XX-tool-census-baseline.json`
- `bash bin/tool-census.sh > .planning/audits/2026-05-XX-tool-census-baseline.md`
- Commit baseline as historical record

### Task 1.3 — Classify each tool (30 min)
- Pour chaque skill/lint/script/MCP : ajouter une ligne dans nouveau `tools/INVENTORY.md` :
  ```
  | Tool | Type | Origin | Last used | Action proposed |
  |---|---|---|---|---|
  | mint-flutter-dev | skill | MINT | active | KEEP — promote to specialist Layer 1 |
  | gsd-debug | skill | GSD | never | KEEP — flag « emergency tool, surface in /census --suggest 'bug' » |
  | autoresearch-prompt-lab | skill | autoresearch | never | RETIRE — no foreseen use |
  | tools/checks/no_implicit_bloom_strategy.py | lint | MINT | active in lefthook | KEEP |
  ```
- 4 actions possibles : `KEEP-active`, `KEEP-emergency`, `PROMOTE` (= specialist Layer 1), `RETIRE`

**Verification :** total tools >= 150, 100% classified, action proposée per tool.

**Pre-push checklist :** baseline JSON + MD committed, INVENTORY.md complet.

## PR-2 — Wire census in session-start workflow (2h)

### Task 2.1 — Update CLAUDE.md section 7 with mandatory invocation (30 min)
- Add to section 7 : « Au début de toute session non-triviale : `/claude-code-discipline` puis `bin/tool-census.sh --suggest "$INITIAL_TASK"` »
- The 3 surfaced underused-but-relevant tools become context for current session

### Task 2.2 — Create `/census` slash command (30 min)
- `.claude/commands/census.md` : surface 3 underused tools relevant to user's next task
- Invokes `bin/tool-census.sh --suggest`

### Task 2.3 — Wire `bin/tool-census.sh --underused` warning into lefthook pre-push (1h)
- If census not run in last 7 days, lefthook pre-push warns (not blocks)
- Forces awareness without blocking ship

**Verification :** `/census wiki ingest` returns 3 relevant suggestions ; lefthook warns on stale census.

## PR-3 — Retire + promote (2h)

### Task 3.1 — Retire RETIRE-classified tools (1h)
- For each `RETIRE` in INVENTORY.md : delete or archive to `.archive/skills/` with one-line `RETIRED-YYYY-MM-DD.md` justification
- Update INVENTORY.md status

### Task 3.2 — Promote PROMOTE-classified patterns to specialists (1h)
- For each pattern that was repeatedly invoked manually (e.g., always running `accent_lint_fr.py + check_banned_terms() + flutter analyze`) : create a `mint-pre-flutter-push` specialist agent that bundles them
- 1-3 new specialists max (don't over-engineer)

**Verification :** count tools active before/after, retire-dormant-ratio published in HTML evidence report.

## Definition of Done

- [ ] PR-1 mergé : INVENTORY.md complet + baseline JSON/MD persisted
- [ ] PR-2 mergé : `/census` slash command works, CLAUDE.md section 7 updated, lefthook warns on stale census
- [ ] PR-3 mergé : N tools retired, M specialists created
- [ ] `.planning/phases/56-tool-utilization-audit/56-VERIFICATION-REPORT.html` complet avec :
  - Baseline tool count vs post-cleanup count
  - Specialist creation justifications
  - Retired tool list with reasons
- [ ] Memory MEMORY.md updated : nouvelle entrée « Tool census discipline » référençant ce process
- [ ] Phase 56.1 créé pour follow-up trimestriel (re-census + retire dormant)

## Risques + mitigations

| Risque | Mitigation |
|---|---|
| Retirer un skill « emergency tool » utile au prochain incident | Catégorie `KEEP-emergency` flag les skills used-once-but-valuable → restent visibles via census |
| Promotion de specialist crée maintenance burden | Cap 3 specialists max en PR-3. Si pattern moins fréquent, garde tools individuels |
| `/census --suggest` faible précision sur naming | Itérer sur le matching algo en V0.2 du kit. Pour V1 keyword-match suffit |

## Workflow d'exécution (suivant kit discipline 9 R/P/I)

```
JOUR 1 (4h) — PR-1 + PR-2 (indépendants après PR-1)
  RESEARCH (déjà fait : audit estimate + tool-census.sh design)
  PLAN (ce document)
  RED → tests pour /census slash command (test fixture)
  GREEN → bootstrap + classify + commands
  PRE-PUSH → census re-run, INVENTORY.md fresh
  EVIDENCE → HTML report initialisé

JOUR 2 (2h) — PR-3
  RED → backup tested for archived skills
  GREEN → retire + create specialists
  PANEL skip (no UI)
  PRE-PUSH → no skill dependency broken (grep references)
  EVIDENCE → final HTML, baseline before/after counts
```

## Liens

- Kit doc tool discovery : `tooling/claude-code-discipline-kit/docs/TOOL_DISCOVERY.md`
- Kit doc agent architecture : `tooling/claude-code-discipline-kit/docs/AGENT_ARCHITECTURE.md`
- GitHub : https://github.com/Julienbatt/claude-code-discipline-kit
- Phase 55 (surface-debt sprint, dépendance) : `.planning/phases/55-surface-debt-pareto/PLAN.md`
- Memory feedback_pre_push_checklist (universel)
