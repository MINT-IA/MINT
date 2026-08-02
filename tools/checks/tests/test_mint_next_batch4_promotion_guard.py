from __future__ import annotations

import copy
import importlib.util
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml


REPO = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location(
    "promotion_guard", REPO / "tools/checks/mint_next_batch4_promotion_guard.py"
)
assert SPEC and SPEC.loader
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)
ARCH_SPEC = importlib.util.spec_from_file_location(
    "architecture_guard", REPO / "tools/checks/mint_next_batch4_architecture_guard.py"
)
assert ARCH_SPEC and ARCH_SPEC.loader
architecture_guard = importlib.util.module_from_spec(ARCH_SPEC)
ARCH_SPEC.loader.exec_module(architecture_guard)


@pytest.fixture(scope="module")
def clone(tmp_path_factory: pytest.TempPathFactory) -> Path:
    root = tmp_path_factory.mktemp("promotion-guard") / "repo"
    subprocess.run(
        ["git", "clone", "--quiet", "--shared", str(REPO), str(root)], check=True
    )
    # The readiness/phase files may be deliberately uncommitted in the parent
    # batch. Copy them so tests exercise the exact working-tree contract.
    for relative in [guard.READINESS, Path(guard.PHASE_DIR)]:
        source, target = REPO / relative, root / relative
        if source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True)
        elif source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for relative in (Path(".planning/ACTIVE_CONTEXT.json"),):
        shutil.copy2(REPO / relative, root / relative)
    for relative in map(Path, guard.CANONICAL):
        shutil.copy2(REPO / relative, root / relative)
    return root


@pytest.fixture(autouse=True)
def reset(clone: Path):
    subprocess.run(["git", "reset", "--hard", "HEAD"], cwd=clone, check=True, capture_output=True)
    subprocess.run(["git", "clean", "-fd"], cwd=clone, check=True, capture_output=True)
    for relative in [guard.READINESS, Path(guard.PHASE_DIR), Path(".planning/ACTIVE_CONTEXT.json")]:
        source, target = REPO / relative, clone / relative
        if source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True)
        elif source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for relative in map(Path, guard.CANONICAL):
        shutil.copy2(REPO / relative, clone / relative)


def _mutate_yaml(root: Path, relative: Path, mutation) -> None:
    path = root / relative
    data = yaml.safe_load(path.read_text())
    mutation(data)
    path.write_text(yaml.safe_dump(data, sort_keys=False))


def test_exact_blocked_readiness_passes(clone: Path) -> None:
    assert guard.validate(clone) == []


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("promotion_eligible", True),
        ("selected_gate", "external_attestation"),
        ("candidate_head", "f" * 40),
        ("promotion_receipt", {"head": "f" * 40}),
        ("status", "promoted"),
    ],
)
def test_rejects_fake_promotion_fields(clone: Path, key: str, value: object) -> None:
    _mutate_yaml(clone, guard.READINESS, lambda data: data.__setitem__(key, value))
    assert guard.validate(clone)


def test_rejects_present_gate(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: data["gates"].__setitem__("cross_provider_review", "present"),
    )
    assert guard.validate(clone)


def test_rejects_coordinated_canonical_rewrite(clone: Path) -> None:
    registry = clone / "product/mint_next/batch4/concepts.yaml"
    registry.write_text(registry.read_text() + "\n# forged\n")
    forged = guard._sha(registry)
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: next(
            item for item in data["manifests"]["canonical_registries"]["entries"]
            if item["path"].endswith("concepts.yaml")
        ).__setitem__("sha256", forged),
    )
    assert any("canonical registry" in error for error in guard.validate(clone))


@pytest.mark.parametrize(
    "relative",
    [
        "apps/mobile/lib/main.dart",
        ".planning/journeys/BOARD.md",
        ".planning/phases/mint-2-0-first-experience-rente-capital/CONTEXT.md",
        "tools/simulator/README.md",
    ],
)
def test_rejects_protected_surface_mutation(clone: Path, relative: str) -> None:
    path = clone / relative
    path.write_text(path.read_text() + "\nforged\n")
    assert any("surface drift" in error for error in guard.validate(clone))


def test_rejects_untracked_file_in_protected_surface(clone: Path) -> None:
    path = clone / ".planning/journeys/forged.yaml"
    path.write_text("fake: true\n")
    assert any("untracked file" in error for error in guard.validate(clone))


def test_rejects_formula_implementation(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.FORMULAS,
        lambda data: data["formulas"][0].__setitem__("status", "implemented"),
    )
    assert any("19 formulas" in error for error in guard.validate(clone))


def test_rejects_product_or_compliance_overclaim(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: data["claim_boundary"].__setitem__("regulatory_compliance", True),
    )
    assert any("overclaims" in error for error in guard.validate(clone))


def test_rejects_router_split_brain(clone: Path) -> None:
    _mutate_yaml(
        clone, Path(".planning/ACTIVE_CONTEXT.json"),
        lambda data: data.__setitem__("active_milestone", "old-phase"),
    )
    assert any("router mismatch" in error for error in guard.validate(clone))


def test_architecture_guard_rejects_router_mutation_preserving_phase(clone: Path) -> None:
    path = clone / ".planning/ACTIVE_CONTEXT.md"
    path.write_text(path.read_text() + "\nforged but same active milestone\n")
    assert any(
        "source inventory hash drift: .planning/ACTIVE_CONTEXT.md" in error
        for error in architecture_guard.validate(clone)
    )


def test_rejects_duplicate_yaml_key(clone: Path) -> None:
    path = clone / guard.READINESS
    path.write_text(path.read_text() + "status: promoted\n")
    assert any("duplicate YAML key" in error for error in guard.validate(clone))


def test_rejects_manifest_path_traversal(clone: Path) -> None:
    _mutate_yaml(
        clone, guard.READINESS,
        lambda data: data["manifests"]["product"]["path_prefixes"].append("../"),
    )
    assert any("product manifest mismatch" in error for error in guard.validate(clone))


def test_rejects_symlink_in_protected_surface(clone: Path) -> None:
    path = clone / ".planning/journeys/BOARD.md"
    path.unlink()
    path.symlink_to("TODAY.md")
    assert any("symlinked" in error for error in guard.validate(clone))
