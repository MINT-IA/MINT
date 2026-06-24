# CLAUDE.md — MINT Context (auto-loaded)

> Detail : [flutter](docs/AGENTS/flutter.md) · [backend](docs/AGENTS/backend.md) · [swiss-brain](docs/AGENTS/swiss-brain.md). Conflict : `rules.md` > this > `.claude/skills/*`.

## 🚨 TOP — 6 RULES CRITIQUES (repeat at BOTTOM — Liu 2024 lost-in-the-middle mitigation)

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». Use « pourrait », « envisager », « adapté ». Full list → [swiss-brain.md §1](docs/AGENTS/swiss-brain.md).
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`, `decouvrir → découvrir`, `securite → sécurité`, `premier éclairage` (jamais `premier eclairage`). ASCII « e » à la place de « é » = bug. Lint : `tools/checks/accent_lint_fr.py`.
3. **MINT ≠ retirement app** — 18 life events equally weighted (housing, family, tax, career, debt…). Never frame screens/prompts as « retraite-first ». Target : 18-99. Pivot 2026-04-12 : lucidité, pas protection.
4. **Financial_core reuse mandatory** — <!-- mint-data-architecture-v1-01-canonical:start --> `lib/services/financial_core/` est SOURCE OF TRUTH **pour L1 chiffrer** (single-number deterministic outputs, offline-capable). **L2-L4 (comparer / éclairer / invariants) = backend-canonical** sous `services/backend/app/services/`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type (L1ChiffrePayload → mobile ; L2ComparePayload / L3EclairePayload / L4InvariantPayload → backend). Never re-implement `_calculate*()` cross-layer. ADR : `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` (calc-engine portion, Decided 2026-05-17) + legacy `decisions/ADR-20260223-unified-financial-engine.md`. Phase : `mint-data-architecture-v1-01-calc-engine-canonical`. <!-- mint-data-architecture-v1-01-canonical:end -->
5. **i18n required** — Toutes strings user-facing via `AppLocalizations.of(context)!.key`. Never `Text('Bonjour')`. 6 ARB files (fr/en/de/es/it/pt) sous `lib/l10n/`. Run `flutter gen-l10n`.
6. **0-TRUST — never trust your own claims** — banned without deterministic citation in same message: « shipped », « closed », « ready », « works », « validated », « green », « PROVISIONALLY READY ». Citation = `path:line` / command output / `idb ui describe-all` snapshot / PR-merge timestamp / Julien confirmation. **PR opened ≠ shipped. Tests passing ≠ feature working.** End-to-end user flow on sim before any « ready ». Detail → § 9.

---

## 1. IDENTITY & ARCHITECTURE

MINT = Swiss financial lucidity app (Flutter + FastAPI). Pivot 2026-04-12 : lucidité, pas protection. 18-99, segmentation par life event. <!-- mint-data-architecture-v1-01-canonical:start --> `apps/mobile/lib/services/financial_core/` = ★ L1 chiffrer canonical home (single-number outputs, offline-capable, bundle-size validated 4509 gzip bytes / 95.6% headroom vs 100 KB ceiling per `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-BUNDLE-SIZE-REPORT.md`) ; `services/backend/app/services/` = L2-L4 canonical (comparer / éclairer / invariants — backend-canonical for L2-L4). Boundary = `services/backend/app/models/lucidity/_payload.py` discriminator. <!-- mint-data-architecture-v1-01-canonical:end --> `lib/theme/colors.dart` MintColors · `lib/l10n/` 6 ARBs · `services/backend/` FastAPI Pydantic v2 camelCase. Role docs : `docs/AGENTS/{flutter,backend,swiss-brain}.md`. Full identity : `docs/MINT_IDENTITY.md`.

## 2. COMMANDS

```bash
cd services/backend && python3 -m pytest tests/ -q && uvicorn app.main:app --reload
cd apps/mobile && flutter analyze && flutter test && flutter gen-l10n
```

## 3. MCP TOOLS (Phase 30.7, on-demand via `mint-tools` / `.mcp.json`)

`get_swiss_constants(category)` pillar3a/lpp/avs/mortgage/tax · `check_banned_terms(text)` LSFin scan+sanitize · `validate_arb_parity()` 6-lang ARB check · `check_accent_patterns(text)` 14-pattern FR lint.

**Engram MCP** (`plugin:engram:engram`, auto-loaded user-scope) — persistent memory for subagents. Tools : `mem_save`, `mem_search`, `mem_context`, `mem_stats`, `mem_conflicts` (beta), 19 total. **Live DB : `~/.engram/engram.db`** (used by `engram serve` + `engram mcp` daemons — integrity-check OK, 122+ obs). The legacy `/Volumes/FUN2/engram/engram.db` is abandoned/corrupted as of 2026-05-16 — don't restore. `ENGRAM_DATA_DIR=/Volumes/FUN2/engram` is still exported in `~/.zshrc` so the CLI `engram save` / `engram doctor` fail with « database disk image is malformed (11) » — prefer MCP tools (`mem_save` etc.) over the CLI until the env var is removed. Setup : `docs/AGENTS/VIBE-CODING-INFRA.md`.

## 3.5. TEAM AGENTS (subagents, `.claude/agents/`)

Default roster is Mint-specific and small:

| Agent | File | Use |
|---|---|---|
| `mint-lead` | `.claude/agents/mint-lead.md` | scope, sequencing, PR verdict |
| `mint-quality-gate` | `.claude/agents/mint-quality-gate.md` | auth/privacy/onboarding/runtime gates |
| `mint-mobile` | `.claude/agents/mint-mobile.md` | `apps/mobile/` implementation |
| `mint-backend` | `.claude/agents/mint-backend.md` | `services/backend/` implementation |
| `mint-swiss-brain` | `.claude/agents/mint-swiss-brain.md` | Swiss financial meaning/compliance |

Default route:

`mint-lead` -> `mint-quality-gate` -> `mint-mobile` / `mint-backend` /
`mint-swiss-brain` -> `mint-quality-gate`.

The imported wshobson, VoltAgent, and GSD catalogs remain in `.claude/agents/`
as vendor/on-demand specialists. Do not auto-route to them by description
matching. Use them only for a named gap after a Mint agent asks for a specific
specialist pass.

Engram MCP remains useful for prior root causes and decisions, but checked-in
repo rules, current code, tests, CI, and runtime evidence are authoritative.

## 4. DEV RULES

Git : `feature/S{XX}-<slug>` depuis `dev` ; PRs feature→dev squash, dev→staging+staging→main merge ; never force push ; `--rebase` on pull ; `git status` clean avant mod. Tests : ≥10 unit/service, Julien+Lauren golden, `flutter analyze` + `pytest -q` green (tests green ≠ app functional, device Gate 0 obligatoire).

### 4.1 Staging Push Authority

Codex/Claude agents are authorized to push to `staging` when Julien asks for it or when the explicit goal is to advance a verified integration branch to staging.

Allowed path:
1. Verify clean worktree: `git status --short` empty.
2. Verify branch hygiene: `git fetch origin`, `git status -sb`, no unexpected divergence.
3. Verify latest integration source: PR checks or cited local gates green for the exact head being promoted.
4. Update local `staging` from `origin/staging` without rewriting history.
5. Merge the verified source branch into `staging` with a normal merge or fast-forward.
6. Push with plain `git push origin staging`.

Forbidden:
- `git push --force`, `git push --force-with-lease`, or any history rewrite on `staging`, `dev`, or `main`.
- Pushing `staging` with a dirty worktree, unresolved conflicts, unknown CI status, or unreviewed local-only changes.
- Claiming staging works before a post-push sim/device or staging health check is cited per §9.

If GitHub branch protection rejects direct push to `staging`, open a PR into `staging` instead of bypassing protection.

## 5. 10 TRIPLETS {bad → good → why} (D-07)

### NEVER #1 — Hardcode user-facing strings
- ❌ `Text('Bonjour')`
- ✅ `Text(AppLocalizations.of(context)!.greetingMorning)`
- ⚠️ invoque `validate_arb_parity()` avant PR i18n.

### NEVER #2 — Hardcode colors
❌ `Color(0xFF003B2F)` · ✅ `MintColors.primary` · ⚠️ theme, dark-mode, canton branding.

### NEVER #3 — Duplicate calculation logic across the L1/L2 boundary
<!-- mint-data-architecture-v1-01-canonical:start -->
❌ `_calculateRente(profile)` re-implemented in a backend service (L1 is mobile-canonical) OR re-implemented in a Dart widget for an L2 sensitivity / Monte Carlo (L2-L4 is backend-canonical) · ✅ L1 outputs (returning L1ChiffrePayload) live in `lib/services/financial_core/` ; L2-L4 outputs (returning L2/L3/L4 payloads) live in `services/backend/app/services/`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type · ⚠️ single source of truth per layer ; backend parity for L1 NOT required (mobile is canonical for L1). Strangler-fig migration (D-11) governs any cross-layer move.
<!-- mint-data-architecture-v1-01-canonical:end -->

### NEVER #4 — Frame MINT as retirement app
❌ « Préparez votre retraite » hero copy · ✅ framer par life event (housing/career/family/tax) · ⚠️ 18-99, exclure 25 ans casse trust.

### NEVER #5 — Use banned terms
- ❌ « rendement garanti », « l'optimal », « sans risque »
- ✅ invoque `check_banned_terms(text)` MCP → `banned_found` + `sanitized_text`
- ⚠️ top-3 critiques listés TOP/BOTTOM #1.

### NEVER #6 — Code without reading existing code
❌ nouveau widget sans grep · ✅ `grep -r "ClassName" apps/mobile/lib/` avant Write · ⚠️ façade-sans-câblage doctrine #1 (W14 : 72 files supprimés).

### NEVER #7 — Assume Swiss native archetype
❌ default `swiss_native` · ✅ detect (`expat_eu`, `expat_us` FATCA, `cross_border`, `independent_no_lpp`…) · ⚠️ 8 archetypes, FATCA/frontalier ≠ edge cases.

### NEVER #8 — Promise returns
❌ « Votre 3a rapportera X CHF » · ✅ scénario Bas/Moyen/Haut + hypothèses éditables + sensitivity · ⚠️ no-promise LSFin art. 7-10.

### NEVER #9 — Projection without confidence score
❌ LPP bare number · ✅ `EnhancedConfidence` + uncertainty band + `enrichmentPrompts` · ⚠️ 4-axis (completeness×accuracy×freshness×understanding).

### NEVER #10 — Skip tests
❌ commit sans `pytest` ou `flutter test` · ✅ suite green + golden + device walkthrough · ⚠️ v2.2 = 9326 tests green + 4 bugs device.

## 6. QUICK LINKS

`rules.md` · `docs/MINT_IDENTITY.md` · `docs/DESIGN_SYSTEM.md` · `docs/VOICE_SYSTEM.md` · `SOT.md` · `docs/ROADMAP_V2.md` · `.claude/skills/mint-{swiss-compliance,flutter-dev,backend-dev}/SKILL.md` · `.planning/INDEX.md`.

## 7. BEHAVIOR FOUNDATION — Karpathy 4 (LLM coding pitfalls, [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills))

> Karpathy : *« The models make wrong assumptions on your behalf and just run along with them without checking. They don't manage their confusion, don't seek clarifications, don't surface inconsistencies, don't present tradeoffs. They overcomplicate code, bloat abstractions, don't clean up dead code. »* These 4 principles override default speed bias when in doubt.

### #1 Think Before Coding — *don't assume, surface tradeoffs*
- State assumptions explicitly. If uncertain → ask (per memory `feedback_blockers_ask_dont_defer.md`).
- Multiple interpretations exist → present them, don't pick silently.
- Simpler approach exists → say so, push back when warranted.
- Something unclear → stop, name what's confusing, ask.

### #2 Simplicity First — *minimum code that solves the problem*
- No features beyond what was asked.
- No abstractions for single-use code.
- No « flexibility » / « configurability » not requested.
- No error handling for impossible scenarios.
- 200 lines that could be 50 → rewrite. Test : *« Would a senior engineer say this is overcomplicated ? »*

### #3 Surgical Changes — *touch only what you must, clean only your own mess*
- Don't « improve » adjacent code, comments, formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Notice unrelated dead code → mention, don't delete (unless asked).
- Test : *« Every changed line traces directly to the user's request ? »*

### #4 Goal-Driven Execution — *define success criteria, loop until verified*
- « Add validation » → « Write tests for invalid inputs, then make them pass ».
- « Fix the bug » → « Write a test that reproduces it, then make it pass ».
- « Refactor X » → « Tests pass before AND after ».
- Multi-step task → state plan with `verify:` per step. Strong success criteria let you loop independently. Weak criteria force constant clarification.

**Working when :** fewer unnecessary diff lines, fewer overcomplication rewrites, clarifying questions BEFORE implementation rather than mistake post-mortems.

## 8. WIKI SCHEMA — `.planning/` Karpathy Wiki Pattern conventions

> Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) : *« the LLM is rediscovering knowledge from scratch on every question. There's no accumulation. »* MINT's `.planning/` is the **agent vault** ; `~/.claude/projects/.../memory/` is the **curator vault** (separate per Karpathy practice 1).

**Three layers** :
- **`raw/`** — implicit : `~/Downloads/handoff*/` PDFs, articles, panels-input. Read-only ; never modified by Claude.
- **`.planning/`** — agent-owned wiki. CONTEXT, PLAN, VERIFICATION, decisions, reports, milestones, roadmap, state. Claude writes ; you read.
- **`CLAUDE.md`** (this file) + **`.claude/skills/`** — schema layer. How Claude maintains the wiki.

**Conventions enforced by `tools/checks/wiki_lint.py`** :

1. **TLDR mandatory** — every `.planning/**/*.md` must have either a `description:` frontmatter line OR a non-trivial first paragraph. Auto-extracted into `.planning/INDEX.md` (regen via `python3 tools/checks/wiki_lint.py index`).
2. **Counter-arguments and data gaps** required on every decision artifact (`.planning/decisions/*.md`) — bias-check against echo-chamber. Template at `.planning/decisions/_TEMPLATE.md`. **HARD lint** (FAIL on missing).
3. **File queries back into the wiki** — when a session produces a valuable analysis (panel synthesis, postmortem, audit), file it as a new ADR or `.planning/audit/<topic>.md` page. Don't let it die in chat history.
4. **Monthly lint** — run `python3 tools/checks/wiki_lint.py` to surface contradictions, stale claims, orphan pages, new article candidates. Pre-commit hook (lefthook) runs it on `.planning/**/*.md` touches.

**Scale plan** (Karpathy practice 6, mark in `INDEX.md` when crossed) :
- 0-300 .md pages : flat files + INDEX.md (current : ~455, but most are leaf reports).
- 300-500 article-class pages : add FTS5 / BM25 (`qmd` candidate).
- 500+ : Postgres + frontmatter-driven views.

**Anti-pattern (Karpathy practice 1)** : never write speculative agent-generated drafts into `~/.claude/projects/.../memory/` (curator vault). All Claude-generated content lives in `.planning/`.

## 7. BEHAVIOR FOUNDATION — Karpathy 4 (LLM coding pitfalls, [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills))

> Karpathy : *« The models make wrong assumptions on your behalf and just run along with them without checking. They don't manage their confusion, don't seek clarifications, don't surface inconsistencies, don't present tradeoffs. They overcomplicate code, bloat abstractions, don't clean up dead code. »* These 4 principles override default speed bias when in doubt.

### #1 Think Before Coding — *don't assume, surface tradeoffs*
- State assumptions explicitly. If uncertain → ask (per memory `feedback_blockers_ask_dont_defer.md`).
- Multiple interpretations exist → present them, don't pick silently.
- Simpler approach exists → say so, push back when warranted.
- Something unclear → stop, name what's confusing, ask.

### #2 Simplicity First — *minimum code that solves the problem*
- No features beyond what was asked.
- No abstractions for single-use code.
- No « flexibility » / « configurability » not requested.
- No error handling for impossible scenarios.
- 200 lines that could be 50 → rewrite. Test : *« Would a senior engineer say this is overcomplicated ? »*

### #3 Surgical Changes — *touch only what you must, clean only your own mess*
- Don't « improve » adjacent code, comments, formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Notice unrelated dead code → mention, don't delete (unless asked).
- Test : *« Every changed line traces directly to the user's request ? »*

### #4 Goal-Driven Execution — *define success criteria, loop until verified*
- « Add validation » → « Write tests for invalid inputs, then make them pass ».
- « Fix the bug » → « Write a test that reproduces it, then make it pass ».
- « Refactor X » → « Tests pass before AND after ».
- Multi-step task → state plan with `verify:` per step. Strong success criteria let you loop independently. Weak criteria force constant clarification.

**Working when :** fewer unnecessary diff lines, fewer overcomplication rewrites, clarifying questions BEFORE implementation rather than mistake post-mortems.

## 9. 0-TRUST PROTOCOL — Never trust your own claims (grounded, 2026-05-07)

> Anthropic 2026 ([Reduce hallucinations](https://docs.claude.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations)) : *« cite quotes and sources for each claim. If it can't find a quote, it must retract the claim. »*
> [Ralphable 2026](https://ralphable.com/blog/claude-code-hallucination-problem-atomic-skills-reliable-output) : *« atomic tasks with explicit pass/fail criteria force the agent to ground each step in reality before proceeding. »*
> [johnsonlee.io 2026](https://johnsonlee.io/2026/03/28/ground-truth-core-competency-of-ai-engineering.en/) : *« using a probabilistic tool to verify probabilistic output is the same as no verification. Ground truth must be deterministic. »*

**Why this section exists** : 2026-05-07 session — opened 4 PRs, called « PROVISIONALLY READY » on P1/P2/P3, then Julien sent a sim screenshot showing « Aucune donnée pour l'instant » + « Définis ton budget ». **Tests green + PRs open != app works.** End-to-end user flow had never been run. This section is the operational fence around that failure mode.

### 9.1 Banned phrases without deterministic citation (in the same message)

`shipped`, `livré`, `closed`, `fermé`, `ready`, `prêt`, `works`, `marche`, `validated`, `validé`, `green`, `PROVISIONALLY READY`, `MVP working`, `feature complete`.

Each requires a specific evidence type **in the same message** :

| Claim | Required evidence |
|---|---|
| `shipped` / `livré` | `gh pr view <N> --json mergedAt` returns non-null **AND** post-merge sim run touched the changed surface |
| `closed` / `fermé` | All 5 gates (G1 sim describe-all + G3 dev CI green sha + G4 test exit 0 + G5 lint exit 0 + G2 Julien confirmation) cited explicitly |
| `ready` / `prêt` | End-to-end user flow run on sim by me, with `idb ui describe-all` final state OR a screenshot reviewed by Julien |
| `works` / `marche` | I taped through the user flow on sim. Output of the final `idb ui describe-all` quoted. |
| `validated` | Either Julien said « ok » in chat OR a deterministic checker (test, lint, type-check) returned exit 0 with the command output cited |
| `green` (about CI) | `gh pr checks <N>` output pasted with all jobs ≠ `fail` and ≠ `pending` |

If I cannot cite the evidence type → I do NOT use the claim word. I use **`unit tests green, end-to-end UNKNOWN`** or **`PR opened, merge + sim verification pending`** or **`I haven't checked`**. Honest > optimistic.

### 9.2 Tests passing ≠ feature working

A unit test green means « given input X, function returns Y ». A feature working means « a real user can complete the flow and see the expected result ». **The two are NEVER substitutes.** Stating « 7/7 tests green » does NOT entitle me to say « the feature works ». They're separate truths and they need separate citations.

### 9.3 Strict Write Discipline on PERIMETERS.md & status fields

- A perimeter STATUS = « PROVISIONALLY READY » requires G1 sim walker output **already present in the GATE LOG** for the LATEST fix on that perimeter (timestamp ≥ last fix-PR commit time).
- Opening a PR is **starting** work. Not « shipping ». Not « closing ». Status remains 🟡 IN_FLIGHT until merged AND post-merge sim re-run logged.
- A panel auditor's verdict (« PASS ») is a recommendation, not a gate. The gate is mechanical : sim output, CI exit code, lint exit code, Julien's eyes.

### 9.4 End-of-turn 3-step self-audit (mandatory before any summary)

Before every sentence that would contain one of the §9.1 banned words, run this :

1. **Citation test** — name the file path / command output / `idb` snapshot / PR-merge timestamp that proves the claim. If I can't, retract the claim.
2. **Sim survival test** — *« If Julien opens his sim right now, would my claim survive ? »* If the sim could plausibly show emptiness while I claim « shipped », retract.
3. **Work vs value separation** — separate WORK DONE (PRs opened, tests passing, code edited, lints clean) from USER VALUE DELIVERED (end-to-end flow visibly works for Julien). State both, never conflate.

### 9.5 The « PR opened ≠ shipped » trap (2026-05-07 lesson)

The shipping pipeline has 4 stages : open PR → review → merge → user sees change. I called « shipped » at stage 1 of 4. The 4 stages are :

| Stage | What I can claim | What I cannot claim |
|---|---|---|
| PR opened | « PR #N opened, awaiting CI » | « shipped », « ready », « closed » |
| CI green | « CI green on PR #N » | « ready », « works » (still not merged) |
| Merged | « Merged to dev as <sha> » | « works » (not yet sim-verified post-merge) |
| Post-merge sim | « Sim describe-all shows X after merge » | now I can say « works » for that flow |

### 9.6 The required claim format

When I claim something works, the format is :

```
Evidence : <file path / command output / sim snapshot / PR sha>
Caveat   : <what I have NOT checked>
```

NOT : `✅ shipped`, `✅ ready`, `✅ green`, `✅ closed`. The checkmark is the bullshit signal — the receipt is the citation.

### 9.7 « I don't know » is the highest-quality answer

When uncertain : « I don't know, I haven't checked » beats « should work » / « expected behavior » / « PROVISIONALLY READY ». The first triggers verification ; the second two trigger Julien-frustration-driven session restarts.

---

## 🚨 BOTTOM — 6 RULES CRITIQUES (duplicated intentionally, Liu 2024)

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur ». Use « pourrait », « envisager ».
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`. ASCII = bug.
3. **MINT ≠ retirement app** — 18 life events equally weighted. Frame generically, pas « retraite-first ».
4. **Financial_core reuse mandatory** — <!-- mint-data-architecture-v1-01-canonical:start --> `lib/services/financial_core/` est SOURCE OF TRUTH **pour L1 chiffrer** (single-number deterministic outputs, offline-capable). **L2-L4 (comparer / éclairer / invariants) = backend-canonical** sous `services/backend/app/services/`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type (L1ChiffrePayload → mobile ; L2ComparePayload / L3EclairePayload / L4InvariantPayload → backend). Never re-implement `_calculate*()` cross-layer. ADR : `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` (calc-engine portion, Decided 2026-05-17). <!-- mint-data-architecture-v1-01-canonical:end -->
5. **i18n required** — `AppLocalizations.of(context)!.key`. 6 ARB files. Run `flutter gen-l10n`.
6. **0-TRUST — never trust your own claims** — banned without deterministic citation : « shipped », « closed », « ready », « works », « validated », « green », « PROVISIONALLY READY ». PR opened ≠ shipped. Tests passing ≠ feature working. End-to-end sim run before any « ready ». Detail § 9.
