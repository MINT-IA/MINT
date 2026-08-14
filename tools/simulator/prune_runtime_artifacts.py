#!/usr/bin/env python3
"""Prune old, untracked simulator artefacts without deleting cited evidence."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import time
from pathlib import Path


DEFAULT_ROOTS = (
    ".planning/runtime-evidence",
    ".planning/walker",
    ".planning/_walker",
)


def _git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=repo, text=True, capture_output=True, check=False
    )


def _protected_names(repo: Path, root: str) -> tuple[set[str], str]:
    """Noms protégés pour cette racine, ET la sortie brute du grep.

    La sortie brute sert de second filet : la regex n'accepte que
    `[A-Za-z0-9._-]`, donc un répertoire « run Zurich » cité dans un document
    ne protégeait que « run » — et « run Zurich » se faisait effacer. MINT est
    une application française ; les noms accentués ne sont pas une hypothèse
    d'école. On protège donc aussi tout nom d'entrée qui APPARAÎT dans un
    fichier suivi, quels que soient ses caractères.

    Sur-protéger est le bon sens de l'erreur pour un outil qui supprime.
    """
    root_path = Path(root)
    relative = root_path.as_posix().removeprefix(".planning/")
    grep = _git(
        repo,
        "grep",
        "-I",
        "-h",
        "-E",
        rf"(\.planning/)?{re.escape(relative)}/",
        "--",
        ".",
    )
    if grep.returncode not in (0, 1):
        raise SystemExit(grep.stderr.strip() or "git grep failed")
    pattern = re.compile(
        rf"(?<![A-Za-z0-9_.-])(?:\.planning/)?{re.escape(relative)}/"
        r"([A-Za-z0-9._-]+)"
    )
    cited = {match.group(1) for match in pattern.finditer(grep.stdout)}

    tracked = _git(repo, "ls-files", f"{root_path.as_posix()}/*")
    if tracked.returncode != 0:
        raise SystemExit(tracked.stderr.strip() or "git ls-files failed")
    for path in tracked.stdout.splitlines():
        parts = Path(path).parts
        root_parts = root_path.parts
        if len(parts) > len(root_parts):
            cited.add(parts[len(root_parts)])
    return cited, grep.stdout


def _usable_root(repo: Path, root: str) -> Path | None:
    """La racine, si et seulement si l'élaguer reste DANS le dépôt.

    LE DÉFAUT QUE CETTE FONCTION EXISTE POUR EMPÊCHER
    (trouvé par un axe adverse le 2026-08-14, après que j'ai affirmé à tort
    que les liens symboliques n'étaient jamais suivis)

    Les entrées étaient bien gardées par `not entry.is_symlink()`. La RACINE
    ne l'était pas. Si `.planning/runtime-evidence` est elle-même un lien vers
    un répertoire externe, `is_dir()` le suit, `iterdir()` parcourt la cible,
    et `shutil.rmtree` détruit pour de bon des données hors dépôt.

    Une racine relative contenant `..` sortait du dépôt de la même façon dès
    qu'on appelait `prune()` directement.
    """
    directory = repo / root
    if directory.is_symlink():
        print(f"IGNORÉ (racine symbolique) {root}")
        return None
    if not directory.is_dir():
        return None
    resolved = directory.resolve()
    if not resolved.is_relative_to(repo.resolve()):
        print(f"IGNORÉ (racine hors dépôt) {root}")
        return None
    return directory


def prune(repo: Path, roots: tuple[str, ...], days: int, apply: bool) -> int:
    # Le garde-fou vivait dans main(). Un appel direct à prune(days=0)
    # effaçait tout : la borne appartient à la fonction qui supprime.
    if days < 1:
        raise ValueError("days doit valoir au moins 1")

    cutoff = time.time() - days * 24 * 60 * 60
    removed = 0
    mode = "APPLY" if apply else "DRY-RUN"

    # TOUTES les protections sont collectées AVANT la première suppression.
    # Auparavant, un échec de git à la deuxième racine levait SystemExit —
    # après que la première ait déjà été vidée. Un outil qui supprime doit
    # savoir tout ce qu'il doit épargner avant de toucher quoi que ce soit.
    plan: list[tuple[Path, set[str], str]] = []
    for root in roots:
        directory = _usable_root(repo, root)
        if directory is None:
            continue
        protected, grep_raw = _protected_names(repo, root)
        plan.append((directory, protected, grep_raw))

    for directory, protected, grep_raw in plan:
        for entry in sorted(directory.iterdir()):
            try:
                mtimes = [entry.lstat().st_mtime]
                if entry.is_dir() and not entry.is_symlink():
                    mtimes.extend(
                        child.lstat().st_mtime
                        for child in entry.rglob("*")
                        if child.exists()
                    )
                newest_mtime = max(mtimes)
            except FileNotFoundError:
                # Another explicitly-started prune may have removed it first.
                continue
            # `entry.name in grep_raw` est le second filet : il rattrape les
            # noms que la regex ne sait pas lire — espaces, accents, Unicode.
            if (
                entry.name in protected
                or entry.name in grep_raw
                or newest_mtime >= cutoff
            ):
                continue
            print(f"{mode} {entry.relative_to(repo)}")
            removed += 1
            if apply:
                if entry.is_dir() and not entry.is_symlink():
                    shutil.rmtree(entry)
                else:
                    entry.unlink()

    print(f"{mode}: {removed} old unreferenced artefact(s)")
    return removed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.days < 1:
        parser.error("--days must be at least 1")
    prune(args.repo.resolve(), DEFAULT_ROOTS, args.days, args.apply)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
