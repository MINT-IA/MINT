"""Container-layout robustness for the runtime LSFin banned-terms scanner (P0 #1118 hotfix).

Regression context (proven, Railway staging, 2026-07-30)
========================================================
`banned_terms_runtime.py` resolved its vocabulary source with a hard-coded
``Path(__file__).resolve().parents[5]``. That depth is correct on a dev-box /
CI checkout (``…/services/backend/app/services/encryption/… → repo root``) but
the backend Docker image runs under ``WORKDIR=/app`` with the module at
``/app/app/services/encryption/…``, which has only 5 ancestors → ``parents[5]``
raised ``IndexError: 5`` at IMPORT time. The import is lazy (inside
``_receipt_deterministic_loop_result``), so the app booted but every
resolved-receipt ``/coach/chat`` turn 500-ed (3/3 on staging).

Two belts under test here:
    - Belt 1 — the root resolver climbs to a marker and returns ``None`` on a
      shallow container path instead of raising ``IndexError``.
    - Belt 2 — the vocabulary still resolves from the app-packaged inlined copy
      when the repo-root ``tools/`` dir is absent from the image.
"""
from __future__ import annotations

from pathlib import Path

import pytest

import app.services.encryption.banned_terms_runtime as btr


class TestResolveRepoRoot:
    def test_shallow_container_path_returns_none_not_indexerror(self):
        # Reproduit le layout Railway /app/app/services/encryption/<mod>.py :
        # aucun ancêtre ne porte tools/checks/banned_terms_python.py -> None,
        # sans lever IndexError (le bug #1118).
        shallow = Path("/app/app/services/encryption/banned_terms_runtime.py")
        assert btr._resolve_repo_root(start=shallow) is None

    def test_filesystem_root_returns_none(self):
        assert btr._resolve_repo_root(start=Path("/banned_terms_runtime.py")) is None

    def test_finds_marker_when_present(self, tmp_path):
        # Faux checkout : <root>/tools/checks/banned_terms_python.py.
        marker = tmp_path / "tools" / "checks" / "banned_terms_python.py"
        marker.parent.mkdir(parents=True)
        marker.write_text("# marker\n", encoding="utf-8")
        deep = (
            tmp_path
            / "services"
            / "backend"
            / "app"
            / "services"
            / "encryption"
            / "banned_terms_runtime.py"
        )
        deep.parent.mkdir(parents=True)
        deep.write_text("# module\n", encoding="utf-8")
        assert btr._resolve_repo_root(start=deep) == tmp_path.resolve()

    def test_default_start_never_raises(self):
        # Sans argument : dev-box -> Path racine ; conteneur -> None. Jamais d'exception.
        result = btr._resolve_repo_root()
        assert result is None or isinstance(result, Path)


class TestResolveBannedVocab:
    def test_returns_three_nonempty_tuples(self):
        wb, phrase, para = btr._resolve_banned_vocab()
        assert wb and phrase and para
        assert "garanti" in wb
        assert "sans risque" in phrase
        assert "recommandé" in para

    def test_belt2_used_when_no_repo_root(self, monkeypatch):
        # Force belt 1 à échouer (simulation conteneur) : le repli inliné
        # packagé côté app doit quand même rendre le vocabulaire complet.
        monkeypatch.setattr(btr, "_resolve_repo_root", lambda *a, **k: None)
        wb, phrase, para = btr._resolve_banned_vocab()
        assert wb == btr._INLINED_WORD_BOUNDARY_BANNED
        assert phrase == btr._INLINED_PHRASE_BANNED
        assert para == btr._INLINED_BANNED_PARAPHRASE_VERBS
        assert "garanti" in wb and "sans risque" in phrase and "recommandé" in para

    def test_module_import_did_not_crash_and_scanner_live(self):
        # Les tuples module-level pilotent le scanner : un terme banni est
        # toujours capté après la résolution robuste au conteneur.
        assert btr._scan_text("rendement garanti") is not None
        assert btr._scan_text("bonjour, voici ton net mensuel") is None


class TestInlinedVocabDriftGuard:
    """Le vocabulaire inliné (belt 2) doit rester identique au module lint canonique.

    Tourne sur dev-box / CI où tools/checks/banned_terms_python.py EST présent.
    Skip propre si la racine repo n'est pas localisable (layout conteneur).
    """

    def test_inlined_matches_canonical_lint_module(self):
        import importlib.util

        root = btr._resolve_repo_root()
        if root is None:
            pytest.skip("repo root introuvable — tools/ absent (layout conteneur)")
        lint_path = root / "tools" / "checks" / "banned_terms_python.py"
        if not lint_path.is_file():
            pytest.skip("banned_terms_python.py absent")
        spec = importlib.util.spec_from_file_location(
            "banned_terms_python_canon", lint_path
        )
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        assert btr._INLINED_WORD_BOUNDARY_BANNED == mod._WORD_BOUNDARY_BANNED
        assert btr._INLINED_PHRASE_BANNED == mod._PHRASE_BANNED
        assert btr._INLINED_BANNED_PARAPHRASE_VERBS == mod.BANNED_PARAPHRASE_VERBS
