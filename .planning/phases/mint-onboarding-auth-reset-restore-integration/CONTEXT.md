# Context

Date: 2026-06-13. Status: IN_FLIGHT, contract before product code.

Mission: turn Mint first-run into a calm Swiss path where the user sees what
Mint understood, what is missing, what is stored locally, and how to continue,
create an account, restart, or exit. Mint is not a chat product.

Verified base:

- Clean worktree: `.claude/worktrees/codex-mint-diagnostic-onboarding-v1-route`
- Branch: `codex/mint-account-entry-apple-primary`
- Stack: `53584edcf` diagnostic -> `47936eb12` purge -> `b5808dabb`
  restore -> `06f48000d` auth-safe -> `363ae4df6` Apple-primary UI
- Backup: `7557f82c2`
- `origin/dev` advanced after fetch, so PR work must rebase or rebuild on `dev`.
- Main checkout is dirty aggregate; do not stage from it.

Config gate passed: Claude model is `claude-opus-4-8[1m]`; GSD timeouts are
`cross_ai_timeout=600` and `subagent_timeout=600000`.

Product invariants: pre-account is educational; personal amounts require
canton/tax residence, household, and financial order of magnitude or required
event; numbers come from `financial_core` L1 or backend L2-L4; reset/exit must
remain visible; Apple-primary UI is separate from real entitlement proof.

Storage invariant: iOS secure storage can survive uninstall or return via
iCloud Keychain/backup. A non-Keychain install marker covers uninstall/reinstall
only; full device restore may bring the marker back too. Mint must purge known
keys, use a backup-excluded or device-bound marker/nonce where supported, purge
or revalidate when marker and secure namespace disagree, prefer concrete
ThisDeviceOnly accessibility for new secrets when available, and never promise
erasure of restored cloud copies.
