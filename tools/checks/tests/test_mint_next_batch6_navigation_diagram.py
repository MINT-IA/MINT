from __future__ import annotations

import unittest

from tools.checks.mint_next_batch6_navigation_diagram import render


class Batch6NavigationDiagramTest(unittest.TestCase):
    def test_renders_history_back_edges(self) -> None:
        diagram = render()
        self.assertIn('fact_canton -.->|"back:history"| fact_contribution', diagram)
        self.assertIn('education_explanation -.->|"back:history"| amount_unknown_help', diagram)

    def test_renders_privacy_critical_overlay_actions(self) -> None:
        diagram = render()
        self.assertIn('overlay_safe_exit -->|"keep_local_reference"| reference_saved', diagram)
        self.assertIn('overlay_safe_exit -->|"leave_without_saving"| dismissed', diagram)
        self.assertIn('overlay_safe_exit -.->|"resume:close"| overlay_return_to_invoker', diagram)

    def test_renders_mutation_only_controls(self) -> None:
        self.assertIn('fact_amount -->|"enter_amount:state"| fact_amount', render())


if __name__ == "__main__":
    unittest.main()
