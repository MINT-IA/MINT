"""
Tests for the commune tax multiplier service.

Covers:
    - search_communes by name (exact, partial, case-insensitive)
    - search_communes by NPA
    - search_communes with canton filter
    - get_commune_multiplier for known communes
    - get_commune_multiplier fallback to chef-lieu
    - get_commune_by_npa for valid NPAs
    - get_commune_by_npa for unknown NPAs
    - list_communes_by_canton for major cantons
    - get_cheapest_communes globally and per canton
    - Edge cases: empty query, invalid canton, NPA 0
    - Compliance: disclaimer and sources present in results
    - Data integrity: all 26 cantons present

Sources:
    - LHID art. 1 (harmonisation fiscale)
    - LHID art. 2 al. 1 (autonomie communale)

Sprint S20+ — Commune multiplier service tests.
"""

import pytest

from app.services.fiscal.commune_service import (
    search_communes,
    get_commune_multiplier,
    get_commune_by_npa,
    list_communes_by_canton,
    get_cheapest_communes,
    COMMUNE_DATA,
    CANTON_NAMES,
    DISCLAIMER,
    SOURCES,
)


# ===========================================================================
# Test: search_communes by name
# ===========================================================================

class TestSearchCommunesByName:
    """Test searching communes by name."""

    def test_search_exact_name(self):
        """Search for an exact commune name returns a match."""
        results = search_communes("Zürich")
        assert len(results) >= 1
        assert any(r["commune"] == "Zürich" for r in results)
        assert results[0]["canton"] == "ZH"

    def test_search_partial_name(self):
        """Partial name matches return results."""
        results = search_communes("Laus")
        assert len(results) >= 1
        assert any(r["commune"] == "Lausanne" for r in results)

    def test_search_case_insensitive(self):
        """Search is case-insensitive."""
        results = search_communes("zürich")
        assert len(results) >= 1
        assert any(r["commune"] == "Zürich" for r in results)

    def test_search_accent_insensitive(self):
        """Search handles accented characters (e.g. Geneve vs Geneve)."""
        results = search_communes("geneve")
        assert len(results) >= 1
        assert any(r["commune"] == "Genève" for r in results)

    def test_search_with_canton_filter(self):
        """Canton filter restricts results to specified canton."""
        results = search_communes("Bern", canton="BE")
        assert len(results) >= 1
        assert all(r["canton"] == "BE" for r in results)

    def test_search_empty_query(self):
        """Empty query returns no results."""
        results = search_communes("")
        assert results == []

    def test_search_whitespace_query(self):
        """Whitespace-only query returns no results."""
        results = search_communes("   ")
        assert results == []

    def test_search_no_match(self):
        """Unknown commune name returns empty list."""
        results = search_communes("Atlantis")
        assert results == []


# ===========================================================================
# Test: search_communes by NPA
# ===========================================================================

class TestSearchCommunesByNPA:
    """Test searching communes by NPA (postal code)."""

    def test_search_by_npa_zurich(self):
        """NPA 8000 returns Zurich."""
        results = search_communes("8000")
        assert len(results) == 1
        assert results[0]["commune"] == "Zürich"
        assert results[0]["canton"] == "ZH"

    def test_search_by_npa_lausanne(self):
        """NPA 1000 returns Lausanne."""
        results = search_communes("1000")
        assert len(results) == 1
        assert results[0]["commune"] == "Lausanne"
        assert results[0]["canton"] == "VD"

    def test_search_by_npa_unknown(self):
        """Unknown NPA returns empty list."""
        results = search_communes("9999")
        assert results == []

    def test_search_by_npa_with_canton_filter(self):
        """NPA search respects canton filter."""
        results = search_communes("8000", canton="VD")
        assert results == []  # 8000 is in ZH, not VD


# ===========================================================================
# Test: get_commune_multiplier
# ===========================================================================

class TestGetCommuneMultiplier:
    """Test getting multiplier for a specific commune."""

    def test_known_commune_zurich(self):
        """Known commune returns correct multiplier."""
        mult = get_commune_multiplier("ZH", "Zürich")
        assert mult == 2.38

    def test_known_commune_geneve(self):
        """Known commune Geneve returns correct multiplier."""
        mult = get_commune_multiplier("GE", "Genève")
        assert mult == 2.40

    def test_known_commune_zug(self):
        """Zug has a very low multiplier."""
        mult = get_commune_multiplier("ZG", "Zug")
        assert mult == 1.15

    def test_fallback_to_chef_lieu(self):
        """Unknown commune falls back to chef-lieu multiplier."""
        mult = get_commune_multiplier("ZH", "UnknownVillage")
        assert mult == 2.38  # ZH chef-lieu multiplier

    def test_case_insensitive_commune(self):
        """Commune name match is accent/case-insensitive."""
        mult = get_commune_multiplier("ZH", "zurich")
        assert mult == 2.38

    def test_invalid_canton_raises(self):
        """Invalid canton code raises ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            get_commune_multiplier("XX", "SomeCommune")

    def test_canton_case_insensitive(self):
        """Canton code is case-insensitive."""
        mult = get_commune_multiplier("zh", "Zürich")
        assert mult == 2.38


# ===========================================================================
# Test: get_commune_by_npa
# ===========================================================================

class TestGetCommuneByNPA:
    """Test NPA lookup."""

    def test_valid_npa_8000(self):
        """NPA 8000 returns Zurich with full data."""
        result = get_commune_by_npa(8000)
        assert result["commune"] == "Zürich"
        assert result["canton"] == "ZH"
        assert result["multiplier"] == 2.38
        assert 8000 in result["npa"]

    def test_valid_npa_1200(self):
        """NPA 1200 returns Geneve."""
        result = get_commune_by_npa(1200)
        assert result["commune"] == "Genève"
        assert result["canton"] == "GE"
        assert result["multiplier"] == 2.40

    def test_valid_npa_6300(self):
        """NPA 6300 returns Zug."""
        result = get_commune_by_npa(6300)
        assert result["commune"] == "Zug"
        assert result["canton"] == "ZG"

    def test_unknown_npa(self):
        """Unknown NPA returns empty commune."""
        result = get_commune_by_npa(99999)
        assert result["commune"] == ""
        assert result["canton"] == ""
        assert result["multiplier"] == 0.0

    def test_npa_zero(self):
        """NPA 0 returns empty commune."""
        result = get_commune_by_npa(0)
        assert result["commune"] == ""

    def test_npa_result_has_disclaimer(self):
        """NPA result includes disclaimer."""
        result = get_commune_by_npa(8000)
        assert "disclaimer" in result
        assert len(result["disclaimer"]) > 0

    def test_npa_result_has_sources(self):
        """NPA result includes sources."""
        result = get_commune_by_npa(8000)
        assert "sources" in result
        assert len(result["sources"]) > 0


# ===========================================================================
# Test: list_communes_by_canton
# ===========================================================================

class TestListCommunesByCanton:
    """Test listing communes for a canton."""

    def test_list_zh_communes(self):
        """ZH has many communes."""
        results = list_communes_by_canton("ZH")
        assert len(results) >= 10
        # Check sorted by multiplier ascending
        multipliers = [r["multiplier"] for r in results]
        assert multipliers == sorted(multipliers)

    def test_list_ge_communes(self):
        """GE has many communes."""
        results = list_communes_by_canton("GE")
        assert len(results) >= 5

    def test_list_bs_communes(self):
        """BS has 3 communes (integrated system)."""
        results = list_communes_by_canton("BS")
        assert len(results) == 3
        # All Basel-Stadt communes have multiplier 1.00
        assert all(r["multiplier"] == 1.00 for r in results)

    def test_list_invalid_canton(self):
        """Invalid canton raises ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            list_communes_by_canton("XX")

    def test_list_canton_case_insensitive(self):
        """Canton code is case-insensitive."""
        results = list_communes_by_canton("zh")
        assert len(results) >= 10

    def test_list_sorted_ascending(self):
        """Results are sorted by multiplier ascending (cheapest first)."""
        results = list_communes_by_canton("VD")
        multipliers = [r["multiplier"] for r in results]
        assert multipliers == sorted(multipliers)

    def test_list_all_results_have_system(self):
        """All results include the tax system field."""
        results = list_communes_by_canton("ZG")
        for r in results:
            assert r["system"] == "steuerfuss_pct"


# ===========================================================================
# Test: get_cheapest_communes
# ===========================================================================

class TestGetCheapestCommunes:
    """Test cheapest communes ranking."""

    def test_cheapest_global_default(self):
        """Global cheapest returns 10 results by default."""
        results = get_cheapest_communes()
        assert len(results) == 10
        # Should be sorted ascending
        multipliers = [r["multiplier"] for r in results]
        assert multipliers == sorted(multipliers)

    def test_cheapest_global_custom_limit(self):
        """Custom limit is respected."""
        results = get_cheapest_communes(limit=5)
        assert len(results) == 5

    def test_cheapest_per_canton(self):
        """Per-canton cheapest returns only that canton's communes."""
        results = get_cheapest_communes(canton="ZH", limit=5)
        assert len(results) == 5
        assert all(r["canton"] == "ZH" for r in results)

    def test_cheapest_zg_is_very_low(self):
        """Zug communes should be among the cheapest globally."""
        results = get_cheapest_communes(limit=20)
        zg_communes = [r for r in results if r["canton"] == "ZG"]
        assert len(zg_communes) >= 1

    def test_cheapest_invalid_canton(self):
        """Invalid canton returns empty list (no exception)."""
        results = get_cheapest_communes(canton="XX")
        assert results == []

    def test_cheapest_sorted_ascending(self):
        """Results are sorted by multiplier ascending."""
        results = get_cheapest_communes(limit=20)
        multipliers = [r["multiplier"] for r in results]
        assert multipliers == sorted(multipliers)


# ===========================================================================
# Test: Data integrity
# ===========================================================================

class TestDataIntegrity:
    """Test the integrity of the commune data."""

    def test_all_26_cantons_present(self):
        """All 26 Swiss cantons are present in COMMUNE_DATA."""
        expected_cantons = {
            "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG",
            "FR", "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR",
            "AG", "TG", "TI", "VD", "VS", "NE", "GE", "JU",
        }
        assert set(COMMUNE_DATA.keys()) == expected_cantons

    def test_all_cantons_have_chef_lieu(self):
        """Every canton has a chef_lieu_multiplier."""
        for canton_code, data in COMMUNE_DATA.items():
            assert "chef_lieu_multiplier" in data, f"{canton_code} missing chef_lieu_multiplier"
            assert data["chef_lieu_multiplier"] > 0

    def test_all_cantons_have_system(self):
        """Every canton has a tax system type."""
        for canton_code, data in COMMUNE_DATA.items():
            assert "system" in data, f"{canton_code} missing system"
            assert len(data["system"]) > 0

    def test_all_communes_have_npa(self):
        """Every commune has at least one NPA."""
        for canton_code, data in COMMUNE_DATA.items():
            for commune_name, info in data["communes"].items():
                assert len(info["npa"]) >= 1, (
                    f"{commune_name} ({canton_code}) has no NPA"
                )

    def test_all_multipliers_positive(self):
        """All multipliers are positive."""
        for canton_code, data in COMMUNE_DATA.items():
            for commune_name, info in data["communes"].items():
                assert info["multiplier"] > 0, (
                    f"{commune_name} ({canton_code}) has non-positive multiplier"
                )

    def test_canton_names_complete(self):
        """CANTON_NAMES covers all cantons in COMMUNE_DATA."""
        for canton_code in COMMUNE_DATA.keys():
            assert canton_code in CANTON_NAMES, (
                f"{canton_code} missing from CANTON_NAMES"
            )


# ===========================================================================
# Test: Compliance
# ===========================================================================

class TestCompliance:
    """Test compliance fields (disclaimer, sources) are always present."""

    def test_disclaimer_not_empty(self):
        """DISCLAIMER is a non-empty string."""
        assert isinstance(DISCLAIMER, str)
        assert len(DISCLAIMER) > 50

    def test_disclaimer_mentions_educational(self):
        """DISCLAIMER mentions educational nature."""
        assert "educatif" in DISCLAIMER.lower()

    def test_disclaimer_mentions_lsfin(self):
        """DISCLAIMER mentions LSFin (no financial advice)."""
        assert "LSFin" in DISCLAIMER

    def test_disclaimer_no_banned_terms(self):
        """DISCLAIMER does not contain banned terms."""
        banned = ["garanti", "certain", "assuré", "sans risque",
                  "optimal", "meilleur", "parfait", "conseiller"]
        lower_disclaimer = DISCLAIMER.lower()
        for term in banned:
            assert term not in lower_disclaimer, (
                f"Banned term '{term}' found in DISCLAIMER"
            )

    def test_sources_include_lhid(self):
        """SOURCES include LHID references."""
        sources_str = " ".join(SOURCES)
        assert "LHID" in sources_str

    def test_sources_include_autonomie_communale(self):
        """SOURCES include LHID art. 2 al. 1 (autonomie communale)."""
        sources_str = " ".join(SOURCES)
        assert "art. 2" in sources_str

    def test_search_results_have_compliance(self):
        """Search results include disclaimer and sources."""
        results = search_communes("Zürich")
        assert len(results) >= 1
        for r in results:
            assert "disclaimer" in r
            assert "sources" in r
            assert len(r["sources"]) >= 2

    def test_cheapest_results_have_compliance(self):
        """Cheapest results include disclaimer and sources."""
        results = get_cheapest_communes(limit=3)
        for r in results:
            assert "disclaimer" in r
            assert "sources" in r

    def test_list_results_have_compliance(self):
        """List results include disclaimer and sources."""
        results = list_communes_by_canton("ZH")
        for r in results:
            assert "disclaimer" in r
            assert "sources" in r

    def test_npa_not_found_still_has_compliance(self):
        """Even not-found NPA results include compliance fields."""
        result = get_commune_by_npa(99999)
        assert "disclaimer" in result
        assert "sources" in result
        assert len(result["disclaimer"]) > 0
        assert len(result["sources"]) > 0
