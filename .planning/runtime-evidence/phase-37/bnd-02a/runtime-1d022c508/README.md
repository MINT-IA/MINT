# G1 BND-02 / BND-02A — exact-SHA lightweight runtime proof

This controlled archive freezes only sanitized summaries for exact source SHA
`1d022c5086393e3b2e9df8399232f3dbcc6284e8`.

- Patrol writer: 1 passed / 0 failed.
- Explicit `simctl terminate`: exit 0.
- Separate cold-reader process: 1 passed / 0 failed.
- Normal app build core restored byte-for-byte after external Patrol builds.
- Maestro default-off and stale-review/stale-impact recovery: 17/17 steps,
  exit 0, from a normal exact-SHA detached build.
- Exact BND-02 command: 7/7.
- Exact combined BND-02A command: backend 66/66, mobile 20/20.
- Wrapper-only Claude final confirmations: 4/4 PASS, P0=0, P1=0.

This accepts **technical** G1-BND-02 and G1-BND-02A only. All runtime feature
flags remain default-off. The eight external controller/vendor/legal facts in
`runtime-manifest.json` remain unproven, so activation and G1 remain NO-GO and
G2/G3 remain unauthorized.

No `.xcresult`, binary, screenshot, private certificate, document content,
credential, token, PII, or temporary path is retained.
