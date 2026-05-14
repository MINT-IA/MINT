---
phase: wave-1a
plan: 06
type: execute
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_cap_garde.py
autonomous: true
requirements: [WAVE1A-04]
must_haves:
  truths:
    - "Cap response text passes through _validate_cap_response middleware which rejects CHF tokens without {{cite:<key>}} within ±80 char window"
    - "Rejected CHF tokens are replaced with [montant indisponible] verbatim FR string"
    - "Sentry breadcrumb coach.cap.cap_chf_uncited fires for every rejected token, payload non-PII (snippet first 120 chars only, no profile_id, no user_id)"
    - "Garde flag COACH_CAP_CHF_GARDE_ENABLED defaults ON (independent of per-tool server-side flags — this is the cap_status mitigation per D-09)"
    - "When garde flag OFF, _format_cap_status output is byte-identical to current (no middleware applied)"
    - "Garde regex _RE_CURRENCY is REUSED from app.services.coach.citation_parser — no new regex"
  artifacts:
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_validate_cap_response(rendered: str) -> str middleware + flag-gated dispatcher wrap on get_cap_status"
      contains: "_validate_cap_response"
    # NOTE: COACH_CAP_CHF_GARDE_ENABLED flag is added to config.py by plan-00
    # (Wave 0 scaffolding — single source of truth for all Wave 1a flags).
    # Plan-06 only READS the flag via settings.COACH_CAP_CHF_GARDE_ENABLED.
    - path: "services/backend/tests/test_cap_garde.py"
      provides: "≥5 unit tests covering cite-present / cite-absent / boundary 80-char window / no-CHF passthrough / flag OFF passthrough"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/coach/citation_parser.py"
      via: "import _RE_CURRENCY for CHF detection (reuse Phase 94 regex)"
      pattern: "from app.services.coach.citation_parser import _RE_CURRENCY"
---

<objective>
Implement the `get_cap_status` CHF garde middleware per CONTEXT D-09 + D-17 (option b — keep CapEngine Flutter-source, add runtime garde). The garde rejects any `cap_expected_impact` or other cap-text CHF token that lacks an adjacent `{{cite:<key>}}` within ±80 chars and replaces it with `[montant indisponible]`. This is the smallest mitigation that closes the « CapEngine emits an un-cited CHF claim that the coach narrates » class of hallucination without porting CapEngine to Python.

This plan does NOT refactor `get_cap_status` to a server-side recompute (deferred per D-17 with a re-litigation trigger: > 5/day Sentry breadcrumbs for ≥1 week). It adds an OUTPUT-FILTER middleware on the existing `_format_cap_status(ctx)` path.

Purpose: structural mitigation for the only Wave 1a tool that stays Flutter-sourced — no CHF can leak through cap text without a citation.
Output: middleware function + flag (default ON) + ≥5 unit tests.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/services/coach/citation_parser.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

Existing _RE_CURRENCY regex (REUSE, do not duplicate):
File services/backend/app/services/coach/citation_parser.py lines 65-70:
```python
_RE_CURRENCY = re.compile(
    r"\b(?:\d{1,3}(?:['  ]\d{3})+|\d+)(?:[.,]\d{1,2})?\s*(?:CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b"
)
```

Existing _RE_CITE_PLACEHOLDER (REUSE for adjacency check):
File services/backend/app/services/coach/citation_parser.py line 98:
```python
_RE_CITE_PLACEHOLDER = re.compile(r"\{\{cite:[A-Za-z0-9_\-]+\}\}")
```

Legacy formatter (preserve unchanged):
File services/backend/app/api/v1/endpoints/coach_chat.py lines 2330-2358: `_format_cap_status(ctx)` produces text like:
```
Cap du jour :
- Priorité : ...
- Pourquoi maintenant : ...
- Action suggérée : ...
- Impact attendu : ... (may contain CHF)
- Objectif actif : ...
- Progression : X/Y étapes
```

The garde wraps the OUTPUT of `_format_cap_status` (not the input ctx), since the cap text already comes pre-rendered from CapEngine on the Flutter side.

Existing dispatcher branch (REPLACE):
File services/backend/app/api/v1/endpoints/coach_chat.py line 1921-1922:
```python
if name == "get_cap_status":
    return _format_cap_status(ctx)
```
Replace with garde wrapper:
```python
if name == "get_cap_status":
    rendered = _format_cap_status(ctx)
    return _validate_cap_response(rendered)
```

Settings flag (default ON, unique among Wave 1a — see D-09):
```python
COACH_CAP_CHF_GARDE_ENABLED: bool = True
```

Sentry breadcrumb (reuse pattern from turn_cap.py):
```python
sentry_sdk.add_breadcrumb(
    category="coach.cap.cap_chf_uncited",
    message="CHF token rejected",
    level="warning",
    data={"snippet": window[:120]},  # 120-char window, no PII
)
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add _validate_cap_response middleware + flag + dispatcher wrap + ≥5 tests</name>
  <read_first>
    - services/backend/app/services/coach/citation_parser.py lines 60-100 (regex patterns to reuse)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1900-1930 (dispatcher entry)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2330-2358 (legacy _format_cap_status)
    - services/backend/app/services/coach/turn_cap.py lines 95-120 (Sentry breadcrumb pattern)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify)
    - services/backend/app/core/config.py (modify — add flag default True)
    - services/backend/tests/test_cap_garde.py (create)
  </files>
  <behavior>
    - Test 1: CITE PRESENT — input `"Impact attendu : économise 1'250 CHF par an {{cite:r3a_plafond_2026}}"` → output unchanged (cite within 80 chars of "1'250 CHF").
    - Test 2: CITE ABSENT — input `"Impact attendu : économise 1'250 CHF par an"` → output `"Impact attendu : économise [montant indisponible] par an"` + Sentry breadcrumb fires once with category `coach.cap.cap_chf_uncited`.
    - Test 3: BOUNDARY 80 CHARS — input where `{{cite:<key>}}` is at exactly ±80 chars from CHF token → cite considered adjacent (cite accepted); at ±81 chars → cite NOT adjacent (rejected). Two sub-tests.
    - Test 4: NO CHF — input `"Cap du jour :\n- Priorité : Optimise ton budget"` (no CHF anywhere) → output unchanged, NO breadcrumb fires.
    - Test 5: FLAG OFF — `settings.COACH_CAP_CHF_GARDE_ENABLED = False` → input with un-cited CHF → output unchanged (no replacement, no breadcrumb).
    - Test 6: MULTIPLE CHF TOKENS — input with 2 un-cited CHF tokens → both replaced; breadcrumb fires twice. Plus 1 cited CHF token → only 2 replaced, cited one preserved.
  </behavior>
  <action>
    Step A — Flag verification (plan-00 already added `COACH_CAP_CHF_GARDE_ENABLED: bool = True` to `settings.py`). This plan only READS the flag via `from app.core.config import settings`. If the flag is missing (plan-00 not landed), fail loudly — do not silently fall back.

    Verify before proceeding:
    ```bash
    grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py
    # Expected: 1 (added by plan-00)
    ```

    Step B — `services/backend/app/api/v1/endpoints/coach_chat.py` add `_validate_cap_response` middleware ABOVE `_format_cap_status` (line ~2330):

    ```python
    def _validate_cap_response(rendered: str) -> str:
        """Wave 1a D-09 — strip un-cited CHF tokens from cap text.

        Cap text comes from CapEngine on the Flutter side. Server cannot
        recompute the cap (kept Flutter-source per D-17 option b), but we
        CAN guarantee that no CHF token reaches the LLM without an adjacent
        {{cite:<key>}} placeholder. Within ±80 chars of any CHF token, a
        cite placeholder MUST be present; else replace the token with
        verbatim FR « [montant indisponible] » and emit Sentry breadcrumb.

        Default flag ON (CONTEXT D-09); set OFF only for legacy parity
        debugging.
        """
        from app.core.config import settings
        if not settings.COACH_CAP_CHF_GARDE_ENABLED:
            return rendered
        from app.services.coach.citation_parser import _RE_CURRENCY
        result = rendered
        offset = 0
        for match in _RE_CURRENCY.finditer(rendered):
            window_start = max(0, match.start() - 80)
            window_end = match.end() + 80
            window = rendered[window_start:window_end]
            if "{{cite:" in window:
                continue
            # Replace this match in `result` (adjust offset for prior swaps).
            s = match.start() + offset
            e = match.end() + offset
            replacement = "[montant indisponible]"
            result = result[:s] + replacement + result[e:]
            offset += len(replacement) - (e - s)
            try:
                import sentry_sdk
                sentry_sdk.add_breadcrumb(
                    category="coach.cap.cap_chf_uncited",
                    message="CHF token rejected",
                    level="warning",
                    data={"snippet": window[:120]},
                )
            except Exception:
                pass
        return result
    ```

    Step C — Replace dispatcher branch at line ~1921:
    ```python
        if name == "get_cap_status":
            return _validate_cap_response(_format_cap_status(ctx))
    ```

    Step D — Create `services/backend/tests/test_cap_garde.py` with Tests 1-6. Mock `sentry_sdk.add_breadcrumb` and assert call count + category for Tests 2/3/6. For Test 5, use `monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", False)`.

    Step E — VERBATIM FR string check: « [montant indisponible] » MUST be byte-identical (lowercase « m », single space). `accent_lint_fr.py` validates.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_cap_garde.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_validate_cap_response" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (def + dispatcher call + helper references).
    - `grep -c "COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/core/config.py services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥2.
    - `grep -c "from app.services.coach.citation_parser import _RE_CURRENCY" services/backend/app/api/v1/endpoints/coach_chat.py` returns 1 (regex REUSED, not duplicated).
    - `grep -c "\\[montant indisponible\\]" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "coach.cap.cap_chf_uncited" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_cap_garde.py -q` exits 0 with ≥5 tests collected (target ≥6 per behavior).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - Default value: `grep "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py` returns 1 (default ON per plan-00 single source of truth, NOT False).
  </acceptance_criteria>
  <done>
    Middleware + flag (default ON) wired into dispatcher; ≥5 unit tests green; regex reused not duplicated; Sentry breadcrumb non-PII.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-06-01 | T | Legacy `_format_cap_status` regression when garde flag OFF | mitigate | Test 5 asserts byte-identity passthrough when flag OFF. |
| T-WAVE1A-06-02 | I | LSFin banned-terms leak in garde replacement string | mitigate | « [montant indisponible] » verbatim FR — passed through `banned_terms_python.py` and `accent_lint_fr.py` in verify. |
| T-WAVE1A-06-03 | I | PII leak in Sentry breadcrumb `snippet` payload | mitigate | `snippet` is the 120-char window around the rejected CHF token — by design contains the offending text but no user_id, no profile_id, no email. Test 2 inspects payload structure. Sentry retention on the staging project is ≤90 days. |
| T-WAVE1A-06-04 | T | Regex drift between citation_parser and cap garde | mitigate | Acceptance criterion #3 grep proves `_RE_CURRENCY` is IMPORTED from `citation_parser`, never redeclared. Single source of truth. |
| T-WAVE1A-06-05 | D (Denial of service) | adversarial input with 1000 CHF tokens → 1000 breadcrumbs | accept | Sentry SDK self-rate-limits ; ≤1 garde invocation per coach turn ; typical cap text ≤400 chars (≤2-3 CHF tokens max). Low risk. |
</threat_model>

<verification>
- `pytest tests/test_cap_garde.py -q` exits 0 with ≥5 tests.
- `pytest services/backend/ -q` full suite — zero regressions.
- `banned_terms_python.py` + `accent_lint_fr.py` green.
- Garde flag default ON (asserted by grep).
- Regex reuse asserted (no duplicate _RE_CURRENCY).
</verification>

<success_criteria>
- WAVE1A-04 satisfied: `get_cap_status` stays Flutter-sourced AND gains runtime CHF garde; un-cited CHF tokens are replaced with `[montant indisponible]`; Sentry breadcrumb fires for measurement.
- ≥5 new backend tests, lints green, no LSFin regression, regex single-sourced.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-06-SUMMARY.md` with files, tests, lints, regex-reuse proof, 0-trust self-check.
</output>
