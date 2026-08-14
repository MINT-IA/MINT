from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path


SCRIPT = Path(__file__).with_name("prune_runtime_artifacts.py")


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)


def _init_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "test@example.com")
    _git(repo, "config", "user.name", "Test")
    (repo / ".gitignore").write_text(".planning/runtime-evidence/\n")
    (repo / "proof.md").write_text(
        "preuve: .planning/runtime-evidence/keep-me/result.xml\n"
    )
    _git(repo, "add", ".gitignore", "proof.md")
    _git(repo, "commit", "-qm", "fixture")
    return repo


def _old(path: Path) -> None:
    timestamp = time.time() - 30 * 24 * 60 * 60
    if path.is_dir() and not path.is_symlink():
        for child in path.rglob("*"):
            os.utime(child, (timestamp, timestamp), follow_symlinks=False)
    os.utime(path, (timestamp, timestamp), follow_symlinks=False)


def test_apply_removes_only_old_unreferenced_artifacts(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    root = repo / ".planning/runtime-evidence"
    keep = root / "keep-me"
    old = root / "delete-me"
    recent = root / "recent"
    for directory in (keep, old, recent):
        directory.mkdir(parents=True)
        (directory / "result.xml").write_text("artifact")
    _old(keep)
    _old(old)

    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "14", "--apply"],
        check=True,
        capture_output=True,
        text=True,
    )

    assert keep.exists(), "a tracked proof reference must protect its artifact"
    assert not old.exists(), "old unreferenced runtime sediment must be removed"
    assert recent.exists(), "recent artifacts stay available for diagnosis"
    assert "delete-me" in result.stdout


def test_dry_run_is_the_default(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    old = repo / ".planning/runtime-evidence/delete-me"
    old.mkdir(parents=True)
    _old(old)

    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "14"],
        check=True,
        capture_output=True,
        text=True,
    )

    assert old.exists()
    assert "DRY-RUN" in result.stdout


def test_fresh_descendant_protects_an_old_run_directory(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    run = repo / ".planning/runtime-evidence/active-run"
    run.mkdir(parents=True)
    _old(run)
    (run / "still-writing.log").write_text("fresh")

    subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "14", "--apply"],
        check=True,
        capture_output=True,
        text=True,
    )

    assert run.exists(), "fresh nested output means the run is still active"


def test_symlink_is_unlinked_without_following_its_target(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    target = tmp_path / "outside"
    target.mkdir()
    (target / "keep.txt").write_text("keep")
    link = repo / ".planning/runtime-evidence/old-link"
    link.parent.mkdir(parents=True)
    link.symlink_to(target, target_is_directory=True)
    _old(link)

    subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "14", "--apply"],
        check=True,
        capture_output=True,
        text=True,
    )

    assert not link.is_symlink()
    assert (target / "keep.txt").read_text() == "keep"


def test_zero_day_retention_is_rejected(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "0", "--apply"],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "at least 1" in result.stderr


# ─────────────────────────────────────────────────────────────────────────
# TROIS CHEMINS DESTRUCTIFS, TROUVÉS PAR UN AXE ADVERSE LE 2026-08-14.
#
# Les cinq tests ci-dessus couvraient l'artefact symbolique INTERNE, que
# unlink() traite bien. Ils ne couvraient ni la racine symbolique, ni les
# noms que la regex ne sait pas lire, ni l'appel direct à prune().
# ─────────────────────────────────────────────────────────────────────────


def test_racine_symbolique_refusee_et_cible_externe_intacte(tmp_path: Path) -> None:
    """LE PIRE CAS : la racine elle-même est un lien vers l'extérieur.

    `is_dir()` suit le lien, `iterdir()` parcourt la cible, et `rmtree`
    détruisait pour de bon des données hors dépôt. Les entrées étaient
    gardées ; la racine ne l'était pas.
    """
    repo = _init_repo(tmp_path)
    dehors = tmp_path / "dehors"
    (dehors / "precieux").mkdir(parents=True)
    (dehors / "precieux" / "irremplacable.txt").write_text("ne pas effacer")
    _old(dehors / "precieux")

    root = repo / ".planning/runtime-evidence"
    if root.exists():
        for child in sorted(root.iterdir()):
            child.unlink() if child.is_file() else None
        root.rmdir()
    root.parent.mkdir(parents=True, exist_ok=True)
    root.symlink_to(dehors, target_is_directory=True)

    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "1", "--apply"],
        capture_output=True,
        text=True,
        check=True,
    )

    assert (dehors / "precieux" / "irremplacable.txt").exists(), (
        "une racine symbolique a laissé l'élagueur sortir du dépôt et "
        "détruire des données externes"
    )
    assert "racine symbolique" in proc.stdout, (
        "le refus doit être DIT, sinon un silence ressemble à un élagage réussi"
    )


def test_nom_avec_espace_cite_est_protege(tmp_path: Path) -> None:
    """La regex n'accepte que [A-Za-z0-9._-].

    Un répertoire « run Zurich » cité dans un document ne protégeait que
    « run », puis « run Zurich » se faisait effacer. MINT est une application
    française — les noms accentués et espacés ne sont pas une hypothèse.
    """
    repo = _init_repo(tmp_path)
    (repo / "cite.md").write_text(
        "preuve: .planning/runtime-evidence/run Zurich/result.xml\n"
        "preuve: .planning/runtime-evidence/marche-genève/result.xml\n"
    )
    _git(repo, "add", "cite.md")
    _git(repo, "commit", "-qm", "citations difficiles")

    root = repo / ".planning/runtime-evidence"
    for nom in ("run Zurich", "marche-genève"):
        (root / nom).mkdir(parents=True, exist_ok=True)
        (root / nom / "result.xml").write_text("<testsuite/>")
        _old(root / nom)

    subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), "--days", "1", "--apply"],
        capture_output=True,
        text=True,
        check=True,
    )

    assert (root / "run Zurich").exists(), "un espace ne doit pas déprotéger"
    assert (root / "marche-genève").exists(), "un accent non plus"


def test_appel_direct_avec_zero_jour_leve_au_lieu_de_tout_effacer(
    tmp_path: Path,
) -> None:
    """Le garde-fou vivait dans main(), donc pas dans la fonction qui supprime.

    prune(days=0) fixait la limite à « maintenant » : tout devenait vieux.
    """
    import importlib.util

    spec = importlib.util.spec_from_file_location("prune_mod", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)

    repo = _init_repo(tmp_path)
    fragile = repo / ".planning/runtime-evidence" / "tout-neuf"
    fragile.mkdir(parents=True, exist_ok=True)
    (fragile / "result.xml").write_text("<testsuite/>")

    try:
        module.prune(repo, (".planning/runtime-evidence",), 0, True)
        raise AssertionError("prune(days=0) doit lever, pas supprimer")
    except ValueError:
        pass

    assert fragile.exists(), "rien ne doit avoir été supprimé avant la levée"
