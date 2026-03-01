#!/usr/bin/env python3
"""Generate canonical OpenAPI spec from FastAPI app.

Produces a deterministic JSON output for CI contract diffing.

Problem: FastAPI assigns the "short" schema name (e.g. `EtatCivil`)
to whichever duplicate class is imported first, varying between runs.
The other duplicates get qualified names like
`app__schemas__coaching__EtatCivil`, but WHICH one gets the short name
is non-deterministic.

Solution: For every group of schemas sharing the same short name,
rename ALL of them (bare + qualified) to `h_<content_hash>__ShortName`.
Since the hash is derived from each schema's JSON content, the mapping
is stable regardless of import order.

Usage: python tools/openapi/generate_canonical.py
"""

import hashlib
import json
import re
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'services', 'backend'))

# Set testing env to avoid real DB connections
os.environ.setdefault('TESTING', '1')
os.environ.setdefault('DATABASE_URL', 'sqlite:///./test.db')

_QUALIFIED_RE = re.compile(r"^app__(?:\w+__)+(\w+)$")


def _short_name(schema_name: str) -> str:
    """Extract the short class name from a possibly qualified schema name."""
    m = _QUALIFIED_RE.match(schema_name)
    return m.group(1) if m else schema_name


def _stabilize_schema_names(spec: dict) -> dict:
    """Replace ALL ambiguous schema names with content-hash identifiers.

    When multiple schemas share the same short name (e.g. `EtatCivil`,
    `app__schemas__coaching__EtatCivil`, `app__schemas__segments__EtatCivil`),
    ALL of them are renamed to `h_<content_hash>__EtatCivil`.

    Schemas with unique short names are left unchanged.
    """
    schemas = spec.get("components", {}).get("schemas", {})
    if not schemas:
        return spec

    # Group all schema keys by their short name
    groups: dict[str, list[str]] = {}
    for key in schemas:
        short = _short_name(key)
        groups.setdefault(short, []).append(key)

    # Only rename groups with 2+ members (ambiguous short names)
    renames: dict[str, str] = {}
    for short, keys in groups.items():
        if len(keys) < 2:
            continue
        for key in keys:
            content = json.dumps(schemas[key], sort_keys=True)
            h = hashlib.sha256(content.encode()).hexdigest()[:12]
            renames[key] = f"h_{h}__{short}"

    if not renames:
        return spec

    # Apply renames via string replacement in serialized spec
    # Sort by longest key first to avoid partial replacements
    spec_json = json.dumps(spec, sort_keys=True)
    for old_name, new_name in sorted(renames.items(), key=lambda x: -len(x[0])):
        old_ref = f'"#/components/schemas/{old_name}"'
        new_ref = f'"#/components/schemas/{new_name}"'
        spec_json = spec_json.replace(old_ref, new_ref)

    spec = json.loads(spec_json)

    # Rename schema keys
    schemas = spec["components"]["schemas"]
    for old_name, new_name in renames.items():
        if old_name in schemas:
            schemas[new_name] = schemas.pop(old_name)

    return spec


def _normalize_validation_error_schema(spec: dict) -> dict:
    """Normalize framework-level ValidationError schema across FastAPI versions.

    FastAPI/Pydantic sometimes adds transient fields (e.g. `input`, `ctx`) that
    are not relevant to our API contract and cause CI drift across environments.
    Keep only stable, contract-relevant fields.
    """
    schemas = spec.get("components", {}).get("schemas", {})
    validation_error = schemas.get("ValidationError")
    if not isinstance(validation_error, dict):
        return spec

    properties = validation_error.get("properties")
    if not isinstance(properties, dict):
        return spec

    stable_fields = {"loc", "msg", "type"}
    filtered = {k: v for k, v in properties.items() if k in stable_fields}
    validation_error["properties"] = filtered

    required = validation_error.get("required")
    if isinstance(required, list):
        validation_error["required"] = sorted(
            field for field in required if field in stable_fields
        )

    return spec


def _normalize_binary_file_schema(node):
    """Normalize binary upload field shape across FastAPI versions.

    Older versions emit {"type":"string","format":"binary"} while newer ones
    emit {"type":"string","contentMediaType":"application/octet-stream"}.
    Canonicalize to contentMediaType.
    """
    if isinstance(node, dict):
        if node.get("type") == "string" and node.get("format") == "binary":
            node.pop("format", None)
            node.setdefault("contentMediaType", "application/octet-stream")
        for value in node.values():
            _normalize_binary_file_schema(value)
        return
    if isinstance(node, list):
        for item in node:
            _normalize_binary_file_schema(item)


def generate():
    from app.main import app  # noqa: E402

    # Clear cached spec to ensure fresh generation
    app.openapi_schema = None
    spec = app.openapi()

    # Remove volatile fields
    spec.pop('servers', None)
    if 'info' in spec:
        spec['info'].pop('version', None)
        spec['info'].pop('description', None)

    # Stabilize schema names
    spec = _stabilize_schema_names(spec)
    spec = _normalize_validation_error_schema(spec)
    _normalize_binary_file_schema(spec)

    # Deterministic output
    canonical = json.dumps(spec, sort_keys=True, indent=2, ensure_ascii=False)

    output_path = os.path.join(os.path.dirname(__file__), 'mint.openapi.canonical.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(canonical)
        f.write('\n')

    print(f"Canonical OpenAPI spec written to {output_path}")
    print(f"  Paths: {len(spec.get('paths', {}))}")
    print(f"  Schemas: {len(spec.get('components', {}).get('schemas', {}))}")


if __name__ == '__main__':
    generate()
