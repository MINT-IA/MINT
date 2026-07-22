"""Le libellé affiché de transfer_us_anthropic doit couvrir TOUS ses usages.

Audit T08-F35 follow-up (beads MINT_nosync-65y, review Codex PR #961) : la
finalité est utilisée par (a) le flux documents Vision ET (b) le coach
(profil financier exact + messages). Un libellé documents-only rend le
consentement non éclairé pour l'usage coach — préalable obligatoire au flip
hard_block.
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CURRENT_POLICY_VERSION = "v2.4.0"
POLICY = REPO / "docs" / "legal" / f"privacy_policy_{CURRENT_POLICY_VERSION}.md"
L10N = REPO / "apps" / "mobile" / "lib" / "l10n"


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


def test_consent_sheet_label_covers_coach_profile_all_locales():
    import json

    for lang in ("fr", "en", "de", "es", "it", "pt"):
        arb = json.loads((L10N / f"app_{lang}.arb").read_text(encoding="utf-8"))
        why = arb["consentPurposeTransferUsAnthropicWhy"].lower()
        assert "coach" in why, f"{lang}: libellé sans l'usage coach"
        assert (
            "profil" in why or "profile" in why or "perfil" in why
        ), f"{lang}: sans le profil"
        assert (
            "exact" in why or "exakte" in why or "exato" in why or "esatt" in why
        ), f"{lang}: sans la mention des montants exacts"


def test_current_policy_version_constants_are_coherent():
    """Changement matériel de policy = bump de version PARTOUT (P0 Codex).

    Le fichier v2.4.0 existe, les constantes mobile/backend pointent dessus,
    et l'ancienne v2.3.0 reste intacte pour les reçus historiques.
    """
    assert POLICY.exists(), "policy v2.4.0 absente"
    assert (REPO / "docs" / "legal" / "privacy_policy_v2.3.0.md").exists()

    dart = (
        REPO / "apps" / "mobile" / "lib" / "services" / "consent" /
        "consent_service.dart"
    ).read_text(encoding="utf-8")
    assert f"currentPolicyVersion = '{CURRENT_POLICY_VERSION}'" in dart

    schema = (
        REPO / "services" / "backend" / "app" / "schemas" / "consent_receipt.py"
    ).read_text(encoding="utf-8")
    assert f'default="{CURRENT_POLICY_VERSION}"' in schema
