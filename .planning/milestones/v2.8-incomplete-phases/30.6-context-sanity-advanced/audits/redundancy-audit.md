# CLAUDE.md ↔ mint-* skills — redundancy audit (D-08)

**Threshold:** Jaccard 5-gram ≥ 0.6
**Primary sources:** CLAUDE.md + docs/AGENTS/*.md
**Secondary sources:** .claude/skills/mint-swiss-compliance/SKILL.md, .claude/skills/mint-flutter-dev/SKILL.md, .claude/skills/mint-backend-dev/SKILL.md
**Candidates found:** 10

## Duplicates (ordered by similarity)

| # | Primary (CLAUDE.md / AGENTS) | Secondary (skill) | Similarity | Proposed action |
|---|------------------------------|--------------------|-----------|------------------|
| 1 | docs/AGENTS/backend.md:62 | .claude/skills/mint-backend-dev/SKILL.md:53 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 2 | docs/AGENTS/backend.md:71 | .claude/skills/mint-backend-dev/SKILL.md:62 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 3 | docs/AGENTS/backend.md:107 | .claude/skills/mint-backend-dev/SKILL.md:98 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 4 | docs/AGENTS/flutter.md:117 | .claude/skills/mint-flutter-dev/SKILL.md:86 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 5 | docs/AGENTS/swiss-brain.md:183 | .claude/skills/mint-swiss-compliance/SKILL.md:79 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 6 | docs/AGENTS/swiss-brain.md:195 | .claude/skills/mint-swiss-compliance/SKILL.md:91 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 7 | docs/AGENTS/swiss-brain.md:207 | .claude/skills/mint-swiss-compliance/SKILL.md:103 | 1.00 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 8 | docs/AGENTS/flutter.md:127 | .claude/skills/mint-flutter-dev/SKILL.md:96 | 0.92 | MOVE to skill (keep 1-liner in CLAUDE.md) |
| 9 | docs/AGENTS/flutter.md:97 | .claude/skills/mint-flutter-dev/SKILL.md:137 | 0.80 | REVIEW manually |
| 10 | docs/AGENTS/swiss-brain.md:186 | .claude/skills/mint-swiss-compliance/SKILL.md:82 | 0.80 | REVIEW manually |

## Decisions (manual review)

Per D-08: CLAUDE.md keeps a 1-line summary per skill ("Swiss compliance → `/mint-swiss-compliance`"), detail migrates to the skill file. Full re-architecture skills ↔ CLAUDE.md = deferred v2.9+.

For each high-similarity duplicate (>0.8) above, Julien decides on PR review:

- [ ] #1 (1.00) — docs/AGENTS/backend.md:62 ↔ .claude/skills/mint-backend-dev/SKILL.md:53
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #2 (1.00) — docs/AGENTS/backend.md:71 ↔ .claude/skills/mint-backend-dev/SKILL.md:62
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #3 (1.00) — docs/AGENTS/backend.md:107 ↔ .claude/skills/mint-backend-dev/SKILL.md:98
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #4 (1.00) — docs/AGENTS/flutter.md:117 ↔ .claude/skills/mint-flutter-dev/SKILL.md:86
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #5 (1.00) — docs/AGENTS/swiss-brain.md:183 ↔ .claude/skills/mint-swiss-compliance/SKILL.md:79
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #6 (1.00) — docs/AGENTS/swiss-brain.md:195 ↔ .claude/skills/mint-swiss-compliance/SKILL.md:91
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #7 (1.00) — docs/AGENTS/swiss-brain.md:207 ↔ .claude/skills/mint-swiss-compliance/SKILL.md:103
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
- [ ] #8 (0.92) — docs/AGENTS/flutter.md:127 ↔ .claude/skills/mint-flutter-dev/SKILL.md:96
  - [ ] Accept as-is (1-liner in CLAUDE.md is intentional redundancy)
  - [ ] Drop from CLAUDE.md / AGENTS (content lives in skill)
  - [ ] Drop from skill (content is more general, belongs in CLAUDE.md)
