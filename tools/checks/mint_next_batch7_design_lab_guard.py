#!/usr/bin/env python3
"""Fail closed on the isolated Batch 7 Flutter Design Lab boundary."""

from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.checks.mint_next_artifact_manifest import resolve_entry, validate_manifest

SCOPE = ROOT / "product/mint_next/batch7/design-lab-scope.yaml"
LAB = ROOT / "product/mint_next/batch7/design_lab"
NAVIGATION = ROOT / "product/mint_next/batch6/navigation.yaml"
RUNTIME_RECEIPT = LAB / "evidence/runtime/receipt.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch7/design-lab-acceptance.yaml"
MANIFEST = ROOT / "product/mint_next/batch7/design-lab-manifest.yaml"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def formal_voice_errors_data(data: dict[str, object], locale: str) -> list[str]:
    formal_terms = {
        "fr": ("vous", "votre", "vos"),
        "de": ("Sie", "Ihr", "Ihre", "Ihren", "Ihrem"),
        "es": ("usted", "su", "sus"),
        "it": ("vi", "vostra", "vostro", "vostre", "vostri"),
        "pt": ("si", "seu", "seus", "sua", "suas"),
    }
    values = " ".join(
        value for key, value in data.items()
        if not key.startswith("@") and isinstance(value, str)
    )
    found = [
        term for term in formal_terms.get(locale, ())
        if re.search(rf"(?<!\w){re.escape(term)}(?!\w)", values)
    ]
    if found:
        return [f"{locale} copy drifts from informal singular voice: {', '.join(found)}"]
    return []


def formal_voice_errors(path: Path, locale: str) -> list[str]:
    return formal_voice_errors_data(json.loads(path.read_text(encoding="utf-8")), locale)


def validate(scope_path: Path = SCOPE, acceptance_path: Path = ACCEPTANCE) -> list[str]:
    scope = yaml.safe_load(scope_path.read_text(encoding="utf-8"))
    snapshot, errors = validate_manifest(MANIFEST)
    if snapshot is None:
        return errors
    if digest(MANIFEST) != "0cf7cb3d05b96dc2b9d644e10a70817aa605de268d55f661b92a870e7c639e23":
        errors.append("Batch7 accepted manifest digest drift")
    if snapshot.artifact_id != "mint-next-batch7-design-lab":
        errors.append("Batch7 manifest artifact id drift")
    if snapshot.accepted_commit != "e52974afa3dde8dc03b0c2a0c228d563d0ff40b3":
        errors.append("Batch7 manifest accepted commit drift")
    if snapshot.accepted_tree != "33c18c0a3987d4b2bb3d004a5f517ab1f99af09c":
        errors.append("Batch7 manifest accepted tree drift")
    if len(snapshot.entries) != 40:
        errors.append("Batch7 manifest does not cover the full 40-file accepted package")
    entries = {entry.path: entry for entry in snapshot.entries}

    def accepted_bytes(relative: str) -> bytes:
        entry = entries.get(relative)
        if entry is None:
            errors.append(f"accepted manifest missing required path: {relative}")
            return b""
        resolved = resolve_entry(snapshot, entry)
        if resolved is None:
            errors.append(f"accepted manifest cannot resolve required path: {relative}")
            return b""
        return resolved.read_bytes()

    def accepted_text(relative: str) -> str:
        return accepted_bytes(relative).decode("utf-8")
    authority = scope.get("authority", {})
    if authority.get("navigation_sha256") != digest(NAVIGATION):
        errors.append("design-lab scope is not bound to the accepted navigation hash")
    boundary = scope.get("runtime_boundary", {})
    if boundary != {
        "kind": "standalone_flutter_package",
        "path": "product/mint_next/batch7/design_lab",
        "imported_by_product": False,
        "product_route_added": False,
    }:
        errors.append("design lab is not isolated from product runtime")
    pubspec = yaml.safe_load(accepted_text("pubspec.yaml"))
    dependencies = set(pubspec.get("dependencies", {}))
    if dependencies != {"flutter", "flutter_localizations", "intl"}:
        errors.append("design lab introduced undeclared network or product dependencies")
    locales = scope.get("first_visual_slice", {}).get("locales", [])
    if locales != ["fr", "en", "de", "it", "es", "pt"]:
        errors.append("six-locale scope is incomplete or reordered")
    arb_keys: dict[str, set[str]] = {}
    arb_data: dict[str, dict[str, object]] = {}
    for locale in locales:
        data = json.loads(accepted_text(f"lib/l10n/app_{locale}.arb"))
        arb_data[locale] = data
        arb_keys[locale] = {key for key in data if not key.startswith("@")}
    if arb_keys and any(keys != arb_keys.get("fr") for keys in arb_keys.values()):
        errors.append("design-lab ARB keys are not identical across six locales")
    for locale in ("fr", "de", "es", "it", "pt"):
        if locale in arb_data:
            errors.extend(formal_voice_errors_data(arb_data[locale], locale))
    source = accepted_text("lib/design_lab_app.dart")
    required_bindings = {
        "today_3a_intent", "orientation", "fact_tax_year", "dismissed",
        "action:today_3a_intent.start",
        "action:orientation.continue", "action:orientation.back",
        "action:fact_tax_year.confirm_current_year", "action:fact_tax_year.back",
        "overlay:safe_exit",
        "overlay-action:safe_exit.resume", "overlay-action:safe_exit.keep_local_reference",
        "overlay-action:safe_exit.leave_without_saving",
    }
    missing = sorted(value for value in required_bindings if value not in source)
    if missing:
        errors.append("design-lab source lacks scoped canonical bindings: " + ", ".join(missing))
    if "action:$nodeId.open_safe_exit" not in source:
        errors.append("design-lab header does not bind safe exit to the current canonical node")
    if "keepReferenceUnavailable" not in source or "onPressed: null" not in source:
        errors.append("unimplemented local-reference action is not visibly fail-closed")
    receipt_bytes = accepted_bytes("evidence/runtime/receipt.yaml")
    if receipt_bytes:
        receipt = yaml.safe_load(receipt_bytes)
        if receipt.get("viewport") != {"width": 390, "height": 844, "device_scale_factor": 1}:
            errors.append("runtime evidence viewport is not the scoped 390x844 device")
        captures = receipt.get("captures", [])
        expected_runtime_paths = {
            "evidence/runtime/fr_today_chrome_390.png",
            "evidence/runtime/fr_orientation_chrome_390.png",
            "evidence/runtime/fr_tax_year_chrome_390.png",
            "evidence/runtime/fr_tax_year_selected_chrome_390.png",
        }
        if {capture.get("path") for capture in captures} != expected_runtime_paths:
            errors.append("runtime evidence does not cover all three nodes and the honest selected boundary")
        for capture in captures:
            relative = capture.get("path", "")
            data = accepted_bytes(relative)
            if not data or capture.get("sha256") != hashlib.sha256(data).hexdigest():
                errors.append(f"runtime evidence hash drift: {capture.get('path', '<missing>')}")
                continue
            header = data[:24]
            if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
                errors.append(f"runtime evidence is not PNG: {capture['path']}")
            elif struct.unpack(">II", header[16:24]) != (390, 844):
                errors.append(f"runtime evidence dimensions drift: {capture['path']}")
    forbidden_claims = {"full_renderer", "product_ready", "user_validated", "calculation_verified"}
    if forbidden_claims & set(scope.get("honest_limitations", [])):
        errors.append("design-lab limitations contain contradictory readiness claims")
    if not acceptance_path.is_file():
        errors.append("missing fail-closed design-lab acceptance receipt")
    else:
        if digest(acceptance_path) != "757be7d1bd9d33247761b51ad0987433823c360d3496b09a26011be0e3515b55":
            errors.append("design-lab exact acceptance receipt digest drift")
        acceptance = yaml.safe_load(acceptance_path.read_text(encoding="utf-8"))
        if acceptance.get("status") != "mechanically_accepted_isolated_first_visual_slice":
            errors.append("design-lab acceptance status is not bounded and accepted")
        if acceptance.get("mechanical_acceptance_basis") != {
            "authority": "deterministic_commands_and_hash_bound_runtime_artifacts_only",
            "advisory_roasts_authorize_acceptance": False,
            "limitation": "agent identity independence and truthfulness are not authenticated",
        }:
            errors.append("design-lab mechanical acceptance basis drift")
        if acceptance.get("scope", {}).get("sha256") != digest(SCOPE):
            errors.append("design-lab acceptance scope hash drift")
        if acceptance.get("manifest", {}).get("sha256") != digest(MANIFEST):
            errors.append("design-lab acceptance manifest hash drift")
        artifacts = acceptance.get("artifacts", {})
        accepted_files = {
            "app": "lib/design_lab_app.dart",
            "runtime_receipt": "evidence/runtime/receipt.yaml",
            "web_host": "web/index.html",
        }
        for key, relative in accepted_files.items():
            if artifacts.get(key, {}).get("sha256") != entries[relative].sha256:
                errors.append(f"design-lab accepted artifact hash drift: {key}")
        reviews = acceptance.get("advisory_roasts", [])
        expected_verdicts = {
            "ux_architecture": "ACCEPT",
            "batch1_a11y_review": "PASS",
            "batch1_swiss_tax_review": "PASS",
        }
        if {review.get("agent"): review.get("verdict") for review in reviews} != expected_verdicts:
            errors.append("design-lab advisory roast record drift")
        for review in reviews:
            if review.get("p1") != 0 or review.get("p2") != 0:
                errors.append(f"design-lab acceptance has unresolved review findings: {review.get('agent')}")
            if review.get("bound_app_sha256") != entries["lib/design_lab_app.dart"].sha256:
                errors.append(f"design-lab review app hash drift: {review.get('agent')}")
            if review.get("bound_scope_sha256") != digest(SCOPE):
                errors.append(f"design-lab review scope hash drift: {review.get('agent')}")
        if set(acceptance.get("not_accepted", [])) != {
            "product_integration", "ios_runtime", "android_runtime", "calculation_engine", "personal_result", "user_validation"
        }:
            errors.append("design-lab acceptance limitations drift")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("OK mint_next_batch7_design_lab_guard: isolated first slice is hash-bound, local-only, and six-language.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
