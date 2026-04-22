# fixture — logged + raised except for GUARD-02 tests.
import logging

logger = logging.getLogger(__name__)


def do_work():
    try:
        risky_op()
    except Exception as exc:
        logger.error("risky_op failed: %s", exc)
        raise
