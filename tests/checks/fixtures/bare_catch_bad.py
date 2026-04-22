# fixture — known BAD bare except for GUARD-02 tests.
def do_work():
    try:
        risky_op()
    except Exception:
        pass
