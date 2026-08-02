#!/usr/bin/env python3
"""Strict RFC 8785 subset primitive; canonicalization is not review evidence."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
import stat
import sys
from pathlib import Path
from typing import Callable, NoReturn


EXPECTED_RFC8785_VERSION = "0.1.4"
EXPECTED_RFC8785_FILES = {
    "__init__.py": "fa44927afd547caf7547247078bcf28863d1e69caf116d258c532b3f20ffd154",
    "_impl.py": "c25bc3a046528482d53bee3487b837f31dd9c05f33e8f13288c7aab320932cec",
}
MAX_INPUT_BYTES = 1_048_576
MAX_OUTPUT_BYTES = 1_048_576
MAX_DEPTH = 64
MAX_NODES = 100_000
MAX_CONTAINER_ITEMS = 50_000
MAX_STRING_UTF8_BYTES = 262_144
MAX_INTEGER_DIGITS = 16
MIN_SAFE_INTEGER = -9_007_199_254_740_991
MAX_SAFE_INTEGER = 9_007_199_254_740_991


class CanonicalizationInputError(ValueError):
    """The raw JSON is outside the canonical primitive's accepted domain."""


class CanonicalizationEnvironmentError(RuntimeError):
    """The pinned canonicalization implementation is unavailable or drifted."""


def _reject_float(_token: str) -> NoReturn:
    raise CanonicalizationInputError("float tokens forbidden")


def _reject_constant(_token: str) -> NoReturn:
    raise CanonicalizationInputError("non-finite JSON constant forbidden")


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        raise CanonicalizationInputError("integer digit limit exceeded")
    value = int(token)
    if not MIN_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER:
        raise CanonicalizationInputError("integer outside portable safe range")
    return value


def _object_pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise CanonicalizationInputError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _validate_scalar_string(value: str) -> None:
    try:
        encoded = value.encode("utf-8", errors="strict")
    except UnicodeEncodeError as exc:
        raise CanonicalizationInputError("string must contain only Unicode scalar values") from exc
    if len(encoded) > MAX_STRING_UTF8_BYTES:
        raise CanonicalizationInputError("string byte limit exceeded")


def _validate_domain(root: object) -> None:
    nodes = 0
    stack: list[tuple[object, int]] = [(root, 0)]
    while stack:
        value, depth = stack.pop()
        nodes += 1
        if nodes > MAX_NODES:
            raise CanonicalizationInputError("node limit exceeded")
        if depth > MAX_DEPTH:
            raise CanonicalizationInputError("depth limit exceeded")
        if value is None or isinstance(value, bool):
            continue
        if isinstance(value, int):
            if not MIN_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER:
                raise CanonicalizationInputError("integer outside portable safe range")
            continue
        if isinstance(value, str):
            _validate_scalar_string(value)
            continue
        if isinstance(value, list):
            if len(value) > MAX_CONTAINER_ITEMS:
                raise CanonicalizationInputError("container item limit exceeded")
            stack.extend((item, depth + 1) for item in value)
            continue
        if isinstance(value, dict):
            if len(value) > MAX_CONTAINER_ITEMS:
                raise CanonicalizationInputError("container item limit exceeded")
            for key, item in value.items():
                _validate_scalar_string(key)
                stack.append((item, depth + 1))
            continue
        raise CanonicalizationInputError(f"unsupported JSON value type: {type(value).__name__}")


def _load_verified_implementation() -> tuple[Callable[[object], bytes], type[Exception]]:
    try:
        actual = importlib.metadata.version("rfc8785")
    except importlib.metadata.PackageNotFoundError as exc:
        raise CanonicalizationEnvironmentError("exact rfc8785 version 0.1.4 is required") from exc
    if actual != EXPECTED_RFC8785_VERSION:
        raise CanonicalizationEnvironmentError(
            f"exact rfc8785 version {EXPECTED_RFC8785_VERSION} required; found {actual}"
        )
    distribution = importlib.metadata.distribution("rfc8785")
    expected_root = Path(distribution.locate_file("rfc8785")).resolve(strict=True)
    verified_sources: dict[str, bytes] = {}
    for relative, expected_sha in EXPECTED_RFC8785_FILES.items():
        path = expected_root / relative
        if path.is_symlink() or not path.is_file():
            raise CanonicalizationEnvironmentError(f"pinned rfc8785 file missing or symlinked: {relative}")
        source_bytes = path.read_bytes()
        actual_sha = hashlib.sha256(source_bytes).hexdigest()
        if actual_sha != expected_sha:
            raise CanonicalizationEnvironmentError(f"pinned rfc8785 file hash drift: {relative}")
        verified_sources[relative] = source_bytes
    implementation_path = expected_root / "_impl.py"
    namespace: dict[str, object] = {
        "__name__": "_mint_verified_rfc8785_impl",
        "__file__": str(implementation_path),
    }
    try:
        exec(compile(verified_sources["_impl.py"], str(implementation_path), "exec"), namespace)
        dumps = namespace["dumps"]
        error_type = namespace["CanonicalizationError"]
    except Exception as exc:
        raise CanonicalizationEnvironmentError("cannot load verified rfc8785 implementation bytes") from exc
    if not callable(dumps) or not isinstance(error_type, type) or not issubclass(error_type, Exception):
        raise CanonicalizationEnvironmentError("verified rfc8785 implementation exports are invalid")
    return dumps, error_type


def canonicalize_bytes(raw: bytes) -> bytes:
    """Return canonical bytes for a strict JSON subset, without asserting trust."""
    if not isinstance(raw, bytes):
        raise TypeError("canonicalize_bytes requires raw bytes")
    if len(raw) > MAX_INPUT_BYTES:
        raise CanonicalizationInputError("input byte limit exceeded")
    if raw.startswith(b"\xef\xbb\xbf"):
        raise CanonicalizationInputError("UTF-8 BOM forbidden")
    dumps, canonicalization_error = _load_verified_implementation()
    try:
        text = raw.decode("utf-8", errors="strict")
        value = json.loads(
            text,
            object_pairs_hook=_object_pairs,
            parse_float=_reject_float,
            parse_int=_parse_integer,
            parse_constant=_reject_constant,
        )
    except CanonicalizationInputError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as exc:
        message = "depth limit exceeded" if isinstance(exc, RecursionError) else "invalid strict JSON input"
        raise CanonicalizationInputError(message) from exc
    _validate_domain(value)
    try:
        output = dumps(value)
    except (canonicalization_error, UnicodeError, RecursionError) as exc:
        raise CanonicalizationInputError("RFC 8785 canonicalization failed") from exc
    if len(output) > MAX_OUTPUT_BYTES:
        raise CanonicalizationInputError("output byte limit exceeded")
    return output


def _read_regular_file(path: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        raise CanonicalizationInputError("input path must be a readable non-symlink regular file") from exc
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise CanonicalizationInputError("input path must be a regular file")
        if metadata.st_size > MAX_INPUT_BYTES:
            raise CanonicalizationInputError("input byte limit exceeded")
        chunks: list[bytes] = []
        remaining = MAX_INPUT_BYTES + 1
        while remaining:
            chunk = os.read(descriptor, min(65_536, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        raw = b"".join(chunks)
        if len(raw) > MAX_INPUT_BYTES:
            raise CanonicalizationInputError("input byte limit exceeded")
        return raw
    finally:
        os.close(descriptor)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="path to a raw JSON regular file")
    args = parser.parse_args(argv)
    try:
        canonical = canonicalize_bytes(_read_regular_file(args.input))
    except (CanonicalizationInputError, CanonicalizationEnvironmentError) as exc:
        print(f"ERROR canonical-json-non-evidence: {exc}", file=sys.stderr)
        return 2
    digest = hashlib.sha256(canonical).hexdigest()
    print(f"CANONICAL_DIGEST_NON_EVIDENCE sha256={digest} bytes={len(canonical)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
