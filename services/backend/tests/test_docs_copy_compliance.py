import pytest
import os
import re
import glob

# --- CONFIGURATION ---
REQUIRED_TAGLINE = "Juste quand il faut: une explication, une action, un rappel."

# Regex patterns for forbidden terms
FORBIDDEN_PATTERNS = {
    "Promesses / Certitudes": [
        r"\bgaranti(e|s)?\b",
        r"\bassur(e|ée|és|ées)?\b",
        r"\bsans risque\b",
        r"\b100%\b",
        r"\bcertain\b|\bcertainement\b",
        r"\btu vas (gagner|économiser|doubler|multiplier)\b",
        r"\b(vous|tu) allez (gagner|économiser)\b",
        r"\bprofit garanti\b",
        r"\breturns? guaranteed\b|\bguaranteed returns?\b",
        r"\bno risk\b",
    ],
    "Gains chiffrés absolus": [
        r"\btu (gagnes|économises) \d+",
        r"\b(vous|tu) (gagnerez|économiserez) \d+",
        r"\b(déménager|bouger) (de|à) \d+\s?km .* (gagner|économiser)\b",
    ],
    "Conseil Produit": [
        r"\bisin\b",
        r"\bticker\b",
        r"\b(etf|fund)\b.*\b[A-Z]{2,5}\b",
        r"\bacheter\b.*\b(action|obligation|etf|fonds)\b",
    ],
    "Injonctions / Pression": [
        r"\b(meilleure décision|la meilleure décision)\b",
        r"\btu dois\b",
        r"\bvous devez\b",
        r"\bil faut (absolument|impérativement)\b",  # Targeted to avoid false positive with tagline
        r"\bobligatoire\b",
    ],
    "Autorité Trompeuse": [
        r"\bofficiel(le|s)?\b",
    ],
    "Actions Bancaires": [
        r"\b(ouvrir|ouvre|ouvert)\s+(un\s+)?(compte|iban)\b",
        r"\b(effectuer|faire)\s+(un\s+)?(virement|transfert|paiement)\b",
        r"\b(acheter|vendre)\s+(des?\s+)?(actions?|obligations?|titres?)\b",
        r"\b(souscrire|souscris)\s+(à|un)\b",
        r"\b(connecte|connecter)\s+(ton|votre)\s+compte\b",
    ],
}

# Whitelist strict "officiel"
OFFICIEL_ALLOWED_PHRASES = [
    r"\bpas un calcul officiel\b",
    r"\bceci n['’]est pas un calcul officiel\b",
    r"\bn['’]est pas un calcul officiel\b",
    r"\bne constitue pas un calcul officiel\b",
    r"\bne remplace pas un calcul officiel\b",
    # Tagline exception if needed, though 'il faut' regex is now targeted
]
OFFICIEL_ALLOWED_RE = re.compile("|".join(OFFICIEL_ALLOWED_PHRASES))

# Allow mechanism
ALLOW_START = "<!-- compliance:allow -->"
ALLOW_END = "<!-- compliance:end -->"
MAX_ALLOW_PER_FILE = 1
MAX_ALLOW_GLOBAL = 2

# Files to check
DOCS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
INSERTS_DIR = os.path.join(DOCS_DIR, "education", "inserts")
IYCOMPRENDSRIEN_DIR = os.path.join(DOCS_DIR, "education", "iycomprendsrien")

FILES_TO_CHECK = {
    "vision_product.md": os.path.join(DOCS_DIR, "visions", "vision_product.md"),
    "vision_features.md": os.path.join(DOCS_DIR, "visions", "vision_features.md"),
    "vision_compliance.md": os.path.join(DOCS_DIR, "visions", "vision_compliance.md"),
    "ADR-CH-EDU-SIMULATORS.md": os.path.join(
        DOCS_DIR, "decisions", "ADR-CH-EDU-SIMULATORS.md"
    ),
}

# Add iycomprendsrien hub
IYCOMPRENDSRIEN_README = os.path.join(IYCOMPRENDSRIEN_DIR, "README.md")
if os.path.exists(IYCOMPRENDSRIEN_README):
    FILES_TO_CHECK["iycomprendsrien_README.md"] = IYCOMPRENDSRIEN_README

# Add inserts dynamically
if os.path.exists(INSERTS_DIR):
    for f in glob.glob(os.path.join(INSERTS_DIR, "*.md")):
        if "README" not in f:
            FILES_TO_CHECK[os.path.basename(f)] = f


def read_file(filepath):
    if not os.path.exists(filepath):
        pytest.fail(f"Fichier manquant: {filepath}")
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


def extract_allowed_sections(content):
    """Exclut les sections marquées allow du scan."""
    pattern = re.compile(
        re.escape(ALLOW_START) + r".*?" + re.escape(ALLOW_END), re.DOTALL
    )
    matches = pattern.findall(content)
    cleaned_content = pattern.sub("", content)
    return cleaned_content, len(matches)


def test_tagline_presence():
    """Vérifie la tagline dans Product et Features."""
    for name in ["vision_product.md", "vision_features.md"]:
        path = FILES_TO_CHECK[name]
        content = read_file(path)
        if REQUIRED_TAGLINE not in content:
            pytest.fail(
                f"Tagline officielle manquante dans {name}.\nAttendu: '{REQUIRED_TAGLINE}'"
            )


def test_forbidden_patterns():
    """Scan strict des patterns interdits."""
    total_allow_count = 0

    for name, path in FILES_TO_CHECK.items():
        raw_content = read_file(path)
        content_to_scan, allow_count = extract_allowed_sections(raw_content)
        total_allow_count += allow_count

        if allow_count > MAX_ALLOW_PER_FILE:
            pytest.fail(
                f"Trop d'exceptions compliance dans {name} ({allow_count} > {MAX_ALLOW_PER_FILE})."
            )

        content_lower = content_to_scan.lower()
        content_lines = content_to_scan.splitlines()

        for category, patterns in FORBIDDEN_PATTERNS.items():
            for pat in patterns:
                matches = re.finditer(pat, content_lower)
                for match in matches:
                    matched_text = match.group(0)

                    # Logic 'Officiel' Strict Whitelist Regex
                    if "officiel" in matched_text:
                        start, end = match.span()
                        # Window context to check specific phrases
                        window = content_lower[
                            max(0, start - 120) : min(len(content_lower), end + 120)
                        ]
                        if OFFICIEL_ALLOWED_RE.search(window):
                            continue

                    # Error Reporting
                    matched_index = match.start()
                    line_num = content_to_scan[:matched_index].count("\n") + 1
                    line_content = content_lines[line_num - 1].strip()

                    pytest.fail(
                        f"COMPLIANCE FAILURE in {name}:{line_num}\n"
                        f"Category: {category}\n"
                        f"Pattern: '{pat}' matched '{matched_text}'\n"
                        f'Snippet: "{line_content}"'
                    )

    if total_allow_count > MAX_ALLOW_GLOBAL:
        pytest.fail(
            f"Quota global d'exceptions dépassé ({total_allow_count} > {MAX_ALLOW_GLOBAL}). Durcissez le copy."
        )


def test_absolute_formulations_check():
    """Check pour formulations absolues type 'tu travailles X mois'."""
    pat = r"\btu (travailles?|bosses?)\s+\d+\s+mois"
    for name, path in FILES_TO_CHECK.items():
        content = read_file(path).lower()
        if re.search(pat, content):
            pytest.fail(
                f"Formulation absolue détectée dans {name}: 'tu travailles X mois'. Ajouter des nuances."
            )


def test_inserts_structure():
    """Vérifie la structure complète des inserts."""
    if not os.path.exists(INSERTS_DIR):
        pytest.skip("Dossier inserts introuvable.")

    required_sections = [
        r"^##\s+Metadata\b",
        r"^##\s+Trigger\b",
        r"^##\s+Inputs\b",
        r"^##\s+Outputs\b",
        r"^##\s+Hypothèses\b",
        r"^##\s+Limites\b",
        r"^##\s+Disclaimer\b",
        r"^##\s+Action\b",
        r"^##\s+Reminder\b",
        r"^##\s+Safe Mode\b",
    ]

    import glob

    insert_files = [
        f
        for f in glob.glob(os.path.join(INSERTS_DIR, "*.md"))
        if "README" not in os.path.basename(f)
    ]

    if not insert_files:
        pytest.fail("Aucun insert trouvé dans education/inserts (hors README).")

    for fpath in insert_files:
        content = read_file(fpath)
        missing = []
        for pat in required_sections:
            if not re.search(pat, content, flags=re.MULTILINE):
                missing.append(pat.replace(r"^##\s+", "").replace(r"\b", ""))

        if missing:
            pytest.fail(
                f"INSERT STRUCTURE FAILURE: {os.path.basename(fpath)}\nSections manquantes: {missing}."
            )
