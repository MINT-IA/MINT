from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "docs/codex/INTERACTION_REGISTRY.md"


def test_interaction_registry_proposed_contract() -> None:
    text = SPEC.read_text(encoding="utf-8")
    required = (
        "Status: Pilot",
        "executor/codegen Proposed",
        "tools/checks/interaction_registry_lint.py",
        "interactions/revenu_to_mortgage.yaml",
        ".planning/journeys/diagrams/interaction_graph.mmd",
        "ne bloque PAS les G produits restants",
        "#849 ne doit pas devenir une autorité produit implicite",
        "SCREEN_CONTRACTS.md",
        "WIRING_GRAPH",
        "contract_double_authority",
        "GÉNÉRÉ — ne pas éditer",
        "un flux non migré reste gouverné par les docs actuels",
        "payload.extra",
        "ids d'entités, enums, codes, tokens",
        "`a11y_label` = clé ARB",
        "guard consentement/nLPD",
    )
    for needle in required:
        assert needle in text
    for forbidden in ("déjà testée", "no_domain_data_in_extra_test.dart"):
        assert forbidden not in text


def test_interaction_registry_example_references_live_artifacts() -> None:
    text = SPEC.read_text(encoding="utf-8")
    analytics = (ROOT / "apps/mobile/lib/services/analytics_events.dart").read_text(
        encoding="utf-8"
    )
    paths = (
        "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart",
        "apps/mobile/lib/screens/mortgage/affordability_screen.dart",
        "apps/mobile/.maestro/f2_datablock_to_mortgage.yaml",
    )
    for rel_path in paths:
        assert (ROOT / rel_path).exists()
    for needle in (
        "/data-block/revenu",
        "/data-block/:type",
        "/hypotheque",
        "JAMAIS par extra",
        "fichiers Maestro mono-flow peuvent citer le fichier seul",
        "analytics: cta_clicked",
    ):
        assert needle in text
    assert "Réservation déjà posée" not in text
    assert "kEventCtaClicked = 'cta_clicked'" in analytics
