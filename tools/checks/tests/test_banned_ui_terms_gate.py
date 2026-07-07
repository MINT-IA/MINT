import importlib.util
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/banned_ui_terms.py"
CI = ROOT / ".github/workflows/ci.yml"
LEFTHOOK = ROOT / "lefthook.yml"


def _write_dart(root: Path, relative_path: str, source: str) -> Path:
    path = root / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    return path


def _run_checker(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def _load_checker_module():
    spec = importlib.util.spec_from_file_location("banned_ui_terms", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_ui_promise_string_with_banned_terms_fails(tmp_path: Path) -> None:
    _write_dart(
        tmp_path,
        "apps/mobile/lib/screens/promise_screen.dart",
        """
        import 'package:flutter/widgets.dart';

        Widget build(BuildContext context) {
          return const Text('Plan parfait, rendement garanti et sans risque.');
        }
        """,
    )

    result = _run_checker("--root", str(tmp_path))

    assert result.returncode == 1
    diagnostics = result.stdout + result.stderr
    assert "promise_screen.dart:5" in diagnostics
    assert "parfait" in diagnostics
    assert "garanti" in diagnostics
    assert "sans risque" in diagnostics


def test_comments_and_internal_guard_prompts_are_not_ui_violations(
    tmp_path: Path,
) -> None:
    _write_dart(
        tmp_path,
        "apps/mobile/lib/services/coach_prompt.dart",
        """
        // Exemple interdit documenté: rendement garanti.
        /* Autre documentation: sans risque. */
        const promptRule =
            'Tu NE dis JAMAIS : garanti, certain, assuré, sans risque.';
        """,
    )

    result = _run_checker("--root", str(tmp_path))

    assert result.returncode == 0, result.stdout + result.stderr


def test_single_word_banned_ui_label_fails(tmp_path: Path) -> None:
    _write_dart(
        tmp_path,
        "apps/mobile/lib/widgets/promise_chip.dart",
        """
        import 'package:flutter/widgets.dart';

        Widget build(BuildContext context) => const Text('Garanti');
        """,
    )

    result = _run_checker("--root", str(tmp_path))

    assert result.returncode == 1
    assert "promise_chip.dart:4" in result.stdout + result.stderr
    assert "garanti" in result.stdout + result.stderr


def test_common_french_inflections_of_banned_terms_fail(tmp_path: Path) -> None:
    _write_dart(
        tmp_path,
        "apps/mobile/lib/widgets/inflected_promises.dart",
        """
        import 'package:flutter/widgets.dart';

        Widget build(BuildContext context) {
          return const Column(children: [
            Text('Performance garantie.'),
            Text('La meilleure option.'),
            Text('Solution optimale.'),
            Text('Choix optimaux.'),
            Text('Placement sans risques.'),
            Text('Solution parfaite.'),
          ]);
        }
        """,
    )

    result = _run_checker("--root", str(tmp_path))

    assert result.returncode == 1
    diagnostics = result.stdout + result.stderr
    for term in ("garanti", "meilleur", "optimal", "sans risque", "parfait"):
        assert term in diagnostics


def test_swiss_insurance_terms_and_negated_disclaimers_pass(tmp_path: Path) -> None:
    _write_dart(
        tmp_path,
        "apps/mobile/lib/screens/legal_terms_screen.dart",
        """
        import 'package:flutter/widgets.dart';

        Widget build(BuildContext context) {
          return const Column(children: [
            Text('Salaire assuré'),
            Text('Gain assuré retenu'),
            Text('Plan 1e détecté. Pas de taux de conversion garanti.'),
            Text('Pas de rente garantie ici.'),
            Text('Ne constitue pas un conseil financier personnalisé.'),
            Text('Outil éducatif, pas un conseil financier.'),
            Text('Assure-toi d’être connecté en WiFi.'),
            Text('Libère dans ${meilleur.moisJusquaLiberation} mois.'),
            Text('Parfait, c’est noté.'),
            Text('Aucune option n’est universellement meilleure.'),
          ]);
        }
        """,
    )

    result = _run_checker("--root", str(tmp_path))

    assert result.returncode == 0, result.stdout + result.stderr


def test_adversarial_test_paths_are_skipped_for_single_file(tmp_path: Path) -> None:
    test_file = _write_dart(
        tmp_path,
        "apps/mobile/test/compliance/adversarial_banned_terms_test.dart",
        "const badFixture = 'rendement garanti et sans risque';\n",
    )

    result = _run_checker("--root", str(tmp_path), "--file", str(test_file))

    assert result.returncode == 0, result.stdout + result.stderr


def test_current_repo_ui_strings_are_clean_under_gate() -> None:
    result = _run_checker()

    assert result.returncode == 0, result.stdout + result.stderr


def test_gate_policy_covers_claude_and_legal_banned_terms() -> None:
    module = _load_checker_module()

    policy_terms = {term.raw for term in module.POLICY_TERMS}
    for term in (
        "garanti",
        "optimal",
        "meilleur",
        "certain",
        "assuré",
        "sans risque",
        "parfait",
        "conseil financier",
        "better",
        "recommended",
    ):
        assert term in policy_terms


def test_lefthook_runs_banned_ui_terms_pre_commit_gate() -> None:
    lefthook = LEFTHOOK.read_text(encoding="utf-8")

    assert "banned-ui-terms:" in lefthook
    assert "tools/checks/banned_ui_terms.py --file" in lefthook
    assert 'glob: "apps/mobile/lib/**/*.dart"' in lefthook


def test_ci_runs_banned_ui_terms_and_blocks_ci_gate() -> None:
    ci = CI.read_text(encoding="utf-8")
    gate = ci.split("ci-gate:", maxsplit=1)[1]

    assert "banned-ui-terms:" in ci
    assert "Banned UI terms" in ci
    assert "python3 tools/checks/banned_ui_terms.py" in ci
    assert "banned-ui-terms" in gate
    assert 'banned_terms="${{ needs.banned-ui-terms.result }}"' in gate
    assert '"$banned_terms" != "success"' in gate
