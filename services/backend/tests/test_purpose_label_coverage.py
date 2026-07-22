"""Le libellé affiché de transfer_us_anthropic doit couvrir TOUS ses usages.

Audit T08-F35 follow-up (beads MINT_nosync-65y, review Codex PR #961) : la
finalité est utilisée par (a) le flux documents Vision ET (b) le coach
(profil financier exact + messages). Un libellé documents-only rend le
consentement non éclairé pour l'usage coach — préalable obligatoire au flip
hard_block.
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
POLICY = REPO / "docs" / "legal" / "privacy_policy_v2.3.0.md"
ARB_FR = REPO / "apps" / "mobile" / "lib" / "l10n" / "app_fr.arb"


def _section_3_3(text: str) -> str:
    start = text.find("### 3.3")
    end = text.find("### 3.4")
    assert start != -1 and end > start
    return text[start:end].lower()


def test_policy_purpose_covers_coach_profile():
    sec = _section_3_3(POLICY.read_text(encoding="utf-8"))
    assert "coach" in sec, "policy §3.3 ne mentionne pas l'usage coach"
    assert "profil" in sec, "policy §3.3 ne mentionne pas le profil financier"
    assert "message" in sec, "policy §3.3 ne mentionne pas les messages"


def test_consent_sheet_label_covers_coach_profile():
    import json

    arb = json.loads(ARB_FR.read_text(encoding="utf-8"))
    why = arb["consentPurposeTransferUsAnthropicWhy"].lower()
    assert "coach" in why, "libellé sheet ne mentionne pas l'usage coach"
    assert "profil" in why, "libellé sheet ne mentionne pas le profil"
