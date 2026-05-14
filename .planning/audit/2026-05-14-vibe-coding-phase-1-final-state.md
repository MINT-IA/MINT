---
description: État final Phase 1 vibe-coding-infra MINT après session /office-hours 2026-05-14. Lecture obligatoire pour toute nouvelle session Claude Code MINT — résume ce qui est installé, ce qui est sur dev, ce qui reste à faire post-Wave-1a.
---

# Vibe-Coding Infra MINT — Phase 1 Final State (2026-05-14)

> **Si tu démarres une nouvelle session Claude Code MINT** : lis ce fichier d'abord. Il décrit l'infra opérationnelle aujourd'hui + le plan post-Wave-1a.

## TL;DR

- **Engram MCP** opérationnel sur Mac mini avec storage `/Volumes/FUN2/engram/engram.db` (1.7 TB libre)
- **Subagent `mint-review-pr`** avec `memory: local` créé, déployable dès next session
- **CLAUDE.md §3.5 TEAM AGENTS** documenté avec routing rules
- **Discord channel `#engram-exports`** + webhook + LaunchAgent timer hebdomadaire Mondays 09:00
- **3 PRs Phase 1 mergés** (`#601` + `#602` + `#603`)
- **Hard gate kill-switch 2026-05-21** : ≥3/5 PRs Wave 1 avec `prior_finding_refs` non-null sinon KILL Phase 1

## Architecture opérationnelle aujourd'hui

```
                  Main Claude Code (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
                                  ↓ dispatch
            ┌─────────────────────┼─────────────────────┐
            ↓                     ↓                     ↓
   @mint-review-pr            21 gsd-* subagents       Skills library
   (.claude/agents/,          (gsd-planner,             gstack ~40 + GSD 58
    memory: local,             gsd-executor,            + Superpowers 13
    engram-backed)             gsd-codebase-mapper…)    + autoresearch 11
            ↓                                            (workflows, stateless)
            ↓ tools: Skill, Read, Bash, Grep
            ↓ + mem_search / mem_save via MCP
            ↓
   engram MCP server (plugin:engram:engram)
            ↓
   /Volumes/FUN2/engram/engram.db (SQLite + FTS5)
            ↓ + Discord weekly digest
   #engram-exports (MINT Discord)
```

## Composants installés (persistants Mac mini)

| Couche | Composant | Path |
|---|---|---|
| **Plugin marketplace** | engram (Gentleman-Programming) | `~/.claude/plugins/cache/engram/engram/0.1.0/` |
| **Binary** | engram 1.15.11 | `~/.local/bin/engram` |
| **DB** | SQLite + FTS5 | `/Volumes/FUN2/engram/engram.db` |
| **Env var** | `ENGRAM_DATA_DIR=/Volumes/FUN2/engram` | `~/.zshrc` |
| **MCP server** | `plugin:engram:engram` user-scope | `~/.claude/settings.json` |
| **Agent Teams flag** | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | `~/.claude/settings.json` |
| **Subagent** | `mint-review-pr` v2.1 with `memory: local` | `.claude/agents/mint-review-pr.md` (on `dev` post-PR #603 merge) |
| **Skill v2.0** | `mint-review-pr` (legacy compat) | `.claude/skills/mint-review-pr/SKILL.md` (on `dev`) |
| **Discord webhook** | URL stored mode 600 | `~/.gstack/secrets/discord-engram-webhook` |
| **LaunchAgent** | Weekly Mondays 09:00 | `~/Library/LaunchAgents/com.mint.engram-digest.plist` |
| **Export script** | `engram-export-discord.sh` | `tools/scripts/engram-export-discord.sh` (on `dev`) |
| **Onboarding prompt** | Durable Wave 1 prompt | `.planning/sessions/2026-05-14-wave-1-vibe-coding-infra-onboarding-prompt.md` (on `dev`) |

## Findings engram persistés (3 entries, project `mint-ia-mint`)

| # | Topic | Citation chain |
|---|---|---|
| **1** | smoke-test setup successful | (root finding) |
| **2** | infra-decision: engram challenged 2026-05-14 — KEEP verdict | `prior_finding_refs: [#1]` |
| **3** | infra-setup: Discord engram-exports channel + webhook + LaunchAgent | `prior_finding_refs: [#2]` |

Le pattern compounding observable est démontré live (#3 → #2 → #1). Phase 1 gate métrique reproduira ce pattern sur les findings critic des PRs Wave 1.

## PRs Phase 1 mergés sur dev (2026-05-14)

| PR | sha | Contenu |
|---|---|---|
| **#601** | `41f605a3` | engram setup docs + mint-review-pr v2.0 skill (`memory: local` + Step 0/5.5 engram) |
| **#602** | `f4e9ead8` | gitignore `.claude/agent-memory/` + backlog Graphiti Phase 4+ entry |
| **#603** | (à merger ce turn) | Discord export script + onboarding prompt + subagent mint-review-pr + CLAUDE.md §3.5 TEAM AGENTS routing |

## Hard gate kill-switch 2026-05-21

**Métrique compounding observable** : sur les 5 premiers PRs Wave 1 reviewés par `mint-review-pr`, **≥3 doivent avoir au moins un finding avec `prior_finding_refs` non-null**.

- ✅ GO → Phase 2 (adoption VoltAgent 21 subagents + DELETE mint-* skills + 0-1 MINT custom subagent)
- ❌ KILL → rollback subagent, retour pattern stateless skill, infra à reconsiderer

Decision artifact à créer le 2026-05-21 : `.planning/decisions/2026-05-21-vibe-coding-infra-phase-1-gate.md`.

## Plan Phase 2+ (post-2026-05-21 si GO) — VoltAgent adoption

**Découverte session 2026-05-14** : [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (19.8k stars, MIT, Feb 2026 actif) a **131 subagents production-ready** dont 21 directement pertinents pour MINT mobile app financière :

`flutter-expert`, `mobile-developer`, `swift-expert`, `kotlin-specialist`, `fintech-engineer`, `payment-integration`, `risk-manager`, `compliance-auditor`, `code-reviewer`, `qa-expert`, `test-automator`, `accessibility-tester`, `security-auditor`, `architect-reviewer`, `debugger`, `error-detective`, `ui-designer`, `refactoring-specialist`, `documentation-engineer`, `git-workflow-manager`, `multi-agent-coordinator`, `workflow-orchestrator`, `context-manager`.

**Plan refactor Phase 2** (~2h30) :

1. **DELETE 10 mint-\* skills** (10/11 sont des doublons de gstack/GSD/Superpowers ou legacy) — garder seulement `mint-review-pr` skill comme legacy compat
2. **Adopt 21 VoltAgent subagents** (fork + add `memory: local` au frontmatter de chaque)
3. **Test empirique** : `compliance-auditor` VoltAgent + CLAUDE.md Swiss rules → couvre `mint-swiss-compliance` ?
4. **CLAUDE.md §3.5 update** avec les 21 + decision sur mint-swiss-compliance
5. **`tools/audit/claude_md_vs_skills.py` updated** pour le nouveau pattern

**Décision pending** : 0-1 subagents MINT-pur (potentiellement `mint-swiss-compliance` si test compliance-auditor montre gap Swiss legal). À valider empiriquement post-Phase-1.

## Limites connues multi-machine

- Engram setup = **Mac mini only** aujourd'hui
- Si laptop dev nécessaire : (a) `engram cloud bootstrap` (pricing unclear, à tester) OU (b) HTTP serve via Tailscale OU (c) rsync nightly
- Discord webhook = Mac mini LaunchAgent only (Discord lui-même est cloud, accessible partout)

## Pour toute nouvelle session

**Premier acte** : `claude mcp list` doit montrer `plugin:engram:engram → ✓ Connected`. Si non-connecté, STOP et flag.

**Si tu travailles sur Wave 1+** : invoque manuellement `@mint-review-pr` subagent (ou skill via `/mint-review-pr`) **avant chaque PR merge**. Sinon kill-switch fire 2026-05-21.

**Si tu cherches le briefing complet** : lis `~/.gstack/projects/MINT-IA-MINT/julienbattaglia-dev-design-20260514-133000.md` (design doc complet) + `.planning/sessions/_BACKLOG.md` entry #1 (origin) + `.planning/sessions/2026-05-14-wave-1-vibe-coding-infra-onboarding-prompt.md` (prompt durable).

## Contradictions / counter-arguments à creuser

- **mint-review-pr subagent peut être DELETE Phase 2** si VoltAgent `code-reviewer` + CLAUDE.md MINT rules suffisent. À tester post-2026-05-21.
- **mint-swiss-compliance** : Julien doute encore que ce specialist mérite l'existence (le knowledge est déjà dans `mint-tools` MCP + CLAUDE.md + ADRs). À tester avec `compliance-auditor` VoltAgent.
- **Engram vendor risk** : single-org maintainer Gentleman-Programming (Alan Buscaglia). Vendor strategy : pin sha + monthly check + fork plan documenté §Dependencies du design doc.

## Data gaps

- Aucune mesure encore de compounding ROI réel (Phase 1 démarre sur Wave 1a)
- Aucune mesure du « critic invocation discipline » sans GitHub Action (manuel pour Phase 1)
- Engram cloud sync pricing inconnu (à tester)
