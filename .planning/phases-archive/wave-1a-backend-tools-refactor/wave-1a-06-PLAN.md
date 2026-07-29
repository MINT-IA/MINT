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
    - "Cap response text from _format_cap_status(ctx) passes through _validate_cap_response middleware which rejects CHF tokens lacking {{cite:<key>}} within ±80 char window"
    - "Rejected CHF tokens are replaced with [montant indisponible] verbatim FR string (proper FR accents)"
    - "Sentry breadcrumb category coach.cap.cap_chf_uncited fires for every rejected token; payload is non-PII (snippet ≤120 chars; no profile_id, no user_id, no LSFin claim)"
    - "Garde flag COACH_CAP_CHF_GARDE_ENABLED is READ from plan-00 (default True per D-09) — plan-06 only reads, does NOT redeclare"
    - "When COACH_CAP_CHF_GARDE_ENABLED is False, _validate_cap_response returns input rendered byte-identical (no middleware applied, no breadcrumb)"
    - "Garde regex _RE_CURRENCY is REUSED from app.services.coach.citation_parser — no new regex definition (single source of truth at citation_parser.py:68-70)"
  artifacts:
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_validate_cap_response(rendered: str) -> str middleware (inserted ABOVE _format_cap_status at ~line 2543) + flag-gated dispatcher wrap on get_cap_status inside markers at lines 1933-1936"
      contains: "_validate_cap_response"
    - path: "services/backend/tests/test_cap_garde.py"
      provides: "≥5 unit tests covering cite-present passthrough / cite-absent rejection / boundary 80-char window / no-CHF passthrough / flag OFF passthrough / multi-token mixed"
      contains: "def test_"
  key_links:
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/coach/citation_parser.py"
      via: "from app.services.coach.citation_parser import _RE_CURRENCY (Phase 94 regex, re-exported per citation_parser.py:727)"
      pattern: "from app.services.coach.citation_parser import _RE_CURRENCY"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/core/config.py"
      via: "settings.COACH_CAP_CHF_GARDE_ENABLED flag read"
      pattern: "COACH_CAP_CHF_GARDE_ENABLED"
---

<objective>
Implement the `get_cap_status` CHF garde middleware per CONTEXT D-09 + D-17 (option b — keep CapEngine Flutter-source, add runtime garde). The garde rejects any cap-text CHF token that lacks an adjacent `{{cite:<key>}}` within ±80 chars and replaces it with the verbatim FR string `[montant indisponible]`. This is the smallest mitigation that closes the « CapEngine emits an un-cited CHF claim that the coach narrates » class of hallucination without porting CapEngine to Python.

This plan does NOT refactor `get_cap_status` to a server-side recompute (deferred per D-17 with re-litigation trigger: > 5/day Sentry breadcrumbs for ≥1 week). It adds an OUTPUT-FILTER middleware on the existing `_format_cap_status(ctx)` path.

**Grep-verified 2026-05-14:**
- `_RE_CURRENCY` is defined in `services/backend/app/services/coach/citation_parser.py:68-70` (verified) AND publicly re-exported via `__all__` at `citation_parser.py:727` (verified). Plan-06 imports it as a module-level top-of-file import — convention-private prefix `_` is allowed because `_RE_CURRENCY` IS publicly re-exported (the citation_parser source comment at lines 726-727 says « Compiled regex (private but re-used by tests) »).
- `_format_cap_status(ctx)` is defined at `coach_chat.py:2543-2571` (verified — emits text lines including « - Impact attendu : {cap_impact} » at line 2565).
- The dispatcher marker pair for `get_cap_status` lives at `coach_chat.py:1933-1936` (verified):
  ```python
  # >>> dispatch: get_cap_status
  if name == "get_cap_status":
      return _format_cap_status(ctx)
  # <<< dispatch: get_cap_status
  ```
- `COACH_CAP_CHF_GARDE_ENABLED: bool = True` is at `config.py:102` (verified — plan-00 shipped it as DEFAULT TRUE, unique among Wave 1a flags per D-09).

Purpose: structural mitigation for the only Wave 1a tool that stays Flutter-sourced — no CHF can leak through cap text without a citation.
Output: middleware function + dispatcher wrap (inside markers) + ≥5 unit tests. Plan-06 does NOT touch `config.py` (flag is plan-00 single source of truth).
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
<!-- Contracts the executor MUST follow. Every symbol below was grep-verified 2026-05-14. -->

== _RE_CURRENCY regex (REUSE, do NOT duplicate) ==

File `services/backend/app/services/coach/citation_parser.py` lines 65-70:
```python
# 1. CHF / EUR / USD / fr. amounts. Apostrophe + non-breaking space + regular
#    space tolerated as group separator. Decimals via `,` or `.`. Unit MUST
#    follow the digits (D-02 spec — `CHF 80000` is out of scope).
_RE_CURRENCY = re.compile(
    r"\b(?:\d{1,3}(?:['  ]\d{3})+|\d+)(?:[.,]\d{1,2})?\s*(?:CHF|chf|EUR|eur|USD|usd|fr\.?|francs?)\b"
)
```

The regex is re-exported via `__all__` at `citation_parser.py:721-734`:
```python
__all__ = [
    ...
    # Compiled regex (private but re-used by tests)
    "_RE_CURRENCY",
    "_RE_PERCENT",
    ...
]
```
The underscore prefix is a Python convention for « internal »; the explicit `__all__` re-export makes it part of the module's PUBLIC API for inter-module reuse. Plan-06 imports it via `from app.services.coach.citation_parser import _RE_CURRENCY` (idiomatic for re-exported underscore-prefixed names).

== _RE_CITE_PLACEHOLDER regex (REUSE for adjacency check) ==

File `services/backend/app/services/coach/citation_parser.py` line 98:
```python
# 6. Citation placeholder body — `{{cite:r3a_plafond_2026}}`. Used by the
#    gate to STRIP the placeholder span before number detection (D-04#4) so
#    digits inside the key don't false-trigger the regex above.
_RE_CITE_PLACEHOLDER = re.compile(r"\{\{cite:[A-Za-z0-9_\-]+\}\}")
```
Also re-exported via `__all__` at `citation_parser.py:732`.

For the adjacency check, the simpler substring `"{{cite:" in window` is sufficient (the cite placeholder always starts with that literal) and avoids importing a second compiled regex. The plan adopts the substring check for clarity. Importing `_RE_CITE_PLACEHOLDER` is reserved for stricter adjacency checks added in a future plan if needed.

== Legacy formatter (PRESERVED, unchanged) ==

File `services/backend/app/api/v1/endpoints/coach_chat.py` lines 2543-2571:
```python
def _format_cap_status(ctx: dict) -> str:
    """Format current Cap (priority action) as readable text."""
    # Cap data comes from CapEngine on the Flutter side.
    # These fields are injected into profile_context by Flutter.
    cap_headline = ctx.get("cap_headline")
    cap_why_now = ctx.get("cap_why_now")
    cap_cta = ctx.get("cap_cta")
    cap_impact = ctx.get("cap_expected_impact")
    seq_completed = ctx.get("sequence_completed")
    seq_total = ctx.get("sequence_total")
    active_goal = ctx.get("active_goal")

    if cap_headline is None:
        return "Aucun Cap du jour calculé. Le profil manque peut-être de données."

    lines = ["Cap du jour :"]
    lines.append(f"- Priorité : {cap_headline}")
    if cap_why_now:
        lines.append(f"- Pourquoi maintenant : {cap_why_now}")
    if cap_cta:
        lines.append(f"- Action suggérée : {cap_cta}")
    if cap_impact:
        lines.append(f"- Impact attendu : {cap_impact}")
    if active_goal:
        lines.append(f"- Objectif actif : {active_goal}")
    if seq_completed is not None and seq_total is not None:
        lines.append(f"- Progression : {seq_completed}/{seq_total} étapes")

    return "\n".join(lines)
```

The cap text already comes pre-rendered from CapEngine on the Flutter side (Flutter writes `cap_headline`, `cap_expected_impact`, etc. into `profile_context` which the backend reads as `ctx`). The garde wraps the OUTPUT of `_format_cap_status` (the FINAL rendered string), not the input ctx fields — this is the simplest interception point that catches CHF tokens anywhere in any cap field (headline / why_now / cta / impact / active_goal).

== Existing dispatcher (REPLACE inside markers shipped by plan-00) ==

File `services/backend/app/api/v1/endpoints/coach_chat.py` lines 1933-1936 (verified 2026-05-14):
```python
    # >>> dispatch: get_cap_status
    if name == "get_cap_status":
        return _format_cap_status(ctx)
    # <<< dispatch: get_cap_status
```

Replace WITH (markers preserved, garde wrap added):
```python
    # >>> dispatch: get_cap_status
    if name == "get_cap_status":
        return _validate_cap_response(_format_cap_status(ctx))
    # <<< dispatch: get_cap_status
```

== Pre-existing scaffolding (DO NOT redeclare) ==

Confirmed 2026-05-14:
- `services/backend/app/core/config.py:102` — `COACH_CAP_CHF_GARDE_ENABLED: bool = True` (DEFAULT ON, unique among Wave 1a flags per D-09). Plan-06 only READS this — does NOT redeclare. The plan-00 single-source-of-truth invariant: plan-06's `files_modified` list does NOT include `config.py`.
- The plan-00 dispatcher marker pair `# >>> dispatch: get_cap_status` / `# <<< dispatch: get_cap_status` exists at lines 1933-1936.

== Sentry breadcrumb pattern (REUSE pattern from turn_cap.py) ==

File `services/backend/app/services/coach/turn_cap.py` lines 100-118 (verified region) shows the fail-open pattern. Plan-06 follows the same pattern but with a DIFFERENT category (`coach.cap.cap_chf_uncited` per D-09) — this is NOT a coach tool invocation (it's a cap-text middleware), so it does NOT use the plan-00 `emit_coach_tool_breadcrumb` helper (which is reserved for the 5 server-side tool paths and has a different category prefix `coach.tool.<name>`). Plan-06 emits its own breadcrumb directly:
```python
try:
    import sentry_sdk
    sentry_sdk.add_breadcrumb(
        category="coach.cap.cap_chf_uncited",
        message="CHF token rejected",
        level="warning",
        data={"snippet": window[:120]},  # 120-char window — no PII (no user_id, no profile_id)
    )
except Exception:
    pass  # fail-open: never let telemetry break the coach response path
```

== Verbatim FR replacement string ==

`[montant indisponible]` — lowercase « m », single space, plural « -ble » suffix. Verified plain ASCII (no accents) so `accent_lint_fr.py` passes regardless of import context. The string must be byte-identical wherever it appears in tests and the source — Test 5 (multi-token) asserts substring match exactly.

</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add _validate_cap_response middleware + dispatcher wrap (markers preserved) + ≥6 tests</name>
  <read_first>
    - services/backend/app/services/coach/citation_parser.py lines 60-100 (regex patterns to reuse; verify __all__ at line 715-734 re-exports _RE_CURRENCY)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1933-1936 (dispatcher marker pair from plan-00)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2543-2571 (legacy _format_cap_status — preserved unchanged)
    - services/backend/app/services/coach/turn_cap.py lines 100-120 (Sentry breadcrumb fail-open pattern reference)
    - services/backend/app/core/config.py lines 95-110 (verify COACH_CAP_CHF_GARDE_ENABLED present with default True per plan-00)
    - services/backend/tests/conftest.py (pytest fixture pattern; this plan has NO DB tests — middleware is pure string in / string out)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify — insert _validate_cap_response above _format_cap_status at ~line 2543; replace dispatcher branch body inside markers at 1933-1936)
    - services/backend/tests/test_cap_garde.py (create)
  </files>
  <behavior>
    - Test 1 (CITE PRESENT WITHIN 80 CHARS): input `"Impact attendu : économise 1'250 CHF par an {{cite:r3a_plafond_2026}}"` → output unchanged (cite placeholder lies within 80 chars of the CHF token), no breadcrumb fires (mock asserts called 0 times).
    - Test 2 (CITE ABSENT): input `"Impact attendu : économise 1'250 CHF par an"` → CHF token `"1'250 CHF"` replaced with `"[montant indisponible]"`. Output is `"Impact attendu : économise [montant indisponible] par an"`. Sentry breadcrumb fires exactly once with `category="coach.cap.cap_chf_uncited"`. The breadcrumb's `data["snippet"]` is a string of length ≤120 chars.
    - Test 3 (BOUNDARY ≤80 CHARS): input where the `{{cite:r3a_plafond_2026}}` literal opening `{{cite:` starts at exactly 80 chars AFTER the END of the CHF token (the window is `±80` chars from match.start/.end). Two sub-assertions:
      - 3a: cite at exactly 80 chars from match.end → adjacency window catches it (rendered unchanged, no breadcrumb).
      - 3b: cite at 81 chars from match.end → adjacency window misses it (rendered modified, breadcrumb fires once).
      Implementation: build the input string with `" " * N` padding to position the cite precisely; assert outcome.
    - Test 4 (NO CHF TOKENS): input `"Cap du jour :\n- Priorité : Optimise ton budget\n- Action suggérée : Lis ce module"` → output unchanged (no token matches `_RE_CURRENCY`), no breadcrumb.
    - Test 5 (FLAG OFF passthrough): `monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", False)`. Input with un-cited CHF → output byte-identical to input (no replacement, no breadcrumb fires).
    - Test 6 (MULTIPLE CHF TOKENS, MIXED CITE STATE): input contains 3 CHF tokens — 2 un-cited, 1 cited (cite placeholder within 80 chars of token #3 only). Output has tokens #1 and #2 replaced with `[montant indisponible]`; token #3 preserved. Breadcrumb fires exactly 2 times.
    - **Total: 6 tests (≥6, target ≥5 satisfied).**
  </behavior>
  <action>
    Step A — Flag verification (READ-ONLY — plan-00 owns the flag):
    ```bash
    grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py
    # Expected: 1 (plan-00 shipped it DEFAULT TRUE per D-09)
    ```
    If 0, FAIL LOUDLY — plan-00 has not landed; do NOT redeclare here.

    Step B — In `services/backend/app/api/v1/endpoints/coach_chat.py`, INSERT `_validate_cap_response` ABOVE `_format_cap_status` (at the blank line preceding line 2543). Body:
    ```python
    def _validate_cap_response(rendered: str) -> str:
        """Wave 1a D-09 — strip un-cited CHF tokens from cap text.

        Cap text comes from CapEngine on the Flutter side. Server cannot
        recompute the cap (kept Flutter-source per D-17 option b), but we
        CAN guarantee that no CHF token reaches the LLM without an adjacent
        {{cite:<key>}} placeholder. Within ±80 chars of any CHF token, a
        cite placeholder MUST be present; else replace the token with
        verbatim FR « [montant indisponible] » and emit Sentry breadcrumb
        with non-PII snippet payload.

        Default flag ON per CONTEXT D-09 (set OFF only for legacy parity
        debugging — Test 5 covers the OFF path).

        Regex reused: app.services.coach.citation_parser._RE_CURRENCY
        (Phase 94 — single source of truth, re-exported via __all__ at
        citation_parser.py:721-734).
        """
        from app.core.config import settings
        if not settings.COACH_CAP_CHF_GARDE_ENABLED:
            return rendered
        # Inline import to avoid module-import-time circular dep (citation_parser
        # imports config, this module imports citation_parser).
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
                # Fail-open: never let telemetry break the coach response path.
                pass
        return result
    ```

    Step C — Replace dispatcher branch body INSIDE the marker pair shipped by plan-00 (lines 1933-1936, verified 2026-05-14). Locate the EXACT 4-line block:
    ```python
        # >>> dispatch: get_cap_status
        if name == "get_cap_status":
            return _format_cap_status(ctx)
        # <<< dispatch: get_cap_status
    ```
    Replace WITH (markers preserved verbatim — do NOT modify the marker comment lines):
    ```python
        # >>> dispatch: get_cap_status
        if name == "get_cap_status":
            return _validate_cap_response(_format_cap_status(ctx))
        # <<< dispatch: get_cap_status
    ```
    Acceptance after edit: `grep -c "# >>> dispatch: get_cap_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 AND `grep -c "# <<< dispatch: get_cap_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.

    Step D — Create `services/backend/tests/test_cap_garde.py` with Tests 1-6 from `<behavior>`. Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.sentry_sdk.add_breadcrumb")` for the breadcrumb assertion. Alternatively use the more local `unittest.mock.patch` on the `sentry_sdk` module-level `add_breadcrumb`. Mock pattern reference: matches the shipped scaffolding test 12 in `test_coach_tools_scaffolding.py` (plan-00) which mocks sentry_sdk for fail-open testing.

    Test 5 (FLAG OFF): use `monkeypatch.setattr(settings, "COACH_CAP_CHF_GARDE_ENABLED", False)`.

    Test 3 (boundary): construct strings with `f"...{ ' ' * N}{{{{cite:k}}}}..."` where N is computed precisely. Use `_RE_CURRENCY` from `app.services.coach.citation_parser` directly in the test setup to verify `match.start()` / `match.end()` positions on the constructed string (proves the boundary math is correct, not just hoping).

    Step E — VERBATIM FR string check: `[montant indisponible]` MUST be byte-identical (lowercase « m », single space, no accents — pure ASCII). `accent_lint_fr.py` validates the file as a whole — the replacement string has no accents to lint, but the cap docstring and FR descriptions are checked.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_cap_garde.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def _validate_cap_response" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `grep -c "_validate_cap_response" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (def + dispatcher call + at minimum one docstring/comment self-reference).
    - `grep -c "COACH_CAP_CHF_GARDE_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (read inside _validate_cap_response).
    - `grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" services/backend/app/core/config.py` returns exactly 1 (plan-00 invariant — plan-06 does NOT modify config.py).
    - `grep -c "from app.services.coach.citation_parser import _RE_CURRENCY" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (regex REUSED, not duplicated).
    - `grep -c "re\.compile(.*CHF.*EUR\|_RE_CURRENCY\s*=\s*re\.compile" services/backend/app/api/v1/endpoints/coach_chat.py` returns 0 (anti-fabrication grep — proves the regex is NOT redeclared in this file).
    - `grep -F "[montant indisponible]" services/backend/app/api/v1/endpoints/coach_chat.py | wc -l` returns ≥1 (verbatim FR replacement string present).
    - `grep -c "coach.cap.cap_chf_uncited" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (breadcrumb category).
    - `grep -c "# >>> dispatch: get_cap_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 (marker preserved).
    - `grep -c "# <<< dispatch: get_cap_status" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `grep -F "return _validate_cap_response(_format_cap_status(ctx))" services/backend/app/api/v1/endpoints/coach_chat.py | wc -l` returns 1 (dispatcher correctly chains middleware over legacy formatter).
    - `pytest services/backend/tests/test_cap_garde.py -q` exits 0 with ≥5 tests collected (plan ships 6).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
  </acceptance_criteria>
  <done>
    Middleware + dispatcher wrap inside markers (markers preserved exactly); ≥6 unit tests green; regex REUSED not duplicated (anti-fabrication grep proof); flag default ON preserved (plan-00 invariant); Sentry breadcrumb non-PII (≤120-char snippet, no user_id/profile_id); FR replacement string byte-identical.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Flutter CapEngine → backend ctx | Flutter writes `cap_headline`, `cap_expected_impact`, etc. into the profile_context; these are user-influenced strings reaching the LLM. Garde acts as the output-filter between cap text and LLM. |
| `_validate_cap_response` → Sentry | Outbound telemetry; snippet is 120-char window around offending CHF token — by design contains the offending text but no user_id, no profile_id, no email. |
| Cap response text → LLM | Untrusted in the sense that CapEngine bugs / stale data could produce CHF claims without citation; garde ensures structural compliance regardless of upstream bugs. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-06-01 | T (Tampering) | Legacy `_format_cap_status` regression when garde flag OFF | mitigate | Test 5 asserts byte-identity passthrough when flag OFF. |
| T-WAVE1A-06-02 | I (Information disclosure) | LSFin banned-terms leak in garde replacement string | mitigate | « [montant indisponible] » verbatim FR — passed through `banned_terms_python.py` in verify step; pure ASCII (no accents to break). |
| T-WAVE1A-06-03 | I | PII leak in Sentry breadcrumb `snippet` payload | mitigate | `snippet` is the 120-char window around the rejected CHF token — by design contains the offending text but no user_id, no profile_id, no email. Test 2 inspects the payload structure. Sentry staging project retention ≤90 days. |
| T-WAVE1A-06-04 | T | Regex drift between citation_parser and cap garde | mitigate | Acceptance criterion proves `_RE_CURRENCY` is IMPORTED from `citation_parser`, never redeclared (`grep -c "_RE_CURRENCY\s*=\s*re\.compile" coach_chat.py` returns 0). Single source of truth at citation_parser.py:68-70. |
| T-WAVE1A-06-05 | D (Denial of service) | adversarial input with 1000 CHF tokens → 1000 breadcrumbs | accept | Sentry SDK self-rate-limits ; ≤1 garde invocation per coach turn ; typical cap text ≤400 chars (≤2-3 CHF tokens max). Low risk; not worth a per-call rate limit at this stage. |
| T-WAVE1A-06-06 | E (Elevation of privilege) | Sentry SDK raises during breadcrumb emission, breaks coach response | mitigate | `try/except Exception: pass` wraps the entire sentry_sdk.add_breadcrumb call — same fail-open guarantee as the plan-00 `emit_coach_tool_breadcrumb` helper. |
| T-WAVE1A-06-07 | T | Offset calculation bug in multi-token replacement produces corrupt output | mitigate | Test 6 (multi-token mixed) explicitly tests 3 CHF tokens with offset arithmetic. The implementation tracks `offset` cumulatively across replacements; finditer returns matches in source-position order (matches must be replaced left-to-right, which the loop does naturally). |
</threat_model>

<verification>
- `pytest services/backend/tests/test_cap_garde.py -q` exits 0 with ≥5 tests (plan ships 6).
- `pytest services/backend/ -q` full suite — zero regressions (target ≥6567 baseline + 6 = ≥6573).
- `python3 tools/checks/banned_terms_python.py` green on touched files.
- `python3 tools/checks/accent_lint_fr.py` green on touched files.
- Garde flag default ON preserved (grep proof: `COACH_CAP_CHF_GARDE_ENABLED: bool = True` count = 1).
- Regex single-sourced (grep proof: `_RE_CURRENCY\s*=\s*re\.compile` count = 0 in coach_chat.py — REUSED from citation_parser only).
- Dispatcher marker pair preserved exactly (grep proof: 1 opening + 1 closing).
- config.py is NOT in `files_modified` — plan-00 single source of truth invariant honored.
</verification>

<success_criteria>
- WAVE1A-04 satisfied: `get_cap_status` stays Flutter-sourced AND gains runtime CHF garde; un-cited CHF tokens are replaced with `[montant indisponible]`; Sentry breadcrumb fires for measurement (re-litigation signal per D-17).
- ≥6 new backend tests (target ≥5), lints green, no LSFin regression, regex single-sourced.
- Plan-00 invariant honored: COACH_CAP_CHF_GARDE_ENABLED read-only (not redeclared in this plan).
- Dispatcher marker pair preserved exactly (panel race-fix invariant from plan-00 architect-review concern #1).
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-06-SUMMARY.md` with:
- Files modified (paths + line deltas — confirm coach_chat.py is the ONLY modified source file in `app/`, plus the new test file).
- 6+ tests collected + passed (paste pytest tail).
- accent_lint_fr.py + banned_terms_python.py green outputs.
- Regex-reuse proof: paste `grep "from app.services.coach.citation_parser import _RE_CURRENCY" coach_chat.py` AND `grep -c "_RE_CURRENCY\s*=\s*re\.compile" coach_chat.py` (= 0).
- Dispatcher marker preservation proof: paste `grep -c "# >>> dispatch: get_cap_status" coach_chat.py` (= 1) AND `grep -c "# <<< dispatch: get_cap_status" coach_chat.py` (= 1).
- Plan-00 invariant proof: paste `grep -c "COACH_CAP_CHF_GARDE_ENABLED: bool = True" config.py` (= 1, unchanged from pre-plan-06).
- Multi-token offset correctness proof: paste Test 6 output (3 tokens, 2 replaced + 1 preserved).
- 0-trust §9 self-check section citing every command output verbatim (G3 pytest exit 0 + G4 regression count baseline+N + G5 lints exit 0).
</output>
