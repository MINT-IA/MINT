"""Wave 1a Plan 07 — shared fixture-loader package for parity tests.

Renamed from the plan-07 frontmatter literal path
``tests/test_coach_tools/conftest.py`` to ``tests/test_coach_tools_pkg/``
to avoid the documented pytest module-name collision with the
pre-existing ``tests/test_coach_tools.py`` file (plan-00 SUMMARY § Rule 3
deviation 2026-05-14). Plans 01-06 already established the flat-file
sibling convention (``tests/test_coach_tools_<feature>.py``); this
subdirectory is the FIRST per-plan-07 subpackage and applies the same
mitigation.

The ``conftest.py`` next to this file ships the
``parity_fixtures`` pytest fixture + the underlying loader function
``load_parity_fixtures`` that
``tests/test_coach_tools_parity.py`` imports directly.
"""
