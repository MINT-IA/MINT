---
phase: wave-1b
plan: 02
type: execute
wave: 1
depends_on: [wave-1b-01]
files_modified:
  - services/backend/app/services/coach/citation_registry.py
  - services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py
  - services/backend/tests/test_citation_gate/test_registry_contract.py
autonomous: true
requirements: [WAVE1B-01, WAVE1B-07]
must_haves:
  truths:
    - "CITATION_REGISTRY contains 6 new entries (one per Wave 1a tool) with source_kind='tool_call_id'"
    - "Each new entry's description_fr is FR-accent-clean and LSFin-banned-terms-clean"
    - "The 6 new registry keys follow the pattern tool_<name> (e.g. tool_budget_snapshot)"
    - "The 6 new source_ref values follow the pattern tool:<name> (e.g. tool:budget_snapshot)"
    - "test_registry_contract.py::test_registry_subset_of_bundle_allowlists is updated to exempt source_kind='tool_call_id' entries"
    - "A new complementary invariant test verifies every tool_* key has a corresponding _compute_<tool> dispatcher branch in coach_chat.py"
    - "Plan 01's stubs in test_tool_call_id_registry_entries.py have their skip markers removed and tests pass"
  artifacts:
    - path: "services/backend/app/services/coach/citation_registry.py"
      provides: "6 new tool_call_id entries in _REGISTRY dict"
      contains: "tool_budget_snapshot|tool_retirement_projection|tool_cross_pillar_analysis|tool_couple_optimization|tool_cap_status|tool_retrieve_memories"
    - path: "services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py"
      provides: "All 6 stub tests unskipped + passing"
      contains: "def test_six_entries_present|def test_source_kind_invariant|def test_resolve_returns_description"
    - path: "services/backend/tests/test_citation_gate/test_registry_contract.py"
      provides: "Subset invariant exempts tool_call_id; complementary invariant added"
      contains: "tool_call_id"
  key_links:
    - from: "services/backend/app/services/coach/citation_registry.py"
      to: "services/backend/app/api/v1/endpoints/coach_chat.py"
      via: "Every tool_<name> key resolves to a _compute_<name> dispatcher branch"
      pattern: "_compute_budget_status|_compute_retirement_projection|_compute_cross_pillar_analysis|_compute_couple_optimization|_compute_retrieve_memories"
---

<objective>
Extend `services/backend/app/services/coach/citation_registry.py` `_REGISTRY` dict with 6 `tool_call_id` entries — one per Wave 1a server-side tool (per CONTEXT D-02 + RESEARCH §3.2).

The `source_kind` Literal at `citation_registry.py:54` already declares `"tool_call_id"`; no schema change. New entries follow the existing shape (4 fields: `key`, `source_kind`, `source_ref`, `description_fr` — `extra=forbid` + `frozen=True`).

**Implements WAVE1B-01 per D-02.** Honors all hard constraints — banned terms, accents, MINT ≠ retirement, financial_core reuse (no new calculation logic, only consumer-side registry).

Plan 01 stubs become PASS after this plan lands.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@services/backend/app/services/coach/citation_registry.py
@services/backend/tests/test_citation_gate/test_registry_contract.py

<interfaces>
Existing CitationSource shape (citation_registry.py:36-56):
```python
class CitationSource(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    key: str
    source_kind: Literal["profile", "reasoning", "tool_call_id", "adr", "spec"]
    source_ref: str
    description_fr: str
```

Existing _REGISTRY entries pattern (citation_registry.py:67-72 — pillar3a example):
```python
"r3a_plafond_salarie_2026": CitationSource(
    key="r3a_plafond_salarie_2026",
    source_kind="spec",
    source_ref="spec:OPP3#art_7_alinea_1_lit_a",
    description_fr="Plafond annuel 3a salarié·e affilié·e LPP, OPP3 art. 7 al. 1 let. a, année 2026.",
),
```

Wave 1a dispatcher branches (services/backend/app/api/v1/endpoints/coach_chat.py — for the complementary invariant test):
- `_compute_budget_status` at coach_chat.py:2368-2469 (per wave-1a-SUMMARY.md:64)
- `_compute_retirement_projection` at coach_chat.py:2472-2566
- `_compute_cross_pillar_analysis` at coach_chat.py:2596-2691
- `_compute_couple_optimization` at coach_chat.py:2807-2938
- `_compute_retrieve_memories` at coach_chat.py:910-987
- `_validate_cap_response` (cap CHF garde) at coach_chat.py:2723-2773

RESEARCH §3.2 verbatim FR description strings (banned-terms-clean, accent-clean):
- tool_budget_snapshot — "Instantané du budget calculé côté serveur : revenu mensuel net, dépenses, surplus, mois de liquidité — depuis ton profil MINT."
- tool_retirement_projection — "Projection de retraite calculée côté serveur : rente AVS estimée, rente LPP estimée, total — à partir de ton certificat et de ton profil."
- tool_cross_pillar_analysis — "Analyse inter-piliers calculée côté serveur : marge 3a, marge rachat LPP, économie fiscale potentielle — selon ta situation actuelle."
- tool_couple_optimization — "Optimisation couple calculée côté serveur : répartition AVS, partage fiscal, marge 3a couple — depuis tes estimations partenaire."
- tool_cap_status — "Cap du jour validé côté serveur (garde CHF appliquée) : texte du cap + sources réglementaires explicites — depuis ton profil et l'état du jour."
- tool_retrieve_memories — "Souvenirs pertinents retrouvés par recherche BM25 dans tes faits déclarés — depuis ta biographie financière MINT."
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add 6 tool_call_id entries + update subset invariant + add complementary invariant</name>
  <read_first>
    - services/backend/app/services/coach/citation_registry.py (FULL — confirm _REGISTRY shape, line 65-178)
    - services/backend/tests/test_citation_gate/test_registry_contract.py (FULL — find test_registry_subset_of_bundle_allowlists and study its current shape)
    - services/backend/app/services/coach/bundles/__init__.py (skim — confirm bundle list structure)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 900-1000 (verify _compute_retrieve_memories presence)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2300-2500 (verify _compute_budget_status presence)
    - tools/checks/banned_terms_python.py (CLI usage)
    - tools/checks/accent_lint_fr.py (CLI usage)
  </read_first>
  <files>
    - services/backend/app/services/coach/citation_registry.py (modify)
    - services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py (modify — unskip)
    - services/backend/tests/test_citation_gate/test_registry_contract.py (modify — exempt tool_call_id from subset)
  </files>
  <behavior>
    After this plan:
    - `len(CITATION_REGISTRY) == 24` (was 18; +6).
    - `resolve("tool_budget_snapshot", ctx=None)` returns the FR description string (not None).
    - `CITATION_REGISTRY["tool_budget_snapshot"].source_kind == "tool_call_id"`.
    - All 6 description_fr strings pass `banned_terms_python.py` + `accent_lint_fr.py`.
    - `test_registry_subset_of_bundle_allowlists` exempts source_kind=="tool_call_id" entries (they are NOT required to be in any bundle allowlist — they activate per tool call, not per intent).
    - A new test `test_every_tool_key_has_dispatcher_branch` greps `coach_chat.py` for `_compute_<name>` per `tool_<name>` registry key.
  </behavior>
  <action>
    Step A — Edit `services/backend/app/services/coach/citation_registry.py`. Append after line 177 (last existing entry — `ratio_endettement_max_33pct`) and BEFORE the closing `}` of `_REGISTRY` at line 178. Concretely, insert these 6 entries inside the `_REGISTRY: dict[str, CitationSource] = { ... }` block:

    ```python
        # --------------------------------------------------- Wave 1b tool_call_id
        # 6 entries — one per Wave 1a server-side tool. Per CONTEXT D-02 +
        # RESEARCH §3.2. Each tool's runtime `inputs_hash` + `computed_at` travel
        # via the response container (Pydantic v2 camelCase model with
        # `inputs_hash` 64-char hex), NOT via the registry entry. The Flutter
        # chip-tap modal enriches with these dynamic fields at render time.
        "tool_budget_snapshot": CitationSource(
            key="tool_budget_snapshot",
            source_kind="tool_call_id",
            source_ref="tool:budget_snapshot",
            description_fr="Instantané du budget calculé côté serveur : revenu mensuel net, dépenses, surplus, mois de liquidité — depuis ton profil MINT.",
        ),
        "tool_retirement_projection": CitationSource(
            key="tool_retirement_projection",
            source_kind="tool_call_id",
            source_ref="tool:retirement_projection",
            description_fr="Projection de retraite calculée côté serveur : rente AVS estimée, rente LPP estimée, total — à partir de ton certificat et de ton profil.",
        ),
        "tool_cross_pillar_analysis": CitationSource(
            key="tool_cross_pillar_analysis",
            source_kind="tool_call_id",
            source_ref="tool:cross_pillar_analysis",
            description_fr="Analyse inter-piliers calculée côté serveur : marge 3a, marge rachat LPP, économie fiscale potentielle — selon ta situation actuelle.",
        ),
        "tool_couple_optimization": CitationSource(
            key="tool_couple_optimization",
            source_kind="tool_call_id",
            source_ref="tool:couple_optimization",
            description_fr="Optimisation couple calculée côté serveur : répartition AVS, partage fiscal, marge 3a couple — depuis tes estimations partenaire.",
        ),
        "tool_cap_status": CitationSource(
            key="tool_cap_status",
            source_kind="tool_call_id",
            source_ref="tool:cap_status",
            description_fr="Cap du jour validé côté serveur (garde CHF appliquée) : texte du cap + sources réglementaires explicites — depuis ton profil et l'état du jour.",
        ),
        "tool_retrieve_memories": CitationSource(
            key="tool_retrieve_memories",
            source_kind="tool_call_id",
            source_ref="tool:retrieve_memories",
            description_fr="Souvenirs pertinents retrouvés par recherche BM25 dans tes faits déclarés — depuis ta biographie financière MINT.",
        ),
    ```

    Step B — Run `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_registry.py` — MUST exit 0. If non-zero, the description_fr strings violate LSFin and must be revised (consult RESEARCH §3.2 and CLAUDE.md banned list).

    Step C — Run `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_registry.py` — MUST exit 0.

    Step D — Edit `services/backend/tests/test_citation_gate/test_registry_contract.py`. Locate `test_registry_subset_of_bundle_allowlists`. Add an exemption for source_kind=="tool_call_id" entries. Concrete pattern (adapt to current test shape):
    ```python
    def test_registry_subset_of_bundle_allowlists():
        # Wave 1b: tool_call_id entries activate per tool call (not per intent).
        # Exempt them from the subset rule; complementary invariant covers them
        # in test_every_tool_key_has_dispatcher_branch.
        non_tool_keys = {
            k for k, src in CITATION_REGISTRY.items()
            if src.source_kind != "tool_call_id"
        }
        union_of_allowlists = set()
        for bundle in ALL_BUNDLE_CLASSES:
            union_of_allowlists.update(bundle.citation_allowlist)
        missing = non_tool_keys - union_of_allowlists
        assert not missing, f"Registry keys missing from any bundle allowlist: {missing}"
    ```

    Step E — In the SAME file `test_registry_contract.py`, ADD a new test (or place in `tests/test_coach_citation/test_tool_call_id_registry_entries.py` — pick wherever the dispatcher import lives):
    ```python
    import inspect
    from app.api.v1.endpoints import coach_chat

    def test_every_tool_key_has_dispatcher_branch():
        """Per RESEARCH §9.7 complementary invariant for subset exemption."""
        tool_keys = [
            k for k, src in CITATION_REGISTRY.items()
            if src.source_kind == "tool_call_id"
        ]
        source = inspect.getsource(coach_chat)
        for key in tool_keys:
            # key is e.g. "tool_budget_snapshot" -> expect "_compute_budget_status" OR
            # for cap_status / retrieve_memories the helper may have a different
            # naming; require at least the substring of the bare tool name.
            tool_short = key.replace("tool_", "")
            # Accept either _compute_<short> OR a dispatcher branch mentioning it.
            assert (
                f"_compute_{tool_short}" in source or
                f'"{tool_short}"' in source or  # name == "budget_status" branch
                f"'{tool_short}'" in source
            ), f"Registry key {key} has no dispatcher branch in coach_chat.py"
    ```

    Step F — Edit `services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` to REMOVE all `@pytest.mark.skip(...)` decorators. The 6 stub tests must now PASS.

    Step G — Run `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_registry_entries.py tests/test_citation_gate/test_registry_contract.py -q -x`. MUST exit 0 with the formerly-skipped tests now PASSED.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_citation/test_tool_call_id_registry_entries.py tests/test_citation_gate/test_registry_contract.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "tool_call_id" services/backend/app/services/coach/citation_registry.py` returns ≥7 (1 Literal declaration + 6 entries).
    - `grep -c "tool_budget_snapshot\|tool_retirement_projection\|tool_cross_pillar_analysis\|tool_couple_optimization\|tool_cap_status\|tool_retrieve_memories" services/backend/app/services/coach/citation_registry.py` returns ≥12 (each key appears twice — dict key + `key=` arg).
    - `grep -c 'source_ref="tool:' services/backend/app/services/coach/citation_registry.py` returns ≥6.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_registry.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_registry.py` exits 0.
    - `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_tool_call_id_registry_entries.py` returns 0 (all skip markers removed by Plan 02).
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_registry_entries.py -q` exits 0 with ≥6 PASSED.
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/test_registry_contract.py -q` exits 0 (subset invariant respects exemption).
    - `cd services/backend && python3 -c "from app.services.coach.citation_registry import CITATION_REGISTRY; print(len(CITATION_REGISTRY))"` prints `24`.
  </acceptance_criteria>
  <done>
    6 new registry entries land; subset invariant updated + complementary invariant added; Plan 01 stubs unskipped and green; banned-terms + accent lints clean.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-02-01 | I | description_fr strings contain LSFin banned terms (e.g. "garanti", "optimal") | mitigate | Step B runs `banned_terms_python.py` on the file before commit; CI gate (G5) re-runs in wave_1b_close.sh. Verified manually in RESEARCH §3.2. |
| T-WAVE1B-02-02 | I | description_fr strings have ASCII accents (e.g. "calcule" instead of "calculé") | mitigate | Step C runs `accent_lint_fr.py`; CI gate (G5) re-runs in wave_1b_close.sh. |
| T-WAVE1B-02-03 | T | Registry subset invariant test silently swallows new tool_call_id keys without exemption | mitigate | Subset test explicitly filters source_kind != "tool_call_id" with a comment citing Plan 02; complementary invariant (test_every_tool_key_has_dispatcher_branch) covers the exempted keys. |
| T-WAVE1B-02-04 | T | Registry key naming drift (`tool_<name>` vs `tool:<name>` vs `tool_call_id:<name>`) | mitigate | Convention pinned in source_ref pattern test (Step F stub `test_source_ref_pattern`); future tool additions caught at G3. |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_registry_entries.py -q` exits 0 with ≥6 PASSED.
- `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` exits 0 (no regressions in Phase 94 byte-identity).
- `cd services/backend && python3 -m pytest tests/ -q | tail -3` exits 0 with delta ≥ +6 vs Wave 1a baseline (6864).
- `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_registry.py` exits 0.
- `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_registry.py` exits 0.
</verification>

<success_criteria>
- 6 new `tool_call_id` entries land in CITATION_REGISTRY.
- Phase 94 byte-identity preserved (subset invariant gracefully exempts tool_call_id; complementary invariant adds positive coverage).
- LSFin + accent lints pass on the modified file.
- Wave 0 stubs (Plan 01) for registry tests transition from SKIPPED to PASSED.
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-02-SUMMARY.md` with:
- Test count delta (≥+6 from Plan 01 baseline)
- Registry size before/after (18 → 24)
- 0-trust self-check citing `len(CITATION_REGISTRY)` Python output + lint exit codes
</output>
