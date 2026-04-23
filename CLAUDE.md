# CLAUDE.md — MINT Context (auto-loaded)

> Detail : [flutter](docs/AGENTS/flutter.md) · [backend](docs/AGENTS/backend.md) · [swiss-brain](docs/AGENTS/swiss-brain.md). Conflict : `rules.md` > this > `.claude/skills/*`.

## 🚨 TOP — 5 RULES CRITIQUES (repeat at BOTTOM — Liu 2024 lost-in-the-middle mitigation)

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». Use « pourrait », « envisager », « adapté ». Full list → [swiss-brain.md §1](docs/AGENTS/swiss-brain.md).
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`, `decouvrir → découvrir`, `securite → sécurité`, `premier éclairage` (jamais `premier eclairage`). ASCII « e » à la place de « é » = bug. Lint : `tools/checks/accent_lint_fr.py`.
3. **MINT ≠ retirement app** — 18 life events equally weighted (housing, family, tax, career, debt…). Never frame screens/prompts as « retraite-first ». Target : 18-99. Pivot 2026-04-12 : lucidité, pas protection.
4. **Financial_core reuse mandatory** — `lib/services/financial_core/` est SOURCE OF TRUTH. Never re-implement `_calculate*()` dans services. ADR : `decisions/ADR-20260223-unified-financial-engine.md`.
5. **i18n required** — Toutes strings user-facing via `AppLocalizations.of(context)!.key`. Never `Text('Bonjour')`. 6 ARB files (fr/en/de/es/it/pt) sous `lib/l10n/`. Run `flutter gen-l10n`.

---

## 1. IDENTITY & ARCHITECTURE

MINT = Swiss financial lucidity app (Flutter + FastAPI). Pivot 2026-04-12 : lucidité, pas protection. 18-99, segmentation par life event. `apps/mobile/lib/services/financial_core/` = ★ shared calculators (source of truth) · `lib/theme/colors.dart` MintColors · `lib/l10n/` 6 ARBs · `services/backend/` FastAPI Pydantic v2 camelCase. Role docs : `docs/AGENTS/{flutter,backend,swiss-brain}.md`. Full identity : `docs/MINT_IDENTITY.md`.

## 2. COMMANDS

```bash
cd services/backend && python3 -m pytest tests/ -q && uvicorn app.main:app --reload
cd apps/mobile && flutter analyze && flutter test && flutter gen-l10n
```

## 3. MCP TOOLS (Phase 30.7, on-demand via `mint-tools` / `.mcp.json`)

`get_swiss_constants(category)` pillar3a/lpp/avs/mortgage/tax · `check_banned_terms(text)` LSFin scan+sanitize · `validate_arb_parity()` 6-lang ARB check · `check_accent_patterns(text)` 14-pattern FR lint.

## 4. DEV RULES

Git : `feature/S{XX}-<slug>` depuis `dev` ; PRs feature→dev squash, dev→staging+staging→main merge ; never force push ; `--rebase` on pull ; `git status` clean avant mod. Tests : ≥10 unit/service, Julien+Lauren golden, `flutter analyze` + `pytest -q` green (tests green ≠ app functional, device Gate 0 obligatoire).

## 5. 10 TRIPLETS {bad → good → why} (D-07)

### NEVER #1 — Hardcode user-facing strings
- ❌ `Text('Bonjour')`
- ✅ `Text(AppLocalizations.of(context)!.greetingMorning)`
- ⚠️ invoque `validate_arb_parity()` avant PR i18n.

### NEVER #2 — Hardcode colors
❌ `Color(0xFF003B2F)` · ✅ `MintColors.primary` · ⚠️ theme, dark-mode, canton branding.

### NEVER #3 — Duplicate calculation logic
❌ `_calculateRente(profile)` dans un service · ✅ `AvsCalculator.computeMonthlyRente` depuis `financial_core/` · ⚠️ single source of truth, backend parity.

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

`rules.md` · `docs/MINT_IDENTITY.md` · `docs/DESIGN_SYSTEM.md` · `docs/VOICE_SYSTEM.md` · `SOT.md` · `docs/ROADMAP_V2.md` · `.claude/skills/mint-{swiss-compliance,flutter-dev,backend-dev}/SKILL.md`.

## 🚨 BOTTOM — 5 RULES CRITIQUES (duplicated intentionally, Liu 2024)

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur ». Use « pourrait », « envisager ».
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`. ASCII = bug.
3. **MINT ≠ retirement app** — 18 life events equally weighted. Frame generically, pas « retraite-first ».
4. **Financial_core reuse mandatory** — `lib/services/financial_core/`. Never re-implement `_calculate*()`.
5. **i18n required** — `AppLocalizations.of(context)!.key`. 6 ARB files. Run `flutter gen-l10n`.
