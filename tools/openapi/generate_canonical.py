#!/usr/bin/env python3
"""Generate canonical OpenAPI spec from FastAPI app.

Produces a deterministic JSON output (sorted keys, consistent formatting)
for CI contract diffing. Excludes volatile fields (servers, version).

Usage: python tools/openapi/generate_canonical.py
"""

import json
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'services', 'backend'))

# Set testing env to avoid real DB connections
os.environ.setdefault('TESTING', '1')
os.environ.setdefault('DATABASE_URL', 'sqlite:///./test.db')

from app.main import app

def generate():
    spec = app.openapi()

    # Remove volatile fields that change between environments
    spec.pop('servers', None)
    if 'info' in spec:
        spec['info'].pop('version', None)
        spec['info'].pop('description', None)

    # Deterministic output
    canonical = json.dumps(spec, sort_keys=True, indent=2, ensure_ascii=False)

    output_path = os.path.join(os.path.dirname(__file__), 'mint.openapi.canonical.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(canonical)
        f.write('\n')  # trailing newline

    print(f"Canonical OpenAPI spec written to {output_path}")
    print(f"  Paths: {len(spec.get('paths', {}))}")
    print(f"  Schemas: {len(spec.get('components', {}).get('schemas', {}))}")

if __name__ == '__main__':
    generate()
