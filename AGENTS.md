# AGENTS.md — MINT Agent Team Workflow

> Team structure, roles, and agent spawning instructions.
> Sprint history: `docs/SPRINT_TRACKER.md` | Full rules: `CLAUDE.md`

---

## TEAM STRUCTURE

```
┌──────────────────────────────────────────────┐
│              TEAM LEAD (Opus)                │
│     Orchestrate, review, decide, merge       │
│     Doesn't code directly (except urgency)   │
└─────────┬──────────┬──────────┬──────────────┘
          │          │          │
    ┌─────▼──┐ ┌─────▼──┐ ┌────▼─────┐
    │  DART  │ │ PYTHON │ │  SWISS   │
    │ Agent  │ │ Agent  │ │  BRAIN   │
    │Sonnet  │ │Sonnet  │ │  Opus    │
    └────────┘ └────────┘ └──────────┘
```

---

## SPAWNING AGENTS

### Flutter chantier (UI, widgets, screens)
```
Spawn "dart-agent" with model sonnet.
Read: .claude/skills/mint-flutter-dev/SKILL.md, .claude/skills/mint-test-suite/SKILL.md, CLAUDE.md
Scope: apps/mobile/ only. Never touch backend.
Before changes: flutter analyze && flutter test.
```

### Backend chantier (FastAPI, services, tax)
```
Spawn "python-agent" with model sonnet.
Read: .claude/skills/mint-backend-dev/SKILL.md, .claude/skills/mint-test-suite/SKILL.md, CLAUDE.md
Scope: services/backend/ only. Never touch Flutter.
Before changes: ruff check . && pytest -q.
API change → update tools/openapi/ + SOT.md.
```

### Business/compliance chantier (fiscalité, LPP, compliance)
```
Spawn "swiss-brain" with model opus.
Read: .claude/skills/mint-swiss-compliance/SKILL.md, CLAUDE.md, LEGAL_RELEASE_CHECK.md, visions/
Scope: docs/, education/, decisions/, visions/. No code.
Output: specs with legal sources, test cases, educational text, compliance alerts.
```

---

## WORKFLOW PROTOCOL

### Rule 1: Team Lead doesn't code (except urgency)
Orchestrate, review, merge. Create tasks, verify outputs, make decisions.

### Rule 2: Swiss-Brain validates BEFORE devs implement
```
Swiss-Brain (spec + test cases)
  → Python-Agent (backend implementation)
    → Dart-Agent (UI/screen)
      → Team Lead (review + merge)
```

### Rule 3: Cross-modification boundaries
| Agent | Can modify | Cannot modify |
|-------|-----------|---------------|
| dart-agent | `apps/mobile/` | `services/backend/`, `tools/openapi/` |
| python-agent | `services/backend/`, `tools/openapi/`, `SOT.md` | `apps/mobile/` |
| swiss-brain | `docs/`, `education/`, `decisions/`, `visions/` | Code (`*.dart`, `*.py`) |

### Rule 4: Token economy
- Sonnet by default, Opus for complex reasoning
- One agent at a time unless tasks are independent
- Prefer well-defined short tasks over vague prompts

---

## SKILLS INDEX

| Skill | File | Agent |
|-------|------|-------|
| mint-flutter-dev | `.claude/skills/mint-flutter-dev/SKILL.md` | dart-agent |
| mint-backend-dev | `.claude/skills/mint-backend-dev/SKILL.md` | python-agent |
| mint-swiss-compliance | `.claude/skills/mint-swiss-compliance/SKILL.md` | swiss-brain |
| mint-test-suite | `.claude/skills/mint-test-suite/SKILL.md` | all agents |
| mint-commit | `.claude/skills/mint-commit/SKILL.md` | team-lead |

---

## DREAM TEAM (extended agents)

Launchable in parallel for specialized tasks:

| Agent | Mission | When |
|-------|---------|------|
| QA Agent | Test coverage, edge case fuzzing | After each sprint |
| i18n Agent | ARB file completion (6 languages) | Parallel to sprints |
| Accessibility Agent | WCAG 2.1 AA audit | Before beta |
| Compliance Guard Agent | ComplianceGuard + HallucinationDetector | S34 (completed) |
| OCR Agent | Document parsing pipeline | S42-S45 (completed) |
| ASO Agent | App Store/Play Store listings | 4 weeks before launch |
| Legal Agent | nLPD/CGU/Privacy audit | Before launch |

Each agent reads `CLAUDE.md` first. Team Lead reviews all output before merge.
