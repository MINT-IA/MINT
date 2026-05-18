"""Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-09 PR-1) — frontalier rename tests.

Locks the contract that :
  (a) `from app.services.expat.frontalier_service import FrontalierSegmentService` works.
  (b) `FrontalierService is FrontalierSegmentService` (alias identity).
  (c) The S12 façade `app.services.frontalier_service.FrontalierService` is a
      DIFFERENT class with the same name — both must NOT resolve to the
      S23 segment class (this would be a D-08 collision).
  (d) `app.services.expat.__init__` re-exports both names.
"""
from __future__ import annotations

import pytest


def test_canonical_name_importable():
    """`FrontalierSegmentService` is importable from the S23 module."""
    from app.services.expat.frontalier_service import FrontalierSegmentService
    assert FrontalierSegmentService.__name__ == "FrontalierSegmentService"


def test_alias_identity_preserved():
    """`FrontalierService` (old) and `FrontalierSegmentService` (new) are the SAME class."""
    from app.services.expat.frontalier_service import (
        FrontalierService,
        FrontalierSegmentService,
    )
    assert FrontalierService is FrontalierSegmentService, (
        "Alias identity broken — Plan 02-04 PR-2 will remove the alias atomically."
    )


def test_s12_facade_is_different_class():
    """The S12 façade has the same name `FrontalierService` but is a DIFFERENT class.

    This MUST hold per D-08 : `app.services.frontalier_service.FrontalierService`
    is the S12 segments façade, `app.services.expat.frontalier_service.FrontalierService`
    is the S23 segment class (alias of `FrontalierSegmentService` since D-09).
    """
    from app.services.frontalier_service import FrontalierService as S12FrontalierService
    from app.services.expat.frontalier_service import FrontalierSegmentService
    assert S12FrontalierService is not FrontalierSegmentService, (
        "D-08 collision : S12 façade collapsed into S23 segment class."
    )


def test_expat_init_reexports_both_names():
    """The `app.services.expat` package re-exports both names."""
    from app.services.expat import FrontalierService, FrontalierSegmentService
    assert FrontalierService is FrontalierSegmentService


def test_alias_callable_from_old_imports():
    """Old import path `app.services.expat.frontalier_service.FrontalierService()`
    still produces a working instance (no breakage for callers between W0 and W4).
    """
    from app.services.expat.frontalier_service import FrontalierService
    instance = FrontalierService()
    # Must expose the canonical methods.
    assert hasattr(instance, "calculate_source_tax")
