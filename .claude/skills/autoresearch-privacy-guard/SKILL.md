---
name: autoresearch-privacy-guard
description: "Audit-only scan for PII leaks in logs, analytics, LLM prompts, and CoachContext. Reports violations without modifying code. Use with /autoresearch-privacy-guard."
compatibility: Requires Flutter SDK and Python 3.10+
allowed-tools: Bash(grep:*) Bash(find:*) Read Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Privacy Guard — PII leak scanner (audit-only)

## Purpose

Scan the entire MINT codebase for potential PII (Personally Identifiable Information) leaks. This skill is **read-only** — it produces a report but never modifies code.

## Legal context

- **nLPD** (Swiss Federal Act on Data Protection, in force since 1 Sept 2023)
- **CLAUDE.md rule**: "Never log identifiable data (IBANs, names, SSN, employer)"
- **CoachContext**: NEVER contains exact salary, savings, debts, NPA, or employer

## What constitutes PII in MINT

| Category | Examples | Detection pattern |
|----------|----------|-------------------|
| Financial IDs | IBAN, account numbers | `CH\d{2}\s?\d{4}`, `\d{4}\s\d{4}\s\d{4}` |
| Social security | AHV/AVS number | `756\.\d{4}\.\d{4}\.\d{2}` |
| Personal | Name, email, phone | `@.*\.`, `+41`, `firstName`, `lastName` in log context |
| Location | NPA, exact address | `\d{4}\s[A-Z]` (Swiss postal code pattern) |
| Financial amounts | Exact salary, debts | Raw amounts in `print()`, `log()`, `debugPrint()` |
| Employer | Company name | `employer`, `employeur` in log/prompt context |

## Scan phases

### Phase 1: Dart code — print/log statements

```bash
# Find all print/log statements
grep -rn "print(\|debugPrint(\|log(\|logger\." apps/mobile/lib/ --include="*.dart" | grep -v "// \|/// \|_test\|test/"
```

For each match, check if the logged content could contain:
- Profile fields (salary, savings, debts, NPA, employer)
- User input (form values, text fields)
- API responses with user data

### Phase 2: CoachContext construction

```bash
# Find CoachContext building
grep -rn "CoachContext\|coachContext\|_buildCoachContext\|profileContext" apps/mobile/lib/ --include="*.dart" | grep -v test
```

Verify that CoachContext never contains:
- Exact salary amounts (should use ranges like "80-120k")
- Exact savings/debt amounts
- NPA or commune name
- Employer name
- IBAN or account numbers

### Phase 3: Analytics events

```bash
# Find analytics tracking
grep -rn "analytics\.\|trackEvent\|logEvent\|FirebaseAnalytics" apps/mobile/lib/ --include="*.dart" | grep -v test
```

Verify no PII in event properties.

### Phase 4: Backend logging

```bash
# Find Python logging
grep -rn "logger\.\|logging\.\|print(" services/backend/ --include="*.py" | grep -v test | grep -v "__pycache__"
```

### Phase 5: LLM prompts

```bash
# Find system prompts sent to LLM
grep -rn "systemPrompt\|system_prompt\|buildPrompt\|_buildSystem" apps/mobile/lib/ --include="*.dart" | grep -v test
```

Verify prompts don't embed raw financial data.

### Phase 6: SharedPreferences / local storage

```bash
# Find local storage writes
grep -rn "SharedPreferences\|setString\|setDouble\|setInt" apps/mobile/lib/ --include="*.dart" | grep -v test
```

Verify sensitive data is not stored in plain text.

## Report format

```
PRIVACY GUARD AUDIT REPORT
============================
Scan date: YYYY-MM-DD
Files scanned: N

CRITICAL (PII in logs/prompts):
  - file.dart:123 — print() contains profile.salaireBrut
  - file.dart:456 — CoachContext includes exact NPA
  ...

WARNING (potential PII exposure):
  - file.dart:789 — debugPrint with user input variable
  ...

OK (verified safe):
  - CoachContext: ✅ uses ranges, no exact values
  - Analytics: ✅ no PII in event properties
  - LLM prompts: ✅ no raw financial data
  ...

RECOMMENDATIONS:
  - Replace print(profile.salary) with print('salary: [redacted]')
  - Use CoachContext.anonymized() instead of raw profile
  ...
```

## Strict rules

- **NEVER** modify any code — this is an audit-only skill
- **NEVER** create files (except the report)
- Report ALL findings, even if they seem minor
- False positives are OK — better to over-report than miss a leak
- Focus on what reaches external systems (logs, analytics, LLM, network)
- Local-only data (SharedPreferences for app state) is lower priority

## Invocation

`/autoresearch-privacy-guard` — full scan, produces report
