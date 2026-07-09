# CLAUDE.md — MINT Project Context (auto-loaded)

> Loaded at every session start. Quickref ~150L.
> Role-scoped detail : [docs/AGENTS/flutter.md](docs/AGENTS/flutter.md) · [docs/AGENTS/backend.md](docs/AGENTS/backend.md) · [docs/AGENTS/swiss-brain.md](docs/AGENTS/swiss-brain.md).
> Conflict resolution : `rules.md` (tier 1) > this file (tier 2) > `.claude/skills/*` (tier 3).
> Memory hierarchy : repo git/ADR/AGENTS_LOG is the source of truth. Engram is a recall index, not a primary source. If memory conflicts with the checked-in repo, the repo wins.

## 🚨 TOP — 5 RULES CRITIQUES (repeat at BOTTOM — Liu 2024 lost-in-the-middle mitigation)

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». Use « pourrait », « envisager », « adapté ». Full list → [swiss-brain.md §1](docs/AGENTS/swiss-brain.md). Mechanical UI scan enforced by hook/CI: banned-ui-terms.
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`, `decouvrir → découvrir`, `securite → sécurité`, `premier éclairage` (jamais `premier eclairage`). ASCII « e » à la place de « é » = bug. Mechanical scan enforced by hook/CI: accent-lint-fr.
3. **MINT ≠ retirement app** — 18 life events equally weighted (housing, family, tax, career, debt…). Never frame screens/prompts as « retraite-first ». Target : 18-99. Pivot 2026-04-12 : lucidité, pas protection.
4. **Financial_core reuse mandatory** — `lib/services/financial_core/` est SOURCE OF TRUTH. Never re-implement `_calculate*()` dans services. ADR : `decisions/ADR-20260223-unified-financial-engine.md`. Mechanical scan enforced by hook/CI: financial-core-gate.
5. **i18n required** — Toutes strings user-facing via `AppLocalizations.of(context)!.key`. Never `Text('Bonjour')`. 6 ARB files (fr/en/de/es/it/pt) sous `lib/l10n/`. Mechanical scan enforced by hook/CI: no-hardcoded-fr, arb-parity.

---

## 1. IDENTITY (1-line)

MINT = Swiss financial lucidity app (Flutter + FastAPI). Read-only, éducative, 4-layer insight engine. Full : `docs/MINT_IDENTITY.md`. **Pivot 2026-04-12 : lucidité, pas « protection-first ».** Target ALL Swiss residents 18-99, segmentation par life event + lifecycle phase, JAMAIS par âge.

## 2. ARCHITECTURE (tree sketch)

```
apps/mobile/                 # Flutter (iOS/Android/Web)
  lib/services/financial_core/   # ★ SHARED CALCULATORS — single source of truth
  lib/theme/colors.dart          # MintColors palette
  lib/l10n/                      # ARB files (6 languages)
services/backend/            # FastAPI (Python, Pydantic v2, camelCase alias)
docs/AGENTS/{flutter,backend,swiss-brain}.md    # role-scoped detail
.claude/skills/mint-*/SKILL.md                  # operational skills
```

## 3. COMMANDS

```bash
# Backend
cd services/backend && python3 -m pytest tests/ -q && uvicorn app.main:app --reload

# Mobile
cd apps/mobile && flutter analyze && flutter test && flutter gen-l10n
```

### 3.1 EXTERNAL CLAUDE AUDIT (latency policy)

Use the checked-in wrapper, never raw `claude -p`, for external reviews:

```bash
tools/checks/claude_external_audit.sh code <base-ref>
tools/checks/claude_external_audit.sh specs
tools/checks/claude_external_audit.sh architecture
```

The wrapper is intentionally bounded: Opus high by default, Sonnet high for
same-gate reruns via `CLAUDE_AUDIT_RERUN=1`, `--safe-mode`,
`--strict-mcp-config`, empty MCP config, `--no-session-persistence`, and bounded
tools. Use `--effort max` only for a named final-release/P0 dispute with
`CLAUDE_AUDIT_ALLOW_MAX=1`. Do not add unsupported `--max-turns`: the installed
Claude CLI does not expose it, and the wrapper rejects `CLAUDE_AUDIT_MAX_TURNS`
so agents cannot rely on a fake safety knob.

## 4. ROLE ROUTING

- **Flutter work** → [docs/AGENTS/flutter.md](docs/AGENTS/flutter.md) (UX rules, design system, navigation, i18n setup, anti-bug discipline).
- **Backend work** → [docs/AGENTS/backend.md](docs/AGENTS/backend.md) (Pydantic v2, pure functions, testing, FastAPI patterns, error handling).
- **Compliance / Swiss law** → [docs/AGENTS/swiss-brain.md](docs/AGENTS/swiss-brain.md) (archetypes, banned terms full list, LPP/AVS/LIFD refs, golden couple Julien+Lauren).

## 5. DEV RULES (common)

- Branches : `feature/S{XX}-<slug>` depuis `dev`. Hotfix : `hotfix/<slug>`. Never force push. Always `--rebase` on pull.
- PRs : feature→dev (squash), dev→staging (merge), staging→main (merge). Promotion PRs seulement sur demande user.
- Before code mod : `git branch --show-current` (confirm feature branch) + `git status` (clean).
- Testing : service files ≥ 10 unit tests, Julien + Lauren golden contre valeurs connues, `flutter analyze` 0 issues + `pytest -q` green.
- **Lucidité pivot 2026-04-12** : voir MEMORY.md §VISION — LUCIDITE. Compliance guardrails inchangés, messaging hiérarchie à revoir (deferred v2.9+).

## 6. 10 TRIPLETS {bad → good → why} (D-07, ordered by violation frequency)

### NEVER #1 — Hardcode user-facing strings
- ❌ NEVER: `Text('Bonjour')`
- ✅ INSTEAD: `Text(AppLocalizations.of(context)!.greetingMorning)`
- ⚠️ WHY: i18n drift 6 langues, ARB parity breaks, l10n CI fails, blocs MintShell audit.

### NEVER #2 — Hardcode colors
- ❌ NEVER: `Color(0xFF003B2F)`
- ✅ INSTEAD: `MintColors.primary` (depuis `lib/theme/colors.dart`)
- ⚠️ WHY: theme consistency, dark-mode ready, canton branding. 12 core tokens dans DESIGN_SYSTEM.md §3.2.

### NEVER #3 — Duplicate calculation logic
- ❌ NEVER: `double _calculateRente(profile) { ... }` dans un service file
- ✅ INSTEAD: `AvsCalculator.computeMonthlyRente(profile)` depuis `lib/services/financial_core/`
- ⚠️ WHY: single source of truth, testé contre Julien+Lauren golden, backend parity garantie.

### NEVER #4 — Frame MINT as retirement app
- ❌ NEVER: « Préparez votre retraite avec MINT » en hero copy
- ✅ INSTEAD: framer par life event (housing, career, family, tax) — 18 events equally weighted
- ⚠️ WHY: MINT sert 18-99. Retirement = 1 of 18 events. Exclure les 25 ans casse trust + growth.

### NEVER #5 — Use banned terms
- ❌ NEVER: « rendement garanti », « l'optimal », « sans risque », « meilleur choix »
- ✅ INSTEAD: « scénarios (Bas/Moyen/Haut) », « pourrait », « envisager », « adapté »
- ⚠️ WHY: LSFin compliance, FINMA, disclaimer required sur chaque projection. `ComplianceGuard` enforce.

### NEVER #6 — Code without reading existing code
- ❌ NEVER: écrire un nouveau widget sans grep pour un existant
- ✅ INSTEAD: `grep -r "ClassName" apps/mobile/lib/` avant Write tool
- ⚠️ WHY: façade-sans-câblage doctrine #1. W14 audit = 5 duplicates + 72 files supprimés en Wave E-PRIME.

### NEVER #7 — Assume Swiss native archetype
- ❌ NEVER: default retirement projection à `swiss_native`
- ✅ INSTEAD: detect archetype (`swiss_native`, `expat_eu`, `expat_us` FATCA, `cross_border` frontalier, `independent_no_lpp`, etc.) depuis profile
- ⚠️ WHY: 8 archetypes, 3a/LPP/AVS divergent. FATCA, frontalier Permis G, expat EU totalisation ne sont pas edge cases.

### NEVER #8 — Promise returns
- ❌ NEVER: « Votre 3a rapportera X CHF »
- ✅ INSTEAD: « Scénario Bas/Moyen/Haut avec hypothèses éditables + sensitivity range »
- ⚠️ WHY: no-promise compliance, LSFin art. 7-10, sensitivity (« si rendement passe de X% à Y%… ») toujours visible.

### NEVER #9 — Projection without confidence score
- ❌ NEVER: afficher LPP projected value en bare number
- ✅ INSTEAD: show `EnhancedConfidence` + uncertainty band + `enrichmentPrompts`
- ⚠️ WHY: 4-axis (completeness × accuracy × freshness × understanding), applies à ALL projections (pas juste retirement).

### NEVER #10 — Skip tests
- ❌ NEVER: commit service code sans `pytest tests/ -q` ou `flutter test`
- ✅ INSTEAD: full suite green + Julien+Lauren golden contre valeurs connues + device walkthrough pour Gate 0
- ⚠️ WHY: regressions silent sinon ; 9326 tests ne t'ont pas sauvé des 4 bugs device v2.2. Tests green ≠ app functional.

## 7. QUICK LINKS

- `rules.md` (tier 1) | `docs/MINT_IDENTITY.md` (positioning) | `docs/DESIGN_SYSTEM.md` | `docs/VOICE_SYSTEM.md`.
- `SOT.md` (data contracts) | `LEGAL_RELEASE_CHECK.md` | `DefinitionOfDone.md` | `docs/ROADMAP_V2.md`.
- `.claude/skills/mint-swiss-compliance/SKILL.md` · `.claude/skills/mint-flutter-dev/SKILL.md` · `.claude/skills/mint-backend-dev/SKILL.md`.

## 🚨 BOTTOM — 5 RULES CRITIQUES (duplicated intentionally, Liu 2024)

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur ». Use « pourrait », « envisager ».
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`. ASCII = bug.
3. **MINT ≠ retirement app** — 18 life events equally weighted. Frame generically, pas « retraite-first ».
4. **Financial_core reuse mandatory** — `lib/services/financial_core/`. Never re-implement `_calculate*()`.
5. **i18n required** — `AppLocalizations.of(context)!.key`. 6 ARB files. Run `flutter gen-l10n`.
