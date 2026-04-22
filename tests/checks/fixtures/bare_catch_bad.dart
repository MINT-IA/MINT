// fixture — known BAD bare-catch for GUARD-02 tests. Do NOT lint this file directly.
void doWork() {
  try {
    riskyOp();
  } catch (e) {}
}
