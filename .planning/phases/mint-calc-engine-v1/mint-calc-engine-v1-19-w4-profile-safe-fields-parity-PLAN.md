---
phase: mint-calc-engine-v1
plan: 19
wave: 4
title: W4 — Flutter ↔ server _PROFILE_SAFE_FIELDS parity lint (Concern C)
type: execute
depends_on: [01]
files_modified:
  - tools/checks/profile_safe_fields_parity.py
  - tools/checks/tests/test_profile_safe_fields_parity.py
  - lefthook.yml
autonomous: true
requirements: [Concern-C]
estimated_duration: 2
must_haves:
  truths:
    - "Lint walks server canonical `_PROFILE_SAFE_FIELDS` at `coach_chat.py:875` + asserts each name maps to a Dart field in `coach_context_builder.dart`"
    - "Lint runs in lefthook pre-commit on touches to either file"
    - "Drift between Flutter and server triggers lint failure (exit 1) with file:line diff report"
  artifacts:
    - path: tools/checks/profile_safe_fields_parity.py
      provides: "Parity lint with exit 1 on drift"
      min_lines: 60
  key_links:
    - from: tools/checks/profile_safe_fields_parity.py
      to: services/backend/app/api/v1/endpoints/coach_chat.py
      via: "AST-extract _PROFILE_SAFE_FIELDS list"
      pattern: "_PROFILE_SAFE_FIELDS"
    - from: tools/checks/profile_safe_fields_parity.py
      to: apps/mobile/lib/services/coach/coach_context_builder.dart
      via: "regex-extract Dart field names"
      pattern: "coach_context_builder"
---

<objective>
Ship Concern C parity lint. Server canonical `_PROFILE_SAFE_FIELDS` at `coach_chat.py:875` is the source of truth ; Flutter `coach_context_builder.dart` must mirror it. Drift = silent grounding gap.

Purpose: Concern C. Lint catches drift at pre-commit, BEFORE merge.

Output: 1 lint script + 1 self-test + lefthook wiring.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@apps/mobile/lib/services/coach/coach_context_builder.dart
@tools/checks/banned_terms_python.py
@lefthook.yml
</context>

<tasks>

<task id="W4-03-01" type="auto" tdd="true">
  <name>Task 1: profile_safe_fields_parity.py lint + tests</name>
  <files>tools/checks/profile_safe_fields_parity.py, tools/checks/tests/test_profile_safe_fields_parity.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py:875 (`_PROFILE_SAFE_FIELDS` declaration)
    - apps/mobile/lib/services/coach/coach_context_builder.dart (current Dart field names)
    - tools/checks/banned_terms_python.py (lint pattern precedent)
  </read_first>
  <behavior>
    - Test 1: Lint succeeds (exit 0) when server + Flutter lists match.
    - Test 2: Lint fails (exit 1) when server has a field Flutter is missing.
    - Test 3: Lint fails (exit 1) when Flutter has a field server doesn't expose.
    - Test 4: Diff report identifies the specific missing field name + which side is missing.
  </behavior>
  <action>
    ```python
    # tools/checks/profile_safe_fields_parity.py
    """Phase mint-calc-engine-v1 W4 — Concern C parity lint.

    Server canonical: _PROFILE_SAFE_FIELDS at coach_chat.py:875 (source of truth).
    Flutter mirror: apps/mobile/lib/services/coach/coach_context_builder.dart.

    Drift = silent grounding gap. Lint catches at pre-commit.
    """
    import ast
    import re
    import sys
    from pathlib import Path


    SERVER_FILE = Path("services/backend/app/api/v1/endpoints/coach_chat.py")
    DART_FILE = Path("apps/mobile/lib/services/coach/coach_context_builder.dart")


    def extract_server_fields() -> set[str]:
        """AST-extract _PROFILE_SAFE_FIELDS list from coach_chat.py."""
        source = SERVER_FILE.read_text()
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id == "_PROFILE_SAFE_FIELDS":
                        # Expect a list/frozenset of string literals
                        if isinstance(node.value, (ast.List, ast.Set, ast.Tuple)):
                            return {
                                el.value for el in node.value.elts
                                if isinstance(el, ast.Constant) and isinstance(el.value, str)
                            }
                        # frozenset({...}) call
                        if isinstance(node.value, ast.Call):
                            args = node.value.args
                            if args and isinstance(args[0], (ast.List, ast.Set, ast.Tuple)):
                                return {
                                    el.value for el in args[0].elts
                                    if isinstance(el, ast.Constant) and isinstance(el.value, str)
                                }
        return set()


    def extract_dart_fields() -> set[str]:
        """Regex-extract Dart context-builder field names.

        Heuristic: looks for `'<field_name>': <expr>,` or `"<field_name>": <expr>,`
        inside the build*Context method body.
        """
        source = DART_FILE.read_text()
        # Match string keys in Map literals — e.g. 'canton': profile.canton,
        return set(re.findall(r"['\"]([a-z][a-z_0-9]+)['\"]\s*:", source))


    def main() -> int:
        server = extract_server_fields()
        dart = extract_dart_fields()
        if server == dart:
            print("Concern C parity: OK")
            return 0
        missing_in_dart = sorted(server - dart)
        extra_in_dart = sorted(dart - server)
        if missing_in_dart:
            print(f"Concern C parity FAIL: server has fields Dart is missing: {missing_in_dart}")
        if extra_in_dart:
            print(f"Concern C parity FAIL: Dart has fields server doesn't expose: {extra_in_dart}")
        return 1


    if __name__ == "__main__":
        sys.exit(main())
    ```

    4 tests in `tools/checks/tests/test_profile_safe_fields_parity.py`.
  </action>
  <verify>
    <automated>python3 tools/checks/profile_safe_fields_parity.py 2>&1 | tail -3 ; echo "EXIT=$?"</automated>
  </verify>
  <acceptance_criteria>
    - Script ≥60 lines, exits 0 if parity OR exits 1 with diff if drift
    - 4 self-tests green
    - Heuristic correctly identifies ≥10 server fields and ≥10 Dart fields (sanity check)
  </acceptance_criteria>
  <done>Parity lint live</done>
</task>

<task id="W4-03-02" type="auto" tdd="false">
  <name>Task 2: lefthook pre-commit wiring</name>
  <files>lefthook.yml</files>
  <read_first>
    - lefthook.yml (current pre-commit gates)
    - tools/checks/profile_safe_fields_parity.py (just created)
  </read_first>
  <action>
    Add a hook to `lefthook.yml` `pre-commit` section:

    ```yaml
    pre-commit:
      commands:
        # ... existing hooks ...
        profile_safe_fields_parity:
          glob: "{services/backend/app/api/v1/endpoints/coach_chat.py,apps/mobile/lib/services/coach/coach_context_builder.dart}"
          run: python3 tools/checks/profile_safe_fields_parity.py
    ```

    Per memory `feedback_ci_path_filter_blind_spots`: also add to backend CI lints workflow if not auto-included.
  </action>
  <verify>
    <automated>grep -c "profile_safe_fields_parity" lefthook.yml</automated>
  </verify>
  <acceptance_criteria>
    - lefthook entry added
    - `grep -c "profile_safe_fields_parity" lefthook.yml` returns ≥1
    - Running `lefthook run pre-commit --files services/backend/app/api/v1/endpoints/coach_chat.py` 2>&1 shows the lint executing
  </acceptance_criteria>
  <done>lefthook wired</done>
</task>

<task id="W4-03-99" type="auto" tdd="false">
  <name>Task 3: Engram</name>
  <files>(engram)</files>
  <action>
    Engram save:
    - `topic_key: calc_engine:w4:profile_safe_fields_parity_lint`
    - `type: pattern`
    - `prior_finding_refs: [Plan 01 obs, #103 panel synthesis Concern C, memory feedback_ci_path_filter_blind_spots]`
    - Content: « Concern C parity lint live. Server _PROFILE_SAFE_FIELDS at coach_chat.py:875 + Flutter coach_context_builder.dart mirror. Drift caught at pre-commit via lefthook glob trigger. CI fallback inherited per memory feedback_ci_path_filter_blind_spots. »
  </action>
  <verify>
    <automated>python3 tools/checks/profile_safe_fields_parity.py 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Lint baseline state captured in SUMMARY (PASS or initial drift list)
    - Engram saved
  </acceptance_criteria>
  <done>W4-03 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-19-01 | Tampering | parity drift silent merge | mitigate | lefthook gate fails closed on diff. CI fallback per memory note. |
| T-mint-calc-19-02 | Information disclosure | parity diff output | accept | Lists FIELD NAMES only ; no PII. |
| T-mint-calc-19-03 | DoS | lint runtime | accept | <100ms (AST + regex on 2 files). |
| T-mint-calc-19-04 | LSFin | n/a | accept | Not financial output surface. |
</threat_model>

<success_criteria>
- Parity lint live + 4 tests green
- lefthook wired
- Engram observation persisted
</success_criteria>

<risks>
- **Heuristic Dart regex.** The `['\"]<field_name>['\"]:` pattern may miss Dart field names in non-map contexts (e.g. method args). If false-negative rate >10%, refine in follow-up.
- **Initial drift expected.** First lint run may surface existing drift. Document as P1 follow-ups OR fix in this plan if scope allows (≤5 field renames).
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-19-w4-profile-safe-fields-parity-SUMMARY.md`.
</output>
