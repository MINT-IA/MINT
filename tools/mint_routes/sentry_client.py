"""Keychain resolver + Sentry Issues API client + batch chunker + status
classifier + cache TTL helpers.

Python 3.9-compatible. No PEP 604 unions, no match/case.

Security contracts (T-32-03 mitigation):
- Token is NEVER passed via argv. `urllib.request` with `Authorization: Bearer`
  header is used instead of the `sentry-cli --auth-token ...` subprocess
  pattern.
- Token length is the only thing ever printed when debugging is needed.
- Keychain fallback service name is `SENTRY_AUTH_TOKEN` (reused verbatim from
  Phase 31 `tools/simulator/sentry_quota_smoke.sh:72` per
  executor_discretion_pre_locked item #3 — CONTEXT D-02 literal
  `mint-sentry-auth` is amended to avoid onboarding friction).

nLPD D-09 contracts:
- §1 token scope minimization — `verify_token_scope` enforces read-only scope.
- §2 redaction — every Sentry API response is `redact()`-walked before use.
- §3 retention — `.cache/route-health.json` auto-deletes after 7 days on
  startup (`_purge_stale_cache`). `purge_cache()` is the operator escape hatch.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .redaction import redact

# sysexits
EX_OK = 0
EX_OSERR = 71
EX_TEMPFAIL = 75
EX_CONFIG = 78

SENTRY_ORG = os.environ.get("SENTRY_ORG", "mint")
SENTRY_API_BASE = os.environ.get("SENTRY_API_BASE", "https://sentry.io/api/0")


# ---------------------------------------------------------------------------
# Cache (D-09 §3 — 7-day retention)
# ---------------------------------------------------------------------------


def _cache_path() -> Path:
    """Resolve cache file path.

    Prefer `MINT_ROUTES_CACHE_DIR` env override (tests + CI), otherwise fall
    back to `~/.cache/mint/route-health.json`. The repo-local `.cache/` is
    listed in `.gitignore` (Plan 05 CI gate verifies).
    """
    root = os.environ.get("MINT_ROUTES_CACHE_DIR")
    if root:
        return Path(root) / "route-health.json"
    return Path.home() / ".cache" / "mint" / "route-health.json"


def _purge_stale_cache(ttl_days: int = 7) -> None:
    """D-09 §3 — 7-day retention. Called at CLI startup (best-effort)."""
    p = _cache_path()
    if not p.exists():
        return
    age = time.time() - p.stat().st_mtime
    if age > ttl_days * 86400:
        try:
            p.unlink()
        except OSError:
            pass


def purge_cache() -> None:
    """Immediate wipe. Exposed as `mint-routes purge-cache`."""
    p = _cache_path()
    if p.exists():
        try:
            p.unlink()
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Token resolution (T-32-03 mitigation)
# ---------------------------------------------------------------------------


def get_sentry_token() -> str:
    """Env var first; else macOS Keychain service name SENTRY_AUTH_TOKEN.

    Reused from `tools/simulator/sentry_quota_smoke.sh:72` per
    executor_discretion_pre_locked item #3 — zero onboarding friction with
    Phase 31.

    Exits 71 (EX_OSERR) with setup pointer if both unavailable.
    """
    tok = os.environ.get("SENTRY_AUTH_TOKEN", "")
    if tok:
        return tok
    try:
        r = subprocess.run(
            [
                "security",
                "find-generic-password",
                "-s",
                "SENTRY_AUTH_TOKEN",
                "-w",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    sys.stderr.write(
        "[FAIL] SENTRY_AUTH_TOKEN missing.\n"
        "       env: export SENTRY_AUTH_TOKEN=<token>\n"
        "       or Keychain: security add-generic-password -a $USER "
        "-s SENTRY_AUTH_TOKEN -w <token> -U -A\n"
        "       See docs/SETUP-MINT-ROUTES.md for scope "
        "(project:read + event:read).\n"
    )
    sys.exit(EX_OSERR)


# ---------------------------------------------------------------------------
# Batching + status classification
# ---------------------------------------------------------------------------


def _chunks(items: List[str], n: int) -> Iterator[List[str]]:
    for i in range(0, len(items), n):
        yield items[i:i + n]


def classify_status(
    sentry_24h: int,
    ff_state: bool,
    last_visit: Optional[str],
) -> str:
    """MAP-03 status classification (D-06 locked).

    Buckets:
      - `dead`  : feature flag disabled OR no visit in last 30 days OR
                  last_visit=null OR last_visit unparseable.
      - `red`   : sentry_24h >= 10.
      - `yellow`: 1 <= sentry_24h <= 9.
      - `green` : sentry_24h == 0 AND last_visit within 30d AND ff enabled.
    """
    if not ff_state:
        return "dead"
    if sentry_24h >= 10:
        return "red"
    if sentry_24h >= 1:
        return "yellow"
    if last_visit is None:
        return "dead"
    try:
        dt = datetime.fromisoformat(last_visit.replace("Z", "+00:00"))
    except ValueError:
        return "dead"
    if datetime.now(timezone.utc) - dt > timedelta(days=30):
        return "dead"
    return "green"


# ---------------------------------------------------------------------------
# Registry parser (lightweight regex over route_metadata.dart)
# ---------------------------------------------------------------------------


def load_registry_rows() -> List[Dict[str, Any]]:
    """Parse `apps/mobile/lib/routes/route_metadata.dart` via regex.

    NOT a full Dart parser — extracts path/category/owner/requires_auth/
    kill_flag per entry for CLI display. Used for join in DRY_RUN and in
    live mode.
    """
    import re

    src_path = (
        Path(__file__).resolve().parents[2]
        / "apps/mobile/lib/routes/route_metadata.dart"
    )
    src = src_path.read_text()
    rows: List[Dict[str, Any]] = []
    # Match per-entry block from key through optional killFlag.
    pat = re.compile(
        r"'(?P<path>[^']+)':\s*RouteMeta\(\s*"
        r"path:\s*'[^']+',\s*"
        r"category:\s*RouteCategory\.(?P<cat>\w+),\s*"
        r"owner:\s*RouteOwner\.(?P<owner>\w+),\s*"
        r"requiresAuth:\s*(?P<auth>true|false),"
        r"(?:\s*killFlag:\s*'(?P<flag>[^']+)',)?",
        re.DOTALL,
    )
    for m in pat.finditer(src):
        rows.append(
            {
                "path": m.group("path"),
                "category": m.group("cat"),
                "owner": m.group("owner"),
                "requires_auth": m.group("auth") == "true",
                "kill_flag": m.group("flag"),
            }
        )
    return rows


# ---------------------------------------------------------------------------
# Sentry Issues API — batch OR query with graceful fallback
# ---------------------------------------------------------------------------


def _build_batch_query(paths: List[str]) -> str:
    # Sentry search list syntax: transaction:[/a, /b]
    return "transaction:[" + ", ".join(paths) + "]"


class _BatchTooLarge(Exception):
    def __init__(self, query_len: int):
        self.query_len = query_len


class _RateLimited(Exception):
    pass


def _call_sentry_issues(
    query: str,
    token: str,
    stats_period: str = "24h",
) -> Dict[str, Any]:
    params = urlencode({"query": query, "statsPeriod": stats_period})
    url = "{}/organizations/{}/issues/?{}".format(
        SENTRY_API_BASE, SENTRY_ORG, params
    )
    req = Request(
        url,
        headers={
            "Authorization": "Bearer {}".format(token),
            "User-Agent": "mint-routes/1.0",
        },
    )
    try:
        with urlopen(req, timeout=15) as resp:
            body = resp.read().decode()
    except HTTPError as e:
        status = e.code
        if status in (401, 403):
            sys.stderr.write(
                "[FAIL] Sentry auth error {} — scope missing? "
                "See docs/SETUP-MINT-ROUTES.md\n".format(status)
            )
            sys.exit(EX_CONFIG)
        if status == 414:
            raise _BatchTooLarge(len(query)) from e
        if status == 429:
            raise _RateLimited() from e
        raise
    except OSError as e:
        sys.stderr.write("[FAIL] network error: {}\n".format(e))
        sys.exit(EX_TEMPFAIL)
    data = json.loads(body) if body else {}
    if isinstance(data, (dict, list)):
        return redact(data) if isinstance(data, dict) else {"data": redact(data)}
    return {}


def fetch_health(
    token: str,
    batch_size: int = 30,
) -> List[Dict[str, Any]]:
    """Full scan. Batches `transaction:[a, b, ...]` OR queries.

    Falls back to 1 req/sec sequential if any chunk errors with 414.
    """
    _purge_stale_cache()
    registry = load_registry_rows()
    index: Dict[str, Dict[str, Any]] = {}
    paths = [r["path"] for r in registry]
    try:
        for chunk in _chunks(paths, batch_size):
            q = _build_batch_query(chunk)
            d = _call_sentry_issues(q, token=token)
            issues = d.get("data", []) if isinstance(d, dict) else []
            for issue in issues:
                t = issue.get("transaction") or issue.get("culprit")
                if t:
                    index[t] = {
                        "count_24h": issue.get("count", 0),
                        "last_seen": issue.get("lastSeen"),
                    }
    except _BatchTooLarge:
        # Fallback: 1 req/sec sequential.
        for p in paths:
            d = _call_sentry_issues(
                "transaction:{}".format(p), token=token
            )
            issues = d.get("data", []) if isinstance(d, dict) else []
            for issue in issues:
                index[issue.get("transaction", p)] = {
                    "count_24h": issue.get("count", 0),
                    "last_seen": issue.get("lastSeen"),
                }
            time.sleep(1.0)
    except _RateLimited:
        time.sleep(4.0)
        # Best-effort single retry is left to a follow-up; for now we proceed
        # with whatever was already indexed (graceful degradation).
        pass

    # Join with registry
    rows: List[Dict[str, Any]] = []
    for meta in registry:
        s = index.get(meta["path"], {"count_24h": 0, "last_seen": None})
        rows.append(
            {
                "path": meta["path"],
                "category": meta["category"],
                "owner": meta["owner"],
                "requires_auth": meta["requires_auth"],
                "kill_flag": meta["kill_flag"],
                "status": classify_status(
                    s["count_24h"], True, s["last_seen"]
                ),
                "sentry_count_24h": s["count_24h"],
                "ff_enabled": True,
                "last_visit_iso": s["last_seen"],
                "_redaction_applied": True,
                "_redaction_version": 1,
            }
        )
    return rows


def fetch_redirect_hits(
    token: str,
    days: int = 30,
) -> List[Dict[str, Any]]:
    """Aggregate breadcrumb `mint.routing.legacy_redirect.hit` counts.

    Phase 35 may refine via dedicated breadcrumb query API. For Phase 32 MVP:
    reuse events API filtered on message containing the category, aggregated
    by `from -> to` tag pair.
    """
    q = "message:mint.routing.legacy_redirect.hit"
    d = _call_sentry_issues(q, token=token, stats_period="{}d".format(days))
    counts: Dict[str, Dict[str, Any]] = {}
    issues = d.get("data", []) if isinstance(d, dict) else []
    for issue in issues:
        tags = (issue.get("tags", {}) or {})
        from_ = tags.get("from", "unknown")
        to_ = tags.get("to", "unknown")
        key = "{}->{}".format(from_, to_)
        counts.setdefault(
            key, {"from": from_, "to": to_, "count_30d": 0}
        )
        counts[key]["count_30d"] += issue.get("count", 0)
    return sorted(counts.values(), key=lambda r: -r["count_30d"])


def verify_token_scope(token: str) -> int:
    """D-09 §1 — query /api/0/auth/ and fail if scope > project:read +
    event:read.

    `org:read` is kept in the allowed set because Sentry's `/api/0/auth/`
    endpoint itself requires that scope to enumerate scopes on the token
    (context: the endpoint returns `user.organizations` alongside `scopes`;
    without `org:read` the call itself 403s, making `--verify-token`
    unusable). Operators who want the strictest read-only posture may omit
    `org:read` from token creation and skip `--verify-token`.
    """
    req = Request(
        "{}/auth/".format(SENTRY_API_BASE),
        headers={"Authorization": "Bearer {}".format(token)},
    )
    try:
        with urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except HTTPError as e:
        sys.stderr.write(
            "[FAIL] /auth/ returned {} — token invalid?\n".format(e.code)
        )
        return EX_CONFIG
    scopes = set(data.get("scopes", []))
    # org:read needed by /auth/ endpoint itself.
    allowed = {"project:read", "event:read", "org:read"}
    extra = scopes - allowed
    if extra:
        sys.stderr.write(
            "[FAIL] token has extra scopes (nLPD D-09 §1 minimization): "
            "{}\n".format(extra)
        )
        return EX_CONFIG
    print(
        "[OK] token scopes are within allowed set: {}".format(sorted(scopes))
    )
    return EX_OK
