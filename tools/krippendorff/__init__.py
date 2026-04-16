"""Krippendorff α computation utilities for MINT voice-cursor IRR validation.

Public surface:
    compute_alpha(ratings, levels=None) -> dict

See ``krippendorff_alpha.py`` for the implementation and Phase 11 protocol.
"""

from .krippendorff_alpha import compute_alpha, load_ratings

__all__ = ["compute_alpha", "load_ratings"]
