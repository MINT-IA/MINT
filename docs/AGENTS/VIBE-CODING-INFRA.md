# AGENTS — Vibe-Coding Infra (MINT)

> Persistent specialist agents with memory for MINT dev workflow.
> Phase 1 = pilot `@mint-code-reviewer` extension. Full architecture in `~/.gstack/projects/MINT-IA-MINT/julienbattaglia-dev-design-20260514-133000.md`.

## What this is

MINT runs `engram` (Gentleman-Programming, MIT, single Go binary + SQLite) as MCP server providing per-agent persistent memory. Each `mint-*` skill with `memory: local` frontmatter accumulates findings across sessions. Read-side via `mem_search`, write-side via `mem_save`. Cross-agent learning via `@karpathy-curator` (Phase 2).

## Setup (Mac mini, one-time)

```bash
# Install engram via official Claude marketplace
claude plugin marketplace add Gentleman-Programming/engram
claude plugin install engram

# Storage on Fun2 (1.7 TB free, persistent)
mkdir -p /Volumes/FUN2/engram
echo 'export ENGRAM_DATA_DIR="/Volumes/FUN2/engram"' >> ~/.zshrc

# Verify
engram --version       # engram 1.15.11+
engram doctor          # 4 ok, 0 errors expected
claude mcp list        # plugin:engram:engram → ✓ Connected
```

Round-trip smoke test :

```bash
engram save "test" "round-trip" --type validation --project mint
engram search "test" --project mint
```

## Public-repo discipline

Findings can contain sensitive code references. `.gitignore` excludes :
- `.claude/agent-memory/`
- `.claude/agent-memory-local/`

Default memory scope for new mint-* skills = `memory: local` (NOT `project`) so memories stay outside version control. `tools/checks/no_legal_admission_in_public_docs.py` scans engram exports if surfaced via `engram export`.

## Skills with persistent memory

| Skill | Memory scope | Role |
|---|---|---|
| `mint-review-pr` | `memory: local` | Senior Flutter+Dart reviewer, accumulates patterns across PRs (Phase 1 pilot) |

Phase 2+ extensions (post 2026-05-21 gate) :
- `mint-swiss-compliance` → `@lsfin-officer` + `@swiss-fintech-expert`
- `mint-audit-complet` → `@adversarial-tester`
- NEW `mint-ux-critic-aesop`, `mint-karpathy-curator`

## Multi-machine (future, Phase 4)

Currently engram runs local-stdio on Mac mini. If laptop access needed, expose HTTP API via :

```bash
engram serve --http :7437 --project mint
# + Tailscale Mac mini + laptop
# + .mcp.json HTTP entry on laptop: http://mac-mini.tailscale.net:7437
```

LaunchAgent auto-start template in `tools/scripts/launchagent-engram.plist.template` (TBD Phase 2 if needed).

## Findings JSON schema (engram entries)

```json
{
  "agent": "mint-review-pr",
  "topic_key": "flutter:state-management:provider-pattern",
  "file": "apps/mobile/lib/screens/onboarding_screen.dart",
  "line": 142,
  "category": "anti-pattern | regression | acceptance | warning",
  "severity": "P0 | P1 | P2 | nit",
  "recommendation": "Move state to ChangeNotifier — see PR #XXX where pattern was agreed",
  "pr_sha": "<sha>",
  "pr_number": <int>,
  "prior_finding_refs": ["<obs_id>", "..."]
}
```

`prior_finding_refs` non-null in ≥3 of first 5 PRs reviewed = compounding observable (Phase 1 hard gate, 2026-05-21).

## References

- Design doc : `~/.gstack/projects/MINT-IA-MINT/julienbattaglia-dev-design-20260514-133000.md`
- Backlog : `.planning/sessions/_BACKLOG.md` entry #1
- Engram upstream : https://github.com/Gentleman-Programming/engram
- Anthropic subagent memory docs : https://code.claude.com/docs/en/sub-agents
