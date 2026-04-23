"""GUARD-02 pytest coverage — 12 cases covering D-05/D-06/D-07.

Technical English only — dev-facing diagnostics per CLAUDE.md §2
self-compliance (Pitfall 8) and Phase 32-03 M-1 admin carve-out.

Covers:
  - D-05 Dart `} catch (e) {}` + Python `except Exception: pass` detection
  - D-06 exemptions: apps/mobile/test, integration_test, services/backend/tests,
    async* Dart streams, inline override comment on preceding line
  - D-07 diff-only mode (critical): existing bare-catches are ignored; only
    bare-catches introduced by the staged diff are flagged

Uses the tmp_git_repo fixture from conftest.py to isolate diff state.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "checks"))

import no_bare_catch as lint  # noqa: E402


def _stage(repo: Path, rel: str, content: str) -> None:
    """Write and `git add` a file in the repo."""
    p = repo / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    subprocess.run(["git", "-C", str(repo), "add", rel], check=True)


def _run_lint(repo: Path, files: list[str]) -> tuple[int, list[str]]:
    violations: list[str] = []
    for f in files:
        violations.extend(lint.process_file(f, repo_root=repo))
    return (1 if violations else 0, violations)


# --- D-05 bare-catch detection -------------------------------------------


def test_dart_bare_catch_empty(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "foo.dart",
        "void f() {\n  try { x(); } catch (e) {}\n}\n",
    )
    rc, vios = _run_lint(tmp_git_repo, ["foo.dart"])
    assert rc == 1
    assert any("bare-catch" in v for v in vios)


def test_python_bare_except_pass(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "bar.py",
        "def f():\n    try:\n        x()\n    except Exception:\n        pass\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["bar.py"])
    assert rc == 1


def test_python_bare_except_colon_eol(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "baz.py",
        "def f():\n    try:\n        x()\n    except:\n        pass\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["baz.py"])
    assert rc == 1


# --- D-06 exemptions -----------------------------------------------------


def test_test_dir_exempt(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "apps/mobile/test/foo_test.dart",
        "void f() { try { x(); } catch (e) {} }\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["apps/mobile/test/foo_test.dart"])
    assert rc == 0


def test_integration_test_exempt(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "apps/mobile/integration_test/foo.dart",
        "void f() { try { x(); } catch (e) {} }\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["apps/mobile/integration_test/foo.dart"])
    assert rc == 0


def test_services_backend_tests_exempt(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "services/backend/tests/test_x.py",
        "def f():\n    try: x()\n    except: pass\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["services/backend/tests/test_x.py"])
    assert rc == 0


def test_async_star_exempt(tmp_git_repo: Path):
    content = (
        "Stream<int> produce() async* {\n"
        "  try {\n"
        "    yield 1;\n"
        "  } catch (e) {}\n"
        "}\n"
    )
    _stage(tmp_git_repo, "stream.dart", content)
    rc, _ = _run_lint(tmp_git_repo, ["stream.dart"])
    assert rc == 0


# --- Inline override (D-06) — PRECEDING-LINE semantics -------------------


def test_inline_override_valid(tmp_git_repo: Path):
    # Override comment on line IMMEDIATELY PRECEDING the bare-catch.
    _stage(
        tmp_git_repo,
        "ok.dart",
        "void f() {\n"
        "  // lefthook-allow:bare-catch: legitimate dev fallback only\n"
        "  try { x(); } catch (e) {}\n"
        "}\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["ok.dart"])
    assert rc == 0


def test_inline_override_insufficient_reason(tmp_git_repo: Path):
    _stage(
        tmp_git_repo,
        "bad.dart",
        "void f() {\n"
        "  // lefthook-allow:bare-catch: short\n"
        "  try { x(); } catch (e) {}\n"
        "}\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["bad.dart"])
    assert rc == 1


# --- D-07 diff-only (CRITICAL) -------------------------------------------


def test_diff_only_ignores_existing_bad(tmp_git_repo: Path):
    # Pre-existing bare-catch at line 2.
    (tmp_git_repo / "existing.dart").write_text(
        "void f() {\n  try { x(); } catch (e) {}\n}\nvoid g() {}\n",
        encoding="utf-8",
    )
    subprocess.run(
        ["git", "-C", str(tmp_git_repo), "add", "existing.dart"], check=True
    )
    subprocess.run(
        ["git", "-C", str(tmp_git_repo), "commit", "-q", "-m", "initial"], check=True
    )
    # Add an unrelated line (no new bare-catch).
    (tmp_git_repo / "existing.dart").write_text(
        "void f() {\n  try { x(); } catch (e) {}\n}\nvoid g() {}\n"
        "void h() { print('x'); }\n",
        encoding="utf-8",
    )
    subprocess.run(
        ["git", "-C", str(tmp_git_repo), "add", "existing.dart"], check=True
    )
    rc, _ = _run_lint(tmp_git_repo, ["existing.dart"])
    assert rc == 0, "D-07 diff-only mode must ignore pre-existing bad lines"


def test_diff_adds_bare_catch_to_file_with_existing(tmp_git_repo: Path):
    (tmp_git_repo / "foo.dart").write_text(
        "void f() {\n  try { x(); } catch (e) {}\n}\n",
        encoding="utf-8",
    )
    subprocess.run(["git", "-C", str(tmp_git_repo), "add", "foo.dart"], check=True)
    subprocess.run(
        ["git", "-C", str(tmp_git_repo), "commit", "-q", "-m", "initial"], check=True
    )
    # Add a NEW bare-catch on top of the existing one.
    (tmp_git_repo / "foo.dart").write_text(
        "void f() {\n  try { x(); } catch (e) {}\n}\n"
        "void g() {\n  try { y(); } catch (e) {}\n}\n",
        encoding="utf-8",
    )
    subprocess.run(["git", "-C", str(tmp_git_repo), "add", "foo.dart"], check=True)
    rc, vios = _run_lint(tmp_git_repo, ["foo.dart"])
    assert rc == 1, "new bare-catch must fail"
    assert len(vios) == 1, "only the newly-added bare-catch must be flagged"


# --- Positive case: logged+rethrown catch passes -------------------------


def test_logged_catch_passes(tmp_git_repo: Path):
    content = (
        "void f() {\n"
        "  try {\n"
        "    x();\n"
        "  } catch (e) {\n"
        "    Sentry.captureException(e);\n"
        "    rethrow;\n"
        "  }\n"
        "}\n"
    )
    _stage(tmp_git_repo, "ok.dart", content)
    rc, _ = _run_lint(tmp_git_repo, ["ok.dart"])
    assert rc == 0


# --- Phase 34.1 Fix #3: regex widening per audits/01 + audits/05 ---------
# (amends D-05 -- documented as D-28 in CONTEXT.md)


def test_dart_catch_ex_identifier_bypass(tmp_git_repo: Path):
    """Audit 01 P0: `catch (ex)` -- identifier not in (e|_|err|error)."""
    _stage(tmp_git_repo, "a.dart", "void f() {\n  try { x(); } catch (ex) {}\n}\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.dart"])
    assert rc == 1


def test_dart_catch_exception_identifier_bypass(tmp_git_repo: Path):
    """Audit 01 P0: `catch (exception)` full identifier bypass."""
    _stage(tmp_git_repo, "a.dart", "void f() {\n  try { x(); } catch (exception) {}\n}\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.dart"])
    assert rc == 1


def test_dart_catch_e_stack_two_arg_bypass(tmp_git_repo: Path):
    """Audit 01 P0: `catch (e, stack)` two-arg bypass."""
    _stage(tmp_git_repo, "a.dart", "void f() {\n  try { x(); } catch (e, stack) {}\n}\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.dart"])
    assert rc == 1


def test_dart_on_type_catch_two_arg(tmp_git_repo: Path):
    """Audit 01: `on FormatException catch (e, s) {}` two-arg typed catch."""
    _stage(tmp_git_repo, "a.dart", "void f() {\n  try { x(); } on FormatException catch (e, s) {}\n}\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.dart"])
    assert rc == 1


def test_python_except_pass_oneliner(tmp_git_repo: Path):
    """Audit 05 P0: `except: pass` -- the canonical Python bare-except."""
    _stage(tmp_git_repo, "a.py", "def f():\n    try:\n        x()\n    except: pass\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_exception_pass_oneliner(tmp_git_repo: Path):
    """Audit 05 P0: `except Exception: pass` one-liner."""
    _stage(tmp_git_repo, "a.py", "def f():\n    try:\n        x()\n    except Exception: pass\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_exc_as_e_pass_oneliner(tmp_git_repo: Path):
    """Audit 05 P0: `except Exception as e: pass` one-liner with as binding."""
    _stage(tmp_git_repo, "a.py", "def f():\n    try:\n        x()\n    except Exception as e: pass\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_tuple_pass_oneliner(tmp_git_repo: Path):
    """Audit 05 P0: `except (A, B): pass` tuple one-liner."""
    _stage(tmp_git_repo, "a.py", "def f():\n    try:\n        x()\n    except (ValueError, TypeError): pass\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_tuple_as_e_oneliner(tmp_git_repo: Path):
    """Audit 05 P0: `except (A, B) as e: pass` tuple + as one-liner."""
    _stage(
        tmp_git_repo,
        "a.py",
        "def f():\n    try:\n        x()\n    except (ValueError, TypeError) as e: pass\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_tuple_empty_body(tmp_git_repo: Path):
    """`except (A, B):` with next-line pass is bare (no log)."""
    _stage(
        tmp_git_repo,
        "a.py",
        "def f():\n    try:\n        x()\n    except (ValueError, TypeError):\n        pass\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_typed_no_as(tmp_git_repo: Path):
    """`except ValueError:` typed-no-as empty body is still bare without log."""
    _stage(
        tmp_git_repo,
        "a.py",
        "def f():\n    try:\n        x()\n    except ValueError:\n        pass\n",
    )
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1


def test_python_except_pass_with_comment_still_fails(tmp_git_repo: Path):
    """`except: pass  # noqa` -- trailing comment must not exempt."""
    _stage(tmp_git_repo, "a.py", "def f():\n    try:\n        x()\n    except: pass  # noqa\n")
    rc, _ = _run_lint(tmp_git_repo, ["a.py"])
    assert rc == 1
