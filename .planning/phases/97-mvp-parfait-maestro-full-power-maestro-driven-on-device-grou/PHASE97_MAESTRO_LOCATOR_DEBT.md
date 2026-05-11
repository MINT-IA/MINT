---
description: Phase 97 W1/W3 input — Maestro locator violations across the 4 broken flows. 14 violations catalogued from `python3 tools/checks/maestro_locator_audit.py` direct run 2026-05-11. Each violation is either (a) a text literal that doesn't exist in app source/ARB, or (b) an ID literal referencing a `Key('...')` that doesn't exist in Dart code.
phase: 97
wave: 1
deliverable_for: « W1 fragments + W3 regression suite »
source: « python3 tools/checks/maestro_locator_audit.py (lint repo-wide) »
total_violations: 14
flows_affected: 4
---

# Phase 97 — Maestro Locator Debt Inventory

> 14 locator violations across 4 flows means those flows CANNOT run live today. Each violation is one of two types : text literal not in app/ARB, OR ID literal without matching Key declaration. Both block Maestro from finding the widget to tap.

## Violations by flow

### Flow 1 — `tools/simulator/flows/auth_coach_post_hotfix.yaml` (4 text literals missing)

| # | Violation | Type | Fix path |
|---|-----------|------|----------|
| 1 | `'Comme tu vis dans le canton de Vaud'` | text not in app/ARB | Either (a) update flow to use existing ARB string OR (b) add string to ARB if narrator legitimately outputs it |
| 2 | `'Quel est ton salaire net mensuel ?'` | text not in app/ARB | Same — likely narrator output, check `services/backend/app/services/coach/*` |
| 3 | `'explorer des simulateurs pour des estimations chiffrées'` | text not in app/ARB | Same |
| 4 | `'salaire net mensuel'` | text not in app/ARB | Same |

**Diagnosis :** This flow was authored assuming the narrator would emit specific FR strings. The strings drifted (narrator changed prompt, output non-deterministic). Maestro can't assert on regex-y narrator output reliably.

**Fix strategy :** Replace `assertVisible` on narrator text with `assertVisible` on stable UI containers (`Key('chat_message_assistant')` + `attribute: bounds > 0`). The actual narrator text isn't the assertion ; the rendering of a message bubble is.

### Flow 2 — `tools/simulator/flows/julien_swiss.yaml` (1 text + 4 IDs missing)

| # | Violation | Type | Fix path |
|---|-----------|------|----------|
| 5 | `'Estime ta marge précise'` | text not in app/ARB | Narrator-output drift (same as Flow 1) |
| 6 | `id: 'anon-chat-input'` | Key('anon-chat-input') not declared in Dart | Add `Key('anon-chat-input')` to the TextField in `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` |
| 7 | `id: 'anon-chat-message-assistant'` | Key('anon-chat-message-assistant') not declared | Add `Key('anon-chat-message-assistant')` to the assistant message bubble widget |
| 8 | `id: 'anon-chat-opener-bubble'` | Key('anon-chat-opener-bubble') not declared | Add `Key('anon-chat-opener-bubble')` to the opener bubble component |
| 9 | `id: 'anon-chat-register-cta'` | Key('anon-chat-register-cta') not declared | Add `Key('anon-chat-register-cta')` to the « Crée un compte » button |

**Diagnosis :** The flow expects 4 stable Keys on the anonymous chat screen. None of them are declared. The screen was built without the testID convention — typical W14-pattern (widget exists, no Key for testing).

**Fix strategy :** Add the 4 Keys to `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` per the convention `Key(ValueKey('<scope>-<id>'))`. Surgical fix, ~30 min.

### Flow 3 — `tools/simulator/flows/lauren_expat_us.yaml` (1 text + 4 IDs missing)

Same set of violations as Flow 2 (`anon-chat-*` IDs + `'Estime ta marge précise'` text). Both flows target the same anonymous chat surface.

| # | Violation | Type | Fix path |
|---|-----------|------|----------|
| 10 | `'Estime ta marge précise'` | text not in app/ARB | Same as #5 |
| 11 | `id: 'anon-chat-input'` | same as #6 | Same fix |
| 12 | `id: 'anon-chat-message-assistant'` | same as #7 | Same fix |
| 13 | `id: 'anon-chat-opener-bubble'` | same as #8 | Same fix |
| 14 | `id: 'anon-chat-register-cta'` | same as #9 | Same fix |

**Diagnosis :** The 4 IDs are referenced by BOTH julien_swiss + lauren_expat_us. Once the Keys land in code (single commit), both flows pass simultaneously.

## W1 + W3 task implication

- **W1 fragment `anon_chat_send_message.yaml`** depends on the 4 anon-chat IDs being declared. **Phase 97 W1 T0 = land the 4 Key declarations** in `anonymous_chat_screen.dart`.
- **W3 regression flow `regression/anonymous_chat__<archetype>.yaml`** generates 8 archetype variants from the julien_swiss + lauren_expat_us templates. Currently broken on locators ; fixes after W1 T0 unblocks both.
- **auth_coach_post_hotfix.yaml** narrator-text issues require either (a) deleting the flow as outdated OR (b) refactoring to use stable bubble Keys. Decision deferred to W3 plan-phase.

## Counter-arguments and data gaps

### Counter-arguments

- **CA1 — These flows may be intentionally obsolete (auth_coach_post_hotfix was specifically a hotfix flow ; might be deletable).** Mitigation : check git blame on the flow files. If they're > 90 days old + no recent reference, they're candidates for deletion rather than fixing. W3 plan-phase decides.
- **CA2 — Adding 4 testID Keys requires touching anonymous_chat_screen.dart which may already have stable widget tests breaking on Key addition.** Mitigation : Flutter Key on existing widgets is non-breaking (widget identity preserved). But run `flutter test` after addition to confirm.
- **CA3 — Text-literal-drift suggests narrator prompts changed over time. Asserting on narrator output is structurally fragile.** Mitigation : adopt the « assert on stable container, not on dynamic content » convention as a Phase 97 W3 design principle. Document in `97-MAESTRO-CONVENTIONS.md` (Phase 97 W6 deliverable).

### Data gaps

- **DG1** — When were the 4 anon-chat IDs supposed to land in code? `git log -- 'tools/simulator/flows/julien_swiss.yaml'` would surface the authoring date ; the Keys may have been planned but the implementation skipped.
- **DG2** — Does Maestro support regex-y `assertVisible` for narrator text? If yes, drift tolerance is higher.

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Inventory generated : 2026-05-11 (W1+W3 deliverable, written ahead of plan in W0 audit)*
