"""Self-test fixture for `tools/checks/s23_class_name_lint.py` (D-09 iter-2 B4).

Contains the forbidden `class FrontalierService:` redeclaration pattern verbatim.
NEVER imported by production code.
"""
from __future__ import annotations


class FrontalierService:
    """FORBIDDEN — re-introduction of the old S23 class name."""
    pass
