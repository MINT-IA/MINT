#!/usr/bin/env python3
"""Fail closed unless Batch20 R2 (fact_lieu, COMMUNE DIRECTE) is an honest,
executable RED contract.

Mirrors tools/checks/mint_next_batch19_r1_red_guard.py. R1 is done and is
superseded BY PIN (regle13 lesson c): this guard never re-attests R1 live; it
only reads the batch20 registry authority.supersedes pin. The commune-directe
pivot (Julien 2026-08-04) folds fact_canton into a single fused fact_lieu node
answered by a NATIONAL commune search with a DERIVED canton. That fused runtime
does NOT exist, so design_lab_batch20_commune_r2_test.dart drives the attested
green 3a entry path to the contribution boundary and then asserts the absent
fact_lieu surface: 2 pass, 13 named behavioural RED failures, 0 load/harness
errors.
"""

# HISTORICAL-REPLAY NOTICE (batch19 pattern, product decision 2026-08-05). This is
# an expected-RED guard: validate()/run_expected_red assert the PRE-runtime state
# (EXPECTED_LIB_SOURCE_SHA256 = the lib WITHOUT the fact_lieu runtime). The fact_lieu
# runtime has existed since fec98e82b, so validate() and `--contract` fail on the
# lib-inventory drift post-runtime — the expected-RED replay is HISTORICAL, attested
# at the sealed RED_COMMIT, never a live proof. The STRUCTURAL constants below
# (ANCHOR, EXPECTED_{COPY,SCOPE,TEST}_SHA256, EXPECTED_TEST_NAMES, subgates) remain
# the sealed reference the green-gate reads; the LIVE structural proof is the
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
REGISTRY = Path("product/mint_next/batch20/runtime-gates.yaml")
SCOPE = Path("product/mint_next/batch20/commune-scope.yaml")
COPY = Path("product/mint_next/batch20/six-locale-copy.yaml")
DATASET = Path("product/mint_next/batch20/commune-dataset.yaml")
TEST = Path(
    "product/mint_next/batch7/design_lab/test/"
    "design_lab_batch20_commune_r2_test.dart"
)
FIXTURE = Path(
    "product/mint_next/batch7/design_lab/test/batch20_commune_fixture.g.dart"
)
PUBSPEC = Path("product/mint_next/batch7/design_lab/pubspec.yaml")
PUBSPEC_LOCK = Path("product/mint_next/batch7/design_lab/pubspec.lock")
LIB_ROOT = Path("product/mint_next/batch7/design_lab/lib")
L10N_CONFIG = Path("product/mint_next/batch7/design_lab/l10n.yaml")
ASSETS_ROOT = Path("product/mint_next/batch7/design_lab/assets")

# regle13 lesson (d): ANCHOR is the parent of the RED_COMMIT that authors the
# sealed RED files (RED_COMMIT^). It is the batch20 content commit (scope, copy,
# dataset, fixture) — the frozen fact_lieu contract validated by Julien. The
# RED-scope diff ANCHOR..candidate_end must touch only ALLOWED_DIFF_PATHS.
# test_..._red_guard.py asserts ANCHOR == RED_COMMIT^.
ANCHOR = "df4f7a4427e0feed44957ab7f3aec1f4d42779ed"

EXPECTED_SCOPE_SHA256 = "ee347aeb8d9081441d0ba700e7c85ecbdf9178863f3b849325c06d1ea9fbbe00"
EXPECTED_COPY_SHA256 = "a0de2dc4990bd69032e7b47a28efe95910d528cabe8b307ac94a986234d9e1de"
EXPECTED_DATASET_SHA256 = "da63fba5a08ce7f6757e2ae794bd4ae12a57b87a6d909e382d4a7deb8e1c3969"
EXPECTED_TEST_SHA256 = "1df3c7f0b2823c8d10fe1f753a132ea2e0c0806e1dca0e24e1be399804512a33"
EXPECTED_FIXTURE_SHA256 = "25b9adad279215b54d67d924f9ea5fb754e97b5dae7746f30acf26e635f38700"
EXPECTED_PUBSPEC_SHA256 = "0b83bf36a5ee2242becbd0fb601235f0c3b2942813207552a03957aaf1569326"
EXPECTED_PUBSPEC_LOCK_SHA256 = "6d7f501ae44e385c80d3726c6a25d830d04d3acf0a7456c6129a293f97f885a1"
EXPECTED_LIB_SOURCE_SHA256 = {
    "canton_r1.dart": "928297a39bcb50466df1460f730b2700287f8c93ec6504b0adfb62faadbe1161",
    "canton_r1_catalog.g.dart": "f8444b10283d4dc600feb695c19850963b044e67cb3a4766dab9f2c69d40781d",
    "design_lab_app.dart": "cac3a9d5d50e3603cc7137a734d9f9c7e430f06100bbfda3d1b04543c817f72e",
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
    "R2", "R3", "R4a_safe_exit",
    "R4b_lifecycle_generation_and_privacy",
    "R4c_six_locale_accessibility_and_compact",
    "R4d_cross_step_integration", "R4", "runtime_global",
]
EXPECTED_TEST_NAMES = {
    "R2_01 the shared entry path reaches the contribution boundary before the fused location runtime",
    "R2_02 arrival focuses the heading not a raised keyboard and the question carries the meaning without a body",
    "R2_03 an empty national query prompts for a commune name and dumps nothing until a prefix is typed",
    "R2_04 every national result names its derived canton",
    "R2_05 results cap at fifty with an overflow status carrying the total",
    "R2_06 bilingual aliases and official variants match the reviewed labels",
    "R2_07 the postcode is searchable secondary text but never the committed value",
    "R2_08 the selection summary persists and is visible when the selected commune is not in the current results",
    "R2_09 selecting a commune announces the commune and its derived canton atomically as one node",
    "R2_10 no match prompts a spelling check and reveals a help link that escalates to r3 in the no match state only",
    "R2_11 a tappable glossary anchor opens an aerated definition sheet with a sentence and a metaphor and restores focus",
    "R2_12 entry is unset with no default recommended or derived commune and no unknown control",
    "R2_13 compact 320x700 text scale two keyboard raised keeps continue and a canton naming result reachable",
    "R2_14 continue is guarded by a reviewed commune reselection is idempotent and continue never routes in r2",
    "R2_15 registry keeps R2 before R3 and excludes later evidence",
    "R2_16 the positive contribution branch also reaches the fused location runtime and back returns to the amount step",
}
EXPECTED_FAILED_NAMES = EXPECTED_TEST_NAMES - {
    "R2_01 the shared entry path reaches the contribution boundary before the fused location runtime",
    "R2_15 registry keeps R2 before R3 and excludes later evidence",
}
EXPECTED_RED_SENTINELS = {
    name: name.split(" ", 1)[0]
    for name in EXPECTED_FAILED_NAMES
}
ALLOWED_DIFF_PATHS = {
    str(REGISTRY), str(TEST),
    "tools/checks/mint_next_batch20_r2_red_guard.py",
    "tools/checks/tests/test_mint_next_batch20_r2_red_guard.py",
}
EXPECTED_TOP_KEYS = {
    "schema_version", "status", "batch", "authority", "ordered_gates",
    "gates", "forbidden_claims",
}
EXPECTED_FORBIDDEN_CLAIMS = [
    "runtime_implemented", "runtime_accepted", "user_validated", "production_ready"
]
EXPECTED_BLOCKED_GATES = {
    "R3": "blocked_by_R2",
    "R4a_safe_exit": "blocked_by_R3",
    "R4b_lifecycle_generation_and_privacy": "blocked_by_R4a",
    "R4c_six_locale_accessibility_and_compact": "blocked_by_R4b",
    "R4d_cross_step_integration": "blocked_by_R4c",
    "R4": "blocked_by_R4d",
    "runtime_global": "blocked_by_R4",
}
EXPECTED_SUBGATES = {
    "R2a_arrival_states_and_national_search": ["R2_02", "R2_03", "R2_04", "R2_05", "R2_12", "R2_16"],
    "R2b_matching_privacy_npa_and_aliases": ["R2_06", "R2_07", "R2_08", "R2_10"],
    "R2c_selection_glossary_a11y_and_compact": ["R2_09", "R2_11", "R2_13", "R2_14"],
}
# regle13 lesson (c): the pin R1 was superseded by, never re-attested live.
EXPECTED_SUPERSEDES = {
    "r1_green_gate": "product/mint_next/batch19/r1-green-gate.yaml",
    "r1_green_accepted_commit": "584702094",
    "r1_green_attestation_run": "https://github.com/MINT-IA/MINT/actions/runs/30916749754",
    "r1_red_acceptance_commit": "d7461aab184125c11ec78c8d0f269c23a1236c7b",
    "no_live_reattestation_of_r1": True,
}
LOCALES = ["fr", "en", "de", "it", "es", "pt"]
# The 32 reviewed fact_commune_* copy keys of the commune-directe contract. Key
# parity across all six locales enforces the removed-key amendments: no body
# sentence (fact_commune_body), no unknown/wheel path (fact_commune_unknown,
# fact_commune_unknown_reassurance, fact_commune_selection_unknown), no scoped
# canton header (fact_commune_scoped_canton) — any of them would break parity.
EXPECTED_COPY_KEYS = {
    "fact_commune_eyebrow", "fact_commune_question", "fact_commune_search_label",
    "fact_commune_search_placeholder", "fact_commune_empty", "fact_commune_match_count",
    "fact_commune_overflow_status", "fact_commune_no_match", "fact_commune_help_link",
    "fact_commune_clear_search", "fact_commune_npa_secondary", "fact_commune_selection_label",
    "fact_commune_selection_selected", "fact_commune_selection_none", "fact_commune_change",
    "fact_commune_communal_hint", "fact_commune_continue", "fact_commune_back",
    "fact_commune_error_no_selection", "fact_commune_error_stale",
    "fact_commune_gloss_communal_term", "fact_commune_gloss_communal_def",
    "fact_commune_gloss_communal_metaphor", "fact_commune_gloss_politique_term",
    "fact_commune_gloss_politique_def", "fact_commune_gloss_jour_term",
    "fact_commune_gloss_jour_def", "fact_commune_gloss_eglise_term",
    "fact_commune_gloss_eglise_def", "fact_commune_gloss_npa_term", "fact_commune_gloss_npa_def",
}
# mandate step 4: per-locale semantic assertions on the fact_lieu copy. Concept
# PRESENCE (accepted keyword variants, case-insensitive) and jargon ABSENCE —
# never a verbatim phrase to recopy. The copy stays free to be said out loud to
# a friend; the guard only asserts the SENSE survived and the jargon did not.
COPY_FORBIDDEN_JARGON = [
    "coefficient", "quotité", "centimes additionnels", "steuerfuss",
    "moltiplicatore", "multiplicateur", "coeficiente",
]
COPY_COMMUNAL_TAX = {
    "fr": ["communal"], "en": ["communal"], "de": ["gemeindesteuer", "gemeinde"],
    "it": ["comunale"], "es": ["municipal"], "pt": ["municipal"],
}
# HARD (Julien): the communal-tax teaching must stay MODAL — a communal tax MAY
# apply, never a promise that it does.
COPY_MODAL_MAY = {
    "fr": ["peut"], "en": ["may"], "de": ["kann"],
    "it": ["può", "puo"], "es": ["puede"], "pt": ["pode"],
}
COPY_CHURCH_SEPARATE = {
    "fr": ["ecclésiastique", "paroisse", "église"], "en": ["church", "parish"],
    "de": ["kirchensteuer", "kirchgemeinde", "kirche"], "it": ["culto", "parrocchia", "chiesa"],
    "es": ["eclesiástico", "parroquia", "iglesia"], "pt": ["eclesiástico", "paróquia", "igreja"],
}
COPY_POLITICAL = {
    "fr": ["politique", "domicile"], "en": ["political", "residence"],
    "de": ["politische", "wohnsitz"], "it": ["politico", "domicilio"],
    "es": ["político", "domicilio"], "pt": ["político", "domicílio"],
}
# privacy_copy_rule REMOVED (product decision 2026-08-05): the fact_lieu screen no
# longer carries an unsolicited on-device claim — privacy claims derive from the
# screen's data contract and locality claims are abolished everywhere. The former
# COPY_SEARCH_LOCAL / COPY_PRIVACY_LOCAL / COPY_PRIVACY_FORBIDDEN dicts (which
# constrained the removed fact_commune_privacy copy line) are dropped with the key.
# The search query stays device-local as a DATA fact (commune-scope runtime_contract),
# it is simply no longer whispered on screen.
# church tax is EXCLUDED here: the church glossary definition must negate (not
# merely mention church tax). Word-bounded negation particle, never a verbatim
# phrase, so the copy stays free to say "we don't count it here" any way it likes.
COPY_CHURCH_EXCLUDED = {
    "fr": r"\b(ne|pas)\b", "en": r"\b(not|don)\b|n't", "de": r"\b(nicht|kein)\b",
    "it": r"\bnon\b", "es": r"\bno\b", "pt": r"\b(não|nao)\b",
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
    """mandate step 4: per-locale semantics of the fact_lieu six-locale copy."""
    copy = _load(root / COPY)
    _require(copy.get("locales") is not None, "copy locales missing")
    _require(set(copy["locales"]) == set(LOCALES), "copy locale set drifted")
    payloads = copy.get("copy", {})
    _require(set(payloads) == set(LOCALES), "copy per-locale payload set drifted")
    seen: dict[str, str] = {}
    placeholders_per_key: dict[str, set[str]] = {}
    for locale in LOCALES:
        block = payloads[locale]
        _require(isinstance(block, dict), f"copy locale not a map: {locale}")
        # key parity enforces the removed-key amendments (no body, no unknown/wheel).
        _require(
            set(block) == EXPECTED_COPY_KEYS,
            f"copy [{locale}] key set drifted (body/unknown/wheel key added or a required key dropped)",
        )
        blob = "\n".join(str(value) for value in block.values())
        low = blob.lower()
        for token in COPY_FORBIDDEN_JARGON:
            _require(
                token not in low,
                f"copy [{locale}] leaks coefficient/multiplier jargon: {token}",
            )

        def _has_any(field: str, variants: list[str]) -> bool:
            low_field = field.lower()
            return any(variant in low_field for variant in variants)

        communal_blob = (
            str(block["fact_commune_gloss_communal_term"]) + "\n"
            + str(block["fact_commune_gloss_communal_def"]) + "\n"
            + str(block["fact_commune_gloss_communal_metaphor"]) + "\n"
            + str(block["fact_commune_communal_hint"])
        )
        communal_def = str(block["fact_commune_gloss_communal_def"])
        eglise_def = str(block["fact_commune_gloss_eglise_def"])
        church_blob = (
            str(block["fact_commune_gloss_eglise_term"]) + "\n"
            + eglise_def + "\n"
            + str(block["fact_commune_gloss_politique_def"])
        )
        political_blob = (
            str(block["fact_commune_gloss_politique_term"]) + "\n"
            + str(block["fact_commune_gloss_politique_def"])
        )
        jour_def = str(block["fact_commune_gloss_jour_def"])
        selection = str(block["fact_commune_selection_selected"])

        _require(
            _has_any(communal_blob, COPY_COMMUNAL_TAX[locale]),
            f"copy [{locale}] glossary must convey that a communal tax can apply",
        )
        _require(
            _has_any(communal_def, COPY_MODAL_MAY[locale]),
            f"copy [{locale}] communal-tax teaching must stay modal (a tax may apply, not a promise)",
        )
        _require(
            _has_any(church_blob, COPY_CHURCH_SEPARATE[locale]),
            f"copy [{locale}] glossary must separate the parish/church tax from the estimate",
        )
        _require(
            re.search(COPY_CHURCH_EXCLUDED[locale], eglise_def.lower()) is not None,
            f"copy [{locale}] church glossary must mark the church tax as excluded here (negation), not merely mention it",
        )
        _require(
            _has_any(political_blob, COPY_POLITICAL[locale]),
            f"copy [{locale}] glossary must name the political commune of domicile as the tax unit",
        )
        _require(
            "31" in jour_def,
            f"copy [{locale}] determining-date glossary must name the 31 December reference",
        )
        _require(
            "{commune}" in selection and "{canton}" in selection,
            f"copy [{locale}] selection must bundle the commune with its derived canton atomically",
        )
        for key, value in block.items():
            placeholders_per_key.setdefault(key, _placeholders(str(value)))
            _require(
                placeholders_per_key[key] == _placeholders(str(value)),
                f"copy [{locale}] placeholder parity drifted for {key}",
            )
        # identical full-locale payloads are forbidden (no lazy fallback locale).
        key = json.dumps(block, sort_keys=True, ensure_ascii=False)
        _require(key not in seen, f"copy [{locale}] is byte-identical to [{seen.get(key)}]")
        seen[key] = locale


def _validate_diff_boundary(root: Path) -> None:
    try:
        candidate_end = subprocess.run(
            ["git", "log", "-1", "--format=%H", "HEAD", "--", *sorted(ALLOWED_DIFF_PATHS)],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.strip()
        _require(re.fullmatch(r"[0-9a-f]{40}", candidate_end) is not None, "cannot locate Batch20 RED candidate commit")
        committed = subprocess.run(
            ["git", "diff", "--name-only", f"{ANCHOR}..{candidate_end}"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise GuardFailure("cannot inspect Batch20 git boundary") from exc
    changed = {
        path for path in committed
        if not path.startswith(".planning/journeys/path-owners/")
    }
    unexpected = changed - ALLOWED_DIFF_PATHS
    _require(not unexpected, f"Batch20 RED scope changed forbidden paths: {sorted(unexpected)}")


def validate(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    for relative in (
        REGISTRY, SCOPE, COPY, DATASET, TEST, FIXTURE, PUBSPEC, PUBSPEC_LOCK,
        L10N_CONFIG,
    ):
        path = root / relative
        _require(path.is_file() and not path.is_symlink(), f"artifact is not a regular file: {relative}")
    registry = _load(root / REGISTRY)
    _require(set(registry) == EXPECTED_TOP_KEYS, "registry top-level schema drifted")
    _require(registry.get("schema_version") == 1 and registry.get("batch") == 20, "registry identity drifted")
    _require(_sha(root / SCOPE) == EXPECTED_SCOPE_SHA256, "accepted scope digest drifted")
    _require(_sha(root / DATASET) == EXPECTED_DATASET_SHA256, "accepted dataset digest drifted")
    _require(
        registry.get("status") == "candidate_expected_red_evidence_runtime_not_implemented",
        "registry lifecycle or runtime claim drifted",
    )
    _require(registry.get("ordered_gates") == EXPECTED_ORDER, "gate order drifted")
    authority = registry.get("authority", {})
    _require(
        set(authority) == {"immutable_scope", "immutable_scope_sha256", "runtime_surface", "product_promotion", "supersedes"},
        "registry authority schema drifted",
    )
    _require(authority.get("immutable_scope") == str(SCOPE), "scope authority drifted")
    _require(authority.get("immutable_scope_sha256") == EXPECTED_SCOPE_SHA256, "scope binding drifted")
    _require(authority.get("runtime_surface") == "hidden_design_lab_only", "runtime surface widened")
    _require(authority.get("product_promotion") == "forbidden", "product promotion widened")
    _require(authority.get("supersedes") == EXPECTED_SUPERSEDES, "R1 supersession pin drifted or re-attested")
    _require(set(registry.get("gates", {})) == set(EXPECTED_ORDER), "registry gate inventory drifted")
    for gate, state in EXPECTED_BLOCKED_GATES.items():
        _require(registry["gates"][gate] == {"state": state}, f"blocked gate widened: {gate}")
    r2 = registry.get("gates", {}).get("R2", {})
    _require(
        set(r2) == {
            "state", "runtime_implemented", "runtime_accepted", "next_gate",
            "later_gate_evidence_counts_for_R2", "test_file", "fixture_file",
            "command", "working_directory", "expected_exit_code",
            "expected_summary", "candidate_binding", "subgates",
            "obligation_test_names", "expected_red_sentinels",
        },
        "R2 registry schema drifted",
    )
    _require(r2.get("state") == "expected_red", "R2 is not expected RED")
    _require(r2.get("runtime_implemented") is False, "R2 claims implementation")
    _require(r2.get("runtime_accepted") is False, "R2 claims acceptance")
    _require(r2.get("next_gate") == "R3", "R2 next gate drifted")
    _require(r2.get("later_gate_evidence_counts_for_R2") is False, "later evidence can falsely accept R2")
    _require(r2.get("test_file") == str(TEST), "R2 test path drifted")
    _require(r2.get("fixture_file") == str(FIXTURE), "R2 fixture path drifted")
    _require(
        r2.get("command") == [
            "flutter", "test", "test/design_lab_batch20_commune_r2_test.dart",
            "--machine", "--no-pub",
        ],
        "R2 command is not exact and targeted",
    )
    _require(r2.get("working_directory") == "product/mint_next/batch7/design_lab", "R2 working directory drifted")
    _require(r2.get("expected_exit_code") == 1, "R2 expected exit drifted")
    _require(r2.get("expected_summary") == {"passed": 2, "failed": 14, "load_or_harness_errors": 0}, "R2 expected summary drifted")
    obligation_map = r2.get("obligation_test_names", {})
    expected_ids = {f"R2_{index:02d}" for index in range(1, 17)}
    _require(set(obligation_map) == expected_ids, "R2 obligation coverage drifted")
    mapped_names = set()
    for value in obligation_map.values():
        mapped_names.update(value if isinstance(value, list) else [value])
    _require(mapped_names == EXPECTED_TEST_NAMES, "R2 named-test inventory drifted")
    _require(r2.get("expected_red_sentinels") == EXPECTED_RED_SENTINELS, "R2 RED sentinel binding drifted")
    subgates = r2.get("subgates", {})
    _require(subgates == EXPECTED_SUBGATES, "R2 subgate coverage drifted")
    covered = {gate for ids in subgates.values() for gate in ids}
    _require(covered == (expected_ids - {"R2_01", "R2_15"}), "R2 subgates must cover every behavioural obligation once")
    _require(registry.get("forbidden_claims") == EXPECTED_FORBIDDEN_CLAIMS, "forbidden claims drifted")

    _require(
        r2.get("candidate_binding") == {
            "test_sha256": EXPECTED_TEST_SHA256,
            "fixture_sha256": EXPECTED_FIXTURE_SHA256,
        },
        "R2 candidate source binding drifted",
    )
    _require(_sha(root / TEST) == EXPECTED_TEST_SHA256, "R2 test digest drifted")
    _require(_sha(root / FIXTURE) == EXPECTED_FIXTURE_SHA256, "R2 fixture digest drifted")
    _require(_sha(root / COPY) == EXPECTED_COPY_SHA256, "accepted copy digest drifted")
    # fixture is bound to the dataset by the declared source sha.
    fixture_text = (root / FIXTURE).read_text(encoding="utf-8")
    _require(EXPECTED_DATASET_SHA256 in fixture_text, "fixture does not declare the reviewed dataset source")
    _validate_copy_semantics(root)

    test_source = (root / TEST).read_text(encoding="utf-8")
    for name in EXPECTED_TEST_NAMES:
        _require(test_source.count(name) == 1, f"R2 test missing or duplicated: {name}")
    _require("MintNextDesignLabApp(" in test_source, "R2 tests do not drive the real app")
    _require("node:fact_lieu" in test_source, "R2 tests do not assert the fused fact_lieu surface")
    # regle13 lesson (a) simulated-green smoke: no R1_12-style process-global
    # mutation (debugPrint reassignment) that would leave a latent teardown
    # defect when the harness runs green.
    _require(
        re.search(r"debugPrint\s*=[^=]", test_source) is None,
        "R2 test reassigns debugPrint (R1_12-style latent teardown risk)",
    )

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
    # This inventory proves the R2 fact_lieu runtime is NOT implemented: the lib
    # carries only the attested R1 canton runtime and shared infra.
    _require(
        sources == EXPECTED_LIB_SOURCE_SHA256,
        "reviewed RED runtime source inventory or digest drifted (R2 runtime must remain unimplemented)",
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


def _run_candidate_command(root: Path, r2: dict) -> subprocess.CompletedProcess[str]:
    design_lab = PUBSPEC.parent
    with tempfile.TemporaryDirectory(prefix="mint-b20-r2-") as directory:
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
        _require(resolved.returncode == 0, "R2 isolated dependency resolution failed")
        return subprocess.run(
            r2["command"], cwd=isolated_lab, capture_output=True, text=True, timeout=180,
        )


def run_expected_red(root: Path = REPO_ROOT, *, check_git: bool = True) -> None:
    validate(root, check_git=check_git)
    registry = _load(root / REGISTRY)
    r2 = registry["gates"]["R2"]
    try:
        completed = _run_candidate_command(root, r2)
    except subprocess.TimeoutExpired as exc:
        raise GuardFailure("R2 RED command timed out") from exc
    _require(not completed.stderr.strip(), "R2 runner emitted stderr")
    _require(completed.returncode == 1, f"R2 RED command exit was {completed.returncode}, expected 1")
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
            raise GuardFailure("R2 runner emitted non-JSON stdout")
        if isinstance(event, list):
            _require(
                len(event) == 1
                and isinstance(event[0], dict)
                and event[0].get("event") == "test.startedProcess",
                "R2 runner emitted unknown list event",
            )
            continue
        _require(isinstance(event, dict), "R2 runner emitted non-object event")
        etype = event.get("type")
        if etype == "testStart":
            test = event["test"]
            _require(test["id"] not in starts, "duplicate R2 testStart id")
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
                _require(name not in results, "duplicate R2 test execution")
                results[name] = event["result"]
            else:
                _require(False, "unexpected hidden testDone event")
        elif etype == "done":
            done_events.append(event)
        else:
            _require(etype in passive_event_types, f"unknown R2 machine event: {etype}")
    _require(load_result == "success", "R2 test failed to compile or load")
    _require(set(test_done_ids) == set(starts), "R2 testStart/testDone inventory drifted")
    _require(
        len(done_events) == 1
        and set(done_events[0]) == {"success", "type", "time"}
        and done_events[0]["type"] == "done"
        and done_events[0]["success"] is False
        and isinstance(done_events[0]["time"], int),
        "R2 final done event drifted",
    )
    _require(set(results) == EXPECTED_TEST_NAMES, "executed R2 test inventory drifted")
    failed = {name for name, result in results.items() if result == "error"}
    passed = {name for name, result in results.items() if result == "success"}
    _require(failed == EXPECTED_FAILED_NAMES, f"unexpected RED failures: {sorted(failed ^ EXPECTED_FAILED_NAMES)}")
    _require(passed == EXPECTED_TEST_NAMES - EXPECTED_FAILED_NAMES, "R2 positive controls did not pass")
    expected_error_ids = sorted(
        test_id for test_id, full_name in starts.items()
        if full_name in EXPECTED_FAILED_NAMES
    )
    _require(sorted(error_ids) == expected_error_ids, "R2 machine error-event inventory drifted")
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
        print(f"BATCH20 R2 RED FAIL: {exc}", file=sys.stderr)
        return 1
    print("BATCH20 R2 RED PASS: behavioural failures are expected and runtime remains unimplemented")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
