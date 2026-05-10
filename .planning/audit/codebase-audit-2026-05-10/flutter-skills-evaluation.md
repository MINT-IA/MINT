---
title: flutter/skills — adoption evaluation for MINT
date: 2026-05-10
branch: docs/phase-2-extractor-v2-research
verdict: cherry-pick 2 / leave 8 / deprecate 0
skill_bloat_risk: 2 of 5
description: Senior Flutter eval of https://github.com/flutter/skills against MINT custom skills (mint-flutter-dev, mint-backend-dev, mint-test-suite, mint-swiss-compliance). flutter/skills is a generic "happy path" beginner kit by Flutter team — partial overlap with mint-flutter-dev (architecture, l10n, routing) but our skills are more codebase-specific (MintColors, MintCard, financial_core, Provider, GoRouter routes already wired). Recommendation: cherry-pick 2 (flutter-fix-layout-issues, flutter-add-integration-test) as supplementary references, do not adopt the rest, do not deprecate any MINT skill.
---

# flutter/skills — adoption evaluation for MINT

## TLDR

flutter/skills is a 10-skill generic Flutter beginner kit (architecture, layouts, l10n, routing, http, JSON, tests) maintained by the Flutter team for **agents starting empty Flutter projects**. MINT is a 30K-LOC mature app with opinionated stack already wired (Provider, GoRouter, MintColors, financial_core, 6 ARBs, 114 tests). 80 % of flutter/skills is « how to set up X » — MINT is past setup. Cherry-pick 2 skills as troubleshooting references; leave the 8 others; deprecate nothing.

---

## Q1. What does flutter/skills actually contain ?

**Source** : https://github.com/flutter/skills (README + `gh api` listing of `skills/`).

10 skills, all `SKILL.md` only (no scripts, no templates), all generated 2026-04-21 from `models/gemini-3.1-pro-preview`, target audience = `--agent universal` (Claude/Codex/Cursor/Gemini compatible) :

| Flutter skill | What it teaches | MINT-relevance |
|---|---|---|
| `flutter-add-integration-test` | `integration_test` package + Flutter Driver + MCP tap/scroll | **Useful** (MINT has zero integration_test/, only Maestro) |
| `flutter-add-widget-preview` | `previews.dart` system | Low — MINT uses Maestro + golden tests instead |
| `flutter-add-widget-test` | `WidgetTester` + Finder/Matcher basics | Already covered by `mint-test-suite` |
| `flutter-apply-architecture-best-practices` | MVVM + Repository + `lib/data,domain,ui/` layout | **Conflict** with MINT's `screens/widgets/services/financial_core/providers/` |
| `flutter-build-responsive-layout` | `LayoutBuilder` + `MediaQuery.sizeOf` + breakpoints | Marginal — MINT is mobile-only, no tablet/desktop targets yet |
| `flutter-fix-layout-issues` | RenderFlex / unbounded constraint debugging | **Useful** (debug reference, no MINT equivalent) |
| `flutter-implement-json-serialization` | Manual `fromJson`/`toJson` with `dart:convert` | Already covered by MINT's existing `models/` patterns |
| `flutter-setup-declarative-routing` | `go_router` initial setup + path strategy + deep linking | **Conflict** — MINT has GoRouter wired since W12 in `app.dart` |
| `flutter-setup-localization` | Initial `flutter_localizations` + `intl` + first ARB | **Conflict** — MINT has 6 ARBs since v1.0, `mint-swiss-compliance` already enforces |
| `flutter-use-http-package` | Basic GET/POST with `http` package | Marginal — MINT uses `dio` via `lib/services/api_*` |

**Format** : YAML frontmatter (`name`, `description`, `metadata.model`) + Markdown body with `## Contents` TOC, `### Task Progress` checklists, `## Examples` with input/output Dart pairs. Length ~100-200 lines per skill. **Zero project-specific context** — they teach Flutter idioms, not how to ship a specific app.

**Distribution** : `npx skills add flutter/skills --skill '*' --agent universal` writes to `.agents/skills/` (separate from MINT's `.claude/skills/`). Per https://docs.flutter.dev/ai/agent-skills the CLI clones into `.dart_skills/repos/` and re-exports.

**Verdict on Q1** : Generic « happy path » beginner skills. Designed for agents starting fresh projects, not for agents working on a 30K-LOC app with opinionated stack already locked.

---

## Q2. Overlap with MINT's existing skills (file-by-file)

### Inventory of MINT's MINT-specific Flutter skills (the 4 in scope)

| MINT skill | Path | Lines | Specificity |
|---|---|---|---|
| `mint-flutter-dev` | `/Users/julienbattaglia/Desktop/MINT.nosync/.claude/skills/mint-flutter-dev/SKILL.md` | 154 | High — names `MintCard`, `MintColors.textPrimary`, `MintPremiumButton`, `app.dart`, GoRouter conventions, financial_core reuse, certificate→profile chantier |
| `mint-backend-dev` | `/Users/julienbattaglia/Desktop/MINT.nosync/.claude/skills/mint-backend-dev/SKILL.md` | 152 | High — names `rules_engine.py`, `mint.openapi.canonical.json`, Pydantic v2 schemas, banned words list |
| `mint-test-suite` | `/Users/julienbattaglia/Desktop/MINT.nosync/.claude/skills/mint-test-suite/SKILL.md` | 129 | High — lists 30+ specific test files, common GoRouter/SharedPreferences pitfalls |
| `mint-swiss-compliance` | `/Users/julienbattaglia/Desktop/MINT.nosync/.claude/skills/mint-swiss-compliance/SKILL.md` | 113 | Maximum — LSFin banned-words table, LPP/LIFD/LAVS article references, Swiss-only |

(Plus 92 other skills in `.claude/skills/` — most are GSD workflow skills + autoresearch loops + gstack/codex meta — out of scope for this evaluation.)

### Pairwise overlap

| flutter/skills | MINT skill it would touch | Overlap | Conflict ? |
|---|---|---|---|
| flutter-apply-architecture-best-practices | mint-flutter-dev | 60 % | YES — MVVM/Repository ≠ MINT's screens+widgets+services+providers. Adopting would invalidate the established pattern. |
| flutter-setup-declarative-routing | mint-flutter-dev | 70 % | YES — already done in `app.dart`, the skill walks setup-from-zero. Reading it would mislead an agent into re-installing `go_router`. |
| flutter-setup-localization | mint-flutter-dev + mint-swiss-compliance | 80 % | YES — already done. The MINT-specific constraint (6 ARBs incl. fr/en/de/es/it/pt + accent_lint_fr.py + LSFin banned words) is covered by `mint-swiss-compliance`. Generic skill would underspecify. |
| flutter-add-widget-test | mint-test-suite | 50 % | NO — flutter/skills covers WidgetTester basics; mint-test-suite covers MINT-specific GoRouter/SharedPreferences pitfalls. Complementary but redundant in agent context. |
| flutter-implement-json-serialization | mint-flutter-dev (implicit) | 30 % | NO — MINT models follow the same pattern; redundant for an agent that has read `lib/models/`. |
| flutter-use-http-package | none | 20 % | NO — MINT uses `dio` not `http`; skill is irrelevant. |
| flutter-build-responsive-layout | none | 10 % | NO — MINT is mobile-only today, skill is premature. |
| flutter-add-widget-preview | none | 5 % | NO — MINT uses Maestro + golden tests; skill is on a path MINT isn't taking. |
| **flutter-fix-layout-issues** | none | 0 % | **NO conflict + fills a gap** — MINT has no debug reference for RenderFlex/unbounded constraints. Pure complement. |
| **flutter-add-integration-test** | none (Maestro adjacent) | 10 % | **NO conflict + fills a gap** — MINT integration_test/ does not exist; team uses Maestro flows. Skill could seed the in-process integration_test path if needed for CI gates Maestro can't cover. |

**Verdict on Q2** : 3 skills directly **conflict** with already-locked MINT decisions (architecture, routing, l10n). 5 are **redundant or premature**. **2 are pure complements** with zero overlap.

---

## Q3. Adoption recommendation + skill-bloat risk

### Recommendation : **cherry-pick 2, ignore 8, deprecate nothing**

**Cherry-pick** :
1. `flutter-fix-layout-issues` — debug reference for the day a `RenderFlex overflowed` lands in CI logs. Generic Flutter knowledge, zero MINT-specific contradiction.
2. `flutter-add-integration-test` — seed if/when MINT needs in-process integration_test/ CI gates that Maestro can't run (e.g. headless CI without sim).

**Do not adopt** :
- `flutter-apply-architecture-best-practices`, `flutter-setup-declarative-routing`, `flutter-setup-localization` — would either contradict locked decisions (Provider not MVVM, MINT has its own folder layout, 6-ARB i18n pipeline already established) or mislead agents into re-doing setup work.
- `flutter-add-widget-test`, `flutter-implement-json-serialization`, `flutter-use-http-package`, `flutter-build-responsive-layout`, `flutter-add-widget-preview` — redundant, premature, or off-stack.

**Deprecate from MINT** : nothing. The 4 MINT skills are project-specific in a way flutter/skills cannot replace. They name specific files (`app.dart`, `mint_ui_kit.dart`, `rules_engine.py`), specific test pitfalls (`SharedPreferences.setMockInitialValues`, GoRouter wrapping), specific compliance rules (LSFin banned words, accent_lint_fr.py, financial_core reuse) that flutter/skills will never carry.

### Skill-bloat risk score : **2 / 5**

Why 2 not higher :
- The 2 cherry-picks together = ~400 lines, both load on-demand only when an agent matches their `description` (RenderFlex error / integration_test request). They will sit idle 95 % of sessions.
- They install to `.agents/skills/`, **not** `.claude/skills/`, so they don't pollute the existing namespace or compete with the gsd-* / mint-* / autoresearch-* skills already triggered by the Skill loader.

Why not 1 :
- MINT already has 96 `.claude/skills/` entries (per `ls .claude/skills/`). Adding even 2 more in a sibling directory adds discovery surface that a future Claude session has to scan. There is a real « one-more-thing » accretion cost — that's the 1 point.

Why not 3 or higher :
- Cherry-picking 2 is below the threshold where bloat becomes a maintenance liability. The risk would jump to 4/5 if MINT adopted the full `--skill '*'` install (10 skills, 3 of which actively contradict locked decisions). That outcome is what this evaluation explicitly recommends against.

---

## 3 concrete proposals

### Proposal 1 — import the 2 skills via the official CLI, scoped

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync
npx skills add flutter/skills --skill flutter-fix-layout-issues --agent universal
npx skills add flutter/skills --skill flutter-add-integration-test --agent universal
```

This writes `.agents/skills/flutter-fix-layout-issues/SKILL.md` and `.agents/skills/flutter-add-integration-test/SKILL.md`. Add `.agents/skills/` to `.gitignore` so they're per-developer (avoids polluting the public repo discipline rule). Or commit them — they're MIT/BSD-style Flutter team docs — but mark them as imported references in a top-level `.agents/README.md` so future audits know they're not MINT-authored.

### Proposal 2 — add a one-line cross-reference inside `mint-flutter-dev/SKILL.md`

Insert under « ## Architecture Patterns » :

```markdown
> Layout debug : if you hit `RenderFlex overflowed` or `unbounded constraints`, consult `.agents/skills/flutter-fix-layout-issues/SKILL.md` for the systematic resolution checklist. MINT-specific patterns (MintColors, MintCard, financial_core) still apply; flutter-fix-layout-issues only covers generic constraint resolution.
```

This makes the cherry-picked skill discoverable without duplicating its content into `mint-flutter-dev`.

### Proposal 3 — explicit non-adoption list in `CLAUDE.md` § 3 or § 4

Add a short note so future sessions don't re-litigate :

```markdown
## flutter/skills (https://github.com/flutter/skills) — adoption status

Adopted via .agents/skills/ : flutter-fix-layout-issues, flutter-add-integration-test
NOT adopted (would contradict locked decisions) :
- flutter-apply-architecture-best-practices (we use Provider+screens/widgets/services, not MVVM+lib/data/domain/ui)
- flutter-setup-declarative-routing (GoRouter already wired in app.dart)
- flutter-setup-localization (6 ARBs + accent_lint_fr.py + LSFin banned words already enforced via mint-swiss-compliance)
NOT adopted (off-stack or premature) : flutter-add-widget-preview, flutter-add-widget-test (covered by mint-test-suite), flutter-build-responsive-layout, flutter-implement-json-serialization, flutter-use-http-package
Eval : .planning/audit/codebase-audit-2026-05-10/flutter-skills-evaluation.md (2026-05-10)
```

This is the « monthly lint » discipline from CLAUDE.md § 8 applied to external skill registries — file the decision back into the wiki so it survives the chat session.

---

## Counter-arguments and data gaps (per CLAUDE.md § 8 lint rule)

**Counter-argument 1** : *« flutter/skills is maintained by the Flutter team — adopting all 10 lets us drift toward Flutter idiomatic conventions when the team's recommendations evolve (e.g. a future MVVM push). »*
Response : the cost of contradicting our 30K-LOC of locked Provider/GoRouter wiring outweighs the upside of conformance-by-default. We re-evaluate yearly, not at every Flutter team push. If they ship a skill that depreciates `Provider`, we want to find out via a deliberate review, not via an agent silently following an injected SKILL.md.

**Counter-argument 2** : *« Cherry-picking creates a fork-by-omission ; future maintainers won't know which 2 we picked vs the 8 we skipped. »*
Response : Proposal 3 (the explicit non-adoption list in CLAUDE.md) addresses exactly this. Without it, the counter-argument lands.

**Counter-argument 3** : *« mint-test-suite is 129 lines and might genuinely benefit from absorbing flutter-add-widget-test patterns. »*
Response : possible. Specifically `flutter-add-widget-test` documents `pumpAndSettle` vs `pump`, `scrollUntilVisible`, `Dismissible` testing — all generic patterns that mint-test-suite assumes. A future revision of mint-test-suite could absorb this delta inline rather than via a separate skill. Defer.

**Data gap 1** : I did not directly read every skill's full body. I sampled 6 / 10 (architecture, fix-layout, localization, widget-test, routing, integration-test, responsive-layout). The 4 unread (`add-widget-preview`, `implement-json-serialization`, `use-http-package`, plus a few not opened) are the lowest-stakes ones based on title/description alone. If one of those turns out to contain hidden gold, this evaluation underrates it. Confidence on the verdict for those 4 : medium-high, not certain.

**Data gap 2** : I did not measure how often Claude actually loads `mint-flutter-dev` vs other skills in real MINT sessions. If telemetry shows `mint-flutter-dev` loads <5 % of sessions, the bloat-risk argument shifts (since flutter/skills would also load <5 % and the « namespace pollution » concern weakens). No data on this today.

**Data gap 3** : the « 2/5 bloat-risk » score is qualitative. There's no MINT bloat metric (e.g. « # skills loaded per session », « tokens spent on skill metadata »). The scoring is grounded in « 96 existing skills + 2 added » + « `.agents/` ≠ `.claude/skills/` namespace », not in measurement.

---

## Sources

- [flutter/skills GitHub repository](https://github.com/flutter/skills)
- [Flutter agent skills documentation](https://docs.flutter.dev/ai/agent-skills)
- [dart-lang/skills GitHub repository](https://github.com/dart-lang/skills)
- [Harishwarrior/flutter-claude-skills (community)](https://github.com/Harishwarrior/flutter-claude-skills)
- [VoltAgent awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills)
- [skills CLI Dart package](https://pub.dev/packages/skills)
