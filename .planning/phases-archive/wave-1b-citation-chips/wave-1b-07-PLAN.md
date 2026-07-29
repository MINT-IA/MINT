---
phase: wave-1b
plan: 07
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
autonomous: true
requirements: [WAVE1B-06]
must_haves:
  truths:
    - "15 new ARB keys exist in app_fr.arb: coachCitationChipsHeader, coachCitationChipLabel (with toolDisplayName placeholder), coachCitationModalTitle (with toolDisplayName placeholder), coachCitationJsonViewerLabel, coachCitationRememberCta, plus 6 tool display name keys (coachToolBudgetSnapshot, coachToolRetirementProjection, coachToolCrossPillarAnalysis, coachToolCoupleOptimization, coachToolCapStatus, coachToolRetrieveMemories), plus 4 relative-time keys per Q8_DECISION (coachCitationRelativeJustNow, coachCitationRelativeMinutes, coachCitationRelativeHours, coachCitationRelativeDays — last 3 use Intl.plural for {count})"
    - "The 15 new keys exist in ALL 6 locales (fr/en/de/es/it/pt) — total 90 new entries (revised from 66 per Q8_DECISION in Plan 06)"
    - "FR copy is verbatim from RESEARCH §6.3 (banned-terms-clean + accent-clean) for the 11 frame/tool keys; the 4 relative-time FR strings are: « à l'instant », « il y a {count} min », « il y a {count} h », « il y a {count} j »"
    - "EN copy is from RESEARCH §6.3 for the 11 frame/tool keys; EN relative-time: « just now », « {count} min ago », « {count} h ago », « {count} d ago »"
    - "DE/IT/ES/PT translations are mechanical and acceptable for v1 (Plan 09 close-out runs validate_arb_parity to confirm 6-locale parity)"
    - "AppLocalizations regenerated via `flutter gen-l10n` so the new getters compile in Plan 05 + 06 widgets"
    - "Q6 DEVIATION block visible at top of plan: 90 entries (15 keys × 6 locales), NOT 30 as CONTEXT line 41 prescribed (RESEARCH §6.2 + Q8_DECISION from Plan 06 adds 4 relative-time keys)"
  artifacts:
    - path: "apps/mobile/lib/l10n/app_fr.arb"
      provides: "15 new keys with FR verbatim copy from RESEARCH §6.3 + Q8 relative-time strings"
      contains: "coachCitationChipsHeader|coachCitationChipLabel|coachCitationModalTitle|coachCitationJsonViewerLabel|coachCitationRememberCta|coachToolBudgetSnapshot|coachCitationRelativeJustNow|coachCitationRelativeMinutes|coachCitationRelativeHours|coachCitationRelativeDays"
    - path: "apps/mobile/lib/l10n/app_en.arb"
      provides: "15 new keys with EN translations"
      contains: "coachCitationChipsHeader|coachCitationRelativeJustNow"
    - path: "apps/mobile/lib/l10n/app_de.arb"
      provides: "15 new keys with DE translations"
      contains: "coachCitationChipsHeader|coachCitationRelativeJustNow"
    - path: "apps/mobile/lib/l10n/app_es.arb"
      provides: "15 new keys with ES translations"
      contains: "coachCitationChipsHeader|coachCitationRelativeJustNow"
    - path: "apps/mobile/lib/l10n/app_it.arb"
      provides: "15 new keys with IT translations"
      contains: "coachCitationChipsHeader|coachCitationRelativeJustNow"
    - path: "apps/mobile/lib/l10n/app_pt.arb"
      provides: "15 new keys with PT translations"
      contains: "coachCitationChipsHeader|coachCitationRelativeJustNow"
  key_links:
    - from: "apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart (Plan 05)"
      to: "apps/mobile/lib/l10n/app_fr.arb"
      via: "AppLocalizations.of(context)!.coachCitationChipsHeader etc."
      pattern: "coachCitationChipsHeader|coachCitationChipLabel|coachTool"
    - from: "apps/mobile/lib/widgets/coach/coach_citation_modal.dart (Plan 06)"
      to: "apps/mobile/lib/l10n/app_fr.arb"
      via: "AppLocalizations.of(context)!.coachCitationRelative* (Q8_DECISION)"
      pattern: "coachCitationRelativeJustNow|coachCitationRelativeMinutes|coachCitationRelativeHours|coachCitationRelativeDays"
---

# Q6_DECISION — 90 ARB entries (15 keys × 6 locales) per Q8 expansion (revised from 66)

**CONTEXT.md line 41 prescribes:** « ARB strings for 6 locales (fr/en/de/es/it/pt) for: chip label, modal title, JSON viewer label, flag-state badge, CTA. » — implying 5 keys × 6 locales = 30 entries.

**RESEARCH §6.2 finds:** 5 frame keys + 6 tool display-name keys (per CLAUDE.md TOP rule #5 strict i18n) = 11 keys × 6 locales = 66 entries.

**Q8_DECISION (Plan 06 revision iter-1) adds:** 4 relative-time keys (`coachCitationRelativeJustNow` + 3 plural-aware: minutes/hours/days). The modal's `_relativeTime` helper reads ARB keys — Dart literals would ship FR-only to 5 other locales (silent i18n leak that ARB-parity gate cannot detect).

**Total: 15 keys × 6 locales = 90 entries.**

**Plus, per Q7_DECISION (Plan 06)**: the flag_state badge is dropped, so we DO NOT add a `coachCitationFlagStateBadge` key. The 5 frame keys are: `coachCitationChipsHeader`, `coachCitationChipLabel(toolDisplayName)`, `coachCitationModalTitle(toolDisplayName)`, `coachCitationJsonViewerLabel`, `coachCitationRememberCta`. The 6 tool-name keys: `coachToolBudgetSnapshot`, `coachToolRetirementProjection`, `coachToolCrossPillarAnalysis`, `coachToolCoupleOptimization`, `coachToolCapStatus`, `coachToolRetrieveMemories`. The 4 relative-time keys (Q8): `coachCitationRelativeJustNow`, `coachCitationRelativeMinutes(count)`, `coachCitationRelativeHours(count)`, `coachCitationRelativeDays(count)`.

**Rationale for surfacing as deviation:**
1. CLAUDE.md TOP rule #5 is strict: every user-facing string MUST go through `AppLocalizations.of(context)!.<key>`.
2. The 6 tool display names ARE user-facing (chip label, modal title both interpolate them).
3. The 4 relative-time strings ARE user-facing (modal's computed_at row).
4. Hardcoding either set as Dart literals (the alternative) leaves a silent FR-only leak to en/de/es/it/pt — gate `validate_arb_parity` cannot detect Dart literal leakage.
5. ARB delta is small (current `app_fr.arb` is 12,206 lines per RESEARCH §6.2; 90 entries = +0.7%).

**Plan adopts the 90-entries path (revised from 66 per Q8).** If Julien rejects the Q8 expansion, alternative is to (a) keep only 11 keys × 6 = 66 entries in ARB and hardcode the 4 relative-time strings in Dart with explicit deviation note (CLAUDE.md TOP rule #5 exemption). Estimated cost saving: ~5 minutes of editor time + acceptance of FR-only leak risk.

---

<objective>
Add 15 new ARB keys across all 6 locale files (11 frame/tool keys + 4 relative-time keys per Q8_DECISION). FR copy is verbatim from RESEARCH §6.3 for the 11 frame/tool keys (banned-terms-clean, accent-clean). EN copy is also from §6.3. The 4 relative-time keys use simple FR phrasing: « à l'instant », « il y a {count} min », « il y a {count} h », « il y a {count} j ». DE / IT / ES / PT translations are mechanical (sense-preserving, target the same length budget as FR/EN).

Plans 05 + 06 consume these keys via `AppLocalizations.of(context)!.<key>` — those plans depend_on this plan.

After landing, run `flutter gen-l10n` so the generated `AppLocalizations` class exposes the new getters (including plural-aware methods for the 3 count-bearing relative-time keys) and Plans 05 + 06 widget code compiles.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@apps/mobile/lib/l10n/app_fr.arb
@apps/mobile/lib/l10n/app_en.arb

<interfaces>
ARB key naming precedent (app_fr.arb:3983-4000):
```json
"coachLoading": "Je regarde tes chiffres…",
"coachSources": "Sources",
"@coachSources": {
  "description": "..."
},
"coachInputHint": "Dis-moi.",
"@coachInputHint": {
  "description": "..."
},
```

Placeholder pattern with `{toolDisplayName}`:
```json
"coachCitationChipLabel": "{toolDisplayName} — calculé",
"@coachCitationChipLabel": {
  "description": "Label rendered on the citation chip; toolDisplayName is one of 6 server-side tool names.",
  "placeholders": {
    "toolDisplayName": {
      "type": "String"
    }
  }
},
```

Plural-aware placeholder pattern (used by the 3 count-bearing relative-time keys per Q8_DECISION). ARB uses ICU MessageFormat plural syntax:
```json
"coachCitationRelativeMinutes": "{count, plural, =1{il y a {count} min} other{il y a {count} min}}",
"@coachCitationRelativeMinutes": {
  "description": "Relative time string for the citation modal's computed_at row, minutes granularity. Q8_DECISION (Plan 06).",
  "placeholders": {
    "count": {
      "type": "int",
      "format": "compact"
    }
  }
},
```
Note: FR doesn't strictly pluralize "min", "h", "j" so the singular/other branches read identically — the ICU syntax is required for `flutter gen-l10n` to produce the `(int count)` method signature.

15 keys + FR/EN copy (11 from RESEARCH §6.3 + 4 from Q8_DECISION):

| Key | FR | EN |
|---|---|---|
| coachCitationChipsHeader | Calculs serveur | Server-side computations |
| coachCitationChipLabel | {toolDisplayName} — calculé | {toolDisplayName} — computed |
| coachCitationModalTitle | Source du calcul : {toolDisplayName} | Source of computation: {toolDisplayName} |
| coachCitationJsonViewerLabel | Voir le détail du calcul (JSON) | View computation detail (JSON) |
| coachCitationRememberCta | Souviens-toi de cette source | Remember this source |
| coachToolBudgetSnapshot | Budget actuel | Current budget |
| coachToolRetirementProjection | Projection de retraite | Retirement projection |
| coachToolCrossPillarAnalysis | Analyse inter-piliers | Cross-pillar analysis |
| coachToolCoupleOptimization | Optimisation couple | Couple optimization |
| coachToolCapStatus | Cap du jour | Daily cap |
| coachToolRetrieveMemories | Souvenirs | Memories |
| coachCitationRelativeJustNow | à l'instant | just now |
| coachCitationRelativeMinutes | il y a {count} min | {count} min ago |
| coachCitationRelativeHours | il y a {count} h | {count} h ago |
| coachCitationRelativeDays | il y a {count} j | {count} d ago |

DE / IT / ES / PT translations (proposed — sense-preserving):

| Key | DE | IT | ES | PT |
|---|---|---|---|---|
| coachCitationChipsHeader | Server-Berechnungen | Calcoli del server | Cálculos del servidor | Cálculos do servidor |
| coachCitationChipLabel | {toolDisplayName} — berechnet | {toolDisplayName} — calcolato | {toolDisplayName} — calculado | {toolDisplayName} — calculado |
| coachCitationModalTitle | Quelle der Berechnung: {toolDisplayName} | Origine del calcolo: {toolDisplayName} | Origen del cálculo: {toolDisplayName} | Origem do cálculo: {toolDisplayName} |
| coachCitationJsonViewerLabel | Berechnungsdetails anzeigen (JSON) | Mostra dettagli del calcolo (JSON) | Ver detalle del cálculo (JSON) | Ver detalhes do cálculo (JSON) |
| coachCitationRememberCta | Diese Quelle merken | Ricorda questa fonte | Recuerda esta fuente | Lembra desta fonte |
| coachToolBudgetSnapshot | Aktuelles Budget | Budget attuale | Presupuesto actual | Orçamento atual |
| coachToolRetirementProjection | Rentenprojektion | Proiezione pensionistica | Proyección de jubilación | Projeção de aposentadoria |
| coachToolCrossPillarAnalysis | Säulen-übergreifende Analyse | Analisi tra pilastri | Análisis entre pilares | Análise entre pilares |
| coachToolCoupleOptimization | Paar-Optimierung | Ottimizzazione di coppia | Optimización en pareja | Otimização do casal |
| coachToolCapStatus | Tageslimit | Limite giornaliero | Límite diario | Limite diário |
| coachToolRetrieveMemories | Erinnerungen | Ricordi | Recuerdos | Lembranças |
| coachCitationRelativeJustNow | gerade eben | proprio ora | justo ahora | agora mesmo |
| coachCitationRelativeMinutes | vor {count} Min. | {count} min fa | hace {count} min | há {count} min |
| coachCitationRelativeHours | vor {count} Std. | {count} h fa | hace {count} h | há {count} h |
| coachCitationRelativeDays | vor {count} T. | {count} g fa | hace {count} d | há {count} d |

Banned-terms verification on FR:
- "calculé", "côté", "détail", "Souviens-toi", "Souvenirs", "Cap du jour", "Optimisation", "Projection", "Analyse", "à l'instant", "il y a" — NONE on banned list (garanti / optimal / meilleur / certain / assuré / parfait / sans risque).
- "Optimisation" word is OK — banned list is "optimal" the adjective, "optimisation" the noun is acceptable per CLAUDE.md banned-terms spec.

Accent verification on FR:
- "Calculs", "calculé", "détail", "Source du calcul", "Voir le détail du calcul", "Souviens-toi", "Projection de retraite", "Analyse inter-piliers", "à l'instant" (the « à » uses U+00E0 NOT ASCII 'a') — all 100% FR.
- The apostrophe in « à l'instant » uses standard ASCII apostrophe `'` (U+0027). If `accent_lint_fr.py` flags the apostrophe form, fall back to typographic apostrophe `’` (U+2019). Both render identically in the UI; pick whichever passes the lint.

Validation tooling (Plan 09 will run these as G5 close-out):
- `python3 tools/checks/validate_arb_parity.py` — confirms all 15 keys exist in all 6 locales.
- `python3 tools/checks/banned_terms_arb.py` — confirms no LSFin banned-terms in FR/EN/DE/IT/ES/PT.
- `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` — confirms FR accents.

flutter gen-l10n regeneration command (per pubspec.yaml l10n config):
```bash
cd apps/mobile && flutter gen-l10n
```
Generated file is `apps/mobile/lib/l10n/app_localizations.dart` (or similar — confirm by reading pubspec.yaml `l10n:` block).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add 15 new ARB keys to app_fr.arb + app_en.arb (incl. 4 Q8 relative-time keys with plural placeholders)</name>
  <read_first>
    - apps/mobile/lib/l10n/app_fr.arb (FULL or at minimum lines 3980-4020 for naming convention precedent)
    - apps/mobile/lib/l10n/app_en.arb (parallel sample around the same line region)
    - apps/mobile/pubspec.yaml l10n: block (confirm generation config)
    - tools/checks/validate_arb_parity.py (CLI usage)
    - tools/checks/banned_terms_arb.py if exists, else fall back to validate_arb_parity
  </read_first>
  <files>
    - apps/mobile/lib/l10n/app_fr.arb (modify — add 15 keys)
    - apps/mobile/lib/l10n/app_en.arb (modify — add 15 keys)
  </files>
  <action>
    Step A — Open `apps/mobile/lib/l10n/app_fr.arb`. Locate a good insertion point near the existing `coachSources` block (line ~3984). Add the 15 new keys as a contiguous block (place AFTER the last existing `coach*` key for organization). Use this exact JSON block (insert before the trailing `}` of the root object):

    ```json
      "coachCitationChipsHeader": "Calculs serveur",
      "@coachCitationChipsHeader": {
        "description": "Header text for the Wave 1b citation-chip section under coach messages. Rendered above the list of tool-call chips."
      },
      "coachCitationChipLabel": "{toolDisplayName} — calculé",
      "@coachCitationChipLabel": {
        "description": "Label rendered on each citation chip. toolDisplayName interpolates a localized name (e.g. 'Budget actuel').",
        "placeholders": {
          "toolDisplayName": { "type": "String" }
        }
      },
      "coachCitationModalTitle": "Source du calcul : {toolDisplayName}",
      "@coachCitationModalTitle": {
        "description": "Title of the citation-chip modal (bottom sheet). Identifies which tool computed the values.",
        "placeholders": {
          "toolDisplayName": { "type": "String" }
        }
      },
      "coachCitationJsonViewerLabel": "Voir le détail du calcul (JSON)",
      "@coachCitationJsonViewerLabel": {
        "description": "Label on the ExpansionTile that wraps the pretty-printed JSON viewer in the citation modal."
      },
      "coachCitationRememberCta": "Souviens-toi de cette source",
      "@coachCitationRememberCta": {
        "description": "Call-to-action button at the bottom of the citation modal. Wires (in a future wave) to save_insight tool persistence."
      },
      "coachToolBudgetSnapshot": "Budget actuel",
      "@coachToolBudgetSnapshot": {
        "description": "Display name for the get_budget_status server-side tool."
      },
      "coachToolRetirementProjection": "Projection de retraite",
      "@coachToolRetirementProjection": {
        "description": "Display name for the get_retirement_projection server-side tool."
      },
      "coachToolCrossPillarAnalysis": "Analyse inter-piliers",
      "@coachToolCrossPillarAnalysis": {
        "description": "Display name for the get_cross_pillar_analysis server-side tool."
      },
      "coachToolCoupleOptimization": "Optimisation couple",
      "@coachToolCoupleOptimization": {
        "description": "Display name for the get_couple_optimization server-side tool."
      },
      "coachToolCapStatus": "Cap du jour",
      "@coachToolCapStatus": {
        "description": "Display name for the get_cap_status server-side tool (daily cap validation)."
      },
      "coachToolRetrieveMemories": "Souvenirs",
      "@coachToolRetrieveMemories": {
        "description": "Display name for the retrieve_memories BM25 server-side tool."
      },
      "coachCitationRelativeJustNow": "à l'instant",
      "@coachCitationRelativeJustNow": {
        "description": "Q8_DECISION — relative-time string for citation modal's computed_at row when delta < 1 minute. Replaces Dart literal 'à l\\'instant' in coach_citation_modal.dart."
      },
      "coachCitationRelativeMinutes": "{count, plural, =1{il y a {count} min} other{il y a {count} min}}",
      "@coachCitationRelativeMinutes": {
        "description": "Q8_DECISION — relative-time string for citation modal's computed_at row when delta < 1 hour. FR doesn't pluralize 'min'; ICU branches are identical.",
        "placeholders": {
          "count": { "type": "int", "format": "compact" }
        }
      },
      "coachCitationRelativeHours": "{count, plural, =1{il y a {count} h} other{il y a {count} h}}",
      "@coachCitationRelativeHours": {
        "description": "Q8_DECISION — relative-time string for citation modal's computed_at row when delta < 1 day.",
        "placeholders": {
          "count": { "type": "int", "format": "compact" }
        }
      },
      "coachCitationRelativeDays": "{count, plural, =1{il y a {count} j} other{il y a {count} j}}",
      "@coachCitationRelativeDays": {
        "description": "Q8_DECISION — relative-time string for citation modal's computed_at row when delta ≥ 1 day.",
        "placeholders": {
          "count": { "type": "int", "format": "compact" }
        }
      },
    ```

    Step B — Open `apps/mobile/lib/l10n/app_en.arb`. Add the same 15 keys at the parallel insertion point with EN values (no `@<key>` metadata needed in non-reference locales per ARB convention — only values):
    ```json
      "coachCitationChipsHeader": "Server-side computations",
      "coachCitationChipLabel": "{toolDisplayName} — computed",
      "coachCitationModalTitle": "Source of computation: {toolDisplayName}",
      "coachCitationJsonViewerLabel": "View computation detail (JSON)",
      "coachCitationRememberCta": "Remember this source",
      "coachToolBudgetSnapshot": "Current budget",
      "coachToolRetirementProjection": "Retirement projection",
      "coachToolCrossPillarAnalysis": "Cross-pillar analysis",
      "coachToolCoupleOptimization": "Couple optimization",
      "coachToolCapStatus": "Daily cap",
      "coachToolRetrieveMemories": "Memories",
      "coachCitationRelativeJustNow": "just now",
      "coachCitationRelativeMinutes": "{count, plural, =1{1 min ago} other{{count} min ago}}",
      "coachCitationRelativeHours": "{count, plural, =1{1 h ago} other{{count} h ago}}",
      "coachCitationRelativeDays": "{count, plural, =1{1 d ago} other{{count} d ago}}",
    ```
    Note: if the existing EN file uses `@<key>` blocks, mirror that convention.

    Step C — Run banned-terms + accent lints:
    ```bash
    python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
    # If banned_terms_arb.py exists:
    python3 tools/checks/banned_terms_arb.py 2>&1 || true
    ```
    Both MUST exit 0. If accent_lint_fr flags the ASCII apostrophe in « à l'instant », replace with typographic « à l’instant » (U+2019) and rerun.

    Step D — Verify the JSON files parse:
    ```bash
    python3 -c "import json; json.load(open('apps/mobile/lib/l10n/app_fr.arb'))"
    python3 -c "import json; json.load(open('apps/mobile/lib/l10n/app_en.arb'))"
    ```
    Both MUST exit 0.
  </action>
  <verify>
    <automated>python3 -c "import json; d = json.load(open('apps/mobile/lib/l10n/app_fr.arb')); assert all(k in d for k in ['coachCitationChipsHeader','coachToolBudgetSnapshot','coachToolRetrieveMemories','coachCitationRelativeJustNow','coachCitationRelativeMinutes','coachCitationRelativeHours','coachCitationRelativeDays']), 'missing keys'; print('OK')"</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "import json; json.load(open('apps/mobile/lib/l10n/app_fr.arb'))"` exits 0.
    - `python3 -c "import json; json.load(open('apps/mobile/lib/l10n/app_en.arb'))"` exits 0.
    - `grep -c "coachCitationChipsHeader\\|coachCitationChipLabel\\|coachCitationModalTitle\\|coachCitationJsonViewerLabel\\|coachCitationRememberCta" apps/mobile/lib/l10n/app_fr.arb` returns ≥5.
    - `grep -c "coachToolBudgetSnapshot\\|coachToolRetirementProjection\\|coachToolCrossPillarAnalysis\\|coachToolCoupleOptimization\\|coachToolCapStatus\\|coachToolRetrieveMemories" apps/mobile/lib/l10n/app_fr.arb` returns ≥6.
    - `grep -c "coachCitationRelativeJustNow\\|coachCitationRelativeMinutes\\|coachCitationRelativeHours\\|coachCitationRelativeDays" apps/mobile/lib/l10n/app_fr.arb` returns ≥4 (Q8_DECISION).
    - `grep -c "coachCitationChipsHeader\\|coachCitationRelativeJustNow" apps/mobile/lib/l10n/app_en.arb` returns ≥2.
    - `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` exits 0.
  </acceptance_criteria>
  <done>
    15 new keys in FR + EN (incl. 4 Q8 relative-time with ICU plural placeholders); JSON parses; accent lint exits 0.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add 15 keys to DE + IT + ES + PT + run flutter gen-l10n + validate parity</name>
  <read_first>
    - apps/mobile/lib/l10n/app_de.arb (skim 3980-4020 region — match convention)
    - apps/mobile/lib/l10n/app_it.arb (same)
    - apps/mobile/lib/l10n/app_es.arb (same)
    - apps/mobile/lib/l10n/app_pt.arb (same)
    - tools/checks/validate_arb_parity.py (CLI usage; verify it lives at this path or under tools/checks/arb_parity.py — pick whichever exists)
  </read_first>
  <files>
    - apps/mobile/lib/l10n/app_de.arb (modify — add 15 keys)
    - apps/mobile/lib/l10n/app_it.arb (modify — add 15 keys)
    - apps/mobile/lib/l10n/app_es.arb (modify — add 15 keys)
    - apps/mobile/lib/l10n/app_pt.arb (modify — add 15 keys)
  </files>
  <action>
    Step A — For each of the 4 remaining locale files, add the 15 keys with translations from the `<interfaces>` block.

    `apps/mobile/lib/l10n/app_de.arb` — insert at the parallel insertion point:
    ```json
      "coachCitationChipsHeader": "Server-Berechnungen",
      "coachCitationChipLabel": "{toolDisplayName} — berechnet",
      "coachCitationModalTitle": "Quelle der Berechnung: {toolDisplayName}",
      "coachCitationJsonViewerLabel": "Berechnungsdetails anzeigen (JSON)",
      "coachCitationRememberCta": "Diese Quelle merken",
      "coachToolBudgetSnapshot": "Aktuelles Budget",
      "coachToolRetirementProjection": "Rentenprojektion",
      "coachToolCrossPillarAnalysis": "Säulen-übergreifende Analyse",
      "coachToolCoupleOptimization": "Paar-Optimierung",
      "coachToolCapStatus": "Tageslimit",
      "coachToolRetrieveMemories": "Erinnerungen",
      "coachCitationRelativeJustNow": "gerade eben",
      "coachCitationRelativeMinutes": "{count, plural, =1{vor 1 Min.} other{vor {count} Min.}}",
      "coachCitationRelativeHours": "{count, plural, =1{vor 1 Std.} other{vor {count} Std.}}",
      "coachCitationRelativeDays": "{count, plural, =1{vor 1 T.} other{vor {count} T.}}",
    ```

    `apps/mobile/lib/l10n/app_it.arb`:
    ```json
      "coachCitationChipsHeader": "Calcoli del server",
      "coachCitationChipLabel": "{toolDisplayName} — calcolato",
      "coachCitationModalTitle": "Origine del calcolo: {toolDisplayName}",
      "coachCitationJsonViewerLabel": "Mostra dettagli del calcolo (JSON)",
      "coachCitationRememberCta": "Ricorda questa fonte",
      "coachToolBudgetSnapshot": "Budget attuale",
      "coachToolRetirementProjection": "Proiezione pensionistica",
      "coachToolCrossPillarAnalysis": "Analisi tra pilastri",
      "coachToolCoupleOptimization": "Ottimizzazione di coppia",
      "coachToolCapStatus": "Limite giornaliero",
      "coachToolRetrieveMemories": "Ricordi",
      "coachCitationRelativeJustNow": "proprio ora",
      "coachCitationRelativeMinutes": "{count, plural, =1{1 min fa} other{{count} min fa}}",
      "coachCitationRelativeHours": "{count, plural, =1{1 h fa} other{{count} h fa}}",
      "coachCitationRelativeDays": "{count, plural, =1{1 g fa} other{{count} g fa}}",
    ```

    `apps/mobile/lib/l10n/app_es.arb`:
    ```json
      "coachCitationChipsHeader": "Cálculos del servidor",
      "coachCitationChipLabel": "{toolDisplayName} — calculado",
      "coachCitationModalTitle": "Origen del cálculo: {toolDisplayName}",
      "coachCitationJsonViewerLabel": "Ver detalle del cálculo (JSON)",
      "coachCitationRememberCta": "Recuerda esta fuente",
      "coachToolBudgetSnapshot": "Presupuesto actual",
      "coachToolRetirementProjection": "Proyección de jubilación",
      "coachToolCrossPillarAnalysis": "Análisis entre pilares",
      "coachToolCoupleOptimization": "Optimización en pareja",
      "coachToolCapStatus": "Límite diario",
      "coachToolRetrieveMemories": "Recuerdos",
      "coachCitationRelativeJustNow": "justo ahora",
      "coachCitationRelativeMinutes": "{count, plural, =1{hace 1 min} other{hace {count} min}}",
      "coachCitationRelativeHours": "{count, plural, =1{hace 1 h} other{hace {count} h}}",
      "coachCitationRelativeDays": "{count, plural, =1{hace 1 d} other{hace {count} d}}",
    ```

    `apps/mobile/lib/l10n/app_pt.arb`:
    ```json
      "coachCitationChipsHeader": "Cálculos do servidor",
      "coachCitationChipLabel": "{toolDisplayName} — calculado",
      "coachCitationModalTitle": "Origem do cálculo: {toolDisplayName}",
      "coachCitationJsonViewerLabel": "Ver detalhes do cálculo (JSON)",
      "coachCitationRememberCta": "Lembra desta fonte",
      "coachToolBudgetSnapshot": "Orçamento atual",
      "coachToolRetirementProjection": "Projeção de aposentadoria",
      "coachToolCrossPillarAnalysis": "Análise entre pilares",
      "coachToolCoupleOptimization": "Otimização do casal",
      "coachToolCapStatus": "Limite diário",
      "coachToolRetrieveMemories": "Lembranças",
      "coachCitationRelativeJustNow": "agora mesmo",
      "coachCitationRelativeMinutes": "{count, plural, =1{há 1 min} other{há {count} min}}",
      "coachCitationRelativeHours": "{count, plural, =1{há 1 h} other{há {count} h}}",
      "coachCitationRelativeDays": "{count, plural, =1{há 1 d} other{há {count} d}}",
    ```

    Step B — Verify each file parses:
    ```bash
    for locale in de it es pt; do
      python3 -c "import json; json.load(open('apps/mobile/lib/l10n/app_${locale}.arb'))"
    done
    ```

    Step C — Run ARB parity gate. Try both possible script names:
    ```bash
    if [ -f tools/checks/validate_arb_parity.py ]; then
      python3 tools/checks/validate_arb_parity.py
    elif [ -f tools/checks/arb_parity.py ]; then
      python3 tools/checks/arb_parity.py
    fi
    ```
    MUST exit 0. Parity = all 15 keys present in all 6 locales (90 total entries).

    Step D — Regenerate AppLocalizations:
    ```bash
    cd apps/mobile && flutter gen-l10n
    ```
    Verify `apps/mobile/lib/l10n/app_localizations.dart` (or similar generated file path per pubspec.yaml `l10n:` block) contains the new getters (including the plural-aware methods for the 3 count-bearing relative-time keys):
    ```bash
    grep -c "coachCitationChipsHeader\|coachToolBudgetSnapshot\|coachCitationRelativeJustNow\|coachCitationRelativeMinutes" apps/mobile/lib/l10n/app_localizations.dart
    ```
    Should return ≥4.

    Step E — Run `cd apps/mobile && flutter analyze 2>&1 | tail -10`. MUST not show new errors (existing baseline of 273 issues per STATE.md is acceptable).
  </action>
  <verify>
    <automated>for locale in fr en de it es pt; do python3 -c "import json; d = json.load(open('apps/mobile/lib/l10n/app_${locale}.arb')); assert all(k in d for k in ['coachCitationChipsHeader','coachCitationChipLabel','coachCitationModalTitle','coachCitationJsonViewerLabel','coachCitationRememberCta','coachToolBudgetSnapshot','coachToolRetirementProjection','coachToolCrossPillarAnalysis','coachToolCoupleOptimization','coachToolCapStatus','coachToolRetrieveMemories','coachCitationRelativeJustNow','coachCitationRelativeMinutes','coachCitationRelativeHours','coachCitationRelativeDays']), f'${locale} missing keys'; print('${locale}: OK'); "; done</automated>
  </verify>
  <acceptance_criteria>
    - All 6 ARB files parse as valid JSON.
    - All 6 ARB files contain all 15 new keys (`grep -c` ≥15 per file for the union of new keys).
    - ARB parity script exits 0 (whichever name is present).
    - `apps/mobile/lib/l10n/app_localizations.dart` (or generated path) contains the 15 new getters (incl. plural-aware methods for the 3 count-bearing keys).
    - `cd apps/mobile && flutter analyze 2>&1 | grep -c "error - "` reports no new errors beyond baseline (273 issues per STATE.md).
  </acceptance_criteria>
  <done>
    15 new keys × 6 locales = 90 new entries; parity exit 0; flutter gen-l10n regenerated; Plans 05 + 06 widgets compile against all 15 getters (incl. relative-time plural-aware methods).
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-07-01 | I | FR copy contains LSFin banned terms ("garanti", "optimal") | mitigate | Verbatim text in `<interfaces>` was hand-verified in RESEARCH §6.4. Step C runs `accent_lint_fr.py`; Plan 09 wave_1b_close.sh runs `banned_terms_arb.py`. |
| T-WAVE1B-07-02 | I | FR copy has ASCII accents (e.g. "calcule" instead of "calculé") | mitigate | Step C runs `accent_lint_fr.py` which fails closed on every ASCII-accent violation. Fallback to typographic apostrophe documented if ASCII apostrophe in « à l'instant » fails the lint. |
| T-WAVE1B-07-03 | T | ARB parity gate fails because one locale is missing a key | mitigate | Step C runs `validate_arb_parity.py` (fail-closed); Step E flutter analyze catches missing-key runtime errors. |
| T-WAVE1B-07-04 | T | Q6_DECISION deviation: 90 entries instead of 30 (and revised from 66 per Q8) | mitigate | Q6_DECISION block at top of plan surfaces deviation. Alternative path (hardcode tool names in Dart map) documented. |
| T-WAVE1B-07-05 | T | flutter gen-l10n fails (pubspec.yaml l10n: misconfigured) | accept | If gen-l10n fails, ARB entries are still committed; Plan 05 + 06 use generated path which may or may not have been refreshed. Defer to Plan 09 close-out if needed. |
| T-WAVE1B-07-06 | I | DE / IT / ES / PT translations are wrong (e.g. wrong grammar) | accept | Translations are mechanical for v1 (Julien is FR-speaker per project_constraints; FR is the primary user audience). A native review can ship as a Wave 2 polish PR. |
| T-WAVE1B-07-07 | T | ICU plural syntax malformed and flutter gen-l10n produces wrong method signature | mitigate | The 3 count-bearing keys (Minutes/Hours/Days) use simplified ICU `{count, plural, =1{...} other{...}}` form. Plan 06 widget tests assert the methods are callable with `(int count)`. Acceptance criteria checks generated getters exist. |
</threat_model>

<verification>
- 6 ARB files parse as JSON.
- 15 new keys present in all 6 locales (90 entries total).
- ARB parity script exits 0.
- `flutter gen-l10n` exits 0.
- accent_lint_fr.py exits 0 on app_fr.arb.
- banned_terms_arb.py (if present) exits 0.
- flutter analyze produces no new errors.
- Q6_DECISION surfaced (revised to 90 entries per Q8).
</verification>

<success_criteria>
- 15 ARB keys × 6 locales = 90 new entries.
- FR copy is banned-terms-clean + accent-clean.
- ARB parity gate exit 0.
- AppLocalizations regenerated; Plan 05 + 06 widgets compile (incl. plural-aware relative-time methods).
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md` with:
- 90 entry count delta confirmed (revised from 66 per Q8_DECISION)
- Q6_DECISION outcome (15 keys instead of 5 — full doctrine i18n)
- 0-trust self-check citing `validate_arb_parity.py` exit code + flutter gen-l10n output
</output>
</content>
</invoke>
