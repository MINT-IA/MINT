#!/usr/bin/env python3
"""ARB key parity lint — Phase 84 (LANG-03), Phase 34 GUARD-05.

Compares the key sets of every Flutter ARB file under
``apps/mobile/lib/l10n/`` and fails the build (exit 1) when any locale is
missing keys present in another locale (or vice-versa).

Why this exists
---------------
Flutter ``gen-l10n`` is silent about missing keys: it accepts ARB files of
different sizes and just falls back to the template-locale string for the
missing entries, producing French copy in a German UI. The cross-language
drift audit (B + E, 2026-05-05) flagged this as a recurring source of
inconsistency. Phase 84 ships this gate to make the drift mechanically
visible.

Behaviour
---------
* Reads every ``app_<locale>.arb`` under ``apps/mobile/lib/l10n/``.
* Treats ``@@locale`` and any ``@<key>`` (metadata) entries as parity-exempt
  *for the per-key diff* — they are descriptive metadata, sometimes only
  shipped in the template locale.
* Fails (exit 1) if the *content* (non-``@``) key sets differ between any
  two locales.
* Optional ``--baseline <file>`` accepts a JSON snapshot of currently-known
  drift to grandfather (per ROADMAP risk R-84-1, never used today since
  the live repo is at zero drift, but the flag is here to avoid blocking
  unrelated PRs in the future).
* Optional ``--json`` for CI-friendly machine output.
* Optional ``--paths <glob>`` to lint a subset (used by tests).

Exit codes
----------
* 0 — all locales share the same content key set.
* 1 — drift detected; per-locale diff printed to stderr.
* 2 — usage / I/O error.

Run::

    python3 tools/checks/arb_parity.py
    python3 tools/checks/arb_parity.py --json
    python3 tools/checks/arb_parity.py --paths /tmp/arb_fixture
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import sys
from pathlib import Path
from typing import Iterable

# Default scan path (relative to repo root). Tests can override via --paths.
_DEFAULT_ARB_DIR = Path("apps/mobile/lib/l10n")


@dataclasses.dataclass(frozen=True)
class LocaleSnapshot:
    """One ARB file's content keys (excluding @-prefixed metadata)."""

    locale: str
    path: Path
    content_keys: frozenset[str]
    meta_keys: frozenset[str]


@dataclasses.dataclass
class ParityReport:
    """Aggregate parity result across N locales."""

    snapshots: list[LocaleSnapshot]
    reference_locale: str
    drift: dict[str, dict[str, list[str]]]  # locale -> {missing, extra}
    grandfathered: dict[str, dict[str, list[str]]]

    @property
    def has_drift(self) -> bool:
        return any(
            entry["missing"] or entry["extra"] for entry in self.drift.values()
        )


def _is_meta(key: str) -> bool:
    """Treat @@locale and any @<key> entry as metadata (parity-exempt)."""
    return key.startswith("@")


def _load_snapshot(path: Path) -> LocaleSnapshot:
    locale = path.stem.replace("app_", "") or "unknown"
    try:
        with path.open(encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"[arb_parity] {path}: invalid JSON ({exc})") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"[arb_parity] {path}: top-level must be an object")

    content: set[str] = set()
    meta: set[str] = set()
    for key in data.keys():
        if _is_meta(key):
            meta.add(key)
        else:
            content.add(key)
    return LocaleSnapshot(
        locale=locale,
        path=path,
        content_keys=frozenset(content),
        meta_keys=frozenset(meta),
    )


def _gather_arb_files(root: Path) -> list[Path]:
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"[arb_parity] not a directory: {root}")
    files = sorted(p for p in root.glob("app_*.arb") if p.is_file())
    if not files:
        raise SystemExit(f"[arb_parity] no app_*.arb under {root}")
    return files


def compute_parity(
    snapshots: Iterable[LocaleSnapshot],
    *,
    reference: str = "fr",
    baseline: dict[str, dict[str, list[str]]] | None = None,
) -> ParityReport:
    """Diff every locale against the reference locale.

    A locale is in drift if its content_keys != reference.content_keys.
    Returned drift dict: ``{locale: {"missing": [...], "extra": [...]}}``
    (only locales with non-empty diff appear). ``baseline`` keys are
    subtracted from the diff and reported separately.
    """
    snaps = list(snapshots)
    by_locale = {s.locale: s for s in snaps}
    if reference not in by_locale:
        # Fall back to alphabetically first locale present.
        reference = sorted(by_locale.keys())[0]
    ref_keys = by_locale[reference].content_keys

    drift: dict[str, dict[str, list[str]]] = {}
    grandfathered: dict[str, dict[str, list[str]]] = {}
    baseline = baseline or {}

    for locale, snap in by_locale.items():
        if locale == reference:
            continue
        missing = sorted(ref_keys - snap.content_keys)
        extra = sorted(snap.content_keys - ref_keys)

        # Subtract baseline grandfather list, if any.
        base_entry = baseline.get(locale, {})
        base_missing = set(base_entry.get("missing", []))
        base_extra = set(base_entry.get("extra", []))
        live_missing = [k for k in missing if k not in base_missing]
        live_extra = [k for k in extra if k not in base_extra]
        gf_missing = [k for k in missing if k in base_missing]
        gf_extra = [k for k in extra if k in base_extra]

        if live_missing or live_extra:
            drift[locale] = {"missing": live_missing, "extra": live_extra}
        if gf_missing or gf_extra:
            grandfathered[locale] = {
                "missing": gf_missing,
                "extra": gf_extra,
            }

    return ParityReport(
        snapshots=snaps,
        reference_locale=reference,
        drift=drift,
        grandfathered=grandfathered,
    )


def _format_human(report: ParityReport) -> str:
    lines: list[str] = []
    lines.append(
        f"[arb_parity] reference={report.reference_locale} "
        f"locales={[s.locale for s in report.snapshots]}"
    )
    if not report.has_drift:
        lines.append("[arb_parity] OK — all content keys are in parity.")
    else:
        lines.append("[arb_parity] DRIFT — locales out of parity:")
        for locale in sorted(report.drift):
            entry = report.drift[locale]
            if entry["missing"]:
                lines.append(
                    f"  {locale}: missing {len(entry['missing'])} key(s) "
                    f"present in {report.reference_locale}: "
                    f"{entry['missing'][:10]}"
                    + (" ..." if len(entry["missing"]) > 10 else "")
                )
            if entry["extra"]:
                lines.append(
                    f"  {locale}: extra  {len(entry['extra'])} key(s) "
                    f"absent in {report.reference_locale}: "
                    f"{entry['extra'][:10]}"
                    + (" ..." if len(entry["extra"]) > 10 else "")
                )
    if report.grandfathered:
        lines.append("[arb_parity] grandfathered (baseline-known drift):")
        for locale, entry in sorted(report.grandfathered.items()):
            lines.append(
                f"  {locale}: missing={len(entry['missing'])} "
                f"extra={len(entry['extra'])}"
            )
    return "\n".join(lines)


def _format_json(report: ParityReport) -> str:
    return json.dumps(
        {
            "reference_locale": report.reference_locale,
            "locales": [s.locale for s in report.snapshots],
            "drift": report.drift,
            "grandfathered": report.grandfathered,
            "has_drift": report.has_drift,
        },
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )


def _resolve_repo_root() -> Path:
    """Walk up from this file until we find a directory containing
    ``apps/mobile/lib/l10n``. Falls back to CWD."""
    here = Path(__file__).resolve()
    for parent in (here.parent, *here.parents):
        if (parent / "apps" / "mobile" / "lib" / "l10n").is_dir():
            return parent
    return Path.cwd()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--paths",
        type=Path,
        default=None,
        help="Directory containing app_<locale>.arb (default: apps/mobile/lib/l10n).",
    )
    parser.add_argument(
        "--reference",
        default="fr",
        help="Reference locale (default: fr — the source-of-truth template).",
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        default=None,
        help=(
            "Optional JSON file with grandfathered drift "
            "(schema: {locale: {missing: [...], extra: [...]}})."
        ),
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a single JSON document on stdout instead of human text.",
    )
    parser.add_argument(
        "--exit-code",
        type=int,
        default=1,
        help=(
            "Exit code when drift is detected (default: 1). "
            "Use 0 to run as a warning-only gate."
        ),
    )
    args = parser.parse_args(argv)

    if args.paths is not None:
        arb_dir = args.paths
    else:
        arb_dir = _resolve_repo_root() / _DEFAULT_ARB_DIR

    arb_files = _gather_arb_files(arb_dir)
    snapshots = [_load_snapshot(p) for p in arb_files]

    baseline_data: dict[str, dict[str, list[str]]] | None = None
    if args.baseline is not None:
        if not args.baseline.is_file():
            print(
                f"[arb_parity] baseline file not found: {args.baseline}",
                file=sys.stderr,
            )
            return 2
        try:
            baseline_data = json.loads(args.baseline.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(
                f"[arb_parity] baseline JSON invalid: {exc}",
                file=sys.stderr,
            )
            return 2

    report = compute_parity(
        snapshots,
        reference=args.reference,
        baseline=baseline_data,
    )

    if args.json:
        print(_format_json(report))
    else:
        text = _format_human(report)
        # OK on stdout, drift on stderr — keeps CI logs greppable.
        if report.has_drift:
            print(text, file=sys.stderr)
        else:
            print(text)

    if report.has_drift:
        return args.exit_code
    return 0


if __name__ == "__main__":
    sys.exit(main())
