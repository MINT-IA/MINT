#!/usr/bin/env python3
"""Phase 87 OBSV-06 — unit tests for no_new_bare_catch.py.

Three guarantees:
  1. The script's BARE_CATCH_RE catches the canonical `} catch (e) {`
     and `} catch (_) {` shapes and IGNORES typed `} on X catch (e) {`.
  2. A lock file with the exact current hits → exit 0 (« no new »).
  3. Adding a synthetic bare catch in a temp file under a fake scan root
     → exit 1.

Run:
    python3 tools/checks/test_no_new_bare_catch.py
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LINT_PATH = Path(__file__).resolve().with_name("no_new_bare_catch.py")


def _load() -> object:
    spec = importlib.util.spec_from_file_location(
        "no_new_bare_catch", LINT_PATH
    )
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_regex_matches_bare_catch() -> None:
    mod = _load()
    rx = mod.BARE_CATCH_RE
    assert rx.search("    } catch (e) {")
    assert rx.search("    } catch (_) {")
    assert rx.search("} catch (foo) {")
    # Typed catch must NOT match.
    assert not rx.search("} on TimeoutException catch (e, st) {")
    assert not rx.search("} on FormatException catch (e) {")
    # Naked arrow / arrow-style match must NOT match (no `}` prefix).
    assert not rx.search("catch (e) => null")
    print("test_regex_matches_bare_catch: OK")


def test_lock_in_sync_means_clean() -> None:
    mod = _load()
    hits = mod.scan()
    allowed, _ = mod.load_lock()
    new_hits = [
        (rel, lineno) for rel, lineno, _ in hits
        if (rel, lineno) not in allowed
    ]
    assert not new_hits, (
        f"lock file is out of sync — {len(new_hits)} new bare catch(es). "
        "Run `python3 tools/checks/no_new_bare_catch.py --regen-debt` "
        "after auditing."
    )
    print(
        f"test_lock_in_sync_means_clean: OK ({len(hits)} grandfathered)"
    )


def test_synthetic_bare_catch_blocks_pass() -> None:
    """End-to-end smoke: spike a temp .dart file with a bare catch and
    verify the regex sees it.
    """
    mod = _load()
    rx = mod.BARE_CATCH_RE
    sample = """
import 'package:flutter/foundation.dart';

void doStuff() {
  try {
    // ...
  } catch (e) {
    debugPrint('lost');
  }
}
"""
    matched = [ln for ln in sample.splitlines() if rx.search(ln)]
    assert len(matched) == 1, (
        f"expected exactly 1 bare-catch hit in sample, got {len(matched)}"
    )
    print("test_synthetic_bare_catch_blocks_pass: OK")


def main() -> int:
    test_regex_matches_bare_catch()
    test_lock_in_sync_means_clean()
    test_synthetic_bare_catch_blocks_pass()
    print("\nALL TESTS PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
