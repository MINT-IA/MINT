"""
OPEN BANKING INFRASTRUCTURE — Phase 3+ (FINMA gate)

ApiConnectorBase — abstract base class for all external API connectors.

Provides:
    - Retry with exponential backoff (tenacity)
    - Configurable timeout
    - Circuit breaker (fail-fast after N consecutive failures)
    - Structured logging

All institutional API connectors (bLink, caisse de pension, AVS)
must inherit from this class.

Status:
    Aucun connecteur concret n'existe encore. La classe abstraite et le
    CircuitBreaker sont testés (test_connectors_and_consent_db.py) et prêts
    pour l'activation après consultation réglementaire FINMA.
    Ne PAS supprimer — l'architecture est prête pour l'activation.

Sources:
    - nLPD art. 6 (data minimization)
    - PSD2 / bLink (open banking standard)
"""

import logging
import threading
import time
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional

from tenacity import (
    Retrying,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
    before_sleep_log,
)


logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Circuit Breaker (lightweight, no external dependency)
# ---------------------------------------------------------------------------

class CircuitOpen(Exception):
    """Raised when the circuit breaker is open (too many failures)."""
    pass


class CircuitBreaker:
    """Simple circuit breaker: opens after `threshold` consecutive failures,
    resets after `recovery_seconds`."""

    def __init__(self, threshold: int = 5, recovery_seconds: int = 60):
        self.threshold = threshold
        self.recovery_seconds = recovery_seconds
        self._failure_count = 0
        self._last_failure_time: float = 0.0
        self._state = "closed"  # closed | open | half_open
        self._lock = threading.Lock()

    def record_success(self) -> None:
        with self._lock:
            self._failure_count = 0
            self._state = "closed"

    def record_failure(self) -> None:
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.time()
            if self._failure_count >= self.threshold:
                self._state = "open"
                logger.warning(
                    "Circuit breaker OPEN after %d failures", self._failure_count
                )

    def allow_request(self) -> bool:
        with self._lock:
            if self._state == "closed":
                return True
            elapsed = time.time() - self._last_failure_time
            if elapsed >= self.recovery_seconds:
                self._state = "half_open"
                return True
            return False

    @property
    def state(self) -> str:
        return self._state


# ---------------------------------------------------------------------------
# Abstract Base Connector
# ---------------------------------------------------------------------------

class ApiConnectorBase(ABC):
    """Abstract base for external API connectors.

    Subclasses must implement:
        - `_do_request(method, path, **kwargs)` — the actual HTTP call
        - `source_name` property — e.g. "blink", "caisse_pension"

    Usage:
        class BlinkConnector(ApiConnectorBase):
            source_name = "blink"
            def _do_request(self, method, path, **kwargs):
                return httpx.request(method, self.base_url + path, ...)
    """

    source_name: str = "unknown"

    def __init__(
        self,
        base_url: str,
        timeout: int = 30,
        max_retries: int = 3,
        circuit_threshold: int = 5,
        circuit_recovery: int = 60,
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.max_retries = max_retries
        self._circuit = CircuitBreaker(
            threshold=circuit_threshold,
            recovery_seconds=circuit_recovery,
        )

    # -- Abstract interface --------------------------------------------------

    @abstractmethod
    def _do_request(
        self,
        method: str,
        path: str,
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        json_body: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Execute the actual HTTP request. Must return parsed JSON dict.

        Subclasses should use httpx, requests, or any HTTP client.
        Raise `ConnectionError` or `TimeoutError` for retryable failures.
        Raise `ValueError` for non-retryable errors (4xx).
        """
        ...

    # -- Public API ----------------------------------------------------------

    def request(
        self,
        method: str,
        path: str,
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        json_body: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Make an API request with retry, circuit breaker, and logging."""
        if not self._circuit.allow_request():
            raise CircuitOpen(
                f"Circuit breaker open for {self.source_name}. "
                f"Try again in {self._circuit.recovery_seconds}s."
            )

        try:
            result = self._request_with_retry(
                method, path, headers=headers, params=params, json_body=json_body
            )
            self._circuit.record_success()
            return result
        except Exception as exc:
            self._circuit.record_failure()
            logger.error(
                "[%s] Request failed: %s %s — %s",
                self.source_name,
                method,
                path,
                str(exc),
            )
            raise

    def _request_with_retry(
        self,
        method: str,
        path: str,
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        json_body: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Internal: calls _do_request with tenacity retry."""
        retryer = Retrying(
            stop=stop_after_attempt(self.max_retries),
            wait=wait_exponential(multiplier=1, min=1, max=10),
            retry=retry_if_exception_type((ConnectionError, TimeoutError)),
            before_sleep=before_sleep_log(logger, logging.WARNING),
            reraise=True,
        )
        logger.debug("[%s] %s %s", self.source_name, method, path)
        return retryer(
            self._do_request,
            method, path, headers=headers, params=params, json_body=json_body,
        )

    # -- Convenience methods -------------------------------------------------

    def get(self, path: str, **kwargs) -> Dict[str, Any]:
        return self.request("GET", path, **kwargs)

    def post(self, path: str, **kwargs) -> Dict[str, Any]:
        return self.request("POST", path, **kwargs)
