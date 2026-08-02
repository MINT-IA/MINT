#!/usr/bin/env python3
"""Fail-closed guard for the MINT Next governance-authority transition.

This guard deliberately proves less than product readiness.  It permits only a
governance-only router transition while protecting the existing retirement
vertical, product code, Journey OS evidence, and simulator flows byte-for-byte.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Mapping, Optional, Sequence, Set

import yaml


OLD_MILESTONE = "mint-2-0-first-experience-rente-capital"
NEW_MILESTONE = "mint-next-architecture-authority-20260802"
NEW_PHASE_DIR = f".planning/phases/{NEW_MILESTONE}"
NEW_CONTEXT = f"{NEW_PHASE_DIR}/CONTEXT.md"
NEW_SPEC = f"{NEW_PHASE_DIR}/SPEC.md"
NEW_PLAN = f"{NEW_PHASE_DIR}/PLAN.md"
NEW_VERIFICATION = f"{NEW_PHASE_DIR}/VERIFICATION.md"
AUDITED_TRANSITION_HEAD = "b88a425573eb93508a554ca9e3c9a7bfd72f5d46"
AUDITED_TRANSITION_MANIFEST: Dict[str, str] = {
    ".planning/ACTIVE_CONTEXT.json": "8fda531e673162678e5e193c7ff82190fc0ea92e0f38ed373abe0dac42c9a5e0",
    ".planning/ACTIVE_CONTEXT.md": "41bcb068b6db45938adfa0476bf4b8c930a2f6523b831411d4aae1b807291a56",
    ".planning/INDEX.md": "3d7569f4e55c08528d6e6b20bdf95e1e84391aa9cb8c2667cd2b0bca208be4b9",
    ".planning/ROADMAP.md": "a34d08c1851241970f21b33d21a6a01985496386f8f7b35cbda10e6b4c931481",
    ".planning/STATE.md": "d504c6272d44111e747e82be34557ade31c42a41f60828547c68eeb17e4f70ad",
    f"{NEW_PHASE_DIR}/CONTEXT.md": "74cab13924ce0ecd30bcacf0a069fa55775af8c01e2c97216e7532f36f681c0e",
    f"{NEW_PHASE_DIR}/PLAN.md": "095abbb9c7dddd0f74611c09eb10e4b3062efaef2e94ee35770446cf59617961",
    f"{NEW_PHASE_DIR}/SPEC.md": "65b7ff39bb4404e96768ec1aa49c51cc3223376defcca2765b714a6dbe0596d5",
    f"{NEW_PHASE_DIR}/VERIFICATION.md": "8cccd38db208ca43490eec1200da5caf9191776cf05e5435db55401efa310a88",
    "product/mint_next/batch4/architecture_conflicts.yaml": "a2d37da20e3b164e571c19b982d61e2a5e508b1d1b9f971e9d67ab65d7f01a36",
    "product/mint_next/batch4/source-inventory.yaml": "2e0c352dabb427c5b0a60d7eda0e9724fa61f8b2992f62df8d5eb9bf1a4e2997",
    "tools/checks/journey_os_check.py": "0c57f6d6bd0edf71ed471cd5ba165c1eb37b3f9d2596f425e0fed46e21ec73e7",
    "tools/checks/mint_next_authority_transition_guard.py": "089cb19017389a5aed8c46e473a53147e52278a968fa15c69f1301f5abe6def1",
    "tools/checks/tests/test_mint_next_authority_transition_guard.py": "513ae6108241ecfed2ee65ec5bc25d948c6f9dcb6313ab9fd68f4c30c5f0b614",
}
REQUIRED_ROASTS = {
    "authority_coherence": (
        "authority_roast_coherence",
        "advisory:authority-coherence:b88a42557",
    ),
    "legacy_evidence_preservation": (
        "authority_roast_preservation",
        "advisory:legacy-preservation:b88a42557",
    ),
    "guard_hostile_mutation_quality": (
        "authority_roast_guard",
        "advisory:guard-hostile-mutations:b88a42557",
    ),
}
ROAST_ARTIFACTS: Dict[str, Dict[str, str]] = {
    "authority_coherence": {
        "path": f"{NEW_PHASE_DIR}/evidence/authority-coherence-b88a42557.yaml",
        "sha256": "54eec126429d6fc0c660745b001e8d746d24a9aa2f07385f25686ea4b19d4a42",
    },
    "legacy_evidence_preservation": {
        "path": f"{NEW_PHASE_DIR}/evidence/legacy-preservation-b88a42557.yaml",
        "sha256": "037577798476278643f891c2628b9d48c86435dbd7644e83656ae75c52f03994",
    },
    "guard_hostile_mutation_quality": {
        "path": f"{NEW_PHASE_DIR}/evidence/guard-hostile-mutations-b88a42557.yaml",
        "sha256": "820de160cf5bf1c0862817536a36445a9b785787e464c2d87147ad10d3825acf",
    },
}

AUTHORITY_MARKER = (
    "<!-- mint-authority: milestone={milestone}; phase_dir={phase_dir}; "
    "context={context}; spec={spec}; mode=governance-only -->"
)

# Audited at 707b25b815483ea20f77b065df9a47c63210f790.  Keeping the
# manifest here makes deletion, addition, or mutation of the old runtime
# vertical fail independently of git rename heuristics.
LEGACY_RETIREMENT_MANIFEST: Dict[str, str] = {
    ".planning/phases/mint-2-0-first-experience-rente-capital/CLAUDE-REVIEW.md": "fbd7894c09762646834247c0cede3178c09240f21550f92ce67cb6e809b4d8f5",
    ".planning/phases/mint-2-0-first-experience-rente-capital/CONTEXT.md": "60c601b8349bd8ac14a5a8a877fc7ee00624866fbe7d5e9dfd2479de34b3127b",
    ".planning/phases/mint-2-0-first-experience-rente-capital/PLAN.md": "d996ff7ba3e635a8da10985719ec70ce3418894c46039fd42a8030b6dee850b5",
    ".planning/phases/mint-2-0-first-experience-rente-capital/PLANS.md": "b3b35b9bbeaac943f4eb1f6102ae9629da29fae9cace01eb26695256df1b72ce",
    ".planning/phases/mint-2-0-first-experience-rente-capital/SPEC.md": "7714cc2ba2784eaa3ce33dce93e8aec2f1bb3b61cda6c0eb69e08350da78109e",
    ".planning/phases/mint-2-0-first-experience-rente-capital/STATE-TABLE.md": "3a0ab9ebd62db4a2c9d22d41edc2ea344e1dacfbb3cbb9cfe9974e16295f4e5e",
    ".planning/phases/mint-2-0-first-experience-rente-capital/TRANCHE-FIRSTJOB-SPEC.md": "6077d06a438bdd9be0f42122d15ca8cb9303354444c79f8e0fa3f270ecb467a0",
    ".planning/phases/mint-2-0-first-experience-rente-capital/VERIFICATION-REPORT.html": "5fb3319fe901eb18ae29e06fa85c120d1d4d9f969af6d9ecce08e69456f85bfb",
    ".planning/phases/mint-2-0-first-experience-rente-capital/VERIFICATION.md": "74896dbe334aed7d729dc7dd92ab9006802075dd1d19f29fef6c102c87ec6438",
    ".planning/phases/mint-2-0-first-experience-rente-capital/VZ_ROUTE_ARCHITECTURE.md": "a73f3b057651ebab288ed6abd53664bd4da35a46bbecb1c6e596dc5505612de7",
    ".planning/phases/mint-2-0-first-experience-rente-capital/golden-onboarding-archetypes.md": "3c354e1699f5fb2fbdbb143f798c87c63a35460963a891cb661322cc2b7367e8",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-01-contract-before-code-PLAN.md": "fd7bbf31436f67f03380a5afb80f59df92fe340114de3b89fd7b46acee8cea3c",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-02-entry-and-three-axes-code-map-PLAN.md": "f31d5f1fe839ebf2738a0a6106cdc3e964a29a4834d083a572b62e3a6fa90491",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-02a-data-dictionary-onboarding-profile-PLAN.md": "2e14e3050dade84788b56cb3042e28efaeeda6338c3dc393de91acb25e03dd53",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-02b-existing-variable-coverage-map-PLAN.md": "29ffd233c536fad3d58fcf270f006fffa8a23a211d4eaa2adff4e95aadbfc7b6",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-02c-variable-contract-lints-implementation-PLAN.md": "57bebb0e1228e195128715341cbd8defb5541897c09b2db26561e78b26bc6298",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-CONTEXT.md": "621bdc78bc574f243e1a220b12d2c3fe2d385e65594d3d8431bd5d306bced426",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-SUMMARY.md": "27b6d39ad843e3e8d3748a8c3120806106537d5744b7273c09eb736fdcfa2229",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-VERIFICATION.md": "7fd674df95137383a00df3b5d9feae88a124c64ca7208530426b2cac17190c91",
    ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/account_lifecycle_delete.json": "0b1fcf88726b120635a3d0083f0266908dee55408af752e9506c5ebde3abc6e7",
    ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/coach_advice_turn.json": "7277b4afa63435f65d3b56c70e88994f38fcc3abde8b2413658bc4e44215f463",
    ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/money_truth_spine.json": "d5f594ca367a67eb22d8e8c3cb74b43490baa619186701445c93af6b851c69dd",
    ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/onboarding_first_value.json": "87de04b9c8d3c047f5364693e9802864d169b9ae86cfd638760a1721322676ff",
    ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/profile_privacy_control.json": "8c0a0205fddc127c147389d300ab76272501ab1a56d5f87c4dabb9e1c4bf0814",
}

DEFAULT_BASELINE_REF = "707b25b815483ea20f77b065df9a47c63210f790"

PROTECTED_PRODUCT_PREFIXES = ("apps/mobile/", "services/backend/")
PROTECTED_EVIDENCE_PREFIXES = (
    ".planning/journeys/records/",
    ".planning/journeys/issues/",
    ".planning/journeys/evidence/",
    "tools/simulator/flows/",
)

ROUTER_SOURCE_ROLES = {
    ".planning/ACTIVE_CONTEXT.json": "governance_authority_verified",
    ".planning/ACTIVE_CONTEXT.md": "governance_authority_verified",
    ".planning/STATE.md": "governance_authority_verified",
    ".planning/ROADMAP.md": "governance_authority_verified",
    ".planning/INDEX.md": "governance_authority_verified",
}

# Only the live authority portion is normative.  Historical receipts legitimately
# contain old milestones and old "shipped" claims and must remain byte-preserved.
ACTIVE_SECTION_END = {
    ".planning/ACTIVE_CONTEXT.md": "## Not Active",
    ".planning/STATE.md": "## Historical Receipts",
    ".planning/ROADMAP.md": "## Soldage des gates legacy",
    ".planning/INDEX.md": "## `_archive/`",
}

ALLOWED_TRANSITION_PATHS = frozenset(
    {
        ".planning/ACTIVE_CONTEXT.json",
        ".planning/ACTIVE_CONTEXT.md",
        ".planning/STATE.md",
        ".planning/ROADMAP.md",
        ".planning/INDEX.md",
        f"{NEW_PHASE_DIR}/CONTEXT.md",
        f"{NEW_PHASE_DIR}/SPEC.md",
        f"{NEW_PHASE_DIR}/PLAN.md",
        f"{NEW_PHASE_DIR}/VERIFICATION.md",
        *(artifact["path"] for artifact in ROAST_ARTIFACTS.values()),
        "product/mint_next/batch4/architecture_conflicts.yaml",
        "product/mint_next/batch4/batch.yaml",
        "product/mint_next/batch4/README.md",
        "product/mint_next/batch4/source-inventory.yaml",
        "tools/checks/journey_os_check.py",
        "tools/checks/tests/test_journey_os_check.py",
        "tools/checks/mint_next_batch4_architecture_guard.py",
        "tools/checks/tests/test_mint_next_batch4_architecture_guard.py",
        "tools/checks/mint_next_authority_transition_guard.py",
        "tools/checks/tests/test_mint_next_authority_transition_guard.py",
    }
)


@dataclass(frozen=True)
class TransitionPolicy:
    baseline_ref: str = DEFAULT_BASELINE_REF
    audited_transition_head: str = AUDITED_TRANSITION_HEAD
    audited_transition_manifest: Mapping[str, str] = None  # type: ignore[assignment]
    roast_artifacts: Mapping[str, Mapping[str, str]] = None  # type: ignore[assignment]
    verify_rollback: bool = True
    legacy_manifest: Mapping[str, str] = None  # type: ignore[assignment]
    allowed_transition_paths: Set[str] = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        if self.audited_transition_manifest is None:
            object.__setattr__(self, "audited_transition_manifest", AUDITED_TRANSITION_MANIFEST)
        if self.roast_artifacts is None:
            object.__setattr__(self, "roast_artifacts", ROAST_ARTIFACTS)
        if self.legacy_manifest is None:
            object.__setattr__(self, "legacy_manifest", LEGACY_RETIREMENT_MANIFEST)
        if self.allowed_transition_paths is None:
            object.__setattr__(self, "allowed_transition_paths", ALLOWED_TRANSITION_PATHS)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(root: Path, args: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=root, text=True, capture_output=True, check=False
    )


def _changed_paths(root: Path, baseline_ref: str, errors: List[str]) -> Set[str]:
    if _git(root, ["cat-file", "-e", f"{baseline_ref}^{{commit}}"]).returncode != 0:
        errors.append(f"baseline ref does not resolve to a git commit: {baseline_ref}")
        return set()
    diff = _git(root, ["diff", "--name-only", baseline_ref, "--"])
    if diff.returncode != 0:
        errors.append(f"cannot compare transition with baseline {baseline_ref}: {diff.stderr.strip()}")
        return set()
    untracked = _git(root, ["ls-files", "--others", "--exclude-standard"])
    if untracked.returncode != 0:
        errors.append(f"cannot enumerate untracked files: {untracked.stderr.strip()}")
        return set()
    return {line for line in (diff.stdout + "\n" + untracked.stdout).splitlines() if line}


def _check_audited_transition_git(
    root: Path, policy: TransitionPolicy, errors: List[str]
) -> None:
    audited = policy.audited_transition_head
    if _git(root, ["cat-file", "-e", f"{audited}^{{commit}}"]).returncode != 0:
        errors.append(f"audited transition head does not resolve to a commit: {audited}")
        return
    for ancestor, descendant, label in (
        (policy.baseline_ref, audited, "baseline must be an ancestor of audited transition"),
        (audited, "HEAD", "audited transition must be an ancestor of accepted HEAD"),
    ):
        result = _git(root, ["merge-base", "--is-ancestor", ancestor, descendant])
        if result.returncode != 0:
            errors.append(f"{label}: {ancestor} -> {descendant}")

    diff = _git(root, ["diff", "--name-only", policy.baseline_ref, audited, "--"])
    if diff.returncode != 0:
        errors.append(f"cannot inspect audited transition diff: {diff.stderr.strip()}")
        return
    actual_paths = {line for line in diff.stdout.splitlines() if line}
    expected_paths = set(policy.audited_transition_manifest)
    if actual_paths != expected_paths:
        errors.append(
            "audited transition diff surface mismatch: "
            f"missing={sorted(expected_paths - actual_paths)!r}, "
            f"unexpected={sorted(actual_paths - expected_paths)!r}"
        )
    for relative, expected_hash in policy.audited_transition_manifest.items():
        blob = _git(root, ["show", f"{audited}:{relative}"])
        if blob.returncode != 0:
            errors.append(f"audited transition manifest path unreadable: {relative}")
            continue
        # Git's text mode would normalize/encode output. Read the exact blob bytes.
        exact = subprocess.run(
            ["git", "show", f"{audited}:{relative}"],
            cwd=root,
            capture_output=True,
            check=False,
        )
        if exact.returncode != 0 or hashlib.sha256(exact.stdout).hexdigest() != expected_hash:
            errors.append(f"audited transition manifest hash mismatch: {relative}")


def _check_rollback_reproducible(
    root: Path, baseline_ref: str, errors: List[str]
) -> None:
    """Prove the committed governance range can be reverse-applied exactly.

    The disposable local clone avoids touching the caller's index/worktree. It
    deliberately proves only the currently committed HEAD; dirty acceptance
    metadata still requires a fresh exact-HEAD run after commit.
    """
    with tempfile.TemporaryDirectory(prefix="mint-authority-rollback-") as temp:
        clone = Path(temp) / "repo"
        created = subprocess.run(
            ["git", "clone", "--quiet", "--no-hardlinks", str(root), str(clone)],
            text=True,
            capture_output=True,
            check=False,
        )
        if created.returncode != 0:
            errors.append(f"cannot create rollback proof clone: {created.stderr.strip()}")
            return
        reverted = _git(clone, ["revert", "--no-commit", f"{baseline_ref}..HEAD"])
        if reverted.returncode != 0:
            errors.append(
                "committed governance range is not cleanly revertible: "
                f"{reverted.stderr.strip()}"
            )
            return
        exact = _git(clone, ["diff", "--quiet", baseline_ref, "--"])
        if exact.returncode != 0:
            errors.append("rollback proof does not restore the exact baseline tracked tree")


def _load_yaml(path: Path, errors: List[str], label: str) -> object:
    if not path.is_file():
        errors.append(f"{label} missing: {path}")
        return None
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        errors.append(f"{label} is unreadable: {exc}")
        return None


def _check_legacy_manifest(root: Path, manifest: Mapping[str, str], errors: List[str]) -> None:
    expected = set(manifest)
    legacy_root = root / ".planning/phases" / OLD_MILESTONE
    actual = {
        path.relative_to(root).as_posix()
        for path in legacy_root.rglob("*")
        if path.is_file()
    } if legacy_root.is_dir() else set()
    for path in sorted(expected | actual):
        full = root / path
        if path not in expected:
            errors.append(f"legacy retirement baseline mismatch: unexpected file {path}")
        elif not full.is_file():
            errors.append(f"legacy retirement baseline mismatch: missing file {path}")
        elif _sha256(full) != manifest[path]:
            errors.append(f"legacy retirement baseline mismatch: byte hash changed for {path}")


def _check_router(root: Path, errors: List[str]) -> None:
    active_path = root / ".planning/ACTIVE_CONTEXT.json"
    try:
        active = json.loads(active_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        errors.append(f"ACTIVE_CONTEXT.json is unreadable: {exc}")
        return
    expected = {
        "active_milestone": NEW_MILESTONE,
        "active_phase_dir": NEW_PHASE_DIR,
        "active_phase_context": NEW_CONTEXT,
        "active_spec": NEW_SPEC,
        "next_product_phase_context": NEW_CONTEXT,
        "authority_mode": "governance-only",
        "successor_product_phase_queued": False,
    }
    for key, value in expected.items():
        if active.get(key) != value:
            errors.append(
                f"old-authority transition incomplete: ACTIVE_CONTEXT.json {key!r} "
                f"must be {value!r}, got {active.get(key)!r}"
            )
    historical = active.get("historical_not_active", [])
    preserved = active.get("preserved_runtime_vertical_not_global_authority", [])
    if OLD_MILESTONE not in historical:
        errors.append("old retirement milestone must be listed in historical_not_active")
    if OLD_MILESTONE not in preserved:
        errors.append(
            "old retirement milestone must be preserved_runtime_vertical_not_global_authority"
        )
    for path in (NEW_CONTEXT, NEW_SPEC, NEW_PLAN, NEW_VERIFICATION):
        if not (root / path).is_file():
            errors.append(f"canonical phase file missing: {path}")

    marker = AUTHORITY_MARKER.format(
        milestone=NEW_MILESTONE,
        phase_dir=NEW_PHASE_DIR,
        context=NEW_CONTEXT,
        spec=NEW_SPEC,
    )
    markdown_paths = (
        ".planning/ACTIVE_CONTEXT.md",
        ".planning/STATE.md",
        ".planning/ROADMAP.md",
        ".planning/INDEX.md",
    )
    for relative in markdown_paths:
        path = root / relative
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            errors.append(f"router document unreadable: {relative}: {exc}")
            continue
        if marker not in text:
            errors.append(f"router authority marker missing or inconsistent: {relative}")
        active_old_phrases = (
            f"Active milestone: `{OLD_MILESTONE}`",
            f"Active milestone: {OLD_MILESTONE}",
            f"milestone: {OLD_MILESTONE}",
            "Current operating phase is **Mint 2.0 first experience rente/capital**",
        )
        if any(phrase in text for phrase in active_old_phrases):
            errors.append(f"old retirement authority remains active in {relative}")
        _check_active_authority_semantics(relative, text, marker, errors)


def _active_section(relative: str, text: str) -> str:
    boundary = ACTIVE_SECTION_END[relative]
    return text.split(boundary, 1)[0]


def _check_active_authority_semantics(
    relative: str, text: str, expected_marker: str, errors: List[str]
) -> None:
    active = _active_section(relative, text)
    marker_count = active.count(expected_marker)
    if marker_count != 1:
        errors.append(
            f"active authority section must contain exactly one canonical marker: "
            f"{relative} has {marker_count}"
        )
    all_markers = re.findall(r"<!--\s*mint-authority:[\s\S]*?-->", active)
    if any(candidate != expected_marker for candidate in all_markers):
        errors.append(f"conflicting authority marker in active section: {relative}")

    # The canonical marker is necessary but not sufficient.  Reject an explicit
    # prose override even if an attacker leaves the marker in place.
    conflicting_claims = (
        r"\bbinding\s+override\b",
        r"\bactive\s+product\s+authority\b",
        r"\bsupersedes\s+the\s+governance\s+phase\b",
    )
    if any(re.search(pattern, active, flags=re.IGNORECASE) for pattern in conflicting_claims):
        errors.append(f"conflicting authority claim in active section: {relative}")

    expected_by_label = {
        "milestone": NEW_MILESTONE,
        "phase_dir": NEW_PHASE_DIR,
        "phase": NEW_PHASE_DIR,
        "context": NEW_CONTEXT,
        "spec": NEW_SPEC,
    }
    label_pattern = re.compile(
        r"^\s*(?:[-*]\s*)?(?:\*\*)?"
        r"(?P<label>(?:active\s+)?milestone|(?:active\s+)?phase[_ ]dir|"
        r"active\s+phase|active\s+context|active\s+spec)"
        r"(?:\*\*)?\s*[:=]\s*(?P<value>.+?)\s*$",
        flags=re.IGNORECASE | re.MULTILINE,
    )
    for match in label_pattern.finditer(active):
        label = re.sub(r"\s+", " ", match.group("label").lower()).strip()
        if label.startswith("active "):
            label = label[len("active ") :]
        label = label.replace(" ", "_")
        value = _normalize_authority_value(match.group("value"))
        expected = expected_by_label[label]
        if value != expected:
            errors.append(
                f"conflicting explicit {label} authority in active section: "
                f"{relative} has {value!r}, expected {expected!r}"
            )

    authority_phase_pattern = re.compile(
        r"\b(?:current|active)\s+authority\s+phase\s+is\s+([^,.\n]+)",
        flags=re.IGNORECASE,
    )
    for match in authority_phase_pattern.finditer(active):
        value = _normalize_authority_value(match.group(1))
        if value not in (NEW_MILESTONE, "MINT Next Architecture Authority"):
            errors.append(
                f"conflicting explicit authority phase in active section: "
                f"{relative} has {value!r}"
            )

    forbidden_completion = re.compile(
        r"\b(?:MINT\s+Next\s+is\s+)?(?:built|shipped|compliant|user[- ]validated)\b",
        flags=re.IGNORECASE,
    )
    if forbidden_completion.search(active):
        errors.append(f"forbidden completion claim in active section: {relative}")


def _normalize_authority_value(value: str) -> str:
    # Prefer the visible label from Markdown links: router docs deliberately use
    # repo-relative link targets while displaying the canonical root-relative path.
    value = re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", value)
    value = value.replace("`", "").replace("*", "")
    return value.strip().rstrip(". ")


def _check_roast_artifact(
    root: Path,
    name: str,
    roast: Mapping[str, object],
    artifact_contract: Mapping[str, str],
    audited_head: str,
    errors: List[str],
) -> None:
    path_value = artifact_contract.get("path")
    hash_value = artifact_contract.get("sha256")
    if roast.get("artifact_path") != path_value or roast.get("artifact_sha256") != hash_value:
        errors.append(f"transition roast {name!r} artifact receipt mismatch")
    if not isinstance(path_value, str) or not isinstance(hash_value, str):
        errors.append(f"transition roast {name!r} artifact contract is invalid")
        return
    path = root / path_value
    if not path.is_file() or _sha256(path) != hash_value:
        errors.append(f"transition roast {name!r} artifact hash mismatch")
        return
    artifact = _load_yaml(path, errors, f"transition roast {name!r} artifact")
    if not isinstance(artifact, dict):
        errors.append(f"transition roast {name!r} artifact must be a mapping")
        return
    expected_keys = {
        "schema_version", "advisory_id", "review", "claimed_context_label",
        "audited_head", "advisory_outcome", "reported_p1", "reported_p2",
        "limitation", "source", "captured_at", "checks",
    }
    if set(artifact) != expected_keys:
        errors.append(f"transition roast {name!r} artifact schema keys mismatch")
    expected_values = {
        "schema_version": 1,
        "advisory_id": roast.get("advisory_id"),
        "review": name,
        "claimed_context_label": roast.get("claimed_context_label"),
        "audited_head": audited_head,
        "advisory_outcome": "REPORTED_PASS",
        "reported_p1": 0,
        "reported_p2": 0,
        "limitation": roast.get("limitation"),
        "source": "untrusted_separate_context_review_report",
    }
    for key, value in expected_values.items():
        if artifact.get(key) != value:
            errors.append(f"transition roast {name!r} artifact {key!r} mismatch")
    captured_at = artifact.get("captured_at")
    if not isinstance(captured_at, str) or not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", captured_at
    ):
        errors.append(f"transition roast {name!r} artifact captured_at is invalid")
    checks = artifact.get("checks")
    if not isinstance(checks, list) or not checks:
        errors.append(f"transition roast {name!r} artifact checks must be nonempty")
        return
    for index, check in enumerate(checks):
        if not isinstance(check, dict) or set(check) != {"command", "exit", "evidence"}:
            errors.append(f"transition roast {name!r} check {index} schema mismatch")
            continue
        if (
            not isinstance(check.get("command"), str)
            or not check["command"].strip()
            or check.get("exit") != 0
            or not isinstance(check.get("evidence"), str)
            or not check["evidence"].strip()
        ):
            errors.append(f"transition roast {name!r} check {index} is not passing evidence")


def _check_no_trust_overclaim(root: Path, errors: List[str]) -> None:
    documents = (
        f"{NEW_PHASE_DIR}/CONTEXT.md",
        f"{NEW_PHASE_DIR}/PLAN.md",
        f"{NEW_PHASE_DIR}/SPEC.md",
        f"{NEW_PHASE_DIR}/VERIFICATION.md",
        ".planning/STATE.md",
        "product/mint_next/batch4/architecture_conflicts.yaml",
    )
    # Explicit negations such as "not authenticated" are required honesty, not
    # overclaims. These patterns target only affirmative acceptance language.
    forbidden = (
        r"\bthree\s+independent\b",
        r"\bindependent(?:ly)?\s+(?:accepted|verified|audited|reviewed|authenticated)\b",
        r"\b(?:reviewer\s+)?independence\s+(?:is|was|has\s+been)\s+(?:established|verified|proven)\b",
        r"\bauthenticated\s+(?:reviewer|identity|receipt|evidence|attestation)\b(?!\s+(?:is|are)\s+(?:absent|unavailable))",
        r"\bauthentication\s+(?:is|was|has\s+been)\s+(?:established|verified|proven)\b",
        r"\bsigned\s+(?:receipt|report|evidence|attestation)\b",
        r"\bsignature\s+(?:is|was)\s+(?:valid|verified|present)\b",
        r"\btamper[- ]proof\b",
        r"\bcryptographically\s+(?:authenticated|verified|signed|protected|immutable)\b",
        r"\bexternal\s+attestation\s+(?:exists|is\s+present|is\s+verified)\b",
        r"^##\s+Independent\s+(?:Roast|Review|Audit)",
        r"\badvisory\s+reports?\s+(?:are|form|provide|constitute)\s+(?:the\s+)?acceptance\s+(?:basis|proof|evidence)\b",
    )
    for relative in documents:
        path = root / relative
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            errors.append(f"trust-boundary document unreadable: {relative}: {exc}")
            continue
        if relative == ".planning/STATE.md":
            text = _active_section(relative, text)
        for pattern in forbidden:
            for match in re.finditer(pattern, text, flags=re.IGNORECASE | re.MULTILINE):
                prefix = text[max(0, match.start() - 180) : match.start()]
                # Allow explicit denial across a short wrapped sentence, e.g.
                # "no external signature ... or external attestation exists".
                # A sentence break or adversative clause ends that negation.
                clause = re.split(r"[.;!?]|\b(?:but|however)\b", prefix, flags=re.IGNORECASE)[-1]
                if re.search(r"\b(?:no|not|never|neither|without)\b", clause, re.IGNORECASE):
                    continue
                errors.append(
                    f"forbidden acceptance trust overclaim in {relative}: {pattern}"
                )
                break


def _check_conflict(root: Path, policy: TransitionPolicy, errors: List[str]) -> None:
    audited_head = policy.audited_transition_head
    conflict_path = root / "product/mint_next/batch4/architecture_conflicts.yaml"
    try:
        conflict_text = conflict_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        errors.append(f"Batch4 conflict registry is unreadable: {exc}")
        return
    for key in ("resolution_required", "batch4_promotion"):
        occurrences = re.findall(rf"(?m)^\s*{re.escape(key)}\s*:", conflict_text)
        if len(occurrences) != 1:
            errors.append(
                f"Batch4 conflict registry must contain exactly one {key!r} field; "
                f"found {len(occurrences)}"
            )
    data = _load_yaml(
        conflict_path,
        errors,
        "Batch4 conflict registry",
    )
    if not isinstance(data, dict) or not isinstance(data.get("conflicts"), list):
        errors.append("Batch4 conflict registry must contain conflicts[]")
        return
    conflict = next(
        (item for item in data["conflicts"] if isinstance(item, dict) and item.get("id") == "retirement_first_active_context"),
        None,
    )
    expected_status = "resolved_for_governance_routing_only"
    if not conflict or conflict.get("status") != expected_status:
        errors.append(
            "retirement-first conflict is not at the accepted transition "
            f"lifecycle: expected {expected_status!r}"
        )
        return
    resolution = conflict.get("resolution")
    expected = {
        "kind": "governance_authority_transition",
        "authority_milestone": NEW_MILESTONE,
        "legacy_disposition": "preserved_runtime_vertical_not_global_authority",
    }
    if not isinstance(resolution, dict):
        errors.append("retirement-first conflict lacks a structured resolution")
        return
    for key, value in expected.items():
        if resolution.get(key) != value:
            errors.append(f"retirement-first conflict resolution {key!r} must be {value!r}")
    evidence = resolution.get("evidence")
    required_evidence = {
        ".planning/ACTIVE_CONTEXT.json",
        ".planning/ACTIVE_CONTEXT.md",
        ".planning/STATE.md",
        ".planning/ROADMAP.md",
        ".planning/INDEX.md",
    }
    if not isinstance(evidence, list) or not required_evidence.issubset(set(evidence)):
        errors.append("retirement-first conflict resolution evidence is incomplete")
    verification = resolution.get("verification")
    if not isinstance(verification, dict):
        errors.append("resolved transition requires structured resolution.verification")
        return
    expected_verification = {
        "audited_head": audited_head,
        "accepted_scope": "governance_authority_only",
        "batch4_promotion": False,
        "successor_product_phase_queued": False,
        "trust_basis": "reproducible_deterministic_git_evidence_only",
        "external_attestation": "absent",
        "cross_provider_review": "absent",
        "cross_provider_review_scope": (
            "diversity_only_not_authenticated_or_cryptographic_identity"
        ),
        "batch4_promotion_gate": (
            "blocked_pending_external_attestation_or_cross_provider_review"
        ),
    }
    expected_verification_keys = set(expected_verification) | {"advisory_reports"}
    if set(verification) != expected_verification_keys:
        errors.append(
            "transition verification schema must contain only deterministic trust "
            "fields and advisory_reports"
        )
    for key, value in expected_verification.items():
        if verification.get(key) != value:
            errors.append(f"transition verification {key!r} must be {value!r}")
    roasts = verification.get("advisory_reports")
    if not isinstance(roasts, list):
        errors.append("transition advisory_reports must be a list")
        return
    by_name = {
        roast.get("name"): roast
        for roast in roasts
        if isinstance(roast, dict) and isinstance(roast.get("name"), str)
    }
    if set(by_name) != set(REQUIRED_ROASTS) or len(roasts) != len(REQUIRED_ROASTS):
        errors.append(
            "transition verification must contain exactly the three named untrusted advisory reports"
        )
    for name, (expected_reviewer, expected_evidence) in sorted(REQUIRED_ROASTS.items()):
        roast = by_name.get(name)
        if not isinstance(roast, dict):
            continue
        expected_advisory_keys = {
            "name", "advisory_id", "artifact_path", "artifact_sha256",
            "claimed_context_label", "advisory_outcome", "reported_p1",
            "reported_p2", "audited_head", "limitation", "trust",
        }
        if set(roast) != expected_advisory_keys:
            errors.append(f"transition advisory {name!r} schema keys mismatch")
        if roast.get("advisory_outcome") != "REPORTED_PASS":
            errors.append(f"transition advisory {name!r} outcome must be REPORTED_PASS")
        if roast.get("reported_p1") != 0 or roast.get("reported_p2") != 0:
            errors.append(
                f"transition advisory {name!r} must report p1=0 and p2=0"
            )
        if roast.get("audited_head") != audited_head:
            errors.append(f"transition roast {name!r} audited_head mismatch")
        if roast.get("claimed_context_label") != expected_reviewer:
            errors.append(f"transition advisory {name!r} claimed_context_label mismatch")
        if roast.get("advisory_id") != expected_evidence:
            errors.append(f"transition advisory {name!r} advisory_id mismatch")
        if roast.get("trust") != "untrusted_advisory_only":
            errors.append(f"transition advisory {name!r} must be untrusted_advisory_only")
        artifact_contract = policy.roast_artifacts.get(name)
        if not isinstance(artifact_contract, Mapping):
            errors.append(f"transition roast {name!r} artifact contract missing")
        else:
            _check_roast_artifact(
                root, name, roast, artifact_contract, audited_head, errors
            )

    expected_resolution_claim = (
        "Satisfied for governance routing only from reproducible deterministic "
        "evidence; Batch 4 promotion remains blocked pending external "
        "attestation or cross-provider review."
    )
    if conflict.get("resolution_required") != expected_resolution_claim:
        errors.append(
            "retirement-first conflict must contain exactly one canonical "
            "governance-only satisfaction claim"
        )


def _single_receipt_value(
    text: str, pattern: str, label: str, expected: str, errors: List[str]
) -> None:
    values = re.findall(pattern, text, flags=re.MULTILINE | re.IGNORECASE)
    if values != [expected]:
        errors.append(
            f"accepted phase VERIFICATION must contain exactly one {label}={expected!r}; "
            f"found {values!r}"
        )


def _check_accepted_documents(root: Path, audited_head: str, errors: List[str]) -> None:
    verification_path = root / NEW_VERIFICATION
    state_path = root / ".planning/STATE.md"
    try:
        verification = verification_path.read_text(encoding="utf-8")
        state = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        errors.append(f"accepted transition document unreadable: {exc}")
        return
    receipt_fields = (
        (
            r"^Status:\s*\*\*(.+?)\*\*\s*$",
            "status",
            "ACCEPTED — GOVERNANCE AUTHORITY ONLY",
        ),
        (r"^Audited transition head:\s*`([^`]+)`\s*$", "audited head", audited_head),
        (r"^Accepted scope:\s*`([^`]+)`\s*$", "accepted scope", "governance_authority_only"),
        (r"^Batch 4 promotion:\s*\*\*(true|false)\*\*\s*$", "Batch 4 promotion", "false"),
    )
    for pattern, label, expected in receipt_fields:
        _single_receipt_value(verification, pattern, label, expected, errors)

    state_statuses = re.findall(r"(?m)^status:\s*([^\s#]+)\s*$", state)
    if state_statuses != ["governance-authority-accepted"]:
        errors.append("STATE must record exactly one status: governance-authority-accepted")
    state_heads = re.findall(
        r"(?m)^accepted_transition_head:\s*[\"']?([0-9a-f]{40})[\"']?\s*$", state
    )
    if state_heads != [audited_head]:
        errors.append("STATE must record exactly one exact accepted_transition_head")


def _check_batch_remains_draft(root: Path, errors: List[str]) -> None:
    data = _load_yaml(root / "product/mint_next/batch4/batch.yaml", errors, "Batch4 batch contract")
    if not isinstance(data, dict):
        errors.append("Batch4 batch contract must be a mapping")
        return
    if data.get("status") != "draft_unproven":
        errors.append("Batch4 must remain draft_unproven during the authority transition")
    if data.get("promotion_receipt") is not None:
        errors.append("draft batch must not claim a promotion receipt")


def _check_router_source_inventory(root: Path, errors: List[str]) -> None:
    data = _load_yaml(
        root / "product/mint_next/batch4/source-inventory.yaml",
        errors,
        "Batch4 source inventory",
    )
    sources = data.get("sources") if isinstance(data, dict) else None
    if not isinstance(sources, list):
        errors.append("router source inventory must contain sources[]")
        return
    by_path = {
        item.get("path"): item
        for item in sources
        if isinstance(item, dict) and isinstance(item.get("path"), str)
    }
    for relative, expected_role in ROUTER_SOURCE_ROLES.items():
        item = by_path.get(relative)
        if not isinstance(item, dict):
            errors.append(f"router source inventory missing: {relative}")
            continue
        if item.get("role") != expected_role:
            errors.append(
                f"router source inventory role mismatch: {relative} must be {expected_role!r}"
            )
        digest = item.get("sha256")
        full = root / relative
        if (
            not full.is_file()
            or not isinstance(digest, str)
            or len(digest) != 64
            or _sha256(full) != digest
        ):
            errors.append(f"router source inventory hash mismatch: {relative}")


def run_guard(root: Path, policy: Optional[TransitionPolicy] = None) -> List[str]:
    policy = policy or TransitionPolicy()
    errors: List[str] = []
    _check_audited_transition_git(root, policy, errors)
    if policy.verify_rollback:
        _check_rollback_reproducible(root, policy.baseline_ref, errors)
    _check_legacy_manifest(root, policy.legacy_manifest, errors)
    changed = _changed_paths(root, policy.baseline_ref, errors)
    for path in sorted(changed):
        if path not in policy.allowed_transition_paths:
            errors.append(f"path outside governance transition allowlist changed: {path}")
        if path.startswith(PROTECTED_PRODUCT_PREFIXES):
            errors.append(f"product/runtime path changed during governance transition: {path}")
        if path.startswith(PROTECTED_EVIDENCE_PREFIXES):
            errors.append(f"Journey OS/runtime evidence changed during governance transition: {path}")
    _check_router(root, errors)
    _check_conflict(root, policy, errors)
    _check_no_trust_overclaim(root, errors)
    _check_accepted_documents(root, policy.audited_transition_head, errors)
    _check_batch_remains_draft(root, errors)
    _check_router_source_inventory(root, errors)
    return errors


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--baseline-ref", default=DEFAULT_BASELINE_REF)
    args = parser.parse_args(argv)
    errors = run_guard(args.root.resolve(), TransitionPolicy(baseline_ref=args.baseline_ref))
    if errors:
        print("MINT NEXT AUTHORITY TRANSITION GUARD: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("MINT NEXT AUTHORITY TRANSITION GUARD: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
