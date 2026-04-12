---
name: autoresearch-privacy-guard
description: "PII leak scanner + autonomous fixer. Scans logs, analytics, LLM prompts, CoachContext for PII. Detect → anonymize → verify → commit. Use with /autoresearch-privacy-guard."
compatibility: Requires Flutter SDK and Python 3.10+
metadata:
  author: mint-team
  version: "4.0"
---

# Autoresearch Privacy Guard v4 — Karpathy PII Hunter

> "If it can identify a user, it must not reach logs, analytics, or LLM."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: PII violations count (target: 0).
- **Time budget**: 3 min per fix. If fix breaks tests → revert immediately.
- **Single target**: ONE file per fix cycle.
- **Legal**: nLPD (Swiss Data Protection Act), CLAUDE.md § 6.
- **NEVER delete functionality** — only redact/anonymize the PII portion.
- **NEVER fix PII in test files** — fake test data is acceptable.

## Context Budget Protocol

Your context window is a finite resource. Quality degrades as it fills.

| Tier | Context Used | Behavior |
|------|-------------|----------|
| PEAK | 0-30% | Full operations. Read freely, explore, try multiple approaches. |
| GOOD | 30-50% | Normal. Prefer targeted reads over exploratory. |
| DEGRADING | 50-70% | Economize. No exploration. Targeted fixes only. Warn in log. |
| POOR | 70%+ | STOP new iterations. Finish current only. Write report. Commit. |

### Degradation Warning Signs — STOP and assess if you notice:

- **Silent partial completion**: Claiming done but skipping verify steps you'd normally follow.
- **Increasing vagueness**: Writing "appropriate handling" instead of specific code references.
- **Skipped steps**: Iteration normally has 6 steps but you only did 4.

If ANY sign is present → treat as POOR tier. Write final report and stop.

### Iteration Budget

Estimate remaining iterations: `(100 - context_used%) / 3`.
At < 10 remaining → plan exit. At < 5 → STOP. Report only.

## PII Detection Patterns

| Category | Grep pattern | Anonymize to |
|----------|-------------|--------------|
| IBAN | `CH\d{2}\s?\d{4}` | `[IBAN_REDACTED]` |
| AVS/AHV number | `756\.\d{4}\.\d{4}\.\d{2}` | `[AVS_REDACTED]` |
| Exact salary in log | `salary\|salaire` in `print\|log\|debug` | Range bracket "100-120K" |
| NPA in prompt | `\d{4}\s[A-Z]` in coach context | Canton code only ("VS") |
| Employer | `employer\|employeur` in log/prompt | `[EMPLOYER]` |
| Email | `@.*\.` in log context | `[EMAIL_REDACTED]` |
| Phone | `+41\|0[0-9]{9}` | `[PHONE_REDACTED]` |

## Scan Phases (in order)

```bash
# Phase 1: Dart print/log statements
grep -rn "print(\|debugPrint(\|log(\|logger\." apps/mobile/lib/ --include="*.dart" \
  | grep -v "// \|/// \|_test\|test/"

# Phase 2: CoachContext construction (CRITICAL — sent to LLM)
grep -rn "CoachContext\|coachContext\|_buildCoachContext" apps/mobile/lib/ --include="*.dart" \
  | grep -v test

# Phase 3: Analytics events
grep -rn "analytics\.\|trackEvent\|logEvent" apps/mobile/lib/ --include="*.dart" | grep -v test

# Phase 4: Backend logging
grep -rn "logger\.\|logging\.\|print(" services/backend/ --include="*.py" \
  | grep -v test | grep -v "__pycache__"

# Phase 5: LLM prompts
grep -rn "systemPrompt\|system_prompt\|buildPrompt" apps/mobile/lib/ --include="*.dart" \
  | grep -v test

# Phase 6: SharedPreferences
grep -rn "SharedPreferences\|setString\|setDouble" apps/mobile/lib/ --include="*.dart" \
  | grep -v test
```

## The Loop

```
┌─ SCAN: Run all 6 phase commands. Collect hits.
│
├─ CLASSIFY each hit: CRITICAL (reaches external: logs, LLM, analytics) | WARNING (local only)
│
├─ FIX (one file at a time, ≤3 min):
│  1. Read file containing PII
│  2. Identify PII type
│  3. Replace with anonymized equivalent (see table above)
│  4. Verify: grep for original pattern → must return 0 hits
│  5. flutter test → pass → commit. Fail → revert.
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add ... && git commit -m "fix(privacy): redact PII in <file>"
│
└─ REPEAT: Fix all CRITICAL findings. Report WARNING findings.
```

## CoachContext Checklist (CRITICAL)

CoachContext sent to LLM must NEVER contain:
- [ ] Exact salary (use bracket: "80-100K")
- [ ] Exact savings/debt amounts (use bracket)
- [ ] NPA/commune (use canton code: "VS", "GE")
- [ ] Employer name (omit or "[EMPLOYER]")
- [ ] IBAN or account numbers

```bash
grep -A 20 "CoachContext\|buildCoachContext" apps/mobile/lib/ -r --include="*.dart" \
  | grep -i "salaire\|salary\|savings\|dette\|debt\|npa\|postal\|employer\|employeur\|iban"
```

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY PII fix, before reporting it as done:

1. **RUN** `grep -rn "<original_pattern>" <file>` to confirm the PII is gone. Paste output (must be empty).
2. **RUN** `flutter test 2>&1 | tail -10` if Dart file changed. Paste output.
3. **RUN** the scan phase command for the fixed category. Confirm hit count decreased.
4. If pattern still matches → the fix is incomplete. Do not claim otherwise.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the grep. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "This data isn't really PII" | If it can identify a user, it's PII. Period. |
| "It's only in debug logs" | Debug logs reach crash reporters. Redact it. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. If grep still matches the PII pattern → the fix is incomplete. If `flutter test` broke → revert and try a different anonymization approach.

Claiming work is complete without verification is dishonesty, not efficiency.

### Common Failures — what your claim REQUIRES (Superpowers)

| Claim | Requires | NOT Sufficient |
|-------|----------|----------------|
| "PII removed" | Fresh grep pattern count = 0 for that file | Code changed, "should be clean" |
| "No regressions" | `flutter test` output: same or fewer failures | Running only grep |
| "Violation count decreased" | Fresh full scan count < previous count | "I fixed 3 leaks" without re-scanning |
| "Iteration complete" | All loop steps executed + output pasted | Steps skipped, partial evidence |
| "Ready to commit" | Grep clean + tests green, this iteration | Clean from previous iteration |

### Red Flags — STOP if you catch yourself doing ANY of these:

- Using "should", "probably", "seems to" about test results
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit without fresh verification in THIS iteration
- Trusting a previous run's results after code changed
- Relying on partial verification ("I tested the main case")
- Thinking "just this once I can skip verification"
- Feeling rushed and wanting to move to the next iteration
- Using different words to dodge this rule ("appears to work" = "should work")
- Reporting fewer steps than the loop specifies (silent step-skipping)

## Experiment Log (append-only)

```
finding  phase  file                    pii_type  severity  status   action
1        1      coach_service.dart:45   salary    CRITICAL  fixed    replaced with bracket
2        2      coach_context.dart:89   npa       CRITICAL  fixed    replaced with canton
3        3      analytics.dart:12       email     WARNING   flagged  needs manual review
```

## Final Report

```
AUTORESEARCH PRIVACY GUARD — SESSION REPORT
Date: YYYY-MM-DD | Files scanned: N

CRITICAL (fixed):
  - coach_service.dart:45 — print(salary) → print("[SALARY_BRACKET]")
  - coach_context.dart:89 — NPA in prompt → canton only

WARNING (flagged for review):
  - analytics.dart:12 — ambiguous variable in event

OK (verified safe):
  - CoachContext: ✅ uses ranges
  - Analytics: ✅ no PII in events
  - LLM prompts: ✅ no raw financial data

EXPERIMENT LOG:
finding  phase  file  type  severity  status  action
1        ...
```

## Invocation

- `/autoresearch-privacy-guard` — full scan + autonomous fix
