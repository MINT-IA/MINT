# Mint Foundation Cleanup — Inventory

## Accepted Into Clean Foundation

| Category | Files |
|---|---|
| Agent workflow | `docs/MINT_AGENT_WORKFLOW.md`, minimal pointer in `AGENTS.md` |
| Mint 2.0 GSD phase | `.planning/phases/mint-2-0-first-experience-rente-capital/` |
| Foundation hygiene phase | `.planning/phases/mint-foundation-cleanup-20260614/` |

## Quarantined In Original Dirty Tree

These files remain in `/Users/julienbattaglia/Desktop/MINT.nosync` and are not carried into the clean foundation unless explicitly selected later.

| Category | Files / directories |
|---|---|
| GSD / Claude config | `.claude/get-shit-done/**`, `.planning/config.json`, `.planning/ROADMAP.md`, `CLAUDE.md` |
| Mixed AGENTS doctrine | original dirty diff in `AGENTS.md` beyond the workflow pointer |
| Auth / account UI | `apps/mobile/lib/screens/auth/**`, `apps/mobile/lib/widgets/auth/auth_gate_bottom_sheet.dart`, auth tests |
| Anonymous restore / reset | `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart`, `apps/mobile/lib/services/coach/conversation_store.dart`, related tests |
| Profile / financial summary | `apps/mobile/lib/providers/coach_profile_provider.dart`, `apps/mobile/lib/screens/profile/financial_summary_screen.dart`, related tests |
| Landing / onboarding | `apps/mobile/lib/screens/landing_screen.dart`, landing tests |
| l10n generated / ARB | `apps/mobile/lib/l10n/app_*.arb`, `apps/mobile/lib/l10n/app_localizations*.dart` |
| Backend anonymous chat | `services/backend/app/api/v1/endpoints/anonymous_chat.py`, `services/backend/tests/test_anonymous_chat.py` |
| Legacy untracked phases | `mint-account-entry-apple-primary`, `mint-anonymous-chat-restore-control`, `mint-diagnostic-onboarding-v1`, `mint-onboarding-lifecycle-reset`, `mint-profile-clear-conversation-purge` |
| Public identity doc | `docs/MINT_IDENTITY.md` |

## Rule

No quarantined change may enter Mint 2.0 by copy/paste. It needs a named slice, a diff review, tests, and a reason tied to the active GSD phase.
