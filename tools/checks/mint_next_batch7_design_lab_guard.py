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
SCOPE = ROOT / "product/mint_next/batch7/design-lab-scope.yaml"
LAB = ROOT / "product/mint_next/batch7/design_lab"
NAVIGATION = ROOT / "product/mint_next/batch6/navigation.yaml"
MOBILE_FONTS = ROOT / "apps/mobile/assets/fonts"
RUNTIME_RECEIPT = LAB / "evidence/runtime/receipt.yaml"
ACCEPTANCE = ROOT / "product/mint_next/batch7/design-lab-acceptance.yaml"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def formal_voice_errors(path: Path, locale: str) -> list[str]:
    formal_terms = {
        "fr": ("vous", "votre", "vos"),
        "de": ("Sie", "Ihr", "Ihre", "Ihren", "Ihrem"),
        "es": ("usted", "su", "sus"),
        "it": ("vi", "vostra", "vostro", "vostre", "vostri"),
        "pt": ("si", "seu", "seus", "sua", "suas"),
    }
    values = " ".join(
        value for key, value in json.loads(path.read_text(encoding="utf-8")).items()
        if not key.startswith("@") and isinstance(value, str)
    )
    found = [
        term for term in formal_terms.get(locale, ())
        if re.search(rf"(?<!\w){re.escape(term)}(?!\w)", values)
    ]
    if found:
        return [f"{locale} copy drifts from informal singular voice: {', '.join(found)}"]
    return []


def validate(scope_path: Path = SCOPE) -> list[str]:
    scope = yaml.safe_load(scope_path.read_text(encoding="utf-8"))
    errors: list[str] = []
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
    pubspec = yaml.safe_load((LAB / "pubspec.yaml").read_text(encoding="utf-8"))
    dependencies = set(pubspec.get("dependencies", {}))
    if dependencies != {"flutter", "flutter_localizations", "intl"}:
        errors.append("design lab introduced undeclared network or product dependencies")
    product_imports = []
    for path in (ROOT / "apps/mobile/lib").rglob("*.dart"):
        if "mint_next_design_lab" in path.read_text(encoding="utf-8"):
            product_imports.append(str(path.relative_to(ROOT)))
    if product_imports:
        errors.append("product imports the isolated design lab: " + ", ".join(product_imports))
    for name in ("Supreme-Regular.otf", "Supreme-Medium.otf", "Supreme-Bold.otf", "Gambarino-Regular.otf"):
        if digest(LAB / "assets/fonts" / name) != digest(MOBILE_FONTS / name):
            errors.append(f"design-lab font drift: {name}")
    locales = scope.get("first_visual_slice", {}).get("locales", [])
    if locales != ["fr", "en", "de", "it", "es", "pt"]:
        errors.append("six-locale scope is incomplete or reordered")
    arb_keys: dict[str, set[str]] = {}
    for locale in locales:
        path = LAB / "lib/l10n" / f"app_{locale}.arb"
        if not path.is_file():
            errors.append(f"missing ARB locale: {locale}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        arb_keys[locale] = {key for key in data if not key.startswith("@")}
    if arb_keys and any(keys != arb_keys.get("fr") for keys in arb_keys.values()):
        errors.append("design-lab ARB keys are not identical across six locales")
    for locale in ("fr", "de", "es", "it", "pt"):
        path = LAB / "lib/l10n" / f"app_{locale}.arb"
        if not path.is_file():
            continue
        errors.extend(formal_voice_errors(path, locale))
    source = (LAB / "lib/design_lab_app.dart").read_text(encoding="utf-8")
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
    if not RUNTIME_RECEIPT.is_file():
        errors.append("missing standalone runtime evidence receipt")
    else:
        receipt = yaml.safe_load(RUNTIME_RECEIPT.read_text(encoding="utf-8"))
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
            path = LAB / capture.get("path", "")
            if not path.is_file() or capture.get("sha256") != digest(path):
                errors.append(f"runtime evidence hash drift: {capture.get('path', '<missing>')}")
                continue
            with path.open("rb") as stream:
                header = stream.read(24)
            if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
                errors.append(f"runtime evidence is not PNG: {capture['path']}")
            elif struct.unpack(">II", header[16:24]) != (390, 844):
                errors.append(f"runtime evidence dimensions drift: {capture['path']}")
    forbidden_claims = {"full_renderer", "product_ready", "user_validated", "calculation_verified"}
    if forbidden_claims & set(scope.get("honest_limitations", [])):
        errors.append("design-lab limitations contain contradictory readiness claims")
    if not ACCEPTANCE.is_file():
        errors.append("missing fail-closed design-lab acceptance receipt")
    else:
        acceptance = yaml.safe_load(ACCEPTANCE.read_text(encoding="utf-8"))
        if acceptance.get("status") != "accepted_isolated_first_visual_slice":
            errors.append("design-lab acceptance status is not bounded and accepted")
        if acceptance.get("scope", {}).get("sha256") != digest(SCOPE):
            errors.append("design-lab acceptance scope hash drift")
        artifacts = acceptance.get("artifacts", {})
        accepted_files = {
            "app": LAB / "lib/design_lab_app.dart",
            "runtime_receipt": RUNTIME_RECEIPT,
            "web_host": LAB / "web/index.html",
        }
        for key, path in accepted_files.items():
            if artifacts.get(key, {}).get("sha256") != digest(path):
                errors.append(f"design-lab accepted artifact hash drift: {key}")
        reviews = acceptance.get("reviews", [])
        if {review.get("agent") for review in reviews} != {
            "ux_architecture", "batch1_a11y_review", "batch1_swiss_tax_review"
        }:
            errors.append("design-lab acceptance lacks the three independent reviews")
        for review in reviews:
            if review.get("p1") != 0 or review.get("p2") != 0:
                errors.append(f"design-lab acceptance has unresolved review findings: {review.get('agent')}")
            if review.get("bound_app_sha256") != digest(LAB / "lib/design_lab_app.dart"):
                errors.append(f"design-lab review app hash drift: {review.get('agent')}")
            if review.get("bound_scope_sha256") != digest(SCOPE):
                errors.append(f"design-lab review scope hash drift: {review.get('agent')}")
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
