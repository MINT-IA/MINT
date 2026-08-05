#!/usr/bin/env python3
"""Fail closed unless Batch21 R3 (arc ÉCLAIRAGE — fact_revenu + eclairage_impot_3a)
is an honest, executable RED contract.

Mirrors tools/checks/mint_next_batch20_r2_red_guard.py. R2 (fact_lieu, commune
directe) is done and is superseded BY PIN (regle13 lesson c): this guard never
re-attests R2 live; it only reads the batch21 registry authority.supersedes pin
(r2_green_accepted_commit 816d8f260). The R3 arc adds two nodes AFTER the attested
R2 fact_lieu boundary: fact_revenu (a taxable-income band picker, no keyboard/wheel)
and eclairage_impot_3a (the payoff — a mechanism, a low→high RANGE, four editable
hypotheses, and the estimate-not-advice disclaimer). That fused R3 runtime does NOT
exist, so design_lab_batch21_r3_test.dart drives the attested green 3a entry path to
the R2 fact_lieu boundary (commune selected) and then asserts the absent R3 surface:
2 pass, 12 named behavioural RED failures, 0 load/harness errors.
"""

# HISTORICAL-REPLAY NOTICE (batch19/batch20 pattern, product decision 2026-08-05).
# This is an expected-RED guard: validate()/run_expected_red assert the PRE-runtime
# state (EXPECTED_LIB_SOURCE_SHA256 = the lib WITHOUT the fact_revenu/eclairage
# runtime — it carries the attested R1 canton + R2 fact_lieu runtimes and shared
# infra only). At this sealed RED_COMMIT the R3 runtime is unimplemented, so
# validate() and `--contract` PASS live now. When R3 wires the two nodes
# (mint-mobile runtime, integrated post-flip: fact_revenu.dart + eclairage.dart land
# and design_lab_app.dart changes — see registry.runtime_regating), the lib inventory
# drifts and validate()/`--contract` will fail on that drift: the expected-RED replay
# BECOMES HISTORICAL at the green flip, attested at the sealed RED_COMMIT, never a
# live proof past it. The STRUCTURAL constants below (ANCHOR, EXPECTED_*_SHA256,
# EXPECTED_TEST_NAMES, subgates) remain the sealed reference the green-gate reads;
# the LIVE structural proof past the flip is the green-gate guard's `--contract`.

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY = Path("product/mint_next/batch21/runtime-gates.yaml")
FACT_REVENU_SCOPE = Path("product/mint_next/batch21/fact_revenu-scope.yaml")
ECLAIRAGE_SCOPE = Path("product/mint_next/batch21/eclairage-scope.yaml")
COPY = Path("product/mint_next/batch21/r3-six-locale-copy.yaml")
FIXTURES = Path("product/mint_next/batch21/r3-engine-fixtures.yaml")
TEST = Path(
    "product/mint_next/batch7/design_lab/test/design_lab_batch21_r3_test.dart"
)
# The R3 test reuses the batch20 commune fixture for compile (the shared green path
# to the fact_lieu boundary); it is not an R3 authority artifact but it is a sealed
# compile input, so its digest is pinned for the isolated RED run.
FIXTURE = Path(
    "product/mint_next/batch7/design_lab/test/batch20_commune_fixture.g.dart"
)
PUBSPEC = Path("product/mint_next/batch7/design_lab/pubspec.yaml")
PUBSPEC_LOCK = Path("product/mint_next/batch7/design_lab/pubspec.lock")
LIB_ROOT = Path("product/mint_next/batch7/design_lab/lib")
L10N_CONFIG = Path("product/mint_next/batch7/design_lab/l10n.yaml")
ASSETS_ROOT = Path("product/mint_next/batch7/design_lab/assets")

# regle13 lesson (d): ANCHOR is the parent of the RED_COMMIT that authors the sealed
# RED files (RED_COMMIT^). It is the batch21 content commit (the two scopes, the
# six-locale copy, the engine fixtures) — the frozen R3 contract validated by Julien.
# The RED-scope diff ANCHOR..candidate_end must touch only ALLOWED_DIFF_PATHS.
# test_..._red_guard.py asserts ANCHOR == RED_COMMIT^.
ANCHOR = "b67a4a87d772706ed51717802d2b0a13f6f3ba67"

EXPECTED_FACT_REVENU_SCOPE_SHA256 = "7a7b02925833c1a7604513fb7f426aa137596dc0e65b7e3af37824b36ddd1681"
EXPECTED_ECLAIRAGE_SCOPE_SHA256 = "e8903173a5fb9572271a5fb3f0e9f9cfd5c56b790eb22567a683af5fe77ff3dc"
EXPECTED_COPY_SHA256 = "ae6d8c9d01b7cec2bd67a31ba7d2d20c2c20aa9528f631e1e5adad4d6b3c5bf6"
EXPECTED_FIXTURES_SHA256 = "255f587bd8a9d2904a079f32871c8815cad345b120b297b7b210df79008f2aa3"
EXPECTED_TEST_SHA256 = "17528fa4714383d6bb95ee05f71cfa003436a1ad17f64b493c3efc6036da44c7"
EXPECTED_FIXTURE_SHA256 = "25b9adad279215b54d67d924f9ea5fb754e97b5dae7746f30acf26e635f38700"
EXPECTED_PUBSPEC_SHA256 = "0b83bf36a5ee2242becbd0fb601235f0c3b2942813207552a03957aaf1569326"
EXPECTED_PUBSPEC_LOCK_SHA256 = "6d7f501ae44e385c80d3726c6a25d830d04d3acf0a7456c6129a293f97f885a1"
# PRE-runtime-R3 inventory: R1 canton + R2 fact_lieu runtimes + shared infra, and NO
# fact_revenu.dart / eclairage.dart. This proves the R3 runtime is NOT implemented.
EXPECTED_LIB_SOURCE_SHA256 = {
    "canton_r1.dart": "928297a39bcb50466df1460f730b2700287f8c93ec6504b0adfb62faadbe1161",
    "canton_r1_catalog.g.dart": "f8444b10283d4dc600feb695c19850963b044e67cb3a4766dab9f2c69d40781d",
    "design_lab_app.dart": "80386e09caf84278d3dc25e992daaa578b61934667f62c6b77cde9cce0401565",
    "fact_lieu.dart": "43f961adc34d28fb712bd9cc4aedcba03944e98890f798a6d69dd3affc82e43a",
    "fact_lieu_catalog.g.dart": "5f7e4003a701205ffc74e9c9679a8f56ce44f41c65ba292e3e7721902ae19ba8",
    "l10n/app_de.arb": "7f283d427787d7bd23138433128c7adc2653906b780e48df8fba668a8564d8ad",
    "l10n/app_en.arb": "59b383b51a9808e7e5514b77d7db55e232f12793f6f91e6f1ce1ae676e07de61",
    "l10n/app_es.arb": "1f8130fee1785858cd878acc768bc8b7a6e92760babbdf63e5ed6b14e41b8dd0",
    "l10n/app_fr.arb": "f37b21af04584bcac05cc932f30b4311628059b263ab76807b496fd9cfbf05a4",
    "l10n/app_it.arb": "01e53567f90955a8828d73355cb92e937dfdd8da50f7af2153ffc639356e36a7",
    "l10n/app_pt.arb": "b44a6f641f21c7300b7dfee4eeb91157ba67fd28487b65e5e885167963a0f462",
    "l10n/generated/mint_next_localizations.dart": "4fb82bcbeb91bfc814d8e773615cf972933b8810749271928ece466034056a13",
    "l10n/generated/mint_next_localizations_de.dart": "950543ea668b2370bd260d362508978a7443b6f5ca527adea8e3f708d01dc45e",
    "l10n/generated/mint_next_localizations_en.dart": "79c5382c4f1832e19ad78bd99223ac60f32c7f53475b381392e6b13303b48998",
    "l10n/generated/mint_next_localizations_es.dart": "e55a7388fa3528c1f4b45fb431ff91c6b8a737b051781cfa3e57b7f3842e4f99",
    "l10n/generated/mint_next_localizations_fr.dart": "d8453505d2b796f9b0e4d53b690b465e7b3b9cd3671dc2f6483937900440f639",
    "l10n/generated/mint_next_localizations_it.dart": "28f997c26dc66796b999aabe23aa8dc67aea440c85c5f45db2854e184e641e95",
    "l10n/generated/mint_next_localizations_pt.dart": "0873ec7c8617e7b84667b0d3ae47e0bca8df86eab296849a84e839279e797370",
    "main.dart": "5c8b1681e8997acde204ff7049204fb55aa9829d98c81dd065202992c85efd24",
    "multi_provider_amount_draft.dart": "6ec168f74f21d56703eb37498c3a5ac86a13d1911b01e1296832144d2849e6c7",
    "multi_provider_amount_editor.dart": "3f2bf5c29e678bc4a0dd8a0d7fba6365a4d0fd751ea9f93f548804a01019f145",
    "multi_provider_casefold_data.dart": "9acee5029f8b19b02c2fc87cc133a199efaf5aa8c9c5226f7ceaca870d5f2115",
    "multi_provider_default_ignorable_data.dart": "0f8bb0b187d94f0c5cfb56e1735f220541c5ed7a9238917a66c92aec799bec66",
    "multi_provider_label.dart": "f39f18d582dcec006422631710f1168d3fd582da1dc688bf330ca0f8c56757ac",
    "ordinary_chf_amount.dart": "43c9850e89d0696f98d11c1b6cdd295ab48aeb480149b8d5e60116fccf4b55be",
    "provider_label.dart": "06f3714e147660539e6eed40898f9f691a77b7fdaa50f7ca6ad7a44d36c3188a",
}
EXPECTED_AUX_INPUT_SHA256 = {
    "l10n.yaml": "0879c4e81347d78e3551434c75ad282aa818efe28ede77d63326dd8b8d4201be",
    "assets/fonts/Gambarino-Regular.otf": "3cfc8143b820d4e9e5970748cf6189d0624aeb1f8c5a0138c2c82bbb9b50efdf",
    "assets/fonts/LICENSE-GAMBARINO.txt": "c2fa18da766a12ef7a1750bc58268048ec01744669e99061494995ea93320e01",
    "assets/fonts/LICENSE-SUPREME.txt": "716d23ed97562988d3436b36c9a2f6a3876be064bafcebceea29b0a135768e03",
    "assets/fonts/Supreme-Bold.otf": "00ebce7fae218b2e28df0581652749e9cbc1d4a6a4221780541532362471d89a",
    "assets/fonts/Supreme-Medium.otf": "4771fa1237212a3eddb060814b2d721e47a79b9b3bf58451ac1b98c48dce58f9",
    "assets/fonts/Supreme-Regular.otf": "00410913847ad5e731e49da556a0c541aacfae84e6c998c5a3a6b4fca3b18ee4",
}
EXPECTED_ORDER = [
    "R3", "R4a_safe_exit",
    "R4b_lifecycle_generation_and_privacy",
    "R4c_six_locale_accessibility_and_compact",
    "R4d_cross_step_integration", "R4", "runtime_global",
]
EXPECTED_TEST_NAMES = {
    "R3_01 the shared entry path reaches the fact_lieu boundary before the R3 fact_revenu runtime",
    "R3_02 fact_revenu shows six taxable income band cards none preselected and no wheel or keyboard",
    "R3_03 fact_revenu arrival focuses the heading not a raised keyboard and the question carries the meaning without a body",
    "R3_04 selecting a taxable income band announces the selection summary and marks the band",
    "R3_05 the revenu imposable glossary sheet opens focus trapped and restores to the anchor",
    "R3_06 fact_revenu error no selection is announced and continue never routes in r3",
    "R3_07 eclairage nominal shows the mechanism a low to high range four hypotheses and the disclaimer never a single number",
    "R3_08 each eclairage hypothesis row is a named editable control with a refine affordance",
    "R3_09 eclairage precision refined tightens the range but never collapses it to a single number",
    "R3_10 eclairage pending missing income shows no number and eclairage low income floor shows the honest note",
    "R3_11 eclairage non_applicable source shows no chf amount under the binary gate",
    "R3_12 the deduction glossary sheet opens focus trapped and restored",
    "R3_13 compact 320x700 text scale two shows the eclairage mechanism range and disclaimer without overflow",
    "R3_14 registry keeps R3 after R2 before R4 and excludes later evidence",
}
EXPECTED_FAILED_NAMES = EXPECTED_TEST_NAMES - {
    "R3_01 the shared entry path reaches the fact_lieu boundary before the R3 fact_revenu runtime",
    "R3_14 registry keeps R3 after R2 before R4 and excludes later evidence",
}
EXPECTED_RED_SENTINELS = {
    name: name.split(" ", 1)[0]
    for name in EXPECTED_FAILED_NAMES
}
ALLOWED_DIFF_PATHS = {
    str(REGISTRY), str(TEST),
    "tools/checks/mint_next_batch21_r3_red_guard.py",
    "tools/checks/tests/test_mint_next_batch21_r3_red_guard.py",
}
EXPECTED_TOP_KEYS = {
    "schema_version", "status", "batch", "authority", "ordered_gates",
    "gates", "runtime_regating", "deferred_integration", "forbidden_claims",
}
EXPECTED_FORBIDDEN_CLAIMS = [
    "runtime_implemented", "runtime_accepted", "user_validated", "production_ready"
]
EXPECTED_BLOCKED_GATES = {
    "R4a_safe_exit": "blocked_by_R3",
    "R4b_lifecycle_generation_and_privacy": "blocked_by_R4a",
    "R4c_six_locale_accessibility_and_compact": "blocked_by_R4b",
    "R4d_cross_step_integration": "blocked_by_R4c",
    "R4": "blocked_by_R4d",
    "runtime_global": "blocked_by_R4",
}
EXPECTED_SUBGATES = {
    "R3a_fact_revenu_taxable_income_band": ["R3_02", "R3_03", "R3_04", "R3_05", "R3_06"],
    "R3b_eclairage_payoff_range_and_hypotheses": [
        "R3_07", "R3_08", "R3_09", "R3_10", "R3_11", "R3_12", "R3_13",
    ],
}
# regle13 lesson (c): the pin R2 was superseded by, never re-attested live.
EXPECTED_SUPERSEDES = {
    "r2_green_gate": "product/mint_next/batch20/r2-green-gate.yaml",
    "r2_green_accepted_commit": "816d8f260",
    "no_live_reattestation_of_r2": True,
}
EXPECTED_RUNTIME_REGATING = {
    "scope_owner": "batch21-r3-runtime",
    # aligned to what the runtime actually built (eclairage_impot_3a.dart +
    # r3_eclairage_catalog.g.dart), not the earlier eclairage.dart guess.
    "regated_files": [
        "product/mint_next/batch7/design_lab/lib/fact_revenu.dart",
        "product/mint_next/batch7/design_lab/lib/eclairage_impot_3a.dart",
        "product/mint_next/batch7/design_lab/lib/r3_eclairage_catalog.g.dart",
        "product/mint_next/batch7/design_lab/lib/design_lab_app.dart",
    ],
    "lib_inventory_seal": "deferred_to_implementation_under_this_gate",
}
# RIDER 1+2 — the deferred integration governance unit sealed into the registry.
EXPECTED_DEFERRED_INTEGRATION = {
    "status": "declared_next_governance_unit_after_r3_runtime_lands",
    "green_flips_here_not_at_screen_flip": True,
    "scope": [
        "wire_journey_fact_lieu_continue_to_fact_revenu_then_fact_revenu_continue_to_eclairage_then_next_action",
        "supersede_batch20_r2_fact_lieu_outbound_edge_obligation_and_re_gate_it",
        "remove_runtime_inline_situation_toggle_situation_is_display_only",
        "re_gate_sibling_screens_touched_by_the_new_wiring",
    ],
    "interim_evidence": {
        "runtime_dev_tests": [
            "product/mint_next/batch7/design_lab/test/dev_eclairage_r3_test.dart",
            "product/mint_next/batch7/design_lab/test/dev_fact_revenu_r3_test.dart",
        ],
        "reached_via": "MintNextDesignLabApp.batch21Harness",
        "not_a_silent_gray_zone": True,
    },
    "green_gate_semantics": {
        "acceptance_means": "r3_runtime_implemented_AND_journey_wired",
        "release_attestation_replays": "this_linear_integration_test_passing_within_the_wired_screens",
        "no_pin_may_attest_runtime_only_without_wiring": True,
    },
}
LOCALES = ["fr", "en", "de", "it", "es", "pt"]
# The R3 six-locale copy required-placeholder contract (copy.required_placeholders).
EXPECTED_PLACEHOLDERS = {
    "taxYear", "band", "low", "high", "versement", "commune", "canton",
}
# mandate step 1 — R3 copy semantics. Concept PRESENCE and jargon/claim ABSENCE,
# never a verbatim phrase to recopy. The copy stays free to be said out loud to a
# friend; the guard only asserts the SENSE survived (LSFin-safe, honest) and the
# forbidden classes (promise words, marginal-rate jargon, locality claims) did not
# reappear.
#
# LSFin promise/superlative words. Word-bounded, applied to every locale (cognate
# across the six). The authored copy is LSFin-safe, so none of these appear; the
# guard prevents their reintroduction (bug #1061 lineage — « Économise X » abolished).
COPY_BANNED_LSFIN = [
    r"garanti", r"garantie", r"garantit", r"garantiert", r"guarantee",
    r"garantizad", r"garant[ií]a", r"garantid", r"garantit[oa]", r"garanzia",
    r"sans risque", r"risikolos", r"risikofrei", r"risk-?free", r"no risk",
    r"sin riesgo", r"sem risco", r"senza rischio",
    r"\boptimal", r"\bottimale\b", r"\b[oó]timo\b",
    r"\bmeilleur", r"\bbest\b", r"\bbeste\b", r"\bmejor\b", r"\bmigliore\b", r"\bmelhor\b",
    r"\bparfait", r"\bperfect", r"\bperfekt", r"\bperfect[oa]\b", r"\bperfett[oa]\b", r"\bperfeit[oa]\b",
]
# Marginal-rate / coefficient jargon must never surface on this francs-not-a-rate
# screen (semantic_assertion: marginal_rate_jargon_is_NOT_surfaced_on_screen).
COPY_FORBIDDEN_JARGON = [
    "taux marginal", "marginal rate", "grenzsteuersatz", "aliquota marginale",
    "tipo marginal", "taxa marginal", "coefficient", "steuerfuss",
]
# AUCUNE claim de localité (« reste sur ton téléphone » ABOLI, product decision
# 2026-08-05). No datum on these two screens is device-only, so any on-device /
# device-retention claim is a resurrected false privacy line. Device/phone nouns
# have no legitimate use in taxable-income + 3a payoff copy, so their mere presence
# is the signal. Word-bounded, applied to every locale.
COPY_FORBIDDEN_LOCALITY = [
    r"t[eé]l[eé]phone", r"\bphone\b", r"appareil", r"\bdevice\b", r"on-?device",
    r"ger[aä]t", r"\btelefon", r"dispositivo", r"telem[oó]vel", r"cellulare",
    r"\bm[oó]vil\b",
]
# no-promise + disclaimer on eclairage. The eclairage_disclaimer must convey BOTH
# « estimate » and « not (tax) advice » per locale; dropping the negation turns the
# line into a promise. Accented tokens matched case-insensitively as substrings.
COPY_DISCLAIMER_ESTIMATE = {
    "fr": ["estimation"], "en": ["estimate"], "de": ["schätzung", "schatzung"],
    "it": ["stima"], "es": ["estimación", "estimacion"], "pt": ["estimativa"],
}
COPY_DISCLAIMER_NOT_ADVICE = {
    "fr": ["pas un conseil"], "en": ["not tax advice", "not advice"],
    "de": ["keine steuerberatung", "keine beratung"],
    "it": ["non una consulenza", "non e una consulenza", "non è una consulenza"],
    "es": ["no un asesoramiento", "no es un asesoramiento"],
    "pt": ["não um aconselhamento", "nao um aconselhamento", "não é um aconselhamento"],
}


class GuardFailure(RuntimeError):
    pass


class UniqueLoader(yaml.SafeLoader):
    pass


def _unique_mapping(loader: yaml.Loader, node: yaml.MappingNode, deep: bool = False) -> dict:
    result: dict = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise GuardFailure(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardFailure(message)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load(path: Path) -> dict:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueLoader)


def _placeholders(value: str) -> set[str]:
    return set(re.findall(r"\{(\w+)\}", value))


def _validate_copy_semantics(root: Path) -> None:
    """mandate step 1: per-locale semantics of the R3 six-locale copy."""
    copy = _load(root / COPY)
    _require(copy.get("locales") == LOCALES, "copy locale set or order drifted")
    _require(
        set(copy.get("required_placeholders", [])) == EXPECTED_PLACEHOLDERS,
        "copy required-placeholder contract drifted",
    )
    receipt = copy.get("semantic_receipt", {})
    _require(isinstance(receipt, dict), "copy semantic_receipt missing")
    required_keys = (
        set(receipt.get("required_keys_fact_revenu", []) or [])
        | set(receipt.get("required_keys_eclairage", []) or [])
    )
    _require(
        len(required_keys) >= 40 and "eclairage_disclaimer" in required_keys
        and "eclairage_amount" in required_keys,
        "copy required-key receipt drifted",
    )
    payloads = copy.get("copy", {})
    _require(set(payloads) == set(LOCALES), "copy per-locale payload set drifted")
    seen: dict[str, str] = {}
    placeholders_per_key: dict[str, set[str]] = {}
    used_placeholders: set[str] = set()
    for locale in LOCALES:
        block = payloads[locale]
        _require(isinstance(block, dict), f"copy locale not a map: {locale}")
        _require(
            set(block) == required_keys,
            f"copy [{locale}] key set drifted (a required key dropped or a stray key added)",
        )
        blob = "\n".join(str(value) for value in block.values())
        low = blob.lower()
        for token in COPY_BANNED_LSFIN:
            _require(
                re.search(token, low) is None,
                f"copy [{locale}] reintroduces an LSFin promise/superlative term: {token}",
            )
        for token in COPY_FORBIDDEN_JARGON:
            _require(
                token not in low,
                f"copy [{locale}] surfaces marginal-rate/coefficient jargon: {token}",
            )
        for token in COPY_FORBIDDEN_LOCALITY:
            _require(
                re.search(token, low) is None,
                f"copy [{locale}] reintroduces a locality/on-device claim: {token}",
            )

        def _has_any(field: str, variants: list[str]) -> bool:
            low_field = field.lower()
            return any(variant in low_field for variant in variants)

        # no-promise: the eclairage amount is a low→high RANGE, never a single number.
        amount = str(block["eclairage_amount"])
        _require(
            "{low}" in amount and "{high}" in amount,
            f"copy [{locale}] eclairage amount must be a low-to-high range, never a single number",
        )
        # ANCHOR' amendment: the open-top band (gt150) is anchored LOW only — it
        # carries {low} and NEVER a fabricated high bound (« {low} CHF et plus »).
        amount_open = str(block["eclairage_amount_open"])
        _require(
            "{low}" in amount_open and "{high}" not in amount_open,
            f"copy [{locale}] eclairage open band must be anchored low with no fabricated high bound",
        )
        # disclaimer: estimate AND not-advice, both present (LSFin no-promise).
        disclaimer = str(block["eclairage_disclaimer"])
        _require(
            _has_any(disclaimer, COPY_DISCLAIMER_ESTIMATE[locale]),
            f"copy [{locale}] eclairage disclaimer must frame the payoff as an estimate",
        )
        _require(
            _has_any(disclaimer, COPY_DISCLAIMER_NOT_ADVICE[locale]),
            f"copy [{locale}] eclairage disclaimer must say it is not tax advice (no-promise negation)",
        )
        for key, value in block.items():
            marks = _placeholders(str(value))
            used_placeholders |= marks
            placeholders_per_key.setdefault(key, marks)
            _require(
                placeholders_per_key[key] == marks,
                f"copy [{locale}] placeholder parity drifted for {key}",
            )
        # identical full-locale payloads are forbidden (no lazy fallback locale).
        key = json.dumps(block, sort_keys=True, ensure_ascii=False)
        _require(key not in seen, f"copy [{locale}] is byte-identical to [{seen.get(key)}]")
        seen[key] = locale
    _require(
        used_placeholders <= EXPECTED_PLACEHOLDERS,
        f"copy uses an undeclared placeholder: {sorted(used_placeholders - EXPECTED_PLACEHOLDERS)}",
    )


def _validate_joint_satisfiability(test_source: str) -> None:
    """The obligations must be mutually satisfiable under ONE green (joint
    satisfiability, not obligation-by-obligation). The class of defect this closes
    (it let the R3_06/R3_10 pair through the first review): two obligations driving
    the same terminal gesture from the same reached state but asserting mutually
    exclusive outcomes. Encoded as the contract's routing rule —
    fact_revenu.continue NEVER routes without a committed band (it shows
    error_no_selection and stays; eclairage-scope continue.never_routes_in_r3) — so
    any obligation that taps continue and then asserts an eclairage state MUST first
    commit a band (choice:fact_revenu.* or _reachEclairage, which commits one).
    Otherwise it contradicts the error_no_selection obligation and cannot be green
    under one runtime. Reusable pattern-level guard for this and later batches.
    """
    # strip // line comments first, so a token quoted inside a comment can neither
    # bypass the guard (a commented choice:fact_revenu.*) nor false-trigger it. The
    # sha pin is the primary lock; this keeps the structural check from being fooled
    # by prose. (The design-lab tests use // comments only, no /* */ blocks.)
    stripped = "\n".join(re.sub(r"//.*$", "", line) for line in test_source.splitlines())
    blocks = re.split(r"\btestWidgets\(", stripped)
    for block in blocks[1:]:
        match = re.search(r"""['"]([^'"]+)['"]""", block)
        name = match.group(1) if match else "<unknown>"
        taps_continue = "action:fact_revenu.continue" in block
        commits_band = ("choice:fact_revenu." in block) or ("_reachEclairage(" in block)
        routes_to_eclairage = (
            "node:eclairage_impot_3a" in block or "status:eclairage." in block
        )
        _require(
            not (taps_continue and routes_to_eclairage and not commits_band),
            "joint-satisfiability: obligation taps fact_revenu.continue with no committed "
            "band yet expects an eclairage state — contradicts the error_no_selection "
            f"obligation (continue never routes without a band): {name}",
        )


def _validate_diff_boundary(root: Path) -> None:
    try:
        candidate_end = subprocess.run(
            ["git", "log", "-1", "--format=%H", "HEAD", "--", *sorted(ALLOWED_DIFF_PATHS)],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.strip()
        _require(re.fullmatch(r"[0-9a-f]{40}", candidate_end) is not None, "cannot locate Batch21 RED candidate commit")
        committed = subprocess.run(
            ["git", "diff", "--name-only", f"{ANCHOR}..{candidate_end}"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect Batch21 git boundary") from exc
    changed = {
        path for path in committed
        if not path.startswith(".planning/journeys/path-owners/")
    }
    unexpected = changed - ALLOWED_DIFF_PATHS
    _require(not unexpected, f"Batch21 RED scope changed forbidden paths: {sorted(unexpected)}")


def validate(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    for relative in (
        REGISTRY, FACT_REVENU_SCOPE, ECLAIRAGE_SCOPE, COPY, FIXTURES, TEST, FIXTURE,
        PUBSPEC, PUBSPEC_LOCK, L10N_CONFIG,
    ):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not a regular file: {relative}")
    registry = _load(root / REGISTRY)
    _require(set(registry) == EXPECTED_TOP_KEYS, "registry top-level schema drifted")
    _require(registry.get("schema_version") == 1 and registry.get("batch") == 21, "registry identity drifted")
    _require(_sha(root / FACT_REVENU_SCOPE) == EXPECTED_FACT_REVENU_SCOPE_SHA256, "accepted fact_revenu scope digest drifted")
    _require(_sha(root / ECLAIRAGE_SCOPE) == EXPECTED_ECLAIRAGE_SCOPE_SHA256, "accepted eclairage scope digest drifted")
    _require(_sha(root / FIXTURES) == EXPECTED_FIXTURES_SHA256, "accepted engine fixtures digest drifted")
    _require(
        registry.get("status") == "candidate_expected_red_evidence_runtime_not_implemented",
        "registry lifecycle or runtime claim drifted",
    )
    _require(registry.get("ordered_gates") == EXPECTED_ORDER, "gate order drifted")
    authority = registry.get("authority", {})
    _require(
        set(authority) == {
            "immutable_scopes", "immutable_scope_sha256", "immutable_copy",
            "immutable_copy_sha256", "immutable_fixtures", "immutable_fixtures_sha256",
            "runtime_surface", "product_promotion", "supersedes",
        },
        "registry authority schema drifted",
    )
    _require(
        authority.get("immutable_scopes") == {
            "fact_revenu": str(FACT_REVENU_SCOPE),
            "eclairage": str(ECLAIRAGE_SCOPE),
        },
        "scope authority drifted",
    )
    _require(
        authority.get("immutable_scope_sha256") == {
            "fact_revenu": EXPECTED_FACT_REVENU_SCOPE_SHA256,
            "eclairage": EXPECTED_ECLAIRAGE_SCOPE_SHA256,
        },
        "scope binding drifted",
    )
    _require(authority.get("immutable_copy") == str(COPY), "copy authority drifted")
    _require(authority.get("immutable_copy_sha256") == EXPECTED_COPY_SHA256, "copy binding drifted")
    _require(authority.get("immutable_fixtures") == str(FIXTURES), "fixtures authority drifted")
    _require(authority.get("immutable_fixtures_sha256") == EXPECTED_FIXTURES_SHA256, "fixtures binding drifted")
    _require(authority.get("runtime_surface") == "hidden_design_lab_only", "runtime surface widened")
    _require(authority.get("product_promotion") == "forbidden", "product promotion widened")
    _require(authority.get("supersedes") == EXPECTED_SUPERSEDES, "R2 supersession pin drifted or re-attested")
    _require(registry.get("runtime_regating") == EXPECTED_RUNTIME_REGATING, "runtime regating scope drifted")
    _require(registry.get("deferred_integration") == EXPECTED_DEFERRED_INTEGRATION, "deferred integration governance unit drifted")
    _require(set(registry.get("gates", {})) == set(EXPECTED_ORDER), "registry gate inventory drifted")
    for gate, state in EXPECTED_BLOCKED_GATES.items():
        _require(registry["gates"][gate] == {"state": state}, f"blocked gate widened: {gate}")
    r3 = registry.get("gates", {}).get("R3", {})
    _require(
        set(r3) == {
            "state", "runtime_implemented", "runtime_accepted", "next_gate",
            "later_gate_evidence_counts_for_R3", "test_file",
            "command", "working_directory", "expected_exit_code",
            "expected_summary", "candidate_binding", "subgates",
            "obligation_test_names", "expected_red_sentinels",
        },
        "R3 registry schema drifted",
    )
    _require(r3.get("state") == "expected_red", "R3 is not expected RED")
    _require(r3.get("runtime_implemented") is False, "R3 claims implementation")
    _require(r3.get("runtime_accepted") is False, "R3 claims acceptance")
    _require(r3.get("next_gate") == "R4a_safe_exit", "R3 next gate drifted")
    _require(r3.get("later_gate_evidence_counts_for_R3") is False, "later evidence can falsely accept R3")
    _require(r3.get("test_file") == str(TEST), "R3 test path drifted")
    _require(
        r3.get("command") == [
            "flutter", "test", "test/design_lab_batch21_r3_test.dart",
            "--machine", "--no-pub",
        ],
        "R3 command is not exact and targeted",
    )
    _require(r3.get("working_directory") == "product/mint_next/batch7/design_lab", "R3 working directory drifted")
    _require(r3.get("expected_exit_code") == 1, "R3 expected exit drifted")
    _require(r3.get("expected_summary") == {"passed": 2, "failed": 12, "load_or_harness_errors": 0}, "R3 expected summary drifted")
    obligation_map = r3.get("obligation_test_names", {})
    expected_ids = {f"R3_{index:02d}" for index in range(1, 15)}
    _require(set(obligation_map) == expected_ids, "R3 obligation coverage drifted")
    mapped_names = set()
    for value in obligation_map.values():
        mapped_names.update(value if isinstance(value, list) else [value])
    _require(mapped_names == EXPECTED_TEST_NAMES, "R3 named-test inventory drifted")
    _require(r3.get("expected_red_sentinels") == EXPECTED_RED_SENTINELS, "R3 RED sentinel binding drifted")
    subgates = r3.get("subgates", {})
    _require(subgates == EXPECTED_SUBGATES, "R3 subgate coverage drifted")
    covered = {gate for ids in subgates.values() for gate in ids}
    _require(covered == (expected_ids - {"R3_01", "R3_14"}), "R3 subgates must cover every behavioural obligation once")
    _require(registry.get("forbidden_claims") == EXPECTED_FORBIDDEN_CLAIMS, "forbidden claims drifted")

    _require(
        r3.get("candidate_binding") == {"test_sha256": EXPECTED_TEST_SHA256},
        "R3 candidate source binding drifted",
    )
    _require(_sha(root / TEST) == EXPECTED_TEST_SHA256, "R3 test digest drifted")
    _require(_sha(root / FIXTURE) == EXPECTED_FIXTURE_SHA256, "R3 compile fixture digest drifted")
    _require(_sha(root / COPY) == EXPECTED_COPY_SHA256, "accepted copy digest drifted")
    _validate_copy_semantics(root)

    test_source = (root / TEST).read_text(encoding="utf-8")
    for name in EXPECTED_TEST_NAMES:
        _require(test_source.count(name) == 1, f"R3 test missing or duplicated: {name}")
    _require("MintNextDesignLabApp(" in test_source, "R3 tests do not drive the real app")
    _require("node:fact_revenu" in test_source, "R3 tests do not assert the absent fact_revenu surface")
    _require("node:eclairage_impot_3a" in test_source, "R3 tests do not assert the absent eclairage payoff surface")
    _require("node:fact_lieu" in test_source, "R3 tests do not reach the attested R2 fact_lieu boundary")
    # regle13 lesson (a) simulated-green smoke: no R1_12-style process-global
    # mutation (debugPrint reassignment) that would leave a latent teardown defect
    # when the harness runs green.
    _require(
        re.search(r"debugPrint\s*=[^=]", test_source) is None,
        "R3 test reassigns debugPrint (R1_12-style latent teardown risk)",
    )
    _validate_joint_satisfiability(test_source)

    _require(_sha(root / PUBSPEC) == EXPECTED_PUBSPEC_SHA256, "reviewed pubspec digest drifted")
    _require(_sha(root / PUBSPEC_LOCK) == EXPECTED_PUBSPEC_LOCK_SHA256, "reviewed pubspec lock digest drifted")
    pubspec = _load(root / PUBSPEC)
    _require(
        set(pubspec.get("dependencies", {}))
        == {"characters", "flutter", "flutter_localizations", "intl", "unorm_dart"},
        "Design Lab dependency capability surface widened",
    )
    for tree in (root / LIB_ROOT, root / ASSETS_ROOT):
        _require(tree.is_dir() and not tree.is_symlink(), f"reviewed RED input tree is invalid: {tree.relative_to(root)}")
        nodes = list(tree.rglob("*"))
        _require(
            all(not node.is_symlink() and (node.is_file() or node.is_dir()) for node in nodes),
            f"reviewed RED input tree contains symlink or special entry: {tree.relative_to(root)}",
        )
    sources = {
        path.relative_to(root / LIB_ROOT).as_posix(): _sha(path)
        for path in sorted((root / LIB_ROOT).rglob("*"))
        if path.is_file()
    }
    # This inventory proves the R3 runtime is NOT implemented: the lib carries only
    # the attested R1 canton + R2 fact_lieu runtimes and shared infra — no
    # fact_revenu.dart / eclairage.dart.
    _require(
        sources == EXPECTED_LIB_SOURCE_SHA256,
        "reviewed RED runtime source inventory or digest drifted (R3 runtime must remain unimplemented)",
    )
    design_lab = PUBSPEC.parent
    auxiliary = {"l10n.yaml": _sha(root / L10N_CONFIG)}
    auxiliary.update({
        path.relative_to(root / design_lab).as_posix(): _sha(path)
        for path in sorted((root / ASSETS_ROOT).rglob("*"))
        if path.is_file()
    })
    _require(
        auxiliary == EXPECTED_AUX_INPUT_SHA256,
        "reviewed RED auxiliary input inventory or digest drifted",
    )
    if check_git:
        _validate_diff_boundary(root)


def _run_candidate_command(root: Path, r3: dict) -> subprocess.CompletedProcess[str]:
    design_lab = PUBSPEC.parent
    with tempfile.TemporaryDirectory(prefix="mint-b21-r3-") as directory:
        isolated_root = Path(directory)
        isolated_lab = isolated_root / design_lab
        isolated_lab.mkdir(parents=True)
        for relative in (PUBSPEC, PUBSPEC_LOCK):
            target = isolated_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        shutil.copy2(root / design_lab / "l10n.yaml", isolated_lab / "l10n.yaml")
        shutil.copytree(root / LIB_ROOT, isolated_root / LIB_ROOT)
        shutil.copytree(root / design_lab / "assets", isolated_lab / "assets")
        for relative in (TEST, FIXTURE, REGISTRY):
            target = isolated_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        resolved = subprocess.run(
            ["flutter", "pub", "get", "--offline", "--enforce-lockfile"],
            cwd=isolated_lab, capture_output=True, text=True, timeout=120,
        )
        _require(resolved.returncode == 0, "R3 isolated dependency resolution failed")
        return subprocess.run(
            r3["command"], cwd=isolated_lab, capture_output=True, text=True, timeout=180,
        )


def run_expected_red(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    validate(root, check_git=check_git)
    registry = _load(root / REGISTRY)
    r3 = registry["gates"]["R3"]
    try:
        completed = _run_candidate_command(root, r3)
    except subprocess.TimeoutExpired as exc:
        raise GuardFailure("R3 RED command timed out") from exc
    _require(not completed.stderr.strip(), "R3 runner emitted stderr")
    _require(completed.returncode == 1, f"R3 RED command exit was {completed.returncode}, expected 1")
    starts: dict[int, str] = {}
    results: dict[str, str] = {}
    diagnostics: dict[int, list[str]] = {}
    load_result: str | None = None
    done_events: list[dict] = []
    error_ids: list[int] = []
    test_done_ids: list[int] = []
    passive_event_types = {"start", "suite", "allSuites", "group"}
    for line in completed.stdout.splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            raise GuardFailure("R3 runner emitted non-JSON stdout")
        if isinstance(event, list):
            _require(
                len(event) == 1
                and isinstance(event[0], dict)
                and event[0].get("event") == "test.startedProcess",
                "R3 runner emitted unknown list event",
            )
            continue
        _require(isinstance(event, dict), "R3 runner emitted non-object event")
        etype = event.get("type")
        if etype == "testStart":
            test = event["test"]
            _require(test["id"] not in starts, "duplicate R3 testStart id")
            starts[test["id"]] = test["name"]
        elif etype == "print":
            _require(event["testID"] in starts, "print without testStart")
            diagnostics.setdefault(event["testID"], []).append(event.get("message", ""))
        elif etype == "error":
            _require(event["testID"] in starts, "error without testStart")
            error_ids.append(event["testID"])
            diagnostics.setdefault(event["testID"], []).append(
                (event.get("error", "") or "") + "\n" + (event.get("stackTrace", "") or "")
            )
        elif etype == "testDone":
            _require(event["testID"] in starts, "testDone without testStart")
            _require(event["testID"] not in test_done_ids, "duplicate testDone id")
            test_done_ids.append(event["testID"])
            name = starts.get(event["testID"], "<unknown>")
            if name.startswith("loading "):
                load_result = event["result"]
            elif not event.get("hidden", False):
                _require(name not in results, "duplicate R3 test execution")
                results[name] = event["result"]
            else:
                _require(False, "unexpected hidden testDone event")
        elif etype == "done":
            done_events.append(event)
        else:
            _require(etype in passive_event_types, f"unknown R3 machine event: {etype}")
    _require(load_result == "success", "R3 test failed to compile or load")
    _require(set(test_done_ids) == set(starts), "R3 testStart/testDone inventory drifted")
    _require(
        len(done_events) == 1
        and set(done_events[0]) == {"success", "type", "time"}
        and done_events[0]["type"] == "done"
        and done_events[0]["success"] is False
        and isinstance(done_events[0]["time"], int),
        "R3 final done event drifted",
    )
    _require(set(results) == EXPECTED_TEST_NAMES, "executed R3 test inventory drifted")
    failed = {name for name, result in results.items() if result == "error"}
    passed = {name for name, result in results.items() if result == "success"}
    _require(failed == EXPECTED_FAILED_NAMES, f"unexpected RED failures: {sorted(failed ^ EXPECTED_FAILED_NAMES)}")
    _require(passed == EXPECTED_TEST_NAMES - EXPECTED_FAILED_NAMES, "R3 positive controls did not pass")
    expected_error_ids = sorted(
        test_id for test_id, full_name in starts.items()
        if full_name in EXPECTED_FAILED_NAMES
    )
    _require(sorted(error_ids) == expected_error_ids, "R3 machine error-event inventory drifted")
    forbidden_diagnostics = (
        "Test timed out", "pumpAndSettle timed out", "NoSuchMethodError",
        "LateInitializationError", "RangeError", "Bad state:",
        "precondition:", "Could not find a generator for route",
    )
    for test_id, full_name in starts.items():
        if full_name not in EXPECTED_FAILED_NAMES:
            continue
        output = "\n".join(diagnostics.get(test_id, []))
        expected_marker = f"[{EXPECTED_RED_SENTINELS[full_name]}]"
        _require("TestFailure" in output and expected_marker in output, f"RED failure is not the exact named behavioural assertion: {full_name}")
        _require(not any(token in output for token in forbidden_diagnostics), f"RED failure is a harness/runtime error: {full_name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", action="store_true", help="skip expected-failing Flutter execution")
    args = parser.parse_args()
    try:
        if args.contract:
            validate()
        else:
            run_expected_red()
    except GuardFailure as exc:
        print(f"BATCH21 R3 RED FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH21 R3 RED PASS: behavioural failures are expected and runtime remains unimplemented")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
