# Friction Pass 1 — Galaxy A14 Walkthrough (YYYY-MM-DD)

> Phase 10.5 — MINT v2.2 "La Beauté de Mint". Do NOT edit thresholds. See `.planning/phases/10.5-friction-pass-1/10.5-CONTEXT.md` §D-04 for full definitions.

## Device

- Model: Galaxy A14 (arm64-v8a)
- Android version: `<fill at runtime>`
- Build: release APK (D-01), commit `<fill: git rev-parse --short HEAD>`
- Date: `<fill at runtime>`
- Tester: Julien

## Perf numbers (3 cold-start runs, median wins)

| Run        | cold_start_ms | interactive_ms | first_reply_ms |
| ---------- | ------------- | -------------- | -------------- |
| 1          |               |                |                |
| 2          |               |                |                |
| 3          |               |                |                |
| **median** |               |                |                |
| **target** | <2500         | <3000          | <4000          |
| **pass?**  |               |                |                |

If any median fails → that row becomes a **block** entry in the Friction notes table below.

## Golden path (D-09)

cold start → S0 landing → intent chip (`explore`) → chat opener → first message (*"Je viens d'avoir 30 ans, je commence à me demander si je devrais ouvrir un 3a."*) → first insight

## Severity thresholds (from CONTEXT.md D-04)

- **block** — user CAN'T proceed OR feels shame ("I should already know this") OR perf fails OR banned term visible OR >5s unresponsive. Hot-fix immediately.
- **polish** — noticeable, doesn't break flow, no shame. Queue for Phase 12.
- **nit** — only Claude would notice. Deferred post-milestone.

**shame test:** *"Would a 55-year-old Swiss grandmother feel stupid or behind?"* → yes = **block**.

## Axis taxonomy

`timing` | `copy` | `motion` | `color` | `pacing` | `tap` | `layout` | `sound`

## Friction notes

| #   | Run | Timestamp (mm:ss) | Surface | Axis | Severity | Description | Proposed fix |
| --- | --- | ----------------- | ------- | ---- | -------- | ----------- | ------------ |
| 1   |     |                   |         |      |          |             |              |
| 2   |     |                   |         |      |          |             |              |
| 3   |     |                   |         |      |          |             |              |

<!-- add rows as needed — keep them numbered sequentially, Claude grep-matches row # in triage -->

## Notes for Claude

<!-- free-form impressions, gestalt feelings, anything that doesn't fit the table -->
