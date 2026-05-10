# Test package for tools/checks design lints (Phase MVP-DESIGN-LINTS-V1).
#
# Layout:
#   tests/__init__.py         — this file (marker)
#   tests/_lint_test_helpers.py — shared loader + tmpdir fixture utilities
#   tests/test_prefer_mint_*.py — per-lint unit suites (5 files)
#   tests/test_design_lints_smoke.py — integration smoke (Wave 3)
#   tests/fixtures/           — synthetic .dart violation/clean/ignored fixtures
