"""Phase 94 anticipation stub — narrator citation gate (skip-marked).

Phase 91 Wave 2 ships the structural prereq: narrator's tool list no
longer contains save_fact + save_insight (EXTR-04) and the system
prompt no longer carries extraction directives (EXTR-03). Phase 94
will add the runtime parser that REJECTS narrator output containing
uncited numeric claims.

Until Phase 94 lands, this test is `skip`-marked. Its presence here
flags the contract owners (« le narrateur LLM est mathématiquement
incapable d'émettre un chiffre un-cited » per the milestone doctrine)
and gives Phase 94 a single placeholder to fill.

Run:
    cd services/backend && python3 -m pytest tests/test_narrator_refuses_uncited_numbers.py -v
"""
import pytest


@pytest.mark.skip(
    reason=(
        "Phase 94 CITATION-GATE — runtime parser not implemented yet. "
        "Phase 91 Wave 2 only ships the structural prereq (narrator tools "
        "+ prompt narrowed)."
    )
)
def test_narrator_refuses_uncited_numbers():
    """When Phase 94 ships:

    1. Send a turn that should produce a number (e.g. a projection).
    2. Mock narrator to emit an uncited number (no profile_block source).
    3. Assert ComplianceGuard rejects with a CITATION-GATE marker.

    The gate is the ground-truth invariant for « le narrateur LLM est
    mathématiquement incapable d'émettre un chiffre un-cited ».
    """
    pass
