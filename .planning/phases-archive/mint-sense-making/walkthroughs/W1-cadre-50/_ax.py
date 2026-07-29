#!/usr/bin/env python3
"""Parse idb ui describe-all JSON from stdin into a readable table."""
import sys, json
try:
    data = json.load(sys.stdin)
except Exception as e:
    print("PARSE_ERROR", e); sys.exit(1)
if not isinstance(data, list):
    print("NOT_A_LIST"); sys.exit(1)
rows = 0
for e in data:
    label = e.get('AXLabel') or ''
    val = e.get('AXValue') or ''
    t = e.get('type') or ''
    f = e.get('frame', {}) or {}
    x, y = f.get('x', 0), f.get('y', 0)
    w, h = f.get('width', 0), f.get('height', 0)
    if t == 'Application' and not label:
        continue
    cx, cy = x + w/2, y + h/2
    disp = (label or val or t)[:55]
    print(f"{t:11} | {disp:55} | tap({cx:.0f},{cy:.0f}) | wh={w:.0f}x{h:.0f}")
    rows += 1
print(f"--- {rows} interactive/labeled nodes (of {len(data)} total) ---")
