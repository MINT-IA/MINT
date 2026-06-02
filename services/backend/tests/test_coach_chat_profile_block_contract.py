"""Source contract for the final Coach profile block.

The endpoint currently builds the final `PROFIL UTILISATEUR` block inline.
This contract pins that DB `pillar3aAnnual` is surfaced there, not only in
the intermediate sanitized context.
"""
from __future__ import annotations

import pathlib


def test_final_profile_block_includes_annual_3a_contribution():
    source = (
        pathlib.Path(__file__).resolve().parent.parent
        / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    ).read_text(encoding="utf-8")

    profile_block_start = source.index('if _d.get("pillar3aBalance")')
    session_block_start = source.index("## PROFIL UTILISATEUR (faits saisis cette session")
    profile_block_source = source[profile_block_start:session_block_start]

    assert 'if _d.get("pillar3aAnnual")' in profile_block_source
    assert "3a verse cette annee" in profile_block_source
