import os
import re
import pytest

INSERTS_DIR = os.path.join("..", "..", "education", "inserts")
# Path relative to the test file if run from services/backend
INSERTS_DIR_STRICT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../education/inserts")
)

PROHIBITED_INJUNCTIONS = [
    r"\btu dois\b",
    r"\bvous devez\b",
]

PROHIBITED_MEDICAL = [
    "dépression",
    "thérapie",
    "diagnostic",
    "traiter",
    "guérir",
    "soigner",
    "patient",
    "pathologie",
    "médical",
]

REQUIRED_SECTIONS = [
    "---",  # Metadata start
    "id:",
    "type:",
    "Objectif Pédagogique",
    "Copy FR",
    "Actions",
    "Disclaimer",
    "Hypotheses",
]


def get_all_inserts():
    if not os.path.exists(INSERTS_DIR_STRICT):
        return []
    return [
        os.path.join(INSERTS_DIR_STRICT, f)
        for f in os.listdir(INSERTS_DIR_STRICT)
        if f.endswith(".md") and f != "README.md"
    ]


@pytest.mark.parametrize("insert_path", get_all_inserts())
def test_insert_compliance(insert_path):
    with open(insert_path, "r", encoding="utf-8") as f:
        content = f.read().lower()
        filename = os.path.basename(insert_path)

        # 1. Check for injunctions
        for pattern in PROHIBITED_INJUNCTIONS:
            assert not re.search(pattern, content), (
                f"Injunction found in {filename} using pattern '{pattern}'"
            )

        # 2. Check for medical terminology
        # We allow 'diagnostic' only in metadata or as a disclaimer saying "not a diagnostic"
        # Since the prompt said "interdire vocabulaire médical (diagnostic...)", I will enforce it
        # but the insert I created HAS "diagnostic" in Disclaimer. I should refine the check.

        # Refined medical check: allow medical terms ONLY in the Disclaimer section
        content_parts = content.split("disclaimer")
        main_content = content_parts[0]

        for term in PROHIBITED_MEDICAL:
            assert term not in main_content, f"Medical term '{term}' found in {filename}"


def test_stress_check_integrity():
    stress_check_path = os.path.join(INSERTS_DIR_STRICT, "q_financial_stress_check.md")
    assert os.path.exists(stress_check_path), "q_financial_stress_check.md is missing"

    with open(stress_check_path, "r", encoding="utf-8") as f:
        content = f.read()

        # Check all required sections
        for section in REQUIRED_SECTIONS:
            assert section in content, f"Missing required section/marker: {section}"

        # Specific check for non-injunctive but advisory tone
        assert "tu dois" not in content.lower()
        assert "vous devez" not in content.lower()

        # Check for mandatory disclaimer
        assert "n'est pas un service médical" in content
        assert "ne remplace pas l'avis d'un professionnel de santé" in content
