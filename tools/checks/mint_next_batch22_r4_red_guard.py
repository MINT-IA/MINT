#!/usr/bin/env python3
"""Fail closed unless Batch22 R4 (FERMETURE DE LA BOUCLE — scenarios_versement +
fact_etat_civil) is an honest, executable RED contract.

Mirrors tools/checks/mint_next_batch21_r3_red_guard.py. R3 (arc ÉCLAIRAGE) is done
and DELIVERED (wired journey up to eclairage_impot_3a); it is superseded BY PIN
(regle13 lesson c): this guard never re-attests R3 live; it only reads the batch22
registry authority.supersedes pin (r3_green_accepted_commit 0a81c9b60). The R4 arc
closes the loop AFTER the delivered eclairage boundary with two nodes:
scenarios_versement (the « et maintenant ? » scenario spectrum) and fact_etat_civil
(the heaviest sensitivity fact — the civil status). That R4 runtime does NOT exist,
so design_lab_batch22_r4_test.dart drives the attested green 3a arc to the delivered
eclairage payoff and then asserts the absent R4 surface (scenarios via
eclairage.continue, which today never routes; fact_etat_civil via a future refine
affordance on the display-only situation row): 2 pass, 14 named behavioural RED
failures, 0 load/harness errors.
"""

# HISTORICAL-REPLAY NOTICE (batch19/batch20/batch21 pattern, product decision
# 2026-08-05; re-graved for the Vague Groupée fermeture 2026-08-06). This is an
# expected-RED guard: validate()/run_expected_red assert the PRE-runtime state
# (EXPECTED_LIB_SOURCE_SHA256 = the lib WITHOUT the R4 runtime). That state is now in
# the PAST: the R4 runtime is IMPLEMENTED and the fermeture loop is WIRED
# (scenarios_versement.dart + fact_etat_civil.dart + r4_fermeture_catalog.g.dart
# landed; design_lab_app.dart + fact_lieu.dart re-gated — see
# registry.runtime_regating). So validate() and `--contract` FAIL LIVE NOW, BY
# DESIGN, on EXPECTED_LIB_SOURCE_SHA256 (the "reviewed RED runtime source inventory
# or digest drifted" require — the last inventory block of validate(): the live lib
# carries the delivered R4 runtime the frozen inventory omits). The expected-RED
# replay is HISTORICAL, attested at the sealed RED_COMMIT, never a live proof past
# the green flip. deferred_integration below reflects the DELIVERED Vague-Groupée
# state (loop closed; only the married CHIFFRE recompute stays a backend L2 contract
# on dev) and is asserted byte-equal to the registry. The STRUCTURAL constants
# (ANCHOR, EXPECTED_*_SHA256, EXPECTED_TEST_NAMES, subgates) remain the sealed
# reference the green-gate reads; the LIVE structural proof past the flip is the
# green-gate guard's `--contract`.

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
REGISTRY = Path("product/mint_next/batch22/runtime-gates.yaml")
SCENARIOS_SCOPE = Path("product/mint_next/batch22/scenarios_versement-scope.yaml")
ETAT_CIVIL_SCOPE = Path("product/mint_next/batch22/fact_etat_civil-scope.yaml")
COPY = Path("product/mint_next/batch22/r4-six-locale-copy.yaml")
FIXTURES = Path("product/mint_next/batch22/r4-engine-fixtures.yaml")
TEST = Path(
    "product/mint_next/batch7/design_lab/test/design_lab_batch22_r4_test.dart"
)
# The R4 test reuses the batch20 commune fixture for compile (the shared green path
# through the fact_lieu boundary); it is not an R4 authority artifact but it is a
# sealed compile input, so its digest is pinned for the isolated RED run.
FIXTURE = Path(
    "product/mint_next/batch7/design_lab/test/batch20_commune_fixture.g.dart"
)
PUBSPEC = Path("product/mint_next/batch7/design_lab/pubspec.yaml")
PUBSPEC_LOCK = Path("product/mint_next/batch7/design_lab/pubspec.lock")
LIB_ROOT = Path("product/mint_next/batch7/design_lab/lib")
L10N_CONFIG = Path("product/mint_next/batch7/design_lab/l10n.yaml")
ASSETS_ROOT = Path("product/mint_next/batch7/design_lab/assets")

# regle13 lesson (d): ANCHOR is the parent of the RED_COMMIT that authors the sealed
# RED files (RED_COMMIT^). It is the batch22 content commit (the two scopes, the
# six-locale copy, the engine fixtures) — the frozen R4 contract validated by Julien.
# The RED-scope diff ANCHOR..candidate_end must touch only ALLOWED_DIFF_PATHS.
# test_..._red_guard.py asserts ANCHOR == RED_COMMIT^.
ANCHOR = "c8b67214f19e50df66266454800ef38e2f3859a6"

EXPECTED_SCENARIOS_SCOPE_SHA256 = "5d3ebea8de3d0e8c16cbd2f8c10e982d04383655d3d3b8e9a96f44aa34a2c320"
EXPECTED_ETAT_CIVIL_SCOPE_SHA256 = "a3fb33c2d9b0a0ab70d39be6f16c958036b849e1f8f3a2da396fb3a08d1c704e"
EXPECTED_COPY_SHA256 = "889e33bc8f73dc04c0a7b81da455e4b27c7be3b6339947cca7aff0eb89cc0bf2"
EXPECTED_FIXTURES_SHA256 = "ec1b419f1edd102b723b3a96f0bf773330fc94010e68c5f6d4498d86a30c51b2"
EXPECTED_TEST_SHA256 = "42dfbadae42f85a9b48cba6fa875d0331716d837f69180c25020350a90c520cb"
EXPECTED_FIXTURE_SHA256 = "25b9adad279215b54d67d924f9ea5fb754e97b5dae7746f30acf26e635f38700"
EXPECTED_PUBSPEC_SHA256 = "0b83bf36a5ee2242becbd0fb601235f0c3b2942813207552a03957aaf1569326"
EXPECTED_PUBSPEC_LOCK_SHA256 = "6d7f501ae44e385c80d3726c6a25d830d04d3acf0a7456c6129a293f97f885a1"
# PRE-runtime-R4 inventory (HISTORICAL): the frozen lib WITHOUT the R4 runtime.
# fact_lieu.dart is NO LONGER frozen here — the Vague Groupée fermeture re-gated it
# (it gained onCommuneSelected to lift the picked commune LABEL into the éclairage
# payoff), so it moved to EXPECTED_RUNTIME_REGATING.regated_files below. Its
# generated catalog fact_lieu_catalog.g.dart stays frozen (untouched by R4). This
# whole inventory is a HISTORICAL sha snapshot: post-runtime the live lib carries
# the delivered R4 runtime, so validate()/`--contract` fail on it BY DESIGN (see
# the module header). It never lists scenarios_versement.dart / fact_etat_civil.dart.
EXPECTED_LIB_SOURCE_SHA256 = {
    'canton_r1.dart': '928297a39bcb50466df1460f730b2700287f8c93ec6504b0adfb62faadbe1161',
    'canton_r1_catalog.g.dart': 'f8444b10283d4dc600feb695c19850963b044e67cb3a4766dab9f2c69d40781d',
    'design_lab_app.dart': 'ec39dcb8a0e040c53eb8cf01af4c1a1474e0d20d76ee12a1676b5b9dd5deda40',
    'eclairage_impot_3a.dart': '0eace8eec21528a4e3cc999066c79b621bb0a9d842de2a7efa61f7ed8916e0c8',
    'fact_lieu_catalog.g.dart': '5f7e4003a701205ffc74e9c9679a8f56ce44f41c65ba292e3e7721902ae19ba8',
    'fact_revenu.dart': 'f26884f8dff16abb76f34e86baa8b7c861e2f4f6b37bb9f7103ae370e258e344',
    'l10n/app_de.arb': '7f283d427787d7bd23138433128c7adc2653906b780e48df8fba668a8564d8ad',
    'l10n/app_en.arb': '59b383b51a9808e7e5514b77d7db55e232f12793f6f91e6f1ce1ae676e07de61',
    'l10n/app_es.arb': '1f8130fee1785858cd878acc768bc8b7a6e92760babbdf63e5ed6b14e41b8dd0',
    'l10n/app_fr.arb': 'f37b21af04584bcac05cc932f30b4311628059b263ab76807b496fd9cfbf05a4',
    'l10n/app_it.arb': '01e53567f90955a8828d73355cb92e937dfdd8da50f7af2153ffc639356e36a7',
    'l10n/app_pt.arb': 'b44a6f641f21c7300b7dfee4eeb91157ba67fd28487b65e5e885167963a0f462',
    'l10n/generated/mint_next_localizations.dart': '4fb82bcbeb91bfc814d8e773615cf972933b8810749271928ece466034056a13',
    'l10n/generated/mint_next_localizations_de.dart': '950543ea668b2370bd260d362508978a7443b6f5ca527adea8e3f708d01dc45e',
    'l10n/generated/mint_next_localizations_en.dart': '79c5382c4f1832e19ad78bd99223ac60f32c7f53475b381392e6b13303b48998',
    'l10n/generated/mint_next_localizations_es.dart': 'e55a7388fa3528c1f4b45fb431ff91c6b8a737b051781cfa3e57b7f3842e4f99',
    'l10n/generated/mint_next_localizations_fr.dart': 'd8453505d2b796f9b0e4d53b690b465e7b3b9cd3671dc2f6483937900440f639',
    'l10n/generated/mint_next_localizations_it.dart': '28f997c26dc66796b999aabe23aa8dc67aea440c85c5f45db2854e184e641e95',
    'l10n/generated/mint_next_localizations_pt.dart': '0873ec7c8617e7b84667b0d3ae47e0bca8df86eab296849a84e839279e797370',
    'main.dart': '5c8b1681e8997acde204ff7049204fb55aa9829d98c81dd065202992c85efd24',
    'multi_provider_amount_draft.dart': '6ec168f74f21d56703eb37498c3a5ac86a13d1911b01e1296832144d2849e6c7',
    'multi_provider_amount_editor.dart': '3f2bf5c29e678bc4a0dd8a0d7fba6365a4d0fd751ea9f93f548804a01019f145',
    'multi_provider_casefold_data.dart': '9acee5029f8b19b02c2fc87cc133a199efaf5aa8c9c5226f7ceaca870d5f2115',
    'multi_provider_default_ignorable_data.dart': '0f8bb0b187d94f0c5cfb56e1735f220541c5ed7a9238917a66c92aec799bec66',
    'multi_provider_label.dart': 'f39f18d582dcec006422631710f1168d3fd582da1dc688bf330ca0f8c56757ac',
    'ordinary_chf_amount.dart': '43c9850e89d0696f98d11c1b6cdd295ab48aeb480149b8d5e60116fccf4b55be',
    'provider_label.dart': '06f3714e147660539e6eed40898f9f691a77b7fdaa50f7ca6ad7a44d36c3188a',
    'r3_eclairage_catalog.g.dart': '3d0ab9f4fc8a7ed224ed26c15aaddb5c7424870c957ef0ab5356d0c82d957031',
}
EXPECTED_AUX_INPUT_SHA256 = {
    'l10n.yaml': '0879c4e81347d78e3551434c75ad282aa818efe28ede77d63326dd8b8d4201be',
    'assets/fonts/Gambarino-Regular.otf': '3cfc8143b820d4e9e5970748cf6189d0624aeb1f8c5a0138c2c82bbb9b50efdf',
    'assets/fonts/LICENSE-GAMBARINO.txt': 'c2fa18da766a12ef7a1750bc58268048ec01744669e99061494995ea93320e01',
    'assets/fonts/LICENSE-SUPREME.txt': '716d23ed97562988d3436b36c9a2f6a3876be064bafcebceea29b0a135768e03',
    'assets/fonts/Supreme-Bold.otf': '00ebce7fae218b2e28df0581652749e9cbc1d4a6a4221780541532362471d89a',
    'assets/fonts/Supreme-Medium.otf': '4771fa1237212a3eddb060814b2d721e47a79b9b3bf58451ac1b98c48dce58f9',
    'assets/fonts/Supreme-Regular.otf': '00410913847ad5e731e49da556a0c541aacfae84e6c998c5a3a6b4fca3b18ee4',
}
EXPECTED_ORDER = ["R4", "runtime_global"]
EXPECTED_TEST_NAMES = {
    "R4_01 the wired arc reaches the delivered eclairage boundary before the R4 fermeture runtime",
    "R4_02 scenarios_versement nominal shows the choose line at least two scenario effect ranges and never a single bare number",
    "R4_03 scenarios_versement arrival focuses the choose line heading not a scenario amount and carries the meaning without a body",
    "R4_04 scenarios_versement states the locked liquidity cost and the chef lieu commune caveat and the estimate not advice disclaimer",
    "R4_05 a scenario is a named announced region whose amount and effect are spoken as one utterance",
    "R4_06 the plafond glossary sheet opens focus trapped and restores to the anchor",
    "R4_07 the own amount control is an optional named button pulled by value with no preselected amount",
    "R4_08 compact 320x700 text scale two shows the choose line at least one scenario the liquidity note and the disclaimer without overflow",
    "R4_09 fact_etat_civil shows three civil status cards none preselected and no wheel or keyboard",
    "R4_10 fact_etat_civil arrival focuses the question and the 31 december determining hint without a body sentence",
    "R4_11 selecting the concubinage card announces the selection summary and marks it",
    "R4_12 the splitting glossary sheet opens focus trapped and restored",
    "R4_13 the concubinage glossary states separate taxation never the married splitting",
    "R4_14 fact_etat_civil no selection announces the error and stays but a selected status routes continue to eclairage",
    "R4_15 compact 320x700 text scale two shows the question the three status cards and continue without overflow",
    "R4_16 registry keeps R4 after R3 before runtime_global and excludes later evidence",
    "R4_17 non_affilie reaches a derived ceiling never a flat 7258",
}
EXPECTED_FAILED_NAMES = EXPECTED_TEST_NAMES - {
    "R4_01 the wired arc reaches the delivered eclairage boundary before the R4 fermeture runtime",
    "R4_16 registry keeps R4 after R3 before runtime_global and excludes later evidence",
}
EXPECTED_RED_SENTINELS = {
    name: name.split(" ", 1)[0]
    for name in EXPECTED_FAILED_NAMES
}
ALLOWED_DIFF_PATHS = {
    str(REGISTRY), str(TEST),
    "tools/checks/mint_next_batch22_r4_red_guard.py",
    "tools/checks/tests/test_mint_next_batch22_r4_red_guard.py",
}
EXPECTED_TOP_KEYS = {
    "schema_version", "status", "batch", "authority", "ordered_gates",
    "gates", "runtime_regating", "deferred_integration", "forbidden_claims",
}
EXPECTED_FORBIDDEN_CLAIMS = [
    "runtime_implemented", "runtime_accepted", "user_validated", "production_ready"
]
EXPECTED_BLOCKED_GATES = {
    "runtime_global": "blocked_by_R4",
}
EXPECTED_SUBGATES = {
    "R4a_scenarios_versement": ["R4_02", "R4_03", "R4_04", "R4_05", "R4_06", "R4_07", "R4_08", "R4_17"],
    "R4b_fact_etat_civil": [
        "R4_09", "R4_10", "R4_11", "R4_12", "R4_13", "R4_14", "R4_15",
    ],
}
# regle13 lesson (c): the pin R3 was superseded by, never re-attested live.
EXPECTED_SUPERSEDES = {
    "r3_green_gate": "product/mint_next/batch21/r3-green-gate.yaml",
    "r3_green_accepted_commit": "0a81c9b60",
    "no_live_reattestation_of_r3": True,
}
EXPECTED_RUNTIME_REGATING = {
    "scope_owner": "batch22-r4-runtime",
    "regated_files": [
        "product/mint_next/batch7/design_lab/lib/scenarios_versement.dart",
        "product/mint_next/batch7/design_lab/lib/fact_etat_civil.dart",
        "product/mint_next/batch7/design_lab/lib/r4_fermeture_catalog.g.dart",
        "product/mint_next/batch7/design_lab/lib/design_lab_app.dart",
        # Vague Groupée fermeture: fact_lieu.dart is R4-regated (it lifts the
        # picked commune LABEL to the éclairage payoff via onCommuneSelected).
        "product/mint_next/batch7/design_lab/lib/fact_lieu.dart",
    ],
    "lib_inventory_seal": "deferred_to_implementation_under_this_gate",
}
# RIDER 1+2 — the deferred integration governance unit sealed into the registry.
# LOOP CLOSED (Vague Groupée fermeture-de-boucle, 2026-08-06): the OUTBOUND edges
# are wired (scenarios.continue -> fact_etat_civil ; fact_etat_civil.continue with
# a selected status -> éclairage ; scenarios footer back/keep route), the non-affilié
# LPP-no branch routes to a DERIVED ceiling (sealed R4_17, never a flat 7258), and
# the fermeture-loop financial state survives one loop turn. The ONLY piece not
# recomputed in Dart is the MARRIED CHIFFRE (splitting quotient) — that is a backend
# L2 (comparer) contract on dev (CLAUDE.md NEVER#3), so the runtime carries a
# co-located married caveat on the éclairage Situation row (Vague Groupée P1) rather
# than a fabricated in-Dart number. This dict MUST stay byte-equal to the registry's
# deferred_integration (validate() asserts equality); registry comments are ignored.
EXPECTED_DEFERRED_INTEGRATION = {
    "status": "delivered_r4_loop_closed_married_chiffre_recompute_backend_l2_deferred",
    "green_flips_here_not_at_screen_flip": True,
    "key_reconciliation": {
        "direction": "runtime_conforms_to_sealed_test_never_the_inverse",
        "runtime_adopted_test_keys": [
            "etat_civil_dot_prefix_not_fact_etat_civil_dot",
            "region_scenarios_scenario_not_row_scenarios_scenario_N",
            "amount_scenarios_effect",
        ],
    },
    "delivered_edges": {
        "edges": [
            "eclairage_continue_to_scenarios_versement",
            "eclairage_situation_row_refine_to_fact_etat_civil",
            "fact_etat_civil_continue_routes_to_eclairage_with_a_selected_status",
            "scenarios_versement_footer_continue_back_keep_routing",
        ],
        "non_affilie_ceiling_derivation_delivered_and_sealed_r4_17": True,
        "eclairage_batch21_arc_untouched": True,
    },
    "not_yet_delivered": {
        "edges": [],
        "married_chiffre_recompute_is_backend_l2_contract_on_dev": True,
        "eclairage_situation_row_shows_a_colocated_married_caveat": True,
        "non_affilie_routing_to_scenarios_deferred_real_lpp_no_stops_at_without_lpp_boundary": True,
    },
    "scope": [
        "wire_eclairage_continue_to_scenarios_versement_refreshing_next_action",
        "upgrade_the_eclairage_situation_row_to_a_refine_affordance_routing_to_fact_etat_civil",
        "wire_fact_etat_civil_continue_to_recompute_eclairage_with_is_married_no_re_ask_of_income",
        "route_the_non_affilie_lpp_no_branch_to_a_derived_ceiling_not_a_flat_7258",
        "keep_situation_display_only_until_the_married_recompute_exists_engine_side",
        "re_gate_sibling_screens_touched_by_the_new_wiring",
    ],
    "interim_evidence": {
        "runtime_dev_tests": [
            "product/mint_next/batch7/design_lab/test/dev_scenarios_versement_r4_test.dart",
            "product/mint_next/batch7/design_lab/test/dev_fact_etat_civil_r4_test.dart",
        ],
        "reached_via": "MintNextDesignLabApp.batch22Harness",
        "not_a_silent_gray_zone": True,
    },
    "green_gate_semantics": {
        "acceptance_means": "r4_runtime_implemented_AND_journey_wired",
        "release_attestation_replays": "this_linear_integration_test_passing_within_the_wired_screens",
        "no_pin_may_attest_runtime_only_without_wiring": True,
    },
}
LOCALES = ["fr", "en", "de", "it", "es", "pt"]
# The R4 six-locale copy required-placeholder contract (copy.required_placeholders).
EXPECTED_PLACEHOLDERS = {
    "taxYear", "amount", "low", "high", "room", "contributed", "cap",
    "affiliatedCap", "excess", "ceiling", "commune", "canton", "status", "fact",
}
# mandate step 1 — R4 copy semantics. Concept PRESENCE and jargon/claim ABSENCE,
# never a verbatim phrase to recopy. The copy stays free to be said out loud to a
# friend; the guard only asserts the SENSE survived (LSFin-safe, honest) and the
# forbidden classes (promise words, marginal-rate jargon, locality claims) did not
# reappear.
#
# LSFin promise/superlative words. Word-bounded, applied to every locale (cognate
# across the six). The authored copy is LSFin-safe, so none of these appear; the
# guard prevents their reintroduction (bug #1061 lineage — imperatives abolished).
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
# arc (semantic_assertion: marginal_rate_jargon_is_NOT_surfaced_francs_not_a_rate).
COPY_FORBIDDEN_JARGON = [
    "taux marginal", "marginal rate", "grenzsteuersatz", "aliquota marginale",
    "tipo marginal", "taxa marginal", "coefficient", "steuerfuss",
]
# AUCUNE claim de localité (product decision 2026-08-05): no datum on these two
# screens is device-only (committed amounts + civil status join the profile), so any
# on-device / device-retention claim is a resurrected false privacy line. Device/
# phone nouns have no legitimate use in the scenarios + civil-status copy, so their
# mere presence is the signal. Word-bounded, applied to every locale.
COPY_FORBIDDEN_LOCALITY = [
    r"t[eé]l[eé]phone", r"\bphone\b", r"appareil", r"\bdevice\b", r"on-?device",
    r"ger[aä]t", r"\btelefon", r"dispositivo", r"telem[oó]vel", r"cellulare",
    r"\bm[oó]vil\b",
]
# no-promise + disclaimer on scenarios_versement. The scenarios_disclaimer must
# convey BOTH « estimate » and « not (tax) advice » per locale; dropping the
# negation turns the line into a promise. Accented tokens matched case-insensitively
# as substrings.
COPY_DISCLAIMER_ESTIMATE = {
    "fr": ["estimation"], "en": ["estimate"], "de": ["schätzung", "schatzung"],
    "it": ["stim"], "es": ["estimación", "estimacion"], "pt": ["estimativa"],
}
COPY_DISCLAIMER_NOT_ADVICE = {
    "fr": ["pas un conseil"], "en": ["not advice", "not tax advice"],
    "de": ["keine beratung", "keine steuerberatung"],
    "it": ["non una consulenza", "non e una consulenza", "non è una consulenza"],
    "es": ["no un asesoramiento", "no es un asesoramiento"],
    "pt": ["não um aconselhamento", "nao um aconselhamento", "não é um aconselhamento"],
}
# The locked-liquidity note is the anti-dark-pattern obligation (fault_D): the money
# is locked until retirement (save legal exceptions). The scenarios_liquidity line
# must convey BOTH « locked/blocked » AND « retirement » per locale — dropping either
# hides the liquidity cost.
COPY_LIQUIDITY_LOCKED = {
    "fr": ["bloqué", "bloque"], "en": ["locked"], "de": ["gebunden"],
    "it": ["vincolat"], "es": ["bloquead"], "pt": ["bloquead"],
}
COPY_LIQUIDITY_RETIREMENT = {
    "fr": ["retraite"], "en": ["retirement"], "de": ["pensionierung"],
    "it": ["pensione"], "es": ["jubilación", "jubilacion"], "pt": ["reforma"],
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
    """mandate step 1: per-locale semantics of the R4 six-locale copy."""
    copy = _load(root / COPY)
    _require(copy.get("locales") == LOCALES, "copy locale set or order drifted")
    _require(
        set(copy.get("required_placeholders", [])) == EXPECTED_PLACEHOLDERS,
        "copy required-placeholder contract drifted",
    )
    receipt = copy.get("semantic_receipt", {})
    _require(isinstance(receipt, dict), "copy semantic_receipt missing")
    required_keys = (
        set(receipt.get("required_keys_scenarios", []) or [])
        | set(receipt.get("required_keys_etat_civil", []) or [])
    )
    _require(
        len(required_keys) >= 50 and "scenarios_disclaimer" in required_keys
        and "scenarios_effect" in required_keys and "scenarios_liquidity" in required_keys
        and "etat_civil_gloss_concubinage_def" in required_keys,
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

        # no-promise: every scenario effect is a low->high RANGE, never a single
        # number. scenarios_effect carries {low} and {high}; there is no bare-number
        # effect key.
        effect = str(block["scenarios_effect"])
        _require(
            "{low}" in effect and "{high}" in effect,
            f"copy [{locale}] scenarios effect must be a low-to-high range, never a single number",
        )
        # disclaimer: estimate AND not-advice, both present (LSFin no-promise).
        disclaimer = str(block["scenarios_disclaimer"])
        _require(
            _has_any(disclaimer, COPY_DISCLAIMER_ESTIMATE[locale]),
            f"copy [{locale}] scenarios disclaimer must frame the payoff as an estimate",
        )
        _require(
            _has_any(disclaimer, COPY_DISCLAIMER_NOT_ADVICE[locale]),
            f"copy [{locale}] scenarios disclaimer must say it is not advice (no-promise negation)",
        )
        # anti-dark-pattern (fault_D): the liquidity line states the money is locked
        # until retirement.
        liquidity = str(block["scenarios_liquidity"])
        _require(
            _has_any(liquidity, COPY_LIQUIDITY_LOCKED[locale]),
            f"copy [{locale}] liquidity note must state the money is locked (anti dark pattern)",
        )
        _require(
            _has_any(liquidity, COPY_LIQUIDITY_RETIREMENT[locale]),
            f"copy [{locale}] liquidity note must state it is locked until retirement",
        )
        # the concubinage ruling is carried in clear text: the concubinage gloss says
        # each person is taxed separately / like a single person (never the married
        # splitting). Presence of the single/separate concept, per locale.
        concubinage = str(block["etat_civil_gloss_concubinage_def"]).lower()
        _require(
            any(token in concubinage for token in {
                "fr": ["séparément", "separement", "célibataire", "celibataire"],
                "en": ["separately", "single"],
                "de": ["einzeln", "ledige"],
                "it": ["separatamente", "sola"],
                "es": ["separado", "soltera", "soltero"],
                "pt": ["separadamente", "solteira", "solteiro"],
            }[locale]),
            f"copy [{locale}] concubinage gloss must state the single/separate treatment (the ruling)",
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
    for R4: an obligation that taps the fact_etat_civil continue from the reached
    state but asserts a routed/committed outcome without first committing a status —
    it would contradict the error_no_selection obligation (continue never routes in
    r4 without a selected status: fact_etat_civil continue.never_routes_in_r4 +
    route_guard a_status_is_selected). Any obligation that taps
    action:etat_civil.continue and then asserts a non-error committed/routed state
    MUST first select a status (choice:etat_civil.*). Otherwise it cannot be green
    under one runtime. Reusable pattern-level guard for this and later batches.
    """
    # strip // line comments first, so a token quoted inside a comment can neither
    # bypass the guard nor false-trigger it. The sha pin is the primary lock; this
    # keeps the structural check from being fooled by prose.
    stripped = "\n".join(re.sub(r"//.*$", "", line) for line in test_source.splitlines())
    blocks = re.split(r"\btestWidgets\(", stripped)
    for block in blocks[1:]:
        match = re.search(r"""['"]([^'"]+)['"]""", block)
        name = match.group(1) if match else "<unknown>"
        taps_continue = "action:etat_civil.continue" in block
        commits_status = "choice:etat_civil." in block
        asserts_committed = (
            "status:etat_civil.selection'" in block
            or "node:fact_etat_civil" in block and "findsNothing" not in block and "_reachEtatCivil" not in block
        )
        # the error_no_selection assertion is the SANCTIONED no-commit continue tap.
        asserts_error = "status:etat_civil.error_no_selection" in block
        _require(
            not (taps_continue and asserts_committed and not commits_status and not asserts_error),
            "joint-satisfiability: obligation taps etat_civil.continue with no committed "
            "status yet expects a committed/routed state — contradicts the "
            f"error_no_selection obligation (continue never routes without a status): {name}",
        )


def _validate_diff_boundary(root: Path) -> None:
    try:
        candidate_end = subprocess.run(
            ["git", "log", "-1", "--format=%H", "HEAD", "--", *sorted(ALLOWED_DIFF_PATHS)],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.strip()
        _require(re.fullmatch(r"[0-9a-f]{40}", candidate_end) is not None, "cannot locate Batch22 RED candidate commit")
        committed = subprocess.run(
            ["git", "diff", "--name-only", f"{ANCHOR}..{candidate_end}"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect Batch22 git boundary") from exc
    changed = {
        path for path in committed
        if not path.startswith(".planning/journeys/path-owners/")
    }
    unexpected = changed - ALLOWED_DIFF_PATHS
    _require(not unexpected, f"Batch22 RED scope changed forbidden paths: {sorted(unexpected)}")


def validate(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    for relative in (
        REGISTRY, SCENARIOS_SCOPE, ETAT_CIVIL_SCOPE, COPY, FIXTURES, TEST, FIXTURE,
        PUBSPEC, PUBSPEC_LOCK, L10N_CONFIG,
    ):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not a regular file: {relative}")
    registry = _load(root / REGISTRY)
    _require(set(registry) == EXPECTED_TOP_KEYS, "registry top-level schema drifted")
    _require(registry.get("schema_version") == 1 and registry.get("batch") == 22, "registry identity drifted")
    _require(_sha(root / SCENARIOS_SCOPE) == EXPECTED_SCENARIOS_SCOPE_SHA256, "accepted scenarios scope digest drifted")
    _require(_sha(root / ETAT_CIVIL_SCOPE) == EXPECTED_ETAT_CIVIL_SCOPE_SHA256, "accepted etat_civil scope digest drifted")
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
            "scenarios_versement": str(SCENARIOS_SCOPE),
            "fact_etat_civil": str(ETAT_CIVIL_SCOPE),
        },
        "scope authority drifted",
    )
    _require(
        authority.get("immutable_scope_sha256") == {
            "scenarios_versement": EXPECTED_SCENARIOS_SCOPE_SHA256,
            "fact_etat_civil": EXPECTED_ETAT_CIVIL_SCOPE_SHA256,
        },
        "scope binding drifted",
    )
    _require(authority.get("immutable_copy") == str(COPY), "copy authority drifted")
    _require(authority.get("immutable_copy_sha256") == EXPECTED_COPY_SHA256, "copy binding drifted")
    _require(authority.get("immutable_fixtures") == str(FIXTURES), "fixtures authority drifted")
    _require(authority.get("immutable_fixtures_sha256") == EXPECTED_FIXTURES_SHA256, "fixtures binding drifted")
    _require(authority.get("runtime_surface") == "hidden_design_lab_only", "runtime surface widened")
    _require(authority.get("product_promotion") == "forbidden", "product promotion widened")
    _require(authority.get("supersedes") == EXPECTED_SUPERSEDES, "R3 supersession pin drifted or re-attested")
    _require(registry.get("runtime_regating") == EXPECTED_RUNTIME_REGATING, "runtime regating scope drifted")
    _require(registry.get("deferred_integration") == EXPECTED_DEFERRED_INTEGRATION, "deferred integration governance unit drifted")
    _require(set(registry.get("gates", {})) == set(EXPECTED_ORDER), "registry gate inventory drifted")
    for gate, state in EXPECTED_BLOCKED_GATES.items():
        _require(registry["gates"][gate] == {"state": state}, f"blocked gate widened: {gate}")
    r4 = registry.get("gates", {}).get("R4", {})
    _require(
        set(r4) == {
            "state", "runtime_implemented", "runtime_accepted", "next_gate",
            "later_gate_evidence_counts_for_R4", "test_file",
            "command", "working_directory", "expected_exit_code",
            "expected_summary", "candidate_binding", "subgates",
            "obligation_test_names", "expected_red_sentinels",
        },
        "R4 registry schema drifted",
    )
    _require(r4.get("state") == "expected_red", "R4 is not expected RED")
    _require(r4.get("runtime_implemented") is False, "R4 claims implementation")
    _require(r4.get("runtime_accepted") is False, "R4 claims acceptance")
    _require(r4.get("next_gate") == "runtime_global", "R4 next gate drifted")
    _require(r4.get("later_gate_evidence_counts_for_R4") is False, "later evidence can falsely accept R4")
    _require(r4.get("test_file") == str(TEST), "R4 test path drifted")
    _require(
        r4.get("command") == [
            "flutter", "test", "test/design_lab_batch22_r4_test.dart",
            "--machine", "--no-pub",
        ],
        "R4 command is not exact and targeted",
    )
    _require(r4.get("working_directory") == "product/mint_next/batch7/design_lab", "R4 working directory drifted")
    _require(r4.get("expected_exit_code") == 1, "R4 expected exit drifted")
    _require(r4.get("expected_summary") == {"passed": 2, "failed": 15, "load_or_harness_errors": 0}, "R4 expected summary drifted")
    obligation_map = r4.get("obligation_test_names", {})
    expected_ids = {f"R4_{index:02d}" for index in range(1, 18)}
    _require(set(obligation_map) == expected_ids, "R4 obligation coverage drifted")
    mapped_names = set()
    for value in obligation_map.values():
        mapped_names.update(value if isinstance(value, list) else [value])
    _require(mapped_names == EXPECTED_TEST_NAMES, "R4 named-test inventory drifted")
    _require(r4.get("expected_red_sentinels") == EXPECTED_RED_SENTINELS, "R4 RED sentinel binding drifted")
    subgates = r4.get("subgates", {})
    _require(subgates == EXPECTED_SUBGATES, "R4 subgate coverage drifted")
    covered = {gate for ids in subgates.values() for gate in ids}
    _require(covered == (expected_ids - {"R4_01", "R4_16"}), "R4 subgates must cover every behavioural obligation once")
    _require(registry.get("forbidden_claims") == EXPECTED_FORBIDDEN_CLAIMS, "forbidden claims drifted")

    _require(
        r4.get("candidate_binding") == {"test_sha256": EXPECTED_TEST_SHA256},
        "R4 candidate source binding drifted",
    )
    _require(_sha(root / TEST) == EXPECTED_TEST_SHA256, "R4 test digest drifted")
    _require(_sha(root / FIXTURE) == EXPECTED_FIXTURE_SHA256, "R4 compile fixture digest drifted")
    _require(_sha(root / COPY) == EXPECTED_COPY_SHA256, "accepted copy digest drifted")
    _validate_copy_semantics(root)

    test_source = (root / TEST).read_text(encoding="utf-8")
    for name in EXPECTED_TEST_NAMES:
        _require(test_source.count(name) == 1, f"R4 test missing or duplicated: {name}")
    _require("MintNextDesignLabApp(" in test_source, "R4 tests do not drive the real app")
    _require("node:scenarios_versement" in test_source, "R4 tests do not assert the absent scenarios_versement surface")
    _require("node:fact_etat_civil" in test_source, "R4 tests do not assert the absent fact_etat_civil surface")
    _require("node:eclairage_impot_3a" in test_source, "R4 tests do not reach the delivered R3 eclairage boundary")
    # regle13 lesson (a) simulated-green smoke: no R1_12-style process-global
    # mutation (debugPrint reassignment) that would leave a latent teardown defect
    # when the harness runs green.
    _require(
        re.search(r"debugPrint\s*=[^=]", test_source) is None,
        "R4 test reassigns debugPrint (R1_12-style latent teardown risk)",
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
    # This inventory proves the R4 runtime is NOT implemented: the lib carries only
    # the attested R1 canton + R2 fact_lieu + R3 fact_revenu/eclairage runtimes and
    # shared infra — no scenarios_versement.dart / fact_etat_civil.dart.
    _require(
        sources == EXPECTED_LIB_SOURCE_SHA256,
        "reviewed RED runtime source inventory or digest drifted (R4 runtime must remain unimplemented)",
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


def _run_candidate_command(root: Path, r4: dict) -> subprocess.CompletedProcess[str]:
    design_lab = PUBSPEC.parent
    with tempfile.TemporaryDirectory(prefix="mint-b22-r4-") as directory:
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
        _require(resolved.returncode == 0, "R4 isolated dependency resolution failed")
        return subprocess.run(
            r4["command"], cwd=isolated_lab, capture_output=True, text=True, timeout=180,
        )


def run_expected_red(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    validate(root, check_git=check_git)
    registry = _load(root / REGISTRY)
    r4 = registry["gates"]["R4"]
    try:
        completed = _run_candidate_command(root, r4)
    except subprocess.TimeoutExpired as exc:
        raise GuardFailure("R4 RED command timed out") from exc
    _require(not completed.stderr.strip(), "R4 runner emitted stderr")
    _require(completed.returncode == 1, f"R4 RED command exit was {completed.returncode}, expected 1")
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
            raise GuardFailure("R4 runner emitted non-JSON stdout")
        if isinstance(event, list):
            _require(
                len(event) == 1
                and isinstance(event[0], dict)
                and event[0].get("event") == "test.startedProcess",
                "R4 runner emitted unknown list event",
            )
            continue
        _require(isinstance(event, dict), "R4 runner emitted non-object event")
        etype = event.get("type")
        if etype == "testStart":
            test = event["test"]
            _require(test["id"] not in starts, "duplicate R4 testStart id")
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
                _require(name not in results, "duplicate R4 test execution")
                results[name] = event["result"]
            else:
                _require(False, "unexpected hidden testDone event")
        elif etype == "done":
            done_events.append(event)
        else:
            _require(etype in passive_event_types, f"unknown R4 machine event: {etype}")
    _require(load_result == "success", "R4 test failed to compile or load")
    _require(set(test_done_ids) == set(starts), "R4 testStart/testDone inventory drifted")
    _require(
        len(done_events) == 1
        and set(done_events[0]) == {"success", "type", "time"}
        and done_events[0]["type"] == "done"
        and done_events[0]["success"] is False
        and isinstance(done_events[0]["time"], int),
        "R4 final done event drifted",
    )
    _require(set(results) == EXPECTED_TEST_NAMES, "executed R4 test inventory drifted")
    failed = {name for name, result in results.items() if result == "error"}
    passed = {name for name, result in results.items() if result == "success"}
    _require(failed == EXPECTED_FAILED_NAMES, f"unexpected RED failures: {sorted(failed ^ EXPECTED_FAILED_NAMES)}")
    _require(passed == EXPECTED_TEST_NAMES - EXPECTED_FAILED_NAMES, "R4 positive controls did not pass")
    expected_error_ids = sorted(
        test_id for test_id, full_name in starts.items()
        if full_name in EXPECTED_FAILED_NAMES
    )
    _require(sorted(error_ids) == expected_error_ids, "R4 machine error-event inventory drifted")
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
        print(f"BATCH22 R4 RED FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH22 R4 RED PASS: behavioural failures are expected and runtime remains unimplemented")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
