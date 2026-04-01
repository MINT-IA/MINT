"""
Anomaly detection service for spending transactions.

Pure-Python implementation using Z-score and Modified Z-score (MAD-based)
for detecting unusual spending patterns. No sklearn dependency required.

Used by JITAI nudge system to surface spending anomalies to the coach.
"""

from __future__ import annotations

import math
from statistics import mean, median, stdev


class AnomalyDetectionService:
    """Detect anomalous spending in transaction lists.

    Two complementary detectors:
    1. Global Modified Z-score (MAD-based) — robust to outliers
    2. Per-category Z-score — catches category-level anomalies

    Both are pure functions, deterministic, no external dependencies.
    """

    @staticmethod
    def _median_absolute_deviation(values: list[float]) -> float:
        """Compute MAD = median(|xi - median(x)|)."""
        med = median(values)
        return median([abs(v - med) for v in values])

    @staticmethod
    def detect_spending_anomalies(
        transactions: list[dict],
        contamination: float = 0.05,  # noqa: ARG004 — kept for API compat
        mad_threshold: float = 3.5,
        zscore_threshold: float = 2.5,
    ) -> list[dict]:
        """Detect anomalous transactions using statistical methods.

        Args:
            transactions: List of dicts with at least 'amount' key.
                          Optional: 'category', 'date', 'description'.
            contamination: Unused, kept for API compatibility with spec.
            mad_threshold: Modified Z-score threshold for global detection.
                          3.5 is standard (≈ p < 0.001 for normal data).
            zscore_threshold: Z-score threshold for per-category detection.

        Returns:
            List of anomalous transactions, sorted by anomaly_score desc.
            Each entry is a copy of the original transaction with added:
            - anomaly_score (float): severity measure
            - anomaly_type (str): 'global' or 'category_zscore'
        """
        if len(transactions) < 10:
            return []

        amounts = [abs(t["amount"]) for t in transactions]
        anomalies: list[dict] = []
        seen_indices: set[int] = set()

        # --- Global detection: Modified Z-score (MAD-based) ---
        # More robust than standard Z-score for outlier detection
        if len(amounts) >= 20:
            mad = AnomalyDetectionService._median_absolute_deviation(amounts)
            med = median(amounts)

            if mad > 0:
                # Modified Z-score: 0.6745 is the 0.75th quantile of N(0,1)
                # which makes MAD consistent with std for normal distributions
                consistency_constant = 0.6745
                for i, amt in enumerate(amounts):
                    modified_z = consistency_constant * (amt - med) / mad
                    if abs(modified_z) > mad_threshold:
                        entry = transactions[i].copy()
                        entry["anomaly_score"] = float(abs(modified_z))
                        entry["anomaly_type"] = "global"
                        anomalies.append(entry)
                        seen_indices.add(i)

        # --- Per-category Z-score ---
        categories: dict[str, list[tuple[int, float]]] = {}
        for i, t in enumerate(transactions):
            cat = t.get("category", "other")
            categories.setdefault(cat, []).append((i, abs(t["amount"])))

        for _cat, indexed_amounts in categories.items():
            if len(indexed_amounts) < 5:
                continue

            cat_values = [a for _, a in indexed_amounts]
            cat_mean = mean(cat_values)
            cat_std = stdev(cat_values) if len(cat_values) > 1 else 0.0

            if cat_std == 0:
                continue

            for idx, amt in indexed_amounts:
                z = (amt - cat_mean) / cat_std
                if abs(z) > zscore_threshold and idx not in seen_indices:
                    entry = transactions[idx].copy()
                    entry["anomaly_score"] = float(abs(z))
                    entry["anomaly_type"] = "category_zscore"
                    anomalies.append(entry)
                    seen_indices.add(idx)

        return sorted(anomalies, key=lambda x: x["anomaly_score"], reverse=True)

    @staticmethod
    def generate_anomaly_insight(
        anomaly: dict,
        category_avg: float,
        canton: str | None = None,  # noqa: ARG004 — reserved for regional voice
        cash_level: int = 3,  # noqa: ARG004 — reserved for literacy adaptation
    ) -> str:
        """Generate a human-readable insight for an anomaly.

        Uses conditional language per MINT compliance rules
        (no absolutes, educational tone, French informal 'tu').

        Args:
            anomaly: Transaction dict with 'amount' and optional 'category'.
            category_avg: Average spending in that category.
            canton: Reserved for future regional voice adaptation.
            cash_level: Reserved for future literacy-level adaptation.

        Returns:
            French insight string (educational, not prescriptive).
        """
        amount = abs(anomaly["amount"])
        category = anomaly.get("category", "autre")

        if category_avg > 0:
            ratio = amount / category_avg
            return (
                f"D\u00e9pense inhabituelle\u00a0: CHF\u00a0{amount:,.0f} "
                f"en {category}. "
                f"C\u2019est {ratio:.1f}\u00d7 ta moyenne dans cette cat\u00e9gorie."
            )

        return (
            f"D\u00e9pense inhabituelle\u00a0: CHF\u00a0{amount:,.0f} "
            f"en {category}."
        )
