#!/usr/bin/env python3
"""Phase mint-data-architecture-v1-01 Plan 04 — regulatory constants codegen.

Bakes the active RegulatoryRegistry snapshot into a committed Dart file so the
mobile app's L1 layer is offline-capable on day 1 (D-08 + D-16). Scope is
REGULATORY CONSTANTS ONLY per codex HIGH #4 (scope creep — doctrinal codegen
dropped, those stay Dart-side with their own version field per D-13).

Usage :

    # Normal regen against the live in-process registry (default).
    python3 tools/codegen/regulatory_constants_to_dart.py --source local --write

    # Regen against the deployed staging snapshot endpoint (Plan 03).
    python3 tools/codegen/regulatory_constants_to_dart.py --source staging --write

    # Pre-commit / CI verification — exits 1 on drift, never touches the file.
    python3 tools/codegen/regulatory_constants_to_dart.py --check --source local

Design notes :

* Serialisation pipeline mirrors `tools/measurement/regulatory_snapshot_bundle_size.py`
  exactly : `is_active(today)` filter + `.to_dict()` + `json.dumps(separators=(",",
  ":"), sort_keys=True, ensure_ascii=False)`. This keeps byte-parity with Plan 01
  measurement + Plan 03 endpoint.
* Generated Dart uses raw-string + jsonDecode pattern (codex MEDIUM #3 fix) :
  the snapshot is embedded as `const String _snapshotJson = r'''<json>'''` and
  decoded lazily via `jsonDecode()` at first access. No Dart literal escaping
  edge cases.
* TWO hashes are baked : `regulatoryConstantsVersionHash` (echoes backend
  `version_hash`) AND `_payloadIntegrityHash` (SHA-256 of the embedded JSON
  body). The integrity hash detects manual tampering with the JSON body even
  when the version_hash literal looks correct (codex MEDIUM #4 fix).
* Aging-state machine for staging-down escalation (codex HIGH #3 fix) lives in
  `compute_escalation_level()` + `load_aging_state()` + `save_aging_state()`.
  Thresholds : 7/14/28 days → escalation levels 1/2/3. Pure function — the CI
  workflow consumes the state file and acts on the level.
* `--check` is network-free by contract (Karpathy #2 simplicity) — it reads the
  committed Dart file, recomputes hashes from `--source local`, compares.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import socket
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Optional, Sequence

# tools/codegen/<this>.py → parents[2] = repo root
_REPO_ROOT = Path(__file__).resolve().parents[2]
# Allow `from app.services...` resolution without invoking via FastAPI.
sys.path.insert(0, str(_REPO_ROOT / "services" / "backend"))

_DEFAULT_STAGING_URL = "https://mint-staging.up.railway.app"
_DEFAULT_OUTPUT = (
    _REPO_ROOT
    / "apps"
    / "mobile"
    / "lib"
    / "services"
    / "financial_core"
    / "generated"
    / "regulatory_constants.g.dart"
)
_DEFAULT_AGING_STATE = (
    _REPO_ROOT / ".planning" / "state" / "regulatory-codegen-aging.json"
)
_SNAPSHOT_PATH = "/api/v1/regulatory/constants/snapshot"
_STAGING_TIMEOUT_SECONDS = 10

# Regex narrowing extraction in --check mode. Strict 64-hex = SHA-256.
_VERSION_HASH_RE = re.compile(
    r"const\s+String\s+regulatoryConstantsVersionHash\s*=\s*'([0-9a-f]{64})';"
)
_INTEGRITY_HASH_RE = re.compile(
    r"const\s+String\s+_payloadIntegrityHash\s*=\s*'([0-9a-f]{64})';"
)
_SNAPSHOT_JSON_RE = re.compile(
    r"const\s+String\s+_snapshotJson\s*=\s*r'''(.*?)''';",
    re.DOTALL,
)


# ─── Aging state machine ────────────────────────────────────────────────────


def compute_escalation_level(consecutive_down_days: int) -> int:
    """Pure function mapping consecutive-down-days to escalation level 0-3.

    Thresholds locked by codex HIGH #3 mitigation + plan `<interfaces>` :
    * 0-6 days  → level 0 (warning only, exit 0)
    * 7-13 days → level 1 (PR comment, exit 0)
    * 14-27 days → level 2 (auto-open issue, exit 0)
    * >=28 days → level 3 (HARD BLOCK, exit 1)
    """
    if consecutive_down_days < 0:
        return 0
    if consecutive_down_days < 7:
        return 0
    if consecutive_down_days < 14:
        return 1
    if consecutive_down_days < 28:
        return 2
    return 3


def _default_aging_state() -> dict:
    return {
        "first_staging_down_at": None,
        "last_staging_down_at": None,
        "last_staging_up_at": None,
        "consecutive_down_days": 0,
        "escalation_level": 0,
    }


def load_aging_state(path: Path) -> dict:
    """Load aging state from disk ; missing-file returns the default state."""
    if not path.exists():
        return _default_aging_state()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return _default_aging_state()


def save_aging_state(path: Path, state: dict) -> None:
    """Persist aging state to disk ; creates parent dirs if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def _update_aging_on_down(state: dict, now: datetime) -> dict:
    """Mutate aging state for a staging-down event ; recompute level."""
    now_iso = now.isoformat().replace("+00:00", "Z")
    if not state.get("first_staging_down_at"):
        state["first_staging_down_at"] = now_iso
    state["last_staging_down_at"] = now_iso
    first = datetime.fromisoformat(
        state["first_staging_down_at"].replace("Z", "+00:00")
    )
    days = max(0, (now - first).days)
    state["consecutive_down_days"] = days
    state["escalation_level"] = compute_escalation_level(days)
    return state


def _update_aging_on_up(state: dict, now: datetime) -> dict:
    """Mutate aging state for a staging-up event ; reset counters."""
    now_iso = now.isoformat().replace("+00:00", "Z")
    state["last_staging_up_at"] = now_iso
    state["consecutive_down_days"] = 0
    state["escalation_level"] = 0
    state["first_staging_down_at"] = None
    return state


# ─── Payload sources ────────────────────────────────────────────────────────


def _build_payload_local(today: date) -> dict:
    """Build the snapshot payload from the in-process RegulatoryRegistry.

    Mirrors `tools/measurement/regulatory_snapshot_bundle_size.py` _build_payload()
    AND adds the canonical `version_hash` D-15 key (so the local payload matches
    the Plan 03 endpoint payload byte-for-byte).
    """
    from app.services.regulatory.registry import RegulatoryRegistry  # noqa: E402

    registry = RegulatoryRegistry.instance()
    active = [p for p in registry.get_all() if p.is_active(today)]
    version_hash = registry.version_hash(today)
    return {
        "active_version_hash": version_hash,
        "version_hash": version_hash,
        "effective_on": today.isoformat(),
        "param_count": len(active),
        "parameters": [p.to_dict() for p in active],
    }


def _fetch_payload_staging(staging_url: str) -> dict:
    """GET the Plan 03 snapshot endpoint from staging ; parse JSON body.

    Raises urllib.error.URLError / socket.timeout / ValueError on failure.
    """
    url = f"{staging_url.rstrip('/')}{_SNAPSHOT_PATH}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=_STAGING_TIMEOUT_SECONDS) as resp:
        status = getattr(resp, "status", 200)
        if status != 200:
            raise urllib.error.URLError(f"staging returned HTTP {status}")
        body = resp.read().decode("utf-8")
    return json.loads(body)


def _serialise_payload(payload: dict) -> str:
    """Byte-stable JSON encoding shared by measurement + endpoint + codegen."""
    return json.dumps(
        payload, separators=(",", ":"), sort_keys=True, ensure_ascii=False
    )


def _resolve_source(
    source: str,
    staging_url: str,
    aging_state_file: Path,
) -> tuple[dict, str, dict]:
    """Resolve the snapshot payload from local or staging.

    Returns (payload_dict, source_used_str, aging_state_after).
    `source_used_str` is "local", "staging", or "staging-fallback-to-local".
    Aging state is mutated based on staging probe outcome (only when source=staging).
    """
    today = date.today()
    now_utc = datetime.now(timezone.utc)
    aging_state = load_aging_state(aging_state_file)

    if source == "local":
        return _build_payload_local(today), "local", aging_state

    # source == "staging"
    try:
        payload = _fetch_payload_staging(staging_url)
        aging_state = _update_aging_on_up(aging_state, now_utc)
        save_aging_state(aging_state_file, aging_state)
        return payload, "staging", aging_state
    except (
        urllib.error.URLError,
        socket.timeout,
        TimeoutError,
        ConnectionError,
        ValueError,
        OSError,
    ) as exc:
        # Network or parse failure → fall back to local + update aging state.
        sys.stderr.write(
            f"[regulatory-codegen] staging unreachable ({exc!r}) — "
            f"falling back to local in-process snapshot.\n"
        )
        aging_state = _update_aging_on_down(aging_state, now_utc)
        save_aging_state(aging_state_file, aging_state)
        return _build_payload_local(today), "staging-fallback-to-local", aging_state


# ─── Dart file generation ──────────────────────────────────────────────────


def render_dart_file(payload: dict, source_label: str) -> str:
    """Render the full Dart source for the generated file.

    Uses raw-string + jsonDecode pattern (codex MEDIUM #3) so we never hand-escape
    Dart literals. The triple-quote raw string sidesteps single-quote, backslash,
    and Unicode escaping. The only payload constraint is that the JSON body must
    not contain the literal sequence `'''` — JSON output never does (no triple
    apostrophes can appear in deterministic JSON output).
    """
    json_body = _serialise_payload(payload)
    if "'''" in json_body:
        # Defensive : this should be unreachable for JSON-encoded data, but if a
        # future param value introduced apostrophe sequences we want to fail
        # loud rather than corrupt the Dart file.
        raise ValueError(
            "snapshot JSON body contains ''' — raw-string Dart literal would "
            "be malformed. Investigate the offending parameter."
        )

    version_hash = payload["version_hash"]
    effective_on = payload["effective_on"]
    integrity_hash = hashlib.sha256(json_body.encode("utf-8")).hexdigest()

    # Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-21) — header is deterministic.
    # The previous `Generated at: {datetime.utcnow().isoformat()}Z` line drifted on every
    # regeneration even when the underlying RegulatoryParameter snapshot was identical,
    # creating noise diffs that masked real parity-lint signals (D-12). We now anchor
    # the header on `effective_on` (the RegulatoryParameter snapshot date) — a stable
    # audit anchor that only changes when the law / params change. Git commit sha +
    # `version_hash` provide regeneration provenance.
    return (
        f"// AUTO-GENERATED by tools/codegen/regulatory_constants_to_dart.py — DO NOT EDIT MANUALLY.\n"
        f"// Phase mint-data-architecture-v1-01 Plan 04. Source snapshot effective_on: {effective_on}. Version hash: {version_hash}.\n"
        f"// Source: {source_label}. Generated for effective_on: {effective_on}.\n"
        f"// To regenerate: python3 tools/codegen/regulatory_constants_to_dart.py --source local --write\n"
        f"// To verify: python3 tools/codegen/regulatory_constants_to_dart.py --check\n"
        f"// To check determinism: python3 tools/codegen/regulatory_constants_to_dart.py --check-determinism\n"
        f"\n"
        f"// ignore_for_file: prefer_const_constructors, lines_longer_than_80_chars, unused_element\n"
        f"\n"
        f"import 'dart:convert' show jsonDecode;\n"
        f"\n"
        f"/// Version hash of the baked regulatory constants snapshot.\n"
        f"/// Matches GET /api/v1/regulatory/constants/version on the backend at bake time.\n"
        f"/// Runtime delta-check (D-08) compares this against the live /version response.\n"
        f"const String regulatoryConstantsVersionHash = '{version_hash}';\n"
        f"\n"
        f"/// SHA-256 of the embedded JSON body — for --check integrity validation.\n"
        f"/// DO NOT manually edit ; recompute via the codegen script.\n"
        f"const String _payloadIntegrityHash = '{integrity_hash}';\n"
        f"\n"
        f"/// Effective date of the baked snapshot (ISO 8601).\n"
        f"const String regulatoryConstantsEffectiveOn = '{effective_on}';\n"
        f"\n"
        f"/// The full baked snapshot as a JSON string.\n"
        f"/// Decode lazily via [regulatoryConstantsSnapshot].\n"
        f"const String _snapshotJson = r'''{json_body}''';\n"
        f"\n"
        f"/// Decoded snapshot — Map<String, dynamic> matching the backend\n"
        f"/// /constants/snapshot endpoint payload shape.\n"
        f"/// Decoded once on first access (final initializer).\n"
        f"final Map<String, dynamic> regulatoryConstantsSnapshot =\n"
        f"    jsonDecode(_snapshotJson) as Map<String, dynamic>;\n"
    )


# ─── --check verification ──────────────────────────────────────────────────


def _extract_existing_hashes(content: str) -> tuple[Optional[str], Optional[str], Optional[str]]:
    """Parse the committed Dart file ; return (version_hash, integrity_hash, embedded_json)."""
    vmatch = _VERSION_HASH_RE.search(content)
    imatch = _INTEGRITY_HASH_RE.search(content)
    jmatch = _SNAPSHOT_JSON_RE.search(content)
    version = vmatch.group(1) if vmatch else None
    integrity = imatch.group(1) if imatch else None
    body = jmatch.group(1) if jmatch else None
    return version, integrity, body


def _run_check(output_path: Path) -> int:
    """--check mode : read committed file, recompute from local source, compare."""
    if not output_path.exists():
        sys.stderr.write(
            f"[regulatory-codegen] --check FAIL : generated file missing at {output_path}. "
            f"Run: python3 tools/codegen/regulatory_constants_to_dart.py --source local --write\n"
        )
        return 1

    content = output_path.read_text(encoding="utf-8")
    baked_version, baked_integrity, baked_body = _extract_existing_hashes(content)
    if not baked_version or not baked_integrity or baked_body is None:
        sys.stderr.write(
            f"[regulatory-codegen] --check FAIL : could not parse hashes from {output_path}. "
            f"Run: python3 tools/codegen/regulatory_constants_to_dart.py --source local --write\n"
        )
        return 1

    # Integrity check FIRST — detects payload tampering even when version_hash
    # literal was not touched.
    body_hash = hashlib.sha256(baked_body.encode("utf-8")).hexdigest()
    if body_hash != baked_integrity:
        sys.stderr.write(
            f"[regulatory-codegen] --check FAIL : payload integrity mismatch in {output_path}.\n"
            f"  baked _payloadIntegrityHash = {baked_integrity}\n"
            f"  recomputed from embedded JSON = {body_hash}\n"
            f"The embedded JSON body has been tampered with. Run: "
            f"python3 tools/codegen/regulatory_constants_to_dart.py --source local --write\n"
        )
        return 1

    # Version hash check : recompute from the in-process registry.
    today = date.today()
    fresh_payload = _build_payload_local(today)
    fresh_version = fresh_payload["version_hash"]
    if fresh_version != baked_version:
        sys.stderr.write(
            f"[regulatory-codegen] --check FAIL : version hash drift in {output_path}.\n"
            f"  baked regulatoryConstantsVersionHash = {baked_version}\n"
            f"  current registry version_hash(today)  = {fresh_version}\n"
            f"Run: python3 tools/codegen/regulatory_constants_to_dart.py --source local --write\n"
        )
        return 1

    sys.stderr.write(
        f"[regulatory-codegen] --check OK : {output_path} matches registry version_hash {baked_version}.\n"
    )
    return 0


# ─── CLI entry point ───────────────────────────────────────────────────────


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Bake the active RegulatoryRegistry snapshot into the committed Dart file "
            "consumed by the mobile app's offline-first L1 layer (D-08 + D-16). "
            "Scope is REGULATORY CONSTANTS ONLY (codex HIGH #4 — doctrinal codegen dropped)."
        )
    )
    parser.add_argument(
        "--source",
        choices=("local", "staging"),
        default="local",
        help="Snapshot source: 'local' uses the in-process registry, 'staging' GETs /api/v1/regulatory/constants/snapshot from --staging-url.",
    )
    parser.add_argument(
        "--staging-url",
        default=_DEFAULT_STAGING_URL,
        help=f"Staging base URL (default {_DEFAULT_STAGING_URL}).",
    )
    parser.add_argument(
        "--output",
        default=str(_DEFAULT_OUTPUT),
        help=f"Output path for the generated Dart file (default {_DEFAULT_OUTPUT}).",
    )
    parser.add_argument(
        "--aging-state-file",
        default=str(_DEFAULT_AGING_STATE),
        help=f"Aging state JSON file for CI escalation tracking (default {_DEFAULT_AGING_STATE}).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON status to stdout (CI mode).",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--check",
        action="store_true",
        help="Verify the committed Dart file matches the source ; exit 1 on drift. Network-free (local source only).",
    )
    mode.add_argument(
        "--write",
        action="store_true",
        help="(Re)generate the Dart file from --source.",
    )
    mode.add_argument(
        "--check-determinism",
        action="store_true",
        help=(
            "Phase 02 D-21 — Run the generator twice in-process from the local source "
            "and assert the two outputs are byte-identical. Exits 1 on any drift "
            "(catches future regressions of the utcnow() / random / etc. determinism contract). "
            "Network-free."
        ),
    )
    args = parser.parse_args(argv)

    output_path = Path(args.output)
    aging_state_file = Path(args.aging_state_file)

    if args.check_determinism:
        # Phase 02 D-21 — run generator twice in-process, compare byte-for-byte.
        today = date.today()
        run1 = render_dart_file(_build_payload_local(today), "local")
        run2 = render_dart_file(_build_payload_local(today), "local")
        if run1 != run2:
            # Find the first diverging line for actionable diagnosis.
            l1 = run1.splitlines()
            l2 = run2.splitlines()
            divergence_line = -1
            for i in range(min(len(l1), len(l2))):
                if l1[i] != l2[i]:
                    divergence_line = i + 1
                    break
            sys.stderr.write(
                f"[regulatory-codegen] --check-determinism FAIL : two consecutive "
                f"render_dart_file() calls produced different output.\n"
            )
            if divergence_line > 0:
                sys.stderr.write(
                    f"  First divergence at line {divergence_line} :\n"
                    f"    run1: {l1[divergence_line - 1]!r}\n"
                    f"    run2: {l2[divergence_line - 1]!r}\n"
                )
            return 1
        sys.stderr.write(
            f"[regulatory-codegen] --check-determinism OK : two runs of "
            f"render_dart_file() byte-identical ({len(run1)} bytes). D-21 met.\n"
        )
        if args.json:
            sys.stdout.write(
                json.dumps(
                    {"mode": "check-determinism", "exit_code": 0, "byte_length": len(run1)},
                    sort_keys=True,
                )
                + "\n"
            )
        return 0

    if args.check:
        # --check is network-free by contract (Karpathy #2 simplicity).
        rc = _run_check(output_path)
        if args.json:
            sys.stdout.write(
                json.dumps(
                    {"mode": "check", "exit_code": rc, "output": str(output_path)},
                    sort_keys=True,
                )
                + "\n"
            )
        return rc

    # --write
    payload, source_used, aging_state = _resolve_source(
        args.source, args.staging_url, aging_state_file
    )
    dart_source = render_dart_file(payload, source_used)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(dart_source, encoding="utf-8")
    sys.stderr.write(
        f"[regulatory-codegen] --write OK : wrote {output_path} "
        f"(source={source_used}, version_hash={payload['version_hash']}, "
        f"param_count={payload['param_count']}).\n"
    )
    if args.json:
        sys.stdout.write(
            json.dumps(
                {
                    "mode": "write",
                    "exit_code": 0,
                    "source": source_used,
                    "version_hash": payload["version_hash"],
                    "effective_on": payload["effective_on"],
                    "output": str(output_path),
                    "aging_state": aging_state,
                },
                sort_keys=True,
            )
            + "\n"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
