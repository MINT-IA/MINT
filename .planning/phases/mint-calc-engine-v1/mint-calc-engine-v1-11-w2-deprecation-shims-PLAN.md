---
phase: mint-calc-engine-v1
plan: 11
wave: 2
title: W2 — Deprecation shims for `independant_service.py` + `frontalier_service.py` roots (D-CE-10)
type: execute
depends_on: [01]
files_modified:
  - services/backend/app/services/independant_service.py
  - services/backend/app/services/frontalier_service.py
  - services/backend/tests/test_independant_shim.py
  - services/backend/tests/test_frontalier_shim.py
autonomous: true
requirements: [D-CE-10]
estimated_duration: 2
must_haves:
  truths:
    - "Root `independant_service.py` is a 1-line `from app.services.independants import *` shim with `DeprecationWarning`"
    - "Root `frontalier_service.py` is a shim importing from `expat/frontalier_service.py` with `DeprecationWarning`"
    - "All callers of root paths grep'd + verified migrated to canonical paths"
    - "Both shims documented for removal in next release post-W2 merge"
  artifacts:
    - path: services/backend/app/services/independant_service.py
      provides: "Shim with re-export + DeprecationWarning"
      max_lines: 25
    - path: services/backend/app/services/frontalier_service.py
      provides: "Shim with re-export + DeprecationWarning"
      max_lines: 25
  key_links:
    - from: services/backend/app/services/independant_service.py
      to: services/backend/app/services/independants/
      via: "from app.services.independants import *"
      pattern: "from app.services.independants"
---

<objective>
Mechanical cleanup of duplicate service files per D-CE-10. Both `independant_service.py` (root) and `frontalier_service.py` (root) are W0-audit-flagged duplicates. Sub-directory versions (`independants/` + `expat/frontalier_service.py`) are canonical.

Purpose: D-CE-10. Single-source-of-truth restoration. Strangler fig (Fowler) — shims for 1 release, then removed.

Output: 2 root files become 1-line `from ... import *` shims with `warnings.warn(DeprecationWarning(...))`. All callers grep'd + migrated.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@services/backend/app/services/independant_service.py
@services/backend/app/services/frontalier_service.py
@services/backend/app/services/independants/__init__.py
@services/backend/app/services/expat/frontalier_service.py
</context>

<tasks>

<task id="W2-05-00" type="auto" tdd="false">
  <name>Task 0: Pre-flight — grep all callers of root paths</name>
  <files>(read-only)</files>
  <read_first>
    - services/backend/app/services/independant_service.py
    - services/backend/app/services/frontalier_service.py
  </read_first>
  <action>
    Identify all import paths that consume the root files:

    1. `grep -rn "from app.services.independant_service\|from app.services import independant_service" services/backend/ apps/ tools/ 2>/dev/null`
    2. `grep -rn "from app.services.frontalier_service\|from app.services import frontalier_service" services/backend/ apps/ tools/ 2>/dev/null`

    Document the caller list in SUMMARY. If a caller is INTERNAL (services/backend), migrate to canonical path in this plan. If EXTERNAL (apps/, tools/), keep shim alive but warn.

    Per D-CE-20: spot-check that `services/backend/app/services/independants/__init__.py` re-exports everything `independant_service.py` exports. If missing, surface as P1 follow-up.
  </action>
  <verify>
    <automated>grep -rn "from app.services.independant_service\|from app.services import independant_service" services/backend/ 2>&1 | wc -l</automated>
  </verify>
  <acceptance_criteria>
    - Caller list captured in SUMMARY (per file)
    - `independants/__init__.py` re-export coverage verified ; missing exports flagged as P1
  </acceptance_criteria>
  <done>Pre-flight done</done>
</task>

<task id="W2-05-01" type="auto" tdd="true">
  <name>Task 1: `independant_service.py` shim + migrate internal callers</name>
  <files>services/backend/app/services/independant_service.py, services/backend/tests/test_independant_shim.py</files>
  <read_first>
    - services/backend/app/services/independant_service.py (current full content)
    - services/backend/app/services/independants/__init__.py (canonical exports)
  </read_first>
  <behavior>
    - Test 1: `import warnings; with warnings.catch_warnings(record=True) as w: from app.services import independant_service; assert any(issubclass(ww.category, DeprecationWarning) for ww in w)` succeeds.
    - Test 2: `from app.services.independant_service import <known_export>` still works (re-export functional).
    - Test 3: Migration target documented (caller list in SUMMARY).
  </behavior>
  <action>
    Replace contents of `services/backend/app/services/independant_service.py` (preserve only file existence — destroys current logic in favor of canonical re-export):

    ```python
    """DEPRECATED — Phase mint-calc-engine-v1 D-CE-10.

    This module is a shim re-exporting from `app.services.independants/`.
    Removed in next release post-W2 merge.

    Migrate callers to:
        from app.services.independants import <symbol>
    """
    import warnings

    warnings.warn(
        "app.services.independant_service is deprecated. "
        "Use `from app.services.independants import <symbol>` instead. "
        "Removed in next release post-W2 merge.",
        DeprecationWarning,
        stacklevel=2,
    )

    from app.services.independants import *  # noqa: F401,F403
    ```

    Migrate any INTERNAL caller (per Task 0 grep) to use `from app.services.independants import ...`.

    Test file `test_independant_shim.py` with 3 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_independant_shim.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `wc -l services/backend/app/services/independant_service.py` returns ≤25
    - `grep -c "DeprecationWarning" services/backend/app/services/independant_service.py` returns 1
    - `grep -c "from app.services.independants import \*" services/backend/app/services/independant_service.py` returns 1
    - 3 shim tests green
    - All previously-passing tests using legacy import path still pass (re-export coverage)
  </acceptance_criteria>
  <done>Shim live</done>
</task>

<task id="W2-05-02" type="auto" tdd="true">
  <name>Task 2: `frontalier_service.py` shim + migrate callers</name>
  <files>services/backend/app/services/frontalier_service.py, services/backend/tests/test_frontalier_shim.py</files>
  <read_first>
    - services/backend/app/services/frontalier_service.py (current root content)
    - services/backend/app/services/expat/frontalier_service.py (canonical content)
  </read_first>
  <action>
    Same pattern as Task 1. Root `frontalier_service.py` becomes:

    ```python
    """DEPRECATED — Phase mint-calc-engine-v1 D-CE-10.

    This module is a shim re-exporting from `app.services.expat.frontalier_service`.
    Removed in next release post-W2 merge.

    Migrate callers to:
        from app.services.expat.frontalier_service import <symbol>
    """
    import warnings

    warnings.warn(
        "app.services.frontalier_service is deprecated. "
        "Use `from app.services.expat.frontalier_service import <symbol>` instead. "
        "Removed in next release post-W2 merge.",
        DeprecationWarning,
        stacklevel=2,
    )

    from app.services.expat.frontalier_service import *  # noqa: F401,F403
    ```

    Test file with 3 tests mirroring Task 1.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_frontalier_shim.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `wc -l services/backend/app/services/frontalier_service.py` returns ≤25
    - 3 shim tests green
    - All previously-passing tests still pass
  </acceptance_criteria>
  <done>Shim live</done>
</task>

<task id="W2-05-99" type="auto" tdd="false">
  <name>Task 3: Full suite + engram + removal TODO</name>
  <files>(verification + engram)</files>
  <action>
    Engram save:
    - `topic_key: calc_engine:w2:deprecation_shims_independant_frontalier`
    - `type: architecture`
    - `prior_finding_refs: [W0 audit row 32 (independant root duplicate), W0 audit row 35 (frontalier root duplicate), #103 panel synthesis D-CE-10]`
    - Content: « Root `independant_service.py` + `frontalier_service.py` shimmed with DeprecationWarning. All internal callers migrated to canonical paths. Removal scheduled for next release post-W2 merge. Strangler fig per D-CE-10 / Fowler. »

    Note in SUMMARY: « TODO post-W2 merge: delete both shims in a one-line PR. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
    - Removal TODO documented
  </acceptance_criteria>
  <done>W2-05 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-11-01 | Tampering | shim re-export break | mitigate | Test 2 of each task verifies known exports still resolvable. Full backend suite catches any caller-side breakage. |
| T-mint-calc-11-02 | Information disclosure | DeprecationWarning leak | accept | DeprecationWarning surfaces to Sentry as warning. No PII content. |
| T-mint-calc-11-03 | LSFin | shim text | mitigate | Text uses « deprecated » + path migration instructions. No financial claims. banned_terms_python.py lint runs on touched files. |
</threat_model>

<success_criteria>
- 2 shim files ≤25 LOC each
- 6 shim tests green
- All internal callers migrated
- Full suite green
- Engram observation + removal TODO
</success_criteria>

<risks>
- **External callers in apps/ or tools/**. If grep finds external imports, leave shim alive AND document migration step in a public-facing changelog (post-phase).
- **Re-export coverage gap.** If `independants/__init__.py` doesn't re-export everything the root file used to expose, callers break. Test 2 catches this — surfacing the gap.
- **`# noqa: F401,F403` lint suppression.** `from X import *` triggers lint rules. The noqa is intentional and documented in the docstring.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-11-w2-deprecation-shims-SUMMARY.md` + W2 wave-close engram (cumulative since Plans 07-11).
</output>
