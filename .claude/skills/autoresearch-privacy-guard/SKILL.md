---
name: autoresearch-privacy-guard
description: "PII leak scanner + autonomous fixer. Scans logs, analytics, LLM prompts, CoachContext for PII. Detect → anonymize → verify → commit. Use with /autoresearch-privacy-guard."
compatibility: Requires Flutter SDK and Python 3.10+
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch Privacy Guard v3 — Karpathy PII Hunter

> "If it can identify a user, it must not reach logs, analytics, or LLM."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: PII violations count (target: 0).
- **Time budget**: 3 min per fix. If fix breaks tests → revert immediately.
- **Single target**: ONE file per fix cycle.
- **Legal**: nLPD (Swiss Data Protection Act), CLAUDE.md § 6.
- **NEVER delete functionality** — only redact/anonymize the PII portion.
- **NEVER fix PII in test files** — fake test data is acceptable.

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
