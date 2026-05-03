# Screen registry parity — KNOWN-MISSES allow-list rationale

Companion to `tools/checks/screen_registry_parity.py`. When a route in
`apps/mobile/lib/app.dart` is intentionally NOT enforced for parity with
`MintScreenRegistry`, the rationale lives here. The lint reads the
allow-list constants in the script; this doc is the human audit trail.

---

## Categories

### Category A — Not chat-routable (`_NOT_CHAT_ROUTABLE`)

Routes the LLM should never surface from the coach chat. Either pre-auth
flows, shell tabs accessible from the bottom navigation, dev-only admin
surfaces, or the chat itself (you don't route INTO the chat from the chat).

| Route | Reason |
|---|---|
| `/` | Root landing — pre-auth, no chat surface yet |
| `/start` | Anonymous wedge entry — pre-chat |
| `/onb` | Onboarding root — pre-chat |
| `/auth/login` | Auth flow — never surfaced from chat |
| `/auth/register` | Same |
| `/auth/forgot-password` | Same |
| `/auth/verify-email` | Same |
| `/auth/verify` | Same |
| `/anonymous/intent` | Anonymous wedge — pre-auth |
| `/anonymous/chat` | Anonymous chat — different surface than authenticated coach chat |
| `/admin/routes` | Phase 32 admin shell — dev-only, tree-shaken in prod (D-06 + D-10) |
| `/admin/observability` | Phase 31 admin observability — dev-only |
| `/admin/analytics` | Phase 32 admin analytics — dev-only |
| `/achievements` | Achievements grid — surfaced by tab bar; an entry exists in registry with `preferFromChat: false` |
| `/coach` | Coach root — same redirect target as `/coach/chat` |
| `/coach/chat` | The chat itself; coach can't route to itself |

Adding a route here requires a one-line entry in this table explaining why
the route should not appear in `MintScreenRegistry`.

**Note on registry presence:** several of these routes ALSO have a
`ScreenEntry` declared in `screen_registry.dart` (e.g. `_authLogin`,
`_achievements`, `_home`) — that's intentional. The LLM's `IntentResolver`
needs to know about them so it can refer to them by intent tag without
actually navigating users there (the entries carry `preferFromChat: false`).
The lint exempts these routes from BOTH sides of the comparison so the
KNOWN-MISSES allow-list signals « do not enforce parity » rather than
« must be absent from registry ».

### Category B — Nested profile children (`_NESTED_PROFILE_CHILDREN`)

GoRouter declares child routes as bare segments under a parent
`/profile` path; the registry stores the composed `/profile/<segment>`
form. The regex captures the bare segment (left side); the registry
stores the composed (right side). Both sides are exempted from
comparison to prevent false-positive drift.

| Bare segment in `app.dart` | Composed form in registry |
|---|---|
| `admin-observability` | `/profile/admin-observability` |
| `admin-analytics` | `/profile/admin-analytics` |
| `byok` | `/profile/byok` |
| `slm` | `/profile/slm` |
| `bilan` | `/profile/bilan` |
| `privacy-control` | `/profile/privacy-control` |
| `privacy` | `/profile/privacy` |

Adding a new nested child requires both the lint constant AND this table.

---

## Maintenance policy

When the parity lint reports drift:

1. **First, fix the code.** Add the missing `ScreenEntry` to the registry
   OR remove the stale entry. The default is « parity must hold ».
2. **Only allow-list when the route is structurally exempt.** Auth flows,
   dev-only admin surfaces, shell tabs whose UX makes chat-routing
   nonsensical. NOT « we'll add this later » — that's a backlog ticket,
   not an allow-list entry.
3. **Document the reason.** A one-line entry in this table is part of the
   PR. A reviewer should be able to read « why is this route exempt? »
   in 10 seconds without consulting other docs.
4. **Keep the lint script and this doc in sync.** A code reviewer who
   sees a new entry in `_NOT_CHAT_ROUTABLE` must find the matching
   table row here, or block the PR.

## Origin

Plan 53-01 (Phase 53 — architecture parity + sequence wiring), spawned
from the 5-expert MINT panel synthesis at
`.planning/decisions/2026-05-04-phase-53-target.md`. Mirrors the
`tools/checks/route_registry_parity-KNOWN-MISSES.md` discipline established
in Phase 32-04 (MAP-04).
