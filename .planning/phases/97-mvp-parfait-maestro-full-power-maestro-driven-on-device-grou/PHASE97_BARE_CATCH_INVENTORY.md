---
description: Phase 97 W0 input — bare catch inventory across Python backend + Dart mobile. Gross counts from `grep` 2026-05-11 ; net counts (truly silent vs legit log-and-rethrow) require line-by-line audit deferred to W7 first iteration cycle.
phase: 97
wave: 0
deliverable_for: « W7 first iteration cycle — top-10-bugs P0/P1 closure »
source: « grep -rn 'except Exception:$' services/backend/app/ + grep -rnE 'catch \([a-z_]+\) \{\\s*$|catch \(_\) \{\\s*$' apps/mobile/lib/ »
gross_count: 386
caveat: « gross count includes catches followed by log+rethrow or specific exception conversion ; net TRULY-silent count requires per-site review »
---

# Phase 97 — Bare Catch Inventory (gross)

## Counts

| Surface | Gross count | Severity tier |
|---------|-------------|---------------|
| Python backend (`services/backend/app/`) | **52** sites with `except Exception:` or `except:` | P1 forbidden per CLAUDE.md §5 if no log+rethrow |
| Dart mobile (`apps/mobile/lib/`) | **334** sites with `catch (e) {` or `catch (_) {` | P1 forbidden if empty/no Sentry |
| **TOTAL** | **386** | — |

## Why this is a meaningful signal

CLAUDE.md §5 DEV RULES (« No bare catches ») explicitly forbids :
> `catch (e) {}` ou `except Exception:` sans log/rethrow = forbidden.

Memory `commit-hygiene-reminder` (2026-05-10) confirms `no_bare_catch.py` lint is **NOT yet wired** in lefthook (deferred Phase 34 GUARD-* restant). So 386 sites accumulated unchecked.

Real-world impact :
- Production exceptions silently swallowed → Sentry alerts suppressed
- Async/Future errors caught and dropped → UI shows generic state instead of error
- Authentication failures look like « no user » instead of « auth broken »
- DB connection failures silent → user sees stale data instead of error

## Gross vs Net

The 386 gross count includes BOTH :
- (a) Truly silent (`catch (e) { /* nothing */ }`) — these are forbidden
- (b) Log-and-rethrow (`catch (e) { logger.exception(e); raise }`) — these are FINE
- (c) Conversion (`except SomeError: raise HTTPException(...)`) — these are FINE
- (d) Default-value fallback with log (`catch (_) { _logger.warn('...'); return defaultValue; }`) — these are USUALLY FINE if intentional

The net TRULY-silent count requires per-site review. Estimate based on sample (`coach_chat.py:1417` is followed by `return None  # silent skip` — actually silent ; `main.py:99` Dart side is followed by `developer.log(e)` — not silent).

## Top file by count

Python :
- `services/backend/app/api/v1/endpoints/coach_chat.py` : 8 sites (lines 1131, 1414, 1417, 1571, 2989, 3009, 3538, +1)
- `services/backend/app/api/v1/endpoints/documents.py` : 4 sites (469, 746, 859, 1187)
- `services/backend/app/services/document_vision_service.py` : 3 sites
- (the rest distributed across services/auth, rag, privacy, document_memory)

Dart : distribution requires further audit ; high-density files :
- `apps/mobile/lib/providers/coach_profile_provider.dart` : 6+ sites
- `apps/mobile/lib/providers/byok_provider.dart` : 2 sites
- (the rest distributed across services, widgets, screens)

## Registry rows (registered in 97-BUGS-REGISTRY.md)

- **L006** « 52 Python bare except » — severity P1, score 16 — was reported as 15+ in v0 ; updated to 52 in v1
- **L007** « 334 Dart bare catch (gross) » — severity P1, score 16 — was reported as 8+ in v0 ; updated to 334 in v1
- **NEW : L010** — net silent-fail count audit (audit task for W7 first iteration cycle)

## Closure path

**W7 first iteration cycle (proof-of-concept) :**
- Pick top 5 sites by call-frequency (coach_chat.py + documents.py probably) and per-site review : silent? log-and-rethrow? type-conversion?
- For TRULY silent sites : replace with `except <SpecificException>: logger.exception(...); raise` OR `except Exception as e: logger.exception(...); raise` if cross-cutting
- Add `no_bare_catch.py` lint to lefthook AFTER the top 5 sites are clean (otherwise lint blocks all commits in the codebase)
- Inventory the remaining net-silent sites for v2.10 sub-phases

**v2.10 follow-up :**
- Sub-phase « bare-catch sweep » : 5-10 sites per sprint until net count < 10

## Counter-arguments and data gaps

### Counter-arguments

- **CA1 — Some bare catches are legitimate « last-line defense » in middleware (e.g. global exception handler at main.py:169-180).** These should NOT be promoted to P0 silent-failure violations. The lint exemption marker `# lint-ignore: bare-catch` documents intent.
- **CA2 — Dart `catch (e)` followed by an empty body is uncommon ; most have `_logger.warn(e)` or similar.** The 334 gross count probably contains < 50 truly-silent sites. Net audit needed before deciding the actual P0/P1 severity per site.
- **CA3 — Adding `logger.exception()` to every silent catch increases Sentry noise.** If exception is expected (e.g. user not authenticated → return 401), it shouldn't fire Sentry. Each site needs intent-based classification.

### Data gaps

- **DG1** — net truly-silent count (the per-site review) is the main gap. W7 first iteration spends 1 day on this.
- **DG2** — production Sentry exception count over last 7 days on staging would surface the ACTUAL silent surface (catches that DID fire production exceptions but Sentry never saw them). Requires Sentry API access.
- **DG3** — `no_bare_catch.py` script doesn't exist yet (per memory `commit-hygiene-reminder` deferred Phase 34). Phase 97 W6 could land it as part of methodology lockdown.

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Inventory generated : 2026-05-11 (W0 deliverable ; W7 closure path documented)*
