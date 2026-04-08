# Friction Pass 1 — Galaxy A14 Walkthrough (Julien's card)

> Phase 10.5 — MINT v2.2 "La Beauté de Mint". Read this ONCE on your laptop, then follow it. Scope is **closed** per D-09: golden path only, no exploration.

---

## Before you start (5 min, on laptop)

1. Confirm branch: `git branch --show-current` → `feature/v2.2-p0a-code-unblockers`
2. Plug Galaxy A14 via USB. Unlock. Enable **USB debugging** (Developer Options → USB debugging).
3. `adb devices` → should show exactly one device, state `device`.
4. From repo root: `tools/scripts/build_a14.sh --install --launch`
5. Verify the MINT icon appears in the app drawer.
6. **Force-stop the app** (Settings → Apps → MINT → Force stop). Do NOT keep it warm.

---

## Recording setup (2 min, on device)

1. Swipe down twice from the top → find **Screen record** tile (add to Quick Settings if missing).
2. Developer Options → **Show taps**: ON (draws tap circles into the recording).
3. Developer Options → **Pointer location**: OFF (too cluttered).
4. **Do Not Disturb**: ON (mute notifications).
5. Prepare a **stopwatch on a second device** (iPhone, wristwatch, or second phone). You need to time cold-start without touching the A14.

---

## The walkthrough (30 min, on device) — 3 runs

Do this **3 times**, each one a clean cold-start:

1. Force-stop MINT. Wait 10 seconds.
2. On the second device, stopwatch at 00:00.
3. Start screen recorder on the A14.
4. Finger hovering over the MINT icon — **do not tap yet**.
5. **Start stopwatch and tap icon simultaneously.**
6. Note stopwatch at first pixel of **S0 landing** → `cold_start_ms` (target **<2500ms**).
7. Note stopwatch when intent chips register a tap and change state → `interactive_ms` (target **<3000ms**).
8. Tap the **`explore`** intent chip (D-09 canonical choice).
9. On the chat screen, read the coach opener.
10. Type EXACTLY:
    > `Je viens d'avoir 30 ans, je commence à me demander si je devrais ouvrir un 3a.`
11. Tap send and **reset stopwatch simultaneously**.
12. Note stopwatch at first character of assistant response → `first_reply_ms` (target **<4000ms**).
13. Read the full response once. Any banned term, any untranslated jargon, any claim of certainty → **block**.
14. Stop screen recording.
15. Open `docs/FRICTION_PASS_1.md` on your phone (or notebook) and log every frottement from this run. One row per frottement.

---

## After the 3 runs

1. `adb pull /sdcard/Movies/<recording>.mp4 docs/FRICTION_PASS_1/walkthrough_run1.mp4` (repeat for run2, run3)
2. If any file >100MB, Claude will extract frames with `ffmpeg -i input.mp4 -vf fps=2 frames_run1/frame_%04d.png`
3. Fill the **Perf numbers** section at the top of `docs/FRICTION_PASS_1.md` with the 3×3 measurements, compute medians.
4. Tell Claude: **"Walkthrough done, triage please."** → Plan 10.5-03 begins.

---

## The shame test (MANDATORY — apply to every note)

> **"If a 55-year-old Swiss grandmother with no finance background saw this, would she think *'I'm stupid for not understanding'* or *'I'm behind in life'*?"**
>
> If yes → **block**. Not polish. Not nit. **Block.**

Per CONTEXT.md **D-04**: shame is existential, not cosmetic. There is no negotiation on shame leaks.

---

## Severity (LITERAL — from D-04)

- **block** = user can't proceed OR feels shame OR perf metric fails OR banned term visible OR >5s unresponsive. Hot-fix this iteration.
- **polish** = noticeable, doesn't break flow, no shame leak. Queued for Phase 12.
- **nit** = only Claude would notice. Deferred post-milestone.

---

## Golden path is CLOSED scope (D-09)

You are testing **exactly** this sequence:

> cold start → S0 landing → intent chip (`explore`) → chat opener → first message → first insight

You are **NOT** exploring ProfileDrawer, Explorer hubs, life-event screens, settings, or anything else. Stay on the golden path. Resist curiosity. Scope discipline = honest signal.

Build profile is **release**, not debug — per **D-01**. Cold start numbers from a debug build are lies.
