# Claude Code Discipline Kit

> Stop shipping surface code. Start shipping verified work. Bring rigor to your AI-assisted projects in 30 seconds.

A teleportable discipline layer for any project where Claude Code (or another AI coding agent) writes code. Composes with [obra/superpowers](https://github.com/obra/superpowers) and [muratcankoylan/Agent-Skills-for-Context-Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering); does not replace them.

## What this kit gives you

13 disciplines that prevent the dominant failure modes of AI-assisted development:

**Engineering disciplines (1-7)** — derived from Anthropic Code best practices, BMAD framework, Superpowers methodology, Generative.inc 2026 guide:

1. Plan-mode before code (any task ≥ 3 decisions or ≥ 2 files)
2. Iron Law: no fix without root-cause investigation written
3. Subagent-driven development (≥ 10 files or ≥ 3 work pieces)
4. TDD inverted: RED-GREEN-REFACTOR (failing test FIRST)
5. Verification-before-completion (evidence > assertions)
6. Design / code-review panel before merge (not after)
7. HTML evidence per phase (durable memory across sessions)

**Context engineering disciplines (8-13)** — derived from Anthropic context-engineering article, Manus production lessons, Dexter Horthy YC talk, Patrick Debois "Context Is the New Code":

8. Context utilization < 40% in permanence (compact / clear / sub-agent dispatch above)
9. Research / Plan / Implement as 3 separate artifacts
10. KV-cache stability (stable prefix, append-only, deterministic serialization, mask-don't-remove tools, TTL 1h)
11. Recitation pattern for long-running goals
12. Keep errors in context (counter-intuitive: don't clean error traces, the model learns)
13. Avoid few-shot drift on repetitive tasks (controlled variation)

Plus generic enforcement infrastructure:

- `lint_status_audit.py` — every lint in `tools/checks/` must be classified as `enforced-ci` / `enforced-pre-commit` / `manual-only` in `STATUS.md`. Catches "lint exists but never runs" — the #1 source of false confidence.
- `lefthook.discipline.yml` — additive lefthook overlay (never overwrites your `lefthook.yml`)
- `bootstrap.sh` — additive installer, dry-run by default, idempotent
- `doctor.sh` — diagnose project's discipline state
- `uninstall.sh` — clean removal path (lock-file tracked)
- `SKILL.md` — manual-trigger Claude Code skill (no auto-trigger collision with `using-superpowers`)

## Quick start

```bash
# 1. Clone (security: read bootstrap.sh before running)
git clone https://github.com/julienbatt/claude-code-discipline-kit.git
cd your-project

# 2. Dry-run (default — shows what would change, writes nothing)
~/path/to/claude-code-discipline-kit/bin/bootstrap.sh --dry-run

# 3. Apply (additive only — never overwrites)
~/path/to/claude-code-discipline-kit/bin/bootstrap.sh --apply

# 4. Verify
~/path/to/claude-code-discipline-kit/bin/doctor.sh
```

## Composes with, doesn't replace

If you have `obra/superpowers` installed, the kit detects it and **defers engineering disciplines 1-7 to superpowers**. The kit then only adds disciplines 8-13 (context engineering) + the enforcement infra. Zero collision, zero duplication.

If you have GSD (`gsd-*` skills), the kit detects it and **maps R/P/I (discipline 9) to `gsd-discuss-phase` → `gsd-plan-phase` → `gsd-execute-phase`**. The kit augments, not replaces.

## Project-specific customization

The kit ships base disciplines that are language- and domain-agnostic. Add your own rules in `<your-project>/CLAUDE.md` between marker blocks:

```markdown
<!-- discipline:project-specific:begin -->
## Your project's NEVER list

1. NEVER do X — reason
2. NEVER use Y — reason

<!-- discipline:project-specific:end -->
```

These survive kit upgrades. See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md).

## Status

- **Version:** 0.1.0 (V1, dogfooded on the MINT project)
- **Stability:** Use in any project; API may evolve before 1.0
- **License:** MIT
- **Privacy:** Zero telemetry, zero phone-home, fully local — see [PRIVACY.md](PRIVACY.md)

## Roadmap

- V0.2: 3-package split (`discipline-core/`, `discipline-claude-code/`, `discipline-bootstrap/`) for independent versioning
- V0.3: Marker-based merge tool for CLAUDE.md upgrades
- V0.4: Locale split (EN, FR, DE templates)
- V1.0: Battle-tested across 3+ projects, public stable API

## Credits

Inspired by:
- [obra/superpowers](https://github.com/obra/superpowers) — TDD + plan-mode + verification disciplines
- [muratcankoylan/Agent-Skills-for-Context-Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) — context engineering pillars
- [garrytan/gstack](https://github.com/garrytan/gstack) — voice triggers + lifecycle skills
- [Patrick Debois (Tessl) — "Context Is the New Code"](https://www.youtube.com/watch?v=bSG9wUYaHWU)
- [Dexter Horthy (Human Layer) — "Advanced Context Engineering for Agents"](https://www.youtube.com/watch?v=IS_y40zY-hc)
- [Manus — Context Engineering for AI Agents: Lessons from Building Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [Anthropic — Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
