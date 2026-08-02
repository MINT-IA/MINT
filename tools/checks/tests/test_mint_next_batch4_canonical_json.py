from __future__ import annotations

import hashlib
import importlib.metadata
import importlib.util
import itertools
import json
import os
import socket
import subprocess
import sys
import textwrap
import unicodedata
from pathlib import Path

import pytest
import yaml


REPO = Path(__file__).resolve().parents[3]
TOOL_PATH = REPO / "tools/checks/mint_next_batch4_canonical_json.py"
SPEC_PATH = REPO / "product/mint_next/batch4/evidence/canonical-json-v1.yaml"
LOCK_PATH = REPO / "tools/checks/requirements-batch4-canonical-json.lock"
SPEC = importlib.util.spec_from_file_location("mint_canonical_json", TOOL_PATH)
assert SPEC and SPEC.loader
canonical = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(canonical)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


@pytest.mark.parametrize(
    ("raw", "expected", "expected_sha"),
    [
        (
            b'{ "b" : 2, "a" : 1 }',
            b'{"a":1,"b":2}',
            "43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777",
        ),
        (
            json.dumps({"x": "€$\u000f\nA'B\"\\\"/"}, ensure_ascii=True).encode(),
            b'{"x":"\xe2\x82\xac$\\u000f\\nA\'B\\"\\\\\\"/"}',
            "db3b3be1ab04d6a2aa1f78a0476765acc5a00fa264e0897de19429eadde03199",
        ),
        (
            json.dumps({"\ue000": 1, "😀": 2}, ensure_ascii=True).encode(),
            b'{"\xf0\x9f\x98\x80":2,"\xee\x80\x80":1}',
            "28c95d1bbb2209223307e62f489020e8f9e0cfa16adf2daf6d88127a1e8dd22a",
        ),
        (b"-0", b"0", "5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9"),
        (
            b"[null,true,false,9007199254740991,-9007199254740991]",
            b"[null,true,false,9007199254740991,-9007199254740991]",
            "440efa57bb93b02ac9d8777140ee049d1f37a83e4ce8233405dfbe2d0ed7b628",
        ),
    ],
)
def test_golden_bytes_and_sha(raw: bytes, expected: bytes, expected_sha: str) -> None:
    output = canonical.canonicalize_bytes(raw)
    assert output == expected
    assert sha(output) == expected_sha
    assert not output.endswith(b"\n")


def test_idempotence_and_all_key_insertion_orders() -> None:
    expected = b'{"a":1,"b":2,"c":3}'
    for order in itertools.permutations([("a", 1), ("b", 2), ("c", 3)]):
        raw = json.dumps(dict(order), separators=(",", ":")).encode()
        first = canonical.canonicalize_bytes(raw)
        assert first == expected
        assert canonical.canonicalize_bytes(first) == first


def test_escaped_and_literal_duplicate_keys_rejected_after_decoding() -> None:
    with pytest.raises(canonical.CanonicalizationInputError, match="duplicate JSON key"):
        canonical.canonicalize_bytes(b'{"a":1,"\\u0061":2}')


def test_nfc_and_nfd_are_not_normalized_or_collapsed() -> None:
    nfc = unicodedata.normalize("NFC", "é")
    nfd = unicodedata.normalize("NFD", "é")
    assert nfc != nfd
    nfc_bytes = canonical.canonicalize_bytes(json.dumps(nfc).encode())
    nfd_bytes = canonical.canonicalize_bytes(json.dumps(nfd).encode())
    assert nfc_bytes != nfd_bytes
    assert nfc.encode() in nfc_bytes
    assert nfd.encode() in nfd_bytes


@pytest.mark.parametrize("raw", [b'"\\ud800"', b'{"\\udfff":1}', b'"\\ud800x"'])
def test_lone_surrogates_rejected(raw: bytes) -> None:
    with pytest.raises(canonical.CanonicalizationInputError, match="Unicode scalar"):
        canonical.canonicalize_bytes(raw)


@pytest.mark.parametrize("raw", [b"1.0", b"-0.0", b"1e0", b"1E+2", b"1e400"])
def test_every_float_token_rejected(raw: bytes) -> None:
    with pytest.raises(canonical.CanonicalizationInputError, match="float tokens forbidden"):
        canonical.canonicalize_bytes(raw)


@pytest.mark.parametrize("raw", [b"NaN", b"Infinity", b"-Infinity"])
def test_nonfinite_constants_rejected(raw: bytes) -> None:
    with pytest.raises(canonical.CanonicalizationInputError, match="non-finite"):
        canonical.canonicalize_bytes(raw)


@pytest.mark.parametrize(
    "raw",
    [b"9007199254740992", b"-9007199254740992", b"1" * 1000],
)
def test_integer_portability_and_digit_limits(raw: bytes) -> None:
    with pytest.raises(canonical.CanonicalizationInputError, match="integer"):
        canonical.canonicalize_bytes(raw)


@pytest.mark.parametrize(
    "raw",
    [b"\xef\xbb\xbf{}", b"{} trailing", b"\xff", b'{"x":"\\uZZZZ"}'],
)
def test_strict_input_bytes_rejected(raw: bytes) -> None:
    with pytest.raises(canonical.CanonicalizationInputError):
        canonical.canonicalize_bytes(raw)


def test_non_bytes_api_input_rejected() -> None:
    with pytest.raises(TypeError, match="raw bytes"):
        canonical.canonicalize_bytes({"a": 1})  # type: ignore[arg-type]


def test_resource_limits_rejected() -> None:
    with pytest.raises(canonical.CanonicalizationInputError, match="input byte limit"):
        canonical.canonicalize_bytes(b" " * (canonical.MAX_INPUT_BYTES + 1))
    deep = ("[" * (canonical.MAX_DEPTH + 2) + "]" * (canonical.MAX_DEPTH + 2)).encode()
    with pytest.raises(canonical.CanonicalizationInputError, match="depth"):
        canonical.canonicalize_bytes(deep)
    long_string = json.dumps("x" * (canonical.MAX_STRING_UTF8_BYTES + 1)).encode()
    with pytest.raises(canonical.CanonicalizationInputError, match="string byte limit"):
        canonical.canonicalize_bytes(long_string)


def test_dependency_version_is_exact_and_failure_is_loud(monkeypatch: pytest.MonkeyPatch) -> None:
    assert importlib.metadata.version("rfc8785") == "0.1.4"
    monkeypatch.setattr(canonical.importlib.metadata, "version", lambda _name: "0.1.5")
    with pytest.raises(canonical.CanonicalizationEnvironmentError, match="exact rfc8785 version"):
        canonical.canonicalize_bytes(b"{}")


def test_preloaded_fake_module_cannot_replace_verified_callable() -> None:
    script = textwrap.dedent(
        f"""
        import importlib.util, pathlib, sys, types
        import importlib.metadata
        genuine = pathlib.Path(importlib.metadata.distribution('rfc8785').locate_file('rfc8785/__init__.py'))
        fake = types.ModuleType('rfc8785')
        fake.__file__ = str(genuine)
        fake.CanonicalizationError = ValueError
        fake.dumps = lambda _value: b'NOT-JCS'
        sys.modules['rfc8785'] = fake
        spec = importlib.util.spec_from_file_location('target', {str(TOOL_PATH)!r})
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        assert module.canonicalize_bytes(b'{{"b":2,"a":1}}') == b'{{"a":1,"b":2}}'
        """
    )
    result = subprocess.run([sys.executable, "-c", script], text=True, capture_output=True)
    assert result.returncode == 0, result.stderr


def test_same_version_module_hash_drift_is_rejected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setitem(canonical.EXPECTED_RFC8785_FILES, "_impl.py", "0" * 64)
    with pytest.raises(canonical.CanonicalizationEnvironmentError, match="file hash drift"):
        canonical.canonicalize_bytes(b"{}")


def test_verified_implementation_bytes_are_read_exactly_once(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    original = canonical.Path.read_bytes
    reads = 0

    def counted(path: Path) -> bytes:
        nonlocal reads
        if path.name == "_impl.py":
            reads += 1
            if reads > 1:
                raise AssertionError("verified implementation was read twice")
        return original(path)

    monkeypatch.setattr(canonical.Path, "read_bytes", counted)
    assert canonical.canonicalize_bytes(b'{"b":2,"a":1}') == b'{"a":1,"b":2}'
    assert reads == 1


def test_machine_spec_and_dependency_lock_are_exact() -> None:
    spec = yaml.safe_load(SPEC_PATH.read_text())
    assert spec["status"] == "implemented_component_unintegrated_blocking"
    assert spec["algorithm"] == "RFC_8785_JCS_strict_no_float_I_JSON_subset"
    assert spec["claims"]["request_or_manifest_valid"] is False
    assert spec["claims"]["review_or_promotion_evidence"] is False
    assert "rfc8785==0.1.4" in LOCK_PATH.read_text()
    assert "520d690b448ecf0703691c76e1a34a24ddcd4fc5bc41d589cb7c58ec651bcd48" in LOCK_PATH.read_text()
    assert spec["dependency"]["installed_module_sha256"] == canonical.EXPECTED_RFC8785_FILES


def test_raw_and_canonical_hashes_are_distinct_and_both_retainable() -> None:
    raw = b'{ "b" : 2, "a" : 1 }'
    output = canonical.canonicalize_bytes(raw)
    assert sha(raw) != sha(output)


def test_no_network(monkeypatch: pytest.MonkeyPatch) -> None:
    def denied(*_args, **_kwargs):
        raise AssertionError("network attempted")

    monkeypatch.setattr(socket, "socket", denied)
    assert canonical.canonicalize_bytes(b"{}") == b"{}"


def test_cli_digest_only_is_deterministic(tmp_path: Path) -> None:
    source = tmp_path / "input.json"
    source.write_bytes(b'{ "b" : 2, "a" : 1 }')
    command = [sys.executable, str(TOOL_PATH), str(source)]
    first = subprocess.run(command, text=True, capture_output=True)
    second = subprocess.run(command, text=True, capture_output=True)
    assert first.returncode == second.returncode == 0
    expected = (
        "CANONICAL_DIGEST_NON_EVIDENCE "
        "sha256=43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777 "
        "bytes=13"
    )
    assert first.stdout.strip() == second.stdout.strip() == expected
    assert first.stderr == second.stderr == ""
    assert '{"a":1' not in first.stdout


def test_cli_rejects_symlink_fifo_and_oversize(tmp_path: Path) -> None:
    source = tmp_path / "input.json"
    source.write_bytes(b"{}")
    link = tmp_path / "link.json"
    link.symlink_to(source)
    fifo = tmp_path / "fifo"
    os.mkfifo(fifo)
    oversized = tmp_path / "oversized.json"
    oversized.write_bytes(b" " * (canonical.MAX_INPUT_BYTES + 100_000))
    for path in (link, fifo, oversized):
        result = subprocess.run(
            [sys.executable, str(TOOL_PATH), str(path)], text=True, capture_output=True,
            timeout=5,
        )
        assert result.returncode != 0
        assert "CANONICAL_DIGEST_NON_EVIDENCE" not in result.stdout
