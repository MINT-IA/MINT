#!/usr/bin/env python3
"""Offline verifier/reconstructor for immutable MINT Next artifact snapshots."""

from __future__ import annotations

import argparse
import hashlib
import os
import stat
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

import yaml


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CAS = ROOT / "product/mint_next/evidence/blobs/sha256"
ALLOWED_MODES = {"100644", "100755"}
ALLOWED_ROLES = {"asset", "config", "evidence", "generated", "license", "source", "test"}


class _UniqueKeyLoader(yaml.SafeLoader):
    pass


def _construct_unique_mapping(loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False) -> dict[object, object]:
    mapping: dict[object, object] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise ValueError(f"duplicate YAML key: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


_UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_unique_mapping,
)


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest_file(path: Path) -> str:
    return digest_bytes(path.read_bytes())


@dataclass(frozen=True)
class Entry:
    path: str
    mode: str
    size: int
    sha256: str
    role: str


@dataclass(frozen=True)
class Snapshot:
    artifact_id: str
    accepted_commit: str
    accepted_tree: str
    root: Path
    closure_count: int
    excluded: tuple[str, ...]
    toolchain_inputs: tuple[str, ...]
    entries: tuple[Entry, ...]


def _safe_relative(value: object) -> str | None:
    if not isinstance(value, str) or not value:
        return None
    raw_parts = value.split("/")
    if any(part in {"", ".", ".."} for part in raw_parts):
        return None
    pure = PurePosixPath(value)
    if pure.is_absolute() or "\\" in value:
        return None
    return pure.as_posix()


def load_manifest(manifest_path: Path, repo_root: Path = ROOT) -> tuple[Snapshot | None, list[str]]:
    errors: list[str] = []
    try:
        raw = yaml.load(manifest_path.read_text(encoding="utf-8"), Loader=_UniqueKeyLoader)
    except (OSError, TypeError, ValueError, yaml.YAMLError) as exc:
        return None, [f"cannot read artifact manifest: {exc}"]
    if not isinstance(raw, dict) or raw.get("schema_version") != 1:
        return None, ["artifact manifest schema_version must be 1"]
    artifact_id = raw.get("artifact_id")
    accepted_commit = raw.get("accepted_commit")
    accepted_tree = raw.get("accepted_tree")
    root_value = _safe_relative(raw.get("root"))
    if not isinstance(artifact_id, str) or not artifact_id:
        errors.append("artifact manifest missing artifact_id")
    for label, value in (("accepted_commit", accepted_commit), ("accepted_tree", accepted_tree)):
        if not isinstance(value, str) or len(value) != 40 or any(c not in "0123456789abcdef" for c in value):
            errors.append(f"artifact manifest {label} must be a full lowercase SHA-1")
    if root_value is None:
        errors.append("artifact manifest root is not a safe repo-relative path")

    raw_entries = raw.get("entries")
    if not isinstance(raw_entries, list) or not raw_entries:
        errors.append("artifact manifest entries must be a non-empty list")
        return None, errors
    entries: list[Entry] = []
    seen: set[str] = set()
    seen_casefold: set[str] = set()
    listed_paths: list[str] = []
    for index, item in enumerate(raw_entries):
        if not isinstance(item, dict):
            errors.append(f"artifact manifest entry {index} is not a mapping")
            continue
        path = _safe_relative(item.get("path"))
        mode = str(item.get("mode", ""))
        size = item.get("size")
        sha256 = item.get("sha256")
        role = item.get("role")
        if path is None:
            errors.append(f"artifact manifest entry {index} has unsafe path")
            continue
        listed_paths.append(path)
        if path in seen:
            errors.append(f"artifact manifest duplicate path: {path}")
        if path.casefold() in seen_casefold:
            errors.append(f"artifact manifest case-colliding path: {path}")
        seen.add(path)
        seen_casefold.add(path.casefold())
        if mode not in ALLOWED_MODES:
            errors.append(f"artifact manifest unsupported mode for {path}: {mode}")
        if not isinstance(size, int) or size < 0:
            errors.append(f"artifact manifest invalid size for {path}")
        if not isinstance(sha256, str) or len(sha256) != 64 or any(c not in "0123456789abcdef" for c in sha256):
            errors.append(f"artifact manifest invalid sha256 for {path}")
        if role not in ALLOWED_ROLES:
            errors.append(f"artifact manifest invalid role for {path}: {role}")
        if mode in ALLOWED_MODES and isinstance(size, int) and size >= 0 and isinstance(sha256, str) and len(sha256) == 64 and role in ALLOWED_ROLES:
            entries.append(Entry(path, mode, size, sha256, role))
    if listed_paths != sorted(listed_paths):
        errors.append("artifact manifest entries are not canonically sorted")
    closure = raw.get("closure")
    if not isinstance(closure, dict) or set(closure) != {"tracked_files", "excluded"}:
        errors.append("artifact manifest closure must declare tracked_files and excluded")
        closure_count = -1
        excluded: list[str] = []
    else:
        closure_count = closure.get("tracked_files")
        excluded = closure.get("excluded")
        if closure_count != len(raw_entries):
            errors.append("artifact manifest closure count does not match entries")
        if not isinstance(excluded, list) or not excluded or excluded != sorted(excluded):
            errors.append("artifact manifest excluded paths must be a non-empty sorted list")
            excluded = []
        for prefix in excluded:
            candidate = _safe_relative(prefix[:-1]) if isinstance(prefix, str) and prefix.endswith("/") else None
            if candidate is None:
                errors.append(f"artifact manifest excluded path is unsafe: {prefix}")
            if any(path == candidate or path.startswith(f"{candidate}/") for path in listed_paths):
                errors.append(f"artifact manifest includes excluded path: {prefix}")
    toolchain_inputs = raw.get("toolchain_inputs")
    if not isinstance(toolchain_inputs, list) or not toolchain_inputs or toolchain_inputs != sorted(toolchain_inputs):
        errors.append("artifact manifest toolchain_inputs must be a non-empty sorted list")
        toolchain_inputs = []
    for value in toolchain_inputs:
        safe = _safe_relative(value)
        if safe is None or safe not in seen:
            errors.append(f"artifact manifest toolchain input is missing or unsafe: {value}")
    provenance = raw.get("provenance")
    if provenance != {
        "creation_binding": "git_ls_tree",
        "offline_verification": "content_only_manifest_digest_must_be_anchored_externally",
    }:
        errors.append("artifact manifest provenance limits are not explicit")
    if errors or root_value is None:
        return None, errors
    raw_root = repo_root / root_value
    cursor = repo_root
    for part in PurePosixPath(root_value).parts:
        cursor /= part
        if cursor.is_symlink():
            return None, [f"artifact manifest root contains symlink: {root_value}"]
    snapshot = Snapshot(
        artifact_id=str(artifact_id),
        accepted_commit=str(accepted_commit),
        accepted_tree=str(accepted_tree),
        root=raw_root.resolve(),
        closure_count=int(closure_count),
        excluded=tuple(excluded),
        toolchain_inputs=tuple(toolchain_inputs),
        entries=tuple(entries),
    )
    try:
        snapshot.root.relative_to(repo_root.resolve())
    except ValueError:
        return None, ["artifact manifest root escapes repository"]
    return snapshot, []


def _valid_candidate(path: Path, entry: Entry) -> bool:
    if not path.is_file() or path.is_symlink():
        return False
    data = path.read_bytes()
    return len(data) == entry.size and digest_bytes(data) == entry.sha256


def _current_mode_matches(path: Path, entry: Entry) -> bool:
    expected = 0o755 if entry.mode == "100755" else 0o644
    return stat.S_IMODE(path.stat().st_mode) == expected


def _has_symlink_component(base: Path, relative: str) -> bool:
    cursor = base
    if cursor.is_symlink():
        return True
    for part in PurePosixPath(relative).parts:
        cursor /= part
        if cursor.is_symlink():
            return True
    return False


def resolve_entry(snapshot: Snapshot, entry: Entry, cas_root: Path = DEFAULT_CAS) -> Path | None:
    current = snapshot.root / entry.path
    if _valid_candidate(current, entry) and _current_mode_matches(current, entry):
        return current
    archived = cas_root / entry.sha256
    if archived.name != entry.sha256 or not _valid_candidate(archived, entry):
        return None
    return archived


def validate_manifest(
    manifest_path: Path,
    *,
    repo_root: Path = ROOT,
    cas_root: Path = DEFAULT_CAS,
) -> tuple[Snapshot | None, list[str]]:
    snapshot, errors = load_manifest(manifest_path, repo_root)
    if snapshot is None:
        return None, errors
    lexical_repo = repo_root.absolute()
    lexical_cas = cas_root.absolute()
    try:
        lexical_relative = lexical_cas.relative_to(lexical_repo).as_posix()
        cas_root.resolve().relative_to(repo_root.resolve())
    except ValueError:
        errors.append("artifact CAS root escapes repository")
        return snapshot, errors
    if _has_symlink_component(lexical_repo, lexical_relative):
        errors.append("artifact CAS root contains symlink")
        return snapshot, errors
    for entry in snapshot.entries:
        current = snapshot.root / entry.path
        if _has_symlink_component(snapshot.root, entry.path):
            errors.append(f"artifact current path contains symlink: {entry.path}")
            continue
        archived = cas_root / entry.sha256
        if _has_symlink_component(cas_root, entry.sha256):
            errors.append(f"artifact archived path contains symlink: {entry.sha256}")
            continue
        resolved = resolve_entry(snapshot, entry, cas_root)
        if resolved is None:
            if _valid_candidate(current, entry) and not _current_mode_matches(current, entry):
                errors.append(f"artifact mode drift: {entry.path}")
            else:
                errors.append(f"artifact bytes unavailable or drifted: {entry.path} ({entry.sha256})")
            continue
        if resolved.parent == cas_root:
            if stat.S_IMODE(resolved.stat().st_mode) != 0o644:
                errors.append(f"artifact CAS blob mode drift: {entry.sha256}")
        elif not _current_mode_matches(resolved, entry):
            errors.append(f"artifact mode drift: {entry.path}")
    return snapshot, errors


def reconstruct(
    manifest_path: Path,
    destination: Path,
    *,
    repo_root: Path = ROOT,
    cas_root: Path = DEFAULT_CAS,
) -> list[str]:
    snapshot, errors = validate_manifest(manifest_path, repo_root=repo_root, cas_root=cas_root)
    if snapshot is None or errors:
        return errors
    if destination.exists():
        return ["reconstruct destination must be absent"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{destination.name}.tmp-", dir=destination.parent))
    try:
        for entry in snapshot.entries:
            source = resolve_entry(snapshot, entry, cas_root)
            if source is None:
                return [f"artifact bytes disappeared during reconstruct: {entry.path}"]
            target = temporary / entry.path
            target.parent.mkdir(parents=True, exist_ok=True)
            data = source.read_bytes()
            if len(data) != entry.size or digest_bytes(data) != entry.sha256:
                return [f"artifact bytes changed during reconstruct: {entry.path}"]
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
            if hasattr(os, "O_NOFOLLOW"):
                flags |= os.O_NOFOLLOW
            fd = os.open(target, flags, 0o755 if entry.mode == "100755" else 0o644)
            with os.fdopen(fd, "wb") as stream:
                stream.write(data)
        try:
            os.rename(temporary, destination)
        except OSError as exc:
            return [f"reconstruct atomic publish failed: {exc}"]
        return []
    finally:
        if temporary.exists():
            for path in sorted(temporary.rglob("*"), key=lambda value: len(value.parts), reverse=True):
                if path.is_symlink() or path.is_file():
                    path.unlink()
                elif path.is_dir():
                    path.rmdir()
            temporary.rmdir()


def archive_entries(
    manifest_path: Path,
    relative_paths: list[str],
    *,
    repo_root: Path = ROOT,
    cas_root: Path = DEFAULT_CAS,
) -> list[str]:
    snapshot, errors = validate_manifest(manifest_path, repo_root=repo_root, cas_root=cas_root)
    if snapshot is None or errors:
        return errors
    by_path = {entry.path: entry for entry in snapshot.entries}
    requested = sorted(set(relative_paths))
    if requested != relative_paths:
        return ["archive paths must be unique and canonically sorted"]
    for relative in requested:
        entry = by_path.get(relative)
        if entry is None:
            errors.append(f"archive path is absent from manifest: {relative}")
            continue
        current = snapshot.root / entry.path
        if not _valid_candidate(current, entry) or _has_symlink_component(snapshot.root, entry.path):
            errors.append(f"archive source is not the accepted current file: {relative}")
            continue
        cas_root.mkdir(parents=True, exist_ok=True)
        archived = cas_root / entry.sha256
        if archived.exists():
            if not _valid_candidate(archived, entry):
                errors.append(f"archive CAS collision or corruption: {entry.sha256}")
            continue
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        fd = os.open(archived, flags, 0o644)
        with os.fdopen(fd, "wb") as stream:
            stream.write(current.read_bytes())
        if not _valid_candidate(archived, entry):
            errors.append(f"archive write verification failed: {entry.sha256}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify")
    verify.add_argument("manifest", type=Path)
    rebuild = sub.add_parser("reconstruct")
    rebuild.add_argument("manifest", type=Path)
    rebuild.add_argument("destination", type=Path)
    archive = sub.add_parser("archive")
    archive.add_argument("manifest", type=Path)
    archive.add_argument("paths", nargs="+")
    args = parser.parse_args(argv)
    if args.command == "verify":
        _, errors = validate_manifest(args.manifest.resolve())
    elif args.command == "reconstruct":
        errors = reconstruct(args.manifest.resolve(), args.destination.resolve())
    else:
        errors = archive_entries(args.manifest.resolve(), args.paths)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(
        f"OK mint_next_artifact_manifest {args.command}: {args.manifest} "
        "(content snapshot verified; Git provenance is not re-verified offline)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
