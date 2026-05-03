# Privacy

This kit collects, transmits, or stores **zero telemetry**.

- No analytics, no phone-home, no usage reporting
- No external network calls from `bootstrap.sh`, `doctor.sh`, `uninstall.sh`, or any lint script
- No accounts, no API keys, no third-party services required to install or use the kit
- All operations are local file system reads and writes

The only network usage is when you (the user) clone the repo from GitHub via `git clone` — that's a standard `git` operation under your control, not initiated by the kit.

The kit ships in plain text. Read `bin/*.sh` and `lints/*.py` before running. They are short on purpose.

If you find any code path that contradicts this statement, please open an issue immediately — it is a bug.
