#!/usr/bin/env python3
"""Update GSD phase VERIFICATION-REPORT.html + session HTML rollup.

Invoked by gsd-executor at plan close + gsd-verifier at phase close.
Reads SUMMARY.md files from a phase directory, emits a single dashboard HTML
that Julien can open to see commit list / test deltas / deviations / 0-trust caveats
without reading 30KB of markdown per plan.

Why this exists:
  Memory feedback_html_evidence_report.md says every GSD phase MUST produce
  + update .planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html. The
  convention was oral, not codified. Plans 01-05 of mint-calc-engine-v1 shipped
  without any HTML evidence — this script closes that gap going forward AND
  backfills past plans.

Usage:
  python3 tools/gsd_infra/update_verification_html.py --phase <phase-slug>
  python3 tools/gsd_infra/update_verification_html.py --phase <phase-slug> --append-session
"""
from __future__ import annotations

import argparse
import datetime as dt
import html
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PHASES_DIR = PROJECT_ROOT / ".planning" / "phases"
REPORTS_DIR = PROJECT_ROOT / ".planning" / "reports"

# MINT brand colors for HTML — matches existing session HTML style
CSS = """
body { font: 14px/1.55 -apple-system, system-ui, sans-serif; max-width: 1100px; margin: 2em auto; padding: 0 1em; color: #1a2520; }
h1, h2, h3 { color: #003B2F; }
h1 { border-bottom: 3px solid #003B2F; padding-bottom: .3em; }
h2 { margin-top: 1.8em; border-bottom: 1px solid #d0d6d4; padding-bottom: .2em; }
h3 { margin-top: 1.2em; }
table { border-collapse: collapse; width: 100%; margin: .6em 0; }
th, td { border: 1px solid #ccc; padding: 6px 9px; text-align: left; font-size: 13px; vertical-align: top; }
th { background: #f4faf7; }
.pass { color: #0a7a4f; font-weight: 600; }
.partial { color: #b58b00; font-weight: 600; }
.fail { color: #b3261e; font-weight: 600; }
.deferred { color: #888; font-style: italic; }
code, pre { font: 12px/1.45 ui-monospace, Menlo, monospace; background: #f4f4f4; padding: 1px 4px; border-radius: 3px; }
pre { padding: 8px 12px; overflow-x: auto; }
blockquote { border-left: 3px solid #d0d6d4; padding: .2em .8em; color: #555; margin: .5em 0; }
.meta { color: #666; font-size: 12px; }
.caveat { background: #fff8e6; border-left: 4px solid #b58b00; padding: 8px 12px; margin: .5em 0; }
.sha { font-family: ui-monospace, Menlo, monospace; color: #555; font-size: 12px; }
"""


def parse_summary(path: Path) -> dict:
    """Extract key fields from a SUMMARY.md.

    Tolerant: looks for sections by header pattern. Missing sections → empty.
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    out = {
        "path": str(path.relative_to(PROJECT_ROOT)),
        "plan_id": path.stem.replace("-SUMMARY", ""),
        "tasks": "?",
        "commits": [],
        "tests": "",
        "deviations": "",
        "trust_caveat": "",
        "blockers": "",
    }

    # Tasks completed: "Tasks completed: N/M" or "Tasks: N/M"
    m = re.search(r"\*\*Tasks(?:\s+completed)?:\*\*\s*(\d+\s*/\s*\d+|\d+\s+of\s+\d+)", text, re.I)
    if m:
        out["tasks"] = m.group(1).strip()

    # Commits: lines starting with - `sha` ... in a Commits section, or just `sha` ... pattern
    commits_section = re.search(r"(?:###?\s*Commits[^\n]*\n+)((?:[-*]?\s*[`“]?[0-9a-f]{7,40}[`”]?[^\n]*\n)+)", text, re.I)
    if commits_section:
        for line in commits_section.group(1).split("\n"):
            sha_match = re.search(r"`?([0-9a-f]{7,40})`?\s*[—\-:]?\s*(.+)?", line.strip().lstrip("-*").strip())
            if sha_match:
                sha = sha_match.group(1)
                msg = (sha_match.group(2) or "").strip()
                if sha and len(sha) >= 7:
                    out["commits"].append({"sha": sha, "msg": msg[:200]})

    # Test results: grab line with "passed" near end-of-run
    test_match = re.search(r"(\d[\d,]*\s+passed[^\n]{0,200})", text)
    if test_match:
        out["tests"] = test_match.group(1).strip()

    # Deviations: section header (Deviations / Deviation)
    dev_match = re.search(r"###?\s*Deviations?[^\n]*\n+(.*?)(?=\n###?\s|\Z)", text, re.S | re.I)
    if dev_match:
        out["deviations"] = dev_match.group(1).strip()[:1500]

    # 0-trust caveat
    trust_match = re.search(r"(?:0[-\s]?trust|0[-\s]?Trust)[^\n]*\n+(.*?)(?=\n###?\s|\Z)", text, re.S)
    if trust_match:
        out["trust_caveat"] = trust_match.group(1).strip()[:1500]

    # Blockers
    block_match = re.search(r"###?\s*Blockers?[^\n]*\n+(.*?)(?=\n###?\s|\Z)", text, re.S | re.I)
    if block_match:
        out["blockers"] = block_match.group(1).strip()[:500]

    return out


def render_phase_html(phase_slug: str, summaries: list[dict]) -> str:
    """Render the phase VERIFICATION-REPORT.html dashboard."""
    now_iso = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    plan_count = len(summaries)
    rows = []
    for s in summaries:
        commits_html = "<br>".join(
            f"<span class='sha'>{html.escape(c['sha'][:8])}</span> {html.escape(c['msg'])}"
            for c in s["commits"][:10]
        ) or "<span class='deferred'>none parsed</span>"
        rows.append(f"""
        <tr>
          <td>{html.escape(s['plan_id'])}</td>
          <td>{html.escape(s['tasks'])}</td>
          <td>{commits_html}</td>
          <td><span class='pass'>{html.escape(s['tests'] or 'n/a')}</span></td>
          <td><a href="{html.escape(s['path'])}">SUMMARY.md</a></td>
        </tr>""")
    rows_html = "".join(rows)

    caveats = []
    for s in summaries:
        if s["trust_caveat"]:
            caveats.append(f"""<div class='caveat'><strong>{html.escape(s['plan_id'])}</strong><br><pre style='white-space:pre-wrap'>{html.escape(s['trust_caveat'][:1200])}</pre></div>""")
    caveats_html = "\n".join(caveats) or "<p class='deferred'>No 0-trust caveats parsed.</p>"

    deviations = []
    for s in summaries:
        if s["deviations"]:
            deviations.append(f"""<h3>{html.escape(s['plan_id'])}</h3><pre style='white-space:pre-wrap;background:#f4f4f4;padding:8px 12px;font-size:12px'>{html.escape(s['deviations'][:1500])}</pre>""")
    deviations_html = "\n".join(deviations) or "<p class='deferred'>No deviations parsed.</p>"

    return f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Phase {html.escape(phase_slug)} — Verification Report</title>
<style>{CSS}</style>
</head>
<body>
<h1>Phase {html.escape(phase_slug)} — Verification Report</h1>
<p class="meta">Generated: {now_iso} · Plans: {plan_count} · Auto-generated by <code>tools/gsd_infra/update_verification_html.py</code></p>

<h2>Plans</h2>
<table>
<thead><tr><th>Plan</th><th>Tasks</th><th>Commits</th><th>Tests</th><th>SUMMARY</th></tr></thead>
<tbody>{rows_html}</tbody>
</table>

<h2>0-Trust Caveats</h2>
{caveats_html}

<h2>Deviations from PLAN</h2>
{deviations_html}

</body>
</html>"""


def append_to_session_html(phase_slug: str, summaries: list[dict]) -> Path:
    """Append/refresh a section in today's SESSION-YYYY-MM-DD.html.

    Idempotent: if a phase section already exists for today, replace it.
    """
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    today = dt.date.today().isoformat()
    session_path = REPORTS_DIR / f"SESSION-{today}.html"

    plans_table_rows = "".join(
        f"<tr><td>{html.escape(s['plan_id'])}</td><td>{html.escape(s['tasks'])}</td>"
        f"<td><span class='pass'>{html.escape(s['tests'] or 'n/a')}</span></td>"
        f"<td>{len(s['commits'])}</td></tr>"
        for s in summaries
    )
    section_anchor = f"phase-{phase_slug}"
    section_html = f"""<!-- BEGIN phase {phase_slug} -->
<section id="{section_anchor}">
<h2>Phase <code>{html.escape(phase_slug)}</code></h2>
<p class="meta">Updated: {dt.datetime.now().strftime("%H:%M")} · {len(summaries)} plans with SUMMARY · Full report: <a href="../phases/{html.escape(phase_slug)}/{html.escape(phase_slug)}-VERIFICATION-REPORT.html">{html.escape(phase_slug)}-VERIFICATION-REPORT.html</a></p>
<table>
<thead><tr><th>Plan</th><th>Tasks</th><th>Tests</th><th>Commits</th></tr></thead>
<tbody>{plans_table_rows}</tbody>
</table>
</section>
<!-- END phase {phase_slug} -->
"""

    if session_path.exists():
        existing = session_path.read_text(encoding="utf-8", errors="replace")
        pattern = re.compile(
            rf"<!-- BEGIN phase {re.escape(phase_slug)} -->.*?<!-- END phase {re.escape(phase_slug)} -->\n?",
            re.S,
        )
        if pattern.search(existing):
            new_content = pattern.sub(section_html, existing)
        else:
            insertion = "</body>"
            new_content = existing.replace(insertion, section_html + "\n" + insertion)
        session_path.write_text(new_content, encoding="utf-8")
    else:
        title = f"GSD Session {today}"
        full = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
</head>
<body>
<h1>{html.escape(title)}</h1>
<p class="meta">Auto-generated by <code>tools/gsd_infra/update_verification_html.py</code>. Each GSD plan close appends/refreshes its phase section here.</p>
{section_html}
</body>
</html>"""
        session_path.write_text(full, encoding="utf-8")

    return session_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--phase", required=True, help="Phase slug (e.g. mint-calc-engine-v1)")
    parser.add_argument("--append-session", action="store_true", help="Also append/refresh today's SESSION-*.html")
    args = parser.parse_args()

    phase_dir = PHASES_DIR / args.phase
    if not phase_dir.is_dir():
        print(f"ERROR: phase dir not found: {phase_dir}", file=sys.stderr)
        return 1

    summary_paths = sorted(phase_dir.glob(f"{args.phase}-*-SUMMARY.md"))
    if not summary_paths:
        print(f"ERROR: no SUMMARY.md files in {phase_dir}", file=sys.stderr)
        return 1

    summaries = [parse_summary(p) for p in summary_paths]

    out_path = phase_dir / f"{args.phase}-VERIFICATION-REPORT.html"
    out_path.write_text(render_phase_html(args.phase, summaries), encoding="utf-8")
    print(f"Wrote {out_path.relative_to(PROJECT_ROOT)} ({len(summaries)} plans)")

    if args.append_session:
        session_path = append_to_session_html(args.phase, summaries)
        print(f"Updated {session_path.relative_to(PROJECT_ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
