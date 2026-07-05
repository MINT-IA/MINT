import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ARB_DIR = ROOT / "apps/mobile/lib/l10n"
MOBILE_LIB = ROOT / "apps/mobile/lib"
PLANNER_ONLY_FILES = {
    MOBILE_LIB / "services/data_quest/data_quest_service.dart",
}

RECONFIRM_ARB_KEYS = {
    "freshnessReconfirmPrompt",
    "freshnessReconfirmYes",
    "freshnessReconfirmUpdate",
    "freshnessReconfirmRescan",
}
DATA_BLOCK_REVENUE_ARB_KEYS = {
    "dataBlockRevenueGrossAnnualLabel",
    "dataBlockRevenueSaveIdle",
    "dataBlockRevenueSaveSaving",
    "dataBlockRevenueInvalidAmount",
    "dataBlockRevenueSaved",
}
LOCALES = ("fr", "en", "de", "es", "it", "pt")

RECONFIRM_WIDGET_MARKERS = (
    "DataQuestAskMode.reconfirm",
    "freshnessReconfirmPrompt",
    "freshnessReconfirmYes",
    "freshnessReconfirmUpdate",
    "freshnessReconfirmRescan",
)
HARDCODED_RECONFIRM_PHRASES = (
    "Toujours d'accord",
    "Oui, toujours",
    "Mettre à jour",
    "Rescanner",
)
HARDCODED_DATA_BLOCK_REVENUE_PHRASES = (
    "Revenu brut annuel",
    "Enregistrement...",
    "Enregistrer",
    "Montant invalide",
    "Revenu enregistré",
)


def _arb_keys(locale: str) -> set[str]:
    path = ARB_DIR / f"app_{locale}.arb"
    data = json.loads(path.read_text(encoding="utf-8"))
    return {key for key in data if not key.startswith("@")}


def _reconfirm_ui_files() -> list[Path]:
    files: list[Path] = []
    for path in sorted(MOBILE_LIB.rglob("*.dart")):
        if path in PLANNER_ONLY_FILES:
            continue
        if "/l10n/" in path.as_posix():
            continue
        text = path.read_text(encoding="utf-8")
        if any(marker in text for marker in RECONFIRM_WIDGET_MARKERS):
            files.append(path)
    return files


def test_data_quest_i18n_keys_are_present_in_all_supported_locales() -> None:
    required = RECONFIRM_ARB_KEYS | DATA_BLOCK_REVENUE_ARB_KEYS
    missing_by_locale = {
        locale: sorted(required - _arb_keys(locale))
        for locale in LOCALES
        if required - _arb_keys(locale)
    }
    assert not missing_by_locale, (
        "Data Quest/Data Block UI requires ARB keys in all six locales: "
        f"{missing_by_locale}"
    )


def test_data_quest_reconfirm_widget_cannot_ship_before_i18n_keys() -> None:
    reconfirm_files = _reconfirm_ui_files()

    assert reconfirm_files, (
        "Data Quest reconfirm UI is accepted in this phase; keep at least one "
        "runtime widget using DataQuestAskMode.reconfirm and freshnessReconfirm*."
    )

    missing_by_locale = {
        locale: sorted(RECONFIRM_ARB_KEYS - _arb_keys(locale))
        for locale in LOCALES
        if RECONFIRM_ARB_KEYS - _arb_keys(locale)
    }
    assert not missing_by_locale, (
        "Data Quest reconfirm UI requires ARB keys in all six locales before "
        f"Dart widget code ships: {missing_by_locale}"
    )

    hardcoded: list[str] = []
    for path in reconfirm_files:
        text = path.read_text(encoding="utf-8")
        for phrase in HARDCODED_RECONFIRM_PHRASES:
            if phrase in text:
                hardcoded.append(f"{path.relative_to(ROOT)}: {phrase}")
    assert not hardcoded, (
        "Data Quest reconfirm UI must use AppLocalizations keys, not hardcoded "
        f"French labels: {hardcoded}"
    )


def test_data_quest_doc_matches_live_reconfirm_ui_status() -> None:
    doc_path = ROOT / "docs/codex/DATA_QUEST.md"
    text = doc_path.read_text(encoding="utf-8")
    forbidden_obsolete_claims = [
        "`/data-block/:type` has no delta/before-after UI, no reconfirm",
        'UI rendering of the 1-tap "Oui / Mettre à jour / Rescanner" widget remains Q-3',
        "Once a non-planner reconfirm widget lands",
    ]
    stale_claims = [
        claim for claim in forbidden_obsolete_claims if claim in text
    ]
    assert not stale_claims, (
        "DATA_QUEST.md still describes the shipped reconfirm UI as missing: "
        f"{stale_claims}"
    )


def test_data_quest_doc_matches_live_goal_aware_confidence_ranking() -> None:
    doc_path = ROOT / "docs/codex/DATA_QUEST.md"
    doc = doc_path.read_text(encoding="utf-8")
    scorer = (
        MOBILE_LIB / "services/financial_core/confidence_scorer.dart"
    ).read_text(encoding="utf-8")

    assert "Goal-aware ranking absent" not in doc
    assert "ranker is generic" not in doc
    assert "final String? fieldPath" in scorer
    assert "_goalAwarePromptScore" in scorer
    assert "GoalAType.achatImmo" in scorer


def test_data_block_revenue_form_uses_i18n_keys() -> None:
    path = MOBILE_LIB / "screens/onboarding/data_block_enrichment_screen.dart"
    text = path.read_text(encoding="utf-8")
    hardcoded = [
        phrase
        for phrase in HARDCODED_DATA_BLOCK_REVENUE_PHRASES
        if phrase in text
    ]
    assert not hardcoded, (
        "Data Block revenue form must use AppLocalizations keys, not hardcoded "
        f"French labels: {hardcoded}"
    )


def test_data_quest_reconfirm_ui_cannot_use_update_profile() -> None:
    offenders: list[str] = []
    for path in _reconfirm_ui_files():
        text = path.read_text(encoding="utf-8")
        if "updateProfile(" in text:
            offenders.append(str(path.relative_to(ROOT)))

    assert not offenders, (
        "Data Quest reconfirm UI must confirm via mergeAnswers(), not "
        f"full-profile updateProfile(): {offenders}"
    )
