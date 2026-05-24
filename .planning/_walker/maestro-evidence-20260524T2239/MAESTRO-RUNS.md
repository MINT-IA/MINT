description: Maestro evidence for 2026-05-24 after Plans 23-26.

# Maestro Runs — 2026-05-24

## Environment

- Device: iPhone 17 Pro simulator, iOS 26.2
- Maestro: 2.5.1
- Bundle: `ch.mint.app`
- Build 1: `MINT_E2E_ARCHETYPE=julien_swiss`, `MINT_DISABLE_BETA_MODAL=true`
- Build 2: `MINT_E2E_ARCHETYPE=expat_us`, `MINT_DISABLE_BETA_MODAL=true`

## Passed

| Flow | Exit | Evidence |
|---|---:|---|
| `flow_data_spine_visible_coach_packet.yaml` | 0 | `data-spine-coach-packet-01-visible.png`, `data-spine-coach-packet-02-relaunch.png` |
| `flow_hardgate_expat_us.yaml` | 0 | `01.5-hardgate-01-waitlist-reached.png`, `01.5-hardgate-02-success-state.png`, `01.5-hardgate-03-back-to-home.png` |
| `flow_g2_julien_walkthrough.yaml` | 0 | `g2-01-turn1.png`, `g2-02-turn2.png`, `g2-04-final.png` |
| `flow_drawer_navigation_smoke.yaml` | 0 | Console run completed all drawer route assertions |

## Partial

| Flow | Result | Evidence |
|---|---|---|
| `bug__F001__chat_input_bar_exists.yaml` | The shared cold-launch fragment now reaches `Aujourd'hui`; the outer flow still stops at `card_mon_3a_2026`, matching the flow header's documented precondition. | Console run `20260524T224110` |

## Notes

- The first `expat_us` rebuild hit the known macOS `.nosync` xattr signing
  issue on `App.framework`; stripping xattrs on build artifacts fixed the
  rebuild without code changes.
- The raw failed-run trace directories were discarded after extracting the
  diagnosis to keep the repository small and clean.
