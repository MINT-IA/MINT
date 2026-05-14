---
description: Audit 2026-05-14 Phase 1 vibe-coding-infra MINT — verdict POST-REVIEW : adopt VoltAgent DEFERRED to post-2026-05-21 gate. Plan radical de mid-session INVALIDÉ par eng-review. Version surgical adoptée. Lecture obligatoire pour toute nouvelle session.
---

# Vibe-Coding Infra MINT — Phase 1 État + Plan REVISÉ (2026-05-14)

> **Si tu démarres une nouvelle session Claude Code MINT** : lis ce fichier d'abord. Phase 1 est en pilote actif. Plan radical VoltAgent adoption mid-session a été **REJETÉ par eng-review session** — version surgical adoptée.

## TL;DR Phase 1 (pilote actif)

- ✅ **Engram MCP** opérationnel sur Mac mini, storage `/Volumes/FUN2/engram/engram.db`
- ✅ **Subagent `mint-review-pr`** v2.1 avec `memory: local` sur dev (`.claude/agents/mint-review-pr.md`)
- ✅ **Skill `mint-review-pr`** v2.0 legacy compat sur dev
- ✅ **CLAUDE.md §3.5 TEAM AGENTS** routing documenté
- ✅ **3 PRs Phase 1 mergés** : `#601` + `#602` + `#603`
- ✅ **Discord channel `#engram-exports`** + webhook + LaunchAgent timer hebdomadaire
- ✅ **3 findings engram** persistés (`#1` smoke, `#2` audit verdict, `#3` Discord setup)
- ⏳ **Hard gate kill-switch 2026-05-21** : ≥3/5 PRs Wave 1 avec `prior_finding_refs` non-null = GO Phase 2, sinon KILL

## Status REVISÉ post-eng-review

Pendant cette session j'ai (Claude) proposé un **plan radical** :
- DELETE 10 mint-* skills
- Adopt 21 VoltAgent subagents
- Créer 2 nouveaux MINT-pur subagents (mint-anti-facade-critic, mint-karpathy-curator)

L'**eng-review session** (Julien a lancé `/plan-eng-review` gstack en parallèle) a **REJETÉ ce plan** avec 5 hard blockers — 4 confirmés solides après vérification empirique :

### Hard blockers du reviewer (4 sur 5 confirmés)

1. **Tuer le pilote 7 jours avant son gate sans données.** Le design doc 2026-05-14 a été APPROVED avec un kill-switch empirique 2026-05-21 mesurant compounding observable. DELETE mint-review-pr maintenant = expérience nulle, gate jamais évalué. **Karpathy #1 : faire l'expérience avant la décision.**

2. **VoltAgent était déjà reviewé et REJETÉ Phase 1.** Dans le landscape findings du design doc, VoltAgent listé comme « source d'inspiration, pas adopté ». Ressusciter cette option mid-session sans nouvelle evidence = revirement sans evidence ledger, violation 0-trust §9.

3. **Skills vs agents confusion.** Les 11 mint-* skills sont des **workflows** invocables via `/mint-commit`, `/mint-flutter-dev`, `/mint-test-suite`, `/mint-office-hours`. Ils contiennent bash + AskUserQuestion + flow git + conventions MINT-specific. CLAUDE.md ne peut PAS remplacer un workflow exécutable. DELETE 11 skills = suppression d'outillage productif sans replacement validé.

4. **`mint-anti-facade-critic` n'existe pas.** L'anti-facade est **Pass 8** dans le subagent `mint-review-pr` (`.claude/agents/mint-review-pr.md:145-156`). Je proposais de challenge-DELETE un agent fantôme. Si DELETE mint-review-pr, on perd aussi anti-facade par construction.

5. **8 passes encodent du REASONING MINT-pur, pas du knowledge listable.**
   - Pass 6 FINANCIAL_CORE : `grep _calcul|calculate|compute|estimate|forecast|project|\* 0\.|/ 12|/ 44` puis cross-ref `apps/mobile/lib/services/financial_core/`
   - Pass 7 ARCHETYPES : détecte assumption swiss_native sur 8 archetypes (FATCA expat_us, frontalier, indep_no_lpp)
   - Pass 8 ANTI-FACADE : 4-level Existe/Substantiel/Câblé/Données
   
   Un `compliance-auditor` générique VoltAgent qui lit CLAUDE.md n'inventera pas ces grep + cross-ref. Assertion « couverture identique » sans test = banned phrase §9.1 0-trust.

### Hard blocker faux flag (1 sur 5)

5b. **Project ID engram mismatch** (`mint` vs `mint-ia-mint`). Le reviewer flag un bug critique. **Vérification empirique** : `sqlite3 /Volumes/FUN2/engram/engram.db "SELECT DISTINCT project FROM observations;"` retourne **uniquement `mint-ia-mint`** (3 observations). Pas de bug. Mais bon réflexe de flag — c'eût été killer pour le gate.

## Plan adopté : VERSION SURGICAL (reviewer-recommended)

### Maintenant → 2026-05-21 (gate kill-switch)

1. **Garde `mint-review-pr` subagent + skill** jusqu'au gate. Tel quel.
2. **Garde les 11 mint-* skills.** Ne touche pas. Workflows quotidiens.
3. **Lance le pilote sur 3-5 premiers PRs Wave 1a** (en cours côté Codex).
4. **Mesure empirique** : compounding observable (`prior_finding_refs` non-null ≥3/5 PRs).
5. **Decision artifact 2026-05-21** : `.planning/decisions/2026-05-21-vibe-coding-infra-phase-1-gate.md` avec verdict GO / KILL.

### Post-2026-05-21 (selon gate)

**Si GO** (Phase 1 prouve compounding) :
- Test empirique AVANT remplacement : lance `compliance-auditor` VoltAgent en **parallèle** sur 3 PRs suivants, compare findings vs mint-review-pr, mesure overlap.
- Si compliance-auditor catch **≥90%** de ce que mint-review-pr catch ET a compounding via engram → retire mint-review-pr.
- Si <90% → garde mint-review-pr, considère VoltAgent comme **additif**, pas substitut.
- Adopt **0** VoltAgent subagent par défaut. Re-évalue avec données.

**Si KILL** (Phase 1 ne prouve pas compounding) :
- Rollback `.claude/agents/mint-review-pr.md`
- Le skill v2.0 reste (legacy compat)
- Replan vibe-coding infra avec leçons apprises
- VoltAgent adoption peut être candidate alternative à ce moment

## Composants persistants Mac mini (post-PR #601-#603 mergés)

| Couche | Path | Status |
|---|---|---|
| **Engram MCP plugin** | `~/.claude/plugins/cache/engram/engram/0.1.0/` | user-scope, toute session le voit |
| **engram binary** | `~/.local/bin/engram` v1.15.11 | persistent |
| **Engram DB** | `/Volumes/FUN2/engram/engram.db` (3 findings) | persistent local |
| **ENGRAM_DATA_DIR env** | `~/.zshrc` | sourced auto |
| **Subagent** | `.claude/agents/mint-review-pr.md` | sur `dev`, visible toute session post-pull |
| **Skill** | `.claude/skills/mint-review-pr/SKILL.md` v2.0 | sur `dev` |
| **CLAUDE.md §3.5** | `CLAUDE.md` | sur `dev` |
| **Discord channel** | MINT server `#engram-exports` (id `1504454027469918308`) | permanent multi-device |
| **Discord webhook** | `~/.gstack/secrets/discord-engram-webhook` mode 600 | Mac mini only |
| **LaunchAgent** | `~/Library/LaunchAgents/com.mint.engram-digest.plist` | Mondays 09:00 |
| **Export script** | `tools/scripts/engram-export-discord.sh` | sur `dev` |
| **Onboarding prompt** | `.planning/sessions/2026-05-14-wave-1-vibe-coding-infra-onboarding-prompt.md` | sur `dev` |

## Findings engram (3 entries, project `mint-ia-mint`)

| # | Topic | Citation chain |
|---|---|---|
| **1** | smoke-test setup successful | (root) |
| **2** | infra-decision: engram challenged 2026-05-14 — KEEP verdict | `[#1]` |
| **3** | infra-setup: Discord engram-exports channel + webhook + LaunchAgent | `[#2]` |

Pattern compounding visible (#3 → #2 → #1). Phase 1 gate reproduira sur PRs Wave 1.

## Pour toute nouvelle session Claude Code MINT

**Premier check** : `claude mcp list` doit montrer `plugin:engram:engram → ✓ Connected`.

**Wave 1+ PRs** : invoque manuellement `@mint-review-pr` subagent (ou skill `/mint-review-pr`) **avant chaque PR merge**. Le compounding observable se mesure sur ces findings.

**NE PAS** :
- Supprimer mint-review-pr avant gate 2026-05-21
- Supprimer les mint-* skills (workflows quotidiens)
- Adopter VoltAgent subagents avant test empirique post-gate
- Inventer des subagents qui n'existent pas (`mint-anti-facade-critic` est Pass 8, pas un agent à part)

**Si tu cherches le briefing complet** :
- Design doc : `~/.gstack/projects/MINT-IA-MINT/julienbattaglia-dev-design-20260514-133000.md`
- Backlog : `.planning/sessions/_BACKLOG.md` entry #1
- Onboarding prompt : `.planning/sessions/2026-05-14-wave-1-vibe-coding-infra-onboarding-prompt.md`

## Counter-arguments + data gaps

- **Counter-argument à la version surgical** : ne rien changer = on traîne le namespace mint-* potentiellement médiocre. Réponse reviewer : « measure first, decide after ». Acceptable.
- **Counter-argument au gate empirique** : si le critic n'est jamais invoqué sur Wave 1a (oubli manuel), le gate fire NO COMPOUNDING même si le critic est bon. Mitigation : prompt durable + CLAUDE.md §3.5 routing + Agent Teams auto-dispatch dès que main agent matche description.
- **Data gap** : engram cloud sync pricing inconnu. Ne pas tester avant Phase 2 si besoin multi-machine.
- **Data gap** : aucune mesure ROI réel. Le gate est la première mesure.
- **Data gap** : eng-review session est elle-même un humain-in-the-loop. Si elle se trompe, la version surgical traîne plus longtemps. À re-challenger empiriquement post-gate.

## Karpathy Wiki conventions

- Counter-args et data gaps capturés (per CLAUDE.md §8 lint)
- `prior_finding_refs` chain démontré live (engram #1→#2→#3)
- Audit lint-checkable via `tools/checks/wiki_lint.py`

## Mea culpa Claude

Pendant cette session j'ai zigzagué : skill → subagent → garde-tout → nuke-tout → 3 MINT custom → 0 MINT custom → VoltAgent adoption. Le reviewer a brutalement et justement aligné cette dérive. Hard blockers 1-4 sont solides. Le 5e (project ID) était faux flag mais bon réflexe.

Lesson : Karpathy #1 (Think Before Coding) + 0-trust §9 (banned « works », « validated » sans citation) — j'ai violé les deux. La version surgical adoptée respecte les deux.

---

## UPDATE 2026-05-14 (post-PR #603 merge + panel evidence + Julien testimony)

Cette section ajoute les findings d'un 2e tour `/plan-eng-review` lancé par Julien dans la même session, qui a spawné 3 expert panels en parallèle (mapping VoltAgent, engram project ID, skills decision tree) ET reçu un testimony direct de Julien sur l'usage réel des skills mint-*.

### Correction du « faux flag » §Hard blocker 5b (project ID engram)

Le verdict original « Pas de bug » (ligne 48) était empiriquement correct AU MOMENT de l'audit (la DB n'avait que `mint-ia-mint`). **Devient un vrai bug** dès qu'un agent appelle `mem_save` via MCP sans `--project` explicite — l'auto-detection cwd/git_remote retourne `mint`, pas `mint-ia-mint`. Engram ne normalise pas. Panel #2 a confirmé empiriquement : après son round-trip test, engram a 2 projets coexistants (`mint-ia-mint` 4 obs + `mint` 1 obs).

**Action prise 2026-05-14** : 5 fichiers patchés `mint-ia-mint` → `mint` (agent file, skill file, VIBE-CODING-INFRA doc, onboarding prompt, discord-export script). Les 4 observations historiques restent dans `mint-ia-mint` ; à consolider via `engram projects consolidate mint-ia-mint mint` avant le gate 2026-05-21.

### Panel #1 — Mapping mint-review-pr 8 passes → VoltAgent + MINT-pur

Vérifié contre `VoltAgent/awesome-claude-code-subagents` README :

| Pass | Origine | VoltAgent equivalent | MINT-pur requis ? |
|---|---|---|---|
| 1 BUGS | code generic | `code-reviewer` + `debugger` | Non |
| 2 COMPLIANCE LSFin | métier Swiss | `compliance-auditor` (base) | Oui — `mint-lsfin-officer` |
| 3 REGRESSIONS | refactor generic | `architect-reviewer` + `refactoring-specialist` | Non |
| 4 i18n | aucun équivalent | AUCUN | Oui — `mint-i18n-arb` |
| 5 DESIGN SYSTEM | tokens MINT | `accessibility-tester` (partiel) | Oui — `mint-design-system` |
| 6 FINANCIAL_CORE | ADR-20260223 | `fintech-engineer` (orientation) | Oui — `mint-financial-core-guard` |
| 7 ARCHETYPES | ontologie produit | AUCUN | Oui — `mint-archetype-router` |
| 8 ANTI-FACADE | doctrine W14 | `architect-reviewer` (partiel) | Oui partiel — `mint-anti-facade` |

Synthèse panel #1 : 2 passes pure VoltAgent, 2 hybrides, **4 MINT-pur obligatoires** (i18n, FINANCIAL_CORE, ARCHETYPES, ANTI-FACADE). Risque dominant si VoltAgent-only sans MINT-pur : 4 BLOCKERs CLAUDE.md passent (`Color(0xFF...)`, ARB FR-only, `_calculateRente()` dupliqué, « rendement garanti »). **Le chiffre `0-1 MINT-pur` du plan radical est invalidé. Le bon chiffre est 4.**

### Panel #3 + Julien testimony — Skills mint-* (revirement)

Panel #3 a appliqué un decision tree skill-vs-subagent et conclu 8/11 mint-* skills survivent en standalone. **MAIS** Panel #3 n'a pas comparé contre l'inventaire gstack/GSD/superpowers que Julien utilise réellement.

Testimony Julien (texte verbatim 2026-05-14) : *« le mint commit, le mint flutter dev et tous ces trucs, c'est de la grosse merde qui sert à rien. GSD et gstack contiennent des bien meilleures skills. On a aussi superpowers qui a des meilleures skills. Franchement, je n'utilise aucune commande skills mint. »*

Reconciliation : `/mint-commit ≈ /ship` (gstack), `/mint-retro ≈ /retro`, `/mint-test-suite ≈ /qa`, `/mint-office-hours ≈ /office-hours`, `/mint-phase-audit ≈ /gsd-verify-work`, `/mint-wiring-check ≈ /investigate`. Les 11 mint-* skills sont des early-MINT versions duplicatives. **Le « Hard blocker 3 » de l'audit original (« skills vs agents confusion → préserver 11 skills ») est donc partiellement invalidé sur le plan d'action** : skills ≠ agents reste vrai conceptuellement, mais les 11 mint-* skills concrets sont remplaçables par leurs équivalents gstack/GSD/superpowers que Julien utilise déjà.

**Action différée post-Wave-1a** : verify 1-by-1 chaque /mint-* a son replacement gstack/GSD, puis DELETE. Pas de DELETE pre-verify.

### Architecture cible révisée (post-gate)

```
Main agent (orchestrateur Anthropic Agent Teams)
                 │
                 ├── reads CLAUDE.md (MINT rules)
                 ├── reads .claude/agents/* (team manifest)
                 └── auto-dispatch par description matching
                                  ↓
       ┌──────────────────────────┼──────────────────────────┐
       ↓                          ↓                          ↓
  GSD subagents              VoltAgent subagents        MINT-pur subagents
  (.claude/agents/gsd-*)     (.claude/agents/*)         (.claude/agents/mint-*)
  21 préinstallés            ~17-21 selectif post-gate   4 post-décomposition
                              (compliance-auditor,        de mint-review-pr :
                               code-reviewer,             - mint-i18n-arb (Pass 4)
                               architect-reviewer,        - mint-financial-core-guard (Pass 6)
                               accessibility-tester,      - mint-archetype-router (Pass 7)
                               refactoring-specialist,    - mint-anti-facade (Pass 8)
                               qa-expert, security-auditor,
                               fastapi-developer,
                               flutter-expert, ...)
       │                          │                          │
       └──────────────────────────┼──────────────────────────┘
                                  ↓ tools: Skill, Read, Bash, MCPs
                                  ↓
       ┌──────────────────────────┼──────────────────────────┐
       ↓                          ↓                          ↓
    SKILLS LIBRARY            MCP TOOLS                   engram MCP
    gstack (~40)              mint-tools                  (project: `mint`)
    GSD (58 /gsd-*)            (Swiss constants,           Per-agent memory
    superpowers (13)          banned terms,               on /Volumes/FUN2
    autoresearch (11)         ARB parity,                 cross-agent topic_key
    [0-3 mint-* survivants]   accent patterns)            convention agent-agnostic
```

Plus de namespace mint-* skills hardcoded. La couche skills devient gstack/GSD/superpowers + 0-3 mint-* survivants vérifiés. La couche subagents devient 21 GSD + ~17-21 VoltAgent + 4 MINT-pur (post-décomposition de mint-review-pr).

### Cross-agent memory schema (Panel #2)

`topic_key` à 3 niveaux agent-agnostic : `<domain>:<sub-domain>:<specific-pattern>` (e.g. `flutter:state-management:provider-pattern`). Tous les agents écrivent en `--project mint --scope project` (cross-agent lookup). `memory: local` (`.claude/agent-memory-local/`) reste pour notes de processus internes uniquement, jamais pour findings PR. `prior_finding_refs` cite les `obs_id` peu importe l'agent émetteur. Anti-duplicate via `topic_key` upsert + `judgment_required` MCP heuristic (confidence ≥ 0.7 + relation compatible/scoped → résoudre silencieusement).

### Révision §11 « Pour toute nouvelle session »

- **NE PAS** supprimer mint-review-pr avant gate 2026-05-21 ✅ (inchangé)
- ~~**NE PAS** supprimer les mint-* skills (workflows quotidiens)~~ → **REVISÉ** : verify 1-by-1 le replacement gstack/GSD/superpowers, puis DELETE post-Wave-1a (Julien testimony d'usage)
- ~~**NE PAS** adopter VoltAgent subagents avant test empirique post-gate~~ → **REVISÉ** : adopt selectivement post-gate avec mapping panel #1 (~17-21 subagents en cible, pas 21 indistinct)
- **NE PAS** inventer des subagents qui n'existent pas ✅ (inchangé)
- **NE PAS** adopter 0 ou 21 sans nuance — la cible empirique est **4 MINT-pur + ~17-21 VoltAgent + 21 GSD = ~42-46 subagents totaux**

### Counter-arguments + data gaps (mises à jour)

- **Counter-argument à la cible 4 MINT-pur** : peut-être que `compliance-auditor` VoltAgent + CLAUDE.md routing catch ces 4 cas en pratique sans MINT-pur. Mitigation : test empirique post-gate (lance compliance-auditor en parallèle sur 3 PRs, mesure overlap).
- **Data gap : Julien testimony vs panel #3** : panel n'a pas vérifié les replacements concrets. Avant DELETE, verify chaque /mint-* a son équivalent gstack/GSD qui couvre 100% du contenu.
- **Data gap : engram cross-agent schema** non testé en pratique. Premier test avec mint-review-pr Wave 1a PRs.
- **Data gap : 4 obs dans `mint-ia-mint` non encore migrées vers `mint`**. Manuelle requise : `engram projects consolidate mint-ia-mint mint` à exécuter par Julien (commande destructive sur DB engram, pas auto-runnée).

### Fichiers patchés cette UPDATE

- `tools/scripts/engram-export-discord.sh` (PROJECT default + comment header)
- `.claude/agents/mint-review-pr.md` (lignes 45, 204, 231)
- `.claude/skills/mint-review-pr/SKILL.md` (lignes 36, 225, 252)
- `docs/AGENTS/VIBE-CODING-INFRA.md` (lignes 30, 31, 58)
- `.planning/sessions/2026-05-14-wave-1-vibe-coding-infra-onboarding-prompt.md` (lignes 33, 69, 101)

Tous uncommitted à ce stade — Julien décide du commit + PR follow-up.
