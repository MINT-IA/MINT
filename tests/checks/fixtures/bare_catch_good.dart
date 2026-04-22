// fixture — logged + rethrown catch for GUARD-02 tests.
void doWork() {
  try {
    riskyOp();
  } catch (e) {
    Sentry.captureException(e);
    rethrow;
  }
}
