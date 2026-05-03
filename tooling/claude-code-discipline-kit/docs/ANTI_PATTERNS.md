# Anti-Patterns

| ❌ Anti-pattern | ✅ Discipline | Why it fails |
|---|---|---|
| "I'll just edit this file quickly" without a plan | 1 — Plan-mode | 20 micro-decisions × 80% accuracy = 1% joint correctness |
| Patching a symptom without root cause | 2 — Iron Law | Same bug returns elsewhere; debug debt compounds |
| "Let me try one more thing" past 3 failed fixes | 2 — Iron Law (3-Fix Rule) | Architectural problem masquerading as a bug |
| Doing everything in the main thread | 3 — Subagents | Context saturation; quality degrades past 30K tokens |
| Writing tests after the implementation | 4 — TDD inverted | Tests confirm what the code does, not what it should do |
| "It compiles, I push" | 5 — Verification | Compilation ≠ correctness ≠ requirement satisfaction |
| Skipping the pre-push checklist on "small" changes | 5 — Verification | Source of multi-cycle CI failures |
| Pushing UI without a design panel | 6 — Panel | Visual/a11y drift accumulates silently |
| Storing evidence in `/tmp/...` | 7 — HTML evidence | Lost across sessions; same errors reproduce |
| Loading 5 files at once "for context" | 8 — < 40% utilization | Context rot; "lost in the middle" |
| Mixing research notes and plan decisions in the same doc | 9 — R/P/I separation | Implementation re-reads discovery; token cost + attention dilution |
| Per-second timestamps in system prompt | 10 — KV-cache stability | Cache invalidation every turn; ~10× cost |
| Editing past tool results retroactively | 10 — KV-cache | Same as above |
| 50 tool calls without restating the goal | 11 — Recitation | Macro-drift from accumulated correct micro-decisions |
| Cleaning the transcript after a failed test "to retry fresh" | 12 — Errors-in-context | Model reproduces the same failure |
| Generating 144 templates in identical series | 13 — Few-shot drift | Systematic undetected drift |
| "We have a skill for that, somewhere" without checking | 14 — Tool census | The 90% never-used tools rot; reinventing badly |
| Installing superpowers + gstack + GSD without reading their indexes | 14 — Tool census | Cargo-cult tooling; net negative ROI |

## Three failure-mode constellations

### A. The "looks done" trap (failures 1, 4, 5, 6, 7)
Code compiles, tests pass, PR is green, you merge. Production breaks because the test suite tested mocks not behavior, the design hadn't been reviewed, and the feature was never device-walked. Fix: enforce disciplines 1, 4, 5, 6 as gate, not preference.

### B. The "context exhaustion" trap (failures 8, 9, 10, 11)
Long conversation, accumulating context, model starts producing incoherent decisions. You blame the model. Actually you violated 4 context engineering disciplines simultaneously. Fix: monitor utilization, separate R/P/I, stabilize prefix, recite.

### C. The "tool blindness" trap (failures 14)
Project accumulates 100+ tools over years. Active operator uses 10%. The other 90% rot. Eventually someone "reinvents" a worse version of an existing tool. Fix: tool-census at session start, retire what isn't used.
