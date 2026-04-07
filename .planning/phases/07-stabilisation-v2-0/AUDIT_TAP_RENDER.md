# AUDIT_TAP_RENDER — STAB-17

**Status:** SCAFFOLD READY — requires manual walkthrough on real device or emulator
**Last gate before TestFlight.** Every interactive element on the 3 tabs + ProfileDrawer must produce a documented PASS/FAIL.

Scaffold authored: 2026-04-07 (Phase 7 plan 07-06).
Source enumeration is grep-driven over `onTap:|onPressed:|onChanged:|onSubmit` in the four entry-point files. Drilling into sub-screens (each hub, each chat tool result widget) is **out of scope** for this gate — those have their own coverage via STAB-12..16. The point of STAB-17 is to prove the four primary entry points are alive.

## How to run

1. `cd apps/mobile && flutter run` (iOS simulator or real device).
2. For each section below, tap every interactive element listed.
3. Mark PASS or FAIL with the actual outcome in the `Actual` and `Verdict` columns.
4. Any FAIL becomes a follow-up commit in this phase, OR is escalated as ACCEPT-WITH-RATIONALE in `AUDIT_ACCEPT_LOG.md` and a v3.0 GSD todo.
5. Phase 7 ships only when zero FAIL rows remain unaddressed.

Estimated time: 30–45 minutes.

---

## Tab 1: Aujourd'hui (`mint_home_screen.dart`)

| # | Element | File:Line | Expected | Actual | Verdict |
|---|---|---|---|---|---|
| 1.1 | Premier éclairage card tap | mint_home_screen.dart:151 | Opens premier éclairage detail / triggers coach handoff | TODO — manual | TODO |
| 1.2 | Premier éclairage CTA button | mint_home_screen.dart:258 | Triggers the éclairage primary action | TODO — manual | TODO |
| 1.3 | Coach handoff card | mint_home_screen.dart:340 | Switches to Coach tab with payload | TODO — manual | TODO |
| 1.4 | Hero card tap | mint_home_screen.dart:475 | `context.push(hero.route)` — opens hero target screen | TODO — manual | TODO |
| 1.5 | Progress milestone card tap | mint_home_screen.dart:484 | `context.push(progress.route)` — opens progress detail | TODO — manual | TODO |
| 1.6 | Action opportunity card tap | mint_home_screen.dart:488 | `context.push(action.route)` — opens action target | TODO — manual | TODO |
| 1.7 | "Simuler" button on plan card | mint_home_screen.dart:547 | Runs simulation flow | TODO — manual | TODO |
| 1.8 | "Parler au coach" button on plan card | mint_home_screen.dart:569 | Switches to Coach tab | TODO — manual | TODO |
| 1.9 | Coach input bar — submit on enter | mint_home_screen.dart:663 | Sends message + switches to Coach tab | TODO — manual | TODO |
| 1.10 | Coach input bar — send button | mint_home_screen.dart:684 | Sends message + switches to Coach tab | TODO — manual | TODO |
| 1.11 | First check-in CTA card | mint_home_screen.dart:730 | Switches to Coach tab in check-in mode | TODO — manual | TODO |
| 1.12 | Anticipation signal card | mint_home_screen.dart:743 | Switches to Coach tab with anticipation payload | TODO — manual | TODO |
| 1.13 | Plan reality card | mint_home_screen.dart:758 | Switches to Coach tab with plan reality context | TODO — manual | TODO |
| 1.14 | Generic contextual card wrapper | mint_home_screen.dart:780 | Routes to bound onTap handler | TODO — manual | TODO |
| 1.15 | Contextual overflow card (more) | mint_home_screen.dart:897 | Expands or routes via intent tag | TODO — manual | TODO |

**Notes for tester:**
- The home screen has variable cards depending on profile state. Tap whatever is rendered; mark N/A if a card is not present in your test profile.
- For 1.9 / 1.10 ("coach input bar"): try empty input (should be inert) and a real message (should switch tabs).

---

## Tab 2: Coach (`mint_coach_tab.dart` → `coach_chat_screen.dart`)

`mint_coach_tab.dart` is a thin wrapper around `CoachChatScreen`. All interactive elements live in `coach_chat_screen.dart`.

| # | Element | File:Line | Expected | Actual | Verdict |
|---|---|---|---|---|---|
| 2.1 | Chat composer — text field submit | coach_chat_screen.dart (TextField onSubmit) | Sends message, streams response | TODO — manual | TODO |
| 2.2 | Chat composer — send button | coach_chat_screen.dart | Sends message, streams response | TODO — manual | TODO |
| 2.3 | Suggestion chip in coach action panel | coach_chat_screen.dart:1491 (`onActionTap: _handleActionTap`) | Routes to handler — opens screen, runs tool, or sends prompt | TODO — manual | TODO |
| 2.4 | Intensity selector chip (check-in) | coach_chat_screen.dart:1578 | Selects intensity, advances flow | TODO — manual | TODO |
| 2.5 | `route_to_screen` tool result chip | (rendered via widget_renderer.dart) | Opens the routed screen | TODO — manual | TODO |
| 2.6 | `generate_document` tool result chip | (rendered via widget_renderer.dart) | Triggers document generation | TODO — manual | TODO |
| 2.7 | `generate_financial_plan` tool result widget | (rendered via widget_renderer.dart) | Shows the generated plan card | TODO — manual | TODO |
| 2.8 | `record_check_in` tool result widget | (rendered via widget_renderer.dart:450) | Shows confirmation, persists check-in | TODO — manual | TODO |
| 2.9 | Conversation history button (app bar) | coach_chat_screen.dart | Opens `/coach/history` | TODO — manual | TODO |
| 2.10 | Lightning menu (widget shortcut) | coach_chat_screen.dart | Opens contextual widget picker | TODO — manual | TODO |

**Notes for tester:**
- 2.5–2.8 require triggering each tool from the LLM. Use prompts like:
  - "Ouvre l'écran AVS" → expect `route_to_screen`
  - "Génère mon plan financier" → expect `generate_financial_plan`
  - "Comment je me sens aujourd'hui : 7/10" → expect `record_check_in`
  - "Génère un récapitulatif PDF" → expect `generate_document`
- These four are STAB-01..04. If they don't render, that's a P0 regression of Phase 7's headline work.

---

## Tab 3: Explorer (`explore_tab.dart`)

| # | Element | File:Line | Expected | Actual | Verdict |
|---|---|---|---|---|---|
| 3.1 | Search bar — onChanged | explore_tab.dart:488 | Filters hub list / shows search results | TODO — manual | TODO |
| 3.2 | Search result tile tap | explore_tab.dart:613 | `context.push(entry.route)` — opens deep link | TODO — manual | TODO |
| 3.3 | Hub card — Retraite | explore_tab.dart:576 → :380 | `context.push('/explore/retraite')` | TODO — manual | TODO |
| 3.4 | Hub card — Famille | explore_tab.dart:576 → :387 | `context.push('/explore/famille')` | TODO — manual | TODO |
| 3.5 | Hub card — Travail & Statut | explore_tab.dart:576 → :394 | `context.push('/explore/travail')` | TODO — manual | TODO |
| 3.6 | Hub card — Logement | explore_tab.dart:576 → :401 | `context.push('/explore/logement')` | TODO — manual | TODO |
| 3.7 | Hub card — Fiscalité | explore_tab.dart:576 → :408 | `context.push('/explore/fiscalite')` | TODO — manual | TODO |
| 3.8 | Hub card — Patrimoine & Succession | explore_tab.dart:576 → :415 | `context.push('/explore/patrimoine')` | TODO — manual | TODO |
| 3.9 | Hub card — Santé & Protection | explore_tab.dart:576 → :422 | `context.push('/explore/sante')` | TODO — manual | TODO |
| 3.10 | "Blocked hub" bottom sheet — when readiness=blocked | explore_tab.dart:577 | Shows blocked sheet listing missing fields | TODO — manual | TODO |
| 3.11 | App bar action (menu / refresh) | explore_tab.dart:347 / :473 | Opens corresponding action | TODO — manual | TODO |

**Notes for tester:**
- Test 3.10 by tapping a hub for which your profile is missing the required fields (e.g. Santé without disability data). The blocked sheet must surface the missing fields, not silently no-op.

---

## ProfileDrawer (`profile_drawer.dart`)

| # | Element | File:Line | Expected | Actual | Verdict |
|---|---|---|---|---|---|
| 4.1 | "Mon profil" | profile_drawer.dart:40 | Navigates to `/profile` | TODO — manual | TODO |
| 4.2 | "Mon bilan" | profile_drawer.dart:48 | Navigates to `/profile/bilan` | TODO — manual | TODO |
| 4.3 | "Couple" (visible only if `profile.isCouple`) | profile_drawer.dart:57 | Navigates to `/couple` | TODO — manual | TODO |
| 4.4 | "Mes documents" — main tap | profile_drawer.dart:65 | Navigates to `/documents` | TODO — manual | TODO |
| 4.5 | "Mes documents" — camera trailing action | profile_drawer.dart:67 | Navigates to `/scan` | TODO — manual | TODO |
| 4.6 | "Historique coach" | profile_drawer.dart:75 | Navigates to `/coach/history` | TODO — manual | TODO |
| 4.7 | "Clé API" (BYOK) | profile_drawer.dart:98 | Navigates to `/profile/byok` | TODO — manual | TODO |
| 4.8 | "Confidentialité" (consent) | profile_drawer.dart:104 | Navigates to `/profile/consent` | TODO — manual | TODO |
| 4.9 | "Langue" | profile_drawer.dart:110 | **Known stub** — TODO inline language picker. Should at minimum no-op gracefully or surface a placeholder. | TODO — manual | TODO |
| 4.10 | "Transparence des données" | profile_drawer.dart:118 | Navigates to `/profile/data-transparency` | TODO — manual | TODO |
| 4.11 | "Contrôle confidentialité" | profile_drawer.dart:124 | Navigates to `/profile/privacy-control` | TODO — manual | TODO |
| 4.12 | "Déconnexion" | profile_drawer.dart:134 | Pops drawer + `context.go('/')` to landing | TODO — manual | TODO |

**Known issue ahead of walkthrough:**
- **4.9 "Langue"** has a TODO comment at `profile_drawer.dart:111` (`// TODO: inline language picker`). It is currently a no-op tap. Mark FAIL → escalate as ACCEPT-WITH-RATIONALE for v3.0 (i18n picker is not v2.1 scope, app already supports 6 languages via system locale).

---

## Triage rubric

For each FAIL row, classify and act:

- **P0 — broken core flow** (chat doesn't send, hub card crashes, drawer entry → null screen): fix in this phase, new commit `fix(07-06): <thing>`.
- **P1 — wrong screen / wrong data**: fix in this phase if surgical, otherwise ACCEPT-WITH-RATIONALE + GSD todo.
- **P2 — known stub (e.g. 4.9 language picker)**: log to `AUDIT_ACCEPT_LOG.md` and add v3.0 GSD todo.
- **P3 — cosmetic / animation glitch**: defer to v3.0.

Append every fix commit hash to a `## Fixes Applied` section at the bottom of this file.

---

## Sign-off

Tester: _______________________
Build: dev @ _______________________
Date: _______________________
Result: ☐ PASS ☐ PASS-WITH-ACCEPTED-FAILS ☐ BLOCKED

Once signed off with zero unaddressed FAILs → STAB-17 closes → v2.1 ready for TestFlight.
