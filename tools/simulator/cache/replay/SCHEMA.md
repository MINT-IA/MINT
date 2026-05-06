# LLM Replay-Cache Schema (PERS-05, v2.13 Phase 90)

## Why

Per panel-locked architecture (`.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`) :

> **Phase 51 was killed by a missing ANTHROPIC_API_KEY.** The dev backend
> returned HTTP 503 « Je suis temporairement indisponible. » — operational,
> not architectural — and blocked phases 02-06 across all 3 mandatory
> archetypes uniformly.

v2.13 hard rule #3 : « ANY backend dependency MUST have a recorded-fixture
mock. ANTHROPIC_API_KEY must NOT gate any script. »

The replay-cache is the mock layer.

## Modes

`MINT_LLM_CACHE_MODE` env / dart-define :
- `replay` (default in walker mode) — chat service reads from cache files,
  no live API call.
- `record` — chat service makes live calls AND writes responses to cache
  for next run. Used to bootstrap or refresh fixtures.
- `live` — bypass cache entirely, always hit backend. Used for the weekly
  LLM regression run only ; never default.

## File layout

```
tools/simulator/cache/replay/
├── SCHEMA.md                              (this file)
├── julien_swiss/
│   ├── fr/
│   │   ├── premier_eclairage_turn_01.json
│   │   ├── premier_eclairage_turn_02.json
│   │   └── manifest.json
│   ├── de/
│   │   └── ...
│   └── en/
│       └── ...
├── lauren_expat_us/
│   ├── fr/
│   ├── de/
│   └── en/
├── sofia_independent/        (Phase 92)
├── anna_widow/               (Phase 92)
├── jennifer_fatca/           (Phase 92)
└── pierre_late_career/       (Phase 92)
```

## Cache key

A cached response is keyed by the **deterministic hash of** :
- archetype slug (`MINT_E2E_ARCHETYPE`)
- locale (`APP_LOCALE`)
- forced eclairage kind (`MINT_E2E_FORCE_ECLAIRAGE_KIND`)
- conversation turn index (1, 2, …)
- normalized user prompt (trimmed, NFC-unicode, lowercased)

Hash : `sha256(archetype + "|" + locale + "|" + forced_kind + "|" + turn + "|" + prompt)[:16]`.

Stored as filename : `<scenario>_turn_<NN>.json` where `<scenario>` is
the panel-tagged scenario id (e.g. `premier_eclairage`,
`fatca_garanti_combien`, `deuil_23h`).

## Cache entry schema

```json
{
  "schema_version": "1.0",
  "key": {
    "archetype": "julien_swiss",
    "locale": "fr",
    "forced_eclairage_kind": "fiscal_margin_3a",
    "turn": 1,
    "prompt_hash": "abcd1234567890ef",
    "prompt_normalized": "combien je peux mettre dans un 3a cette annee ?"
  },
  "recorded_at": "2026-05-06T07:00:00Z",
  "recorded_by": "Claude Sonnet 4.6 via Railway staging",
  "request": {
    "endpoint": "/api/v1/anonymous/coach/chat",
    "model": "claude-sonnet-4-6-20250929"
  },
  "response": {
    "status": 200,
    "body": {
      "message": {
        "role": "assistant",
        "content": "Plafond du 3e pilier 2026 : ...",
        "eclairage": {
          "kind": "fiscal_margin_3a",
          "headline": "Ta marge fiscale 3a",
          "body": "...",
          "chf_range_low": 1500,
          "chf_range_high": 2500,
          "chf_range_period": "year",
          "soft_account_hint": "Estime ta marge précise",
          "lsfin_disclaimer": "..."
        }
      },
      "compliance": {
        "passed": true,
        "banned_terms_hit": []
      }
    }
  },
  "assertions": {
    "lsfin_banned_regex_hit_count": 0,
    "issuer_names_hit_count": 0,
    "promise_regex_hit_count": 0,
    "fr_accent_violations": 0,
    "min_chf_in_body": 1500,
    "max_chf_in_body": 2500
  }
}
```

## Wiring contract (Flutter app side)

`apps/mobile/lib/services/coach_llm_service.dart` (or equivalent
chat service) reads `MINT_LLM_CACHE_MODE` at startup :
- `replay` : intercept `/api/v1/anonymous/coach/chat` calls, look up
  the cache entry by key, return `response.body` directly. Skip Sentry
  breadcrumb for the live call (still emit a `mint.replay.served`
  breadcrumb for traceability).
- `record` : pass through the live call AND write the response to cache.
  Skip if cache file already exists (no overwrites without explicit
  --force flag).
- `live` (default for non-walker, non-test builds) : current behaviour,
  no cache touched.

## Bootstrap procedure

1. Build app with `MINT_LLM_CACHE_MODE=record` + the persona archetype
   dart-defines.
2. Run walker once against staging → all turns of the scripted scenario
   get persisted to cache.
3. Re-run walker with `MINT_LLM_CACHE_MODE=replay` → no network calls,
   deterministic responses.
4. Cache files committed to git (small JSON, < 10 KB each).

## Refresh policy

Cache fixtures are refreshed when :
- The deterministic prompt for a persona changes (rare, panel-locked).
- The éclairage card schema changes (Pydantic v2 model bump backend-side).
- The compliance regex library changes (rare).
- A net-new banned-term gate is added (`mint.compliance.guard.fail` should
  fire ; cache must capture this).

Refresh = run walker with `--llm-cache-mode=record --force` for the
affected archetypes.

## Hard rules (anti-Phase-51 carry)

1. NO replay-cache MISS may silently fall back to a live call. If a
   scripted persona scenario's cache key has no match, the test FAILS
   loudly with `MissingReplayCacheError(key)`.
2. The cache files are NOT goldens. Do not gate on byte-equal screenshots
   from cached runs ; gate on the rendered widget tree assertions
   (PERS-08 Dart assertions).
3. `MINT_LLM_CACHE_MODE=live` is opt-in only. Default for walker = replay.

## Status

- Schema : SHIPPED this commit.
- Wiring (Flutter app side) : DEFERRED to Phase 91 — the actual interceptor
  in `coach_llm_service.dart` requires careful integration with the
  existing Sentry breadcrumbs + compliance guard layers ; not a Phase 90
  scaffolding line item.
- Bootstrap fixtures (julien_swiss + lauren_expat_us, FR turn 1) :
  provided as `*_turn_01.json` skeleton files alongside this schema.
