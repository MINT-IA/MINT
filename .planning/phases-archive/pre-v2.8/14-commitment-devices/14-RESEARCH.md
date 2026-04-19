# Phase 14: Commitment Devices - Research

**Researched:** 2026-04-12
**Domain:** Coach AI tool extensions, behavioral nudges, local notifications, DB persistence
**Confidence:** HIGH

## Summary

Phase 14 wires behavioral science into the existing coach AI loop. The architecture is well-constrained: new internal tools (`record_commitment`, `save_pre_mortem`) follow the exact pattern of existing tools like `save_insight`; the system prompt gets new directives for implementation intentions and pre-mortem prompting; two new DB tables store commitment devices and pre-mortem entries; and the notification service gains a new scheduling method for commitment reminders. The fresh-start anchor system is a new backend endpoint + local notification scheduler that reads profile dates.

The codebase is mature for this work. The internal tool interception pattern in `coach_chat.py` (`_execute_internal_tool` + `INTERNAL_TOOL_NAMES`) is proven and handles all edge cases (input validation, PII scrubbing, injection filtering, truncation). The notification service already schedules multiple categories with deeplinks and consent checks. The Alembic migration pipeline has 13+ migrations. No new libraries are needed.

**Primary recommendation:** Implement as 3 vertical slices: (1) implementation intentions (system prompt + tool + DB + widget), (2) pre-mortem flow (system prompt + tool + DB + CoachContext injection), (3) fresh-start anchors (endpoint + notification scheduler + deeplink). Each slice is independently testable E2E.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- System prompt directive in `build_system_prompt`: "After every Layer 4 insight, propose a WHEN/WHERE/IF-THEN implementation intention." Coach generates it as natural text, backend parses into structured `CommitmentDevice`.
- Backend DB table `commitment_devices` (id, user_id, type, when_text, where_text, if_then_text, status, created_at, reminder_at). Persisted via new internal tool `record_commitment`.
- Inline chat widget `CommitmentCard` -- WHEN/WHERE/IF-THEN fields, editable. User taps "Accept" or edits fields, then "Save". Dismiss = swipe away.
- Coach proposes intentions only on Layer 4 insights (personal perspective + action step) -- not every message. Detection via system prompt directive, not code logic.
- 5 landmark types: birthday, month-1 (1er du mois), year-start (1er janvier), job anniversary (from `firstEmploymentYear`), 1-year MINT anniversary.
- Local notification (existing `notification_service.dart` Tier 1 pattern) with deeplink to coach chat. When user taps, coach has pre-loaded context about why today matters.
- Backend fresh-start endpoint `/api/v1/coach/fresh-start` returns personalized message based on user profile + commitment history. Called by notification tap deeplink.
- Rate limiting: max 1 per landmark date, max 2 per month. Birthday + year-start coincidence (Jan 1 birthday) = 2 messages OK.
- 3 irrevocable types trigger pre-mortem: EPL (propriete), capital withdrawal (2e/3a pilier), 3a closure. Detected via intent tags `housing_purchase_epl`, `retirement_capital_choice`, `pillar_3a_closure`.
- Coach-initiated in conversation: "Imagine qu'on est en 2027 et que cette decision s'est mal passee. Qu'est-ce qui aurait pu arriver?" Stores user's free-text response via `save_pre_mortem` internal tool.
- Backend `pre_mortem_entries` table (user_id, decision_type, decision_context, user_response, created_at). Injected into CoachContext memory block as "RISQUES IDENTIFIES" section.
- Auto-referenced: when CoachContext detects topic matching a prior pre-mortem decision type, inject: "L'utilisateur a fait un pre-mortem le {date} concernant {type}. Il a dit craindre que: {response}. Reference naturellement."

### Claude's Discretion
- DB migration details (Alembic vs raw SQL)
- CommitmentCard widget styling details
- Notification scheduling internals (exact vs inexact alarms)
- Fresh-start message content generation approach

### Deferred Ideas (OUT OF SCOPE)
- Push notifications (v2.6 -- requires push infra)
- Graduation Protocol integration (long-term direction)
- Commitment analytics dashboard (v2.6+)
- Social accountability features (never -- no social comparison)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CMIT-01 | Each Layer 4 insight includes an implementation intention (WHEN/WHERE/IF-THEN) that user can accept or edit | System prompt directive + `record_commitment` internal tool + `CommitmentCard` Flutter widget |
| CMIT-02 | Accepted implementation intentions are persisted and surfaced as reminders via notification scheduler | `commitment_devices` DB table + notification service extension for commitment reminders |
| CMIT-03 | Fresh-start anchor detector identifies landmark dates (birthday, month-1, year-start, 1-year anniversary) from user profile | Profile fields (birthDate, firstEmploymentYear, created_at) + local date computation |
| CMIT-04 | Fresh-start anchors trigger ONE proactive MINT message at each landmark date | `/api/v1/coach/fresh-start` endpoint + notification scheduling + rate limiting |
| CMIT-05 | Pre-mortem prompt appears before irrevocable decisions (EPL, capital withdrawal, 3a closure) | System prompt directive with intent tag detection + `save_pre_mortem` internal tool |
| CMIT-06 | Pre-mortem free-text response is stored in dossier and referenced in future related conversations | `pre_mortem_entries` DB table + CoachContext injection as "RISQUES IDENTIFIES" section |
| LOOP-01 (partial) | After each coach insight, MINT suggests the next step in the loop | Already complete per REQUIREMENTS.md -- no work needed |
| LOOP-02 (partial) | After user action (commitment accepted, pre-mortem completed), coach acknowledges and updates memory visibly | Coach text acknowledgement via system prompt directive + save_insight for memory persistence |
</phase_requirements>

## Standard Stack

### Core (already in project -- no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SQLAlchemy | >=2.0.0 | DB models for commitment_devices, pre_mortem_entries | Already used for all 14+ models [VERIFIED: pyproject.toml] |
| Alembic | >=1.13.0 | DB migrations | Already used for 13+ migrations [VERIFIED: pyproject.toml] |
| flutter_local_notifications | ^18.0.1 | Commitment reminders + fresh-start notifications | Already used for 6 notification types [VERIFIED: pubspec.yaml] |
| FastAPI | existing | Fresh-start endpoint | Already used for all endpoints [VERIFIED: codebase] |

### Supporting (no new packages needed)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| timezone (Dart) | existing | TZDateTime scheduling for commitment reminders | Already imported in notification_service.dart |
| shared_preferences | existing | Local persistence of scheduled commitment IDs | Already used for deadline recovery |

**Installation:** No new packages required. All dependencies are already in the project.

## Architecture Patterns

### Recommended Project Structure

```
services/backend/
  app/
    models/
      commitment.py            # CommitmentDevice + PreMortemEntry SQLAlchemy models
    api/v1/endpoints/
      coach_chat.py            # Extended: record_commitment + save_pre_mortem handlers
      fresh_start.py           # NEW: /api/v1/coach/fresh-start endpoint
    services/coach/
      claude_coach_service.py  # Extended: implementation intention + pre-mortem directives
      coach_tools.py           # Extended: 2 new internal tool definitions
      coach_context_builder.py # Extended: commitment history + pre-mortem injection
  alembic/versions/
    p14_commitment_devices.py  # NEW: migration for both tables
  tests/
    test_commitment_devices.py # NEW: unit tests

apps/mobile/
  lib/
    widgets/
      commitment_card.dart     # NEW: editable WHEN/WHERE/IF-THEN card
    services/
      notification_service.dart # Extended: scheduleCommitmentReminder + scheduleFreshStart
      commitment_service.dart   # NEW: API calls for commitment persistence
```

### Pattern 1: Internal Tool Extension (PROVEN)

**What:** Add new internal tools to the coach agent loop following the exact existing pattern.
**When to use:** For `record_commitment` and `save_pre_mortem`.
**How it works (verified from codebase):**

1. Define tool in `coach_tools.py` COACH_TOOLS list with `category: "write"` [VERIFIED: coach_tools.py line 112-724]
2. Add tool name to `INTERNAL_TOOL_NAMES` list [VERIFIED: coach_tools.py line 57-75]
3. Add handler case in `_execute_internal_tool()` [VERIFIED: coach_chat.py line 572-672]
4. Tool is intercepted by agent loop, never forwarded to Flutter [VERIFIED: coach_chat.py line 1038-1042]
5. Result is re-injected as text for next LLM iteration [VERIFIED: coach_chat.py line 1106-1112]

```python
# In coach_tools.py — add to INTERNAL_TOOL_NAMES:
INTERNAL_TOOL_NAMES: list[str] = [
    # ... existing ...
    "record_commitment",
    "save_pre_mortem",
]

# In coach_tools.py — add to COACH_TOOLS:
{
    "name": "record_commitment",
    "category": "write",
    "access_level": "user_scoped",
    "description": (
        "Record the user's implementation intention after they accept or edit it. "
        "Call this ONLY after the user confirms the WHEN/WHERE/IF-THEN fields. "
        "The commitment is persisted and a reminder is scheduled."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "when_text": {"type": "string", "description": "WHEN: date or trigger moment"},
            "where_text": {"type": "string", "description": "WHERE: context or location"},
            "if_then_text": {"type": "string", "description": "IF-THEN: conditional action plan"},
            "reminder_at": {"type": "string", "description": "ISO 8601 datetime for reminder (optional)"},
        },
        "required": ["when_text", "where_text", "if_then_text"],
    },
}
```

### Pattern 2: System Prompt Directive Injection (PROVEN)

**What:** Add behavioral directives to the system prompt that guide LLM behavior without code logic.
**When to use:** For Layer 4 implementation intention generation and pre-mortem triggering.
**How it works (verified from codebase):**

The system prompt in `claude_coach_service.py` already contains multiple directive blocks: `_FOUR_LAYER_ENGINE`, `_CHECK_IN_PROTOCOL`, `_LIFECYCLE_AWARENESS`, `_PLAN_AWARENESS`, `_BIOGRAPHY_AWARENESS` [VERIFIED: claude_coach_service.py lines 106-220]. New directives follow the same pattern.

```python
_IMPLEMENTATION_INTENTION = """\
## IMPLEMENTATION INTENTIONS (engagement comportemental)
Apres CHAQUE reponse Layer 4 (perspective personnelle + prochaine action) :
1. Propose une intention d'implementation sous forme QUAND/OU/SI-ALORS.
2. Formule en langage naturel, pas en schema.
   Exemple : "Ce lundi, quand tu recevras ta fiche de paie, ouvre ton app 3a 
   et verse 604 CHF. Si le solde est insuffisant, verse au moins 200 CHF."
3. L'utilisateur peut accepter, modifier, ou ignorer.
4. Si l'utilisateur accepte ou modifie, appelle l'outil record_commitment avec 
   les champs when_text, where_text, if_then_text.
5. Ne propose PAS d'intention si la reponse est purement informationnelle 
   (Layer 1-2 seulement).
"""

_PRE_MORTEM_PROTOCOL = """\
## PRE-MORTEM (decisions irreversibles)
Quand le sujet concerne une decision IRREVERSIBLE :
- EPL (retrait anticipe 2e pilier pour achat immobilier)
- Retrait en capital du 2e pilier (vs rente)
- Cloture du 3e pilier
AVANT de proposer une action :
1. Demande : "Imagine qu'on est en 2027 et que cette decision s'est mal passee. 
   Qu'est-ce qui aurait pu arriver ?"
2. Ecoute la reponse de l'utilisateur.
3. Appelle save_pre_mortem avec decision_type, decision_context, user_response.
4. Reformule les risques identifies et continue la conversation.
Si un pre-mortem a deja ete fait sur ce sujet (voir RISQUES IDENTIFIES dans le 
contexte), reference-le naturellement : "En mars tu avais dit craindre que..."
"""
```

### Pattern 3: CoachContext Memory Injection (PROVEN)

**What:** Inject commitment and pre-mortem data into the system prompt memory block.
**When to use:** For auto-referencing pre-mortems and showing commitment status.
**How it works (verified from codebase):**

The memory block is appended to the system prompt in `_build_system_prompt_with_memory()` [VERIFIED: coach_chat.py line 456-471]. New sections follow the same markdown format used for `BIOGRAPHIE FINANCIERE`, `PLAN EN COURS`, etc.

```python
# Injected into memory_block:
"""
ENGAGEMENTS ACTIFS:
- [2026-04-15] Verser 604 CHF sur 3a (QUAND: lundi paie, OU: app bancaire, SI-ALORS: si solde < 604, verser 200)
- [2026-05-01] Demander certificat LPP a l'employeur

RISQUES IDENTIFIES (PRE-MORTEM):
- [2026-03-20] EPL: L'utilisateur a dit craindre que "si les taux montent, on ne pourra plus payer les charges"
- [2026-04-01] Capital 2e pilier: L'utilisateur a dit craindre que "si je vis plus longtemps que prevu, le capital sera epuise"
"""
```

### Pattern 4: Notification Scheduling Extension (PROVEN)

**What:** Add commitment reminder and fresh-start scheduling to the existing notification service.
**When to use:** For CMIT-02 and CMIT-04.
**How it works (verified from codebase):**

The notification service uses `_scheduleNotification()` with ID, title, body, TZDateTime, and payload deeplink [VERIFIED: notification_service.dart lines 713-724]. Uses `AndroidScheduleMode.inexactAllowWhileIdle` and consent checking via `ConsentManager` [VERIFIED: notification_service.dart lines 299-301].

```dart
// New method in NotificationService:
Future<void> scheduleCommitmentReminder({
  required int commitmentId,
  required DateTime reminderAt,
  required String title,
  required String body,
}) async {
  if (kIsWeb || _plugin == null) return;
  if (!_isInitialized) await init();
  
  final hasConsent = await ConsentManager.isConsentGiven(ConsentType.notifications);
  if (!hasConsent) return;
  
  final tzDate = tz.TZDateTime.from(reminderAt, tz.local);
  await _scheduleNotification(
    id: _idCommitmentBase + commitmentId,
    title: title,
    body: body,
    scheduledDate: tzDate,
    payload: '/home?tab=1&intent=commitmentReminder&id=$commitmentId',
  );
}
```

### Anti-Patterns to Avoid

- **Code-level Layer 4 detection:** The CONTEXT decision is clear -- Layer 4 detection is via system prompt directive, NOT code logic that parses LLM output to determine layer. The LLM itself decides when to propose an intention. [VERIFIED: CONTEXT.md line 17]
- **Persisting raw LLM text as commitment fields:** The LLM generates a natural-language intention; the `record_commitment` tool receives structured fields. Don't store the raw narrative -- store the parsed WHEN/WHERE/IF-THEN.
- **Blocking agent loop on DB writes:** The internal tool handlers in `_execute_internal_tool()` are synchronous text-return functions [VERIFIED: coach_chat.py line 572]. Keep DB writes async but return an ack string immediately. The actual persistence can happen in the endpoint handler after the agent loop completes.
- **Scheduling notifications without consent check:** Every notification scheduling path MUST check `ConsentManager.isConsentGiven(ConsentType.notifications)` first [VERIFIED: notification_service.dart line 299-301].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local notification scheduling | Custom alarm manager | `flutter_local_notifications` `zonedSchedule()` | Already handles timezone, inexact alarms, iOS/Android differences [VERIFIED: in use] |
| Agent loop tool interception | New middleware layer | Existing `_execute_internal_tool()` + `INTERNAL_TOOL_NAMES` pattern | Proven pattern with input validation, PII scrubbing, injection filtering [VERIFIED: coach_chat.py] |
| System prompt composition | Dynamic prompt builder | Existing `build_system_prompt()` + directive constants | Already composes 10+ directive blocks cleanly [VERIFIED: claude_coach_service.py] |
| DB migrations | Raw SQL | Alembic `op.create_table()` | Already used for all 14+ model tables; handles SQLite + PostgreSQL [VERIFIED: alembic/versions/] |
| Deeplink routing from notifications | Custom intent handler | Existing `_onNotificationTap` + `pendingRoute` + GoRouter | Proven pattern, auth guard built in [VERIFIED: notification_service.dart lines 742-755] |

**Key insight:** This phase is 100% extension of existing patterns. Zero new architectural concepts needed. The risk is wiring, not novelty.

## Common Pitfalls

### Pitfall 1: _execute_internal_tool is synchronous but DB writes are async
**What goes wrong:** The `_execute_internal_tool` function returns `str` synchronously. If you try to await a DB write inside it, it fails.
**Why it happens:** The function signature is `def _execute_internal_tool(...) -> str` -- not async [VERIFIED: coach_chat.py line 572].
**How to avoid:** Two options: (a) make the function async (requires changing the agent loop caller), or (b) collect tool call data in the function return value and persist after the agent loop completes in the endpoint handler. Option (b) is safer -- it follows the existing `save_insight` pattern which is also acknowledgement-only during the loop [VERIFIED: coach_chat.py lines 664-668].
**Warning signs:** "save_insight ack (non-persisted)" pattern in logs -- the existing tools don't persist during the loop either.

### Pitfall 2: Notification ID collision
**What goes wrong:** Notification IDs must be unique integers. The existing service uses hardcoded ID ranges for different notification types.
**Why it happens:** Each commitment reminder needs its own ID to be individually cancellable.
**How to avoid:** Reserve a new ID range (e.g., 2000+) for commitment reminders. Use `commitmentId % 1000 + 2000` to stay within range. Check existing ID constants in the notification service.
**Warning signs:** Notifications silently replacing each other instead of stacking.

### Pitfall 3: Fresh-start notification spam
**What goes wrong:** Without rate limiting, a user could get 5+ notifications per month (birthday, month-1, year-start, job anniversary, MINT anniversary overlapping).
**Why it happens:** Multiple landmark dates in the same month.
**How to avoid:** The CONTEXT specifies "max 2 per month." Implement a counter in SharedPreferences: `fresh_start_count_YYYY_MM`. Check before scheduling.
**Warning signs:** User receiving 3+ proactive messages in January (year-start + birthday + month-1).

### Pitfall 4: Pre-mortem injection bloating the system prompt
**What goes wrong:** If a user does many pre-mortems, the "RISQUES IDENTIFIES" section grows unbounded, eating into context window.
**Why it happens:** No limit on injection size.
**How to avoid:** Limit to the 3 most recent pre-mortem entries. Each entry should be max 200 chars (same limit as save_insight). The existing memory block truncation in `_sanitize_memory_block` will help but explicit limits are safer.
**Warning signs:** Token budget exhaustion warnings in agent loop logs.

### Pitfall 5: CommitmentCard as Flutter-bound tool call vs inline widget
**What goes wrong:** Confusion about whether `record_commitment` sends a tool_call to Flutter (like `show_fact_card`) or is internal-only.
**Why it happens:** The commitment has two phases: (1) LLM proposes an intention in text, (2) user accepts via CommitmentCard widget.
**How to avoid:** `record_commitment` is INTERNAL (called after user confirms). The CommitmentCard widget is rendered by Flutter from the LLM's text output -- it needs a new Flutter-bound tool (e.g., `show_commitment_card`) that IS forwarded to Flutter. The LLM calls `show_commitment_card` to display the editable card, then after user edits and confirms, Flutter calls the backend to persist.
**Warning signs:** No UI appearing when LLM proposes an intention.

## Code Examples

### SQLAlchemy Model for commitment_devices

```python
# Source: follows existing pattern from app/models/snapshot.py, user.py
from uuid import uuid4
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Text
from sqlalchemy import ForeignKey
from app.core.database import Base

class CommitmentDevice(Base):
    __tablename__ = "commitment_devices"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    type = Column(String, nullable=False, default="implementation_intention")
    when_text = Column(Text, nullable=False)
    where_text = Column(Text, nullable=False)
    if_then_text = Column(Text, nullable=False)
    status = Column(String, nullable=False, default="pending")  # pending, completed, dismissed
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    reminder_at = Column(DateTime, nullable=True)


class PreMortemEntry(Base):
    __tablename__ = "pre_mortem_entries"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    decision_type = Column(String, nullable=False)  # epl, capital_withdrawal, pillar_3a_closure
    decision_context = Column(Text, nullable=True)
    user_response = Column(Text, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
```

### Internal Tool Handler Pattern

```python
# Source: follows existing pattern from coach_chat.py lines 655-668
# In _execute_internal_tool():

if name == "record_commitment":
    when_t = tool_input.get("when_text", "")
    where_t = tool_input.get("where_text", "")
    if_then_t = tool_input.get("if_then_text", "")
    logger.info("record_commitment ack: %s / %s", when_t[:50], if_then_t[:50])
    return f"Engagement note : {when_t} — {if_then_t}"

if name == "save_pre_mortem":
    decision_type = tool_input.get("decision_type", "")
    user_response = tool_input.get("user_response", "")
    logger.info("save_pre_mortem ack: %s", decision_type[:50])
    return f"Pre-mortem enregistre pour {decision_type}."
```

### Fresh-Start Anchor Date Computation

```python
# Source: custom logic, follows profile date patterns
from datetime import date, timedelta

def compute_fresh_start_dates(
    birth_date: str | None,
    first_employment_year: int | None,
    account_created_at: datetime,
) -> list[dict]:
    """Compute upcoming fresh-start landmark dates."""
    today = date.today()
    landmarks = []
    
    # Birthday (if birth_date available)
    if birth_date:
        bd = date.fromisoformat(birth_date[:10])
        next_birthday = bd.replace(year=today.year)
        if next_birthday < today:
            next_birthday = next_birthday.replace(year=today.year + 1)
        landmarks.append({"type": "birthday", "date": next_birthday.isoformat()})
    
    # Month-1 (1er du mois prochain)
    if today.month == 12:
        next_month_1 = date(today.year + 1, 1, 1)
    else:
        next_month_1 = date(today.year, today.month + 1, 1)
    landmarks.append({"type": "month_start", "date": next_month_1.isoformat()})
    
    # Year-start (1er janvier prochain)
    next_year_start = date(today.year + 1, 1, 1)
    landmarks.append({"type": "year_start", "date": next_year_start.isoformat()})
    
    # Job anniversary (if firstEmploymentYear available)
    if first_employment_year:
        job_anniversary = date(today.year, 1, 1)  # approximation -- exact date unknown
        if job_anniversary < today:
            job_anniversary = date(today.year + 1, 1, 1)
        landmarks.append({"type": "job_anniversary", "date": job_anniversary.isoformat()})
    
    # MINT anniversary (1 year from account creation)
    mint_anniversary = account_created_at.date().replace(
        year=account_created_at.year + 1
    )
    if mint_anniversary < today:
        mint_anniversary = mint_anniversary.replace(year=today.year + 1)
    landmarks.append({"type": "mint_anniversary", "date": mint_anniversary.isoformat()})
    
    return landmarks
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `save_insight` ack-only (no persistence) | Internal tools still ack-only in loop | Current | commitment_devices requires actual DB persistence post-loop |
| Memory block as flat text | Memory block with structured sections | S56 | New sections (ENGAGEMENTS, RISQUES) follow same pattern |

**Implementation intention research (behavioral science):** The WHEN/WHERE/IF-THEN format comes from Gollwitzer's implementation intentions research (1999). Meta-analyses show a medium-to-large effect size (d = 0.65) on goal achievement. The structure is: "When [situation X arises], I will [perform behavior Y]." The IF-THEN variant adds a conditional: "If [obstacle Z occurs], then I will [backup action W]." [ASSUMED -- standard behavioral science, not codebase-specific]

**Pre-mortem technique:** Originated from Gary Klein's research on prospective hindsight. Asking "imagine this decision failed -- what went wrong?" has been shown to increase ability to identify risks by 30% compared to standard risk assessment. [ASSUMED -- standard behavioral science]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Implementation intentions effect size d=0.65 from Gollwitzer meta-analysis | State of the Art | No code impact -- informational only |
| A2 | Pre-mortem 30% improvement from Klein research | State of the Art | No code impact -- informational only |
| A3 | `firstEmploymentYear` is available in CoachProfile/profile_context for job anniversary calculation | Architecture Patterns | If not available, job anniversary anchor silently degrades (omitted from list) |
| A4 | The `_execute_internal_tool` function should remain sync with ack-only pattern, persisting after loop | Common Pitfalls | If made async instead, requires agent loop refactor -- both approaches work |

## Open Questions

1. **CommitmentCard as Flutter-bound tool vs text parsing**
   - What we know: The LLM proposes an intention in natural text. The user needs an editable UI.
   - What's unclear: Should the LLM call a new Flutter-bound tool `show_commitment_card` (which renders the widget), or should Flutter parse the LLM text response to detect intention proposals?
   - Recommendation: New Flutter-bound tool `show_commitment_card` is cleaner -- follows the `show_fact_card` pattern exactly. The LLM calls it with structured fields, Flutter renders the editable card. After user confirms, Flutter calls a new backend endpoint to persist.

2. **DB persistence timing -- during agent loop or after?**
   - What we know: Existing internal tools (`save_insight`, `set_goal`, `mark_step_completed`) are acknowledgement-only -- they don't persist during the loop [VERIFIED: coach_chat.py lines 651-668].
   - What's unclear: Should `record_commitment` also be ack-only, or should it persist immediately?
   - Recommendation: Follow the existing pattern (ack-only during loop). Persist via a separate mechanism: either (a) the Flutter-bound `show_commitment_card` tool triggers a Flutter API call after user confirms, or (b) a new dedicated endpoint `/api/v1/coach/commitment` handles persistence.

3. **Fresh-start message generation -- static template or LLM-generated?**
   - What we know: The endpoint `/api/v1/coach/fresh-start` returns a personalized message.
   - What's unclear: Should the message be a template with variable substitution, or should it call the LLM?
   - Recommendation: Template-based with profile data interpolation. Calling the LLM for each fresh-start message adds latency, cost, and complexity. A well-crafted template per landmark type (5 templates) is simpler and faster.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (backend), flutter test (mobile) |
| Config file | `services/backend/pyproject.toml`, `apps/mobile/pubspec.yaml` |
| Quick run command | `cd services/backend && python3 -m pytest tests/test_commitment_devices.py -q` |
| Full suite command | `cd services/backend && python3 -m pytest tests/ -q && cd ../../apps/mobile && flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CMIT-01 | System prompt contains implementation intention directive | unit | `pytest tests/test_commitment_devices.py::test_system_prompt_has_intention_directive -x` | Wave 0 |
| CMIT-01 | record_commitment tool defined in COACH_TOOLS | unit | `pytest tests/test_commitment_devices.py::test_record_commitment_tool_defined -x` | Wave 0 |
| CMIT-02 | CommitmentDevice model creates and queries correctly | unit | `pytest tests/test_commitment_devices.py::test_commitment_model_crud -x` | Wave 0 |
| CMIT-03 | Fresh-start dates computed correctly for all 5 types | unit | `pytest tests/test_commitment_devices.py::test_fresh_start_date_computation -x` | Wave 0 |
| CMIT-04 | Fresh-start endpoint returns personalized message | unit | `pytest tests/test_commitment_devices.py::test_fresh_start_endpoint -x` | Wave 0 |
| CMIT-04 | Rate limiting: max 2 messages per month | unit | `pytest tests/test_commitment_devices.py::test_fresh_start_rate_limit -x` | Wave 0 |
| CMIT-05 | System prompt contains pre-mortem directive | unit | `pytest tests/test_commitment_devices.py::test_system_prompt_has_premortem_directive -x` | Wave 0 |
| CMIT-05 | save_pre_mortem tool defined in COACH_TOOLS | unit | `pytest tests/test_commitment_devices.py::test_save_premortem_tool_defined -x` | Wave 0 |
| CMIT-06 | PreMortemEntry model creates and queries correctly | unit | `pytest tests/test_commitment_devices.py::test_premortem_model_crud -x` | Wave 0 |
| CMIT-06 | CoachContext includes RISQUES IDENTIFIES when pre-mortem exists | unit | `pytest tests/test_commitment_devices.py::test_coach_context_includes_premortem -x` | Wave 0 |
| LOOP-02 | Coach ack message after commitment accepted | unit | `pytest tests/test_commitment_devices.py::test_commitment_ack_message -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `cd services/backend && python3 -m pytest tests/test_commitment_devices.py -x -q`
- **Per wave merge:** `cd services/backend && python3 -m pytest tests/ -q`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `services/backend/tests/test_commitment_devices.py` -- covers CMIT-01 through CMIT-06 + LOOP-02
- [ ] `apps/mobile/test/widgets/commitment_card_test.dart` -- covers CommitmentCard widget rendering

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | All new endpoints require `require_current_user` (existing auth pattern) [VERIFIED: coach_chat.py line 1148] |
| V3 Session Management | no | No session changes |
| V4 Access Control | yes | `user_id` from auth token, never from request body. DB queries filtered by user_id. |
| V5 Input Validation | yes | Tool input validation via `_execute_internal_tool` guards (type check, length limit 500 chars) [VERIFIED: coach_chat.py lines 594-617] |
| V6 Cryptography | no | No crypto operations |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| LLM tool injection via crafted user message | Tampering | Input sanitization in `_execute_internal_tool` + `_INJECTION_PATTERNS` filter [VERIFIED: coach_chat.py line 1091] |
| PII in commitment text (user writes IBAN in IF-THEN field) | Information Disclosure | PII scrub via `_PII_PATTERNS` on all tool inputs [VERIFIED: coach_chat.py lines 1066-1073] |
| IDOR on commitment/pre-mortem entries | Elevation of Privilege | Always filter by authenticated user_id from token, never accept user_id in request body |
| Fresh-start endpoint abuse (rate limit bypass) | Denial of Service | Server-side rate check on landmark count per month, not just client-side SharedPreferences |

## Project Constraints (from CLAUDE.md)

- **Branch flow:** Feature branch from `dev`, never direct push to staging/main
- **Testing:** Minimum 10 unit tests per service file; golden couple verification
- **Backend conventions:** Pure functions for calculations; Pydantic v2 with camelCase alias
- **Compliance:** All LLM output through ComplianceGuard; no banned terms; conditional language only
- **i18n:** ALL user-facing strings via ARB files -- CommitmentCard labels, notification texts, fresh-start messages
- **No hardcoded colors:** CommitmentCard uses `MintColors.*`
- **Notification consent:** Must check `ConsentManager` before any notification scheduling
- **CoachContext:** NEVER contains exact salary, savings, debts, NPA, or employer -- commitment text must also respect this
- **No social comparison:** Commitment tracking is personal only, never compared to others

## Sources

### Primary (HIGH confidence)
- `services/backend/app/services/coach/coach_tools.py` -- tool definition pattern, INTERNAL_TOOL_NAMES, access control helpers
- `services/backend/app/api/v1/endpoints/coach_chat.py` -- agent loop, _execute_internal_tool, _build_system_prompt_with_memory
- `services/backend/app/services/coach/claude_coach_service.py` -- system prompt directives, 4-layer engine
- `apps/mobile/lib/services/notification_service.dart` -- scheduling pattern, deeplinks, consent checking
- `services/backend/app/models/` -- SQLAlchemy model patterns (User, SnapshotModel, etc.)
- `services/backend/alembic/versions/` -- migration patterns (13+ existing migrations)

### Secondary (MEDIUM confidence)
- `14-CONTEXT.md` -- user decisions on architecture and implementation approach

### Tertiary (LOW confidence)
- Behavioral science claims (implementation intentions, pre-mortem) -- from training data, not verified in session

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries already in project, no new dependencies
- Architecture: HIGH -- every pattern is a direct extension of verified existing code
- Pitfalls: HIGH -- identified from reading actual implementation code, not hypothetical
- Behavioral science: LOW -- training knowledge, informational only

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable -- no fast-moving dependencies)
